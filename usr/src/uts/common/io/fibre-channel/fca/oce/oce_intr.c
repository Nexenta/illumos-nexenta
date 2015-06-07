/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright (c) 2009-2012 Emulex. All rights reserved.
 * Use is subject to license terms.
 */



/*
 * Source file interrupt registration
 * and related helper functions
 */

#include <oce_impl.h>

static uint_t oce_isr(caddr_t arg1, caddr_t arg2);
static int
oce_adjust_intrs(struct oce_dev *dev, ddi_cb_action_t action, int count);

/*
 * top level function to setup interrupts
 *
 * dev - software handle to the device
 *
 * return DDI_SUCCESS => success, failure otherwise
 */
int
oce_setup_intr(struct oce_dev *dev)
{
	int ret, i;
	int intr_types = 0;
	int navail = 0;
	int nsupported = 0;
	int min = 0;
	int nreqd = 0;
	int nallocd = 0;
	extern int oce_irm_enable;

	/* get supported intr types */
	ret = ddi_intr_get_supported_types(dev->dip, &intr_types);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Failed to retrieve intr types 0x%x", ret);
		return (DDI_FAILURE);
	}

	dev->rx_rings = min(dev->rx_rings, ncpus + dev->rss_cnt);
	dev->tx_rings = min(dev->tx_rings, ncpus);
#ifdef __sparc
	nreqd = min(dev->tx_rings + dev->rx_rings - dev->rss_cnt, ncpus);
	dev->rx_group[0].eq_idx = dev->tx_rings;
#else
	nreqd = max(dev->tx_rings, dev->rx_rings - dev->rss_cnt);
#endif
	min  = OCE_MIN_VECTORS;

retry_intr:

	if (intr_types & DDI_INTR_TYPE_MSIX) {
		dev->intr_type = DDI_INTR_TYPE_MSIX;
	} else {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "MSIX not available");

		if (intr_types & DDI_INTR_TYPE_FIXED) {
			dev->intr_type = DDI_INTR_TYPE_FIXED;
			dev->rx_rings = dev->tx_rings = min;
		} else {
			return (DDI_FAILURE);
		}
		nreqd = OCE_MIN_VECTORS;
	}

	ret = ddi_intr_get_nintrs(dev->dip, dev->intr_type, &nsupported);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Could not get supported intrs:0x%x", ret);
		return (DDI_FAILURE);
	}

	/* get the number of vectors available */
	ret = ddi_intr_get_navail(dev->dip, dev->intr_type, &navail);
	if (ret != DDI_SUCCESS || navail < min) {
		oce_log(dev, CE_NOTE, MOD_CONFIG,
		    "Vectors: supported:0x%x, available:0x%x, ret:0x%x",
		    nsupported, navail, ret);
		intr_types &= ~dev->intr_type;
		goto retry_intr;
	}

	if (navail < nreqd) {
		nreqd = navail;
	}

	/* allocate htable */
	dev->hsize  = nreqd *  sizeof (ddi_intr_handle_t);
	dev->htable = kmem_zalloc(dev->hsize,  KM_NOSLEEP);

	if (dev->htable == NULL)
		return (DDI_FAILURE);

	/* allocate interrupt */
	ret = ddi_intr_alloc(dev->dip, dev->htable, dev->intr_type,
	    0, nreqd, &nallocd, DDI_INTR_ALLOC_NORMAL);

	if (ret != DDI_SUCCESS || nallocd < min) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Alloc intr failed: %d %d",
		    navail, ret);
		kmem_free(dev->htable, nreqd * sizeof (ddi_intr_handle_t));
		intr_types &= ~dev->intr_type;
		goto retry_intr;
	}

	/*
	 * get the interrupt priority. Assumption is that all handlers have
	 * equal priority
	 */

	ret = ddi_intr_get_pri(dev->htable[0], &dev->intr_pri);

	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Unable to get intr priority: 0x%x", ret);

		for (i = 0; i < dev->num_vectors; i++) {
			(void) ddi_intr_free(dev->htable[i]);
		}
		kmem_free(dev->htable, nreqd * sizeof (ddi_intr_handle_t));
		return (DDI_FAILURE);
	}

	(void) ddi_intr_get_cap(dev->htable[0], &dev->intr_cap);

	/* update the actual number of interrupts allocated */
	dev->num_vectors = nallocd;
	if (oce_irm_enable && dev->intr_type == DDI_INTR_TYPE_MSIX) {
		dev->max_vectors = nreqd;
	} else {
		dev->max_vectors = nallocd;
		dev->tx_rings = min(dev->tx_rings, nallocd);
		dev->rx_rings = min(dev->rx_rings, nallocd + dev->rss_cnt);
	}

	oce_group_rings(dev);
	return (DDI_SUCCESS);
}


/*
 * top level function to undo initialization in oce_setup_intr
 *
 * dev - software handle to the device
 *
 * return DDI_SUCCESS => success, failure otherwise
 */
int
oce_teardown_intr(struct oce_dev *dev)
{
	int i;

	/* release handlers */
	for (i = 0; i < dev->num_vectors; i++) {
		(void) ddi_intr_free(dev->htable[i]);
	}

	/* release htable */
	kmem_free(dev->htable, dev->hsize);
	dev->htable = NULL;
	if (dev->attach_state & ATTACH_CB_REG) {
		(void) ddi_cb_unregister(dev->cb_handle);
	}
	return (DDI_SUCCESS);
}

/*
 * helper function to add ISR based on interrupt type
 *
 * dev - software handle to the device
 *
 * return DDI_SUCCESS => success, failure otherwise
 */
int
oce_setup_handlers(struct oce_dev *dev)
{
	int i = 0;
	int ret;
	for (i = 0; i < dev->num_vectors; i++) {
		ret = ddi_intr_add_handler(dev->htable[i], oce_isr,
		    (caddr_t)&dev->eq[i], NULL);
		if (ret != DDI_SUCCESS) {
			oce_log(dev, CE_WARN, MOD_CONFIG,
			    "Failed to add interrupt handler %d, ret = 0x%x",
			    i, ret);
			for (i--; i >= 0; i--) {
				(void) ddi_intr_remove_handler(dev->htable[i]);
			}
			return (DDI_FAILURE);
		}
	}
	return (DDI_SUCCESS);
}

/*
 * helper function to remove ISRs added in oce_setup_handlers
 *
 * dev - software handle to the device
 *
 * return DDI_SUCCESS => success, failure otherwise
 */
void
oce_remove_handler(struct oce_dev *dev)
{
	int nvec;
	for (nvec = 0; nvec < dev->num_vectors; nvec++) {
		(void) ddi_intr_remove_handler(dev->htable[nvec]);
	}
}

void
oce_chip_ei(struct oce_dev *dev)
{
	uint32_t reg;

	reg =  OCE_CFG_READ32(dev, PCICFG_INTR_CTRL);
	reg |= HOSTINTR_MASK;
	OCE_CFG_WRITE32(dev, PCICFG_INTR_CTRL, reg);
}

/*
 * function to enable interrupts
 *
 * dev - software handle to the device
 *
 * return DDI_SUCCESS => success, failure otherwise
 */
int
oce_ei(struct oce_dev *dev)
{
	int i;
	int ret;

	if (dev->intr_cap & DDI_INTR_FLAG_BLOCK) {
		ret =  ddi_intr_block_enable(dev->htable, dev->num_vectors);
		if (ret !=  DDI_SUCCESS) {
			oce_log(dev, CE_WARN, MOD_CONFIG,
			    "Interrupts block enable failed :%d\n", ret);
			return (DDI_FAILURE);
		}
	} else {
		for (i = 0; i < dev->num_vectors; i++) {
			ret = ddi_intr_enable(dev->htable[i]);
			if (ret != DDI_SUCCESS) {
				oce_log(dev, CE_WARN, MOD_CONFIG,
				    "Failed  to enable, ret %d, interrupt %d,"
				    " type %d, cnt %d ",
				    ret, i, dev->intr_type, dev->num_vectors);
				for (i--; i >= 0; i--) {
					(void) ddi_intr_disable(dev->htable[i]);
				}
				return (DDI_FAILURE);
			}
		}
	}

	return (DDI_SUCCESS);
} /* oce_ei */

void
oce_chip_di(struct oce_dev *dev)
{
	uint32_t reg;

	reg =  OCE_CFG_READ32(dev, PCICFG_INTR_CTRL);
	reg &= ~HOSTINTR_MASK;
	OCE_CFG_WRITE32(dev, PCICFG_INTR_CTRL, reg);
}

/*
 * function to disable interrupts
 *
 * dev - software handle to the device
 *
 * return DDI_SUCCESS => success, failure otherwise
 */
int
oce_di(struct oce_dev *dev)
{
	int i;
	int ret;

	dev->state &= ~STATE_INTR_ENABLED;
	if (!LANCER_CHIP(dev))
		oce_chip_di(dev);

	if (dev->intr_cap & DDI_INTR_FLAG_BLOCK) {
		ret =  ddi_intr_block_disable(dev->htable, dev->num_vectors);
		if (ret !=  DDI_SUCCESS) {
			oce_log(dev, CE_WARN, MOD_CONFIG,
			    "Interrupt block disable failed :%d\n", ret);
			return (DDI_FAILURE);
		}
	} else {
		for (i = 0; i < dev->num_vectors; i++) {
			ret = ddi_intr_disable(dev->htable[i]);
			if (ret != DDI_SUCCESS) {
				oce_log(dev, CE_WARN, MOD_CONFIG,
				    "Failed to disable the interrupts 0x%x",
				    ret);
				return (DDI_FAILURE);
			}
		}
	}
	return (DDI_SUCCESS);
} /* oce_di */


int
oce_ring_intr_enable(mac_intr_handle_t ring_handle)
{
	struct oce_rq *rx_ring = (struct oce_rq *)ring_handle;
	struct oce_dev *dev;
	dev = rx_ring->parent;
	oce_group_t *grp = rx_ring->grp;
	mutex_enter(&grp->grp_lock);
	if (grp->state & GROUP_SUSPEND) {
		mutex_exit(&grp->grp_lock);
		return (DDI_SUCCESS);
	}
	mutex_enter(&rx_ring->rx_lock);
	oce_arm_cq(dev, rx_ring->cq->cq_id, 0, B_TRUE);
	rx_ring->qmode = OCE_MODE_INTR;
	mutex_exit(&rx_ring->rx_lock);
	mutex_exit(&grp->grp_lock);
	return (DDI_SUCCESS);
}


int
oce_ring_intr_disable(mac_intr_handle_t ring_handle)
{
	struct oce_rq *rx_ring = (struct oce_rq *)ring_handle;
	struct oce_dev *dev;

	dev = rx_ring->parent;
	mutex_enter(&rx_ring->rx_lock);
	oce_arm_cq(dev, rx_ring->cq->cq_id, 0, B_FALSE);
	rx_ring->qmode = OCE_MODE_POLL;
	mutex_exit(&rx_ring->rx_lock);
	return (DDI_SUCCESS);
}

uint_t
oce_ring_common_drain(struct oce_eq *eq)
{
	struct oce_eqe *eqe;
	uint16_t num_eqe = 0;
	uint16_t cq_id;
	struct oce_cq *cq;
	struct oce_dev  *dev;

	dev = eq->parent;

	eqe = RING_GET_CONSUMER_ITEM_VA(eq->ring, struct oce_eqe);

	if (eqe->u0.dw0) {
		eqe->u0.dw0 = LE_32(eqe->u0.dw0);

		/* get the cq from the eqe */
		cq_id = eqe->u0.s.resource_id % OCE_MAX_CQ;
		cq = dev->cq[cq_id];

		/* clear valid bit and progress eqe */
		eqe->u0.dw0 = 0;
		RING_GET(eq->ring, 1);
		num_eqe++;

		if (cq) {
			/* Call the completion handler */
			(void) cq->cq_handler(cq->cb_arg, 0, 0);
		}
	}

	/* ring the eq doorbell, signify that it's done processing  */
	oce_arm_eq(dev, eq->eq_id, num_eqe, B_TRUE, B_TRUE);

	return (num_eqe);

} /* oce_ring_common_drain */


/* MSI/INTX handler: common vector for TX/RX/MQ */
uint_t
oce_isr(caddr_t arg1, caddr_t arg2)
{
	struct oce_eq *eq;
	struct oce_dev *dev;
	uint16_t num_eqe = 0;

	_NOTE(ARGUNUSED(arg2));

	eq = (struct oce_eq *)(void *)(arg1);
	dev = eq->parent;

	if ((dev == NULL) ||
	    !(dev->state & STATE_INTR_ENABLED)) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "Dummy interrupt received");
		return (DDI_INTR_CLAIMED);
	}

	mutex_enter(&eq->lock);
	if (eq->qstate != QSTARTED) {
		mutex_exit(&eq->lock);
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "oce_isr EQ Not started");
		return (DDI_INTR_CLAIMED);
	}
	num_eqe = oce_ring_common_drain(eq);
	mutex_exit(&eq->lock);
	if (num_eqe) {
		return (DDI_INTR_CLAIMED);
	} else {
		return (DDI_INTR_UNCLAIMED);
	}
}

/*
 * IRM callback routine
 */
int
oce_cbfunc(dev_info_t *dip, ddi_cb_action_t cbaction, void *cbarg,
    void *arg1, void *arg2)
{
	struct oce_dev *dev = (struct oce_dev *)arg1;
	int count = (int)(uintptr_t)cbarg, ret = DDI_ENOTSUP;

	_NOTE(ARGUNUSED(dip));
	_NOTE(ARGUNUSED(arg2));

	switch (cbaction) {
	case DDI_CB_INTR_ADD:
	case DDI_CB_INTR_REMOVE:

		oce_log(dev, CE_NOTE, MOD_CONFIG,
		    "IRM cbaction %d count %d vectors %d max_vectors %d",
		    cbaction, count, dev->num_vectors, dev->max_vectors);
		ret = oce_adjust_intrs(dev, cbaction, count);
		if (ret != DDI_SUCCESS) {
			oce_log(dev, CE_NOTE,  MOD_CONFIG, "%s",
			    "IRM: Failed to adjust interrupts");
			return (ret);
		}
		break;

	default:
		return (ret);
	}
	return (ret);
}


static int
oce_adjust_intrs(struct oce_dev *dev, ddi_cb_action_t action, int count)
{
	int	i, nallocd, ret;

	if (count == 0)
		return (DDI_SUCCESS);

	if ((action == DDI_CB_INTR_ADD &&
	    dev->num_vectors + count > dev->max_vectors) ||
	    (action == DDI_CB_INTR_REMOVE &&
	    dev->num_vectors - count < OCE_MIN_VECTORS)) {
		return (DDI_FAILURE);
	}

	if (!(dev->state & STATE_MAC_STARTED)) {
		return (DDI_FAILURE);
	}

	mutex_enter(&dev->dev_lock);
	dev->state |= STATE_INTR_ADJUST;
	dev->suspended = B_TRUE;

	/* stop the groups */
	for (i = 0; i < dev->num_rx_groups; i++) {
		mutex_enter(&dev->rx_group[i].grp_lock);
		oce_suspend_group_rings(&dev->rx_group[i]);
		oce_stop_group(&dev->rx_group[i], B_FALSE);
		mutex_exit(&dev->rx_group[i].grp_lock);
	}

	oce_stop(dev);
	oce_remove_handler(dev);
	if (action == DDI_CB_INTR_ADD) {
		/* allocate additional vectors */
		ret = ddi_intr_alloc(dev->dip, dev->htable, DDI_INTR_TYPE_MSIX,
		    dev->num_vectors, count, &nallocd, DDI_INTR_ALLOC_NORMAL);

		if (ret != DDI_SUCCESS) {
			goto irm_fail;
		}

		/* update actual count of available interrupts */
		dev->num_vectors += nallocd;
		oce_log(dev, CE_NOTE, MOD_CONFIG,
		    "IRM: INTR_ADD - count=0x%x allocated=0x%x vectors=0x%x",
		    count, nallocd, dev->num_vectors);
	} else {
		/* free interrupt vectors */
		for (i = dev->num_vectors - count;
		    i < dev->num_vectors; i++) {
			ret = ddi_intr_free(dev->htable[i]);
			if (ret != DDI_SUCCESS) {
				oce_log(dev, CE_WARN, MOD_CONFIG,
				    "IRM: can't free vectors ret 0x%x", ret);
				goto irm_fail;
			}
			dev->htable[i] = NULL;
		}

		/* update actual count of available interrupts */
		dev->num_vectors -= count;
		oce_log(dev, CE_NOTE, MOD_CONFIG,
		    "IRM: INTR_REMOVE - count = 0x%x vectors = 0x%x",
		    count, dev->num_vectors);
	}

	if (oce_setup_handlers(dev) != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "Failed to Setup handlers during IRM");
		goto irm_fail;
	}

	/* re-start the device instance */
	if (oce_start(dev) != DDI_SUCCESS) {
		goto irm_fail;
	}

	ret = ddi_intr_get_pri(dev->htable[0], &dev->intr_pri);

	if (ret != DDI_SUCCESS) {
		goto irm_fail;
	}

	(void) ddi_intr_get_cap(dev->htable[0], &dev->intr_cap);

	/* re-start the groups */
	for (i = 0; i < dev->num_rx_groups; i++) {
		mutex_enter(&dev->rx_group[i].grp_lock);
		ret = oce_start_group(&dev->rx_group[i], B_FALSE);
		if (ret == DDI_SUCCESS) {
			ret = oce_resume_group_rings(&dev->rx_group[i]);
		}
		mutex_exit(&dev->rx_group[i].grp_lock);
		if (ret != DDI_SUCCESS) {
			goto irm_fail;
		}
	}
	dev->state &= ~STATE_INTR_ADJUST;
	dev->suspended = B_FALSE;
	mutex_exit(&dev->dev_lock);

	/* Wakeup all Tx rings */
	for (i = 0; i < dev->tx_rings; i++) {
		mac_tx_ring_update(dev->mac_handle,
		    dev->default_tx_rings[i].tx->handle);
	}

	return (DDI_SUCCESS);

irm_fail:
	ddi_fm_service_impact(dev->dip, DDI_SERVICE_LOST);
	mutex_exit(&dev->dev_lock);
	return (DDI_FAILURE);
}

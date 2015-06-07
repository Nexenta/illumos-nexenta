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
 * Source file containing the implementation of the driver entry points
 * and related helper functions
 */

#include <oce_impl.h>
#include <oce_ioctl.h>

/* ---[ static function declarations ]----------------------------------- */
static int oce_set_priv_prop(struct oce_dev *dev, const char *name,
    uint_t size, const void *val);

static int oce_get_priv_prop(struct oce_dev *dev, const char *name,
    uint_t size, void *val);

/* ---[ GLD entry points ]----------------------------------------------- */
int
oce_m_start(void *arg)
{
	struct oce_dev *dev = arg;
	int i;

	mutex_enter(&dev->dev_lock);

	if (dev->state & STATE_MAC_STARTED) {
		mutex_exit(&dev->dev_lock);
		return (0);
	}

	if (dev->suspended) {
		mutex_exit(&dev->dev_lock);
		return (EIO);
	}

	/* allocate Tx buffers */
	if (oce_init_tx(dev) != DDI_SUCCESS) {
		mutex_exit(&dev->dev_lock);
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "Failed to init rings");
		return (DDI_FAILURE);
	}

	if (oce_start(dev) != DDI_SUCCESS) {
		oce_fini_tx(dev);
		mutex_exit(&dev->dev_lock);
		return (EIO);
	}
	dev->state |= STATE_MAC_STARTED;

	/* initialise the group locks */
	for (i = 0; i < dev->num_rx_groups; i++) {
		mutex_init(&dev->rx_group[i].grp_lock, NULL, MUTEX_DRIVER,
		    DDI_INTR_PRI(dev->intr_pri));
	}

	mutex_exit(&dev->dev_lock);
	oce_enable_wd_timer(dev);
	return (DDI_SUCCESS);
}

void
oce_start_eqs(struct oce_dev *dev)
{
	int qidx = 0;

	for (qidx = 0; qidx < dev->neqs; qidx++) {
		mutex_enter(&dev->eq[qidx].lock);
		oce_arm_eq(dev, dev->eq[qidx].eq_id, 0, B_TRUE, B_FALSE);
		dev->eq[qidx].qstate = QSTARTED;
		mutex_exit(&dev->eq[qidx].lock);
	}
}

void
oce_stop_eqs(struct oce_dev *dev)
{
	int qidx = 0;

	for (qidx = 0; qidx < dev->neqs; qidx++) {
		mutex_enter(&dev->eq[qidx].lock);
		oce_arm_eq(dev, dev->eq[qidx].eq_id, 0, B_FALSE, B_FALSE);
		dev->eq[qidx].qstate = QSTOPPED;
		mutex_exit(&dev->eq[qidx].lock);
	}
}
int
oce_start(struct oce_dev *dev)
{
	int qidx = 0;

	/* disable the interrupts */
	if (!LANCER_CHIP(dev))
		oce_chip_di(dev);

	/* set default flow control */
	(void) oce_set_flow_control(dev, dev->flow_control, MBX_BOOTSTRAP);
	(void) oce_set_promiscuous(dev, dev->promisc, MBX_BOOTSTRAP);

	if (oce_ei(dev) != DDI_SUCCESS) {
		return (DDI_FAILURE);
	}

	if (oce_create_queues(dev) != DDI_SUCCESS) {
		goto cleanup_handler;
	}

	for (qidx = 0; qidx < dev->tx_rings; qidx++) {
		mac_ring_intr_set(dev->default_tx_rings[qidx].tx->handle,
		    dev->htable[dev->default_tx_rings[qidx].tx->cq->eq->idx]);
		(void) oce_start_wq(dev->default_tx_rings[qidx].tx);
	}

	if (oce_create_mcc_queue(dev) != DDI_SUCCESS) {
		goto delete_queues;
	}
	(void) oce_start_mq(dev->mq);

	dev->state |= STATE_INTR_ENABLED;

	if (!LANCER_CHIP(dev))
		oce_chip_ei(dev);

	/* arm the eqs */
	oce_start_eqs(dev);

	/* get link status */
	if (oce_get_link_status(dev, &dev->link_status, &dev->link_speed,
	    (uint8_t *)&dev->link_duplex, 1, MBX_ASYNC_MQ) != DDI_SUCCESS) {
		(void) oce_get_link_status(dev, &dev->link_status,
		    &dev->link_speed, (uint8_t *)&dev->link_duplex,
		    0, MBX_ASYNC_MQ);
	}
	oce_log(dev, CE_NOTE, MOD_CONFIG, "link speed %d "
	    "link status %d", dev->link_speed, dev->link_status);

	mac_link_update(dev->mac_handle, dev->link_status);
	return (DDI_SUCCESS);

delete_queues:
	oce_delete_queues(dev);
cleanup_handler:
	(void) oce_di(dev);
	return (DDI_FAILURE);
} /* oce_start */


void
oce_m_stop(void *arg)
{
	struct oce_dev *dev = arg;
	int i;

	mutex_enter(&dev->dev_lock);
	if (dev->suspended) {
		mutex_exit(&dev->dev_lock);
		return;
	}

	dev->state &= ~STATE_MAC_STARTED;
	oce_stop(dev);

	/* free Tx buffers */
	oce_fini_tx(dev);

	for (i = 0; i < dev->rx_rings; i++) {
		while (dev->rq[i].pending > 0) {
			oce_log(dev, CE_NOTE, MOD_CONFIG,
			    "%d pending buffers on rq %p\n",
			    dev->rq[i].pending, (void *)&dev->rq[i]);
			drv_usecwait(10 * 1000);
		}
	}

	/* destroy group locks */
	for (i = 0; i < dev->num_rx_groups; i++) {
		mutex_destroy(&dev->rx_group[i].grp_lock);
	}

	mutex_exit(&dev->dev_lock);
	oce_disable_wd_timer(dev);
}


/* called with Tx/Rx comp locks held */
void
oce_stop(struct oce_dev *dev)
{
	int qidx;

	dev->state |= STATE_MAC_STOPPING;

	/* disable interrupts */
	(void) oce_di(dev);
	oce_stop_eqs(dev);
	dev->state &= (~STATE_INTR_ENABLED);

	for (qidx = 0; qidx < dev->nwqs; qidx++) {
		mac_ring_intr_set(dev->default_tx_rings[qidx].tx->handle, NULL);
		mutex_enter(&dev->wq[qidx].tx_lock);
	}
	mutex_enter(&dev->mq->lock);

	for (qidx = 0; qidx < dev->tx_rings; qidx++) {
		/* stop and flush the Tx */
		(void) oce_clean_wq(dev->default_tx_rings[qidx].tx);
	}

	/* Free the pending commands */
	oce_clean_mq(dev->mq);

	/* Release all the locks */
	mutex_exit(&dev->mq->lock);
	for (qidx = 0; qidx < dev->nwqs; qidx++)
		mutex_exit(&dev->wq[qidx].tx_lock);

	if (dev->link_status == LINK_STATE_UP) {
		dev->link_status = LINK_STATE_UNKNOWN;
		mac_link_update(dev->mac_handle, dev->link_status);
	}

	oce_delete_mcc_queue(dev);
	oce_delete_queues(dev);

	dev->state &= ~STATE_MAC_STOPPING;
} /* oce_stop */


int
oce_m_multicast(void *arg, boolean_t add, const uint8_t *mca)
{
	struct oce_dev *dev = (struct oce_dev *)arg;
	struct ether_addr  *mca_drv_list;
	struct ether_addr  mca_hw_list[OCE_MAX_MCA];
	uint16_t new_mcnt = dev->num_mca;
	int ret;
	int i;

	/* Allocate the local array for holding the addresses temporarily */
	bzero(&mca_hw_list, sizeof (&mca_hw_list));
	mca_drv_list = &dev->multi_cast[0];

	DEV_LOCK(dev);
	if (add) {
		/* check if we exceeded hw max  supported */
		if (new_mcnt < OCE_MAX_MCA) {
			/* copy entire dev mca to the mbx */
			bcopy((void*)mca_drv_list,
			    (void*)mca_hw_list,
			    (dev->num_mca * sizeof (struct ether_addr)));
			/* Append the new one to local list */
			bcopy(mca, &mca_hw_list[dev->num_mca],
			    sizeof (struct ether_addr));
		}
		new_mcnt++;
	} else {
		struct ether_addr *hwlistp = &mca_hw_list[0];
		for (i = 0; i < dev->num_mca; i++) {
			/* copy only if it does not match */
			if (bcmp((mca_drv_list + i), mca, ETHERADDRL)) {
				bcopy(mca_drv_list + i, hwlistp,
				    ETHERADDRL);
				hwlistp++;
			}
		}
		/* Decrement the count */
		new_mcnt--;
	}

	if (dev->suspended) {
		goto finish;
	}
	if (new_mcnt > OCE_MAX_MCA) {
		ret = oce_set_multicast_table(dev, dev->if_id, &mca_hw_list[0],
		    OCE_MAX_MCA, B_TRUE, MBX_BOOTSTRAP);
	} else {
		ret = oce_set_multicast_table(dev, dev->if_id,
		    &mca_hw_list[0], new_mcnt, B_FALSE, MBX_BOOTSTRAP);
	}
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "mcast %s failed 0x%x", add ? "ADD" : "DEL", ret);
		DEV_UNLOCK(dev);
		return (EIO);
	}
	/*
	 *  Copy the local structure to dev structure
	 */
finish:
	if (new_mcnt && new_mcnt <= OCE_MAX_MCA) {
		bcopy(mca_hw_list, mca_drv_list,
		    new_mcnt * sizeof (struct ether_addr));

		dev->num_mca = (uint16_t)new_mcnt;
	}
	DEV_UNLOCK(dev);
	oce_log(dev, CE_NOTE, MOD_CONFIG,
	    "mcast %s, addr=%02x:%02x:%02x:%02x:%02x:%02x, num_mca=%d",
	    add ? "ADD" : "DEL",
	    mca[0], mca[1], mca[2], mca[3], mca[4], mca[5],
	    dev->num_mca);
	return (0);
} /* oce_m_multicast */


boolean_t
oce_m_getcap(void *arg, mac_capab_t cap, void *data)
{
	struct oce_dev *dev = arg;
	boolean_t ret = B_TRUE;
	switch (cap) {

	case MAC_CAPAB_HCKSUM: {
		uint32_t *csum_flags = u32ptr(data);
		*csum_flags = HCKSUM_ENABLE |
		    HCKSUM_INET_FULL_V4 |
		    HCKSUM_IPHDRCKSUM;
		break;
	}
	case MAC_CAPAB_LSO: {
		mac_capab_lso_t *mcap_lso = (mac_capab_lso_t *)data;
		if (dev->lso_capable) {
			mcap_lso->lso_flags = LSO_TX_BASIC_TCP_IPV4;
			mcap_lso->lso_basic_tcp_ipv4.lso_max = OCE_LSO_MAX_SIZE;
		} else {
			ret = B_FALSE;
		}
		break;
	}
	case MAC_CAPAB_RINGS:

		ret = oce_fill_rings_capab(dev, (mac_capab_rings_t *)data);
		break;

	default:
		ret = B_FALSE;
		break;
	}
	return (ret);
} /* oce_m_getcap */

int
oce_m_setprop(void *arg, const char *name, mac_prop_id_t id,
    uint_t size, const void *val)
{
	struct oce_dev *dev = arg;
	int ret = 0;

	DEV_LOCK(dev);
	switch (id) {
	case MAC_PROP_MTU: {
		uint32_t mtu;

		bcopy(val, &mtu, sizeof (uint32_t));

		if (dev->mtu == mtu) {
			ret = 0;
			break;
		}

		if (mtu != OCE_MIN_MTU && mtu != OCE_MAX_MTU) {
			ret = EINVAL;
			break;
		}

		if (dev->state & STATE_MAC_STARTED) {
			ret =  EBUSY;
			break;
		}

		ret = mac_maxsdu_update(dev->mac_handle, mtu);
		if (0 == ret) {
			dev->mtu = mtu;
			break;
		}
		break;
	}

	case MAC_PROP_FLOWCTRL: {
		link_flowctrl_t flowctrl;
		uint32_t fc = 0;

		bcopy(val, &flowctrl, sizeof (link_flowctrl_t));

		switch (flowctrl) {
		case LINK_FLOWCTRL_NONE:
			fc = 0;
			break;

		case LINK_FLOWCTRL_RX:
			fc = OCE_FC_RX;
			break;

		case LINK_FLOWCTRL_TX:
			fc = OCE_FC_TX;
			break;

		case LINK_FLOWCTRL_BI:
			fc = OCE_FC_RX | OCE_FC_TX;
			break;
		default:
			ret = EINVAL;
			break;
		} /* switch flowctrl */

		if (ret)
			break;

		if (fc == dev->flow_control)
			break;

		if (dev->suspended) {
			dev->flow_control = fc;
			break;
		}
		/* call to set flow control */
		ret = oce_set_flow_control(dev, fc, MBX_ASYNC_MQ);
		/* store the new fc setting on success */
		if (ret == 0) {
			dev->flow_control = fc;
		}
		break;
	}

	case MAC_PROP_PRIVATE:
		ret = oce_set_priv_prop(dev, name, size, val);
		break;

	default:
		ret = ENOTSUP;
		break;
	} /* switch id */

	DEV_UNLOCK(dev);
	return (ret);
} /* oce_m_setprop */

int
oce_m_getprop(void *arg, const char *name, mac_prop_id_t id,
    uint_t size, void *val)
{
	struct oce_dev *dev = arg;
	uint32_t ret = 0;

	switch (id) {
	case MAC_PROP_ADV_10GFDX_CAP:
	case MAC_PROP_EN_10GFDX_CAP:
		*(uint8_t *)val = 0x01;
		break;

	case MAC_PROP_DUPLEX: {
		uint32_t *mode = (uint32_t *)val;

		ASSERT(size >= sizeof (link_duplex_t));
		if (dev->state & STATE_MAC_STARTED)
			*mode = LINK_DUPLEX_FULL;
		else
			*mode = LINK_DUPLEX_UNKNOWN;
		break;
	}

	case MAC_PROP_SPEED: {
		uint64_t speed;
		speed = dev->link_speed * 1000000ull;
		bcopy(&speed, val, sizeof (speed));
		break;
	}

	case MAC_PROP_FLOWCTRL: {
		link_flowctrl_t *fc = (link_flowctrl_t *)val;

		ASSERT(size >= sizeof (link_flowctrl_t));
		if (dev->flow_control & OCE_FC_TX &&
		    dev->flow_control & OCE_FC_RX)
			*fc = LINK_FLOWCTRL_BI;
		else if (dev->flow_control == OCE_FC_TX)
			*fc = LINK_FLOWCTRL_TX;
		else if (dev->flow_control == OCE_FC_RX)
			*fc = LINK_FLOWCTRL_RX;
		else if (dev->flow_control == 0)
			*fc = LINK_FLOWCTRL_NONE;
		else
			ret = EINVAL;
		break;
	}

	case MAC_PROP_PRIVATE:
		ret = oce_get_priv_prop(dev, name, size, val);
		break;

	default:
		ret = ENOTSUP;
		break;
	} /* switch id */
	return (ret);
} /* oce_m_getprop */

void
oce_m_propinfo(void *arg, const char *name, mac_prop_id_t pr_num,
    mac_prop_info_handle_t prh)
{
	_NOTE(ARGUNUSED(arg));

	switch (pr_num) {
	case MAC_PROP_AUTONEG:
	case MAC_PROP_EN_AUTONEG:
	case MAC_PROP_ADV_1000FDX_CAP:
	case MAC_PROP_EN_1000FDX_CAP:
	case MAC_PROP_ADV_1000HDX_CAP:
	case MAC_PROP_EN_1000HDX_CAP:
	case MAC_PROP_ADV_100FDX_CAP:
	case MAC_PROP_EN_100FDX_CAP:
	case MAC_PROP_ADV_100HDX_CAP:
	case MAC_PROP_EN_100HDX_CAP:
	case MAC_PROP_ADV_10FDX_CAP:
	case MAC_PROP_EN_10FDX_CAP:
	case MAC_PROP_ADV_10HDX_CAP:
	case MAC_PROP_EN_10HDX_CAP:
	case MAC_PROP_ADV_100T4_CAP:
	case MAC_PROP_EN_100T4_CAP:
	case MAC_PROP_ADV_10GFDX_CAP:
	case MAC_PROP_EN_10GFDX_CAP:
	case MAC_PROP_SPEED:
	case MAC_PROP_DUPLEX:
		mac_prop_info_set_perm(prh, MAC_PROP_PERM_READ);
		break;

	case MAC_PROP_MTU:
		mac_prop_info_set_range_uint32(prh, OCE_MIN_MTU, OCE_MAX_MTU);
		break;

	case MAC_PROP_PRIVATE: {
		char valstr[64];
		int value;
		uint_t perm = MAC_PROP_PERM_READ;

		bzero(valstr, sizeof (valstr));
		if (strcmp(name, "_tx_rings") == 0) {
			value = OCE_DEFAULT_WQS;
		} else if (strcmp(name, "_tx_ring_size") == 0) {
			value = OCE_DEFAULT_TX_RING_SIZE;
			perm = MAC_PROP_PERM_RW;
		} else if (strcmp(name, "_tx_bcopy_limit") == 0) {
			value = OCE_DEFAULT_TX_BCOPY_LIMIT;
			perm = MAC_PROP_PERM_RW;
		} else if (strcmp(name, "_tx_reclaim_threshold") == 0) {
			value = OCE_DEFAULT_TX_RECLAIM_THRESHOLD;
			perm = MAC_PROP_PERM_RW;
		} else if (strcmp(name, "_rx_rings") == 0) {
			value = OCE_DEFAULT_RQS;
		} else if (strcmp(name, "_rx_rings_per_group") == 0) {
			value = OCE_DEF_RING_PER_GROUP;
		} else if (strcmp(name, "_rx_ring_size") == 0) {
			value = OCE_DEFAULT_RX_RING_SIZE;
		} else if (strcmp(name, "_rx_bcopy_limit") == 0) {
			value = OCE_DEFAULT_RX_BCOPY_LIMIT;
			perm = MAC_PROP_PERM_RW;
		} else if (strcmp(name, "_rx_pkts_per_intr") == 0) {
			value = OCE_DEFAULT_RX_PKTS_PER_INTR;
			perm = MAC_PROP_PERM_RW;
		} else if (strcmp(name, "_log_level") == 0) {
			value = OCE_DEFAULT_LOG_SETTINGS;
			perm = MAC_PROP_PERM_RW;
		} else
			return;

		(void) snprintf(valstr, sizeof (valstr), "%d", value);
		mac_prop_info_set_default_str(prh, valstr);
		mac_prop_info_set_perm(prh, perm);
		break;
	}
	}
} /* oce_m_propinfo */

/*
 * function to handle dlpi streams message from GLDv3 mac layer
 */
void
oce_m_ioctl(void *arg, queue_t *wq, mblk_t *mp)
{
	struct oce_dev *dev = arg;
	struct  iocblk *iocp;
	int cmd;
	uint32_t payload_length;
	int ret;

	iocp = (struct iocblk *)voidptr(mp->b_rptr);
	iocp->ioc_error = 0;
	cmd = iocp->ioc_cmd;

	DEV_LOCK(dev);
	if (dev->suspended) {
		miocnak(wq, mp, 0, EINVAL);
		DEV_UNLOCK(dev);
		return;
	}
	DEV_UNLOCK(dev);

	switch (cmd) {

	case OCE_ISSUE_MBOX: {
		ret = oce_issue_mbox_passthru(dev, wq, mp, &payload_length);
		miocack(wq, mp, payload_length, ret);
		break;
	}
	case OCE_QUERY_DRIVER_DATA: {
		struct oce_driver_query *drv_query =
		    (struct oce_driver_query *)(void *)mp->b_cont->b_rptr;

		/* if the driver version does not match bail */
		if (drv_query->version != OCN_VERSION_SUPPORTED) {
			oce_log(dev, CE_NOTE, MOD_CONFIG, "%s",
			    "One Connect version mismatch");
			miocnak(wq, mp, 0, ENOTSUP);
			break;
		}

		/* fill the return values */
		bcopy(OCE_MOD_NAME, drv_query->driver_name,
		    (sizeof (OCE_MOD_NAME) > 32) ?
		    31 : sizeof (OCE_MOD_NAME));
		drv_query->driver_name[31] = '\0';

		bcopy(OCE_VERSION, drv_query->driver_version,
		    (sizeof (OCE_VERSION) > 32) ? 31 :
		    sizeof (OCE_VERSION));
		drv_query->driver_version[31] = '\0';

		if (dev->num_smac == 0) {
			drv_query->num_smac = 1;
			bcopy(dev->mac_addr, drv_query->smac_addr[0],
			    ETHERADDRL);
		} else {
			drv_query->num_smac = dev->num_smac;
			bcopy(dev->unicast_addr, drv_query->smac_addr[0],
			    ETHERADDRL);
		}

		bcopy(dev->mac_addr, drv_query->pmac_addr, ETHERADDRL);

		payload_length = sizeof (struct oce_driver_query);
		miocack(wq, mp, payload_length, 0);
		break;
	}

	default:
		miocnak(wq, mp, 0, ENOTSUP);
		break;
	}
} /* oce_m_ioctl */

int
oce_m_promiscuous(void *arg, boolean_t enable)
{
	struct oce_dev *dev = arg;
	int ret = 0;

	DEV_LOCK(dev);

	if (dev->promisc == enable) {
		DEV_UNLOCK(dev);
		return (ret);
	}

	if (dev->suspended) {
		/* remember the setting */
		dev->promisc = enable;
		DEV_UNLOCK(dev);
		return (ret);
	}

	ret = oce_set_promiscuous(dev, enable, MBX_ASYNC_MQ);
	if (ret == DDI_SUCCESS) {
		dev->promisc = enable;
		if (!(enable)) {
			struct ether_addr  *mca_drv_list;
			mca_drv_list = &dev->multi_cast[0];
			if (dev->num_mca > OCE_MAX_MCA) {
				ret = oce_set_multicast_table(dev, dev->if_id,
				    &mca_drv_list[0], OCE_MAX_MCA, B_TRUE,
				    MBX_ASYNC_MQ);
			} else {
				ret = oce_set_multicast_table(dev, dev->if_id,
				    &mca_drv_list[0], dev->num_mca, B_FALSE,
				    MBX_ASYNC_MQ);
			}
		}
	}
	DEV_UNLOCK(dev);
	return (ret);
} /* oce_m_promiscuous */

/*
 * function to set a private property.
 * Called from the set_prop GLD entry point
 *
 * dev - sofware handle to the device
 * name - string containing the property name
 * size - length of the string in name
 * val - pointer to a location where the value to set is stored
 *
 * return EINVAL => invalid value in val 0 => success
 */
static int
oce_set_priv_prop(struct oce_dev *dev, const char *name,
    uint_t size, const void *val)
{
	int ret = EINVAL;
	long result;

	_NOTE(ARGUNUSED(size));

	if (NULL == val) {
		return (EINVAL);
	}
	(void) ddi_strtol(val, (char **)NULL, 0, &result);
	if (strcmp(name, "_tx_ring_size") == 0) {
		if (result <= SIZE_2K) {
			if (dev->tx_ring_size != result) {
				dev->tx_ring_size = (uint32_t)result;
			}
			ret = 0;
		}
	} else if (strcmp(name, "_tx_bcopy_limit") == 0) {
		if (result <= SIZE_2K) {
			if (result != dev->tx_bcopy_limit)
				dev->tx_bcopy_limit = (uint32_t)result;
			ret = 0;
		}
	} else if (strcmp(name, "_tx_reclaim_threshold") == 0) {
		if (result <= dev->tx_ring_size) {
			if (dev->tx_reclaim_threshold != result) {
				dev->tx_reclaim_threshold = (uint32_t)result;
			}
			ret = 0;
		}
	} else if (strcmp(name, "_rx_bcopy_limit") == 0) {
		if (result <= dev->mtu) {
			if (dev->rx_bcopy_limit != result) {
				dev->rx_bcopy_limit = (uint32_t)result;
			}
			ret = 0;
		}
	} else if (strcmp(name, "_rx_pkts_per_intr") == 0) {
		if (result <= dev->rx_ring_size) {
			if (dev->rx_pkt_per_intr != result) {
				dev->rx_pkt_per_intr = (uint32_t)result;
			}
			ret = 0;
		}
	} else if (strcmp(name, "_log_level") == 0) {
		if (result <= OCE_MAX_LOG_SETTINGS) {
			/* derive from the loglevel */
			dev->severity = (uint16_t)(result & 0xffff);
			dev->mod_mask = (uint16_t)(result >> 16);
		}
		ret = 0;
	}

	return (ret);
} /* oce_set_priv_prop */

/*
 * function to get the value of a private property. Called from get_prop
 *
 * dev - software handle to the device
 * name - string containing the property name
 * size - length of the string contained name
 * val - [OUT] pointer to the location where the result is returned
 *
 * return EINVAL => invalid request 0 => success
 */
static int
oce_get_priv_prop(struct oce_dev *dev, const char *name,
    uint_t size, void *val)
{
	int value;

	if (strcmp(name, "_tx_rings") == 0) {
		value = dev->tx_rings;
	} else if (strcmp(name, "_tx_ring_size") == 0) {
		value = dev->tx_ring_size;
	} else if (strcmp(name, "_tx_bcopy_limit") == 0) {
		value = dev->tx_bcopy_limit;
	} else if (strcmp(name, "_tx_reclaim_threshold") == 0) {
		value = dev->tx_reclaim_threshold;
	} else if (strcmp(name, "_rx_rings") == 0) {
			value = dev->rx_rings;
	} else if (strcmp(name, "_rx_rings_per_group") == 0) {
			value = dev->rx_rings_per_group;
	} else if (strcmp(name, "_rx_ring_size") == 0) {
		value = dev->rx_ring_size;
	} else if (strcmp(name, "_rx_bcopy_limit") == 0) {
		value = dev->rx_bcopy_limit;
	} else if (strcmp(name, "_rx_pkts_per_intr") == 0) {
		value = dev->rx_pkt_per_intr;
	} else if (strcmp(name, "_log_level") == 0) {
		value = (dev->mod_mask << 16UL) | dev->severity;
	} else {
		return (ENOTSUP);
	}

	(void) snprintf(val, size, "%d", value);
	return (0);
} /* oce_get_priv_prop */

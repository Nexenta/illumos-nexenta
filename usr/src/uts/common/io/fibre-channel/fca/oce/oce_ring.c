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
 * Source file containing Ring handling functions
 *
 */

#include <oce_impl.h>

void
oce_group_rings(struct oce_dev *dev)
{
	uint32_t i;
	/*
	 * decide the ring groups based on dev->rx_rings &
	 * dev->rx_rings_per_group
	 */

	dev->rss_cnt = 0;
	if ((dev->chip_rev == OC_CNA_GEN2) || (dev->chip_rev == OC_CNA_GEN3)) {
		/*
		 * BE2 supports only one RSS group per function.
		 * In a multi-group configuration Group-0 will have RSS
		 * The remaining groups (group 1 to N-1) will have single
		 * RX ring
		 */

		if (!(dev->function_caps & BE_FUNCTION_CAPS_RSS)) {
			dev->rx_rings = dev->tx_rings = 1;
		}

		/* RSS grouping */
		dev->rx_group[0].parent = dev;
		dev->rx_group[0].num_rings =
		    min(dev->rx_rings, dev->rx_rings_per_group);
		if (dev->rx_group[0].num_rings > 1) {
			dev->rx_group[0].rss_enable = B_TRUE;
			dev->rss_cnt++;
		} else {
			dev->rx_group[0].rss_enable = B_FALSE;
		}

		/* non-RSS groups */
		dev->num_rx_groups =
		    min(dev->rx_rings - dev->rx_group[0].num_rings + 1,
		    OCE_MAX_RING_GROUPS);
		dev->rx_rings =
		    dev->rx_group[0].num_rings + dev->num_rx_groups - 1;

		for (i = 1; i < dev->num_rx_groups; i++) {
			dev->rx_group[i].parent = dev;
			dev->rx_group[i].num_rings = 1;
			dev->rx_group[i].rss_enable = B_FALSE;
			dev->rx_group[i].eq_idx = dev->rx_group[i-1].eq_idx +
			    dev->rx_group[i-1].num_rings -
			    dev->rx_group[i-1].rss_enable;
		}
		/* default single tx group */
		dev->num_tx_groups	= 1;
	} else if (LANCER_CHIP(dev)) {
		if (dev->rx_rings_per_group > dev->rx_rings)
			dev->rx_rings_per_group = dev->rx_rings;
		dev->num_rx_groups = dev->rx_rings / dev->rx_rings_per_group;
		dev->rx_rings = dev->num_rx_groups *  dev->rx_rings_per_group;
		for (i = 0; i < dev->num_rx_groups; i++) {
			dev->rx_group[i].parent = dev;
			dev->rx_group[i].num_rings = dev->rx_rings_per_group;
			if (dev->rx_rings_per_group > 1) {
				dev->rx_group[i].rss_enable = B_TRUE;
				dev->rss_cnt++;
			} else {
				dev->rx_group[i].rss_enable = B_FALSE;
			}

			if (i != 0)
				dev->rx_group[i].eq_idx =
				    dev->rx_group[i-1].eq_idx +
				    dev->rx_group[i-1].num_rings -
				    dev->rx_group[i-1].rss_enable;
		}
		/* default single tx group */
		dev->num_tx_groups	= 1;
	}
}


/*
 * Decide Ring Groups information (no. of groups, no. of rings
 * in each group, rss or no_rss), based on profile, num_rx_rings,
 * num_tx_rings input by the user in the config settings.
 */
boolean_t
oce_fill_rings_capab(struct oce_dev *dev, mac_capab_rings_t *capab)
{

	switch (capab->mr_type) {
	case MAC_RING_TYPE_RX:
		capab->mr_group_type	= MAC_GROUP_TYPE_STATIC;
		capab->mr_gnum = dev->num_rx_groups;
		capab->mr_rnum = dev->rx_rings;
		capab->mr_rget = oce_get_ring;
		capab->mr_gget = oce_get_group;
		capab->mr_gaddring = NULL;
		capab->mr_gremring = NULL;
		break;

	case MAC_RING_TYPE_TX:
		capab->mr_group_type	= MAC_GROUP_TYPE_STATIC;
		/*
		 * XXX: num_tx_groups is always 1, and for some reason
		 * mr_gnum has to be 0 or else we trigger an assertion in
		 * mac_init_rings() at mac.c:4022. This could be a bug in
		 * our GLDv3, I don't know. No other driver seems to use
		 * mr_gnum != 0 for TX.  -- Hans
		 */
		ASSERT(dev->num_tx_groups == 1);
		capab->mr_gnum = dev->num_tx_groups - 1;
		capab->mr_rnum = dev->tx_rings;
		capab->mr_rget = oce_get_ring;
		capab->mr_gget = oce_get_group;
		break;
	default:
		return (B_FALSE);
	}
	return (B_TRUE);

}

/*
 * Driver entry points for groups/rings registration
 */

void
oce_get_ring(void *arg, mac_ring_type_t rtype, const int grp_index,
    const int ring_index, mac_ring_info_t *ring_info,
    mac_ring_handle_t ring_handle)
{
	struct oce_dev *dev = arg;
	oce_ring_t *ring;

	switch (rtype) {
	case MAC_RING_TYPE_RX: {

		ring = &dev->rx_group[grp_index].ring[ring_index];
		ring->rx->handle = ring_handle;
		ring_info->mri_driver = (mac_ring_driver_t)ring->rx;
		ring_info->mri_start = oce_ring_start;
		ring_info->mri_stop = oce_ring_stop;
		ring_info->mri_poll = oce_ring_rx_poll;
		ring_info->mri_stat = oce_ring_rx_stat;
		ring_info->mri_intr.mi_enable = oce_ring_intr_enable;
		ring_info->mri_intr.mi_disable = oce_ring_intr_disable;
		ring_info->mri_intr.mi_handle = (mac_intr_handle_t)ring->rx;

		break;
	}
	case MAC_RING_TYPE_TX: {

		ring = &dev->default_tx_rings[ring_index];
		/* mac_intr_t not applicable for TX */
		ring->tx->handle = ring_handle;
		ring_info->mri_driver = (mac_ring_driver_t)ring->tx;
		ring_info->mri_start = NULL;
		ring_info->mri_stop = NULL;
		ring_info->mri_tx = oce_ring_tx;
		ring_info->mri_stat = oce_ring_tx_stat;

		break;
	}
	default:
		break;
	}
}


void
oce_get_group(void *arg, mac_ring_type_t rtype, const int grp_index,
    mac_group_info_t *grp_info, mac_group_handle_t grp_handle)
{
	struct oce_dev *dev = arg;
	oce_group_t *grp = NULL;
	uint32_t i = 0;

	switch (rtype) {

	case MAC_RING_TYPE_RX: {
		grp = &dev->rx_group[grp_index];
		grp->handle = grp_handle;
		grp->grp_type = rtype;
		grp->grp_num = grp_index;
		/* Initialize the pmac-ids to invalid values */
		while (i < OCE_MAX_PMAC_PER_GRP) {
			grp->pmac_ids[i] = INVALID_PMAC_ID;
			i++;
		}

		grp_info->mgi_driver = (mac_group_driver_t)grp;
		grp_info->mgi_start = oce_m_start_group;
		grp_info->mgi_stop = oce_m_stop_group;
		grp_info->mgi_addmac = oce_group_addmac;
		grp_info->mgi_remmac = oce_group_remmac;
		grp_info->mgi_count = grp->num_rings;
		break;
	}

	case MAC_RING_TYPE_TX:
		/* default TX group of 1 */
		grp_info->mgi_driver = NULL;
		grp_info->mgi_start = NULL;
		grp_info->mgi_stop = NULL;
		grp_info->mgi_count = dev->tx_rings;
		break;

	default:
		break;
	}
}

/*
 * Ring level operations
 */
int
oce_ring_start(mac_ring_driver_t ring_handle, uint64_t gen_number)
{
	struct oce_rq *rx_ring = (struct oce_rq *)ring_handle;
	struct oce_dev *dev = rx_ring->parent;

	mutex_enter(&rx_ring->rx_lock);
	rx_ring->gen_number = gen_number;
	mac_ring_intr_set(rx_ring->handle,
	    dev->htable[rx_ring->cq->eq->idx]);
	(void) oce_start_rq(rx_ring);
	mutex_exit(&rx_ring->rx_lock);

	return (0);
}

void
oce_ring_stop(mac_ring_driver_t ring_handle)
{
	struct oce_rq *rx_ring = (struct oce_rq *)ring_handle;

	(void) oce_ring_intr_disable((mac_intr_handle_t)ring_handle);
	mac_ring_intr_set(rx_ring->handle, NULL);
}

mblk_t *
oce_ring_tx(void *ring_handle, mblk_t *mp)
{
	struct oce_wq *wq = ring_handle;
	mblk_t *nxt_pkt;
	mblk_t *rmp = NULL;
	struct oce_dev *dev = wq->parent;

	if (dev->suspended) {
		freemsg(mp);
		return (NULL);
	}
	while (mp != NULL) {
		/* Save the Pointer since mp will be freed in case of copy */
		nxt_pkt = mp->b_next;
		mp->b_next = NULL;
		/* Hardcode wq since we have only one */
		rmp = oce_send_packet(wq, mp);
		if (rmp != NULL) {
			/* restore the chain */
			rmp->b_next = nxt_pkt;
			break;
		}
		mp  = nxt_pkt;
	}

	if (wq->resched) {
		if (atomic_cas_uint(&wq->qmode, OCE_MODE_POLL, OCE_MODE_INTR)
		    == OCE_MODE_POLL) {
			oce_arm_cq(wq->parent, wq->cq->cq_id, 0, B_TRUE);
			wq->last_armed = ddi_get_lbolt();
		}
	}

	return (rmp);
}

mblk_t	*
oce_ring_rx_poll(void *ring_handle, int nbytes)
{
	struct oce_rq *rx_ring = ring_handle;
	mblk_t *mp = NULL;
	struct oce_dev *dev = rx_ring->parent;

	if (dev->suspended || rx_ring == NULL || nbytes == 0)
		return (NULL);

	mp = oce_drain_rq_cq(rx_ring, nbytes, 0);
	return (mp);
}

int
oce_group_addmac(void *group_handle, const uint8_t *mac)
{
	oce_group_t *grp = group_handle;
	struct oce_dev *dev;
	int pmac_index = 0;
	int ret;

	dev = grp->parent;

	oce_log(dev, CE_NOTE, MOD_CONFIG,
	    "oce_group_addmac , grp_type = %d, grp_num = %d, "
	    "mac = %x:%x:%x:%x:%x:%x",
	    grp->grp_type, grp->grp_num, mac[0], mac[1], mac[2],
	    mac[3], mac[4], mac[5]);

	while ((pmac_index < OCE_MAX_PMAC_PER_GRP) &&
	    (grp->pmac_ids[pmac_index] != INVALID_PMAC_ID)) {
		pmac_index++;
	}
	if ((pmac_index >= OCE_MAX_PMAC_PER_GRP) ||
	    (grp->num_pmac >= OCE_MAX_PMAC_PER_GRP) ||
	    (dev->num_pmac >= OCE_MAX_SMAC_PER_DEV)) {
		oce_log(dev, CE_NOTE, MOD_CONFIG,
		    "PMAC exceeding limits, num_pmac=%d, num_pmac=%d, index=%d",
		    grp->num_pmac, dev->num_pmac, pmac_index);
		return (ENOSPC);
	}

	/* Add the New MAC */
	ret = oce_add_mac(dev, grp->if_id, mac, &grp->pmac_ids[pmac_index],
	    MBX_BOOTSTRAP);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "MAC addition failed ");
		return (EIO);
	}

	grp->num_pmac++;
	dev->num_pmac++;
	bcopy(mac, &grp->mac_addr[pmac_index], ETHERADDRL);
	return (0);
}


int
oce_group_remmac(void *group_handle, const uint8_t *mac)
{
	oce_group_t *grp = group_handle;
	struct oce_dev *dev;
	int ret;
	int pmac_index = 0;

	dev = grp->parent;

	while ((pmac_index < OCE_MAX_PMAC_PER_GRP)) {
		if (bcmp(mac, &grp->mac_addr[pmac_index], ETHERADDRL) == 0) {
			break;
		}
		pmac_index++;
	}

	if (pmac_index >= OCE_MAX_PMAC_PER_GRP) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Could not find the MAC: %x:%x:%x:%x:%x:%x",
		    mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
		return (EINVAL);
	}

	/* Delete previous one */
	ret = oce_del_mac(dev, grp->if_id, &grp->pmac_ids[pmac_index],
	    MBX_BOOTSTRAP);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Failed to delete MAC: %x:%x:%x:%x:%x:%x, ret=0x%x",
		    mac[0], mac[1], mac[2], mac[3], mac[4], mac[5], ret);
		return (EIO);
	}

	grp->num_pmac--;
	dev->num_pmac--;
	grp->pmac_ids[pmac_index] = INVALID_PMAC_ID;
	bzero(&grp->mac_addr[pmac_index], ETHERADDRL);
	return (0);
}


int
oce_m_start_group(mac_group_driver_t group_h)
{
	oce_group_t *grp = (oce_group_t *)group_h;
	int ret;
	mutex_enter(&grp->grp_lock);
	grp->state |= GROUP_MAC_STARTED;
	ret = oce_start_group(grp, B_TRUE);
	if (ret != DDI_SUCCESS) {
		grp->state &= ~GROUP_MAC_STARTED;
	}
	mutex_exit(&grp->grp_lock);
	return (ret);
}


void
oce_m_stop_group(mac_group_driver_t group_h)
{
	oce_group_t *grp = (oce_group_t *)group_h;
	mutex_enter(&grp->grp_lock);
	oce_stop_group(grp, B_TRUE);
	grp->state &= ~GROUP_MAC_STARTED;
	mutex_exit(&grp->grp_lock);
}


int
oce_start_group(oce_group_t *grp, boolean_t alloc_buffer)
{
	struct oce_dev *dev = grp->parent;
	int qidx;
	int max_frame_sz;

	max_frame_sz = dev->mtu + sizeof (struct ether_vlan_header) + VTAG_SIZE;
	/* allocate Rx buffers */
	if (alloc_buffer && !(grp->state & GROUP_INIT)) {
		for (qidx = 0; qidx < grp->num_rings; qidx++) {
			if (oce_rq_init(dev, grp->ring[qidx].rx,
			    dev->rx_ring_size, dev->rq_frag_size,
			    max_frame_sz) != DDI_SUCCESS) {
				goto group_fail;
			}
		}
		grp->state |= GROUP_INIT;
	}

	if (grp->state & GROUP_MAC_STARTED) {

		if (oce_create_group(dev, grp, MBX_ASYNC_MQ) != DDI_SUCCESS) {
			goto group_fail;
		}
		oce_log(dev, CE_NOTE, MOD_CONFIG,
		    "group %d started", grp->grp_num);
	}
	return (DDI_SUCCESS);

group_fail:
	oce_log(dev, CE_WARN, MOD_CONFIG,
	    "Failed to setup group %x", grp->grp_num);
	return (DDI_FAILURE);
}

static int
oce_check_pending(oce_group_t *grp)
{

	struct oce_dev *dev = grp->parent;
	int qidx;
	int pending = 0;
	for (qidx = 0; qidx < grp->num_rings; qidx++) {
		pending = oce_rx_pending(dev, grp->ring[qidx].rx,
		    DEFAULT_DRAIN_TIME);
		if (pending) {
			break;
		}
	}
	return (pending);
}

void
oce_stop_group(oce_group_t *grp, boolean_t free_buffer)
{
	struct oce_dev *dev = grp->parent;
	struct oce_rq *rq;
	int qidx;
	int pending = 0;

	if (grp->state & GROUP_MAC_STARTED) {
		oce_delete_group(dev, grp);
		/* wait for receive buffers to be freed by stack */
		while (oce_check_pending(grp) != 0) {
			oce_log(dev, CE_NOTE, MOD_CONFIG, "%s",
			    "Wait if buffers are pending with stack\n");
			if (pending++ >= 2) {
				break;
			}
		}
	}

	/* free Rx buffers */
	if (free_buffer && (grp->state & GROUP_INIT)) {
		for (qidx = 0; qidx < grp->num_rings; qidx++) {
			rq = grp->ring[qidx].rx;
			mutex_enter(&rq->rq_fini_lock);
			if (rq->pending == 0) {
				if (rq->qstate == QDELETED) {
					oce_rq_fini(dev, rq);
				}
			} else {
				rq->qstate = QFINI_PENDING;
			}
			mutex_exit(&rq->rq_fini_lock);
		}
		grp->state &= ~GROUP_INIT;
	}
	oce_log(dev, CE_NOTE, MOD_CONFIG, "group %d stopped", grp->grp_num);
}


/* Internally halt the rings on group basis (eg. IRM) */
void
oce_suspend_group_rings(oce_group_t *grp)
{
	int qidx;

	if (grp->state & GROUP_MAC_STARTED) {
		grp->state |= GROUP_SUSPEND;
		for (qidx = 0; qidx < grp->num_rings; qidx++) {
			(void) oce_ring_intr_disable((mac_intr_handle_t)
			    grp->ring[qidx].rx);
			mac_ring_intr_set(grp->ring[qidx].rx->handle, NULL);
		}
	}
}


/* Internally resume the rings on group basis (Eg IRM) */
int
oce_resume_group_rings(oce_group_t *grp)
{
	struct oce_dev *dev = grp->parent;
	int qidx, pmac_idx, ret = DDI_SUCCESS;

	if (grp->state & GROUP_MAC_STARTED) {

		if (grp->grp_num == 0) {
			if (dev->num_mca > OCE_MAX_MCA) {
				ret = oce_set_multicast_table(dev, dev->if_id,
				    &dev->multi_cast[0], OCE_MAX_MCA, B_TRUE,
				    MBX_BOOTSTRAP);
			} else {
				ret = oce_set_multicast_table(dev, dev->if_id,
				    &dev->multi_cast[0], dev->num_mca, B_FALSE,
				    MBX_BOOTSTRAP);
			}
			if (ret != 0) {
				oce_log(dev, CE_WARN, MOD_CONFIG,
				    "set mcast failed 0x%x", ret);
				return (ret);
			}
		}

		/* Add the group based MACs */
		for (pmac_idx = 0; pmac_idx < grp->num_pmac; pmac_idx++) {
			if (grp->pmac_ids[pmac_idx] != INVALID_PMAC_ID) {
				ret = oce_add_mac(dev, grp->if_id,
				    (uint8_t *)&grp->mac_addr[pmac_idx],
				    &grp->pmac_ids[pmac_idx], MBX_BOOTSTRAP);
				if (ret != DDI_SUCCESS) {
					oce_log(dev, CE_WARN, MOD_CONFIG,
					    "MAC addition failed grp = %p, "
					    "idx = %d, ret = %x",
					    (void *)grp, pmac_idx, ret);
					return (ret);
				}
			}
		}

		for (qidx = 0; qidx < grp->num_rings; qidx++) {
			mac_ring_intr_set(grp->ring[qidx].rx->handle,
			    dev->htable[grp->ring[qidx].rx->cq->eq->idx]);
			(void) oce_start_rq(grp->ring[qidx].rx);
		}
		grp->state &= ~GROUP_SUSPEND;
	}
	return (ret);
}


int
oce_ring_rx_stat(mac_ring_driver_t ring_handle, uint_t type, uint64_t *stat)
{
	struct oce_rq *rx_ring = (struct oce_rq *)ring_handle;
	struct oce_dev *dev = rx_ring->parent;

	if (dev->suspended || !(dev->state & STATE_MAC_STARTED)) {
		return (ECANCELED);
	}

	switch (type) {
	case MAC_STAT_RBYTES:
		*stat = rx_ring->stat_bytes;
		break;

	case MAC_STAT_IPACKETS:
		*stat = rx_ring->stat_pkts;
		break;

	default:
		*stat = 0;
		return (ENOTSUP);
	}

	return (DDI_SUCCESS);
}

int
oce_ring_tx_stat(mac_ring_driver_t ring_handle, uint_t type, uint64_t *stat)
{
	struct oce_wq *tx_ring = (struct oce_wq *)ring_handle;
	struct oce_dev *dev = tx_ring->parent;

	if (dev->suspended || !(dev->state & STATE_MAC_STARTED)) {
		return (ECANCELED);
	}

	switch (type) {
	case MAC_STAT_OBYTES:
		*stat = tx_ring->stat_bytes;
	break;

	case MAC_STAT_OPACKETS:
		*stat = tx_ring->stat_pkts;
		break;

	default:
		*stat = 0;
		return (ENOTSUP);
	}

	return (DDI_SUCCESS);
}

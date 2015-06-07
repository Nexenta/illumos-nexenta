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
 * Source file containing the implementation of the MailBox queue handling
 * and related helper functions
 */

#include <oce_impl.h>

int pow10[5] = {
	0,
	10,
	100,
	1000,
	10000
};

static void oce_process_link_event(struct oce_dev *dev,
    struct oce_async_cqe_link_state *acqe);
static void oce_async_grp5_qos_speed_process(struct oce_dev *dev,
    struct oce_async_event_grp5_qos_link_speed *acqe);
static void oce_async_grp5_pvid_state(struct oce_dev *dev,
    struct oce_async_event_grp5_pvid_state *acqe);
static void oce_async_grp5_cos_priority(struct oce_dev *dev,
    struct oce_async_event_grp5_cos_priority *acqe);
void oce_process_grp5_event(struct oce_dev *dev,
    struct oce_mq_cqe *cqe, uint8_t event_type);
static void oce_process_mq_compl(struct oce_dev *dev,
    struct oce_mq_cqe *cqe);
static void oce_process_async_events(struct oce_dev *dev,
    struct oce_mq_cqe *cqe);


static void
oce_process_debug_event(struct oce_dev *dev,
    struct async_event_qnq *acqe, uint8_t event_type)
{
	oce_log(dev, CE_NOTE, MOD_CONFIG,
	    "Debug Event: type = %d, enabled = %d, tag = 0x%x",
	    acqe->trailer.u0.bits.event_type, acqe->enabled, acqe->vlan_tag);

	if (event_type == ASYNC_DEBUG_EVENT_TYPE_QNQ) {
		dev->QnQ_queried = 1;
		dev->QnQ_valid = acqe->enabled;
		dev->QnQ_tag = LE_16(acqe->vlan_tag);

		if (!dev->QnQ_valid) {
			dev->QnQ_tag = 0;
		}
	}
}

static void
oce_process_link_event(struct oce_dev *dev,
    struct oce_async_cqe_link_state *acqe)
{
	link_state_t link_status;

	link_status = ((acqe->link_status & ~ASYNC_EVENT_LOGICAL) ==
	    ASYNC_EVENT_LINK_UP) ? LINK_STATE_UP: LINK_STATE_DOWN;

	/* store the link status */
	dev->link_status = link_status;

	dev->link_speed = (acqe->qos_link_speed > 0) ?
	    LE_16(acqe->qos_link_speed) * 10 : pow10[acqe->speed];
	dev->link_duplex = acqe->duplex;

	mac_link_update(dev->mac_handle, link_status);
	oce_log(dev, CE_NOTE, MOD_CONFIG, " Link Event"
	    "Link Status %d Link Speed %d Link Duplex %d\n",
	    dev->link_status, dev->link_speed, dev->link_duplex);
}

static void
oce_async_grp5_qos_speed_process(struct oce_dev *dev,
    struct oce_async_event_grp5_qos_link_speed *acqe)
{

	if (acqe->physical_port == dev->port_id) {
		dev->link_speed = LE_16(acqe->qos_link_speed) * 10;
	}
	oce_log(dev, CE_NOTE, MOD_CONFIG, "GRP5 QOS_SPEED EVENT"
	    "Physical Port : %d QOS_SPEED %d\n", acqe->physical_port,
	    acqe->qos_link_speed);
}

static void
oce_async_grp5_pvid_state(struct oce_dev *dev,
    struct oce_async_event_grp5_pvid_state *acqe)
{

	if (acqe->enabled) {
		dev->pvid = BE_16(acqe->tag);
	} else {
		dev->pvid = 0;
	}
	oce_log(dev, CE_NOTE, MOD_CONFIG, "GRP5 PVID EVENT"
	    "PVID Configured : 0x%x\n", dev->pvid);
}

static void
oce_async_grp5_cos_priority(struct oce_dev *dev,
	struct oce_async_event_grp5_cos_priority *acqe)
{
	if (acqe->valid) {
		dev->vlan_prio_bmap = acqe->available_priority_bmap;
		dev->reco_priority &= acqe->reco_default_priority;
	}

}

void
oce_process_grp5_event(struct oce_dev *dev,
	struct oce_mq_cqe *cqe, uint8_t event_type)
{
	switch (event_type) {
	case ASYNC_EVENT_QOS_SPEED:
		oce_async_grp5_qos_speed_process(dev,
		    (struct oce_async_event_grp5_qos_link_speed *)cqe);
		break;
	case ASYNC_EVENT_COS_PRIORITY:
		oce_async_grp5_cos_priority(dev,
		    (struct oce_async_event_grp5_cos_priority *)cqe);
		break;
	case ASYNC_EVENT_PVID_STATE:
		oce_async_grp5_pvid_state(dev,
		    (struct oce_async_event_grp5_pvid_state *)cqe);
		break;
	default:
		break;
	}

}
/*
 * function to drain a MCQ and process its CQEs
 *
 * dev - software handle to the device
 * cq - pointer to the cq to drain
 *
 * return the number of CQEs processed
 */
void *
oce_drain_mq_cq(void *arg, int arg2, int arg3)
{
	struct oce_mq_cqe *cqe = NULL;
	uint16_t num_cqe = 0;
	struct oce_mq *mq;
	struct oce_cq  *cq;
	struct oce_dev *dev;
	uint32_t flags = 0;

	_NOTE(ARGUNUSED(arg2));
	_NOTE(ARGUNUSED(arg3));

	/* do while we do not reach a cqe that is not valid */
	mq = (struct oce_mq *)arg;
	cq = mq->cq;
	dev = mq->parent;

	DBUF_SYNC(cq->ring->dbuf, 0, 0, DDI_DMA_SYNC_FORKERNEL);
	cqe = RING_GET_CONSUMER_ITEM_VA(cq->ring, struct oce_mq_cqe);

	while (MQ_CQE_VALID(cqe)) {
		flags = LE_32(cqe->u0.dw[3]);

		if (flags & MQ_CQE_ASYNC_MASK) {
			oce_process_async_events(dev, cqe);
		} else if (flags & MQ_CQE_COMPLETED_MASK) {
			oce_process_mq_compl(dev, cqe);
			atomic_add_32(&mq->mq_free, 1);
		}
		MQ_CQE_INVALIDATE(cqe);
		RING_GET(cq->ring, 1);
		cqe = RING_GET_CONSUMER_ITEM_VA(cq->ring, struct oce_mq_cqe);
		num_cqe++;
	} /* for all valid CQE */
	DBUF_SYNC(cq->ring->dbuf, 0, 0, DDI_DMA_SYNC_FORDEV);
	oce_arm_cq(dev, cq->cq_id, num_cqe, B_TRUE);
	return (NULL);
} /* oce_drain_mq_cq */

int
oce_start_mq(struct oce_mq *mq)
{
	oce_arm_cq(mq->parent, mq->cq->cq_id, 0, B_TRUE);
	return (0);
}


void
oce_clean_mq(struct oce_mq *mq)
{
	while (mq->mq_free != mq->cfg.q_len) {
		(void) oce_drain_mq_cq(mq, 0, 0);
	}
	/* Drain the Event queue now */
	oce_drain_eq(mq->cq->eq);
}

/* function to issue mbox on mq */
int
oce_issue_mq_mbox(struct  oce_dev *dev, struct  oce_mbx *mbx)
{
	struct oce_mq *mq;
	struct oce_mbx *mqe;
	struct oce_mbx_ctx *mbctx;
	uint32_t mqdb = 0;

	mq = dev->mq;
	mbctx = (struct oce_mbx_ctx *)
	    (uintptr_t)ADDR_64(mbx->tag[1], mbx->tag[0]);

	mutex_enter(&mq->lock);

	if (oce_atomic_reserve(&mq->mq_free, 1) < 0) {
		mutex_exit(&mq->lock);
		oce_log(dev, CE_NOTE, MOD_CONFIG,
		    "MQ Entries Free(%d) Retry the command Later",
		    mq->mq_free);
		return (MBX_QUEUE_FULL);
	}

	mqe = RING_GET_PRODUCER_ITEM_VA(mq->ring, struct oce_mbx);
	/* save the mqe pointer in ctx required to copy resp back */
	mbctx->mqe = mqe;
	/* enqueue the command */
	bcopy(mbx, mqe, sizeof (struct oce_mbx));
	RING_PUT(mq->ring, 1);
	/* ring mq doorbell num posted is 1  */
	mqdb = (1 << 16) | mq->mq_id;
	OCE_DB_WRITE32(dev, PD_MQ_DB, mqdb);
	mutex_exit(&mq->lock);
	return (MBX_SUCCESS);
}

void
oce_process_mq_compl(struct oce_dev *dev, struct oce_mq_cqe *cqe)
{
	struct oce_mbx_ctx *mbctx;
	struct oce_mbx *mbx;

	_NOTE(ARGUNUSED(dev));

	/* retrieve the context pointer */
	mbctx = (struct oce_mbx_ctx *)(uintptr_t)ADDR_64(cqe->u0.s.mq_tag[1],
	    cqe->u0.s.mq_tag[0]);

	if (mbctx == NULL) {
		return;
	}
	mbx = mbctx->mbx;

	mbctx->compl_status = LE_32(cqe->u0.dw[0]);
	if (mbctx->compl_status == 0) {
		bcopy(mbctx->mqe, mbx, sizeof (struct oce_mbx));
	}
	mutex_enter(&mbctx->cv_lock);
	mbctx->mbx_status = MBX_COMPLETED;
	cv_signal(&mbctx->cond_var);
	mutex_exit(&mbctx->cv_lock);

}

static void
oce_process_async_events(struct oce_dev *dev, struct oce_mq_cqe *cqe)
{
	struct oce_async_event_trailer trailer;

	trailer.u0.code = LE_32(cqe->u0.dw[3]);

	switch (trailer.u0.bits.event_code) {
	case ASYNC_EVENT_CODE_DEBUG:
		oce_process_debug_event(dev, (struct async_event_qnq *)cqe,
		    trailer.u0.bits.event_type);
		break;
	case ASYNC_EVENT_CODE_LINK_STATE:
		oce_process_link_event(dev,
		    (struct oce_async_cqe_link_state *)cqe);
		break;
	case ASYNC_EVENT_CODE_GRP_5:
		oce_process_grp5_event(dev, cqe, trailer.u0.bits.event_type);
		break;

	default:
		break;
	}
}

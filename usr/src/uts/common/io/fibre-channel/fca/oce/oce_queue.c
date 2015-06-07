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
 * Source file containing Queue handling functions
 *
 */

#include <oce_impl.h>

int oce_destroy_q(struct oce_dev  *oce, struct oce_mbx  *mbx, size_t req_size,
    enum qtype  qtype, uint32_t mode);
/* MAil box Queue functions */
struct oce_mq *
oce_mq_create_ext_v0(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len);
struct oce_mq *
oce_mq_create_ext_v1(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len);
struct oce_mq *
oce_mq_create(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len);

/* event queue handling */
int
oce_eq_create(struct oce_dev *dev, struct oce_eq *, uint32_t q_len,
	uint32_t item_size, uint32_t eq_delay, uint32_t mode);

/* completion queue handling */
struct oce_cq *
oce_cq_create(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len,
    uint32_t item_size, boolean_t sol_event, boolean_t is_eventable,
    boolean_t nodelay, uint32_t ncoalesce, boolean_t armed, uint32_t mode);

struct oce_cq *
oce_cq_create_v0(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len,
	uint32_t item_size, boolean_t sol_event, boolean_t is_eventable,
	boolean_t nodelay, uint32_t ncoalesce, boolean_t armed, uint32_t mode);

struct oce_cq *
oce_cq_create_v2(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len,
	uint32_t item_size, boolean_t sol_event, boolean_t is_eventable,
	boolean_t nodelay, uint32_t ncoalesce, boolean_t armed, uint32_t mode);

/* Tx  WQ functions */
int oce_wq_init(struct oce_dev *dev, struct oce_wq *, uint32_t q_len,
    int wq_type);
static void oce_wq_fini(struct oce_dev *dev, struct oce_wq *wq);
static int oce_wq_create(struct oce_wq *wq, struct oce_eq *eq, uint32_t mode);
static void oce_wq_del(struct oce_dev *dev, struct oce_wq *wq, uint32_t mode);
/* Rx Queue functions */
static int oce_rq_create(struct oce_rq *rq, uint32_t if_id, struct oce_eq *eq,
    uint32_t mode);
static void oce_rq_del(struct oce_dev *dev, struct oce_rq *rq, uint32_t mode);

/*
 * function to create an event queue
 *
 * dev - software handle to the device
 * eqcfg - pointer to a config structure containg the eq parameters
 *
 * return pointer to EQ; NULL on failure
 */
int oce_eq_create(struct oce_dev *dev, struct oce_eq *eq,
	uint32_t q_len, uint32_t item_size, uint32_t eq_delay, uint32_t mode)
{
	struct oce_mbx mbx;
	struct mbx_create_common_eq *fwcmd;
	int ret = 0;

	if (eq == NULL) {
		return (DDI_FAILURE);
	}
	mutex_enter(&eq->lock);
	bzero(&mbx, sizeof (struct oce_mbx));
	/* allocate mbx */
	fwcmd = (struct mbx_create_common_eq *)&mbx.payload;

	eq->ring = oce_create_ring_buffer(dev, q_len,
	    item_size, DDI_DMA_CONSISTENT|DDI_DMA_RDWR);

	if (eq->ring == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "EQ ring alloc failed:0x%p", (void *)eq->ring);
		return (DDI_FAILURE);
	}

	mbx_common_req_hdr_init(&fwcmd->hdr, 0, 0,
	    MBX_SUBSYSTEM_COMMON,
	    OPCODE_CREATE_COMMON_EQ, MBX_TIMEOUT_SEC,
	    sizeof (struct mbx_create_common_eq), 0);

	fwcmd->params.req.num_pages = eq->ring->dbuf.num_pages;
	oce_page_list(&eq->ring->dbuf, &fwcmd->params.req.pages[0],
	    eq->ring->dbuf.num_pages);

	/* dw 0 */
	fwcmd->params.req.eq_ctx.size = (item_size == 4) ? 0 : 1;
	fwcmd->params.req.eq_ctx.valid = 1;
	/* dw 1 */
	fwcmd->params.req.eq_ctx.armed = 0;
	fwcmd->params.req.eq_ctx.pd = 0;
	fwcmd->params.req.eq_ctx.count = OCE_LOG2(q_len/256);

	/* dw 2 */
	fwcmd->params.req.eq_ctx.nodelay  = 0;
	fwcmd->params.req.eq_ctx.phase = 0;
	/* todo: calculate multiplier from max min and cur */
	fwcmd->params.req.eq_ctx.delay_mult = eq_delay;

	/* fill rest of mbx */
	mbx.u0.s.embedded = 1;
	mbx.payload_length = sizeof (struct mbx_create_common_eq);
	DW_SWAP(u32ptr(&mbx), mbx.payload_length + OCE_BMBX_RHDR_SZ);

	/* now post the command */
	ret = oce_issue_mbox_cmd(dev, &mbx, MBX_TIMEOUT_SEC, mode);

	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "EQ create failed: 0x%x", ret);
		destroy_ring_buffer(dev, eq->ring);
		return (DDI_FAILURE);
	}

	/* interpret the response */
	eq->eq_id = LE_16(fwcmd->params.rsp.eq_id);
	eq->parent = (void *)dev;
	atomic_inc_32(&dev->neqs);
	eq->qstate = QCREATED;
	mutex_exit(&eq->lock);
	oce_log(dev, CE_NOTE, MOD_CONFIG,
	    "EQ created, eq=0x%p eq_id=0x%x", (void *)eq, eq->eq_id);
	/* Save the eq pointer */
	return (DDI_SUCCESS);
} /* oce_eq_create */

/*
 * function to delete an event queue
 *
 * dev - software handle to the device
 * eq - handle to the eq to be deleted
 *
 * return 0=>success, failure otherwise
 */
void
oce_eq_del(struct oce_dev *dev, struct oce_eq *eq, uint32_t mode)
{
	struct oce_mbx mbx;
	struct mbx_destroy_common_eq *fwcmd;

	mutex_enter(&eq->lock);
	eq->qstate = QDELETED;
	bzero(&mbx, sizeof (struct oce_mbx));

	/* drain the residual events */
	oce_drain_eq(eq);

	/* destroy the ring */
	destroy_ring_buffer(dev, eq->ring);
	eq->ring = NULL;

	/* send a command to delete the EQ */
	fwcmd = (struct mbx_destroy_common_eq *)&mbx.payload;
	fwcmd->params.req.id = eq->eq_id;
	(void) oce_destroy_q(dev, &mbx,
	    sizeof (struct mbx_destroy_common_eq),
	    QTYPE_EQ, mode);
	atomic_dec_32(&dev->neqs);
	mutex_exit(&eq->lock);
}

/*
 * function to create a V0 completion queue
 *
 * dev - software handle to the device
 * eq - optional eq to be associated with to the cq
 * cqcfg - configuration for this queue
 *
 * return pointer to the cq created. NULL on failure
 */
struct oce_cq *
oce_cq_create_v0(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len,
    uint32_t item_size, boolean_t sol_event, boolean_t is_eventable,
    boolean_t nodelay, uint32_t ncoalesce, boolean_t armed, uint32_t mode)
{
	struct oce_cq *cq = NULL;
	struct oce_mbx mbx;
	struct mbx_create_common_cq_v0 *fwcmd;
	int ret = 0;

	/* create cq */
	cq = kmem_zalloc(sizeof (struct oce_cq), KM_NOSLEEP);
	if (cq == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "CQ allocation failed");
		return (NULL);
	}

	/* create the ring buffer for this queue */
	cq->ring = oce_create_ring_buffer(dev, q_len,
	    item_size, DDI_DMA_CONSISTENT|DDI_DMA_RDWR);
	if (cq->ring == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "CQ ring alloc failed:0x%p",
		    (void *)cq->ring);
		kmem_free(cq, sizeof (struct oce_cq));
		return (NULL);
	}
	/* initialize mailbox */
	bzero(&mbx, sizeof (struct oce_mbx));
	fwcmd = (struct mbx_create_common_cq_v0 *)&mbx.payload;

	/* fill the command header */
	mbx_common_req_hdr_init(&fwcmd->hdr, 0, 0,
	    MBX_SUBSYSTEM_COMMON,
	    OPCODE_CREATE_COMMON_CQ, MBX_TIMEOUT_SEC,
	    sizeof (struct mbx_create_common_cq_v0), 0);

	/* fill command context */
	/* dw0 */
	fwcmd->params.req.cq_ctx.eventable = is_eventable;
	fwcmd->params.req.cq_ctx.sol_event = sol_event;
	fwcmd->params.req.cq_ctx.valid = 1;
	fwcmd->params.req.cq_ctx.count = OCE_LOG2(q_len/256);
	fwcmd->params.req.cq_ctx.nodelay = nodelay;
	fwcmd->params.req.cq_ctx.coalesce_wm = ncoalesce;

	/* dw1 */
	fwcmd->params.req.cq_ctx.armed = armed;
	fwcmd->params.req.cq_ctx.eq_id = eq->eq_id;
	fwcmd->params.req.cq_ctx.pd = 0;

	/* fill the rest of the command */
	fwcmd->params.req.num_pages = cq->ring->dbuf.num_pages;
	oce_page_list(&cq->ring->dbuf, &fwcmd->params.req.pages[0],
	    cq->ring->dbuf.num_pages);

	/* fill rest of mbx */
	mbx.u0.s.embedded = 1;
	mbx.payload_length = sizeof (struct mbx_create_common_cq_v0);
	DW_SWAP(u32ptr(&mbx), mbx.payload_length + OCE_BMBX_RHDR_SZ);

	/* now send the mail box */
	ret = oce_issue_mbox_cmd(dev, &mbx, MBX_TIMEOUT_SEC, mode);

	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "CQ create failed: 0x%x", ret);
		destroy_ring_buffer(dev, cq->ring);
		kmem_free(cq, sizeof (struct oce_cq));
		return (NULL);
	}

	cq->parent = dev;
	cq->eq = eq; /* eq array index */
	cq->cq_cfg.q_len = q_len;

	/* interpret the response */
	cq->cq_id = LE_16(fwcmd->params.rsp.cq_id);
	dev->cq[cq->cq_id % OCE_MAX_CQ] = cq;
	cq->qstate = QCREATED;
	atomic_inc_32(&eq->ref_count);
	return (cq);
} /* oce_cq_create_v0 */

/*
 * function to create a V2 completion queue
 *
 * dev - software handle to the device
 * eq - optional eq to be associated with to the cq
 * cqcfg - configuration for this queue
 *
 * return pointer to the cq created. NULL on failure
 */
struct oce_cq *
oce_cq_create_v2(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len,
    uint32_t item_size, boolean_t sol_event, boolean_t is_eventable,
    boolean_t nodelay, uint32_t ncoalesce, boolean_t armed, uint32_t mode)
{
	struct oce_cq *cq = NULL;
	struct oce_mbx mbx;
	struct mbx_create_common_cq_v2 *fwcmd;
	int ret = 0;

	_NOTE(ARGUNUSED(sol_event));
	_NOTE(ARGUNUSED(ncoalesce));
	/* create cq */
	cq = kmem_zalloc(sizeof (struct oce_cq), KM_NOSLEEP);
	if (cq == NULL) {
		oce_log(dev, CE_NOTE, MOD_CONFIG, "%s",
		    "CQ allocation failed");
		return (NULL);
	}

	/* create the ring buffer for this queue */
	cq->ring = oce_create_ring_buffer(dev, q_len,
	    item_size, DDI_DMA_CONSISTENT | DDI_DMA_RDWR);
	if (cq->ring == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "CQ ring alloc failed:0x%p",
		    (void *)cq->ring);
		kmem_free(cq, sizeof (struct oce_cq));
		return (NULL);
	}
	/* initialize mailbox */
	bzero(&mbx, sizeof (struct oce_mbx));
	fwcmd = (struct mbx_create_common_cq_v2 *)&mbx.payload;

	/* fill the command header */
	mbx_common_req_hdr_init(&fwcmd->hdr, 0, 0,
	    MBX_SUBSYSTEM_COMMON,
	    OPCODE_CREATE_COMMON_CQ, MBX_TIMEOUT_SEC,
	    sizeof (struct mbx_create_common_cq_v2), 2);

	/* fill command context */
	/* dw0 */
	fwcmd->params.req.cq_ctx.eventable = is_eventable;
	fwcmd->params.req.cq_ctx.valid = 1;
	fwcmd->params.req.cq_ctx.count = 3;
	fwcmd->params.req.cq_ctx.nodelay = nodelay;
	fwcmd->params.req.cq_ctx.coalesce_wm = 0;

	/* dw1 */
	fwcmd->params.req.cq_ctx.armed = armed;
	fwcmd->params.req.cq_ctx.eq_id = eq->eq_id;
	fwcmd->params.req.cq_ctx.cqe_count = q_len;

	fwcmd->params.req.page_size = 1;
	/* fill the rest of the command */
	fwcmd->params.req.num_pages = cq->ring->dbuf.num_pages;
	oce_page_list(&cq->ring->dbuf, &fwcmd->params.req.pages[0],
	    cq->ring->dbuf.num_pages);

	/* fill rest of mbx */
	mbx.u0.s.embedded = 1;
	mbx.payload_length = sizeof (struct mbx_create_common_cq_v2);
	DW_SWAP(u32ptr(&mbx), mbx.payload_length + OCE_BMBX_RHDR_SZ);

	/* now send the mail box */
	ret = oce_issue_mbox_cmd(dev, &mbx, MBX_TIMEOUT_SEC, mode);

	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "CQ create failed: 0x%x", ret);
		destroy_ring_buffer(dev, cq->ring);
		kmem_free(cq, sizeof (struct oce_cq));
		return (NULL);
	}

	cq->parent = dev;
	cq->eq = eq; /* eq array index */
	cq->cq_cfg.q_len = q_len;

	/* interpret the response */
	cq->cq_id = LE_16(fwcmd->params.rsp.cq_id);
	dev->cq[cq->cq_id % OCE_MAX_CQ] = cq;
	cq->qstate = QCREATED;
	atomic_inc_32(&eq->ref_count);
	return (cq);
} /* oce_cq_create_v2 */

/*
 * function to create a completion queue
 *
 * dev - software handle to the device
 * eq - optional eq to be associated with to the cq
 * cqcfg - configuration for this queue
 *
 * return pointer to the cq created. NULL on failure
 */
struct oce_cq *
oce_cq_create(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len,
    uint32_t item_size, boolean_t sol_event, boolean_t is_eventable,
    boolean_t nodelay, uint32_t ncoalesce, boolean_t armed, uint32_t mode)
{
	struct oce_cq *cq = NULL;
	if (LANCER_CHIP(dev))
		cq = oce_cq_create_v2(dev, eq, q_len, item_size, sol_event,
		    is_eventable, nodelay, ncoalesce, armed, mode);
	else
		cq = oce_cq_create_v0(dev, eq, q_len, item_size, sol_event,
		    is_eventable, nodelay, ncoalesce, armed, mode);
	return (cq);
}

/*
 * function to delete a completion queue
 *
 * dev - software handle to the device
 * cq - handle to the CQ to delete
 *
 * return none
 */
static void
oce_cq_del(struct oce_dev *dev, struct oce_cq *cq, uint32_t mode)
{
	struct oce_mbx mbx;
	struct mbx_destroy_common_cq *fwcmd;

	/* destroy the ring */
	destroy_ring_buffer(dev, cq->ring);
	cq->ring = NULL;

	bzero(&mbx, sizeof (struct oce_mbx));
	/* send a command to delete the CQ */
	fwcmd = (struct mbx_destroy_common_cq *)&mbx.payload;
	fwcmd->params.req.id = cq->cq_id;
	(void) oce_destroy_q(dev, &mbx,
	    sizeof (struct mbx_destroy_common_cq),
	    QTYPE_CQ, mode);

	/* Reset the handler */
	cq->cq_handler = NULL;
	cq->qstate = QDELETED;
	dev->cq[cq->cq_id % OCE_MAX_CQ] = NULL;
	atomic_dec_32(&cq->eq->ref_count);

	/* release the eq */
	kmem_free(cq, sizeof (struct oce_cq));
} /* oce_cq_del */

/*
 * function to create an MQ
 *
 * dev - software handle to the device
 * eq - the EQ to associate with the MQ for event notification
 * q_len - the number of entries to create in the MQ
 *
 * return pointer to the created MQ, failure otherwise
 */
struct oce_mq *
oce_mq_create(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len)
{
	struct oce_mbx mbx;
	struct mbx_create_common_mq *fwcmd;
	struct oce_mq *mq = NULL;
	int ret = 0;
	struct oce_cq  *cq;

	/* Create the Completion Q */
	cq = oce_cq_create(dev, eq, MCC_CQ_LEN,
	    sizeof (struct oce_mq_cqe),
	    B_FALSE, B_TRUE, B_TRUE, 0, B_FALSE, MBX_BOOTSTRAP);
	if (cq == NULL) {
		return (NULL);
	}


	/* allocate the mq */
	mq = kmem_zalloc(sizeof (struct oce_mq), KM_NOSLEEP);

	if (mq == NULL) {
		goto mq_alloc_fail;
	}

	bzero(&mbx, sizeof (struct oce_mbx));
	/* allocate mbx */
	fwcmd = (struct mbx_create_common_mq *)&mbx.payload;

	/* create the ring buffer for this queue */
	mq->ring = oce_create_ring_buffer(dev, q_len,
	    sizeof (struct oce_mbx), DDI_DMA_CONSISTENT | DDI_DMA_RDWR);
	if (mq->ring == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "Legacy MQ ring alloc failed");
		goto mq_ring_alloc;
	}

	mbx_common_req_hdr_init(&fwcmd->hdr, 0, 0,
	    MBX_SUBSYSTEM_COMMON,
	    OPCODE_CREATE_COMMON_MQ, MBX_TIMEOUT_SEC,
	    sizeof (struct mbx_create_common_mq), 0);

	fwcmd->params.req.num_pages = (uint16_t)mq->ring->dbuf.num_pages;
	oce_page_list(&mq->ring->dbuf, fwcmd->params.req.pages,
	    mq->ring->dbuf.num_pages);
	fwcmd->params.req.context.u0.s.cq_id = cq->cq_id;
	fwcmd->params.req.context.u0.s.ring_size =
	    OCE_LOG2(q_len) + 1;
	fwcmd->params.req.context.u0.s.valid = 1;
	fwcmd->params.req.context.u0.s.fid = dev->fn;

	/* fill rest of mbx */
	mbx.u0.s.embedded = 1;
	mbx.payload_length = sizeof (struct mbx_create_common_mq);
	DW_SWAP(u32ptr(&mbx), mbx.payload_length + OCE_BMBX_RHDR_SZ);

	/* now send the mail box */
	ret = oce_issue_mbox_cmd(dev, &mbx, MBX_TIMEOUT_SEC, MBX_BOOTSTRAP);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Legacy MQ create failed: 0x%x", ret);
		goto mq_fail;
	}

	/* interpret the response */
	mq->mq_id = LE_16(fwcmd->params.rsp.mq_id);
	mq->cq = cq;
	mq->cfg.q_len = (uint8_t)q_len;
	mq->cfg.eqd = 0;

	/* fill rest of the mq */
	mq->parent = dev;

	/* set the MQCQ handlers */
	cq->cq_handler = oce_drain_mq_cq;
	cq->cb_arg = (void *)mq;
	mutex_init(&mq->lock, NULL, MUTEX_DRIVER,
	    DDI_INTR_PRI(dev->intr_pri));
	oce_log(dev, CE_NOTE, MOD_CONFIG,
	    "Legacy MQ CREATED SUCCESSFULLY MQID:%d\n",
	    mq->mq_id);
	return (mq);

mq_fail:
	destroy_ring_buffer(dev, mq->ring);
mq_ring_alloc:
	kmem_free(mq, sizeof (struct oce_mq));
mq_alloc_fail:
	oce_cq_del(dev, cq, MBX_BOOTSTRAP);
	return (NULL);
} /* oce_mq_create */

/*
 * function to create an extended V0 MQ
 *
 * dev - software handle to the device
 * eq - the EQ to associate with the MQ for event notification
 * q_len - the number of entries to create in the MQ
 *
 * return pointer to the created MQ, failure otherwise
 */
struct oce_mq *
oce_mq_create_ext_v0(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len)
{
	struct oce_mbx mbx;
	struct mbx_create_common_mq_ext_v0 *fwcmd;
	struct oce_mq *mq = NULL;
	int ret = 0;
	struct oce_cq  *cq;

	/* Create the Completion Q */
	cq = oce_cq_create(dev, eq, MCC_CQ_LEN,
	    sizeof (struct oce_mq_cqe),
	    B_FALSE, B_TRUE, B_TRUE, 0, B_FALSE, MBX_BOOTSTRAP);
	if (cq == NULL) {
		return (NULL);
	}


	/* allocate the mq */
	mq = kmem_zalloc(sizeof (struct oce_mq), KM_NOSLEEP);

	if (mq == NULL) {
		goto mq_alloc_fail;
	}

	bzero(&mbx, sizeof (struct oce_mbx));
	/* allocate mbx */
	fwcmd = (struct mbx_create_common_mq_ext_v0 *)&mbx.payload;

	/* create the ring buffer for this queue */
	mq->ring = oce_create_ring_buffer(dev, q_len,
	    sizeof (struct oce_mbx), DDI_DMA_CONSISTENT | DDI_DMA_RDWR);
	if (mq->ring == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "MQ EXT ring alloc failed");
		goto mq_ring_alloc;
	}

	mbx_common_req_hdr_init(&fwcmd->hdr, 0, 0,
	    MBX_SUBSYSTEM_COMMON,
	    OPCODE_CREATE_COMMON_MQ_EXT, MBX_TIMEOUT_SEC,
	    sizeof (struct mbx_create_common_mq_ext_v0), 0);

	fwcmd->params.req.num_pages = mq->ring->dbuf.num_pages;
	oce_page_list(&mq->ring->dbuf, fwcmd->params.req.pages,
	    mq->ring->dbuf.num_pages);
	fwcmd->params.req.context.u0.s.cq_id = cq->cq_id;
	fwcmd->params.req.context.u0.s.ring_size =
	    OCE_LOG2(q_len) + 1;
	fwcmd->params.req.context.u0.s.valid = 1;
	fwcmd->params.req.context.u0.s.fid = dev->fn;

	/*  Register to Link State(bit 1)  and Group 5 Events(bit 5) */
	fwcmd->params.req.async_event_bitmap[0] =
	    (1 << ASYNC_EVENT_CODE_LINK_STATE) |
	    (1 << ASYNC_EVENT_CODE_GRP_5) |
	    (1 << ASYNC_EVENT_CODE_DEBUG);

	/* fill rest of mbx */
	mbx.u0.s.embedded = 1;
	mbx.payload_length = sizeof (struct mbx_create_common_mq_ext_v0);
	DW_SWAP(u32ptr(&mbx), mbx.payload_length + OCE_BMBX_RHDR_SZ);

	/* now send the mail box */
	ret = oce_issue_mbox_cmd(dev, &mbx, MBX_TIMEOUT_SEC, MBX_BOOTSTRAP);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Extended MQ create failed: 0x%x", ret);
		goto mq_fail;
	}

	/* interpret the response */
	mq->mq_id = LE_16(fwcmd->params.rsp.mq_id);
	mq->cq = cq;
	mq->cfg.q_len = (uint8_t)q_len;
	mq->cfg.eqd = 0;

	/* fill rest of the mq */
	mq->parent = dev;
	mq->qstate = QCREATED;
	mq->mq_free = mq->cfg.q_len;

	/* reset indicies */
	mq->ring->cidx = 0;
	mq->ring->pidx = 0;

	/* set the MQCQ handlers */
	cq->cq_handler = oce_drain_mq_cq;
	cq->cb_arg = (void *)mq;
	mutex_init(&mq->lock, NULL, MUTEX_DRIVER,
	    DDI_INTR_PRI(dev->intr_pri));
	oce_log(dev, CE_NOTE, MOD_CONFIG,
	    "Ext MQ CREATED SUCCESSFULLY MQID:%d\n", mq->mq_id);
	return (mq);

mq_fail:
	destroy_ring_buffer(dev, mq->ring);
mq_ring_alloc:
	kmem_free(mq, sizeof (struct oce_mq));
mq_alloc_fail:
	oce_cq_del(dev, cq, MBX_BOOTSTRAP);
	return (NULL);
} /* oce_mq_create_ext_v0 */

/*
 * function to create an extended V1 MQ
 *
 * dev - software handle to the device
 * eq - the EQ to associate with the MQ for event notification
 * q_len - the number of entries to create in the MQ
 *
 * return pointer to the created MQ, failure otherwise
 */
struct oce_mq *
oce_mq_create_ext_v1(struct oce_dev *dev, struct oce_eq *eq, uint32_t q_len)
{
	struct oce_mbx mbx;
	struct mbx_create_common_mq_ext_v1 *fwcmd;
	struct oce_mq *mq = NULL;
	int ret = 0;
	struct oce_cq  *cq;

	/* Create the Completion Q */
	cq = oce_cq_create(dev, eq, MCC_CQ_LEN,
	    sizeof (struct oce_mq_cqe),
	    B_FALSE, B_TRUE, B_TRUE, 0, B_FALSE, MBX_BOOTSTRAP);
	if (cq == NULL) {
		return (NULL);
	}


	/* allocate the mq */
	mq = kmem_zalloc(sizeof (struct oce_mq), KM_NOSLEEP);

	if (mq == NULL) {
		goto mq_alloc_fail;
	}

	bzero(&mbx, sizeof (struct oce_mbx));
	/* allocate mbx */
	fwcmd = (struct mbx_create_common_mq_ext_v1 *)&mbx.payload;

	/* create the ring buffer for this queue */
	mq->ring = oce_create_ring_buffer(dev, q_len,
	    sizeof (struct oce_mbx), DDI_DMA_CONSISTENT | DDI_DMA_RDWR);
	if (mq->ring == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "MQ EXT ring alloc failed");
		goto mq_ring_alloc;
	}

	mbx_common_req_hdr_init(&fwcmd->hdr, 0, 0,
	    MBX_SUBSYSTEM_COMMON,
	    OPCODE_CREATE_COMMON_MQ_EXT, MBX_TIMEOUT_SEC,
	    sizeof (struct mbx_create_common_mq_ext_v1), 1);

	fwcmd->params.req.cq_id = cq->cq_id;

	fwcmd->params.req.context.u0.s.ring_size =
	    OCE_LOG2(q_len) + 1;
	fwcmd->params.req.context.u0.s.valid = 1;
	fwcmd->params.req.context.u0.s.async_cq_id = cq->cq_id;
	fwcmd->params.req.context.u0.s.async_cq_valid = 1;

	fwcmd->params.req.num_pages = mq->ring->dbuf.num_pages;
	oce_page_list(&mq->ring->dbuf, fwcmd->params.req.pages,
	    mq->ring->dbuf.num_pages);

	/*  Register to Link State(bit 1)  and Group 5 Events(bit 5) */
	fwcmd->params.req.async_event_bitmap[0] =
	    (1 << ASYNC_EVENT_CODE_LINK_STATE) |
	    (1 << ASYNC_EVENT_CODE_GRP_5) |
	    (1 << ASYNC_EVENT_CODE_DEBUG);

	/* fill rest of mbx */
	mbx.u0.s.embedded = 1;
	mbx.payload_length = sizeof (struct mbx_create_common_mq_ext_v1);
	DW_SWAP(u32ptr(&mbx), mbx.payload_length + OCE_BMBX_RHDR_SZ);

	/* now send the mail box */
	ret = oce_issue_mbox_cmd(dev, &mbx, MBX_TIMEOUT_SEC, MBX_BOOTSTRAP);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Extended MQ create failed: 0x%x", ret);
		goto mq_fail;
	}

	/* interpret the response */
	mq->mq_id = LE_16(fwcmd->params.rsp.mq_id);
	mq->cq = cq;
	mq->cfg.q_len = (uint8_t)q_len;
	mq->cfg.eqd = 0;

	/* fill rest of the mq */
	mq->parent = dev;
	mq->qstate = QCREATED;
	mq->mq_free = mq->cfg.q_len;

	/* reset indicies */
	mq->ring->cidx = 0;
	mq->ring->pidx = 0;

	/* set the MQCQ handlers */
	cq->cq_handler = oce_drain_mq_cq;
	cq->cb_arg = (void *)mq;
	mutex_init(&mq->lock, NULL, MUTEX_DRIVER,
	    DDI_INTR_PRI(dev->intr_pri));
	oce_log(dev, CE_NOTE, MOD_CONFIG,
	    "Ext MQ CREATED SUCCESSFULLY MQID:%d\n", mq->mq_id);
	return (mq);

mq_fail:
	destroy_ring_buffer(dev, mq->ring);
mq_ring_alloc:
	kmem_free(mq, sizeof (struct oce_mq));
mq_alloc_fail:
	oce_cq_del(dev, cq, MBX_BOOTSTRAP);
	return (NULL);
} /* oce_mq_create_ext_v0 */

/*
 * function to delete an MQ
 *
 * dev - software handle to the device
 * mq - pointer to the MQ to delete
 *
 * return none
 */
static void
oce_mq_del(struct oce_dev *dev, struct oce_mq *mq)
{
	struct oce_mbx mbx;
	struct mbx_destroy_common_mq *fwcmd;

	/* destroy the ring */
	destroy_ring_buffer(dev, mq->ring);
	mq->ring = NULL;
	bzero(&mbx, sizeof (struct oce_mbx));
	fwcmd = (struct mbx_destroy_common_mq *)&mbx.payload;
	fwcmd->params.req.id = mq->mq_id;
	(void) oce_destroy_q(dev, &mbx,
	    sizeof (struct mbx_destroy_common_mq),
	    QTYPE_MQ, MBX_BOOTSTRAP);
	oce_cq_del(dev, mq->cq, MBX_BOOTSTRAP);
	mq->cq = NULL;
	mq->qstate = QDELETED;
	mutex_destroy(&mq->lock);
	kmem_free(mq, sizeof (struct oce_mq));
} /* oce_mq_del */

/*
 * function to create a WQ for NIC Tx
 *
 * dev - software handle to the device
 * wqcfg - configuration structure providing WQ config parameters
 *
 * return pointer to the WQ created. NULL on failure
 */
int oce_wq_init(struct oce_dev *dev, struct oce_wq *wq, uint32_t q_len,
    int wq_type)
{
	char str[MAX_POOL_NAME];
	int ret;
	static int wq_id = 0;
	int buf_size;

	ASSERT(dev != NULL);
	/* q_len must be min 256 and max 2k */
	if (q_len < 256 || q_len > 2048) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Invalid q length. Must be "
		    "[256, 2000]: 0x%x", q_len);
		return (DDI_FAILURE);
	}

	/* Set the wq config */
	wq->cfg.q_len = q_len;
	wq->cfg.wq_type = (uint8_t)wq_type;
	wq->cfg.eqd = OCE_DEFAULT_WQ_EQD;
	wq->cfg.nbufs = 2 * wq->cfg.q_len;
	wq->cfg.nhdl = 2 * wq->cfg.q_len;

	buf_size = ((dev->tx_bcopy_limit >> 10) +
	    ((dev->tx_bcopy_limit & (((uint32_t)1 << 10) - 1)) > 0 ? 1 :
	    0)) << 10;
	wq->cfg.buf_size = (uint16_t)buf_size;

	/* initialize ring statistics */
	wq->stat_bytes = wq->stat_pkts = 0;

	/* Create the WQ Buffer pool */
	ret  = oce_wqb_cache_create(wq, wq->cfg.buf_size);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "WQ Buffer Pool create failed ");
		return (DDI_FAILURE);
	}

	/* Create a pool of memory handles */
	ret = oce_wqm_cache_create(wq);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "WQ MAP Handles Pool create failed ");
		goto wqm_fail;
	}

	(void) snprintf(str, MAX_POOL_NAME, "%s%d%s%d", "oce_wqed_",
	    dev->dev_id, "_", wq_id++);
	wq->wqed_cache = kmem_cache_create(str, sizeof (oce_wqe_desc_t),
	    0, NULL, NULL, NULL, NULL, NULL, 0);
	if (wq->wqed_cache == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "WQ Packet Desc Pool create failed ");
		goto wqed_fail;
	}

	/* create the ring buffer */
	wq->ring = oce_create_ring_buffer(dev, q_len,
	    NIC_WQE_SIZE, DDI_DMA_CONSISTENT | DDI_DMA_RDWR);
	if (wq->ring == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "Failed to create WQ ring ");
		goto wq_ringfail;
	}

	/* Initialize WQ lock */
	mutex_init(&wq->tx_lock, NULL, MUTEX_DRIVER,
	    DDI_INTR_PRI(dev->intr_pri));
	/* Initialize WQ lock */
	mutex_init(&wq->txc_lock, NULL, MUTEX_DRIVER,
	    DDI_INTR_PRI(dev->intr_pri));
	atomic_inc_32(&dev->nwqs);

	mutex_init(&wq->wqed_list_lock, NULL, MUTEX_DRIVER,
	    DDI_INTR_PRI(dev->intr_pri));

	list_create(&wq->wqe_desc_list, sizeof (oce_wqe_desc_t),
	    offsetof(oce_wqe_desc_t, link));
	return (DDI_SUCCESS);

wqcq_fail:
	destroy_ring_buffer(dev, wq->ring);
wq_ringfail:
	kmem_cache_destroy(wq->wqed_cache);
wqed_fail:
	oce_wqm_cache_destroy(wq);
wqm_fail:
	oce_wqb_cache_destroy(wq);
	return (DDI_FAILURE);
} /* oce_wq_create */

/*
 * function to delete a WQ
 *
 * dev - software handle to the device
 * wq - WQ to delete
 *
 * return 0 => success, failure otherwise
 */
static void
oce_wq_fini(struct oce_dev *dev, struct oce_wq *wq)
{
	/* destroy cq */
	oce_wqb_cache_destroy(wq);
	oce_wqm_cache_destroy(wq);
	kmem_cache_destroy(wq->wqed_cache);

	/* Free the packet descriptor list */
	list_destroy(&wq->wqe_desc_list);
	destroy_ring_buffer(dev, wq->ring);
	wq->ring = NULL;
	/* Destroy the Mutex */
	mutex_destroy(&wq->wqed_list_lock);
	mutex_destroy(&wq->tx_lock);
	mutex_destroy(&wq->txc_lock);
	atomic_dec_32(&dev->nwqs);
} /* oce_wq_del */


static int
oce_wq_create(struct oce_wq *wq, struct oce_eq *eq, uint32_t mode)
{

	struct oce_mbx mbx;
	struct mbx_create_nic_wq *fwcmd;
	struct oce_dev *dev = wq->parent;
	struct oce_cq *cq;
	int ret;

	/* create the CQ */
	cq = oce_cq_create(dev, eq, CQ_LEN_1024,
	    sizeof (struct oce_nic_tx_cqe),
	    B_FALSE, B_TRUE, B_FALSE, 3, B_FALSE, mode);
	if (cq == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "WQCQ create failed ");
		return (DDI_FAILURE);
	}
	/* now fill the command */
	bzero(&mbx, sizeof (struct oce_mbx));
	fwcmd = (struct mbx_create_nic_wq *)&mbx.payload;
	if (LANCER_CHIP(dev)) {
		mbx_common_req_hdr_init(&fwcmd->hdr, 0, 0,
		    MBX_SUBSYSTEM_NIC,
		    OPCODE_CREATE_NIC_WQ, MBX_TIMEOUT_SEC,
		    sizeof (struct mbx_create_nic_wq), 1);
		fwcmd->params.req.ctx.if_id = dev->if_id;
	} else {
		mbx_common_req_hdr_init(&fwcmd->hdr, 0, 0,
		    MBX_SUBSYSTEM_NIC,
		    OPCODE_CREATE_NIC_WQ, MBX_TIMEOUT_SEC,
		    sizeof (struct mbx_create_nic_wq), 0);
	}

	fwcmd->params.req.type = (uint8_t)wq->cfg.wq_type;
	fwcmd->params.req.num_pages = wq->ring->dbuf.num_pages;
	fwcmd->params.req.ulp_num = BE_ULP1_NUM;
	oce_log(dev, CE_NOTE, MOD_CONFIG, "NUM_PAGES = 0x%d size = %lu",
	    (uint32_t)wq->ring->dbuf.num_pages,
	    wq->ring->dbuf.size);

	/* Context info */
	fwcmd->params.req.ctx.wq_size = OCE_LOG2(wq->cfg.q_len) + 1;
	fwcmd->params.req.ctx.valid = 1;
	fwcmd->params.req.ctx.cofe = 1;
	fwcmd->params.req.ctx.no_rem_allowed = 1;
	fwcmd->params.req.ctx.cq_id = cq->cq_id;

	oce_page_list(&wq->ring->dbuf, fwcmd->params.req.pages,
	    wq->ring->dbuf.num_pages);

	/* fill rest of mbx */
	mbx.u0.s.embedded = 1;
	mbx.payload_length = sizeof (struct mbx_create_nic_wq);
	DW_SWAP(u32ptr(&mbx), mbx.payload_length + OCE_BMBX_RHDR_SZ);

	/* now post the command */
	ret = oce_issue_mbox_cmd(dev, &mbx, MBX_TIMEOUT_SEC, mode);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "WQ create failed: 0x%x", ret);
		oce_cq_del(dev, cq, mode);
		return (ret);
	}

	/* interpret the response */
	wq->wq_id = LE_16(fwcmd->params.rsp.wq_id);
	wq->qstate = QCREATED;
	wq->cq = cq;
	/* set the WQCQ handlers */
	wq->cq->cq_handler = oce_drain_wq_cq;
	wq->cq->cb_arg = (void *)wq;

	/* All are free to start with */
	wq->wq_free = wq->cfg.q_len;
	/* reset indicies */
	wq->ring->cidx = 0;
	wq->ring->pidx = 0;
	oce_log(dev, CE_NOTE, MOD_CONFIG, "WQ CREATED WQID = %d",
	    wq->wq_id);

	return (0);
}

/*
 * function to delete a WQ
 *
 * dev - software handle to the device
 * wq - WQ to delete
 *
 * return none
 */
static void
oce_wq_del(struct oce_dev *dev, struct oce_wq *wq, uint32_t mode)
{
	struct oce_mbx mbx;
	struct mbx_delete_nic_wq *fwcmd;

	ASSERT(dev != NULL);
	ASSERT(wq != NULL);
	if (wq->qstate == QCREATED) {
		bzero(&mbx, sizeof (struct oce_mbx));
		/* now fill the command */
		fwcmd = (struct mbx_delete_nic_wq *)&mbx.payload;
		fwcmd->params.req.wq_id = wq->wq_id;
		(void) oce_destroy_q(dev, &mbx,
		    sizeof (struct mbx_delete_nic_wq),
		    QTYPE_WQ, mode);
		wq->qstate = QDELETED;
		oce_cq_del(dev, wq->cq, mode);
		wq->cq = NULL;
	}
} /* oce_wq_del */

/*
 * function to allocate RQ resources
 *
 * dev - software handle to the device
 * rqcfg - configuration structure providing RQ config parameters
 *
 * return pointer to the RQ created. NULL on failure
 */
int oce_rq_init(struct oce_dev *dev, struct oce_rq *rq, uint32_t q_len,
    uint32_t frag_size, uint32_t mtu)
{
	int ret;

	/* validate q creation parameters */
	if (!OCE_LOG2(frag_size))
		return (NULL);
	if ((q_len == 0) || (q_len > 1024))
		return (NULL);

	rq->cfg.q_len = q_len;
	rq->cfg.frag_size = frag_size;
	rq->cfg.mtu = mtu;
	rq->cfg.eqd = 0;
	rq->cfg.nbufs = dev->rq_max_bufs;

	/* initialize ring statistics */
	rq->stat_bytes = rq->stat_pkts = 0;

	rq->rq_bdesc_array =
	    kmem_zalloc((sizeof (oce_rq_bdesc_t) * rq->cfg.nbufs), KM_NOSLEEP);
	if (rq->rq_bdesc_array == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "RQ bdesc alloc failed");
		return (DDI_FAILURE);
	}
	/* create the rq buffer descriptor ring */
	rq->shadow_ring =
	    kmem_zalloc((rq->cfg.q_len * sizeof (oce_rq_bdesc_t *)),
	    KM_NOSLEEP);
	if (rq->shadow_ring == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "RQ shadow ring alloc failed ");
		goto rq_shdw_fail;
	}

	/* allocate the free list array */
	rq->rqb_freelist =
	    kmem_zalloc(rq->cfg.nbufs * sizeof (oce_rq_bdesc_t *), KM_NOSLEEP);
	if (rq->rqb_freelist == NULL) {
		goto rqb_free_list_fail;
	}
	/* create the buffer pool */
	ret  =  oce_rqb_cache_create(rq, rq->cfg.frag_size);
	if (ret != DDI_SUCCESS) {
		goto rqb_fail;
	}

	/* create the ring buffer */
	rq->ring = oce_create_ring_buffer(dev, q_len,
	    sizeof (struct oce_nic_rqe), DDI_DMA_CONSISTENT | DDI_DMA_RDWR);
	if (rq->ring == NULL) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "RQ ring create failed ");
		goto rq_ringfail;
	}

	/* Initialize the RQ lock */
	mutex_init(&rq->rx_lock, NULL, MUTEX_DRIVER,
	    DDI_INTR_PRI(dev->intr_pri));
	/* Initialize the recharge  lock */
	mutex_init(&rq->rc_lock, NULL, MUTEX_DRIVER,
	    DDI_INTR_PRI(dev->intr_pri));
	atomic_inc_32(&dev->nrqs);
	return (DDI_SUCCESS);

rq_ringfail:
	oce_rqb_cache_destroy(rq);
rqb_fail:
	kmem_free(rq->rqb_freelist,
	    (rq->cfg.nbufs * sizeof (oce_rq_bdesc_t *)));
rqb_free_list_fail:

	kmem_free(rq->shadow_ring,
	    (rq->cfg.q_len * sizeof (oce_rq_bdesc_t *)));
rq_shdw_fail:
	kmem_free(rq->rq_bdesc_array,
	    (sizeof (oce_rq_bdesc_t) * rq->cfg.nbufs));
	return (DDI_FAILURE);
} /* oce_rq_create */


/*
 * function to delete an RQ
 *
 * dev - software handle to the device
 * rq - RQ to delete
 *
 * return none
 */
void
oce_rq_fini(struct oce_dev *dev, struct oce_rq *rq)
{
	/* Destroy buffer cache */
	rq->qstate = QFINI;
	oce_rqb_cache_destroy(rq);
	destroy_ring_buffer(dev, rq->ring);
	rq->ring = NULL;
	kmem_free(rq->shadow_ring,
	    sizeof (oce_rq_bdesc_t *) * rq->cfg.q_len);
	rq->shadow_ring = NULL;
	kmem_free(rq->rq_bdesc_array,
	    (sizeof (oce_rq_bdesc_t) * rq->cfg.nbufs));
	rq->rq_bdesc_array = NULL;
	kmem_free(rq->rqb_freelist,
	    (rq->cfg.nbufs * sizeof (oce_rq_bdesc_t *)));
	rq->rqb_freelist = NULL;
	mutex_destroy(&rq->rx_lock);
	mutex_destroy(&rq->rc_lock);
	atomic_dec_32(&dev->nrqs);
} /* oce_rq_del */


static int
oce_rq_create(struct oce_rq *rq, uint32_t if_id, struct oce_eq *eq,
    uint32_t mode)
{
	struct oce_mbx mbx;
	struct mbx_create_nic_rq *fwcmd;
	struct oce_dev *dev = rq->parent;
	struct oce_cq *cq;
	int cq_len;
	int ret;

	if (LANCER_CHIP(dev))
		cq_len = CQ_LEN_2048;
	else
		cq_len = CQ_LEN_1024;

	cq = oce_cq_create(dev, eq, cq_len, sizeof (struct oce_nic_rx_cqe),
	    B_FALSE, B_TRUE, B_FALSE, 3, B_FALSE, mode);

	if (cq == NULL) {
		return (DDI_FAILURE);
	}

	/* now fill the command */
	bzero(&mbx, sizeof (struct oce_mbx));
	fwcmd = (struct mbx_create_nic_rq *)&mbx.payload;
	mbx_common_req_hdr_init(&fwcmd->hdr, 0, 0,
	    MBX_SUBSYSTEM_NIC,
	    OPCODE_CREATE_NIC_RQ, MBX_TIMEOUT_SEC,
	    sizeof (struct mbx_create_nic_rq), 0);

	fwcmd->params.req.num_pages = rq->ring->dbuf.num_pages;
	fwcmd->params.req.frag_size = OCE_LOG2(rq->cfg.frag_size);
	fwcmd->params.req.cq_id = cq->cq_id;
	oce_page_list(&rq->ring->dbuf, fwcmd->params.req.pages,
	    rq->ring->dbuf.num_pages);

	fwcmd->params.req.if_id = if_id;
	fwcmd->params.req.max_frame_size = (uint16_t)rq->cfg.mtu;
	fwcmd->params.req.is_rss_queue = rq->cfg.is_rss_queue;

	/* fill rest of mbx */
	mbx.u0.s.embedded = 1;
	mbx.payload_length = sizeof (struct mbx_create_nic_rq);
	DW_SWAP(u32ptr(&mbx), mbx.payload_length + OCE_BMBX_RHDR_SZ);

	/* now post the command */
	ret = oce_issue_mbox_cmd(dev, &mbx, MBX_TIMEOUT_SEC, mode);
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "RQ create failed: 0x%x", ret);
		oce_cq_del(dev, cq, MBX_BOOTSTRAP);
		return (ret);
	}

	/* interpret the response */
	rq->rq_id = LE_16(fwcmd->params.rsp.u0.s.rq_id);
	rq->rss_cpuid = fwcmd->params.rsp.u0.s.rss_cpuid;
	rq->cfg.if_id = if_id;
	rq->qstate = QCREATED;
	rq->cq = cq;

	/* set the Completion Handler */
	rq->cq->cq_handler = oce_drain_rq_cq;
	rq->cq->cb_arg  = (void *)rq;

	/* reset the indicies */
	rq->ring->cidx = 0;
	rq->ring->pidx = 0;
	rq->buf_avail = 0;
	oce_log(dev, CE_NOTE, MOD_CONFIG, "RQ created, RQID : %d, cpu-id = %d",
	    rq->rq_id, rq->rss_cpuid);
	return (0);

}

/*
 * function to delete an RQ
 *
 * dev - software handle to the device
 * rq - RQ to delete
 *
 * return none
 */
static void
oce_rq_del(struct oce_dev *dev, struct oce_rq *rq, uint32_t mode)
{
	struct oce_mbx mbx;
	struct mbx_delete_nic_rq *fwcmd;

	ASSERT(dev != NULL);
	ASSERT(rq != NULL);

	bzero(&mbx, sizeof (struct oce_mbx));

	mutex_enter(&rq->rx_lock);
	/* delete the Queue  */
	if (rq->qstate == QCREATED) {
		fwcmd = (struct mbx_delete_nic_rq *)&mbx.payload;
		fwcmd->params.req.rq_id = rq->rq_id;
		(void) oce_destroy_q(dev, &mbx,
		    sizeof (struct mbx_delete_nic_rq), QTYPE_RQ, mode);
		oce_clean_rq(rq);
		/* Delete the associated CQ */
		oce_cq_del(dev, rq->cq, mode);
		rq->cq = NULL;
		/* free up the posted buffers */
		oce_rq_discharge(rq);
		(void) atomic_swap_32(&rq->qstate, QDELETED);
	}
	mutex_exit(&rq->rx_lock);
} /* oce_rq_del */

/*
 * function to arm an EQ so that it can generate events
 *
 * dev - software handle to the device
 * qid - id of the EQ returned by the fw at the time of creation
 * npopped - number of EQEs to arm with
 * rearm - rearm bit
 * clearint - bit to clear the interrupt condition because of which
 *	EQEs are generated
 *
 * return none
 */
void
oce_arm_eq(struct oce_dev *dev, int16_t qid, int npopped,
    boolean_t rearm, boolean_t clearint)
{
	eq_db_t eq_db = {0};

	eq_db.bits.rearm = rearm;
	eq_db.bits.event  = B_TRUE;
	eq_db.bits.eq_cq_extid =
	    (((uint64_t)qid & (uint64_t)DB_EQ_RING_ID_EXT_MASK) <<
	    (uint64_t)DB_EQ_RING_ID_EXT_MASK_SHIFT);
	eq_db.bits.num_popped = npopped;
	eq_db.bits.clrint = clearint;
	eq_db.bits.qid = qid;
	OCE_DB_WRITE32(dev, PD_EQ_DB, eq_db.dw0);
}

/*
 * function to arm a CQ with CQEs
 *
 * dev - software handle to the device
 * qid - the id of the CQ returned by the fw at the time of creation
 * npopped - number of CQEs to arm with
 * rearm - rearm bit enable/disable
 *
 * return none
 */
void
oce_arm_cq(struct oce_dev *dev, int16_t qid, int npopped,
    boolean_t rearm)
{
	cq_db_t cq_db = {0};
	cq_db.bits.rearm = rearm;
	cq_db.bits.eq_cq_extid =
	    (((uint64_t)qid & (uint64_t)DB_CQ_RING_ID_EXT_MASK) <<
	    (uint64_t)DB_CQ_RING_ID_EXT_MASK_SHIFT);
	cq_db.bits.num_popped = npopped;
	cq_db.bits.event = 0;
	cq_db.bits.qid = qid;
	OCE_DB_WRITE32(dev, PD_CQ_DB, cq_db.dw0);
}


/*
 * function to delete a EQ, CQ, MQ, WQ or RQ
 *
 * dev - sofware handle to the device
 * mbx - mbox command to send to the fw to delete the queue
 *	mbx contains the queue information to delete
 * req_size - the size of the mbx payload dependent on the qtype
 * qtype - the type of queue i.e. EQ, CQ, MQ, WQ or RQ
 *
 * return DDI_SUCCESS => success, failure otherwise
 */
int
oce_destroy_q(struct oce_dev *dev, struct oce_mbx  *mbx, size_t req_size,
    enum qtype qtype, uint32_t mode)
{
	struct mbx_hdr *hdr = (struct mbx_hdr *)&mbx->payload;
	int opcode;
	int subsys;
	int ret;

	switch (qtype) {
	case QTYPE_EQ: {
		opcode = OPCODE_DESTROY_COMMON_EQ;
		subsys = MBX_SUBSYSTEM_COMMON;
		break;
	}
	case QTYPE_CQ: {
		opcode = OPCODE_DESTROY_COMMON_CQ;
		subsys = MBX_SUBSYSTEM_COMMON;
		break;
	}
	case QTYPE_MQ: {
		opcode = OPCODE_DESTROY_COMMON_MQ;
		subsys = MBX_SUBSYSTEM_COMMON;
		break;
	}
	case QTYPE_WQ: {
		opcode = OPCODE_DELETE_NIC_WQ;
		subsys = MBX_SUBSYSTEM_NIC;
		break;
	}
	case QTYPE_RQ: {
		opcode = OPCODE_DELETE_NIC_RQ;
		subsys = MBX_SUBSYSTEM_NIC;
		break;
	}
	default: {
		ASSERT(0);
		break;
	}
	}

	mbx_common_req_hdr_init(hdr, 0, 0, subsys,
	    opcode, MBX_TIMEOUT_SEC, req_size, 0);

	/* fill rest of mbx */
	mbx->u0.s.embedded = 1;
	mbx->payload_length = (uint32_t)req_size;
	DW_SWAP(u32ptr(mbx), mbx->payload_length + OCE_BMBX_RHDR_SZ);

	/* send command */
	ret = oce_issue_mbox_cmd(dev, mbx, MBX_TIMEOUT_SEC, mode);
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Failed to del q: 0x%x", ret);
	}

	return (ret);
}

/*
 * function to set the delay parameter in the EQ for interrupt coalescing
 *
 * dev - software handle to the device
 * eq_arr - array of EQ ids to delete
 * eq_cnt - number of elements in eq_arr
 * eq_delay - delay parameter
 *
 * return DDI_SUCCESS => success, failure otherwise
 */
int
oce_set_eq_delay(struct oce_dev *dev, uint32_t *eq_arr,
    uint32_t eq_cnt, uint32_t eq_delay, uint32_t mode)
{
	struct oce_mbx mbx;
	struct mbx_modify_common_eq_delay *fwcmd;
	int ret;
	int neq;

	bzero(&mbx, sizeof (struct oce_mbx));
	fwcmd = (struct mbx_modify_common_eq_delay *)&mbx.payload;

	/* fill the command */
	fwcmd->params.req.num_eq = eq_cnt;
	for (neq = 0; neq < eq_cnt; neq++) {
		fwcmd->params.req.delay[neq].eq_id = eq_arr[neq];
		fwcmd->params.req.delay[neq].phase = 0;
		fwcmd->params.req.delay[neq].dm = eq_delay;

	}

	/* initialize the ioctl header */
	mbx_common_req_hdr_init(&fwcmd->hdr, 0, 0,
	    MBX_SUBSYSTEM_COMMON,
	    OPCODE_MODIFY_COMMON_EQ_DELAY,
	    MBX_TIMEOUT_SEC,
	    sizeof (struct mbx_modify_common_eq_delay), 0);

	/* fill rest of mbx */
	mbx.u0.s.embedded = 1;
	mbx.payload_length = sizeof (struct mbx_modify_common_eq_delay);
	DW_SWAP(u32ptr(&mbx), mbx.payload_length + OCE_BMBX_RHDR_SZ);

	/* post the command */
	ret = oce_issue_mbox_cmd(dev, &mbx, MBX_TIMEOUT_SEC, mode);
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Failed to set EQ delay 0x%x", ret);
	}

	return (ret);
} /* oce_set_eq_delay */

/*
 * function to cleanup the eqs used during stop
 *
 * eq - pointer to event queue structure
 *
 * return none
 */
void
oce_drain_eq(struct oce_eq *eq)
{
	struct oce_eqe *eqe;
	uint16_t num_eqe = 0;
	struct oce_dev *dev;

	dev = eq->parent;
	/* get the first item in eq to process */
	eqe = RING_GET_CONSUMER_ITEM_VA(eq->ring, struct oce_eqe);

	while (eqe->u0.dw0) {
		eqe->u0.dw0 = LE_32(eqe->u0.dw0);

		/* clear valid bit */
		eqe->u0.dw0 = 0;

		/* process next eqe */
		RING_GET(eq->ring, 1);

		eqe = RING_GET_CONSUMER_ITEM_VA(eq->ring, struct oce_eqe);
		num_eqe++;
	} /* for all EQEs */
	if (num_eqe) {
		oce_arm_eq(dev, eq->eq_id, num_eqe, B_FALSE, B_TRUE);
	}
} /* oce_drain_eq */


int
oce_init_tx(struct oce_dev  *dev)
{
	int qid = 0;

	for (qid = 0; qid < dev->tx_rings; qid++) {
		if (oce_wq_init(dev, &dev->wq[qid], dev->tx_ring_size,
		    NIC_WQ_TYPE_STANDARD) != DDI_SUCCESS) {
			goto queue_fail;
		}
	}

	return (DDI_SUCCESS);
queue_fail:
	oce_fini_tx(dev);
	return (DDI_FAILURE);
}


void
oce_fini_tx(struct oce_dev *dev)
{
	int qid;
	int nqs;

	/* free all the tx rings */
	/* nwqs is decremented in fini so copy count first */
	nqs = dev->nwqs;
	for (qid = 0; qid < nqs; qid++) {
		oce_wq_fini(dev, &dev->wq[qid]);
	}
}


int
oce_create_queues(struct oce_dev *dev)
{
	int i, num_if;

	for (num_if = 0; num_if < dev->num_rx_groups; num_if++) {
		if (oce_create_nw_interface(dev, &dev->rx_group[num_if],
		    MBX_BOOTSTRAP) != DDI_SUCCESS) {
			goto if_fail;
		}
	}

	/* create resources that are common to an oce instance */
	for (i = 0; i < dev->num_vectors; i++) {
		if (oce_eq_create(dev, &dev->eq[i], EQ_LEN_1024, EQE_SIZE_4, 0,
		    MBX_BOOTSTRAP) != DDI_SUCCESS) {
			goto rings_fail;
		}
	}

	/* create tx rings */
	if (dev->num_tx_groups == 1) {
		for (i = 0; i < dev->tx_rings; i++) {
			if (oce_wq_create(&dev->wq[i], &dev->eq[i],
			    MBX_BOOTSTRAP) != 0) {
				dev->tx_rings = i;
				goto rings_fail;
			}
			oce_log(dev, CE_NOTE, MOD_CONFIG,
			    "wq[%d] created on eq[%d]=%p wq=%p",
			    i, i, (void *)&dev->eq[i], (void *)&dev->wq[i]);
		}
	} else {
		/* Tx groups not supported */
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "unsupported number of tx groups %d", dev->num_tx_groups);
		goto rings_fail;
	}

	return (DDI_SUCCESS);
rings_fail:
	oce_delete_queues(dev);
if_fail:
	for (i = 0; i < num_if; i++) {
		oce_delete_nw_interface(dev, &dev->rx_group[i], MBX_BOOTSTRAP);
	}
	return (DDI_FAILURE);
}

int
oce_create_mcc_queue(struct oce_dev *dev)
{
	if (LANCER_CHIP(dev)) {
		dev->mq = oce_mq_create_ext_v1(dev, &dev->eq[0], MCC_Q_LEN);
	} else {
		dev->mq = oce_mq_create_ext_v0(dev, &dev->eq[0], MCC_Q_LEN);
	}

	if (dev->mq == NULL) {
		oce_log(dev, CE_NOTE, MOD_CONFIG, "%s",
		    "Extended MQ is not supported reverting to Legacy MQ mode");
		dev->mq = oce_mq_create(dev, &dev->eq[0], MCC_Q_LEN);
		if (dev->mq == NULL)
			return (DDI_FAILURE);
	}

	return (DDI_SUCCESS);
}

int
oce_create_group(struct oce_dev *dev, oce_group_t *grp, uint32_t mode)
{
	int eqidx, ret, i;
	char itbl[OCE_ITBL_SIZE];
	char hkey[OCE_HKEY_SIZE];

	for (i = 0; i < grp->num_rings; i++) {
		if (i != 0) {
			grp->ring[i].rx->cfg.is_rss_queue =
			    grp->rss_enable;
			eqidx = (grp->eq_idx + i - grp->rss_enable) %
			    dev->num_vectors;
		} else {
			grp->ring[i].rx->cfg.is_rss_queue = B_FALSE;
			eqidx = grp->eq_idx % dev->num_vectors;
		}

		ret = oce_rq_create(grp->ring[i].rx,
		    grp->if_id, &dev->eq[eqidx], mode);

		if (ret != 0) {
			goto cleanup_group;
		}
		oce_log(dev, CE_NOTE, MOD_CONFIG,
		    "rq[%d][%d] created on eq[%d]=%p rq=%p, rss=%d",
		    grp->grp_num, i, eqidx,
		    (void *)&dev->eq[eqidx],
		    (void *)grp->ring[i].rx,
		    grp->ring[i].rx->cfg.is_rss_queue);
	}

	if (grp->rss_enable) {
		(void) oce_group_create_itbl(grp, itbl);

		(void) oce_gen_hkey(hkey, OCE_HKEY_SIZE);
		ret = oce_config_rss(dev, grp->if_id, hkey,
		    itbl, OCE_ITBL_SIZE, OCE_DEFAULT_RSS_TYPE, B_FALSE,
		    mode);
		if (ret != DDI_SUCCESS) {
			oce_log(dev, CE_WARN, MOD_CONFIG,
			    "Failed to Configure RSS 0x%x", ret);
			goto cleanup_group;
		}
	}

	return (DDI_SUCCESS);
cleanup_group:
	oce_delete_group(dev, grp);
	return (DDI_FAILURE);
}

void
oce_delete_mcc_queue(struct oce_dev *dev)
{
	if (dev->mq != NULL) {
		oce_mq_del(dev, dev->mq);
		dev->mq = NULL;
	}
}

void
oce_delete_queues(struct oce_dev *dev)
{
	int i;
	int neqs = dev->neqs;

	for (i = 0; i < dev->nwqs; i++) {
		oce_wq_del(dev, &dev->wq[i], MBX_BOOTSTRAP);
	}

	/* delete as many eqs as the number of vectors */
	for (i = 0; i < neqs; i++) {
		oce_eq_del(dev, &dev->eq[i], MBX_BOOTSTRAP);
	}

	for (i = dev->num_rx_groups - 1; i >= 0; i--) {
		oce_delete_nw_interface(dev, &dev->rx_group[i], MBX_BOOTSTRAP);
	}
}

void
oce_delete_group(struct oce_dev *dev, oce_group_t *grp)
{
	int i;

	for (i = 0; i < grp->num_rings; i++) {
		oce_rq_del(dev, grp->ring[i].rx, MBX_BOOTSTRAP);
	}
}


void
oce_free_queues(struct oce_dev *dev)
{
	int i = 0;

	for (i = 0; i < dev->rx_rings; i++) {
		mutex_destroy(&dev->rq[i].rq_fini_lock);
	}
	if (dev->rq != NULL) {
		kmem_free(dev->rq,
		    sizeof (struct oce_rq) * dev->rx_rings);
		dev->rq = NULL;
	}
	if (dev->wq != NULL) {
		kmem_free(dev->wq,
		    sizeof (struct oce_wq) * dev->tx_rings);
		dev->wq = NULL;
	}
	if (dev->cq != NULL) {
		kmem_free(dev->cq,
		    sizeof (struct oce_cq *) * OCE_MAX_CQ);
		dev->cq = NULL;
	}
	if (dev->eq != NULL) {
		for (i = 0; i < OCE_MAX_EQ; i++) {
			mutex_destroy(&dev->eq[i].lock);
		}

		kmem_free(dev->eq,
		    sizeof (struct oce_eq) * OCE_MAX_EQ);
		dev->eq = NULL;
	}
}

int
oce_alloc_queues(struct oce_dev *dev)
{
	int i, j, nrings = 0;

	/* Allocate space for RQ array */
	dev->rq = kmem_zalloc(sizeof (struct oce_rq) * dev->rx_rings,
	    KM_NOSLEEP);

	if (dev->rq == NULL) {
		return (DDI_FAILURE);
	}
	for (i = 0; i < dev->rx_rings; i++) {
		mutex_init(&dev->rq[i].rq_fini_lock, NULL, MUTEX_DRIVER,
		    DDI_INTR_PRI(dev->intr_pri));
	}

	/* Allocate space for WQ array */
	dev->wq = kmem_zalloc(sizeof (struct oce_wq) * dev->tx_rings,
	    KM_NOSLEEP);

	if (dev->wq == NULL) {
		goto alloc_fail;
	}

	dev->cq = kmem_zalloc(sizeof (struct oce_cq *) * OCE_MAX_CQ,
	    KM_NOSLEEP);

	if (dev->cq == NULL) {
		goto alloc_fail;
	}

	dev->eq = kmem_zalloc(sizeof (struct oce_eq) * OCE_MAX_EQ,
	    KM_NOSLEEP);
	if (dev->eq == NULL) {
		goto alloc_fail;
	}

	for (i = 0; i < OCE_MAX_EQ; i++) {
		dev->eq[i].idx = i;
		mutex_init(&dev->eq[i].lock, NULL, MUTEX_DRIVER,
		    DDI_INTR_PRI(dev->intr_pri));
	}

	for (i = 0; i < dev->tx_rings; i++) {
		dev->wq[i].parent = (void *)dev;
		dev->default_tx_rings[i].tx = &dev->wq[i];
	}

	for (i = 0; i < dev->num_rx_groups; i++) {
		for (j = 0; j < dev->rx_group[i].num_rings; j++) {
			dev->rq[nrings].parent = (void *)dev;
			dev->rx_group[i].ring[j].rx = &dev->rq[nrings];
			dev->rx_group[i].ring[j].rx->grp = &dev->rx_group[i];
			nrings++;
		}
	}

	return (DDI_SUCCESS);
alloc_fail:
	oce_free_queues(dev);
	return (DDI_FAILURE);
}

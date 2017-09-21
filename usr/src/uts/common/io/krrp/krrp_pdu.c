/*
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 */

/*
 * Copyright 2016 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * PDU is high level structure (a container) that contains header, some ctrl
 * information and list of dblks that contain payload.
 * Over network are transfered header and dblks.
 */

#include "krrp_svc.h"
#include "krrp_pdu.h"

/* #define KRRP_PDU_DEBUG 1 */

static struct {
	uint64_t			ref_cnt;
	krrp_pdu_engine_t	*ctrl_pdu_engine;
} krrp_global_pdu_engine_env = {0, NULL};

static void krrp_pdu_rele_task(void *void_pdu);
static void krrp_pdu_engine_notify_cb(void *void_pdu_engine);

int
krrp_pdu_engine_global_init()
{
	int rc;
	krrp_error_t error;

	VERIFY(krrp_global_pdu_engine_env.ref_cnt == 0);
	VERIFY(krrp_global_pdu_engine_env.ctrl_pdu_engine == NULL);

	/*
	 * CTRL PDU Engine that will be used by all sessions:
	 * preallocation: B_FALSE
	 * max_memory: 100 MB (should be enough)
	 * dblk_per_pdu: 1
	 * dblk_head_sz: 0
	 * dblk_data_sz: 2 KB
	 * notify_free_cb: NULL
	 * notify_free_cb_arg: NULL
	 */
	rc = krrp_pdu_engine_create(&krrp_global_pdu_engine_env.ctrl_pdu_engine,
	    B_TRUE, B_FALSE, 100, 1, 0, 2 * 1024, &error);

	return (rc);
}

void
krrp_pdu_engine_global_fini()
{
	VERIFY(krrp_global_pdu_engine_env.ctrl_pdu_engine != NULL);
	VERIFY(krrp_global_pdu_engine_env.ref_cnt == 1);

	krrp_pdu_engine_destroy(krrp_global_pdu_engine_env.ctrl_pdu_engine);
	krrp_global_pdu_engine_env.ctrl_pdu_engine = NULL;
}

void
krrp_pdu_ctrl_alloc(krrp_pdu_ctrl_t **result_pdu, boolean_t with_header)
{
	krrp_pdu_alloc(krrp_global_pdu_engine_env.ctrl_pdu_engine,
	    (krrp_pdu_t **)result_pdu, with_header);
}

int
krrp_pdu_engine_create(krrp_pdu_engine_t **result_engine, boolean_t ctrl,
    boolean_t prealloc, size_t max_memory, size_t dblks_per_pdu,
    size_t dblk_head_sz, size_t dblk_data_sz, krrp_error_t *error)
{
	int rc;
	krrp_pdu_engine_t *engine;
	size_t total_dblk_sz, max_dblk_cnt;

	VERIFY(result_engine != NULL && *result_engine == NULL);
	VERIFY(max_memory != 0);
	VERIFY(dblk_data_sz != 0);

	engine = kmem_zalloc(sizeof (krrp_pdu_engine_t), KM_SLEEP);

	engine->type = ctrl ? KRRP_PET_CTRL : KRRP_PET_DATA;

	total_dblk_sz = dblk_head_sz + dblk_data_sz;
	if (dblks_per_pdu == 0)
		engine->dblks_per_pdu =
		    (KRRP_PDU_DEFAULT_SIZE / total_dblk_sz) + 1;
	else
		engine->dblks_per_pdu = dblks_per_pdu;

	engine->max_pdu_cnt = (max_memory * 1024 * 1024) /
	    total_dblk_sz / engine->dblks_per_pdu;

	engine->pdu_data_sz = dblk_data_sz * engine->dblks_per_pdu;

	max_dblk_cnt = engine->max_pdu_cnt * engine->dblks_per_pdu;
	rc = krrp_dblk_engine_create(&engine->dblk_engine, prealloc,
	    max_dblk_cnt, dblk_head_sz, dblk_data_sz,
	    engine->dblks_per_pdu, &krrp_pdu_engine_notify_cb, engine,
	    error);
	if (rc != 0) {
		kmem_free(engine, sizeof (krrp_pdu_engine_t));
		return (-1);
	}

	atomic_inc_64(&krrp_global_pdu_engine_env.ref_cnt);

	mutex_init(&engine->mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&engine->cv, NULL, CV_DEFAULT, NULL);

	cmn_err(CE_NOTE, "PDU Engine config: dblk_head_sz:[%lu], "
	    "dblk_data_sz:[%lu], max_mem:[%lu MB], "
	    "dblks_per_pdu:[%lu], prealloc:[%s]",
	    dblk_head_sz, dblk_data_sz, max_memory,
	    engine->dblks_per_pdu, (prealloc ? "YES" : "NO"));

	*result_engine = engine;
	return (0);
}

void
krrp_pdu_engine_destroy(krrp_pdu_engine_t *engine)
{
	krrp_dblk_engine_destroy(engine->dblk_engine);

	mutex_enter(&engine->mtx);

	cv_destroy(&engine->cv);

	mutex_exit(&engine->mtx);
	mutex_destroy(&engine->mtx);

	atomic_dec_64(&krrp_global_pdu_engine_env.ref_cnt);

	kmem_free(engine, sizeof (krrp_pdu_engine_t));
}

void
krrp_pdu_engine_register_callback(krrp_pdu_engine_t *engine,
    krrp_pdu_free_notify_cb_t *notify_cb, void *notify_cb_arg)
{
	VERIFY(notify_cb != NULL);
	VERIFY(engine->notify_free.cb == NULL);

	mutex_enter(&engine->mtx);

	engine->notify_free.cb = notify_cb;
	engine->notify_free.cb_arg = notify_cb_arg;
	engine->notify_free.init_value = engine->max_pdu_cnt >> 3;
	if (engine->notify_free.init_value == 0)
		engine->notify_free.init_value = 1;

	engine->notify_free.cnt = engine->notify_free.init_value;

	mutex_exit(&engine->mtx);
}

void
krrp_pdu_engine_force_notify(krrp_pdu_engine_t *engine, boolean_t initial)
{
	size_t value;

	mutex_enter(&engine->mtx);

	VERIFY(engine->notify_free.cb != NULL);

	if (initial) {
		value = engine->max_pdu_cnt;
		goto out;
	}

	value = engine->notify_free.init_value - engine->notify_free.cnt;
	if (value == 0 && engine->cur_pdu_cnt == 0)
		value = engine->notify_free.init_value;

	engine->notify_free.cnt = engine->notify_free.init_value;

out:
	if (value != 0)
		engine->notify_free.cb(engine->notify_free.cb_arg, value);

	mutex_exit(&engine->mtx);
}

size_t
krrp_pdu_engine_get_used_mem(krrp_pdu_engine_t *pdu_engine)
{
	return (pdu_engine->pdu_data_sz * pdu_engine->cur_pdu_cnt);
}

size_t
krrp_pdu_engine_get_free_mem(krrp_pdu_engine_t *pdu_engine)
{
	size_t free_pdus;

	/*
	 * Mutex is not required here, because this
	 * function is called from zfs-send context,
	 * that does allocation of PDUs.
	 *
	 * Without mutex sometimes free mem may be less
	 * than it actually is, but this is noncritical.
	 */
	free_pdus = pdu_engine->max_pdu_cnt - pdu_engine->cur_pdu_cnt;

	return (pdu_engine->pdu_data_sz * free_pdus);
}

void
krrp_pdu_alloc(krrp_pdu_engine_t *pdu_engine, krrp_pdu_t **result_pdu,
    boolean_t alloc_header)
{
	clock_t time_left = 0;
	krrp_dblk_engine_t *dblk_engine;
	krrp_pdu_t *pdu = NULL;

	VERIFY(pdu_engine != NULL);
	VERIFY(result_pdu != NULL && *result_pdu == NULL);

#ifdef KRRP_PDU_DEBUG
	cmn_err(CE_NOTE, "Init new PDU-[%s]",
	    (pdu_engine->type == KRRP_PET_DATA ? "DATA" : "CTRL"));
#endif

	dblk_engine = pdu_engine->dblk_engine;

	mutex_enter(&pdu_engine->mtx);
	while ((pdu_engine->max_pdu_cnt - pdu_engine->cur_pdu_cnt) == 0) {
		if (time_left == -1) {
			mutex_exit(&pdu_engine->mtx);
			return;
		}

		time_left = cv_reltimedwait(&pdu_engine->cv,
		    &pdu_engine->mtx, MSEC_TO_TICK(500), TR_CLOCK_TICK);
	}

	pdu_engine->cur_pdu_cnt++;
	mutex_exit(&pdu_engine->mtx);

	switch (pdu_engine->type) {
	case KRRP_PET_DATA:
		pdu = kmem_zalloc(sizeof (krrp_pdu_data_t), KM_SLEEP);
		pdu->type = KRRP_PT_DATA;
		break;
	case KRRP_PET_CTRL:
		pdu = kmem_zalloc(sizeof (krrp_pdu_ctrl_t), KM_SLEEP);
		pdu->type = KRRP_PT_CTRL;
		break;
	}

	pdu->max_data_sz = pdu_engine->dblks_per_pdu *
	    dblk_engine->dblk_data_sz;

	if (alloc_header)
		pdu->hdr = kmem_zalloc(sizeof (krrp_hdr_t), KM_SLEEP);

	krrp_dblk_alloc(dblk_engine, &pdu->dblk,
	    pdu_engine->dblks_per_pdu);

	/*
	 * Counter of free PDU is updated by events from dblk-engine,
	 * so if we here, then dblk-engine must not return NULL
	 */
	VERIFY(pdu->dblk != NULL);

	*result_pdu = pdu;
}

void
krrp_pdu_rele(krrp_pdu_t *pdu)
{
	/*
	 * Async rele make sense only if PDU has dblks,
	 * because dblk_rele logic uses locks
	 *
	 * PDU has dblks at receiver side, because PDU initialized
	 * by connection and released by stream
	 *
	 * At sender side PDU does not contain dblk, because PDU intialized
	 * by stream and released by connection, but connection passes dblks
	 * to TCP/IP stack, where dblks are processed and released.
	 */
	if (pdu->dblk == NULL) {
		krrp_pdu_rele_task(pdu);
		return;
	}

	krrp_svc_dispatch_task(krrp_pdu_rele_task, pdu);
}

static void
krrp_pdu_rele_task(void *void_pdu)
{
	krrp_pdu_t *pdu = void_pdu;

#ifdef KRRP_PDU_DEBUG
	cmn_err(CE_NOTE, "RELE PDU: [%d]", pdu->type);
#endif

	if (pdu->dblk != NULL) {
		krrp_dblk_rele(pdu->dblk);
		pdu->dblk = NULL;
	}

	if (pdu->hdr != NULL) {
		kmem_free(pdu->hdr, sizeof (krrp_hdr_t));
		pdu->hdr = NULL;
	}

	switch (pdu->type) {
	case KRRP_PT_DATA:
		kmem_free(pdu, sizeof (krrp_pdu_data_t));
		break;
	case KRRP_PT_CTRL:
		kmem_free(pdu, sizeof (krrp_pdu_ctrl_t));
		break;
	}
}

static void
krrp_pdu_engine_notify_cb(void *void_pdu_engine)
{
	krrp_pdu_engine_t *engine = void_pdu_engine;

	mutex_enter(&engine->mtx);

#ifdef KRRP_PDU_DEBUG
	cmn_err(CE_NOTE, "Dblk rele notification [%d]", engine->type);
#endif

	ASSERT(engine->cur_pdu_cnt > 0);

	engine->cur_pdu_cnt--;
	if (engine->notify_free.cb != NULL) {
		engine->notify_free.cnt--;
		if (engine->notify_free.cnt == 0) {
			engine->notify_free.cnt =
			    engine->notify_free.init_value;
			engine->notify_free.cb(engine->notify_free.cb_arg,
			    engine->notify_free.cnt);
		}
	}

	cv_broadcast(&engine->cv);
	mutex_exit(&engine->mtx);
}

int
krrp_pdu_get_payload(krrp_pdu_ctrl_t *pdu, void **res_data, size_t *res_data_sz)
{
	size_t payload_sz;
	void *data;
	int rc;

	ASSERT(pdu != NULL && pdu->hdr != NULL);
	ASSERT(res_data != NULL && res_data_sz != NULL);

	payload_sz = pdu->hdr->payload_sz;
	if (payload_sz == 0) {
		*res_data = NULL;
		*res_data_sz = 0;
		return (0);
	}

	data = kmem_alloc(payload_sz, KM_SLEEP);
	rc = krrp_dblk_get_data(pdu->dblk, data, payload_sz);
	if (rc != 0) {
		kmem_free(data, payload_sz);
		*res_data = NULL;
		*res_data_sz = 0;
		return (rc);
	}

	*res_data = data;
	*res_data_sz = payload_sz;
	return (0);
}

int
krrp_pdu_get_nvl_from_payload(krrp_pdu_ctrl_t *pdu, nvlist_t **res_nvl)
{
	void *data = NULL;
	size_t data_sz = 0;
	int rc;

	rc = krrp_pdu_get_payload(pdu, &data, &data_sz);
	if (rc != 0)
		return (rc);

	rc = nvlist_unpack(data, data_sz, res_nvl, KM_SLEEP);

	kmem_free(data, data_sz);

	return (rc);
}

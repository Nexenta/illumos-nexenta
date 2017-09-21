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
 * Allocation and release DataBlocks.
 * Two types of allocation of data-block:
 * - from preallocated list (all datablock are preallocated at startup)
 * - by using kmem_cache logic on the fly
 */

#include "krrp_svc.h"
#include "krrp_dblk.h"


static int krrp_dblk_engine_configure(krrp_dblk_engine_t *dblk_engine,
    boolean_t prealloc, krrp_error_t *error);
static int krrp_dblk_init_kmem_alloc_logic(krrp_dblk_engine_t *,
    size_t, krrp_error_t *);
static void krrp_dblk_fini_kmem_alloc_logic(krrp_dblk_engine_t *);
static void krrp_dblk_free_dblk_list(krrp_dblk_list_t *);
static int krrp_dblk_constructor(void *, void *, int);
static void krrp_dblk_constructor_int(krrp_dblk_t *, krrp_dblk_engine_t *);
static void krrp_dblk_free_cb(caddr_t);

static void krrp_dblk_alloc_by_kmem_alloc(krrp_dblk_engine_t *,
    krrp_dblk_t **, size_t);
static void krrp_dblk_alloc_by_kmem_cache_alloc(krrp_dblk_engine_t *,
    krrp_dblk_t **, size_t);


int
krrp_dblk_engine_create(krrp_dblk_engine_t **result_engine,
    boolean_t prealloc, size_t max_dblk_cnt, size_t dblk_head_sz,
    size_t dblk_data_sz, size_t notify_free_value,
    krrp_dblk_free_notify_cb_t *notify_free_cb, void *notify_free_cb_arg,
    krrp_error_t *error)
{
	krrp_dblk_engine_t *dblk_engine;

	VERIFY(result_engine != NULL && *result_engine == NULL);
	VERIFY(max_dblk_cnt != 0);
	VERIFY(dblk_data_sz != 0);
	VERIFY(notify_free_value != 0);
	VERIFY(notify_free_cb != NULL);

	dblk_engine = kmem_zalloc(sizeof (krrp_dblk_engine_t), KM_SLEEP);

	dblk_engine->dblk_head_sz = dblk_head_sz;
	dblk_engine->dblk_data_sz = dblk_data_sz;

	dblk_engine->max_dblk_cnt = max_dblk_cnt;
	dblk_engine->cur_dblk_cnt = 0;

	dblk_engine->notify_free.cb = notify_free_cb;
	dblk_engine->notify_free.cb_arg = notify_free_cb_arg;
	dblk_engine->notify_free.init_value = notify_free_value;
	dblk_engine->notify_free.cnt = notify_free_value;

	if (krrp_dblk_engine_configure(dblk_engine, prealloc, error) != 0) {
		kmem_free(dblk_engine, sizeof (krrp_dblk_engine_t));
		return (-1);
	}

	mutex_init(&dblk_engine->mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&dblk_engine->cv, NULL, CV_DEFAULT, NULL);

	*result_engine = dblk_engine;
	return (0);
}

static void
krrp_dblk_engine_destroy_impl(void *arg)
{
	krrp_dblk_engine_t *engine = arg;

	mutex_enter(&engine->mtx);

	while (engine->cur_dblk_cnt != 0)
		cv_wait(&engine->cv, &engine->mtx);

	switch (engine->type) {
	case KRRP_DET_KMEM_ALLOC:
		krrp_dblk_fini_kmem_alloc_logic(engine);
		break;
	case KRRP_DET_KMEM_CACHE:
		kmem_cache_destroy(engine->dblk_cache);
		break;
	}

	cv_destroy(&engine->cv);

	mutex_exit(&engine->mtx);
	mutex_destroy(&engine->mtx);

	kmem_free(engine, sizeof (krrp_dblk_engine_t));
}

void
krrp_dblk_engine_destroy(krrp_dblk_engine_t *engine)
{
	mutex_enter(&engine->mtx);
	engine->destroying = B_TRUE;
	mutex_exit(&engine->mtx);

	/*
	 * Destroy DBLK Engine asynchronously, because TCP/IP
	 * stack might hold our dblks for a long time
	 */
	krrp_svc_dispatch_task(krrp_dblk_engine_destroy_impl, engine);
}

static int
krrp_dblk_engine_configure(krrp_dblk_engine_t *engine, boolean_t prealloc,
    krrp_error_t *error)
{
	size_t total_dblk_sz;
	int rc = 0;

	total_dblk_sz = sizeof (krrp_dblk_t) + engine->dblk_head_sz +
	    engine->dblk_data_sz;

	if (prealloc) {
		engine->type = KRRP_DET_KMEM_ALLOC;
		engine->alloc_func = &krrp_dblk_alloc_by_kmem_alloc;
		rc = krrp_dblk_init_kmem_alloc_logic(engine,
		    total_dblk_sz, error);
	} else {
		char kmem_cache_name[KSTAT_STRLEN];

		(void) snprintf(kmem_cache_name, KSTAT_STRLEN,
		    "krrp_dec_%p", (void *)engine);

		engine->type = KRRP_DET_KMEM_CACHE;
		engine->alloc_func = &krrp_dblk_alloc_by_kmem_cache_alloc;
		engine->dblk_cache = kmem_cache_create(kmem_cache_name,
		    total_dblk_sz, 8, &krrp_dblk_constructor, NULL, NULL,
		    engine, NULL, KM_SLEEP);
	}

	return (rc);
}

void
krrp_dblk_alloc(krrp_dblk_engine_t *dblk_engine, krrp_dblk_t **dblk,
    size_t number)
{
	dblk_engine->alloc_func(dblk_engine, dblk, number);
}

void
krrp_dblk_rele(krrp_dblk_t *dblk)
{
	krrp_dblk_t *dblk_next;

	while (dblk != NULL) {
		dblk_next = dblk->next;
		dblk->free_rtns.free_func(dblk->free_rtns.free_arg);
		dblk = dblk_next;
	}
}

int
krrp_dblk_get_data(krrp_dblk_t *dblk, void *buf, size_t buf_sz)
{
	size_t buf_remain_sz = buf_sz;
	size_t offset = 0;

	while (dblk != NULL) {
		size_t copy_sz = buf_remain_sz > dblk->cur_data_sz ?
		    dblk->cur_data_sz : buf_remain_sz;
		bcopy(dblk->data, (caddr_t)buf + offset, copy_sz);
		buf_remain_sz -= copy_sz;
		offset += copy_sz;
		if (buf_remain_sz == 0 && dblk->next != NULL)
			return (EINVAL);

		dblk = dblk->next;
	}

	return (0);
}

/*
 * Here we use KM_NOSLEEP to be sure,
 * that the system is not under mem-pressure
 */
static int
krrp_dblk_init_kmem_alloc_logic(krrp_dblk_engine_t *dblk_engine,
    size_t dblk_sz, krrp_error_t *error)
{
	size_t i;
	krrp_dblk_list_t *free_dblks;

	free_dblks = &dblk_engine->free_dblks;

	for (i = 0; i < dblk_engine->max_dblk_cnt; i++) {
		krrp_dblk_t *dblk = kmem_alloc(dblk_sz, KM_NOSLEEP);
		if (dblk == NULL) {
			krrp_error_set(error, KRRP_ERRNO_NOMEM, 0);
			krrp_dblk_fini_kmem_alloc_logic(dblk_engine);
			return (-1);
		}

		krrp_dblk_constructor_int(dblk, dblk_engine);
		if (free_dblks->head == NULL) {
			free_dblks->head = dblk;
		} else {
			free_dblks->tail->next = dblk;
		}

		free_dblks->tail = dblk;
		free_dblks->cnt++;
	}

	return (0);
}

static void
krrp_dblk_fini_kmem_alloc_logic(krrp_dblk_engine_t *dblk_engine)
{
	krrp_dblk_free_dblk_list(&dblk_engine->free_dblks);
}

static void
krrp_dblk_free_dblk_list(krrp_dblk_list_t *dblk_list)
{
	size_t cnt = 0;
	krrp_dblk_t *dblk, *dblk_next;

	dblk = dblk_list->head;
	while (dblk != NULL) {
		dblk_next = dblk->next;
		kmem_free(dblk, dblk->total_sz + sizeof (krrp_dblk_t));
		dblk = dblk_next;
		cnt++;
	}

	VERIFY(dblk_list->cnt == cnt);
	dblk_list->cnt = 0;
}

/*
 * DBLK Allocator: uses preallocated list of dblks
 *
 * allocates requested number of dblks or nothing
 */
static void
krrp_dblk_alloc_by_kmem_alloc(krrp_dblk_engine_t *dblk_engine,
    krrp_dblk_t **result_dblk, size_t number)
{
	krrp_dblk_t *dblk_head = NULL, *dblk_prev = NULL, *dblk;
	size_t cnt = 0;

	krrp_dblk_list_t *free_dblks = &dblk_engine->free_dblks;

	mutex_enter(&dblk_engine->mtx);
	if (free_dblks->cnt < number) {
		mutex_exit(&dblk_engine->mtx);
		return;
	}

	dblk_head = free_dblks->head;
	dblk = dblk_head;

	while (cnt < number) {
		dblk_prev = dblk;
		dblk = dblk->next;
		cnt++;
	}

	dblk_prev->next = NULL;
	free_dblks->cnt -= number;
	free_dblks->head = dblk;
	if (free_dblks->head == NULL)
		free_dblks->tail = NULL;

	dblk_engine->cur_dblk_cnt += number;
	mutex_exit(&dblk_engine->mtx);

	*result_dblk = dblk_head;
}

/*
 * DBLK Allocator: uses kmem_cache
 *
 * allocates requested number of dblks or nothing
 */
static void
krrp_dblk_alloc_by_kmem_cache_alloc(krrp_dblk_engine_t *engine,
    krrp_dblk_t **result_dblk, size_t number)
{
	krrp_dblk_t *dblk_head = NULL, *dblk_next, *dblk = NULL;
	size_t cnt = 0;
	size_t available_cnt;

	mutex_enter(&engine->mtx);
	available_cnt = engine->max_dblk_cnt - engine->cur_dblk_cnt;
	if (available_cnt < number) {
		mutex_exit(&engine->mtx);
		return;
	}

	while (cnt < number) {
		engine->cur_dblk_cnt++;
		dblk_next = kmem_cache_alloc(engine->dblk_cache, KM_SLEEP);

		mutex_exit(&engine->mtx);

		if (dblk_head == NULL)
			dblk_head = dblk_next;
		else
			dblk->next = dblk_next;

		dblk = dblk_next;
		cnt++;

		mutex_enter(&engine->mtx);
	}

	mutex_exit(&engine->mtx);

	*result_dblk = dblk_head;
}

/* ARGSUSED */
static int
krrp_dblk_constructor(void *void_dblk, void *void_dblk_engine, int km_flags)
{
	krrp_dblk_constructor_int(void_dblk, void_dblk_engine);

	return (0);
}

static void
krrp_dblk_constructor_int(krrp_dblk_t *dblk, krrp_dblk_engine_t *dblk_engine)
{
	dblk->engine = dblk_engine;

	dblk->free_rtns.free_func = &krrp_dblk_free_cb;
	dblk->free_rtns.free_arg = (caddr_t)dblk;

	dblk->max_data_sz = dblk_engine->dblk_data_sz;
	dblk->cur_data_sz = 0;
	dblk->head = (((caddr_t)dblk) + sizeof (krrp_dblk_t));
	dblk->data = ((caddr_t)dblk->head + dblk_engine->dblk_head_sz);

	dblk->total_sz = dblk_engine->dblk_head_sz + dblk_engine->dblk_data_sz;
	dblk->next = NULL;
}

static void
krrp_dblk_free_cb(caddr_t void_dblk)
{
	krrp_dblk_t *dblk = (krrp_dblk_t *)void_dblk;
	krrp_dblk_engine_t *dblk_engine = dblk->engine;
	krrp_dblk_list_t *free_dblks;

	mutex_enter(&dblk_engine->mtx);

	dblk->cur_data_sz = 0;
	dblk->next = NULL;

	switch (dblk_engine->type) {
	case KRRP_DET_KMEM_ALLOC:
		free_dblks = &dblk_engine->free_dblks;

		if (free_dblks->head == NULL)
			free_dblks->head = dblk;
		else
			free_dblks->tail->next = dblk;

		free_dblks->tail = dblk;
		free_dblks->cnt++;
		break;
	case KRRP_DET_KMEM_CACHE:
		kmem_cache_free(dblk_engine->dblk_cache, dblk);
		break;
	}

	dblk_engine->cur_dblk_cnt--;
	dblk_engine->notify_free.cnt--;

	if (dblk_engine->notify_free.cnt == 0) {
		dblk_engine->notify_free.cnt =
		    dblk_engine->notify_free.init_value;

		if (!dblk_engine->destroying) {
			dblk_engine->notify_free.cb(
			    dblk_engine->notify_free.cb_arg);
		}
	}

	cv_signal(&dblk_engine->cv);
	mutex_exit(&dblk_engine->mtx);
}

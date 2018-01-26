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
 * Copyright 2018 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * Stream-tasks module.
 * One stream-task is one send/recv operation.
 */

#include <sys/types.h>
#include <sys/kmem.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/sunldi.h>
#include <sys/time.h>
#include <sys/strsubr.h>
#include <sys/sysmacros.h>
#include <sys/socketvar.h>
#include <sys/ksocket.h>
#include <sys/filio.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>
#include <inet/ip.h>

#include <sys/dmu_impl.h>

#include <sys/kreplication_common.h>

#include "krrp_stream_task.h"

#define	KRRP_FAKE_TXG 0x9BC1546914997F6C
#define	USEC2NSEC(m) ((hrtime_t)(m) * (NANOSEC / MICROSEC))

/* #define KRRP_STREAM_TASK_DEBUG 1 */

extern boolean_t krrp_stream_is_write_flag_set(krrp_stream_write_flag_t flags,
    krrp_stream_write_flag_t flag);
extern boolean_t krrp_stream_is_read_flag_set(krrp_stream_read_flag_t flags,
    krrp_stream_read_flag_t flag);

static int krrp_stream_te_common_create(krrp_stream_te_t **result_te,
    const char *dataset, boolean_t read_mode, krrp_error_t *error);

static int krrp_stream_task_constructor(void *, void *, int);
static void krrp_stream_task_destructor(void *, void *);

static krrp_stream_task_shandler_t krrp_stream_task_read_start;
static krrp_stream_task_shandler_t krrp_stream_task_common_stop;

static krrp_stream_task_shandler_t krrp_stream_task_fake_common_action;

static krrp_stream_task_handler_t krrp_stream_task_fake_write_handler;
static krrp_stream_task_handler_t krrp_stream_task_write_handler;
static krrp_stream_task_handler_t krrp_stream_task_fake_read_handler;
static krrp_stream_task_handler_t krrp_stream_task_read_handler;

static void krrp_stream_task_correct_total_size(krrp_dblk_t *, size_t *);

static void krrp_stream_task_fake_rate_limit(krrp_stream_task_t *,
    hrtime_t, uint32_t);

uint32_t krrp_stream_fake_rate_limit_mb = 0;

int
krrp_stream_te_read_create(krrp_stream_te_t **result_te,
    const char *dataset, krrp_stream_read_flag_t flags,
    krrp_check_enough_mem *mem_check_cb, void *mem_check_cb_arg,
    krrp_error_t *error)
{
	int rc;
	krrp_stream_te_t *task_engine;

	ASSERT(dataset != NULL);

	rc = krrp_stream_te_common_create(result_te,
	    dataset, B_TRUE, error);
	if (rc != 0)
		return (-1);

	task_engine = *result_te;

	task_engine->recursive =
	    krrp_stream_is_read_flag_set(flags, KRRP_STRMRF_RECURSIVE);
	task_engine->properties =
	    krrp_stream_is_read_flag_set(flags, KRRP_STRMRF_SEND_PROPS);
	task_engine->enable_cksum =
	    krrp_stream_is_read_flag_set(flags, KRRP_STRMRF_ENABLE_CHKSUM);
	task_engine->embedded =
	    krrp_stream_is_read_flag_set(flags, KRRP_STRMRF_EMBEDDED);
	task_engine->compressed =
	    krrp_stream_is_read_flag_set(flags, KRRP_STRMRF_COMPRESSED);
	task_engine->large_blocks =
	    krrp_stream_is_read_flag_set(flags, KRRP_STRMRF_LARGE_BLOCKS);
	task_engine->incremental_package =
	    krrp_stream_is_read_flag_set(flags, KRRP_STRMRF_SEND_ALL_SNAPS);

	task_engine->mem_check_cb = mem_check_cb;
	task_engine->mem_check_cb_arg = mem_check_cb_arg;

	return (0);
}

int
krrp_stream_te_write_create(krrp_stream_te_t **result_te,
    const char *dataset, krrp_stream_write_flag_t flags,
    nvlist_t *ignore_props_list, nvlist_t *replace_props_list,
    krrp_error_t *error)
{
	int rc;
	krrp_stream_te_t *task_engine;

	ASSERT(dataset != NULL);

	rc = krrp_stream_te_common_create(result_te,
	    dataset, B_FALSE, error);
	if (rc != 0)
		return (-1);

	task_engine = *result_te;

	task_engine->force_receive =
	    krrp_stream_is_write_flag_set(flags, KRRP_STRMWF_FORCE_RECV);
	task_engine->enable_cksum =
	    krrp_stream_is_write_flag_set(flags, KRRP_STRMWF_ENABLE_CHKSUM);
	task_engine->discard_head =
	    krrp_stream_is_write_flag_set(flags, KRRP_STRMWF_DISCARD_HEAD);
	task_engine->leave_tail =
	    krrp_stream_is_write_flag_set(flags, KRRP_STRMWF_LEAVE_TAIL);

	/*
	 * Need to dup the nvls because they are part of another nvl,
	 * that will be destroyed
	 */
	if (ignore_props_list != NULL) {
		task_engine->ignore_props_list =
		    fnvlist_dup(ignore_props_list);
	}

	if (replace_props_list != NULL) {
		task_engine->replace_props_list =
		    fnvlist_dup(replace_props_list);
	}

	return (0);
}

int
krrp_stream_te_fake_read_create(krrp_stream_te_t **result_te,
    krrp_error_t *error)
{
	return (krrp_stream_te_common_create(result_te,
	    NULL, B_TRUE, error));
}

int
krrp_stream_te_fake_write_create(krrp_stream_te_t **result_te,
    krrp_error_t *error)
{
	return (krrp_stream_te_common_create(result_te,
	    NULL, B_FALSE, error));
}

void
krrp_stream_te_destroy(krrp_stream_te_t *task_engine)
{
	krrp_stream_task_t *task;

	while ((task = krrp_queue_get_no_wait(task_engine->tasks)) != NULL)
		krrp_stream_task_fini(task);

	krrp_queue_fini(task_engine->tasks);

	if (task_engine->mode == KRRP_STEM_READ) {
		while ((task = krrp_queue_get_no_wait(
		    task_engine->tasks_done)) != NULL)
			krrp_stream_task_fini(task);

		krrp_queue_fini(task_engine->tasks_done);

		while ((task = krrp_queue_get_no_wait(
		    task_engine->tasks_done2)) != NULL)
			krrp_stream_task_fini(task);

		krrp_queue_fini(task_engine->tasks_done2);
	}

	kmem_cache_destroy(task_engine->tasks_cache);

	if (task_engine->global_zfs_ctx != NULL) {
		dmu_krrp_stream_fini(task_engine->global_zfs_ctx);
		task_engine->global_zfs_ctx = NULL;
	}

	if (task_engine->ignore_props_list != NULL)
		fnvlist_free(task_engine->ignore_props_list);

	if (task_engine->replace_props_list != NULL)
		fnvlist_free(task_engine->replace_props_list);

	kmem_free(task_engine, sizeof (krrp_stream_te_t));
}

static int
krrp_stream_te_common_create(krrp_stream_te_t **result_te,
    const char *dataset, boolean_t read_mode, krrp_error_t *error)
{
	krrp_stream_te_t *task_engine;
	char kmem_cache_name[KSTAT_STRLEN];

	ASSERT(result_te != NULL && *result_te == NULL);

	task_engine = kmem_zalloc(sizeof (krrp_stream_te_t), KM_SLEEP);

	if (dataset != NULL) {
		task_engine->global_zfs_ctx = dmu_krrp_stream_init();
		if (task_engine->global_zfs_ctx == NULL) {
			kmem_free(task_engine, sizeof (krrp_stream_te_t));
			krrp_error_set(error, KRRP_ERRNO_ZFSGCTXFAIL, 0);
			return (-1);
		}

		task_engine->dataset = dataset;
	} else
		task_engine->fake_mode = B_TRUE;

	krrp_queue_init(&task_engine->tasks, sizeof (krrp_stream_task_t),
	    offsetof(krrp_stream_task_t, node));

	(void) snprintf(kmem_cache_name, KSTAT_STRLEN,
	    "krrp_stc_%p", (void *)task_engine);

	task_engine->tasks_cache = kmem_cache_create(kmem_cache_name,
	    sizeof (krrp_stream_task_t), 0, &krrp_stream_task_constructor,
	    &krrp_stream_task_destructor, NULL, (void *)task_engine,
	    NULL, KM_SLEEP);

	if (read_mode) {
		task_engine->mode = KRRP_STEM_READ;
		/*
		 * This queue contains tasks, that were completely read
		 * from ZFS and are being sent to the receiver
		 */
		krrp_queue_init(&task_engine->tasks_done,
		    sizeof (krrp_stream_task_t),
		    offsetof(krrp_stream_task_t, node));
		/*
		 * This queue contains tasks/threads waiting to receive
		 * acknowledgement from the receiver that the sent blocks
		 * have been written to the disk.
		 */
		krrp_queue_init(&task_engine->tasks_done2,
		    sizeof (krrp_stream_task_t),
		    offsetof(krrp_stream_task_t, node));
	} else
		task_engine->mode = KRRP_STEM_WRITE;

	*result_te = task_engine;

	return (0);
}

/*
 * Total number of task is the sum of tasks that are:
 *   waiting for write to ZFS on the receiver (task_engine->tasks_done2)
 *
 *   waiting for read from ZFS or in process of being sent to the receiver
 *     task_engine->tasks + task_engine->tasks_done
 */
size_t
krrp_stream_te_total_num_tasks(krrp_stream_te_t *task_engine)
{
	return (krrp_queue_length(task_engine->tasks) +
	    krrp_queue_length(task_engine->tasks_done) +
	    krrp_queue_length(task_engine->tasks_done2));
}

/*
 * Pending tasks are the tasks, that are waiting for read from ZFS
 */
size_t
krrp_stream_te_num_pending_tasks(krrp_stream_te_t *task_engine)
{
	return (krrp_queue_length(task_engine->tasks));
}

void
krrp_stream_read_task_init(krrp_stream_te_t *task_engine, uint64_t txg,
    const char *src_snap, const char *src_inc_snap, nvlist_t *resume_info)
{
	ASSERT(task_engine->mode == KRRP_STEM_READ);

	ASSERT(src_snap != NULL && strlen(src_snap) != 0);

	krrp_stream_task_t *task;

	task = kmem_cache_alloc(task_engine->tasks_cache, KM_SLEEP);

	task->txg = txg;

	(void) strlcpy(task->zargs.from_snap, src_snap,
	    sizeof (task->zargs.from_snap));
	if (src_inc_snap != NULL)
		(void) strlcpy(task->zargs.from_incr_base, src_inc_snap,
		    sizeof (task->zargs.from_incr_base));
	else
		task->zargs.from_incr_base[0] = '\0';

	task->zargs.resume_info =
	    resume_info != NULL ? fnvlist_dup(resume_info) : NULL;

	task->init_hrtime = gethrtime();

	krrp_queue_put(task_engine->tasks, task);
}

void
krrp_stream_fake_read_task_init(krrp_stream_te_t *task_engine,
    uint64_t fake_data_sz)
{
	ASSERT(task_engine->mode == KRRP_STEM_READ);
	ASSERT(fake_data_sz != 0);

	krrp_stream_task_t *task;

	task = kmem_cache_alloc(task_engine->tasks_cache, KM_SLEEP);

	task->txg = KRRP_FAKE_TXG;
	task->fake_data_sz = fake_data_sz;
	task->init_hrtime = gethrtime();

	krrp_queue_put(task_engine->tasks, task);
}

void
krrp_stream_write_task_init(krrp_stream_te_t *task_engine, uint64_t txg,
    krrp_stream_task_t **result_task, nvlist_t *resume_info)
{
	ASSERT(task_engine->mode == KRRP_STEM_WRITE);

	krrp_stream_task_t *task;

	task = kmem_cache_alloc(task_engine->tasks_cache, KM_SLEEP);

	task->txg = txg;

	task->txg_start = UINT64_MAX;
	task->txg_end = UINT64_MAX;

	task->zargs.resume_info =
	    resume_info != NULL ? fnvlist_dup(resume_info) : NULL;

	if (!task_engine->fake_mode)
		task->zfs_ctx = dmu_krrp_init_recv_task(&task->zargs);

	*result_task = task;
}

hrtime_t
krrp_stream_task_calc_rpo(krrp_stream_task_t *task)
{
	ASSERT(task->engine->mode == KRRP_STEM_READ);

	return (gethrtime() - task->init_hrtime);
}

void
krrp_stream_task_fini(krrp_stream_task_t *task)
{
	krrp_stream_te_t *task_engine = task->engine;

	task->txg = 0;
	task->zfs_ctx = NULL;
	task->done = B_FALSE;

	kmem_cache_free(task_engine->tasks_cache, task);
}

void
krrp_stream_task_engine_get_task(krrp_stream_te_t *task_engine,
    krrp_stream_task_t **result_stream_task)
{
	*result_stream_task = krrp_queue_get(task_engine->tasks);
}

/* ARGSUSED */
static int
krrp_stream_task_constructor(void *opaque_task,
    void *opaque_task_engine, int km_flags)
{
	krrp_stream_task_t *task = opaque_task;
	krrp_stream_te_t *task_engine = opaque_task_engine;

	bzero(&task->zargs, sizeof (kreplication_zfs_args_t));

	task->zargs.stream_handler = task_engine->global_zfs_ctx;
	task->zargs.force_cksum = task_engine->enable_cksum;

	switch (task_engine->mode) {
	case KRRP_STEM_READ:
		if (task_engine->fake_mode) {
			task->process = &krrp_stream_task_fake_read_handler;
			task->start = &krrp_stream_task_fake_common_action;
			task->shutdown = &krrp_stream_task_fake_common_action;
		} else {
			(void) strlcpy(task->zargs.from_ds,
			    task_engine->dataset,
			    sizeof (task->zargs.from_ds));

			task->process = &krrp_stream_task_read_handler;
			task->start = &krrp_stream_task_read_start;
			task->shutdown = &krrp_stream_task_common_stop;

			task->zargs.mem_check_cb =
			    task_engine->mem_check_cb;
			task->zargs.mem_check_cb_arg =
			    task_engine->mem_check_cb_arg;
		}

		task->zargs.do_all = task_engine->incremental_package;
		task->zargs.properties = task_engine->properties;
		task->zargs.recursive = task_engine->recursive;
		task->zargs.embedok = task_engine->embedded;
		task->zargs.compressok = task_engine->compressed;
		task->zargs.large_block_ok = task_engine->large_blocks;

		break;
	case KRRP_STEM_WRITE:
		if (task_engine->fake_mode) {
			task->process = &krrp_stream_task_fake_write_handler;
			task->shutdown = &krrp_stream_task_fake_common_action;
		} else {
			(void) strlcpy(task->zargs.to_ds, task_engine->dataset,
			    sizeof (task->zargs.to_ds));

			task->process = &krrp_stream_task_write_handler;
			task->shutdown = &krrp_stream_task_common_stop;
		}

		task->zargs.force = task_engine->force_receive;
		task->zargs.ignore_list = task_engine->ignore_props_list;
		task->zargs.replace_list = task_engine->replace_props_list;
		task->zargs.strip_head = task_engine->discard_head;
		task->zargs.leave_tail = task_engine->leave_tail;

		break;
	default:
		VERIFY(0);
		break;
	}

	if (task_engine->fake_mode) {
		mutex_init(&task->mtx, NULL, MUTEX_DEFAULT, NULL);
		cv_init(&task->cv, NULL, CV_DEFAULT, NULL);
	}

	task->engine = task_engine;

	task->txg = 0;
	task->zfs_ctx = NULL;
	task->done = B_FALSE;

	return (0);
}

static void
krrp_stream_task_destructor(void *opaque_task,
    void *opaque_task_engine)
{
	krrp_stream_task_t *task = opaque_task;
	krrp_stream_te_t *task_engine = opaque_task_engine;

	if (task_engine->fake_mode) {
		cv_destroy(&task->cv);
		mutex_destroy(&task->mtx);
	}
}

static int
krrp_stream_task_fake_write_handler(krrp_stream_task_t *task,
    krrp_pdu_data_t *pdu)
{
	krrp_stream_task_fake_rate_limit(task,
	    gethrtime(), pdu->cur_data_sz);

	if (pdu->final)
		task->done = B_TRUE;

	return (0);
}

static int
krrp_stream_task_write_handler(krrp_stream_task_t *task, krrp_pdu_data_t *pdu)
{
	int rc = 0;
	kreplication_buffer_t *kr_buf = NULL;

	kr_buf = (kreplication_buffer_t *)pdu->dblk;

	ASSERT(task->zfs_ctx != NULL);

	if (pdu->final)
		task->done = B_TRUE;

	if (kr_buf->data_size != 0)
		rc = dmu_krrp_lend_recv_buffer(task->zfs_ctx, kr_buf);

#ifdef KRRP_STREAM_TASK_DEBUG
	VERIFY3U(rc, ==, 0);
#endif

	return (rc);
}

static int
krrp_stream_task_fake_read_handler(krrp_stream_task_t *task,
    krrp_pdu_data_t *pdu)
{
	krrp_dblk_t *dblk;
	hrtime_t start = gethrtime();

	dblk = pdu->dblk;

	while (dblk != NULL) {
		if (task->fake_data_sz > dblk->max_data_sz)
			dblk->cur_data_sz = dblk->max_data_sz;
		else
			dblk->cur_data_sz = task->fake_data_sz;

		task->fake_data_sz -= dblk->cur_data_sz;
		pdu->cur_data_sz += dblk->cur_data_sz;

		if (task->fake_data_sz == 0) {
			if (dblk->next == NULL) {
				pdu->cur_data_sz -= dblk->cur_data_sz;
				dblk->cur_data_sz = 0;
			}

			pdu->final = B_TRUE;
			task->done = B_TRUE;
			break;
		}

		dblk = dblk->next;
	}

	pdu->txg = task->txg;

	krrp_stream_task_fake_rate_limit(task, start, pdu->cur_data_sz);

	return (0);
}

static void
krrp_stream_task_fake_rate_limit(krrp_stream_task_t *task,
    hrtime_t start_time, uint32_t data_sz)
{
	hrtime_t diff, delay;

	if (krrp_stream_fake_rate_limit_mb == 0 || data_sz == 0) {
		DTRACE_PROBE1(rate_limit_delay1, uint64_t, 0);
		return;
	}

	diff = gethrtime() - start_time;
	delay = ((hrtime_t)data_sz * NANOSEC) /
	    ((hrtime_t)krrp_stream_fake_rate_limit_mb * 1024 * 1024);
	if (diff > delay) {
		DTRACE_PROBE2(rate_limit_delay2, uint64_t, diff,
		    uint64_t, delay);
		return;
	}

	delay = delay - diff;

	DTRACE_PROBE1(rate_limit_delay3, uint64_t, delay);

	mutex_enter(&task->mtx);
	(void) cv_timedwait_hires(&task->cv, &task->mtx,
	    delay, USEC2NSEC(100), CALLOUT_FLAG_ROUNDUP);
	mutex_exit(&task->mtx);

	diff = gethrtime() - start_time;
	DTRACE_PROBE2(rate_limit_delay4, uint64_t, delay, uint64_t, diff);
}

static int
krrp_stream_task_read_handler(krrp_stream_task_t *task, krrp_pdu_data_t *pdu)
{
	int rc = 0;
	kreplication_buffer_t *kr_buf = NULL;

	kr_buf = (kreplication_buffer_t *)pdu->dblk;

	ASSERT(task->zfs_ctx != NULL);

	pdu->txg = task->txg;

	/*
	 * dmu_krrp_lend_send_buffer always fill all available space.
	 * only in case of ENODATA it may not fill all available space.
	 */
	pdu->cur_data_sz = pdu->max_data_sz;
	rc = dmu_krrp_lend_send_buffer(task->zfs_ctx, kr_buf);

	/* so in this case need to recalculate total size */
	if (rc == ENODATA) {
		pdu->final = B_TRUE;
		task->done = B_TRUE;
		rc = 0;
		pdu->cur_data_sz = 0;
		krrp_stream_task_correct_total_size(pdu->dblk,
		    &pdu->cur_data_sz);
		VERIFY3U(pdu->cur_data_sz, <=, pdu->max_data_sz);
	}

#ifdef KRRP_STREAM_TASK_DEBUG
	VERIFY3U(rc, ==, 0);
#endif

	return (rc);
}

static void
krrp_stream_task_read_start(krrp_stream_task_t *task)
{
	task->zfs_ctx = dmu_krrp_init_send_task(&task->zargs);
}

/* ARGSUSED */
static void
krrp_stream_task_fake_common_action(krrp_stream_task_t *task)
{
	/* nothing to do */
}

static void
krrp_stream_task_common_stop(krrp_stream_task_t *task)
{
	ASSERT(task->zfs_ctx != NULL);

#ifdef KRRP_STREAM_TASK_DEBUG
	VERIFY3U(dmu_krrp_fini_task(task->zfs_ctx), ==, 0);
#else
	(void) dmu_krrp_fini_task(task->zfs_ctx);
#endif

	task->zfs_ctx = NULL;
}

static void
krrp_stream_task_correct_total_size(krrp_dblk_t *dblk_head,
    size_t *total_data_sz)
{
	krrp_dblk_t *dblk;

	dblk = dblk_head;
	while (dblk != NULL) {
		*total_data_sz += dblk->cur_data_sz;
		if (dblk->cur_data_sz == 0)
			break;

		dblk = dblk->next;
	}
}

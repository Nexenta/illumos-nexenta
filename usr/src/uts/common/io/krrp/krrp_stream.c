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
 * Stream module
 */

#include <sys/types.h>
#include <sys/kmem.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/sunldi.h>
#include <sys/time.h>
#include <sys/sdt.h>
#include <sys/sysmacros.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>

#include "krrp_stream.h"

#define	is_str_empty(str) (str[0] == '\0')

#define	copy_str(dst_str, src_str, dst_str_max_sz) \
	((strlcpy(dst_str, src_str, dst_str_max_sz) < dst_str_max_sz) ? 0 : -1)

/* #define	KRRP_STREAM_DEBUG 1 */

/*
 * This variable is a safeguard for the continuous replication sessions.
 * It defines additional number of read-tasks per one session.
 * Each read-task is an autosnapshot for such sessions.
 * When the total number of read-tasks reach value that equal
 * keep_snaps + krrp_add_num_read_tasks then the corresponding
 * session will stop confirmation of create-requests from Autosnap.
 */
size_t krrp_add_num_read_tasks = 5;


/* These extern functions are part of ZFS sources */
extern int wbc_check_dataset(const char *name);
extern uint64_t dsl_dataset_creation_txg(const char *name);
extern int dmu_krrp_decode_resume_token(const char *resume_token,
    nvlist_t **resume_info);


typedef void (krrp_stream_handler_t)(void *);

static krrp_stream_t *krrp_stream_common_create(void);
static void krrp_stream_task_done(krrp_stream_t *, krrp_stream_task_t *,
    boolean_t);
static void krrp_stream_callback(krrp_stream_t *, krrp_stream_cb_ev_t,
    uintptr_t);

static void krrp_stream_calc_avg_rpo(krrp_stream_t *, krrp_stream_task_t *,
    boolean_t);
static void krrp_stream_read(void *);
static void krrp_stream_write(void *);

static int krrp_stream_activate_autosnap(krrp_stream_t *stream,
    krrp_error_t *error);
static void krrp_stream_autosnap_restore_cb(void *void_stream,
    const char *snap_name, uint64_t txg);

static int krrp_stream_validate_run(krrp_stream_t *stream,
    krrp_error_t *error);

static uint64_t krrp_stream_get_snap_txg(krrp_stream_t *stream,
    const char *short_snap_name);

static boolean_t
krrp_stream_check_mem(size_t required_mem, void *void_stream);

#if 0
static void krrp_stream_debug(const char *, void *, void *, void *, void *);
#endif

static void krrp_stream_snap_create_error_cb(const char *, int,
    uint64_t, void *);
static boolean_t krrp_stream_read_snap_confirm_cb(const char *, boolean_t,
    uint64_t, void *);
static boolean_t krrp_stream_write_snap_notify_cb(const char *, boolean_t,
    boolean_t, uint64_t, uint64_t, void *);
static boolean_t krrp_stream_read_snap_notify_cb(const char *, boolean_t,
    boolean_t, uint64_t, uint64_t, void *);

int
krrp_stream_read_create(krrp_stream_t **result_stream,
    size_t keep_snaps, const char *dataset, const char *base_snap_name,
    const char *incr_snap_name, const char *resume_token,
    krrp_stream_read_flag_t flags, const char *skip_snaps_mask,
    krrp_error_t *error)
{
	krrp_stream_t *stream;
	int rc;

	VERIFY(result_stream != NULL && *result_stream == NULL);
	VERIFY(dataset != NULL);

	stream = krrp_stream_common_create();

	stream->notify_txg = UINT64_MAX;
	stream->mode = KRRP_STRMM_READ;
	stream->recursive =
	    krrp_stream_is_read_flag_set(flags, KRRP_STRMRF_RECURSIVE);
	stream->keep_snaps = keep_snaps;

	rc = copy_str(stream->dataset, dataset, sizeof (stream->dataset));
	if (rc != 0 || is_str_empty(dataset)) {
		krrp_error_set(error, KRRP_ERRNO_SRCDS, EINVAL);
		goto err;
	}

	/* Source and Common snapshots must not be equal */
	if (base_snap_name != NULL && incr_snap_name != NULL &&
	    strcmp(base_snap_name, incr_snap_name) == 0) {
		krrp_error_set(error, KRRP_ERRNO_STREAM, EINVAL);
		goto err;
	}

	/*
	 * If base_snap_name is defined then the stream will be non_continuous,
	 * that means: only one task will be processed
	 */
	if (base_snap_name != NULL) {
		stream->non_continuous = B_TRUE;

		rc = copy_str(stream->base_snap_name, base_snap_name,
		    sizeof (stream->base_snap_name));
		if (rc != 0 || is_str_empty(base_snap_name)) {
			krrp_error_set(error, KRRP_ERRNO_SRCSNAP, EINVAL);
			goto err;
		}

		if (resume_token != NULL) {
			rc = dmu_krrp_decode_resume_token(resume_token,
			    &stream->resume_info);
			if (rc != 0) {
				krrp_error_set(error,
				    KRRP_ERRNO_RESUMETOKEN, rc);
				goto err;
			}
		}
	}

	if (incr_snap_name != NULL) {
		rc = copy_str(stream->incr_snap_name, incr_snap_name,
		    sizeof (stream->incr_snap_name));
		if (rc != 0 || is_str_empty(incr_snap_name)) {
			krrp_error_set(error, KRRP_ERRNO_CMNSNAP, EINVAL);
			goto err;
		}
	}

	rc = krrp_stream_te_read_create(&stream->task_engine,
	    stream->dataset, flags, &krrp_stream_check_mem,
	    stream, skip_snaps_mask, error);
	if (rc != 0)
		goto err;

	krrp_autosnap_rside_create(&stream->autosnap,
	    stream->keep_snaps, stream->dataset, stream->recursive);

	*result_stream = stream;

	return (0);

err:
	krrp_stream_destroy(stream);

	return (-1);
}

int
krrp_stream_write_create(krrp_stream_t **result_stream,
    size_t keep_snaps, const char *dataset, const char *incr_snap_name,
    const char *resume_token, krrp_stream_write_flag_t flags,
    nvlist_t *ignore_props_list, nvlist_t *replace_props_list,
    krrp_error_t *error)
{
	krrp_stream_t *stream;
	int rc;

	VERIFY(result_stream != NULL && *result_stream == NULL);
	VERIFY(dataset != NULL);

	stream = krrp_stream_common_create();

	stream->mode = KRRP_STRMM_WRITE;
	stream->keep_snaps = keep_snaps;

	rc = copy_str(stream->dataset, dataset, sizeof (stream->dataset));
	if (rc != 0 || is_str_empty(dataset)) {
		krrp_error_set(error, KRRP_ERRNO_DSTDS, EINVAL);
		goto err;
	}

	if (resume_token != NULL) {
		rc = dmu_krrp_decode_resume_token(resume_token,
		    &stream->resume_info);
		if (rc != 0) {
			krrp_error_set(error,
			    KRRP_ERRNO_RESUMETOKEN, rc);
			goto err;
		}
	}

	if (incr_snap_name != NULL) {
		rc = copy_str(stream->incr_snap_name, incr_snap_name,
		    sizeof (stream->incr_snap_name));
		if (rc != 0 || is_str_empty(incr_snap_name)) {
			krrp_error_set(error, KRRP_ERRNO_CMNSNAP, EINVAL);
			goto err;
		}
	}

	rc = krrp_stream_te_write_create(&stream->task_engine,
	    stream->dataset, flags, ignore_props_list,
	    replace_props_list, error);
	if (rc != 0)
		goto err;

	krrp_autosnap_wside_create(&stream->autosnap,
	    stream->keep_snaps, stream->dataset);

	*result_stream = stream;

	return (0);

err:
	krrp_stream_destroy(stream);

	return (-1);
}

int
krrp_stream_fake_read_create(krrp_stream_t **result_stream,
    uint64_t fake_data_sz, krrp_error_t *error)
{
	int rc = -1;
	krrp_stream_t *stream;

	VERIFY(result_stream != NULL && *result_stream == NULL);

	if (fake_data_sz == 0) {
		krrp_error_set(error, KRRP_ERRNO_FAKEDSZ, EINVAL);
		goto out;
	}

	stream = krrp_stream_common_create();

	stream->mode = KRRP_STRMM_READ;
	stream->fake_mode = B_TRUE;
	stream->non_continuous = B_TRUE;
	stream->fake_data_sz = fake_data_sz;

	/* Fake never fails */
	VERIFY(krrp_stream_te_fake_read_create(&stream->task_engine,
	    error) == 0);

	*result_stream = stream;
	rc = 0;

out:
	return (rc);
}

int
krrp_stream_fake_write_create(krrp_stream_t **result_stream,
    krrp_error_t *error)
{
	krrp_stream_t *stream;

	VERIFY(result_stream != NULL && *result_stream == NULL);

	stream = krrp_stream_common_create();

	stream->mode = KRRP_STRMM_WRITE;
	stream->fake_mode = B_TRUE;
	stream->non_continuous = B_TRUE;

	/* Fake never fails */
	VERIFY(krrp_stream_te_fake_write_create(&stream->task_engine,
	    error) == 0);

	*result_stream = stream;

	return (0);
}

static krrp_stream_t *
krrp_stream_common_create(void)
{
	krrp_stream_t *stream;

	stream = kmem_zalloc(sizeof (krrp_stream_t), KM_SLEEP);

	mutex_init(&stream->mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&stream->cv, NULL, CV_DEFAULT, NULL);

	stream->state = KRRP_STRMS_CREATED;

	return (stream);
}

void
krrp_stream_destroy(krrp_stream_t *stream)
{
	krrp_stream_lock(stream);

	stream->state = KRRP_STRMS_STOPPED;
	while (stream->work_thread != NULL)
		krrp_stream_cv_wait(stream);

	if (stream->autosnap != NULL)
		krrp_autosnap_destroy(stream->autosnap);

	if (stream->task_engine != NULL)
		krrp_stream_te_destroy(stream->task_engine);

	if (stream->resume_info != NULL)
		fnvlist_free(stream->resume_info);

	krrp_stream_unlock(stream);

	cv_destroy(&stream->cv);
	mutex_destroy(&stream->mtx);

	kmem_free(stream, sizeof (krrp_stream_t));
}

static boolean_t
krrp_stream_check_mem(size_t required_mem, void *void_stream)
{
	krrp_stream_t *stream = void_stream;
	size_t available_mem =
	    krrp_pdu_engine_get_free_mem(stream->data_pdu_engine);

	if (available_mem < required_mem)
		return (B_FALSE);

	return (B_TRUE);
}

void
krrp_stream_register_callback(krrp_stream_t *stream,
    krrp_stream_cb_t *ev_cb, void *ev_cb_arg)
{
	VERIFY(ev_cb != NULL);

	krrp_stream_lock(stream);
	VERIFY(stream->state == KRRP_STRMS_CREATED);

	stream->state = KRRP_STRMS_READY_TO_RUN;
	stream->callback = ev_cb;
	stream->callback_arg = ev_cb_arg;

	krrp_stream_unlock(stream);
}

int
krrp_stream_run(krrp_stream_t *stream, krrp_queue_t *write_data_queue,
    krrp_pdu_engine_t *data_pdu_engine, krrp_error_t *error)
{
	int rc = -1;

	VERIFY(data_pdu_engine != NULL);
	VERIFY(data_pdu_engine->type == KRRP_PET_DATA);
	VERIFY(write_data_queue != NULL);

	krrp_stream_lock(stream);
	VERIFY(stream->state == KRRP_STRMS_READY_TO_RUN);

	stream->data_pdu_engine = data_pdu_engine;
	stream->write_data_queue = write_data_queue;

	if (!stream->fake_mode) {
		if (krrp_stream_validate_run(stream, error) != 0)
			goto out;

		if (krrp_stream_activate_autosnap(stream, error) != 0)
			goto out;
	}

	/* thread_create never fails */
	switch (stream->mode) {
	case KRRP_STRMM_READ:
		if (stream->fake_mode)
			krrp_stream_fake_read_task_init(stream->task_engine,
			    stream->fake_data_sz);

		stream->work_thread = thread_create(NULL, 0, &krrp_stream_read,
		    stream, 0, &p0, TS_RUN, minclsyspri);
		break;
	case KRRP_STRMM_WRITE:
		stream->work_thread = thread_create(NULL, 0, &krrp_stream_write,
		    stream, 0, &p0, TS_RUN, minclsyspri);
		break;
	}

	while (stream->state == KRRP_STRMS_READY_TO_RUN)
		krrp_stream_cv_wait(stream);

	rc = 0;

out:
	krrp_stream_unlock(stream);
	return (rc);
}

void
krrp_stream_stop(krrp_stream_t *stream)
{
	krrp_stream_lock(stream);
	VERIFY(stream->state == KRRP_STRMS_ACTIVE ||
	    stream->state == KRRP_STRMS_IN_ERROR);

	stream->state = KRRP_STRMS_STOPPED;
	krrp_stream_cv_broadcast(stream);

	if (!stream->non_continuous)
		krrp_autosnap_deactivate(stream->autosnap);

	krrp_stream_unlock(stream);
}

int
krrp_stream_send_stop(krrp_stream_t *stream)
{
	int rc = -1;

	ASSERT(stream->mode == KRRP_STRMM_READ);
	ASSERT(!stream->non_continuous);

	if (stream->notify_txg == UINT64_MAX) {
		krrp_autosnap_create_snapshot(stream->autosnap);

		/*
		 * To deactivate autosnap-logic need to be sure
		 * that an autosnap has been created
		 *
		 * Autosnap-service may delay creation of snapshot,
		 * so here we may wait for some time (1-2 transactions)
		 */
		krrp_stream_lock(stream);

		stream->wait_for_snap = B_TRUE;
		while (stream->wait_for_snap &&
		    stream->state == KRRP_STRMS_ACTIVE)
			krrp_stream_cv_wait(stream);

		krrp_stream_unlock(stream);

		krrp_autosnap_deactivate(stream->autosnap);

		rc = 0;
	}

	return (rc);
}

static int
krrp_stream_validate_run(krrp_stream_t *stream, krrp_error_t *error)
{
	int rc = -1;

	/*
	 * The SOURCE datasets must exist always
	 *
	 * The DESTINATION dataset may not exist, that is allowed,
	 * but if incr_snap_name is defined therefore this replication
	 * is incremental and destination dataset must exist, exclude
	 * the cases if the destination dataset is a ZFS pool (the name
	 * does not contain '/'). For all other cases the parent of
	 * the destination dataset must exist.
	 */
	if (dsl_dataset_creation_txg(stream->dataset) == UINT64_MAX) {
		if (stream->mode == KRRP_STRMM_READ) {
			krrp_error_set(error, KRRP_ERRNO_SRCDS, ENOENT);
			goto out;
		} else {
			char *p;
			boolean_t parent_exists = B_TRUE;
			boolean_t dst_is_pool = B_TRUE;

			p = strrchr(stream->dataset, '/');
			if (p != NULL) {
				*p = '\0';
				parent_exists =
				    dsl_dataset_creation_txg(stream->dataset) !=
				    UINT64_MAX;
				*p = '/';
				dst_is_pool = B_FALSE;
			}

			if (dst_is_pool || !parent_exists ||
			    strlen(stream->incr_snap_name) != 0) {
				krrp_error_set(error, KRRP_ERRNO_DSTDS, ENOENT);
				goto out;
			}
		}
	}

	rc = 0;
	if (stream->mode == KRRP_STRMM_READ && !stream->non_continuous) {
		rc = wbc_check_dataset(stream->dataset);
		if (rc == 0 || rc == ENOTACTIVE)
			rc = 0;
		else
			krrp_error_set(error, KRRP_ERRNO_STREAM, rc);
	}

out:
	return (rc);
}

static int
krrp_stream_activate_autosnap(krrp_stream_t *stream,
    krrp_error_t *error)
{
	uint64_t incr_snap_txg = UINT64_MAX;
	int rc = -1;

	if (strlen(stream->incr_snap_name) != 0) {
		incr_snap_txg = krrp_stream_get_snap_txg(stream,
		    stream->incr_snap_name);
		if (incr_snap_txg == UINT64_MAX) {
			krrp_error_set(error, KRRP_ERRNO_CMNSNAP, ENOENT);
			goto out;
		}
	}

	switch (stream->mode) {
	case KRRP_STRMM_READ:
		if (!stream->non_continuous) {
			rc = krrp_autosnap_activate(stream->autosnap, incr_snap_txg,
			    &krrp_stream_read_snap_confirm_cb,
			    &krrp_stream_read_snap_notify_cb,
			    &krrp_stream_snap_create_error_cb,
			    &krrp_stream_autosnap_restore_cb,
			    stream, error);
			if (rc != 0)
				goto out;

			/*
			 * Autosnap does snapshots only in case of I/O
			 * to the dataset, so if user has some data on
			 * the dataset, but does not have I/O the available
			 * data will not be replicated. To exclude this case
			 * need to ask autosnap to create snapshot
			 */
			krrp_autosnap_create_snapshot(stream->autosnap);
		} else {
			uint64_t base_snap_txg;

			VERIFY(stream->base_snap_name[0] != '\0');

			base_snap_txg = krrp_stream_get_snap_txg(stream,
			    stream->base_snap_name);
			if (base_snap_txg == UINT64_MAX) {
				krrp_error_set(error,
				    KRRP_ERRNO_SRCSNAP, ENOENT);
				goto out;
			}

			krrp_stream_read_task_init(stream->task_engine,
			    base_snap_txg, stream->base_snap_name,
			    stream->incr_snap_name, stream->resume_info);

			/*
			 * Non-continuous replication sends only one snapshot.
			 * We remember TXG of this snapshot and will notify
			 * userspace that the snapshot successfully received
			 */
			stream->notify_txg = base_snap_txg;
		}

		break;
	case KRRP_STRMM_WRITE:
		rc = krrp_autosnap_activate(stream->autosnap, incr_snap_txg,
		    NULL, &krrp_stream_write_snap_notify_cb,
		    &krrp_stream_snap_create_error_cb, NULL, stream, error);
		if (rc != 0)
			goto out;

		break;
	}

	rc = 0;

out:
	return (rc);
}

static void
krrp_stream_autosnap_restore_cb(void *void_stream,
    const char *snap_name, uint64_t txg)
{
	krrp_stream_t *stream = void_stream;

	VERIFY(stream->mode == KRRP_STRMM_READ);

	krrp_stream_read_task_init(stream->task_engine, txg, snap_name,
	    stream->incr_snap_name, NULL);

	(void) strlcpy(stream->incr_snap_name, snap_name,
	    sizeof (stream->incr_snap_name));
}

#if 0
static void
krrp_stream_debug(const char *msg, void *arg1, void *arg2,
    void *arg3, void *arg4)
{
	cmn_err(CE_PANIC, "Debug");
}
#endif

/*
 * This function is called after a TXG confirmation
 * has been received from the receiver
 *
 * There are two stages of receiving:
 * - complete recv into krrp-buffers (complete == B_FALSE)
 * - complete recv into ZFS (complete == B_TRUE)
 */
void
krrp_stream_txg_confirmed(krrp_stream_t *stream, uint64_t txg,
    boolean_t complete)
{
	krrp_stream_task_t *task;

	if (complete) {
		DTRACE_PROBE1(krrp_txg_ack2, uint64_t, txg);

		/* autosnap is used only by CDP sender */
		if (!stream->non_continuous)
			krrp_autosnap_txg_rele(stream->autosnap,
			    txg, AUTOSNAP_NO_SNAP);

		stream->last_full_ack_txg = txg;

		task = krrp_queue_get(stream->task_engine->tasks_done2);
		krrp_stream_calc_avg_rpo(stream, task, B_TRUE);
		krrp_stream_task_fini(task);

		if (stream->notify_txg == txg) {
			krrp_stream_callback(stream,
			    KRRP_STREAM_SEND_DONE, NULL);
		}

		return;
	}

	stream->last_ack_txg = txg;

	task = krrp_queue_get(stream->task_engine->tasks_done);
	ASSERT(task != NULL);

	krrp_stream_calc_avg_rpo(stream, task, B_FALSE);
	krrp_queue_put(stream->task_engine->tasks_done2, task);
}

static void
krrp_stream_calc_avg_rpo(krrp_stream_t *stream, krrp_stream_task_t *task,
    boolean_t complete)
{
	size_t i, avg_cnt;
	uint64_t sum;
	krrp_txg_rpo_t *avg_rpo;

	if (complete)
		avg_rpo = &stream->avg_total_rpo;
	else
		avg_rpo = &stream->avg_rpo;

	avg_rpo->buf[avg_rpo->cnt] = krrp_stream_task_calc_rpo(task);
	avg_rpo->cnt++;
	avg_rpo->cnt %= 10;

	sum = 0;
	avg_cnt = 10;
	for (i = 0; i < 10; i++) {
		sum += avg_rpo->buf[i];
		if (avg_rpo->buf[i] == 0)
			avg_cnt--;
	}

	/* Average value in ms */
	avg_rpo->value = sum / avg_cnt / 1000 / 1000;
}

/* ARGSUSED */
static void
krrp_stream_snap_create_error_cb(const char *snap_name, int err,
    uint64_t txg, void *void_stream)
{
	krrp_stream_t *stream;
	krrp_error_t error;
	boolean_t just_return = B_FALSE;

	stream = void_stream;

	krrp_stream_lock(stream);

	if (stream->state == KRRP_STRMS_ACTIVE)
		stream->state = KRRP_STRMS_IN_ERROR;
	else
		just_return = B_TRUE;

	if (stream->wait_for_snap) {
		stream->wait_for_snap = B_FALSE;
		krrp_stream_cv_signal(stream);
	}

	krrp_stream_unlock(stream);

	if (just_return)
		return;

	krrp_error_set(&error, KRRP_ERRNO_SNAPFAIL, err);
	krrp_stream_callback(stream, KRRP_STREAM_ERROR,
	    (uintptr_t)&error);
}

/* ARGSUSED */
static boolean_t
krrp_stream_read_snap_confirm_cb(const char *snap_name, boolean_t recursive,
    uint64_t txg, void *void_stream)
{
	krrp_stream_t *stream = void_stream;
	boolean_t result = B_FALSE;
	size_t krrp_max_num_read_tasks =
	    stream->keep_snaps + krrp_add_num_read_tasks;

	if (krrp_autosnap_try_hold_to_confirm(stream->autosnap)) {
		size_t tasks =
		    krrp_stream_te_total_num_tasks(stream->task_engine);
		if (tasks < krrp_max_num_read_tasks || stream->wait_for_snap)
			result = B_TRUE;
		else
			result = B_FALSE;

		krrp_autosnap_unhold(stream->autosnap);
	}

	return (result);
}

/*
 * Autosnap snap_created callback for the Receiver
 */
/* ARGSUSED */
static boolean_t
krrp_stream_write_snap_notify_cb(const char *snap_name, boolean_t recursive,
    boolean_t autosnap, uint64_t txg, uint64_t unused, void *void_stream)
{
	krrp_stream_t *stream;

	stream = void_stream;

	krrp_stream_lock(stream);

	if (stream->cur_task == NULL) {
		krrp_stream_unlock(stream);
		return (B_FALSE);
	}

	if (stream->cur_task->txg_start == UINT64_MAX) {
		stream->cur_task->txg_start = txg;
		stream->cur_task->txg_end = AUTOSNAP_NO_SNAP;
	} else {
		stream->cur_task->txg_end = txg;
	}

	krrp_stream_unlock(stream);

	return (B_TRUE);
}

/*
 * Autosnap snap_created callback for the Sender
 */
/* ARGSUSED */
static boolean_t
krrp_stream_read_snap_notify_cb(const char *snap_name, boolean_t recursive,
    boolean_t autosnap, uint64_t txg, uint64_t unused, void *void_stream)
{
	krrp_stream_t *stream = void_stream;
	boolean_t result = B_FALSE;
	size_t krrp_max_num_read_tasks =
	    stream->keep_snaps + krrp_add_num_read_tasks;

	if (krrp_autosnap_try_hold_to_confirm(stream->autosnap)) {
		size_t tasks =
		    krrp_stream_te_total_num_tasks(stream->task_engine);
		if (tasks < krrp_max_num_read_tasks || stream->wait_for_snap) {
			uint64_t cur_snap_txg;
			char *cur_snap_name;

			cur_snap_name = strchr(snap_name, '@');
			ASSERT(cur_snap_name != NULL);
			cur_snap_name++;
			cur_snap_txg = txg;

			krrp_stream_read_task_init(stream->task_engine,
			    cur_snap_txg, cur_snap_name,
			    stream->incr_snap_name, NULL);

			(void) strlcpy(stream->incr_snap_name, cur_snap_name,
			    sizeof (stream->incr_snap_name));

			result = B_TRUE;

			if (stream->wait_for_snap) {
				stream->wait_for_snap = B_FALSE;

				/*
				 * This snapshot is the last that we will send.
				 * We remember its TXG and will notify userspace
				 * that the snapshot successfully received
				 */
				stream->notify_txg = txg;

				krrp_stream_lock(stream);
				krrp_stream_cv_signal(stream);
				krrp_stream_unlock(stream);
			}
		}

		krrp_autosnap_unhold(stream->autosnap);
	}

	return (result);
}

/*
 * The handler for READ STREAM
 *
 * Stream tasks are created by Autosnaper and pushed to tasks-queue
 */
static void
krrp_stream_read(void *arg)
{
	krrp_stream_t *stream = arg;

	krrp_stream_task_t *stream_task = NULL;
	int rc;
	krrp_pdu_data_t *pdu = NULL;

	VERIFY(stream->data_pdu_engine != NULL);

	krrp_stream_lock(stream);
	stream->state = KRRP_STRMS_ACTIVE;
	krrp_stream_cv_signal(stream);

	while (stream->state == KRRP_STRMS_ACTIVE) {
		krrp_stream_unlock(stream);

		if (pdu == NULL) {
			DTRACE_PROBE(krrp_pdu_data_alloc_start);

			krrp_pdu_alloc(stream->data_pdu_engine,
			    (krrp_pdu_t **)&pdu, KRRP_PDU_WITH_HDR);

			DTRACE_PROBE(krrp_pdu_data_alloc_stop);

			if (pdu == NULL) {
				krrp_stream_lock(stream);
				continue;
			}
		}

		if (stream_task == NULL) {
			krrp_stream_task_engine_get_task(stream->task_engine,
			    &stream_task);
			if (stream_task == NULL) {
				krrp_stream_lock(stream);
				continue;
			}

			stream->cur_task = stream_task;
			stream->cur_send_txg = stream_task->txg;
			stream->cur_pdu = pdu;

			stream_task->start(stream_task);

			pdu->initial = B_TRUE;

			DTRACE_PROBE1(krrp_stream_task_io_start, uint64_t,
			    stream_task->txg);
		}

		rc = stream_task->process(stream_task, pdu);

		if (rc != 0) {
			krrp_pdu_rele((krrp_pdu_t *)pdu);
			pdu = NULL;
			stream->cur_pdu = NULL;

			krrp_stream_lock(stream);
			if (stream->state == KRRP_STRMS_ACTIVE) {
				krrp_error_t error;

				stream->state = KRRP_STRMS_IN_ERROR;
				krrp_stream_unlock(stream);

				krrp_error_set(&error, KRRP_ERRNO_READFAIL, rc);
				krrp_stream_callback(stream, KRRP_STREAM_ERROR,
				    (uintptr_t)&error);

				krrp_stream_lock(stream);
			}

			break;
		}

		if (stream_task->done) {
			DTRACE_PROBE1(krrp_stream_task_io_stop, uint64_t,
			    stream_task->txg);

			krrp_stream_task_done(stream, stream_task, B_FALSE);
			stream_task = NULL;
			stream->cur_task = NULL;

			stream->last_send_txg = stream->cur_send_txg;
			stream->cur_send_txg = 0;
		}

		stream->bytes_processed += pdu->cur_data_sz;
		krrp_stream_callback(stream, KRRP_STREAM_DATA_PDU,
		    (uintptr_t)pdu);

		pdu = NULL;
		stream->cur_pdu = NULL;
		krrp_stream_lock(stream);
	} /* while() loop */

	stream->cur_task = NULL;
	krrp_stream_unlock(stream);

	if (pdu != NULL)
		krrp_pdu_rele((krrp_pdu_t *)pdu);

	if (stream_task != NULL)
		krrp_stream_task_done(stream, stream_task, B_TRUE);

	krrp_stream_lock(stream);

	stream->work_thread = NULL;

	krrp_stream_cv_broadcast(stream);
	krrp_stream_unlock(stream);
	thread_exit();
}

/*
 * The handler for WRITE STREAM
 *
 * Stream tasks are created on intial PDU
 */
static void
krrp_stream_write(void *arg)
{
	krrp_stream_t *stream = arg;

	krrp_pdu_data_t *pdu = NULL;
	krrp_stream_task_t *stream_task = NULL;
	int rc;

	VERIFY(stream->write_data_queue != NULL);

#ifdef KRRP_STREAM_DEBUG
	krrp_queue_init(&stream->debug_pdu_queue, sizeof (krrp_pdu_t),
	    offsetof(krrp_pdu_t, node));
#endif

	krrp_stream_lock(stream);
	stream->state = KRRP_STRMS_ACTIVE;
	krrp_stream_cv_signal(stream);

	while (stream->state == KRRP_STRMS_ACTIVE) {
		krrp_stream_unlock(stream);

		if (pdu == NULL) {
			pdu = krrp_queue_get(stream->write_data_queue);
			if (pdu == NULL) {
				krrp_stream_lock(stream);
				continue;
			}
		}

		if (pdu->initial) {
			/* Replace by ASSERT */
			VERIFY(stream_task == NULL);

			krrp_stream_write_task_init(stream->task_engine,
			    pdu->txg, &stream_task, stream->resume_info);

			/*
			 * Cookies are required only for
			 * the first received task
			 */
			if (stream->resume_info != NULL) {
				fnvlist_free(stream->resume_info);
				stream->resume_info = NULL;
			}

			stream->cur_task = stream_task;
			stream->cur_recv_txg = pdu->txg;

			DTRACE_PROBE1(krrp_stream_task_io_start, uint64_t,
			    stream_task->txg);
		}

		stream->cur_pdu = pdu;

		rc = stream_task->process(stream_task, pdu);
		if (rc != 0) {
			krrp_stream_lock(stream);
			if (stream->state == KRRP_STRMS_ACTIVE) {
				krrp_error_t error;

				stream->state = KRRP_STRMS_IN_ERROR;
				krrp_stream_unlock(stream);

				krrp_error_set(&error,
				    KRRP_ERRNO_WRITEFAIL, rc);
				krrp_stream_callback(stream, KRRP_STREAM_ERROR,
				    (uintptr_t)&error);
				krrp_stream_lock(stream);
			}

			break;
		}

		stream->bytes_processed += pdu->cur_data_sz;
		if (stream_task->done) {
			VERIFY(pdu->final == B_TRUE);

			DTRACE_PROBE1(krrp_stream_task_io_stop, uint64_t,
			    stream_task->txg);

			krrp_stream_task_done(stream, stream_task, B_FALSE);
			stream_task = NULL;
			stream->cur_task = NULL;
			stream->cur_recv_txg = 0;
		}

#ifdef KRRP_STREAM_DEBUG
		krrp_queue_put(stream->debug_pdu_queue, pdu);

		if (krrp_queue_length(stream->debug_pdu_queue) > 1) {
			pdu = krrp_queue_get(stream->debug_pdu_queue);
			krrp_pdu_rele((krrp_pdu_t *)pdu);
		}
#else
		krrp_pdu_rele((krrp_pdu_t *)pdu);
#endif

		pdu = NULL;
		krrp_stream_lock(stream);
	} /* while() loop */

	stream->cur_task = NULL;
	krrp_stream_unlock(stream);

	if (pdu != NULL)
		krrp_pdu_rele((krrp_pdu_t *)pdu);

#ifdef KRRP_STREAM_DEBUG
	/* Simple get, because this queue without locks */
	while ((pdu = krrp_queue_get(stream->debug_pdu_queue)) != NULL)
		krrp_pdu_rele((krrp_pdu_t *)pdu);

	krrp_queue_fini(stream->debug_pdu_queue);
#endif

	if (stream_task != NULL)
		krrp_stream_task_done(stream, stream_task, B_TRUE);

	krrp_stream_lock(stream);

	stream->work_thread = NULL;

	krrp_stream_cv_broadcast(stream);
	krrp_stream_unlock(stream);
	thread_exit();
}

static void
krrp_stream_task_done(krrp_stream_t *stream,
    krrp_stream_task_t *task, boolean_t only_fini)
{
	task->shutdown(task);

	if (only_fini) {
		krrp_stream_task_fini(task);
		return;
	}

	switch (stream->mode) {
	case KRRP_STRMM_READ:
		if (krrp_stream_te_num_pending_tasks(stream->task_engine) == 0) {
			if (stream->do_ctrl_snap) {
				krrp_autosnap_create_snapshot(stream->autosnap);
				stream->do_ctrl_snap = B_FALSE;
			}
		} else {
			stream->do_ctrl_snap = B_TRUE;
		}

		krrp_queue_put(stream->task_engine->tasks_done, task);
		break;
	case KRRP_STRMM_WRITE:
		krrp_autosnap_txg_rele(stream->autosnap,
		    task->txg_start, task->txg_end);

		krrp_stream_callback(stream, KRRP_STREAM_TXG_RECV_DONE,
		    (uintptr_t)task->txg);
		krrp_stream_task_fini(task);
		break;
	}
}

static void
krrp_stream_callback(krrp_stream_t *stream,
    krrp_stream_cb_ev_t ev, uintptr_t ev_arg)
{
	stream->callback(ev, ev_arg, stream->callback_arg);
}

static uint64_t
krrp_stream_get_snap_txg(krrp_stream_t *stream,
    const char *short_snap_name)
{
	char full_ds_name[MAXNAMELEN];

	(void) snprintf(full_ds_name, sizeof (full_ds_name), "%s@%s",
	    stream->dataset, short_snap_name);

	return (dsl_dataset_creation_txg(full_ds_name));
}

boolean_t
krrp_stream_is_write_flag_set(krrp_stream_write_flag_t flags,
    krrp_stream_write_flag_t flag)
{
	return ((flags & flag) != 0);
}

void
krrp_stream_set_write_flag(krrp_stream_write_flag_t *flags,
    krrp_stream_write_flag_t flag)
{
	*flags |= flag;
}

boolean_t
krrp_stream_is_read_flag_set(krrp_stream_read_flag_t flags,
    krrp_stream_read_flag_t flag)
{
	return ((flags & flag) != 0);
}

void
krrp_stream_set_read_flag(krrp_stream_read_flag_t *flags,
    krrp_stream_read_flag_t flag)
{
	*flags |= flag;
}

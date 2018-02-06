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
 * ZFS Autosnap wrap-module
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

#include "krrp_autosnap.h"

/* #define KRRP_DEBUG 1 */

typedef struct krrp_txg_s {
	list_t		node;
	uint64_t	txg_start;
	uint64_t	txg_end;
} krrp_txg_t;


static void krrp_autosnap_common_create(krrp_autosnap_t **result_autosnap,
    size_t keep_snaps, const char *dataset, autosnap_flags_t flags);
static uint64_t krrp_get_txg_from_snap_nvp(nvpair_t *);
static boolean_t krrp_autosnap_try_hold_with_check_state(
    krrp_autosnap_t *autosnap, krrp_autosnap_state_t min_state);

void
krrp_autosnap_rside_create(krrp_autosnap_t **result_autosnap,
    size_t keep_snaps, const char *dataset, boolean_t recursive)
{
	autosnap_flags_t flags;

	flags = AUTOSNAP_CREATOR | AUTOSNAP_DESTROYER |
	    AUTOSNAP_OWNER | AUTOSNAP_KRRP;
	if (recursive)
		flags |= AUTOSNAP_RECURSIVE;

	krrp_autosnap_common_create(result_autosnap, keep_snaps,
	    dataset, flags);
}

void
krrp_autosnap_wside_create(krrp_autosnap_t **result_autosnap,
    size_t keep_snaps, const char *dataset)
{
	autosnap_flags_t flags;

	flags = AUTOSNAP_DESTROYER | AUTOSNAP_RECURSIVE |
	    AUTOSNAP_OWNER | AUTOSNAP_KRRP;

	krrp_autosnap_common_create(result_autosnap, keep_snaps,
	    dataset, flags);
}

static void
krrp_autosnap_common_create(krrp_autosnap_t **result_autosnap,
    size_t keep_snaps, const char *dataset, autosnap_flags_t flags)
{
	krrp_autosnap_t *autosnap;

	VERIFY(result_autosnap != NULL && *result_autosnap == NULL);
	VERIFY(dataset != NULL && dataset[0] != '\0');

	autosnap = kmem_zalloc(sizeof (krrp_autosnap_t), KM_SLEEP);

	mutex_init(&autosnap->mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&autosnap->cv, NULL, CV_DEFAULT, NULL);

	krrp_queue_init(&autosnap->txg_to_rele, sizeof (krrp_txg_t),
	    offsetof(krrp_txg_t, node));

	autosnap->keep_snaps = keep_snaps;
	autosnap->state = KRRP_AUTOSNAP_STATE_CREATED;
	autosnap->flags = flags;
	autosnap->dataset = dataset;

	*result_autosnap = autosnap;
}

void
krrp_autosnap_destroy(krrp_autosnap_t *autosnap)
{
	krrp_txg_t *txg_item;
	void *zfs_ctx = NULL;

	krrp_autosnap_deactivate(autosnap);

	krrp_autosnap_lock(autosnap);
	autosnap->state = KRRP_AUTOSNAP_STATE_CREATED;
	while (autosnap->ref_cnt > 0)
		krrp_autosnap_cv_wait(autosnap);

	zfs_ctx = autosnap->zfs_ctx;
	autosnap->zfs_ctx = NULL;
	krrp_autosnap_unlock(autosnap);

	if (zfs_ctx != NULL)
		autosnap_unregister_handler(zfs_ctx);


	/*
	 * After deactivation no one can push to the queue
	 * therefore we can safely iterate over all the elements
	 * in the queue and free them.
	 */
	while ((txg_item =
	    krrp_queue_get_no_wait(autosnap->txg_to_rele)) != NULL)
		kmem_free(txg_item, sizeof (krrp_txg_t));

	krrp_queue_fini(autosnap->txg_to_rele);

	cv_destroy(&autosnap->cv);
	mutex_destroy(&autosnap->mtx);

	kmem_free(autosnap, sizeof (krrp_autosnap_t));
}

int
krrp_autosnap_activate(krrp_autosnap_t *autosnap, uint64_t incr_snap_txg,
    autosnap_confirm_cb confirm_cb, autosnap_notify_created_cb notify_cb,
    autosnap_error_cb error_cb, krrp_autosnap_restore_cb_t restore_cb,
    void *cb_arg, krrp_error_t *error)
{
	nvlist_t *snaps;
	nvpair_t *target_snap_nvp = NULL, *snap_nvp;
	uint64_t target_snap_txg = UINT64_MAX;
	boolean_t read_side = ((autosnap->flags & AUTOSNAP_CREATOR) != 0);

	VERIFY(notify_cb != NULL);

	autosnap->zfs_ctx = autosnap_register_handler(autosnap->dataset,
	    autosnap->flags, confirm_cb, notify_cb, error_cb, cb_arg);

	if (autosnap->zfs_ctx == NULL) {
		krrp_error_set(error, KRRP_ERRNO_AUTOSNAP, EINVAL);
		return (-1);
	}

	krrp_autosnap_lock(autosnap);
	autosnap->state = KRRP_AUTOSNAP_STATE_REGISTERED;
	krrp_autosnap_unlock(autosnap);

	snaps = autosnap_get_owned_snapshots(autosnap->zfs_ctx);

	snap_nvp = nvlist_next_nvpair(snaps, NULL);
	while (snap_nvp != NULL) {
		uint64_t snap_txg;

		snap_txg = krrp_get_txg_from_snap_nvp(snap_nvp);

		if (incr_snap_txg != UINT64_MAX && snap_txg < incr_snap_txg) {
			/*
			 * All TXG that before incremetal is not
			 * required and should be released
			 */
			DTRACE_PROBE1(rele_old_snap, uint64_t, snap_txg);

			krrp_autosnap_txg_rele(autosnap, snap_txg,
			    AUTOSNAP_NO_SNAP);
		}

		if (incr_snap_txg == UINT64_MAX || snap_txg > incr_snap_txg) {
			if (target_snap_txg == UINT64_MAX ||
			    snap_txg > target_snap_txg) {

				if (target_snap_txg != UINT64_MAX) {
					/*
					 * We are looking for maximum TXG,
					 * so all previous TXGs should
					 * be released
					 */
					DTRACE_PROBE1(rele_interim_snap,
					    uint64_t, target_snap_txg);

					autosnap_release_snapshots_by_txg(
					    autosnap->zfs_ctx,
					    target_snap_txg,
					    AUTOSNAP_NO_SNAP);
				}

				target_snap_txg = snap_txg;
				target_snap_nvp = snap_nvp;
			}
		}

		snap_nvp = nvlist_next_nvpair(snaps, snap_nvp);
	}

	if (read_side && incr_snap_txg == UINT64_MAX &&
	    target_snap_txg != UINT64_MAX) {
		/*
		 * On start we always create snapshot,
		 * so the have found target_snap_txg
		 * is not required without incr_snap_txg
		 */
		autosnap_release_snapshots_by_txg(autosnap->zfs_ctx,
		    target_snap_txg, AUTOSNAP_NO_SNAP);
		goto out;
	}

	if (incr_snap_txg != UINT64_MAX) {
		krrp_autosnap_txg_rele(autosnap, incr_snap_txg,
		    AUTOSNAP_NO_SNAP);
	}

	if (target_snap_txg != UINT64_MAX && restore_cb != NULL) {
		char *snap_name;

		snap_name = strchr(nvpair_name(target_snap_nvp), '@');
		snap_name++;

		restore_cb(cb_arg, snap_name, target_snap_txg);
	}

out:
	fnvlist_free(snaps);

	krrp_autosnap_lock(autosnap);
	autosnap->state = KRRP_AUTOSNAP_STATE_ACTIVE;
	krrp_autosnap_unlock(autosnap);

	return (0);
}

void
krrp_autosnap_deactivate(krrp_autosnap_t *autosnap)
{
	krrp_autosnap_lock(autosnap);
	if (autosnap->state == KRRP_AUTOSNAP_STATE_ACTIVE) {
		autosnap->state = KRRP_AUTOSNAP_STATE_REGISTERED;
		while (autosnap->ref_cnt > 0)
			krrp_autosnap_cv_wait(autosnap);
	}

	krrp_autosnap_unlock(autosnap);
}

static uint64_t
krrp_get_txg_from_snap_nvp(nvpair_t *snap)
{
	uint64_t *snap_info = NULL;
	uint_t nelem = 0;

	VERIFY3U(nvpair_value_uint64_array(snap,
	    &snap_info, &nelem), ==, 0);
	VERIFY(nelem != 0);

	return (snap_info[0]);
}

boolean_t
krrp_autosnap_try_hold_to_confirm(krrp_autosnap_t *autosnap)
{
	return (krrp_autosnap_try_hold_with_check_state(autosnap,
	    KRRP_AUTOSNAP_STATE_ACTIVE));
}

static boolean_t
krrp_autosnap_try_hold_with_check_state(krrp_autosnap_t *autosnap,
    krrp_autosnap_state_t min_state)
{
	boolean_t rc = B_FALSE;

	krrp_autosnap_lock(autosnap);

	if (autosnap->state >= min_state) {
		autosnap->ref_cnt++;
		rc = B_TRUE;
	}

	krrp_autosnap_unlock(autosnap);

	return (rc);
}

void
krrp_autosnap_unhold(krrp_autosnap_t *autosnap)
{
	krrp_autosnap_lock(autosnap);
	autosnap->ref_cnt--;
	krrp_autosnap_cv_signal(autosnap);
	krrp_autosnap_unlock(autosnap);
}

void
krrp_autosnap_create_snapshot(krrp_autosnap_t *autosnap)
{
	if (krrp_autosnap_try_hold_with_check_state(autosnap,
	    KRRP_AUTOSNAP_STATE_ACTIVE)) {
		autosnap_force_snap(autosnap->zfs_ctx, B_FALSE);

		krrp_autosnap_unhold(autosnap);
	}
}

void
krrp_autosnap_txg_rele(krrp_autosnap_t *autosnap,
    uint64_t txg_start, uint64_t txg_end)
{
	krrp_txg_t *txg_item;

	if (!krrp_autosnap_try_hold_with_check_state(autosnap,
	    KRRP_AUTOSNAP_STATE_REGISTERED))
		return;

	txg_item = kmem_zalloc(sizeof (krrp_txg_t), KM_SLEEP);
	txg_item->txg_start = txg_start;
	txg_item->txg_end = txg_end;
	krrp_queue_put(autosnap->txg_to_rele, txg_item);

	while (krrp_queue_length(autosnap->txg_to_rele) >
	    autosnap->keep_snaps) {
		txg_item = krrp_queue_get(autosnap->txg_to_rele);

		autosnap_release_snapshots_by_txg(autosnap->zfs_ctx,
		    txg_item->txg_start, txg_item->txg_end);

		kmem_free(txg_item, sizeof (krrp_txg_t));
	}

	krrp_autosnap_unhold(autosnap);
}

/*
 * The function is used under krrp_autosnap hold and
 * only from autosnap_notify_cb ctx
 */
void
krrp_autosnap_txg_rele_one(krrp_autosnap_t *autosnap, uint64_t txg)
{
	autosnap_release_snapshots_by_txg_no_lock(autosnap->zfs_ctx,
	    txg, AUTOSNAP_NO_SNAP);
}

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
 * Copyright 2013 Nexenta Systems, Inc.  All rights reserved.
 */

#include "sys/zio.h"
#include "sys/zio_checksum.h"
#include <sys/isal.h>

typedef enum zio_parallel_checksum {
	ZIO_PARALLEL_CHECKSUM_SHA256,
	ZIO_PARALLEL_CHECKSUM_SHA1CRC32,
	ZIO_NUM_PARALLEL_CHECKSUMS
} zio_parallel_checksum_t;

extern kmutex_t zfs_checksum_accum_lock[ZIO_NUM_PARALLEL_CHECKSUMS];

/*
 * Parallel checksum state
 * the list and the count are used to batch concurrent
 * zios for sha256 calculation
 * the mutex protects the list/count
 */
kmutex_t zfs_checksum_accum_lock[ZIO_NUM_PARALLEL_CHECKSUMS];
zio_t *zfs_parallel_checksum_zios[ZIO_NUM_PARALLEL_CHECKSUMS] = { NULL, NULL };
int zfs_parallel_checksum_zios_count[ZIO_NUM_PARALLEL_CHECKSUMS] = { 0, 0 };

/*
 * Tunables
 */
int zfs_parallel_checksum_min_size = 4096;

/* Exports for the acceleration library */
uint32_t zfs_accel_lib_version = ACCEL_LIB_VERSION;
void (*zfs_parallel_sha1crc32_hook)(cksum_op_t *ops, int num_ops) = NULL;
void (*zfs_parallel_sha256_hook)(cksum_op_t *ops, int num_ops) = NULL;
int (*zfs_gzip_hook)(void *in, int insize, void *out, int *outsize) = NULL;
/* Another tunable */
uint32_t zfs_optimal_parallel_shax_ops = OPTIMAL_PARALLEL_SHAX_CHECKSUMS;


void
zio_parallel_checksum_init()
{
	for (int i = 0; i < ZIO_NUM_PARALLEL_CHECKSUMS; i++) {
		mutex_init(&zfs_checksum_accum_lock[i], NULL,
		    MUTEX_DEFAULT, NULL);
	}
}

void
zio_parallel_checksum_fini()
{
	for (int i = 0; i < ZIO_NUM_PARALLEL_CHECKSUMS; i++) {
		mutex_destroy(&zfs_checksum_accum_lock[i]);
	}
}

/*
 * Run the SHA256 chksums in parallel using ISAL.
 * Called with the zfs_checksum_accum_lock held and
 * returns with the lock dropped.
 */
void
zio_parallel_checksum(zio_parallel_checksum_t pll_checksum)
{
	zio_t *zio, *saved;
	int count;
	cksum_op_t ops[MAX_PARALLEL_SHAX_CHECKSUMS];
	int i;

	VERIFY(MUTEX_HELD(&zfs_checksum_accum_lock[pll_checksum]));

	saved = zfs_parallel_checksum_zios[pll_checksum];
	count = zfs_parallel_checksum_zios_count[pll_checksum];
	zfs_parallel_checksum_zios[pll_checksum] = NULL;
	zfs_parallel_checksum_zios_count[pll_checksum] = 0;
	ASSERT((count <= MAX_PARALLEL_SHAX_CHECKSUMS) && (count > 0));

	/* Change checksum state before dropping the lock */
	for (zio = saved; zio; zio = zio->zio_checksum_next) {
		ASSERT(zio->zio_checksum_state == CKSTATE_WAITING);
		zio->zio_checksum_state = CKSTATE_CHECKSUMMING;
	}
	mutex_exit(&zfs_checksum_accum_lock[pll_checksum]);

	DTRACE_PROBE1(shax_batch_size, int, count);

	for (zio = saved, i = 0; zio; zio = zio->zio_checksum_next, i++) {
		ASSERT(i < count);
		ops[i].data_buf = zio->zio_checksum_datap;
		ops[i].data_size = zio->zio_checksum_data_size;
		ops[i].checksum_buf = zio->zio_checksump;
	}

	if (pll_checksum == ZIO_PARALLEL_CHECKSUM_SHA256)
		zfs_parallel_sha256_hook(ops, count);
	else
		zfs_parallel_sha1crc32_hook(ops, count);

	/* No need to grab the lock for doing this state transition. */
	for (zio = saved; zio; zio = zio->zio_checksum_next) {
		zio_cksum_t *cksum = zio->zio_checksump;
		/*
		 * A prior implementation of SHA256 function had a
		 * private implementation always wrote things out in
		 * Big Endian and there wasn't a byteswap variant of it.
		 * To preseve on disk compatibility we need to force that
		 * behaviour.
		 */
		if (pll_checksum == ZIO_PARALLEL_CHECKSUM_SHA256) {
			cksum->zc_word[0] = BE_64(cksum->zc_word[0]);
			cksum->zc_word[1] = BE_64(cksum->zc_word[1]);
			cksum->zc_word[2] = BE_64(cksum->zc_word[2]);
			cksum->zc_word[3] = BE_64(cksum->zc_word[3]);

			membar_producer();
		}

		zio->zio_checksum_state = CKSTATE_CHECKSUM_DONE;
	}
}

/*
 * zio batching for parallel checksum calculation
 * at this time, used for sha256 calculation only
 *
 * return values:
 *	0 - FSM invoked, do not fall back on non-acceledated algo
 *	1 - FSM not invoked, fall back on non-accelerated algo
 */
int
zio_parallel_checksum_fsm(zio_t *zio, enum zio_checksum checksum,
    void *data, uint64_t size, int can_accumulate, zio_cksum_t *result,
    int *zio_progress)
{
	zio_parallel_checksum_t pll_checksum = ZIO_PARALLEL_CHECKSUM_SHA256;

	if (!can_accumulate || (size < zfs_parallel_checksum_min_size))
		return (1);

	switch (checksum) {
	case ZIO_CHECKSUM_SHA1CRC32:
		if (zfs_parallel_sha1crc32_hook == NULL)
			return (1);

		pll_checksum = ZIO_PARALLEL_CHECKSUM_SHA1CRC32;
		break;
	case ZIO_CHECKSUM_SHA256:
		if (zfs_parallel_sha256_hook == NULL)
			return (1);

		pll_checksum = ZIO_PARALLEL_CHECKSUM_SHA256;
		break;
	default:
		/* cannot perform parallel checksum */
		return (1);
	};

	/* this zio might already be on the list, so take the lock */
	mutex_enter(&zfs_checksum_accum_lock[pll_checksum]);
	if (zio->zio_checksum_state != CKSTATE_NONE) {
		/*
		 * If this ZIO has already been queued for
		 * parallel cksum ...
		 */

		/* ... cksum done, continue the pipeline. */
		if (zio->zio_checksum_state == CKSTATE_CHECKSUM_DONE) {
			zio->zio_checksum_state = CKSTATE_NONE;
			mutex_exit(&zfs_checksum_accum_lock[pll_checksum]);
			*zio_progress = ZIO_PIPELINE_CONTINUE;
			return (0);
		}

		/* ... cksum running, check back later. */
		if (zio->zio_checksum_state == CKSTATE_CHECKSUMMING) {
			mutex_exit(&zfs_checksum_accum_lock[pll_checksum]);
			*zio_progress = ZIO_PIPELINE_RESTART_STAGE;
			return (0);
		}

		/*
		 * ... Otherwise lets not wait too long and kick off
		 * the cksum.
		 */
		ASSERT(zio->zio_checksum_state == CKSTATE_WAITING);
		zio_parallel_checksum(pll_checksum);    /* drops the lock */
		*zio_progress = ZIO_PIPELINE_CONTINUE;
	} else {
		/*
		 * This is a new zio; queue for parallel cksum
		 */
		zio->zio_checksum_state = CKSTATE_WAITING;
		zio->zio_checksump = result;
		zio->zio_checksum_datap = data;
		zio->zio_checksum_data_size = size;
		zio->zio_checksum_next =
		    zfs_parallel_checksum_zios[pll_checksum];
		zfs_parallel_checksum_zios[pll_checksum] = zio;
		zfs_parallel_checksum_zios_count[pll_checksum]++;
		ASSERT(zfs_parallel_checksum_zios_count[pll_checksum] <=
		    zfs_optimal_parallel_shax_ops);

		/*
		 * If the queue has sufficient # of zios, then
		 * go ahead and do the parallel cksum.
		 */
		if (zfs_parallel_checksum_zios_count[pll_checksum] ==
		    zfs_optimal_parallel_shax_ops) {
			/* drops the lock */
			zio_parallel_checksum(pll_checksum);
			ASSERT(!MUTEX_HELD(
			    &zfs_checksum_accum_lock[pll_checksum]));
			*zio_progress = ZIO_PIPELINE_CONTINUE;
			return (0);
		}
		mutex_exit(&zfs_checksum_accum_lock[pll_checksum]);
		*zio_progress = ZIO_PIPELINE_RESTART_STAGE;
	}

	/* exited fsm */
	ASSERT(!MUTEX_HELD(&zfs_checksum_accum_lock[pll_checksum]));
	return (0);
}

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

#ifndef	_SYS_WRCACHE_H
#define	_SYS_WRCACHE_H

#include <sys/sysmacros.h>
#include <sys/types.h>
#include <sys/fs/zfs.h>
#include <sys/spa.h>
#include <sys/dmu.h>
#include <sys/dmu_traverse.h>
#include <sys/dsl_dataset.h>

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * write cache special class.
 */

#define	WRCIO_PERC_MIN	(25)
#define	WRCIO_PERC_MAX	(75)

struct wrc_blkhdr;

/*
 * This is the header for each wrc_block_t structure.
 * This stores only the dataset name for now, but can
 * store more details needed for blocks in future.
 * This is in place for avoiding the duplication of
 * dataset details like name in all the block structures.
 */
typedef struct wrc_blkhdr {
	/*
	 * MAXNAMELEN + strlen(MOS_DIR_NAME) + 1
	 */
	char			ds_name[MAXNAMELEN + 5];
	/*
	 * This count determines the life of the header. Header
	 * is removed from the list when th num_blks reaches
	 * zero.
	 */
	int			num_blks;

	/*
	 * The header is valid if the flag is TRUE. This flag can
	 * help in the delayed freeing of the header.
	 */
	boolean_t		hdr_isvalid;

	/*
	 * All the headers are structured as a linked list and
	 * blocks point to this. This avoids the duplication of
	 * details in each blocks.
	 */
	struct wrc_blkhdr	*prev;
	struct wrc_blkhdr	*next;
} wrc_blkhdr_t;

typedef struct wrc_block {
	wrc_blkhdr_t		*hdr;

	uint64_t		object;
	uint64_t		offset;
	uint64_t		size;

	list_node_t		node;
} wrc_block_t;

typedef struct wrc_data {
	kthread_t		*wrc_thread;
	boolean_t		wrc_thr_exit;
	kmutex_t		wrc_lock;
	kcondvar_t		wrc_cv;
	wrc_blkhdr_t		*wrc_blkhdr_head;
	list_t			wrc_blocks;
	uint64_t		wrc_block_count;
} wrc_data_t;

/*
 * Structure maintaining the information needed for
 * weighted round-robin write routing among special
 * and normal devices after low watermark is reached.
 */
typedef struct wrc_route {
	kmutex_t	route_lock;
	uint8_t		route_special; /* # writes to special dev */
	uint8_t		route_normal;  /* # writes to normal dev */

	/*
	 * % of extra data in special dev from low watermark with respect
	 * to high watermark.
	 */
	uint8_t		route_perc;
} wrc_route_t;

typedef struct wrc_parseblock_cb {
	void	*wrc_blkhdr;

	/*
	 * A bookmark for resume
	 */
	zbookmark_phys_t	zb;

	/*
	 * Total size of all collected blocks
	 */
	uint64_t	bt_size;

	/*
	 * The time we started traversal process
	 */
	hrtime_t	start_time;
} wrc_parseblock_cb_t;

#define	WRC_BLK_DSNAME(block)	(block->hdr->ds_name)
#define	WRC_BLK_ADDCOUNT(block)	(block->hdr->num_blks++)
#define	WRC_BLK_DECCOUNT(block)	(block->hdr->num_blks--)

void wrc_route_set(spa_t *, boolean_t);
metaslab_class_t *wrc_select_class(spa_t *);
void *wrc_activate_blkhdr(spa_t *spa, dsl_dataset_t *ds);
void wrc_deactivate_blkhdr(spa_t *spa, dsl_dataset_t *ds);

/*
 * write cache thread.
 */
void start_wrc_thread(spa_t *);
boolean_t stop_wrc_thread(spa_t *);
void wrc_trigger_wrcthread(spa_t *, uint64_t);

/*
 * callback function for traverse_dataset which validates
 * the block pointer and adds to the list.
 */
blkptr_cb_t	wrc_traverse_ds_cb;

boolean_t wrc_check_parseblocks_hold(spa_t *);
void wrc_check_parseblocks_rele(spa_t *spa);
boolean_t wrc_try_hold(spa_t *);
void wrc_hold(spa_t *);
void wrc_rele(spa_t *);
void wrc_clean_special(dsl_pool_t *dp, dmu_tx_t *tx, uint64_t cur_txg);

#ifdef	__cplusplus
}
#endif

#endif	/* _SYS_WRCACHE_H */

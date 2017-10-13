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
 * Copyright 2017 Nexenta Systems, Inc.  All rights reserved.
 */

#ifndef	_KREPLICATION_COMMON_H
#define	_KREPLICATION_COMMON_H

#ifdef	__cplusplus
extern "C" {
#endif

#include <sys/fs/zfs.h>

#include <sys/param.h>
#include <sys/nvpair.h>

/*
 * This callback is used by send-side to decide what will be used:
 * zero-copy ARC-read or regular ARC-read
 */
typedef boolean_t krrp_check_enough_mem(size_t, void *);
typedef int (*arc_bypass_io_func)(void *, int, void *);


typedef struct kreplication_buffer_s {
	void	*data;
	size_t	buffer_size;
	size_t	data_size;
	struct	kreplication_buffer_s *next;
} kreplication_buffer_t;

typedef struct kreplication_ops_s {
    void* (*init_cb)(void*);
    int (*fini_cb)(void*);
    int (*fill_buf_cb)(void*, kreplication_buffer_t *);
    int (*put_buf_cb)(void*, kreplication_buffer_t *);
    void* (*init_stream_cb)();
    void (*fini_stream_cb)(void*);
} kreplication_ops_t;

typedef struct kreplication_zfs_args {
	char from_ds[ZFS_MAX_DATASET_NAME_LEN];
	char from_snap[ZFS_MAX_DATASET_NAME_LEN];
	char from_incr_base[ZFS_MAX_DATASET_NAME_LEN];
	char to_ds[ZFS_MAX_DATASET_NAME_LEN];
	char to_snap[ZFS_MAX_DATASET_NAME_LEN];

	const char *skip_snaps_prop_name;
	const char *skip_snaps_prop_val;

	boolean_t force;
	boolean_t properties;
	boolean_t recursive;
	boolean_t do_all;
	nvlist_t *ignore_list;
	nvlist_t *replace_list;
	nvlist_t *resume_info;
	boolean_t strip_head;
	boolean_t leave_tail;
	boolean_t force_cksum;
	boolean_t embedok;
	boolean_t compressok;
	boolean_t large_block_ok;
	void *stream_handler;
	krrp_check_enough_mem *mem_check_cb;
	void *mem_check_cb_arg;
} kreplication_zfs_args_t;

#ifdef	__cplusplus
}
#endif

#endif /* _KREPLICATION_COMMON_H */

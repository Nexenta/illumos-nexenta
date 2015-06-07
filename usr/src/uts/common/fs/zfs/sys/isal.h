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

#ifndef	_ISAL_H_
#define	_ISAL_H_

typedef struct {
	void	*data_buf;
	void	*checksum_buf;
	int	data_size;
} cksum_op_t;

#define	ACCEL_LIB_VERSION		0x200
#define	MAX_PARALLEL_SHAX_CHECKSUMS	8
#define	OPTIMAL_PARALLEL_SHAX_CHECKSUMS	6

extern uint32_t zfs_accel_lib_version;
extern uint32_t (*zfs_crc32c_hook)(unsigned char *buf, unsigned int size);
extern void (*zfs_parallel_sha1crc32_hook)(cksum_op_t *ops, int num_ops);
extern void (*zfs_parallel_sha256_hook)(cksum_op_t *ops, int num_ops);
extern uint32_t zfs_optimal_parallel_shax_ops;

/*
 * vects = num of arrays, len is length of each array in bytes,
 * the last vect (array[vects-1]) is the destination. All vectors
 * must be aligned on 64 byte boundary. Returns 0 on pass.
 */
extern int (*zfs_xorp_hook)(int vects, int len, void **array);

/*
 * outsize contains size of out buf upon entry and data size in
 * outbuf upon successful return.
 * returns 0 upon success. non-zero otherwise.
 */
extern int (*zfs_gzip_hook)(void *in, int insize, void *out, int *outsize);

#endif /* _ISAL_H_ */

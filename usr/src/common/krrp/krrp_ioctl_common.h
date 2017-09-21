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

#ifndef	_KRRP_IOCTL_COMMON_H
#define	_KRRP_IOCTL_COMMON_H

#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define	KRRP_IOCTL_FLAG_RESULT  0x00000001
#define	KRRP_IOCTL_FLAG_ERROR   0x00000002

/*
 * Do not forget to bump the version
 * if the order in KRRP_IOCTL_MAP
 * needs to be changed
 */
#define	KRRP_IOCTL_VERSION 0x04

#define	KRRP_IOCTL_MAP(X) \
	X(SVC_ENABLE) \
	X(SVC_DISABLE) \
	X(SVC_STATE) \
	X(SVC_GET_CONFIG) \
	X(SVC_SET_CONFIG) \
	X(SESS_LIST) \
	X(SESS_STATUS) \
	X(SESS_CREATE) \
	X(SESS_DESTROY) \
	X(SESS_CREATE_CONN) \
	X(SESS_CREATE_PDU_ENGINE) \
	X(SESS_CREATE_READ_STREAM) \
	X(SESS_CREATE_WRITE_STREAM) \
	X(SESS_RUN) \
	X(SESS_SEND_STOP) \
	X(SESS_CONN_THROTTLE) \
	X(SESS_SET_PRIVATE_DATA) \
	X(SESS_GET_PRIVATE_DATA) \
	X(SESS_GET_CONN_INFO) \

#define	KRRP_IOCTL_EXPAND(enum_name) KRRP_IOCTL_##enum_name,
typedef enum {
	KRRP_IOCTL_FIRST = (KRRP_IOCTL_VERSION << 24 | 'K' << 16 | 'R' << 8),
	KRRP_IOCTL_MAP(KRRP_IOCTL_EXPAND)
	KRRP_IOCTL_LAST
} krrp_ioctl_cmd_t;
#undef KRRP_IOCTL_EXPAND

typedef struct krrp_ioctl_data_s {
	uint32_t	buf_size;
	uint32_t	data_size;
	uint32_t	in_flags;
	uint32_t	out_flags;
	char		buf[1];
} krrp_ioctl_data_t;

const char *krrp_ioctl_cmd_to_str(krrp_ioctl_cmd_t cmd);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_IOCTL_COMMON_H */

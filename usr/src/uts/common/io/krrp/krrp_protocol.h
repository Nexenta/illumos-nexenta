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
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#ifndef	_KRRP_PROTOCOL_H
#define	_KRRP_PROTOCOL_H

#ifdef __cplusplus
extern "C" {
#endif

#define	KRRP_CTRL_OPCODE_MASK	0x1000

/* Data PDU opcodes */
#define	KRRP_OPCODES_DATA_MAP(X)	\
	X(DATA_WRITE)					\

/* Ctrl PDU opcodes */
#define	KRRP_OPCODES_CTRL_MAP(X)	\
	X(ERROR)						\
	X(ATTACH_SESS)					\
	X(PING)							\
	X(PONG)							\
	X(FL_CTRL_UPDATE)				\
	X(TXG_ACK)						\
	X(TXG_ACK2)						\
	X(SEND_DONE)					\
	X(SHUTDOWN)						\

#define	KRRP_OPCODE_EXPAND(enum_name) KRRP_OPCODE_##enum_name,
typedef enum {
	KRRP_OPCODE_DATA_FIRST = 0,
	KRRP_OPCODES_DATA_MAP(KRRP_OPCODE_EXPAND)

	KRRP_OPCODE_CTRL_FIRST = KRRP_CTRL_OPCODE_MASK,
	KRRP_OPCODES_CTRL_MAP(KRRP_OPCODE_EXPAND)
	KRRP_OPCODE_DATA_LAST
} krrp_opcode_t;
#undef KRRP_OPCODE_EXPAND

const char *krrp_protocol_opcode_str(krrp_opcode_t);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_PROTOCOL_H */

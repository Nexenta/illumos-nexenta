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

#include <sys/types.h>
#include <sys/sysmacros.h>
#include <sys/cmn_err.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>

#include "krrp_protocol.h"

static struct {
	const char		*str;
	krrp_opcode_t	opcode;
} opcodes_str[] = {
#define	KRRP_OPCODE_EXPAND(enum_name) \
	    {"KRRP_OPCODE_"#enum_name, KRRP_OPCODE_##enum_name},
	KRRP_OPCODES_DATA_MAP(KRRP_OPCODE_EXPAND)
	KRRP_OPCODES_CTRL_MAP(KRRP_OPCODE_EXPAND)
#undef KRRP_OPCODE_EXPAND
};

static size_t opcodes_str_sz = sizeof (opcodes_str) / sizeof (opcodes_str[0]);

const char *
krrp_protocol_opcode_str(krrp_opcode_t opcode)
{
	size_t i;

	for (i = 0; i < opcodes_str_sz; i++) {
		if (opcodes_str[i].opcode == opcode)
			return (opcodes_str[i].str);
	}

	return ("KRRP_OPCODE_UNKNOWN");
}

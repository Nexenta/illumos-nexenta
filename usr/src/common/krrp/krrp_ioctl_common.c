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

#include "krrp_ioctl_common.h"

#define	KRRP_IOCTL_EXPAND(enum_name) \
	{KRRP_IOCTL_##enum_name, "KRRP_IOCTL_"#enum_name},
static struct {
	krrp_ioctl_cmd_t	cmd;
	const char			*cmd_str;
} ioctl_cmds[] = {
	KRRP_IOCTL_MAP(KRRP_IOCTL_EXPAND)
};
#undef KRRP_IOCTL_EXPAND

static size_t ioctl_cmds_sz = sizeof (ioctl_cmds) / sizeof (ioctl_cmds[0]);

const char *
krrp_ioctl_cmd_to_str(krrp_ioctl_cmd_t cmd)
{
	size_t i;

	for (i = 0; i < ioctl_cmds_sz; i++) {
		if (ioctl_cmds[i].cmd == cmd)
			return (ioctl_cmds[i].cmd_str);
	}

	return ("KRRP_IOCTL_UNKNOWN");
}

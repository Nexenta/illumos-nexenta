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

#ifndef	_KRRP_IOCTL_H_
#define	_KRRP_IOCTL_H_

#include <sys/sysmacros.h>
#include <sys/types.h>
#include <sys/kmem.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>

#include <krrp_error.h>
#include <krrp_ioctl_common.h>

#ifdef __cplusplus
extern "C" {
#endif

int krrp_ioctl_validate_cmd(krrp_ioctl_cmd_t cmd);
int krrp_ioctl_process(krrp_ioctl_cmd_t cmd, nvlist_t *input,
    nvlist_t *output, krrp_error_t *error);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_IOCTL_H_ */

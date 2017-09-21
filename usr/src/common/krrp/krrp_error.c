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

#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/sunldi.h>
#include <sys/cmn_err.h>
#include <sys/varargs.h>
#include <sys/debug.h>

#include "krrp_params.h"
#include "krrp_error.h"

static struct {
	krrp_errno_t	krrp_errno;
	const char		*krrp_errno_str;
} krrp_errs[] = {
	{KRRP_ERRNO_OK, "KRRP_ERRNO_OK"},
	{KRRP_ERRNO_UNKNOWN, "KRRP_ERRNO_UNKNOWN"},
#define	KRRP_ERRNO_EXPAND(enum_name) \
	{KRRP_ERRNO_##enum_name, "KRRP_ERRNO_"#enum_name},
	KRRP_ERRNO_MAP(KRRP_ERRNO_EXPAND)
#undef KRRP_ERRNO_EXPAND
};

static size_t krrp_errs_sz = sizeof (krrp_errs) / sizeof (krrp_errs[0]);

#ifdef _KERNEL

void
krrp_error_set(krrp_error_t *error, krrp_errno_t krrp_errno,
    int unix_errno)
{
	error->krrp_errno = krrp_errno;
	error->unix_errno = unix_errno;
}

void
krrp_error_set_flag(krrp_error_t *error, krrp_error_flag_t flag)
{
	error->flags |= flag;
}

void
krrp_error_to_nvl(krrp_error_t *error, nvlist_t **result_nvl)
{
	nvlist_t *nvl;

	nvl = (*result_nvl == NULL) ? fnvlist_alloc() : *result_nvl;

	VERIFY3U(krrp_param_put(KRRP_PARAM_ERROR_CODE,
	    nvl, (void *) &error->krrp_errno), ==, 0);
	VERIFY3U(krrp_param_put(KRRP_PARAM_ERROR_EXCODE,
	    nvl, (void *) &error->unix_errno), ==, 0);
	VERIFY3U(krrp_param_put(KRRP_PARAM_ERROR_FLAGS,
	    nvl, (void *) &error->flags), ==, 0);

	*result_nvl = nvl;
}

int
krrp_error_from_nvl(krrp_error_t *res_error, nvlist_t *error_nvl)
{
	int rc;
	krrp_error_t error;

	rc = krrp_param_get(KRRP_PARAM_ERROR_CODE,
	    error_nvl, (void *) &error.krrp_errno);
	if (rc != 0)
		return (rc);

	rc = krrp_param_get(KRRP_PARAM_ERROR_EXCODE,
	    error_nvl, (void *) &error.unix_errno);
	if (rc != 0)
		return (rc);

	rc = krrp_param_get(KRRP_PARAM_ERROR_FLAGS,
	    error_nvl, (void *) &error.flags);
	if (rc != 0)
		return (rc);

	bcopy(&error, res_error, sizeof (krrp_error_t));

	return (0);
}

#endif /* _KERNEL */

const char *
krrp_error_errno_to_str(krrp_errno_t krrp_errno)
{
	size_t i;

	for (i = 0; i < krrp_errs_sz; i++) {
		if (krrp_errs[i].krrp_errno == krrp_errno)
			return (krrp_errs[i].krrp_errno_str);
	}

	return (krrp_error_errno_to_str(KRRP_ERRNO_UNKNOWN));
}

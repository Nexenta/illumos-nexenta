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

#include <sys/sysmacros.h>
#include <sys/types.h>
#include <sys/kmem.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>

#ifdef _KERNEL
#include <sys/debug.h>
#else
#include <assert.h>
#endif

#include "krrp_params.h"

#ifdef _KERNEL
#define	krrp_verify(X) VERIFY(X)
#else
#define	krrp_verify(X) assert(X)
#endif

#define	KRRP_PARAM_EXPAND(enum_name, dtype) \
	{KRRP_PARAM_##enum_name, #enum_name, DATA_TYPE_##dtype},
static struct {
	krrp_param_t	param;
	const char		*name;
	data_type_t		dtype;
} krrp_params[] = {
	{KRRP_PARAM_UNKNOWN, NULL, DATA_TYPE_UNKNOWN},
	KRRP_PARAM_MAP(KRRP_PARAM_EXPAND)
};
#undef KRRP_PARAM_EXPAND
static size_t krrp_params_sz = sizeof (krrp_params) / sizeof (krrp_params[0]);

static const char *krrp_param_get_name(krrp_param_t);
static data_type_t krrp_param_get_dtype(krrp_param_t);

int
krrp_param_get(krrp_param_t p, nvlist_t *nvl, void *result)
{
	int rc = 0;
	data_type_t param_dtype;
	const char *name = NULL;
	krrp_param_array_t *param;

	krrp_verify(nvl != NULL);

	param_dtype = krrp_param_get_dtype(p);
	name = krrp_param_get_name(p);

	switch (param_dtype) {
	case DATA_TYPE_BOOLEAN:
		rc = nvlist_lookup_boolean_value(nvl, name, result);
		break;
	case DATA_TYPE_UINT16:
		rc = nvlist_lookup_uint16(nvl, name, result);
		break;
	case DATA_TYPE_UINT32:
		rc = nvlist_lookup_uint32(nvl, name, result);
		break;
	case DATA_TYPE_INT32:
		rc = nvlist_lookup_int32(nvl, name, result);
		break;
	case DATA_TYPE_UINT64:
		rc = nvlist_lookup_uint64(nvl, name, result);
		break;
	case DATA_TYPE_STRING:
		rc = nvlist_lookup_string(nvl, name, result);
		break;
	case DATA_TYPE_NVLIST:
		rc = nvlist_lookup_nvlist(nvl, name, result);
		break;
	case DATA_TYPE_NVLIST_ARRAY:
		param = result;
		rc = nvlist_lookup_nvlist_array(nvl, name,
		    &param->array, &param->nelem);
		break;
	default:
		krrp_verify(0);
	}

	krrp_verify(rc == 0 || rc == ENOENT);

	return (rc);
}

int
krrp_param_put(krrp_param_t p, nvlist_t *nvl, void *value)
{
	data_type_t param_dtype;
	const char *name = NULL;
	krrp_param_array_t *param;

	krrp_verify(nvl != NULL);

	param_dtype = krrp_param_get_dtype(p);
	name = krrp_param_get_name(p);

	if (nvlist_exists(nvl, name))
		return (EEXIST);

	switch (param_dtype) {
	case DATA_TYPE_BOOLEAN:
		if (value != NULL) {
			fnvlist_add_boolean_value(nvl, name,
			    *((boolean_t *)value));
		} else
			fnvlist_add_boolean_value(nvl, name, B_TRUE);

		break;
	case DATA_TYPE_UINT16:
		fnvlist_add_uint16(nvl, name, *((uint16_t *)value));
		break;
	case DATA_TYPE_UINT32:
		fnvlist_add_uint32(nvl, name, *((uint32_t *)value));
		break;
	case DATA_TYPE_INT32:
		fnvlist_add_int32(nvl, name, *((int32_t *)value));
		break;
	case DATA_TYPE_UINT64:
		fnvlist_add_uint64(nvl, name, *((uint64_t *)value));
		break;
	case DATA_TYPE_STRING:
		krrp_verify(value != NULL);
		fnvlist_add_string(nvl, name, value);
		break;
	case DATA_TYPE_NVLIST:
		fnvlist_add_nvlist(nvl, name, value);
		break;
	case DATA_TYPE_NVLIST_ARRAY:
		param = value;
		fnvlist_add_nvlist_array(nvl, name,
		    param->array, param->nelem);
		break;
	default:
		krrp_verify(0);
	}

	return (0);
}

boolean_t
krrp_param_exists(krrp_param_t p, nvlist_t *nvl)
{
	return (nvlist_exists(nvl, krrp_param_get_name(p)));
}

static const char *
krrp_param_get_name(krrp_param_t p)
{
	if (p > KRRP_PARAM_UNKNOWN && p < krrp_params_sz)
		return (krrp_params[p].name);

	krrp_verify(0);

	return (NULL);
}

static data_type_t
krrp_param_get_dtype(krrp_param_t p)
{
	if (p > KRRP_PARAM_UNKNOWN && p < krrp_params_sz)
		return (krrp_params[p].dtype);

	krrp_verify(0);

	return (DATA_TYPE_UNKNOWN);
}

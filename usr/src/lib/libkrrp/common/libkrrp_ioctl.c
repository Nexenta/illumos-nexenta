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
 * Copyright 2015 Nexenta Systems, Inc. All rights reserved.
 */

#include <sys/debug.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <umem.h>
#include <inttypes.h>

#include <sys/krrp.h>
#include "libkrrp.h"
#include "libkrrp_impl.h"

/*
 * The initial size of buffer that will be
 * passed to kernel when a KRRP_IOCTL is called
 */
#define	LIBKRRP_INIT_BUF_SIZE 4096

static int krrp_ioctl_call(libkrrp_handle_t *, krrp_ioctl_cmd_t,
    krrp_ioctl_data_t *);
static int krrp_ioctl_alloc_data(libkrrp_handle_t *,
    krrp_ioctl_data_t **, size_t);
static void krrp_ioctl_free_data(krrp_ioctl_data_t *);
static int krrp_ioctl_data_from_nvl(libkrrp_handle_t *,
    krrp_ioctl_data_t **, nvlist_t *, size_t);
static int krrp_ioctl_data_to_nvl(libkrrp_handle_t *,
    krrp_ioctl_data_t *, nvlist_t **);

int
krrp_ioctl_perform(libkrrp_handle_t *hdl, krrp_ioctl_cmd_t cmd,
    nvlist_t *in_params, nvlist_t **out_params)
{
	int rc;
	size_t buf_sz, attempt = 0;
	krrp_ioctl_data_t *ioctl_data = NULL;
	nvlist_t *result_nvl = NULL;

	VERIFY(hdl != NULL);

	hdl->libkrrp_last_cmd = cmd;

	/*
	 * To get result from kernel we pass to it a buffer.
	 * If kernel has more data than the size of the buffer
	 * then it returns ENOSPC. In this case IOCTL will be
	 * called no more than 10 times and on each iteration
	 * the size of the buffer will be doubled.
	 */
	buf_sz = LIBKRRP_INIT_BUF_SIZE;
	for (;;) {
		rc = krrp_ioctl_data_from_nvl(hdl,
		    &ioctl_data, in_params, buf_sz);
		if (rc != 0)
			return (-1);

		rc = krrp_ioctl_call(hdl, cmd, ioctl_data);
		if (rc != 0) {
			const libkrrp_error_t *err = libkrrp_error(hdl);
			if (err->unix_errno == ENOSPC) {
				if (++attempt > 10)
					goto fini;

				krrp_ioctl_free_data(ioctl_data);
				ioctl_data = NULL;
				buf_sz *= 2;
				continue;
			}

			goto fini;
		}

		break;
	}

	VERIFY0(rc);

	rc = krrp_ioctl_data_to_nvl(hdl, ioctl_data, &result_nvl);
	if (rc != 0)
		goto fini;

	if (ioctl_data->out_flags & KRRP_IOCTL_FLAG_ERROR) {
		VERIFY0(libkrrp_error_from_nvl(result_nvl,
		    &hdl->libkrrp_error));
		rc = -1;
		fnvlist_free(result_nvl);
	} else if (ioctl_data->out_flags & KRRP_IOCTL_FLAG_RESULT) {
		VERIFY(out_params != NULL && *out_params == NULL);
		*out_params = result_nvl;
	}

fini:
	krrp_ioctl_free_data(ioctl_data);
	return (rc);
}

static int
krrp_ioctl_call(libkrrp_handle_t *hdl, krrp_ioctl_cmd_t cmd,
    krrp_ioctl_data_t *ioctl_data)
{
	int rc;

	rc = ioctl(hdl->libkrrp_fd, cmd, ioctl_data);

	if (rc != 0) {
		switch (errno) {
		case ENOTACTIVE:
			libkrrp_error_set(&hdl->libkrrp_error,
			    LIBKRRP_ERRNO_SVCNOTACTIVE, 0, 0);
			break;
		case EALREADY:
			libkrrp_error_set(&hdl->libkrrp_error,
			    LIBKRRP_ERRNO_SVCACTIVE, 0, 0);
			break;
		case ENOTSUP:
			libkrrp_error_set(&hdl->libkrrp_error,
			    LIBKRRP_ERRNO_NOTSUP, 0, 0);
			break;
		default:
			libkrrp_error_set(&hdl->libkrrp_error,
			    LIBKRRP_ERRNO_IOCTLFAIL, errno, 0);
		}
		return (-1);
	}

	return (0);
}

static int
krrp_ioctl_alloc_data(libkrrp_handle_t *hdl, krrp_ioctl_data_t **res_ioctl_data,
    size_t buf_size)
{
	krrp_ioctl_data_t *ioctl_data;

	VERIFY(buf_size <= UINT32_MAX);

	ioctl_data = umem_alloc(sizeof (krrp_ioctl_data_t) + buf_size,
	    UMEM_DEFAULT);

	if (ioctl_data == NULL) {
		libkrrp_error_set(&hdl->libkrrp_error, LIBKRRP_ERRNO_NOMEM,
		    errno, 0);
		return (-1);
	}

	(void) memset(ioctl_data, 0, sizeof (krrp_ioctl_data_t));

	ioctl_data->buf_size = buf_size;

	*res_ioctl_data = ioctl_data;

	return (0);
}

static void
krrp_ioctl_free_data(krrp_ioctl_data_t *ioctl_data)
{
	umem_free(ioctl_data, sizeof (krrp_ioctl_data_t) +
	    ioctl_data->buf_size);
}

static int
krrp_ioctl_data_from_nvl(libkrrp_handle_t *hdl,
    krrp_ioctl_data_t **res_ioctl_data, nvlist_t *params,
    size_t add_size)
{
	int rc;
	size_t packed_size = 0;
	krrp_ioctl_data_t *ioctl_data = NULL;

	if (params != NULL)
		packed_size = fnvlist_size(params);

	rc = krrp_ioctl_alloc_data(hdl, &ioctl_data,
	    packed_size + add_size);
	if (rc != 0)
		return (-1);

	if (params != NULL) {
		char *buf = ioctl_data->buf;
		VERIFY0(nvlist_pack(params, &buf,
		    &packed_size, NV_ENCODE_NATIVE, 0));
		ioctl_data->data_size = packed_size;
	}

	*res_ioctl_data = ioctl_data;

	return (0);
}

static int
krrp_ioctl_data_to_nvl(libkrrp_handle_t *hdl, krrp_ioctl_data_t *ioctl_data,
    nvlist_t **result_nvl)
{
	nvlist_t *nvl = NULL;
	int rc;

	if (!(ioctl_data->out_flags & KRRP_IOCTL_FLAG_ERROR) &&
	    !(ioctl_data->out_flags & KRRP_IOCTL_FLAG_RESULT))
		return (0);

	VERIFY(*result_nvl == NULL && result_nvl != NULL);
	VERIFY(ioctl_data->data_size != 0);

	rc = nvlist_unpack(ioctl_data->buf,
	    ioctl_data->data_size, &nvl, 0);

	if (rc == ENOMEM) {
		libkrrp_error_set(&hdl->libkrrp_error,
		    LIBKRRP_ERRNO_NOMEM, rc, 0);
	} else if (rc != 0) {
		libkrrp_error_set(&hdl->libkrrp_error,
		    LIBKRRP_ERRNO_IOCTLDATAFAIL, rc, 0);
		return (-1);
	}

	*result_nvl = nvl;
	return (0);
}

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

/*
 * Kernel Remote Replication Protocol (KRRP)
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/kmem.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/sunldi.h>
#include <sys/time.h>
#include <sys/strsubr.h>
#include <sys/sysmacros.h>
#include <sys/sdt.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>

#include <krrp_error.h>
#include <sys/krrp.h>

#include "krrp_svc.h"
#include "krrp_ioctl.h"

static int krrp_open(dev_t *, int, int, cred_t *);
static int krrp_close(dev_t, int, int, cred_t *);
static int krrp_ioctl(dev_t, int, intptr_t, int, cred_t *, int *);
static int krrp_info(dev_info_t *, ddi_info_cmd_t, void *, void **);
static int krrp_attach(dev_info_t *, ddi_attach_cmd_t);
static int krrp_detach(dev_info_t *, ddi_detach_cmd_t);

static struct cb_ops krrp_cb_ops = {
	krrp_open,	/* open */
	krrp_close,	/* close */
	nodev,		/* strategy */
	nodev,		/* print */
	nodev,		/* dump */
	nodev,		/* read */
	nodev,		/* write */
	krrp_ioctl,	/* ioctl */
	nodev,		/* devmap */
	nodev,		/* mmap */
	nodev,		/* segmap */
	nochpoll,	/* poll */
	ddi_prop_op,	/* prop_op */
	NULL,		/* streamtab */
	D_NEW | D_MP | D_64BIT,		/* Driver compatibility flag */
	CB_REV,		/* version */
	nodev,		/* async read */
	nodev,		/* async write */
};

static struct dev_ops krrp_dev_ops = {
	DEVO_REV,	/* version */
	0,		/* refcnt */
	krrp_info,	/* info */
	nulldev,	/* identify */
	nulldev,	/* probe */
	krrp_attach,	/* attach */
	krrp_detach,	/* detach */
	nodev,		/* reset */
	&krrp_cb_ops,	/* driver operations */
	NULL		/* no bus operations */
};

static struct modldrv modldrv = {
	&mod_driverops,
	"kernel remote replication protocol module",
	&krrp_dev_ops
};

static struct modlinkage modlinkage = {
	MODREV_1, (void *)&modldrv, NULL
};

static uint16_t version = 1;

int
_init(void)
{
	int rc;
	krrp_svc_t *krrp_svc;

	krrp_svc = krrp_svc_get_instance();

	rc = ldi_ident_from_mod(&modlinkage, &krrp_svc->li);
	if (rc != 0)
		return (rc);

	rc = mod_install(&modlinkage);
	if (rc) {
		ldi_ident_release(krrp_svc->li);
		return (rc);
	}

	krrp_svc_init();

	return (0);
}

int
_fini(void)
{
	int error;
	krrp_svc_t *krrp_svc;

	krrp_svc = krrp_svc_get_instance();

	error = mod_remove(&modlinkage);
	if (error != 0)
		return (error);

	ldi_ident_release(krrp_svc->li);

	krrp_svc_fini();

	return (0);
}

int
_info(struct modinfo *modinfop)
{
	return (mod_info(&modlinkage, modinfop));
}

/* ARGSUSED */
static int
krrp_open(dev_t *devp, int flag, int otyp, cred_t *cr)
{
	return (0);
}

/* ARGSUSED */
static int
krrp_close(dev_t dev, int flag, int otyp, cred_t *cr)
{
	return (0);
}

/* ARGSUSED */
static int
krrp_ioctl(dev_t dev, int cmd, intptr_t argp, int flags, cred_t *cr, int *rvalp)
{
	int rc = 0;
	size_t size = 0;
	size_t total_size;
	krrp_ioctl_data_t ioctl_data_hdr, *ioctl_data;
	nvlist_t *in_nvl = NULL;
	nvlist_t *out_nvl = NULL;
	nvlist_t *error_nvl = NULL;
	krrp_error_t error;
	boolean_t ref_cnt_held;

	if (krrp_ioctl_validate_cmd(cmd) != 0) {
		cmn_err(CE_WARN, "Invalid ioctl command (%d) "
		    "or version mismatch", cmd);
		return (ENOTSUP);
	}

	ref_cnt_held = krrp_svc_ref_cnt_try_hold() == 0;
	if (!ref_cnt_held && cmd != KRRP_IOCTL_SVC_ENABLE &&
	    cmd != KRRP_IOCTL_SVC_STATE) {
		cmn_err(CE_WARN, "KRRP in-kernel service is not enabled");
		return (ENOTACTIVE);
	}

	if (ref_cnt_held && cmd == KRRP_IOCTL_SVC_ENABLE) {
		cmn_err(CE_WARN, "KRRP in-kernel service already enabled");
		rc = EALREADY;
		goto out;
	}

	(void) memset(&ioctl_data_hdr, 0, sizeof (ioctl_data_hdr));
	rc = ddi_copyin((void *) argp, &ioctl_data_hdr,
	    sizeof (krrp_ioctl_data_t), flags);
	if (rc != 0) {
		cmn_err(CE_WARN, "Failed to ddi_copyin() ioctl data hdr");
		rc = EFAULT;
		goto out;
	}

	if (ioctl_data_hdr.buf_size == 0) {
		cmn_err(CE_WARN, "No data buffer");
		rc = ENOBUFS;
		goto out;
	}

	total_size = sizeof (krrp_ioctl_data_t) + ioctl_data_hdr.buf_size;
	ioctl_data = kmem_alloc(total_size, KM_SLEEP);
	rc = ddi_copyin((void *) argp, ioctl_data, total_size, flags);
	if (rc != 0) {
		cmn_err(CE_WARN, "Failed to ddi_copyin() ioctl data buffer");
		rc = EFAULT;
		goto out;
	}

	if (ioctl_data->data_size != 0) {
		rc = nvlist_unpack(ioctl_data->buf,
		    ioctl_data->data_size, &in_nvl, KM_SLEEP);
		if (rc != 0) {
			/*
			 * Unpacking of userspace data is a fatal error
			 * (incorrect use of ioctl API),
			 * so we just print error to syslog and return
			 */
			cmn_err(CE_WARN, "Failed to unpack nvlist [%d]", rc);
			goto out_kmem_free;
		}
	}

	out_nvl = fnvlist_alloc();

	krrp_error_init(&error);
	rc = krrp_ioctl_process(cmd, in_nvl, out_nvl, &error);

	/*
	 * Ioctl has been successfully executed.
	 * So lets try to pack its result if exists
	 */
	if (rc == 0) {
		VERIFY(error.krrp_errno == 0);

		if (nvlist_empty(out_nvl)) {
			ioctl_data->data_size = 0;
		} else {
			size = fnvlist_size(out_nvl);
			if (size > ioctl_data->buf_size) {
				rc = ENOSPC;
				goto out_nvl_free;
			} else {
				char *buf;

				buf = ioctl_data->buf;
				VERIFY3U(nvlist_pack(out_nvl, (char **)&buf,
				    &size, NV_ENCODE_NATIVE, KM_SLEEP), ==, 0);
				ioctl_data->data_size = (uint64_t)size;
				ioctl_data->out_flags |= KRRP_IOCTL_FLAG_RESULT;
			}
		}
	}

	/*
	 * An error occurred during execution of ioctl or
	 * during packing of its result
	 * lets try to copyout the error
	 */
	if (rc != 0 || error.krrp_errno != 0) {
		VERIFY(error.krrp_errno != 0);

		cmn_err(CE_WARN, "KRRP Error: [cmd: %d] [%s] [%d]",
		    cmd, krrp_error_errno_to_str(error.krrp_errno),
		    error.unix_errno);

		krrp_error_to_nvl(&error, &error_nvl);

		size = fnvlist_size(error_nvl);
		if (size > ioctl_data->buf_size) {
			cmn_err(CE_WARN, "The size of provided buffer "
			    "is to small to store the following error:\n"
			    "[ke: [%d], ue: [%d]]",
			    error.krrp_errno, error.unix_errno);
			rc = ENOSPC;
		} else {
			char *buf;

			buf = ioctl_data->buf;
			VERIFY3U(nvlist_pack(error_nvl, (char **)&buf,
			    &size, NV_ENCODE_NATIVE, KM_SLEEP), ==, 0);
			rc = 0;
			ioctl_data->data_size = (uint64_t)size;
			ioctl_data->out_flags |= KRRP_IOCTL_FLAG_ERROR;
		}

		fnvlist_free(error_nvl);
	}

	/*
	 * rc == 0 if
	 *  - successfully executed ioctl
	 *  - an error occurred and we successfully packed it
	 *
	 *  So here we try to copyout the data
	 */
	if (rc == 0) {
		rc = ddi_copyout((void *) ioctl_data, (void *) argp,
		    total_size, flags);
		if (rc != 0) {
			cmn_err(CE_WARN, "Failed to ddi_copyout() "
			    "ioctl data buffer");
			rc = EFAULT;
		}
	}

out_nvl_free:
	fnvlist_free(out_nvl);
	fnvlist_free(in_nvl);

out_kmem_free:
	kmem_free(ioctl_data, total_size);

out:
	if (ref_cnt_held)
		krrp_svc_ref_cnt_rele();

	return (rc);
}

/* ARGSUSED */
static int
krrp_info(dev_info_t *dip, ddi_info_cmd_t infocmd, void *arg, void **result)
{
	krrp_svc_t *krrp_svc;

	krrp_svc = krrp_svc_get_instance();

	switch (infocmd) {
	case DDI_INFO_DEVT2DEVINFO:
		*result = krrp_svc->dip;
		return (DDI_SUCCESS);
	case DDI_INFO_DEVT2INSTANCE:
		*result = (void *) 0;
		return (DDI_SUCCESS);
	default:
		return (DDI_FAILURE);
	}
}

static int
krrp_attach(dev_info_t *dip, ddi_attach_cmd_t cmd)
{
	if (cmd != DDI_ATTACH)
		return (DDI_FAILURE);

	if (ddi_get_instance(dip) != 0)
		return (DDI_FAILURE);

	if (ddi_create_minor_node(dip, KRRP_DRIVER, S_IFCHR, 0,
	    DDI_PSEUDO, 0) != DDI_SUCCESS) {
		return (DDI_FAILURE);
	}

	krrp_svc_attach(dip);
	ddi_report_dev(dip);

	return (DDI_SUCCESS);
}

static int
krrp_detach(dev_info_t *dip, ddi_detach_cmd_t cmd)
{
	if (cmd != DDI_DETACH)
		return (DDI_FAILURE);

	if (krrp_svc_detach() != 0)
		return (EBUSY);

	ddi_remove_minor_node(dip, NULL);
	ddi_prop_remove_all(dip);

	return (DDI_SUCCESS);
}

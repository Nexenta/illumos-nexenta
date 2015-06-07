/*
 * Copyright (C) 2007 VMware, Inc. All rights reserved.
 *
 * The contents of this file are subject to the terms of the Common
 * Development and Distribution License (the "License") version 1.0
 * and no later version.  You may not use this file except in
 * compliance with the License.
 *
 * You can obtain a copy of the License at
 *         http://www.opensource.org/licenses/cddl1.php
 *
 * See the License for the specific language governing permissions
 * and limitations under the License.
 */

/*
 * Copyright 2012 Nexenta Systems, Inc. All rights reserved.
 */

#include "vmxnet3s.h"

/* Used by ddi_regs_map_setup() and ddi_dma_mem_alloc() */
ddi_device_acc_attr_t vmxnet3s_dev_attr = {
	DDI_DEVICE_ATTR_V0,
	DDI_STRUCTURE_LE_ACC,
	DDI_STRICTORDER_ACC
};

/* Buffers with no alignment constraint DMA description */
static ddi_dma_attr_t vmxnet3s_dma1 = {
	DMA_ATTR_V0,		/* dma_attr_version */
	0x0000000000000000ull,	/* dma_attr_addr_lo */
	0xffffffffffffffffull,	/* dma_attr_addr_hi */
	0xffffffffffffffffull,	/* dma_attr_count_max */
	0x0000000000000001ull,	/* dma_attr_align */
	0x0000000000000001ull,	/* dma_attr_burstsizes */
	0x00000001,		/* dma_attr_minxfer */
	0xffffffffffffffffull,	/* dma_attr_maxxfer */
	0xffffffffffffffffull,	/* dma_attr_seg */
	1,			/* dma_attr_sgllen */
	0x00000001,		/* dma_attr_granular */
	0			/* dma_attr_flags */
};

/* Buffers with a 128-bytes alignment constraint DMA description */
static ddi_dma_attr_t vmxnet3s_dma128 = {
	DMA_ATTR_V0,		/* dma_attr_version */
	0x0000000000000000ull,	/* dma_attr_addr_lo */
	0xffffffffffffffffull,	/* dma_attr_addr_hi */
	0xffffffffffffffffull,	/* dma_attr_count_max */
	0x0000000000000080ull,	/* dma_attr_align */
	0x0000000000000001ull,	/* dma_attr_burstsizes */
	0x00000001,		/* dma_attr_minxfer */
	0xffffffffffffffffull,	/* dma_attr_maxxfer */
	0xffffffffffffffffull,	/* dma_attr_seg */
	1,			/* dma_attr_sgllen */
	0x00000001,		/* dma_attr_granular */
	0			/* dma_attr_flags */
};

/* Buffers with a 512-bytes alignment constraint DMA description */
static ddi_dma_attr_t vmxnet3s_dma512 = {
	DMA_ATTR_V0,		/* dma_attr_version */
	0x0000000000000000ull,	/* dma_attr_addr_lo */
	0xffffffffffffffffull,	/* dma_attr_addr_hi */
	0xffffffffffffffffull,	/* dma_attr_count_max */
	0x0000000000000200ull,	/* dma_attr_align */
	0x0000000000000001ull,	/* dma_attr_burstsizes */
	0x00000001,		/* dma_attr_minxfer */
	0xffffffffffffffffull,	/* dma_attr_maxxfer */
	0xffffffffffffffffull,	/* dma_attr_seg */
	1,			/* dma_attr_sgllen */
	0x00000001,		/* dma_attr_granular */
	0			/* dma_attr_flags */
};

/*
 * Allocate /size/ bytes of contiguous DMA-ble memory.
 */
static int
vmxnet3s_alloc(vmxnet3s_softc_t *dp, vmxnet3s_dmabuf_t *dma,
    size_t size, boolean_t cansleep, ddi_dma_attr_t *dma_attrs)
{
	ddi_dma_cookie_t cookie;
	uint_t		cookiecount;
	int (*cb) (caddr_t) = cansleep ? DDI_DMA_SLEEP : DDI_DMA_DONTWAIT;

	ASSERT(size != 0);

	/* Allocate a DMA handle */
	if (ddi_dma_alloc_handle(dp->dip, dma_attrs, cb, NULL,
	    &dma->dmahdl) != DDI_SUCCESS)
		goto error;

	/* Allocate memory */
	if (ddi_dma_mem_alloc(dma->dmahdl, size, &vmxnet3s_dev_attr,
	    DDI_DMA_CONSISTENT, cb, NULL, &dma->buf, &dma->buflen,
	    &dma->datahdl) != DDI_SUCCESS)
		goto error_dma_handle;

	/* Map the memory */
	if (ddi_dma_addr_bind_handle(dma->dmahdl, NULL,
	    dma->buf, dma->buflen, DDI_DMA_RDWR | DDI_DMA_STREAMING,
	    cb, NULL, &cookie, &cookiecount) != DDI_DMA_MAPPED)
		goto error_dma_mem;

	ASSERT(cookiecount == 1);
	dma->bufpa = cookie.dmac_laddress;

	return (DDI_SUCCESS);

error_dma_mem:
	ddi_dma_mem_free(&dma->datahdl);
error_dma_handle:
	ddi_dma_free_handle(&dma->dmahdl);
error:
	dma->buf = NULL;
	dma->bufpa = NULL;
	dma->buflen = 0;

	return (DDI_FAILURE);
}

int
vmxnet3s_alloc1(vmxnet3s_softc_t *dp, vmxnet3s_dmabuf_t *dma,
    size_t size, boolean_t cansleep)
{

	return (vmxnet3s_alloc(dp, dma, size, cansleep, &vmxnet3s_dma1));
}

int
vmxnet3s_alloc128(vmxnet3s_softc_t *dp, vmxnet3s_dmabuf_t *dma,
    size_t size, boolean_t cansleep)
{

	return (vmxnet3s_alloc(dp, dma, size, cansleep, &vmxnet3s_dma128));
}

int
vmxnet3s_alloc512(vmxnet3s_softc_t *dp, vmxnet3s_dmabuf_t *dma,
    size_t size, boolean_t cansleep)
{

	return (vmxnet3s_alloc(dp, dma, size, cansleep, &vmxnet3s_dma512));
}

/*
 * Free DMA-ble memory.
 */
void
vmxnet3s_free(vmxnet3s_dmabuf_t *dma)
{

	(void) ddi_dma_unbind_handle(dma->dmahdl);
	ddi_dma_mem_free(&dma->datahdl);
	ddi_dma_free_handle(&dma->dmahdl);

	dma->buf = NULL;
	dma->bufpa = NULL;
	dma->buflen = 0;
}

/*
 * Get the numeric value of the property "name" in vmxnet3s.conf for
 * the corresponding device instance.
 * If the property isn't found or if it doesn't satisfy the conditions,
 * "def" is returned.
 */
int
vmxnet3s_getprop(vmxnet3s_softc_t *dp, char *name, int min, int max, int def)
{
	int	ret = def;
	int	*props;
	uint_t	nprops;

	if (ddi_prop_lookup_int_array(DDI_DEV_T_ANY, dp->dip, DDI_PROP_DONTPASS,
	    name, &props, &nprops) == DDI_PROP_SUCCESS) {
		if (dp->instance < nprops)
			ret = props[dp->instance];
		ddi_prop_free(props);
	}

	if (ret < min || ret > max) {
		ASSERT(def >= min && def <= max);
		ret = def;
	}

	return (ret);
}

/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright (c) 2009-2012 Emulex. All rights reserved.
 * Use is subject to license terms.
 */



/*
 * Source file containing the implementation of the Hardware specific
 * functions
 */

#include <oce_impl.h>
#include <oce_stat.h>
#include <oce_ioctl.h>

static ddi_device_acc_attr_t reg_accattr = {
	DDI_DEVICE_ATTR_V1,
	DDI_STRUCTURE_LE_ACC,
	DDI_STRICTORDER_ACC,
	DDI_FLAGERR_ACC
};

extern int oce_destroy_q(struct oce_dev *dev, struct oce_mbx *mbx,
    size_t req_size, enum qtype qtype, uint32_t mode);

static int
oce_map_regs(struct oce_dev *dev)
{
	int ret = 0;
	off_t bar_size = 0;

	ASSERT(NULL != dev);
	ASSERT(NULL != dev->dip);

	/* get number of supported bars */
	ret = ddi_dev_nregs(dev->dip, &dev->num_bars);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Could not retrieve num_bars, ret =0x%x", ret);
		return (DDI_FAILURE);
	}

	if (LANCER_CHIP(dev)) {
		/* Doorbells */
		ret = ddi_dev_regsize(dev->dip, OCE_PCI_LANCER_DB_BAR,
		    &bar_size);
		if (ret != DDI_SUCCESS) {
			oce_log(dev, CE_WARN, MOD_CONFIG,
			    "%d Could not get sizeof BAR %d",
			    ret, OCE_PCI_LANCER_DB_BAR);
			return (DDI_FAILURE);
		}

		ret = ddi_regs_map_setup(dev->dip, OCE_PCI_LANCER_DB_BAR,
		    &dev->db_addr, 0, 0, &reg_accattr, &dev->db_handle);
		if (ret != DDI_SUCCESS) {
			oce_log(dev, CE_WARN, MOD_CONFIG,
			    "Could not map bar %d", OCE_PCI_LANCER_DB_BAR);
			return (DDI_FAILURE);
		}
		return (DDI_SUCCESS);
	}

	/* verify each bar and map it accordingly */
	/* PCI CFG */
	ret = ddi_dev_regsize(dev->dip, OCE_DEV_CFG_BAR, &bar_size);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Could not get sizeof BAR %d",
		    OCE_DEV_CFG_BAR);
		return (DDI_FAILURE);
	}

	ret = ddi_regs_map_setup(dev->dip, OCE_DEV_CFG_BAR, &dev->dev_cfg_addr,
	    0, bar_size, &reg_accattr, &dev->dev_cfg_handle);

	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Could not map bar %d",
		    OCE_DEV_CFG_BAR);
		return (DDI_FAILURE);
	}

	/* CSR */
	ret = ddi_dev_regsize(dev->dip, OCE_PCI_CSR_BAR, &bar_size);

	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Could not get sizeof BAR %d",
		    OCE_PCI_CSR_BAR);
		return (DDI_FAILURE);
	}

	ret = ddi_regs_map_setup(dev->dip, OCE_PCI_CSR_BAR, &dev->csr_addr,
	    0, bar_size, &reg_accattr, &dev->csr_handle);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Could not map bar %d",
		    OCE_PCI_CSR_BAR);
		ddi_regs_map_free(&dev->dev_cfg_handle);
		return (DDI_FAILURE);
	}

	/* Doorbells */
	ret = ddi_dev_regsize(dev->dip, OCE_PCI_DB_BAR, &bar_size);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "%d Could not get sizeof BAR %d",
		    ret, OCE_PCI_DB_BAR);
		ddi_regs_map_free(&dev->csr_handle);
		ddi_regs_map_free(&dev->dev_cfg_handle);
		return (DDI_FAILURE);
	}

	ret = ddi_regs_map_setup(dev->dip, OCE_PCI_DB_BAR, &dev->db_addr,
	    0, 0, &reg_accattr, &dev->db_handle);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Could not map bar %d", OCE_PCI_DB_BAR);
		ddi_regs_map_free(&dev->csr_handle);
		ddi_regs_map_free(&dev->dev_cfg_handle);
		return (DDI_FAILURE);
	}
	return (DDI_SUCCESS);
}
static void
oce_unmap_regs(struct oce_dev *dev)
{

	ASSERT(NULL != dev);
	ASSERT(NULL != dev->dip);

	ddi_regs_map_free(&dev->db_handle);
	if (!LANCER_CHIP(dev)) {
		ddi_regs_map_free(&dev->csr_handle);
		ddi_regs_map_free(&dev->dev_cfg_handle);
	}

}


static void
oce_check_slot(struct oce_dev *dev)
{
	uint32_t curr = 0;
	uint32_t max = 0;
	uint32_t width = 0;
	uint32_t max_width = 0;
	uint32_t speed = 0;
	uint32_t max_speed = 0;

	curr = OCE_CFG_READ32(dev, PCICFG_PCIE_LINK_STATUS_OFFSET);

	width = (curr >> PCIE_LINK_STATUS_NEG_WIDTH_SHIFT) &
	    PCIE_LINK_STATUS_NEG_WIDTH_MASK;
	speed = (curr >> PCIE_LINK_STATUS_SPEED_SHIFT) &
	    PCIE_LINK_STATUS_SPEED_MASK;

	oce_log(dev, CE_NOTE, MOD_CONFIG, "Reg value %x"
	    " width %d speed %d\n", curr, width,  speed);
	max = OCE_CFG_READ32(dev, PCICFG_PCIE_LINK_CAP_OFFSET);

	max_width = (max >> PCIE_LINK_CAP_MAX_WIDTH_SHIFT) &
	    PCIE_LINK_CAP_MAX_WIDTH_MASK;
	max_speed = (max >> PCIE_LINK_CAP_MAX_SPEED_SHIFT) &
	    PCIE_LINK_CAP_MAX_SPEED_MASK;
	oce_log(dev, CE_NOTE, MOD_CONFIG, "Reg value %x"
	    " max_width %d max_speed %d\n",
	    max, max_width,  max_speed);

	if (width < max_width || speed < max_speed) {
			oce_log(dev, CE_NOTE, MOD_CONFIG,
			    "Found CNA device in a Gen%s x%d PCIe Slot."
			    "It is recommended to be in a Gen2 x%d slot"
			    "for best performance\n",
			    speed < max_speed ? "1" : "2",
			    width, max_width);
	}
}


/*
 * function to map the device memory
 *
 * dev - handle to device private data structure
 *
 */
int
oce_pci_init(struct oce_dev *dev)
{
	int ret = 0;

	ret = oce_map_regs(dev);

	if (ret != DDI_SUCCESS) {
		return (DDI_FAILURE);
	}

	if (!LANCER_CHIP(dev)) {
		dev->fn =  OCE_PCI_FUNC(dev);
		if (oce_fm_check_acc_handle(dev, dev->dev_cfg_handle) !=
		    DDI_FM_OK) {
			ddi_fm_service_impact(dev->dip, DDI_SERVICE_DEGRADED);
		}
	}

	if (ret != DDI_FM_OK) {
		oce_pci_fini(dev);
		return (DDI_FAILURE);
	}

	if (!LANCER_CHIP(dev))
		oce_check_slot(dev);

	return (DDI_SUCCESS);
} /* oce_pci_init */

/*
 * function to free device memory mapping mapped using
 * oce_pci_init
 *
 * dev - handle to device private data
 */
void
oce_pci_fini(struct oce_dev *dev)
{
	oce_unmap_regs(dev);
} /* oce_pci_fini */


int
oce_identify_hw(struct oce_dev *dev)
{
	int ret = DDI_SUCCESS;
	uint32_t if_type = 0, sli_intf = 0;

	dev->vendor_id = pci_config_get16(dev->pci_cfg_handle,
	    PCI_CONF_VENID);
	dev->device_id = pci_config_get16(dev->pci_cfg_handle,
	    PCI_CONF_DEVID);
	dev->subsys_id = pci_config_get16(dev->pci_cfg_handle,
	    PCI_CONF_SUBSYSID);
	dev->subvendor_id = pci_config_get16(dev->pci_cfg_handle,
	    PCI_CONF_SUBVENID);

	switch (dev->device_id) {

	case DEVID_TIGERSHARK:
		dev->chip_rev = OC_CNA_GEN2;
		/* BE2 hardware properly supports single tx ring */
		dev->tx_rings = 1;
		break;
	case DEVID_TOMCAT:
		dev->chip_rev = OC_CNA_GEN3;
		break;
	case DEVID_LANCER:
		sli_intf = pci_config_get32(dev->pci_cfg_handle,
		    SLI_INTF_REG_OFFSET);

		if_type = (sli_intf & SLI_INTF_IF_TYPE_MASK) >>
		    SLI_INTF_IF_TYPE_SHIFT;

		if (((sli_intf & SLI_INTF_VALID_MASK) != SLI_INTF_VALID) ||
		    if_type != 0x02) {
			oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
			    "SLI I/F not Valid or different interface type\n");
			ret = DDI_FAILURE;
			break;
		}
		dev->sli_family = ((sli_intf & SLI_INTF_FAMILY_MASK) >>
		    SLI_INTF_FAMILY_SHIFT);

		dev->chip_rev = 0;
		break;

	default:
		dev->chip_rev = 0;
		ret = DDI_FAILURE;
		break;
	}
	return (ret);
}


/*
 * function to check if a reset is required
 *
 * dev - software handle to the device
 *
 */
boolean_t
oce_is_reset_pci(struct oce_dev *dev)
{
	mpu_ep_semaphore_t post_status;

	ASSERT(dev != NULL);
	ASSERT(dev->dip != NULL);

	post_status.dw0 = 0;
	post_status.dw0 = OCE_CSR_READ32(dev, MPU_EP_SEMAPHORE);

	if (post_status.bits.stage == POST_STAGE_ARMFW_READY) {
		return (B_FALSE);
	}
	return (B_TRUE);
} /* oce_is_reset_pci */

/*
 * function to do a soft reset on the device
 *
 * dev - software handle to the device
 *
 */
int
oce_pci_soft_reset(struct oce_dev *dev)
{
	pcicfg_soft_reset_t soft_rst;
	/* struct mpu_ep_control ep_control; */
	/* struct pcicfg_online1 online1; */
	clock_t tmo;
	clock_t earlier = ddi_get_lbolt();

	ASSERT(dev != NULL);

	/* issue soft reset */
	soft_rst.dw0 = OCE_CFG_READ32(dev, PCICFG_SOFT_RESET);
	soft_rst.bits.soft_reset = 0x01;
	OCE_CFG_WRITE32(dev, PCICFG_SOFT_RESET, soft_rst.dw0);

	/* wait till soft reset bit deasserts */
	tmo = drv_usectohz(60000000); /* 1.0min */
	do {
		if ((ddi_get_lbolt() - earlier) > tmo) {
			tmo = 0;
			break;
		}

		soft_rst.dw0 = OCE_CFG_READ32(dev, PCICFG_SOFT_RESET);
		if (soft_rst.bits.soft_reset)
			drv_usecwait(100);
	} while (soft_rst.bits.soft_reset);

	if (soft_rst.bits.soft_reset) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "0x%x soft_reset"
		    "bit asserted[1]. Reset failed",
		    soft_rst.dw0);
		return (DDI_FAILURE);
	}

	return (oce_POST(dev));
} /* oce_pci_soft_reset */


static int lancer_wait_ready(struct oce_dev *dev)
{
	uint32_t sliport_status;
	int status = 0, i;

	for (i = 0; i < SLIPORT_READY_TIMEOUT; i++) {
		sliport_status = OCE_DB_READ32(dev, SLIPORT_STATUS_OFFSET);
			if (oce_fm_check_acc_handle(dev, dev->db_handle) !=
			    DDI_FM_OK) {
				ddi_fm_service_impact(dev->dip,
				    DDI_SERVICE_DEGRADED);
				return (EIO);
			}
		if (sliport_status & SLIPORT_STATUS_RDY_MASK)
			break;
		drv_usecwait(20000);
	}

	if (i == SLIPORT_READY_TIMEOUT)
		status = DDI_FAILURE;

	return (status);
}

static int lancer_test_and_set_rdy_state(struct oce_dev *dev)
{
	int status;
	uint32_t sliport_status, err, reset_needed;
	status = lancer_wait_ready(dev);
	if (!status) {
		sliport_status = OCE_DB_READ32(dev, SLIPORT_STATUS_OFFSET);
		if (oce_fm_check_acc_handle(dev, dev->db_handle) != DDI_FM_OK) {
			ddi_fm_service_impact(dev->dip, DDI_SERVICE_DEGRADED);
			return (EIO);
		}
		err = sliport_status & SLIPORT_STATUS_ERR_MASK;
		reset_needed = sliport_status & SLIPORT_STATUS_RN_MASK;
		if (err && reset_needed) {
			OCE_DB_WRITE32(dev, SLIPORT_CONTROL_OFFSET,
			    SLI_PORT_CONTROL_IP_MASK);
			if (oce_fm_check_acc_handle(dev, dev->db_handle) !=
			    DDI_FM_OK) {
				ddi_fm_service_impact(dev->dip,
				    DDI_SERVICE_DEGRADED);
				return (EIO);
			}
			/* check adapter has corrected the error */
			status = lancer_wait_ready(dev);
			sliport_status = OCE_DB_READ32(dev,
			    SLIPORT_STATUS_OFFSET);
			if (oce_fm_check_acc_handle(dev, dev->db_handle) !=
			    DDI_FM_OK) {
				ddi_fm_service_impact(dev->dip,
				    DDI_SERVICE_DEGRADED);
				return (EIO);
			}
			sliport_status &= (SLIPORT_STATUS_ERR_MASK |
			    SLIPORT_STATUS_RN_MASK);
			if (status || sliport_status)
				status = -1;
		} else if (err || reset_needed) {
			status = DDI_FAILURE;
		}
	}
	return (status);
}

/*
 * function to trigger a POST on the Lancer device
 *
 * dev - software handle to the device
 *
 */
int
oce_lancer_POST(struct oce_dev *dev)
{
	int status = 0;
	int sem = 0;
	int stage = 0;
	int timeout = 0;

	status = lancer_test_and_set_rdy_state(dev);
	if (status != 0)
		return (DDI_FAILURE);

	do {
		sem = OCE_DB_READ32(dev, MPU_EP_SEMAPHORE_IF_TYPE2_OFFSET);
		if (oce_fm_check_acc_handle(dev, dev->db_handle) != DDI_FM_OK) {
			ddi_fm_service_impact(dev->dip, DDI_SERVICE_DEGRADED);
			return (EIO);
		}
		stage = sem & EP_SEMAPHORE_POST_STAGE_MASK;

		if ((sem >> EP_SEMAPHORE_POST_ERR_SHIFT) &
		    EP_SEMAPHORE_POST_ERR_MASK) {
			oce_log(dev, CE_WARN, MOD_CONFIG,
			    "POST error; stage=0x%x\n", stage);
			return (DDI_FAILURE);
		} else if (stage != POST_STAGE_ARMFW_READY) {
			drv_usecwait(1000);
		} else {
			return (0);
		}
	} while (timeout++ < 1000);
	oce_log(dev, CE_WARN, MOD_CONFIG,
	    "POST timeout; stage=0x%x\n", stage);
	return (DDI_FAILURE);

} /* oce_lancer_POST */

/*
 * function to trigger a POST on the BE device
 *
 * dev - software handle to the device
 *
 */
int
oce_be_POST(struct oce_dev *dev)
{
	mpu_ep_semaphore_t post_status;
	clock_t tmo;
	clock_t earlier = ddi_get_lbolt();

	/* read semaphore CSR */
	post_status.dw0 = OCE_CSR_READ32(dev, MPU_EP_SEMAPHORE);
	if (oce_fm_check_acc_handle(dev, dev->csr_handle) != DDI_FM_OK) {
		ddi_fm_service_impact(dev->dip, DDI_SERVICE_DEGRADED);
		return (DDI_FAILURE);
	}
	/* if host is ready then wait for fw ready else send POST */
	if (post_status.bits.stage <= POST_STAGE_AWAITING_HOST_RDY) {
		post_status.bits.stage = POST_STAGE_CHIP_RESET;
		OCE_CSR_WRITE32(dev, MPU_EP_SEMAPHORE, post_status.dw0);
		if (oce_fm_check_acc_handle(dev, dev->csr_handle) !=
		    DDI_FM_OK) {
			ddi_fm_service_impact(dev->dip, DDI_SERVICE_DEGRADED);
			return (DDI_FAILURE);
		}
	}

	/* wait for FW ready */
	tmo = drv_usectohz(60000000); /* 1.0min */
	for (;;) {
		if ((ddi_get_lbolt() - earlier) > tmo) {
			tmo = 0;
			break;
		}

		post_status.dw0 = OCE_CSR_READ32(dev, MPU_EP_SEMAPHORE);
		if (oce_fm_check_acc_handle(dev, dev->csr_handle) !=
		    DDI_FM_OK) {
			ddi_fm_service_impact(dev->dip, DDI_SERVICE_DEGRADED);
			return (DDI_FAILURE);
		}
		if (post_status.bits.error) {
			oce_log(dev, CE_WARN, MOD_CONFIG,
			    "0x%x POST ERROR!!", post_status.dw0);
			return (DDI_FAILURE);
		}
		if (post_status.bits.stage == POST_STAGE_ARMFW_READY)
			return (DDI_SUCCESS);

		drv_usecwait(100);
	}
	return (DDI_FAILURE);
} /* oce_be_POST */

/*
 * function to trigger a POST on the device
 *
 * dev - software handle to the device
 *
 */
int
oce_POST(struct oce_dev *dev)
{
	int ret = 0;

	if (LANCER_CHIP(dev)) {
		ret = oce_lancer_POST(dev);
	} else {
		ret = oce_be_POST(dev);
	}

	return (ret);
}

/*
 * function to modify register access attributes corresponding to the
 * FM capabilities configured by the user
 *
 * fm_caps - fm capability configured by the user and accepted by the driver
 */
void
oce_set_reg_fma_flags(int fm_caps)
{
	if (fm_caps == DDI_FM_NOT_CAPABLE) {
		return;
	}
	if (DDI_FM_ACC_ERR_CAP(fm_caps)) {
		reg_accattr.devacc_attr_access = DDI_FLAGERR_ACC;
	} else {
		reg_accattr.devacc_attr_access = DDI_DEFAULT_ACC;
	}
} /* oce_set_fma_flags */


int
oce_create_nw_interface(struct oce_dev *dev, oce_group_t *grp, uint32_t mode)
{
	int ret;
	uint32_t cap_flags, en_flags;

	cap_flags = MBX_RX_IFACE_FLAGS_UNTAGGED;
	en_flags = MBX_RX_IFACE_FLAGS_UNTAGGED;

	/* first/default group receives broadcast and mcast pkts */
	if (grp->grp_num == 0) {
		cap_flags |= MBX_RX_IFACE_FLAGS_BROADCAST |
		    MBX_RX_IFACE_FLAGS_MCAST_PROMISCUOUS |
		    MBX_RX_IFACE_FLAGS_PROMISCUOUS |
		    MBX_RX_IFACE_FLAGS_VLAN_PROMISCUOUS |
		    MBX_RX_IFACE_FLAGS_MCAST;

		en_flags |= MBX_RX_IFACE_FLAGS_BROADCAST |
		    MBX_RX_IFACE_FLAGS_MCAST;


		cap_flags |= MBX_RX_IFACE_FLAGS_PASS_L3L4;
		en_flags  |= MBX_RX_IFACE_FLAGS_PASS_L3L4;
		if (grp->rss_enable) {
			cap_flags |= MBX_RX_IFACE_FLAGS_RSS;
			en_flags |= MBX_RX_IFACE_FLAGS_RSS;
		}
	}

	if (grp->grp_num == 0) {
		ret = oce_if_create(dev, cap_flags, en_flags,
		    0, NULL,
		    (uint32_t *)&grp->if_id, mode);
		/* copy default if_id into dev */
		dev->if_id = grp->if_id;

	} else {
		ret = oce_if_create(dev, cap_flags, en_flags,
		    0, NULL, (uint32_t *)&grp->if_id, mode);
	}
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Interface creation failed for group "
		    "instance %d: 0x%x", grp->grp_num, ret);
		return (ret);
	}

	/* Enable VLAN Promisc on HW */
	ret = oce_config_vlan(dev, (uint8_t)grp->if_id,
	    NULL, 0, B_TRUE, B_TRUE, mode);
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Config vlan failed: 0x%x", ret);
		oce_delete_nw_interface(dev, grp, mode);
		return (ret);
	}
	return (0);
}

void
oce_delete_nw_interface(struct oce_dev *dev, oce_group_t *grp, uint32_t mode)
{
	char itbl[OCE_ITBL_SIZE] = {0};
	char hkey[OCE_HKEY_SIZE] = {0};
	int ret = 0;

	if (grp->rss_enable) {
		ret = oce_config_rss(dev, grp->if_id, hkey,
		    itbl, OCE_ITBL_SIZE, RSS_ENABLE_NONE, B_FALSE, mode);

		if (ret != DDI_SUCCESS) {
			oce_log(dev, CE_NOTE, MOD_CONFIG,
			    "Failed to Disable RSS if_id=%d, ret=0x%x",
			    grp->if_id, ret);
		}
	}
	ret = oce_if_del(dev, (uint8_t)grp->if_id, mode);
	if (ret != DDI_SUCCESS)
		oce_log(dev, CE_NOTE, MOD_CONFIG,
		    "Failed to delete nw i/f gidx =%d if_id = 0x%x ret=0x%x",
		    grp->grp_num, grp->if_id, ret);
}

void
oce_group_create_itbl(oce_group_t *grp, char *itbl)
{
	int i;
	oce_ring_t *rss_queuep = &grp->ring[1];
	/* fill the indirection table rq 0 is default queue */
	for (i = 0; i < OCE_ITBL_SIZE; i++) {
		itbl[i] = rss_queuep[i % (grp->num_rings - 1)].rx->rss_cpuid;
	}
}


int
oce_hw_init(struct oce_dev *dev)
{
	int  ret;
	struct mac_address_format mac_addr;

	ret = oce_POST(dev);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "!!!HW POST1 FAILED");
		/* ADD FM FAULT */
		return (DDI_FAILURE);
	}
	/* create bootstrap mailbox */
	ret = oce_alloc_dma_buffer(dev, &dev->bmbx,
	    sizeof (struct oce_bmbx), NULL, DDI_DMA_CONSISTENT|DDI_DMA_RDWR);
	if (ret != DDI_SUCCESS) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Failed to allocate bmbx: 0x%x", ret);
		return (DDI_FAILURE);
	}

	ret = oce_reset_fun(dev);
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG, "%s",
		    "!!!FUNCTION RESET FAILED");
		goto init_fail;
	}

	/* reset the Endianess of BMBX */
	ret = oce_mbox_init(dev);
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Mailbox initialization failed with 0x%x", ret);
		goto init_fail;
	}

	/* read the firmware version */
	ret = oce_get_fw_version(dev, MBX_BOOTSTRAP);
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Firmaware version read failed with 0x%x", ret);
		goto init_fail;
	}

	/* read the fw config */
	ret = oce_get_fw_config(dev, MBX_BOOTSTRAP);
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Firmware configuration read failed with %d", ret);
		goto init_fail;
	}

	/* read the Factory MAC address */
	ret = oce_read_mac_addr(dev, 0, 1,
	    MAC_ADDRESS_TYPE_NETWORK, &mac_addr, MBX_BOOTSTRAP);
	if (ret != 0) {
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "MAC address read failed with 0x%x", ret);
		goto init_fail;
	}
	bcopy(&mac_addr.mac_addr[0], &dev->mac_addr[0], ETHERADDRL);

	if (!LANCER_CHIP(dev)) {
		/* cache the ue mask registers for ue detection */
		dev->ue_mask_lo = OCE_CFG_READ32(dev, PCICFG_UE_STATUS_LO_MASK);
		dev->ue_mask_hi = OCE_CFG_READ32(dev, PCICFG_UE_STATUS_HI_MASK);
	}

	return (DDI_SUCCESS);
init_fail:
	oce_hw_fini(dev);
	return (DDI_FAILURE);
}
void
oce_hw_fini(struct oce_dev *dev)
{
	(void) oce_mbox_fini(dev);
	oce_free_dma_buffer(dev, &dev->bmbx);
}

boolean_t
oce_check_ue(struct oce_dev *dev)
{
	uint32_t ue_lo;
	uint32_t ue_hi;

	/* check for  the Hardware unexpected error */
	ue_lo = OCE_CFG_READ32(dev, PCICFG_UE_STATUS_LO);
	ue_hi = OCE_CFG_READ32(dev, PCICFG_UE_STATUS_HI);

	if ((~dev->ue_mask_lo & ue_lo) ||
	    (~dev->ue_mask_hi & ue_hi)) {
		/* Unrecoverable error detected */
		oce_log(dev, CE_WARN, MOD_CONFIG,
		    "Hardware UE Detected: "
		    "UE_LOW:%08x"
		    "UE_HI:%08x "
		    "UE_MASK_LO:%08x "
		    "UE_MASK_HI:%08x",
		    ue_lo, ue_hi,
		    dev->ue_mask_lo,
		    dev->ue_mask_hi);
		return (B_TRUE);
	}
	return (B_FALSE);
}

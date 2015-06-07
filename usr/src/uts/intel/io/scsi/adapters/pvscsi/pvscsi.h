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
 * Copyright 2012 Nexenta Systems, Inc. All rights reserved.
 */

#ifndef	_PVSCSI_H_
#define	_PVSCSI_H_

#include <sys/types.h>

#define	PVSCSI_IDENT	"VMware PVSCSI"
#define	PVSCSI_MODNAME	"pvscsi"

#define	PVSCSI_MAX_NUM_SG_ENTRIES_PER_SEGMENT 128

#define	MASK(n)	((1 << (n)) - 1)	/* make an n-bit mask */

#define	PCI_VENDOR_ID_VMWARE		0x15ad
#define	PCI_DEVICE_ID_VMWARE_PVSCSI	0x07c0

#define	BTSTAT_SUCCESS					0x00
#define	BTSTAT_LINKED_COMMAND_COMPLETED			0x0a
#define	BTSTAT_LINKED_COMMAND_COMPLETED_WITH_FLAG	0x0b
#define	BTSTAT_DATA_UNDERRUN				0x0c
#define	BTSTAT_SELTIMEO					0x11
#define	BTSTAT_DATARUN					0x12
#define	BTSTAT_BUSFREE					0x13
#define	BTSTAT_INVPHASE					0x14
#define	BTSTAT_LUNMISMATCH				0x17
#define	BTSTAT_SENSFAILED				0x1b
#define	BTSTAT_TAGREJECT				0x1c
#define	BTSTAT_BADMSG					0x1d
#define	BTSTAT_HAHARDWARE				0x20
#define	BTSTAT_NORESPONSE				0x21
#define	BTSTAT_SENTRST					0x22
#define	BTSTAT_RECVRST					0x23
#define	BTSTAT_DISCONNECT				0x24
#define	BTSTAT_BUSRESET					0x25
#define	BTSTAT_ABORTQUEUE				0x26
#define	BTSTAT_HASOFTWARE				0x27
#define	BTSTAT_HATIMEOUT				0x30
#define	BTSTAT_SCSIPARITY				0x34

/* HBA register offsets */
#define	PVSCSI_REG_OFFSET_COMMAND		0x0000
#define	PVSCSI_REG_OFFSET_COMMAND_DATA		0x0004
#define	PVSCSI_REG_OFFSET_COMMAND_STATUS	0x0008
#define	PVSCSI_REG_OFFSET_LAST_STS_0		0x0100
#define	PVSCSI_REG_OFFSET_LAST_STS_1		0x0104
#define	PVSCSI_REG_OFFSET_LAST_STS_2		0x0108
#define	PVSCSI_REG_OFFSET_LAST_STS_3		0x010c
#define	PVSCSI_REG_OFFSET_INTR_STATUS		0x100c
#define	PVSCSI_REG_OFFSET_INTR_MASK		0x2010
#define	PVSCSI_REG_OFFSET_KICK_NON_RW_IO	0x3014
#define	PVSCSI_REG_OFFSET_DEBUG			0x3018
#define	PVSCSI_REG_OFFSET_KICK_RW_IO		0x4018

/* HBA command codes */
#define	PVSCSI_CMD_FIRST		0x00
#define	PVSCSI_CMD_ADAPTER_RESET	0x01
#define	PVSCSI_CMD_ISSUE_SCSI		0x02
#define	PVSCSI_CMD_SETUP_RINGS		0x03
#define	PVSCSI_CMD_RESET_BUS		0x04
#define	PVSCSI_CMD_RESET_DEVICE		0x05
#define	PVSCSI_CMD_ABORT_CMD		0x06
#define	PVSCSI_CMD_CONFIG		0x07
#define	PVSCSI_CMD_SETUP_MSG_RING	0x08
#define	PVSCSI_CMD_DEVICE_UNPLUG	0x09
#define	PVSCSI_CMD_LAST			0x0a

/* Command descriptor for PVSCSI_CMD_RESET_DEVICE */
struct cmd_desc_reset_device {
	uint32_t	target;
	uint8_t		lun[8];
};

/*
 * Command descriptor for PVSCSI_CMD_ABORT_CMD.
 * - LUN selection is not currently supported
 * - _pad must be zeroed
 */
struct cmd_desc_abort_cmd {
	uint64_t	context;
	uint32_t	target;
	uint32_t	_pad;
};


/*
 * Command descriptor for PVSCSI_CMD_SETUP_RINGS.
 * req_ring_num_pages and cmp_ring_num_pages should:
 * - be power of two
 * - be different from zero
 * - be inferior to PVSCSI_SETUP_RINGS_MAX_NUM_PAGES
 */
#define	PVSCSI_SETUP_RINGS_MAX_NUM_PAGES	32
struct cmd_desc_setup_rings {
	uint32_t	req_ring_num_pages;
	uint32_t	cmp_ring_num_pages;
	uint64_t	rings_state_ppn;
	uint64_t	req_ring_ppns[PVSCSI_SETUP_RINGS_MAX_NUM_PAGES];
	uint64_t	cmp_ring_ppns[PVSCSI_SETUP_RINGS_MAX_NUM_PAGES];
};

/*
 * Command descriptor for PVSCSI_CMD_SETUP_MSG_RING.
 * - num_pages must be a power of two
 * - num_pages must be different from zero
 * - _pad must be zero
 */
#define	PVSCSI_SETUP_MSG_RING_MAX_NUM_PAGES  16
struct cmd_desc_setup_msg_ring {
	uint32_t	num_pages;
	uint32_t	_pad;
	uint64_t	ring_ppns[PVSCSI_SETUP_MSG_RING_MAX_NUM_PAGES];
};

#define	PVSCSI_MSG_DEV_ADDED	0x00
#define	PVSCSI_MSG_DEV_REMOVED	0x01
#define	PVSCSI_MSG_LAST		0x02

/*
 * HBA message descriptor
 * - sizeof(struct ring_msg_desc) == 128
 * - contents of args[] depend on type of the event
 */
struct ring_msg_desc {
	uint32_t	type;
	uint32_t	args[31];
};

/*
 *  - type: PVSCSI_MSG_DEV_ADDED or _REMOVED
 */
struct msg_desc_dev_status_changed {
	uint32_t	type;
	uint32_t	bus;
	uint32_t	target;
	uint8_t		lun[8];
	uint32_t	pad[27];
};

/* HBA rings state */
struct rings_state {
	uint32_t	req_prod_idx;
	uint32_t	req_cons_idx;
	uint32_t	req_num_entries_log2;
	uint32_t	cmp_prod_idx;
	uint32_t	cmp_cons_idx;
	uint32_t	cmp_num_entries_log2;
	uint8_t		_pad[104];
	uint32_t	msg_prod_idx;
	uint32_t	msg_cons_idx;
	uint32_t	msg_num_entries_log2;
};


/* HBA Request descriptor */
struct ring_req_desc {
	uint64_t	context;
	uint64_t	data_addr;
	uint64_t	data_len;
	uint64_t	sense_addr;
	uint32_t	sense_len;
	uint32_t	flags;
	uint8_t		cdb[16];
	uint8_t		cdb_len;
	uint8_t		lun[8];
	uint8_t		tag;
	uint8_t		bus;
	uint8_t		target;
	uint8_t		vcpu_hint;
	uint8_t		unused[59];
};

#define	PVSCSI_FLAG_CMD_WITH_SG_LIST	(1 << 0)
#define	PVSCSI_FLAG_CMD_OUT_OF_BAND_CDB (1 << 1)
#define	PVSCSI_FLAG_CMD_DIR_NONE	(1 << 2)
#define	PVSCSI_FLAG_CMD_DIR_TOHOST	(1 << 3)
#define	PVSCSI_FLAG_CMD_DIR_TODEVICE	(1 << 4)

/* HBA S/G list management */
struct sg_element {
	uint64_t	addr;
	uint32_t	length;
	uint32_t	flags;
};

/* HBA completion descriptor */
struct ring_cmp_desc {
	uint64_t	context;
	uint64_t	data_len;
	uint32_t	sense_len;
	uint16_t	host_status;
	uint16_t	scsi_status;
	uint32_t	_pad[2];
};


/* Interrupt status / IRQ bits */
#define	PVSCSI_INTR_CMPL_0	(1 << 0)
#define	PVSCSI_INTR_CMPL_1	(1 << 1)
#define	PVSCSI_INTR_CMPL_MASK	MASK(2)

#define	PVSCSI_INTR_MSG_0	(1 << 2)
#define	PVSCSI_INTR_MSG_1	(1 << 3)
#define	PVSCSI_INTR_MSG_MASK	(MASK(2) << 2)

#define	PVSCSI_INTR_ALL_SUPPORTED	MASK(4)

/* Number of MSI-X vectors supported */
#define	PVSCSI_MAX_INTRS	24

/* Enumeration of supported MSI-X vectors */
#define	PVSCSI_VECTOR_COMPLETION	0

/* Misc constants for the rings */
#define	PVSCSI_MAX_NUM_PAGES_REQ_RING	PVSCSI_SETUP_RINGS_MAX_NUM_PAGES
#define	PVSCSI_MAX_NUM_PAGES_CMP_RING	PVSCSI_SETUP_RINGS_MAX_NUM_PAGES
#define	PVSCSI_MAX_NUM_PAGES_MSG_RING	PVSCSI_SETUP_MSG_RING_MAX_NUM_PAGES

#define	PVSCSI_MAX_NUM_REQ_ENTRIES_PER_PAGE \
	(PAGE_SIZE / sizeof (struct ring_req_desc))

#define	PVSCSI_MAX_REQ_QUEUE_DEPTH		\
		PVSCSI_MAX_NUM_PAGES_REQ_RING	*\
		PVSCSI_MAX_NUM_REQ_ENTRIES_PER_PAGE

#define	PVSCSI_MEM_SPACE_COMMAND_NUM_PAGES	1
#define	PVSCSI_MEM_SPACE_INTR_STATUS_NUM_PAGES	1
#define	PVSCSI_MEM_SPACE_MISC_NUM_PAGES		2
#define	PVSCSI_MEM_SPACE_KICK_IO_NUM_PAGES	2
#define	PVSCSI_MEM_SPACE_MSIX_NUM_PAGES		2

#define	PVSCSI_MEM_SPACE_COMMAND_PAGE		0x00
#define	PVSCSI_MEM_SPACE_INTR_STATUS_PAGE	0x01
#define	PVSCSI_MEM_SPACE_MISC_PAGE		0x02
#define	PVSCSI_MEM_SPACE_KICK_IO_PAGE		0x04
#define	PVSCSI_MEM_SPACE_MSIX_TABLE_PAGE	0x06
#define	PVSCSI_MEM_SPACE_MSIX_PBA_PAGE		0x07

#define	PVSCSI_MEM_SPACE_NUM_PAGES			\
		(PVSCSI_MEM_SPACE_COMMAND_NUM_PAGES	+\
		PVSCSI_MEM_SPACE_INTR_STATUS_NUM_PAGES	+\
		PVSCSI_MEM_SPACE_MISC_NUM_PAGES		+\
		PVSCSI_MEM_SPACE_KICK_IO_NUM_PAGES	+\
		PVSCSI_MEM_SPACE_MSIX_NUM_PAGES)

#define	PVSCSI_MEM_SPACE_SIZE	(PVSCSI_MEM_SPACE_NUM_PAGES * PAGE_SIZE)

#define	PVSCSI_MAX_IO_PAGES	256
#define	PVSCSI_MAX_IO_SIZE	(PVSCSI_MAX_IO_PAGES * PAGE_SIZE)
#define	PVSCSI_MAX_SG_SIZE	(PVSCSI_MAX_IO_PAGES + 1)

#define	PVSCSI_MAXDEVS	127
#define	PVSCSI_MAXLUNS	8

#endif	/* _PVSCSI_H_ */

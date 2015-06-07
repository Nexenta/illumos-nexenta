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
 * Driver specific data structures and function prototypes
 */

#ifndef	_OCE_IMPL_H_
#define	_OCE_IMPL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/types.h>
#include <sys/dditypes.h>
#include <sys/sysmacros.h>
#include <sys/kstat.h>
#include <sys/ddi_intr.h>
#include <sys/cmn_err.h>
#include <sys/byteorder.h>
#include <netinet/ip6.h>
#include <sys/mac_provider.h>
#include <sys/mac_ether.h>
#include <sys/gld.h>
#include <sys/bitmap.h>
#include <sys/ddidmareq.h>
#include <sys/kmem.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/modctl.h>
#include <sys/devops.h>
#include <sys/systm.h>
#include <sys/conf.h>
#include <sys/dlpi.h>
#include <sys/ethernet.h>
#include <sys/strsun.h>
#include <sys/pattr.h>
#include <sys/strsubr.h>
#include <sys/ddifm.h>
#include <sys/fm/protocol.h>
#include <sys/fm/util.h>
#include <sys/fm/io/ddi.h>
#include <sys/note.h>
#include <sys/pci.h>
#include <sys/random.h>
#include <oce_hw.h>
#include <oce_hw_eth.h>
#include <oce_io.h>
#include <oce_buf.h>
#include <oce_utils.h>
#include <oce_ring.h>
#include <oce_version.h>

#define	SIZE_128	128
#define	SIZE_256	256
#define	SIZE_512	512
#define	SIZE_1K		1024
#define	SIZE_2K		(2 * 1024)
#define	SIZE_4K		(4 * 1024)
#define	SIZE_8K		(8 * 1024)

#define	END		0xdeadface

#define	OCE_MAX_JUMBO_FRAME_SIZE 9018

#define	OCE_MIN_MTU	1500
#define	OCE_MAX_MTU	9000
#define	OCE_MAX_MCA	32

#define	OCE_MAX_EQ	16
#define	OCE_MAX_CQ	1024

#define	OCE_WQ_NUM_BUFFERS	2048
#define	OCE_WQ_BUF_SIZE	2048
#define	OCE_LSO_MAX_SIZE (64 * 1024)
#define	OCE_DEFAULT_TX_BCOPY_LIMIT	512
#define	OCE_DEFAULT_RX_BCOPY_LIMIT	128
#define	OCE_DEFAULT_WQ_EQD	16

#define	OCE_DEFAULT_RX_PKTS_PER_INTR 64
#define	OCE_DEFAULT_TX_RECLAIM_THRESHOLD 1024

#define	OCE_MAX_RSS_RINGS		16
#define	OCE_MAX_RING_GROUPS		4
#define	OCE_MAX_RING_PER_GROUP	(OCE_MAX_RSS_RINGS+1)
#define	OCE_MIN_RING_PER_GROUP	1
#define	OCE_MAX_RQ				(OCE_MAX_EQ+1)
#define	OCE_MAX_WQ				OCE_MAX_EQ
#define	OCE_MIN_RQ				1
#define	OCE_MIN_WQ				1
#define	OCE_DEF_RING_PER_GROUP	OCE_MAX_RING_PER_GROUP
#define	OCE_DEFAULT_RQS			5
#define	OCE_DEFAULT_WQS			1

#define	OCE_MAX_SMAC_PER_DEV	128
#define	OCE_MAX_PMAC_PER_GRP	OCE_MAX_SMAC_PER_DEV

#define	OCE_MAX_RQ_POSTS	255
#define	OCE_RQ_NUM_BUFFERS	2048
#define	OCE_RQ_BUF_SIZE		2048
#define	OCE_DEFAULT_RECHARGE_THRESHOLD	32
#define	OCE_ITBL_SIZE		64
#define	OCE_HKEY_SIZE		40
#define	OCE_DMA_ALIGNMENT	0x0000000000001000ull
#define	OCE_MIN_VECTORS		1

#define	OCE_DEFAULT_TX_RING_SIZE    2048
#define	OCE_DEFAULT_RX_RING_SIZE    1024

#define	OCE_FM_CAPABILITY		(DDI_FM_EREPORT_CAPABLE	|	\
					DDI_FM_ACCCHK_CAPABLE	|	\
					DDI_FM_DMACHK_CAPABLE)
#define	OCE_DEFAULT_RSS_TYPE	(RSS_ENABLE_IPV4|RSS_ENABLE_TCP_IPV4)

/* flow control definitions */
#define	OCE_FC_NONE	0x00000000
#define	OCE_FC_TX	0x00000001
#define	OCE_FC_RX	0x00000002
#define	OCE_DEFAULT_FLOW_CONTROL	(OCE_FC_TX | OCE_FC_RX)

/* PCI Information */
#define	OCE_DEV_CFG_BAR	0x01
#define	OCE_PCI_CSR_BAR	0x02
#define	OCE_PCI_DB_BAR	0x03
/* Lancer DB Bar */
#define	OCE_PCI_LANCER_DB_BAR	0x01

/* macros for device IO */
#define	OCE_READ_REG32(handle, addr) ddi_get32(handle, addr)
#define	OCE_WRITE_REG32(handle, addr, value) ddi_put32(handle, addr, value)

#define	OCE_CSR_READ32(dev, offset) \
	OCE_READ_REG32((dev)->csr_handle, \
	    (uint32_t *)(void *)((dev)->csr_addr + offset))

#define	OCE_CSR_WRITE32(dev, offset, value) \
	OCE_WRITE_REG32((dev)->csr_handle, \
	    (uint32_t *)(void *)((dev)->csr_addr + offset), value)

#define	OCE_DB_READ32(dev, offset) \
	OCE_READ_REG32((dev)->db_handle, \
	    (uint32_t *)(void *)((dev)->db_addr + offset))

#define	OCE_DB_WRITE32(dev, offset, value) \
	OCE_WRITE_REG32((dev)->db_handle, \
		(uint32_t *)(void *)((dev)->db_addr + offset), value)

#define	OCE_CFG_READ32(dev, offset) \
	OCE_READ_REG32((dev)->dev_cfg_handle, \
	    (uint32_t *)(void *)((dev)->dev_cfg_addr + offset))

#define	OCE_CFG_WRITE32(dev, offset, value) \
	OCE_WRITE_REG32((dev)->dev_cfg_handle, \
	    (uint32_t *)(void *)((dev)->dev_cfg_addr + offset), value)

#define	OCE_PCI_FUNC(dev) \
	((OCE_CFG_READ32(dev, PCICFG_INTR_CTRL) \
	    >> HOSTINTR_PFUNC_SHIFT) & HOSTINTR_PFUNC_MASK)

#define	DEV_LOCK(dev)	mutex_enter(&dev->dev_lock)
#define	DEV_UNLOCK(dev)	mutex_exit(&dev->dev_lock)

enum oce_ring_size {
	RING_SIZE_256  = 256,
	RING_SIZE_512  = 512,
	RING_SIZE_1024 = 1024,
	RING_SIZE_2048 = 2048
};

enum oce_device_state {
	STATE_MAC_STARTED	= 0x4,
	STATE_INTR_ENABLED	= 0x8,
	STATE_MAC_STOPPING	= 0x10,
	STATE_INTR_ADJUST	= 0x20
};

enum oce_group_state {
	GROUP_INIT		= 0x01,
	GROUP_MAC_STARTED	= 0x02,
	GROUP_SUSPEND		= 0x04
};

#define	ATTACH_DEV_INIT 	0x1
#define	ATTACH_FM_INIT		0x2
#define	ATTACH_PCI_CFG		0x4
#define	ATTACH_LOCK_INIT	0x8
#define	ATTACH_PCI_INIT 	0x10
#define	ATTACH_HW_INIT		0x20
#define	ATTACH_SETUP_INTR	0x100
#define	ATTACH_STAT_INIT	0x200
#define	ATTACH_MAC_REG		0x400
#define	ATTACH_CB_REG		0x1000
#define	ATTACH_ALLOC_QUEUES	0x2000
#define	ATTACH_REG_INTR_HANDLE	0x4000

typedef union oce_ring_s {
		struct oce_rq *rx;
		struct oce_wq *tx;
} oce_ring_t;


typedef struct oce_group_s
{
	kmutex_t grp_lock; /* lock for group data */
	mac_ring_type_t	grp_type; /* tx or rx ring group */
	uint32_t grp_num; /* index into the group array */
	mac_group_handle_t handle; /* ring handle used by framework */
	boolean_t rss_enable; /* if rx, whether rss or not */
	uint32_t if_id;	/* unique to a group */
	uint32_t num_pmac; /* number of pmacs in this group */
	uint32_t pmac_ids[OCE_MAX_PMAC_PER_GRP]; /* pmac ids of added pmacs */
	struct ether_addr mac_addr[OCE_MAX_PMAC_PER_GRP]; /* MAC Addresses */
	uint32_t num_rings;
	uint32_t eq_idx;
	oce_ring_t ring[OCE_MAX_RING_PER_GROUP];
	void *parent;
	enum oce_group_state state;

	uint16_t num_mca; /* MCA supported */
	struct ether_addr multi_cast[OCE_MAX_MCA]; /* MC TABLE */
}oce_group_t;

struct oce_dev {
	kmutex_t bmbx_lock; /* Bootstrap Lock */
	kmutex_t dev_lock; /* lock for device */

	uint16_t QnQ_tag;
	uint8_t QnQ_valid;
	uint8_t QnQ_queried;

	uint32_t rx_rings_per_group;
	uint32_t num_rx_groups;
	uint32_t num_tx_groups;
	oce_group_t rx_group[OCE_MAX_RING_GROUPS];
	/* ungrouped TX rings */
	oce_ring_t default_tx_rings[OCE_MAX_WQ];
	uint32_t rx_rings; /* total */
	uint32_t tx_rings; /* total */
	uint32_t rss_cnt;

	/* Queues relarted */
	struct oce_wq *wq;	/* TXQ Array */
	struct oce_rq *rq;	/* RXQ Array */
	struct oce_cq **cq;	/* Completion Queues */
	struct oce_eq *eq;	/* Event Queues	*/
	struct oce_mq *mq;	/* MQ ring */

	/* driver state  machine */
	enum oce_device_state state;	/* state */
	boolean_t suspended;		/* CPR */
	uint32_t attach_state;		/* attach progress */

	oce_dma_buf_t bmbx;		/* Bootstrap MailBox */

	uint32_t tx_bcopy_limit;	/* TX BCOPY Limit */
	uint32_t rx_bcopy_limit;	/* RX BCOPY Limit */
	uint32_t tx_reclaim_threshold;	/* Tx reclaim */
	uint32_t tx_reclaim;		/* Tx reclaim */
	uint32_t rx_pkt_per_intr;	/* Rx pkts processed per intr */

	/* BARS */
	int num_bars;
	ddi_acc_handle_t pci_cfg_handle; /* Config space handle */
	ddi_acc_handle_t cfg_handle;	/* MMIO PCI Config Space Regs */
	ddi_acc_handle_t csr_handle;	/* MMIO Control Status Regs */
	caddr_t csr_addr;
	caddr_t db_addr;
	caddr_t dev_cfg_addr;
	ddi_acc_handle_t db_handle;	/* MMIO DoorBell Area */
	ddi_acc_handle_t dev_cfg_handle; /* MMIO CONFIG SPACE */
	mac_handle_t mac_handle;	/* MAC HANDLE	*/

	/* device stats */
	kstat_t *oce_kstats;		/* NIC STATS */
	oce_dma_buf_t stats_dbuf;	/* STATS BUFFER */
	kmutex_t stat_lock;

	/* dev stats */
	uint32_t tx_errors;
	uint32_t tx_noxmtbuf;

	/* link status */
	link_state_t link_status;
	int32_t link_speed;		/* Link speed in Mbps */
	int32_t	link_duplex;
	uint16_t pvid;
	uint16_t reco_priority; /* Recommended priority */
	uint32_t vlan_prio_bmap; /* Available Vlan priorities bitmap */

	/* watch dog timer related */
	kmutex_t wd_lock;
	boolean_t wd_enable;
	timeout_id_t wd_id;

	/* OS */
	uint32_t dev_id;	/* device ID or instance number */
	dev_info_t *dip;	/* device info structure for device tree node */

	/* Interrupt related */
	int intr_type;		/* INTR TYPE USED */
	int num_vectors;	/* number of vectors used */
	uint_t intr_pri;	/* interrupt priority */
	int intr_cap;
	ddi_intr_handle_t *htable;	/* intr handler table */
	int32_t hsize;
	ddi_cb_handle_t	cb_handle;	/* IRM: callback handle */
	int max_vectors;			/* IRM: max number of vectors */

	/* device configuration */
	uint32_t rq_max_bufs;		/* maximum prealloced buffers */
	uint32_t rq_frag_size;		/* Rxq fragment size */
	enum oce_ring_size tx_ring_size;
	enum oce_ring_size rx_ring_size;
	uint32_t neqs;			/* No of event queues */
	uint32_t nwqs;			/* No of Work Queues */
	uint32_t nrqs;			/* No of Receive Queues */
	uint32_t num_pmac;		/* Total pmacs on this port */
	uint32_t pmac_id;		/* used to add or remove mac */
	uint8_t unicast_addr[ETHERADDRL];
	uint32_t num_smac;
	uint32_t mtu;
	int32_t fm_caps;
	boolean_t lso_capable;		/* LSO */
	boolean_t promisc;		/* PROMISC MODE */
	uint32_t flow_control;		/* flow control settings */
	uint8_t mac_addr[ETHERADDRL];	/* hardware mac address */
	uint16_t num_mca;		/* MCA supported */
	struct ether_addr multi_cast[OCE_MAX_MCA];	/* MC TABLE */
	uint32_t cookie;		/* used during fw download */

	/* fw config: only relevant fields */
	uint32_t config_number;
	uint32_t asic_revision;
	uint32_t port_id;
	uint32_t function_mode;
	uint32_t function_caps;
	uint32_t drvfn_caps;
	uint32_t chip_rev;		/* Chip revision */
	uint32_t max_tx_rings;		/* Max Rx rings available */
	uint32_t max_rx_rings;		/* Max rx rings available */
	int32_t if_id;			/* IF ID */
	uint8_t fn;			/* function number */
	uint8_t fw_version[32];		/* fw version string */

	/* PCI related */
	uint16_t    vendor_id;
	uint16_t    device_id;
	uint16_t    subsys_id;
	uint16_t    subvendor_id;

	/* Logging related */
	uint16_t mod_mask;		/* Log Mask */
	int16_t severity;		/* Log level */

	/* ue status */
	uint32_t ue_mask_lo;
	uint32_t ue_mask_hi;
	uint32_t sli_family;
};

/* GLD handler functions */
int oce_m_start(void *arg);
void oce_m_stop(void *arg);
mblk_t *oce_m_send(void *arg, mblk_t *pkt);
int oce_m_promiscuous(void *arg, boolean_t enable);
int oce_m_multicast(void *arg, boolean_t add, const uint8_t *mca);
int oce_m_unicast(void *arg, const uint8_t *uca);
boolean_t oce_m_getcap(void *arg, mac_capab_t cap, void *data);
void oce_m_ioctl(void *arg, queue_t *wq, mblk_t *mp);
int oce_m_setprop(void *arg, const char *name, mac_prop_id_t id,
    uint_t size, const void *val);
int oce_m_getprop(void *arg, const char *name, mac_prop_id_t id,
    uint_t size, void *val);
void oce_m_propinfo(void *arg, const char *pr_name, mac_prop_id_t pr_num,
    mac_prop_info_handle_t prh);

int oce_m_stat(void *arg, uint_t stat, uint64_t *val);

/* Hardware start/stop functions */
int oce_start(struct oce_dev *dev);
void oce_stop(struct oce_dev *dev);
int oce_identify_hw(struct oce_dev *dev);

/* FMA support Functions */
void oce_fm_init(struct oce_dev *dev);
void oce_fm_fini(struct oce_dev *dev);
void oce_set_dma_fma_flags(int fm_caps);
void oce_set_reg_fma_flags(int fm_caps);
void oce_set_tx_map_dma_fma_flags(int fm_caps);
void oce_fm_ereport(struct oce_dev *dev, char *detail);
int  oce_fm_check_acc_handle(struct oce_dev *dev,
    ddi_acc_handle_t acc_handle);
int  oce_fm_check_dma_handle(struct oce_dev *dev,
    ddi_dma_handle_t dma_handle);

/* Interrupt handling */
int oce_setup_intr(struct oce_dev *dev);
int oce_teardown_intr(struct oce_dev *dev);
int oce_setup_handlers(struct oce_dev *dev);
void oce_remove_handler(struct oce_dev *dev);
int oce_ei(struct oce_dev *dev);
int oce_di(struct oce_dev *dev);
void oce_chip_ei(struct oce_dev *dev);
void oce_chip_di(struct oce_dev *dev);

/* HW initialisation */
int oce_hw_init(struct oce_dev *dev);
void oce_hw_fini(struct oce_dev *dev);
int oce_create_group(struct oce_dev *dev, oce_group_t *grp, uint32_t mode);
void oce_delete_group(struct oce_dev *dev, oce_group_t *grp);
void oce_delete_nw_interface(struct oce_dev *dev, oce_group_t *grp,
    uint32_t mode);
int oce_create_nw_interface(struct oce_dev *dev, oce_group_t *grp,
    uint32_t mode);
int oce_rq_init(struct oce_dev *dev, struct oce_rq *, uint32_t q_len,
    uint32_t frag_size, uint32_t mtu);
void oce_rq_fini(struct oce_dev *dev, struct oce_rq *rq);

/* Timer related */
void oce_enable_wd_timer(struct oce_dev  *dev);
void oce_disable_wd_timer(struct oce_dev *dev);
boolean_t oce_check_ue(struct oce_dev *dev);
boolean_t oce_tx_stall_check(struct oce_dev *dev);

/* Helper functions for crossbow ring groups */
int oce_start_group(oce_group_t *, boolean_t);
void oce_stop_group(oce_group_t *, boolean_t);
int oce_resume_group_rings(oce_group_t *);
void oce_suspend_group_rings(oce_group_t *);
void oce_group_create_itbl(oce_group_t *, char *);

#ifdef __cplusplus
}
#endif

#endif /* _OCE_IMPL_H_ */

/*
 * Copyright (C) 2007, 2011 VMware, Inc. All rights reserved.
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

#ifndef	_VMXNET3S_H_
#define	_VMXNET3S_H_

#include <sys/conf.h>
#include <sys/ddi.h>
#include <sys/ddi_impldefs.h>
#include <sys/debug.h>
#include <sys/dlpi.h>
#include <sys/errno.h>
#include <sys/ethernet.h>
#include <sys/kmem.h>
#include <sys/kstat.h>
#include <sys/mac.h>
#include <sys/mac_ether.h>
#include <sys/mac_provider.h>
#include <sys/modctl.h>
#include <sys/pattr.h>
#include <sys/pci.h>
#include <sys/stream.h>
#include <sys/strsubr.h>
#include <sys/strsun.h>
#include <sys/sunddi.h>
#include <sys/types.h>

#include <inet/common.h>
#include <inet/ip.h>
#include <inet/tcp.h>

#define	PCI_VENDOR_ID_VMWARE 0x15AD
#define	PCI_DEVICE_ID_VMWARE_VMXNET3 0x07B0

#define	BUILD_NUMBER_NUMERIC	20120727
#define	BUILD_REVISION		"1"

#define	UPT1_MAX_TX_QUEUES  64
#define	UPT1_MAX_RX_QUEUES  64

#define	UPT1_MAX_INTRS  (UPT1_MAX_TX_QUEUES + UPT1_MAX_RX_QUEUES)

typedef struct upt1_txstats {
	uint64_t	tsop;
	uint64_t	tsob;
	uint64_t	ucastp;
	uint64_t	ucastb;
	uint64_t	mcastp;
	uint64_t	mcastb;
	uint64_t	bcastp;
	uint64_t	bcastb;
	uint64_t	errp;
	uint64_t	discardp;
} upt1_txstats_t;

typedef struct upt1_rxstats {
	uint64_t	lropkts;
	uint64_t	lrobytes;
	uint64_t	ucastp;
	uint64_t	ucastb;
	uint64_t	mcastp;
	uint64_t	mcastb;
	uint64_t	bcastp;
	uint64_t	bcastb;
	uint64_t	oobp;
	uint64_t	errp;
} upt1_rxstats_t;

/* features */
#define	UPT1_F_RXCSUM	0x0001	/* rx csum verification */
#define	UPT1_F_RSS	0x0002
#define	UPT1_F_RXVLAN	0x0004	/* VLAN tag stripping */
#define	UPT1_F_LRO	0x0008

/* all registers are 32 bit wide */
/* BAR 1 */
#define	VMXNET3_REG_VRRS	0x0	/* Vmxnet3 Revision Report Selection */
#define	VMXNET3_REG_UVRS	0x8	/* UPT Version Report Selection */
#define	VMXNET3_REG_DSAL	0x10	/* Driver Shared Address Low */
#define	VMXNET3_REG_DSAH	0x18	/* Driver Shared Address High */
#define	VMXNET3_REG_CMD		0x20	/* Command */
#define	VMXNET3_REG_MACL	0x28	/* MAC Address Low */
#define	VMXNET3_REG_MACH	0x30	/* MAC Address High */
#define	VMXNET3_REG_ICR		0x38	/* Interrupt Cause register */
#define	VMXNET3_REG_ECR		0x40	/* Event Cause register */

/* BAR 0 */
#define	VMXNET3_REG_IMR		0x0   /* Interrupt Mask register */
#define	VMXNET3_REG_TXPROD	0x600 /* Tx Producer Index */
#define	VMXNET3_REG_RXPROD	0x800 /* Rx Producer Index for ring 1 */
#define	VMXNET3_REG_RXPROD2	0xa00 /* Rx Producer Index for ring 2 */

#define	VMXNET3_PHYSMEM_PAGES	4

#define	VMXNET3_CMD_FIRST_SET		0xcafe0000u
#define	VMXNET3_CMD_ACTIVATE_DEV	VMXNET3_CMD_FIRST_SET
#define	VMXNET3_CMD_QUIESCE_DEV		(VMXNET3_CMD_FIRST_SET + 1)
#define	VMXNET3_CMD_RESET_DEV		(VMXNET3_CMD_FIRST_SET + 2)
#define	VMXNET3_CMD_UPDATE_RX_MODE	(VMXNET3_CMD_FIRST_SET + 3)
#define	VMXNET3_CMD_UPDATE_MAC_FILTERS	(VMXNET3_CMD_FIRST_SET + 4)
#define	VMXNET3_CMD_UPDATE_VLAN_FILTERS	(VMXNET3_CMD_FIRST_SET + 5)
#define	VMXNET3_CMD_UPDATE_RSSIDT	(VMXNET3_CMD_FIRST_SET + 6)
#define	VMXNET3_CMD_UPDATE_IML		(VMXNET3_CMD_FIRST_SET + 7)
#define	VMXNET3_CMD_UPDATE_PMCFG	(VMXNET3_CMD_FIRST_SET + 8)
#define	VMXNET3_CMD_UPDATE_FEATURE	(VMXNET3_CMD_FIRST_SET + 9)
#define	VMXNET3_CMD_STOP_EMULATION	(VMXNET3_CMD_FIRST_SET + 10)
#define	VMXNET3_CMD_LOAD_PLUGIN		(VMXNET3_CMD_FIRST_SET + 11)
#define	VMXNET3_CMD_ACTIVATE_VF		(VMXNET3_CMD_FIRST_SET + 12)

#define	VMXNET3_CMD_FIRST_GET		0xf00d0000u
#define	VMXNET3_CMD_GET_QUEUE_STATUS	VMXNET3_CMD_FIRST_GET
#define	VMXNET3_CMD_GET_STATS		(VMXNET3_CMD_FIRST_GET + 1)
#define	VMXNET3_CMD_GET_LINK		(VMXNET3_CMD_FIRST_GET + 2)
#define	VMXNET3_CMD_GET_PERM_MAC_LO	(VMXNET3_CMD_FIRST_GET + 3)
#define	VMXNET3_CMD_GET_PERM_MAC_HI	(VMXNET3_CMD_FIRST_GET + 4)
#define	VMXNET3_CMD_GET_DID_LO		(VMXNET3_CMD_FIRST_GET + 5)
#define	VMXNET3_CMD_GET_DID_HI		(VMXNET3_CMD_FIRST_GET + 6)
#define	VMXNET3_CMD_GET_DEV_EXTRA_INFO	(VMXNET3_CMD_FIRST_GET + 7)
#define	VMXNET3_CMD_GET_CONF_INTR	(VMXNET3_CMD_FIRST_GET + 8)
#define	VMXNET3_CMD_GET_ADAPTIVE_RING_INFO (VMXNET3_CMD_FIRST_GET + 9)

/* Adaptive ring Info Flags */
#define	VMXNET3_DISABLE_ADAPTIVE_RING 1

typedef struct vmxnet3s_txdesc {
	uint64_t	addr;
	uint32_t	len:14;
	uint32_t	gen:1;		/* generation bit */
	uint32_t	rsvd:1;
	uint32_t	dtype:1;	/* descriptor type */
	uint32_t	ext1:1;
	uint32_t	msscof:14;	/* MSS, checksum offset, flags */
	uint32_t	hlen:10;	/* header len */
	uint32_t	om:2;		/* offload mode */
	uint32_t	eop:1;		/* End Of Packet */
	uint32_t	cq:1;		/* completion request */
	uint32_t	ext2:1;
	uint32_t	ti:1;		/* VLAN Tag Insertion */
	uint32_t	tci:16;		/* Tag to Insert */
} vmxnet3s_txdesc_t;

/* txdesc.OM values */
#define	VMXNET3_OM_NONE		0
#define	VMXNET3_OM_CSUM		2
#define	VMXNET3_OM_TSO		3

/* fields in txdesc we access w/o using bit fields */
#define	VMXNET3_TXD_EOP_SHIFT		12
#define	VMXNET3_TXD_CQ_SHIFT		13
#define	VMXNET3_TXD_GEN_SHIFT		14
#define	VMXNET3_TXD_EOP_DWORD_SHIFT	3
#define	VMXNET3_TXD_GEN_DWORD_SHIFT	2

#define	VMXNET3_TXD_CQ		(1 << VMXNET3_TXD_CQ_SHIFT)
#define	VMXNET3_TXD_EOP		(1 << VMXNET3_TXD_EOP_SHIFT)
#define	VMXNET3_TXD_GEN		(1 << VMXNET3_TXD_GEN_SHIFT)

#define	VMXNET3_HDR_COPY_SIZE	128

typedef struct vmxnet3s_txdatadesc {
	uint8_t		data[VMXNET3_HDR_COPY_SIZE];
} vmxnet3s_txdatadesc_t;

#define	VMXNET3_TCD_GEN_SHIFT		31
#define	VMXNET3_TCD_GEN_SIZE		1
#define	VMXNET3_TCD_TXIDX_SHIFT		0
#define	VMXNET3_TCD_TXIDX_SIZE		12
#define	VMXNET3_TCD_GEN_DWORD_SHIFT	3

typedef struct vmxnet3s_txcompdesc {
	uint32_t	txdidx:12;	/* Index of the EOP txdesc */
	uint32_t	ext1:20;
	uint32_t	ext2;
	uint32_t	ext3;
	uint32_t	rsvd:24;
	uint32_t	type:7;		/* completion type */
	uint32_t	gen:1;		/* generation bit */
} vmxnet3s_txcompdesc_t;

typedef struct vmxnet3s_rxdesc {
	uint64_t	addr;
	uint32_t	len:14;
	uint32_t	btype:1;	/* Buffer Type */
	uint32_t	dtype:1;	/* Descriptor type */
	uint32_t	rsvd:15;
	uint32_t	gen:1;		/* Generation bit */
	uint32_t	ext1;
} vmxnet3s_rxdesc_t;

typedef struct vmxnet3s_rxcompdesc {
	uint32_t	rxdidx:12;	/* Index of the rxdesc */
	uint32_t	ext1:2;
	uint32_t	eop:1;		/* End of Packet */
	uint32_t	sop:1;		/* Start of Packet */
	uint32_t	rqid:10;	/* rx queue/ring ID */
	uint32_t	rsstype:4;	/* RSS hash type used */
	uint32_t	cnc:1;		/* Checksum Not Calculated */
	uint32_t	ext2:1;
	uint32_t	rsshash;	/* RSS hash value */
	uint32_t	len:14;		/* data length */
	uint32_t	err:1;		/* Error */
	uint32_t	ts:1;		/* Tag is stripped */
	uint32_t	tci:16;		/* Tag stripped */
	uint32_t	csum:16;
	uint32_t	tuc:1;		/* TCP/UDP Checksum Correct */
	uint32_t	udp:1;		/* UDP packet */
	uint32_t	tcp:1;		/* TCP packet */
	uint32_t	ipc:1;		/* IP Checksum Correct */
	uint32_t	v6:1;		/* IPv6 */
	uint32_t	v4:1;		/* IPv4 */
	uint32_t	frg:1;		/* IP Fragment */
	uint32_t	fcs:1;		/* Frame CRC correct */
	uint32_t	type:7;		/* completion type */
	uint32_t	gen:1;		/* generation bit */
} vmxnet3s_rxcompdesc_t;

/* a union for accessing all cmd/completion descriptors */
typedef union vmxnet3s_gendesc {
	uint64_t		qword[2];
	uint32_t		dword[4];
	uint16_t		word[8];
	vmxnet3s_txdesc_t	txd;
	vmxnet3s_rxdesc_t	rxd;
	vmxnet3s_txcompdesc_t	tcd;
	vmxnet3s_rxcompdesc_t	rcd;
} vmxnet3s_gendesc_t;

#define	VMXNET3_INIT_GEN 1

/* Max size of a single tx buffer */
#define	VMXNET3_MAX_TX_BUF_SIZE (1 << 14)

/* max # of tx descs for a non-tso pkt */
#define	VMXNET3_MAX_TXD_PER_PKT 16

/* Max size of a single rx buffer */
#define	VMXNET3_MAX_RX_BUF_SIZE ((1 << 14) - 1)

/* ring size must be a multiple of 32 */
#define	VMXNET3_RING_SIZE_ALIGN 32
#define	VMXNET3_RING_SIZE_MASK  (VMXNET3_RING_SIZE_ALIGN - 1)

/* completion descriptor types */
#define	VMXNET3_CDTYPE_TXCOMP	0    /* Tx Completion Descriptor */
#define	VMXNET3_CDTYPE_RXCOMP	3    /* Rx Completion Descriptor */

#define	VMXNET3_GOS_BITS_UNK	0   /* unknown */
#define	VMXNET3_GOS_BITS_32	1
#define	VMXNET3_GOS_BITS_64	2

#define	VMXNET3_GOS_TYPE_SOLARIS 3

/* All structures in drivershared are padded to multiples of 8 bytes */
typedef struct vmxnet3s_gosinfo {
	uint32_t	  gosbits: 2;	/* 32-bit or 64-bit? */
	uint32_t	  gostype: 4;	/* which guest */
	uint32_t	  gosver:  16;	/* gos version */
	uint32_t	  gosmisc: 10;	/* other info about gos */
} vmxnet3s_gosinfo_t;

typedef struct vmxnet3s_drvinfo {
	uint32_t	version;	/* driver version */
	vmxnet3s_gosinfo_t gos;
	uint32_t	vmxnet3srevspt;	/* vmxnet3s revision supported */
	uint32_t	uptverspt;	/* upt version supported */
} vmxnet3s_drvinfo_t;

#define	VMXNET3_REV1_MAGIC 0xbabefee1

/*
 * queuedescpa must be 128 bytes aligned. It points to an array of
 * vmxnet3s_txqdesc followed by an array of vmxnet3s_rxqdesc.
 * The number of vmxnet3s_txqdesc/vmxnet3s_rxqdesc are specified by
 * vmxnet3s_miscconf.numtxq/numrxq, respectively.
 */
#define	VMXNET3_QUEUE_DESC_ALIGN 128

typedef struct vmxnet3s_miscconf {
	vmxnet3s_drvinfo_t drvinfo;
	uint64_t	uptfeatures;
	uint64_t	ddpa;		/* driver data PA */
	uint64_t	queuedescpa;	/* queue descriptor table PA */
	uint32_t	ddlen;		/* driver data len */
	uint32_t	queuedesclen;	/* queue descriptor table len */
	uint32_t	mtu;
	uint16_t	maxnumrxsg;
	uint8_t		numtxq;
	uint8_t		numrxq;
	uint32_t	reserved[4];
} vmxnet3s_miscconf_t;

typedef struct vmxnet3s_txqconf {
	uint64_t	txringbasepa;
	uint64_t	dataringbasepa;
	uint64_t	compringbasepa;
	uint64_t	ddpa;		/* driver data */
	uint64_t	reserved;
	uint32_t	txringsize;	/* # of tx desc */
	uint32_t	dataringsize;	/* # of data desc */
	uint32_t	compringsize;	/* # of comp desc */
	uint32_t	ddlen;		/* size of driver data */
	uint8_t		intridx;
	uint8_t		_pad[7];
} vmxnet3s_txqconf_t;

typedef struct vmxnet3s_rxqconf {
	uint64_t	rxringbasepa[2];
	uint64_t	compringbasepa;
	uint64_t	ddpa;		/* driver data */
	uint64_t	reserved;
	uint32_t	rxringsize[2];	/* # of rx desc */
	uint32_t	compringsize;	/* # of rx comp desc */
	uint32_t	ddlen;		/* size of driver data */
	uint8_t		intridx;
	uint8_t		_pad[7];
} vmxnet3s_rxqconf_t;

enum vmxnet3s_intrmaskmode {
	VMXNET3_IMM_AUTO,
	VMXNET3_IMM_ACTIVE,
	VMXNET3_IMM_LAZY
};

enum vmxnet3s_intrtype {
	VMXNET3_IT_AUTO,
	VMXNET3_IT_INTX,
	VMXNET3_IT_MSI,
	VMXNET3_IT_MSIX
};

#define	VMXNET3_MAX_INTRS	25

typedef struct vmxnet3s_intrconf {
	char		automask;
	uint8_t		numintrs;
	uint8_t		eventintridx;
	uint8_t		modlevels[VMXNET3_MAX_INTRS];
	uint32_t	intrctrl;
	uint32_t	reserved[2];
} vmxnet3s_intrconf_t;

/* one bit per VLAN ID, the size is in the units of uint32_t */
#define	VMXNET3_VFT_SIZE  (4096 / (sizeof (uint32_t) * 8))

typedef struct vmxnet3s_qstatus {
	char		stopped;
	uint8_t		_pad[3];
	uint32_t	error;
} vmxnet3s_qstatus_t;

typedef struct vmxnet3s_txqctrl {
	uint32_t	txnumdeferred;
	uint32_t	txthreshold;
	uint64_t	reserved;
} vmxnet3s_txqctrl_t;

typedef struct vmxnet3s_rxqctrl {
	char		updaterxprod;
	uint8_t		_pad[7];
	uint64_t	reserved;
} vmxnet3s_rxqctrl_t;

#define	VMXNET3_RXM_UCAST	0x01
#define	VMXNET3_RXM_MCAST	0x02
#define	VMXNET3_RXM_BCAST	0x04
#define	VMXNET3_RXM_ALL_MULTI	0x08
#define	VMXNET3_RXM_PROMISC	0x10

typedef struct vmxnet3s_rxfilterconf {
	uint32_t	rxmode;
	uint16_t	mftbllen;
	uint16_t	_pad1;
	uint64_t	mftblpa;
	uint32_t	vftbl[VMXNET3_VFT_SIZE];
} vmxnet3s_rxfilterconf_t;

typedef struct vmxnet3s_varlenconfdesc {
	uint32_t	confver;
	uint32_t	conflen;
	uint64_t	confpa;
} vmxnet3s_varlenconfdesc_t;

typedef struct vmxnet3s_dsdevread {
	vmxnet3s_miscconf_t	misc;
	vmxnet3s_intrconf_t	intrconf;
	vmxnet3s_rxfilterconf_t	rxfilterconf;
	vmxnet3s_varlenconfdesc_t rssconfdesc;
	vmxnet3s_varlenconfdesc_t pmconfdesc;
	vmxnet3s_varlenconfdesc_t pluginconfdesc;
} vmxnet3s_dsdevread_t;

typedef struct vmxnet3s_txqdesc {
	vmxnet3s_txqctrl_t	ctrl;
	vmxnet3s_txqconf_t	conf;
	vmxnet3s_qstatus_t	status;
	upt1_txstats_t		stats;
	uint8_t			_pad[88]; /* 128 aligned */
} vmxnet3s_txqdesc_t;

typedef struct vmxnet3s_rxqdesc {
	vmxnet3s_rxqctrl_t	ctrl;
	vmxnet3s_rxqconf_t	conf;
	vmxnet3s_qstatus_t	status;
	upt1_rxstats_t		stats;
	uint8_t			_pad[88]; /* 128 aligned */
} vmxnet3s_rxqdesc_t;

typedef struct vmxnet3s_drvshared {
	uint32_t		magic;
	uint32_t		pad;
	vmxnet3s_dsdevread_t	devread;
	uint32_t		ecr;
	uint32_t		reserved[5];
} vmxnet3s_drvshared_t;

#define	VMXNET3_ECR_RQERR (1 << 0)
#define	VMXNET3_ECR_TQERR (1 << 1)
#define	VMXNET3_ECR_LINK (1 << 2)
#define	VMXNET3_ECR_DIC (1 << 3)
#define	VMXNET3_ECR_DEBUG (1 << 4)

#define	VMXNET3_MAX_MTU 9000

typedef struct vmxnet3s_dmabuf {
	caddr_t			buf;
	uint64_t		bufpa;
	size_t			buflen;
	ddi_dma_handle_t	dmahdl;
	ddi_acc_handle_t	datahdl;
} vmxnet3s_dmabuf_t;

typedef struct vmxnet3s_cmdring {
	vmxnet3s_dmabuf_t	dma;
	uint16_t		size;
	uint16_t		next2fill;
	uint16_t		avail;
	uint8_t			gen;
} vmxnet3s_cmdring_t;

typedef struct vmxnet3s_compring {
	vmxnet3s_dmabuf_t	dma;
	uint16_t		size;
	uint16_t		next2comp;
	uint8_t			gen;
} vmxnet3s_compring_t;

typedef struct vmxnet3s_metatx {
	mblk_t			*mp;
	uint16_t		sopidx;
	uint16_t		frags;
} vmxnet3s_metatx_t;

typedef struct vmxnet3s_txq {
	vmxnet3s_cmdring_t	cmdring;
	vmxnet3s_compring_t	compring;
	vmxnet3s_metatx_t	*metaring;
	vmxnet3s_txqctrl_t	*sharedctrl;
} vmxnet3s_txq_t;

typedef struct vmxnet3s_rxbuf {
	vmxnet3s_dmabuf_t	dma;
	mblk_t			*mblk;
	frtn_t			freecb;
	struct vmxnet3s_softc	*dp;
	struct vmxnet3s_rxbuf	*next;
} vmxnet3s_rxbuf_t;

typedef struct vmxnet3s_bufdesc {
	vmxnet3s_rxbuf_t	*rxbuf;
} vmxnet3s_bufdesc_t;

typedef struct vmxnet3s_rxpool {
	vmxnet3s_rxbuf_t	*listhead;
	uint_t			nbufs;
	uint_t			nbufslimit;
} vmxnet3s_rxpool_t;

typedef struct vmxnet3s_rxq {
	vmxnet3s_cmdring_t	cmdring;
	vmxnet3s_compring_t	compring;
	vmxnet3s_bufdesc_t	*bufring;
	vmxnet3s_rxqctrl_t	*sharedctrl;
} vmxnet3s_rxq_t;

typedef struct vmxnet3s_txcache_node {
	uint64_t		pa;
	caddr_t 		va;
} vmxnet3s_txcache_node_t;

#define	VMXNET3_TX_CACHE_ITEMS_PER_PAGE		\
	(PAGESIZE / VMXNET3_HDR_COPY_SIZE)
#define	VMXNET3_TX_CACHE_MAX_PAGES				\
	(VMXNET3_TX_RING_MAX_SIZE / VMXNET3_TX_CACHE_ITEMS_PER_PAGE)

typedef struct vmxnet3s_txcache {
	int			num_pages;
	page_t			**pages;
	caddr_t			*page_maps;
	vmxnet3s_txcache_node_t *nodes;
	int			num_nodes;
	caddr_t			window;
} vmxnet3s_txcache_t;

typedef struct vmxnet3s_softc {
	dev_info_t		*dip;
	int			instance;
	mac_handle_t		mac;
	ddi_acc_handle_t	pcihdl;
	ddi_acc_handle_t	bar0hdl;
	ddi_acc_handle_t	bar1hdl;
	caddr_t			bar0;
	caddr_t			bar1;
	boolean_t		enabled;
	uint8_t			macaddr[6];
	uint32_t		cur_mtu;
	link_state_t		linkstate;
	uint64_t		linkspeed;
	vmxnet3s_dmabuf_t	shareddata;
	vmxnet3s_dmabuf_t	qdescs;
	kmutex_t		intrlock;
	int			intrtype;
	int			intrmaskmode;
	int			intrcap;
	ddi_intr_handle_t	intrhdl;
	ddi_taskq_t		*resettaskq;
	kmutex_t		txlock;
	vmxnet3s_txq_t		txq;
	ddi_dma_handle_t	txdmahdl;
	boolean_t		txmustresched;
	vmxnet3s_rxq_t		rxq;
	kmutex_t		rxpoollock;
	vmxnet3s_rxpool_t	rxpool;
	volatile uint32_t	rxnumbufs;
	uint32_t		rxmode;
	vmxnet3s_txcache_t	txcache;
	vmxnet3s_dmabuf_t	mftbl;
} vmxnet3s_softc_t;

int	vmxnet3s_alloc1(vmxnet3s_softc_t *, vmxnet3s_dmabuf_t *,
	    size_t, boolean_t);
int	vmxnet3s_alloc128(vmxnet3s_softc_t *, vmxnet3s_dmabuf_t *,
	    size_t, boolean_t);
int	vmxnet3s_alloc512(vmxnet3s_softc_t *, vmxnet3s_dmabuf_t *,
	    size_t, boolean_t);
void	vmxnet3s_free(vmxnet3s_dmabuf_t *);
int	vmxnet3s_getprop(vmxnet3s_softc_t *, char *, int, int, int);

mblk_t	*vmxnet3s_m_tx(void *, mblk_t *);
boolean_t vmxnet3s_tx_complete(vmxnet3s_softc_t *, vmxnet3s_txq_t *);
void	vmxnet3s_txq_fini(vmxnet3s_softc_t *, vmxnet3s_txq_t *);
int	vmxnet3s_txq_init(vmxnet3s_softc_t *, vmxnet3s_txq_t *);

int	vmxnet3s_rxq_init(vmxnet3s_softc_t *, vmxnet3s_rxq_t *);
mblk_t	*vmxnet3s_rx_intr(vmxnet3s_softc_t *, vmxnet3s_rxq_t *);
void	vmxnet3s_rxq_fini(vmxnet3s_softc_t *, vmxnet3s_rxq_t *);

void	mac_lso_get(mblk_t *, uint32_t *, uint32_t *);

extern	ddi_device_acc_attr_t vmxnet3s_dev_attr;

#define	VMXNET3_MODNAME "vmxnet3s"

#define	MACADDR_FMT "%02x:%02x:%02x:%02x:%02x:%02x"
#define	MACADDR_FMT_ARGS(mac) \
	mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]

/* Default ring size */
#define	VMXNET3_DEF_TX_RING_SIZE 256
#define	VMXNET3_DEF_RX_RING_SIZE 256

/* register access helpers */
#define	VMXNET3_BAR0_PUT32(device, reg, value) \
	ddi_put32((device)->bar0hdl, (uint32_t *)((device)->bar0 + (reg)), \
		(value))
#define	VMXNET3_BAR1_GET32(device, reg) \
	ddi_get32((device)->bar1hdl, (uint32_t *)((device)->bar1 + (reg)))
#define	VMXNET3_BAR1_PUT32(device, reg, value) \
	ddi_put32((device)->bar1hdl, (uint32_t *)((device)->bar1 + (reg)), \
		(value))

/* Misc helpers */
#define	VMXNET3_DS(device) \
	((vmxnet3s_drvshared_t *)(device)->shareddata.buf)
#define	VMXNET3_TQDESC(device)				\
	((vmxnet3s_txqdesc_t *)(device)->qdescs.buf)
#define	VMXNET3_RQDESC(device)						\
	((vmxnet3s_rxqdesc_t *)((device)->qdescs.buf +		\
				sizeof (vmxnet3s_txqdesc_t)))

#define	VMXNET3_ADDR_LO(addr) ((uint32_t)(addr))
#define	VMXNET3_ADDR_HI(addr) ((uint32_t)(((uint64_t)(addr)) >> 32))

#define	VMXNET3_GET_DESC(ring, idx) \
	(((vmxnet3s_gendesc_t *)(ring)->dma.buf) + idx)

/* rings handling */
#define	VMXNET3_INC_RING_IDX(ring, idx) \
	do {				\
		(idx)++;		\
		if ((idx) == (ring)->size) {	\
			(idx) = 0;		\
			(ring)->gen ^= 1;	\
		}				\
	} while (0)

#define	VMXNET3_DEC_RING_IDX(ring, idx) \
	do {				\
		if ((idx) == 0) {	\
			(idx) = (ring)->size;	\
			(ring)->gen ^= 1;	\
		}				\
		(idx)--;			\
	} while (0)

#endif	/* _VMXNET3S_H_ */

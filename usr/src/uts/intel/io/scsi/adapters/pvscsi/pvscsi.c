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

#include <sys/atomic.h>
#include <sys/cmn_err.h>
#include <sys/conf.h>
#include <sys/cpuvar.h>
#include <sys/ddi.h>
#include <sys/errno.h>
#include <sys/fs/dv_node.h>
#include <sys/kmem.h>
#include <sys/kmem_impl.h>
#include <sys/list.h>
#include <sys/modctl.h>
#include <sys/pci.h>
#include <sys/scsi/scsi.h>
#include <sys/sunddi.h>
#include <sys/sysmacros.h>
#include <sys/time.h>
#include <sys/types.h>

#include "pvscsi.h"


typedef struct pv_dma_buf {
	ddi_dma_handle_t dma_handle;
	caddr_t		addr;
	uint64_t	pa;
	size_t		real_length;
	ddi_acc_handle_t acc_handle;
} pv_dma_buf_t;

#define	PVSCSI_TGT_PRIV_SIZE 2

#define	PVSCSI_FLAG_CDB_EXT	0x0001
#define	PVSCSI_FLAG_SCB_EXT	0x0002
#define	PVSCSI_FLAG_PRIV_EXT	0x0004
#define	PVSCSI_FLAG_TAG		0x0008
#define	PVSCSI_FLAG_IO_READ	0x0010
#define	PVSCSI_FLAG_IO_IOPB	0x0040
#define	PVSCSI_FLAG_DONE	0x0080
#define	PVSCSI_FLAG_DMA_VALID	0x0100
#define	PVSCSI_FLAG_XARQ	0x0200
#define	PVSCSI_FLAG_HW_STATUS	0x0400
#define	PVSCSI_FLAG_TIMED_OUT	0x0800
#define	PVSCSI_FLAG_ABORTED	0x1000
#define	PVSCSI_FLAG_RESET_BUS	0x2000
#define	PVSCSI_FLAG_RESET_DEV	0x4000
#define	PVSCSI_FLAG_STALLED	0x8000
#define	PVSCSI_FLAG_TRANSPORT	0x10000

/* Flags that must remain during SCSI packet retransmission */
#define	PVSCSI_FLAGS_PERSISTENT		\
		PVSCSI_FLAG_CDB_EXT	|\
		PVSCSI_FLAG_SCB_EXT	|\
		PVSCSI_FLAG_PRIV_EXT	|\
		PVSCSI_FLAG_TAG		|\
		PVSCSI_FLAG_IO_READ	|\
		PVSCSI_FLAG_IO_IOPB	|\
		PVSCSI_FLAG_DMA_VALID	|\
		PVSCSI_FLAG_XARQ

#define	PVSCSI_FLAGS_RESET		\
		PVSCSI_FLAG_RESET_BUS	|\
		PVSCSI_FLAG_RESET_DEV

#define	PVSCSI_FLAGS_NON_HW_COMPLETION	\
		PVSCSI_FLAG_TIMED_OUT	|\
		PVSCSI_FLAG_ABORTED	|\
		PVSCSI_FLAGS_RESET

#define	PVSCSI_FLAGS_COMPLETION		\
		PVSCSI_FLAG_HW_STATUS	|\
		PVSCSI_FLAGS_NON_HW_COMPLETION

#define	PVSCSI_FLAGS_EXT		\
		PVSCSI_FLAG_CDB_EXT	|\
		PVSCSI_FLAG_SCB_EXT	|\
		PVSCSI_FLAG_PRIV_EXT

typedef struct pvscsi_cmd_ctx {
	pv_dma_buf_t	dma_buf;
	struct pvscsi_cmd *cmd;
	list_node_t	list;
} pvscsi_cmd_ctx_t;

typedef struct pvscsi_cmp_desc_stat {
	uchar_t		scsi_status;
	uint32_t	host_status;
	uint64_t	data_len;
} pvscsi_cmp_desc_stat_t;

typedef struct pvscsi_cmd {
	struct scsi_pkt	*pkt;
	uint8_t		cmd_cdb[SCSI_CDB_SIZE];
	struct scsi_arq_status cmd_scb;
	uint64_t	tgt_priv[PVSCSI_TGT_PRIV_SIZE];
	size_t		tgtlen;
	size_t		cmdlen;
	size_t		statuslen;
	uint8_t		tag;
	int		flags;
	ulong_t		dma_count;
	pvscsi_cmp_desc_stat_t cmp_stat;
	pvscsi_cmd_ctx_t *ctx;
	ddi_dma_handle_t cmd_handle;
	ddi_dma_cookie_t cmd_cookie;
	uint_t		cmd_cookiec;
	uint_t		cmd_winindex;
	uint_t		cmd_nwin;
	off_t		cmd_dma_offset;
	size_t		cmd_dma_len;
	uint_t		cmd_dma_count;
	uint_t		cmd_total_dma_count;
	int		cmd_target;
	int		cmd_lun;
	list_node_t	active_list;
	clock_t		timeout_lbolt;
	struct pvscsi_softc *cmd_pvs;
	struct pvscsi_cmd *next_cmd;
	struct pvscsi_cmd *tail_cmd;
	struct buf	*arq_buf;
	ddi_dma_cookie_t arq_cookie;
	ddi_dma_handle_t arq_handle;
	int		cmd_rqslen;
	struct scsi_pkt cached_pkt;
	ddi_dma_cookie_t cached_cookies[PVSCSI_MAX_SG_SIZE];
} pvscsi_cmd_t;

#define	AP2PRIV(ap) ((ap)->a_hba_tran->tran_hba_private)
#define	CMD2PKT(cmd) ((struct scsi_pkt *)((cmd)->pkt))
#define	PKT2CMD(pkt) ((pvscsi_cmd_t *)((pkt)->pkt_ha_private))
#define	SDEV2PRIV(sd) ((sd)->sd_address.a_hba_tran->tran_hba_private)
#define	TRAN2PRIV(tran) ((pvscsi_softc_t *)(tran)->tran_hba_private)

#define	CMD_CTX_SGLIST_VA(cmd_ctx) ((struct sg_element *)	\
				    (((pvscsi_cmd_ctx_t *)	\
				    (cmd_ctx))->dma_buf.addr))

#define	CMD_CTX_SGLIST_PA(cmd_ctx) ((((pvscsi_cmd_ctx_t *)	\
				    (cmd_ctx))->dma_buf.pa))

#define	CMD_ON_STALLED_LIST(cmd) (((cmd)->flags & PVSCSI_FLAG_STALLED) != 0)

#define	MAX_WORKER_THREADS 8
#define	WORKER_THREAD_THRESHOLD 3

typedef struct pvscsi_worker_state {
	kmutex_t mtx;
	pvscsi_cmd_t *head_cmd;
	pvscsi_cmd_t *tail_cmd;
	kcondvar_t cv;
	kthread_t *thread;
	struct pvscsi_softc *pvs;
	int id;
	int flags;
} pvscsi_worker_state_t;

/* IRQ worker flags */
#define	PVSCSI_IRQ_WORKER_ACTIVE	0x01
#define	PVSCSI_IRQ_WORKER_SHUTDOWN	0x02

/* Driver-wide flags */
#define	PVSCSI_DRIVER_SHUTDOWN		0x01
#define	PVSCSI_STALLED_THREAD_RUNNING	0x02
#define	PVSCSI_HBA_QUIESCED		0x04
#define	PVSCSI_HBA_QUIESCE_PENDING	0x08
#define	PVSCSI_HBA_AUTO_REQUEST_SENSE	0x10

#define	HBA_IS_QUIESCED(pvs) (((pvs)->flags & PVSCSI_HBA_QUIESCED) != 0)
#define	SHOULD_WAKE_QUIESCERS(pvs)				\
	(((pvs)->flags & PVSCSI_HBA_QUIESCE_PENDING) != 0 &&	\
	((pvs)->num_active_commands == 0))

typedef struct pvscsi_softc {
	dev_info_t	*dip;
	int		instance;
	scsi_hba_tran_t	*tran;
	ddi_dma_attr_t	msg_dma_attr;
	ddi_dma_attr_t	ring_dma_attr;
	ddi_dma_attr_t	io_dma_attr;
	pv_dma_buf_t	rings_state_buf;
	pv_dma_buf_t	req_ring_buf;
	uint_t		req_pages, req_depth;
	pv_dma_buf_t	cmp_ring_buf;
	uint_t		cmp_pages;
	pv_dma_buf_t	msg_ring_buf;
	uint_t		msg_pages;
	ddi_acc_handle_t pci_config_handle;
	ddi_acc_handle_t mmio_handle;
	caddr_t		mmio_base;
	int		msi_enable;
	int		irq_type;
	int		intr_size;
	int		intr_cnt;
	int		intr_pri;
	int		flags;
	ddi_intr_handle_t *intr_htable;
	pvscsi_cmd_ctx_t *cmd_ctx;
	list_t		cmd_ctx_pool;
	list_t		active_commands;
	list_t		stalled_commands;
	int		worker_thread_priority;
	int		num_active_commands;
	int		num_stalled_commands;
	kcondvar_t	wd_condvar;
	kmutex_t	mutex;
	kmutex_t	rx_mutex;
	kmutex_t	tx_mutex;
	kmutex_t	intr_mutex;
	kmutex_t	stallq_mutex;
	struct kmem_cache *cmd_cache;
	int		num_luns;
	int		num_workers;
	int		worker_threshold;
	pvscsi_worker_state_t *workers_state;
	list_t		devnodes;
	kcondvar_t	syncvar;
	kcondvar_t	quiescevar;
	kthread_t	*wd_thread;
	int		intr_lock_counter;
	int		num_pollers;
} pvscsi_softc_t;

typedef struct pvscsi_device {
	list_node_t	list;
	int		target;
	int		lun;
	dev_info_t	*pdip;
	dev_info_t	*parent;
} pvscsi_device_t;

#define	REQ_RING(pvs)				\
		((struct ring_req_desc *)	\
		(((pvscsi_softc_t *)(pvs))->req_ring_buf.addr))

#define	CMP_RING(pvs)				\
		((struct ring_cmp_desc *)	\
		(((pvscsi_softc_t *)(pvs))->cmp_ring_buf.addr))

#define	MSG_RING(pvs)				\
		((struct ring_msg_desc *)	\
		(((pvscsi_softc_t *)(pvs))->msg_ring_buf.addr))

#define	RINGS_STATE(pvs)			\
		((struct rings_state *)		\
		(((pvscsi_softc_t *)		\
		(pvs))->rings_state_buf.addr))

#define	PVSCSI_DEFAULT_NUM_PAGES_PER_RING 8

#define	PVSCSI_INITIAL_SSTATE_ITEMS 16

#define	SENSE_BUFFER_SIZE SENSE_LENGTH
#define	USECS_TO_WAIT 1000

#define	STALLQ_IS_EMPTY(pvs) (list_is_empty(&(pvs)->stalled_commands))

#define	STALLQ_THREAD_IS_ACTIVE(pvs)	\
	(((pvs)->flags & _STALLED_THREAD_RUNNING) != 0)

#define	TARGET_PROP	"target"
#define	LUN_PROP	"lun"

#define	PAGE_SIZE 4096
#define	PAGE_SHIFT 12

#define	ARRAY_SIZE(x)  (sizeof (x) / sizeof (x[0]))

static int	pvscsi_attach(dev_info_t *, ddi_attach_cmd_t);
static int	pvscsi_detach(dev_info_t *, ddi_detach_cmd_t);
static int	pvscsi_ioctl(dev_t, int, intptr_t, int, cred_t *, int *);
static int	pvscsi_power(dev_info_t *, int, int);
static int	pvscsi_quiesce(dev_info_t *);
static void	pvscsi_complete_command(pvscsi_cmd_t *);

static pvscsi_cmd_ctx_t	*pvscsi_resolve_context(pvscsi_softc_t *, uint64_t);
static pvscsi_cmd_ctx_t	*pvscsi_lookup_context(pvscsi_softc_t *,
			    pvscsi_cmd_t *);
static uint64_t		pvscsi_map_context(pvscsi_softc_t *,
			    pvscsi_cmd_ctx_t *);

static struct cb_ops pvscsi_cb_ops = {
	scsi_hba_open,		/* open */
	scsi_hba_close,		/* close */
	nodev,			/* strategy */
	nodev,			/* print */
	nodev,			/* dump */
	nodev,			/* read */
	nodev,			/* write */
	pvscsi_ioctl,		/* ioctl */
	nodev,			/* devmap */
	nodev,			/* mmap */
	nodev,			/* segmap */
	nochpoll,		/* chpoll */
	ddi_prop_op,		/* cb_prop_op */
	NULL,			/* streamtab */
	D_MP,			/* cb_flag */
	CB_REV,			/* rev */
	nodev,			/* aread */
	nodev			/* awrite */
};

static struct dev_ops pvscsi_ops = {
	DEVO_REV,		/* devo_rev, */
	0,			/* refcnt  */
	ddi_no_info,		/* info */
	nulldev,		/* identify */
	nulldev,		/* probe */
	pvscsi_attach,		/* attach */
	pvscsi_detach,		/* detach */
	nodev,			/* reset */
	&pvscsi_cb_ops,		/* driver operations */
	NULL,			/* bus operations */
	pvscsi_power,		/* power management */
	pvscsi_quiesce		/* quiesce */
};

static struct modldrv modldrv = {
	&mod_driverops,
	PVSCSI_IDENT,
	&pvscsi_ops,
};

static struct modlinkage modlinkage = {
	MODREV_1,
	&modldrv,
	NULL
};

static int pvscsi_ring_pages = PVSCSI_DEFAULT_NUM_PAGES_PER_RING;

static void *pvscsi_sstate;

/* DMA attributes for preallocated Rx/Tx buffers */
static ddi_dma_attr_t pvscsi_msg_dma_attr = {
	DMA_ATTR_V0,		/* version of this structure */
	0,			/* lowest usable address */
	0xffffffffffffffffULL,	/* highest usable address */
	0x7fffffff,		/* maximum DMAable byte count */
	1,			/* alignment in bytes */
	0x7ff,			/* burst sizes (any?) */
	1,			/* minimum transfer */
	0xffffffffU,		/* maximum transfer */
	0xffffffffULL,		/* maximum segment length */
	1,			/* maximum number of segments */
	512,			/* granularity */
	0,			/* dma_attr_flags */
};

/* DMA attributes for rings */
static ddi_dma_attr_t pvscsi_ring_dma_attr = {
	DMA_ATTR_V0,		/* version of this structure */
	0,			/* lowest usable address */
	0xffffffffffffffffULL,	/* highest usable address */
	0x7fffffff,		/* maximum DMAable byte count */
	1,			/* alignment in bytes */
	0x7ff,			/* burst sizes (any?) */
	1,			/* minimum transfer */
	0xffffffffU,		/* maximum transfer */
	0xffffffffULL,		/* maximum segment length */
	1,			/* maximum number of segments */
	1,			/* granularity */
	0,			/* dma_attr_flags */
};

/* DMA attributes for buffer I/O */
static ddi_dma_attr_t pvscsi_io_dma_attr = {
	DMA_ATTR_V0,		/* version of this structure */
	0,			/* lowest usable address */
	0xffffffffffffffffULL,	/* highest usable address */
	0x7fffffff,		/* maximum DMAable byte count */
	1,			/* alignment in bytes */
	0x7ff,			/* burst sizes (any?) */
	1,			/* minimum transfer */
	0xffffffffU,		/* maximum transfer */
	0xffffffffULL,		/* maximum segment length */
	PVSCSI_MAX_SG_SIZE,	/* maximum number of segments */
	512,			/* granularity */
	0,			/* dma_attr_flags */
};

static ddi_device_acc_attr_t pvscsi_mmio_attr = {
	DDI_DEVICE_ATTR_V1,
	DDI_STRUCTURE_LE_ACC,
	DDI_STRICTORDER_ACC,
	DDI_DEFAULT_ACC
};

/* Completes all commands, linked together */
#define	COMPLETE_CHAINED_COMMANDS(cmds)				\
	do {							\
		pvscsi_cmd_t *_clist = (pvscsi_cmd_t *)(cmds);	\
								\
		while (_clist != NULL) {			\
			pvscsi_cmd_t *_cn = _clist->next_cmd;	\
			_clist->next_cmd = NULL;		\
			pvscsi_complete_command(_clist);	\
			_clist = _cn;				\
		}						\
	} while (0)

int
_init(void)
{
	int	status;

	if ((status = ddi_soft_state_init(&pvscsi_sstate,
	    sizeof (struct pvscsi_softc), PVSCSI_INITIAL_SSTATE_ITEMS)) != 0) {
		cmn_err(CE_WARN, "ddi_soft_state_init() failed");
		return (status);
	}

	if ((status = scsi_hba_init(&modlinkage)) != 0) {
		cmn_err(CE_WARN, "scsi_hba_init() failed");
		ddi_soft_state_fini(&pvscsi_sstate);
		return (status);
	}

	if ((status = mod_install(&modlinkage)) != 0) {
		cmn_err(CE_WARN, "mod_install() failed");
		ddi_soft_state_fini(&pvscsi_sstate);
		scsi_hba_fini(&modlinkage);
	}

	return (status);
}

int
_info(struct modinfo *modinfop)
{

	return (mod_info(&modlinkage, modinfop));
}

int
_fini(void)
{
	int	status;

	if ((status = mod_remove(&modlinkage)) == 0) {
		ddi_soft_state_fini(&pvscsi_sstate);
		scsi_hba_fini(&modlinkage);
	}

	return (status);
}

static uint32_t
pvscsi_reg_read(pvscsi_softc_t *pvs, uint32_t offset)
{
	uint32_t	r;

	ASSERT((offset & (sizeof (uint32_t)-1)) == 0);

	r = ddi_get32(pvs->mmio_handle, (uint32_t *)(pvs->mmio_base + offset));
	membar_consumer();
	return (r);
}

static void
pvscsi_reg_write(const pvscsi_softc_t *pvs, uint32_t offset,
    uint32_t value)
{

	ASSERT((offset & (sizeof (uint32_t)-1)) == 0);

	ddi_put32(pvs->mmio_handle, (uint32_t *)(pvs->mmio_base + offset),
	    value);
	membar_producer();
}

static void
pvscsi_write_cmd_desc(const pvscsi_softc_t *pvs, uint32_t cmd,
    const void *desc, size_t len)
{
	const uint32_t	*ptr = desc;
	size_t		i;

	len /= sizeof (*ptr);
	pvscsi_reg_write(pvs, PVSCSI_REG_OFFSET_COMMAND, cmd);
	for (i = 0; i < len; i++)
		pvscsi_reg_write(pvs, PVSCSI_REG_OFFSET_COMMAND_DATA, ptr[i]);
}

static uint32_t
pvscsi_read_intr_status(pvscsi_softc_t *pvs)
{

	return (pvscsi_reg_read(pvs, PVSCSI_REG_OFFSET_INTR_STATUS));
}

static void
pvscsi_write_intr_status(const pvscsi_softc_t *pvs, uint32_t val)
{

	pvscsi_reg_write(pvs, PVSCSI_REG_OFFSET_INTR_STATUS, val);
}

static void
__pvscsi_mask_intr(pvscsi_softc_t *pvs)
{

	pvscsi_reg_write(pvs, PVSCSI_REG_OFFSET_INTR_MASK, 0);
}

/* Called under pvs->intr_mutex */
static void
pvscsi_mask_intr(pvscsi_softc_t *pvs)
{

	ASSERT(mutex_owned(&pvs->intr_mutex));
	VERIFY(pvs->intr_lock_counter >= 0);

	if (++pvs->intr_lock_counter == 1)
		__pvscsi_mask_intr(pvs);
}

static void
__pvscsi_unmask_intr(pvscsi_softc_t *pvs)
{
	uint32_t intr_bits = PVSCSI_INTR_CMPL_MASK | PVSCSI_INTR_MSG_MASK;

	pvscsi_reg_write(pvs, PVSCSI_REG_OFFSET_INTR_MASK, intr_bits);
}

/* Called under pvs->intr_mutex */
static void
pvscsi_unmask_intr(pvscsi_softc_t *pvs)
{

	ASSERT(mutex_owned(&pvs->intr_mutex));
	VERIFY(pvs->intr_lock_counter > 0);

	if (--pvs->intr_lock_counter == 0)
		__pvscsi_unmask_intr(pvs);
}

static void
pvscsi_hba_reset(pvscsi_softc_t *pvs)
{

	pvscsi_write_cmd_desc(pvs, PVSCSI_CMD_ADAPTER_RESET, NULL, 0);
}

static void
pvscsi_bus_reset(pvscsi_softc_t *pvs)
{

	pvscsi_write_cmd_desc(pvs, PVSCSI_CMD_RESET_BUS, NULL, 0);
}

/* ARGSUSED dip */
static int
pvscsi_iport_attach(dev_info_t *dip)
{

	return (DDI_SUCCESS);
}

static int
pvscsi_update_props(dev_info_t *dip, char **compat, int ncompat, int target,
    int lun)
{

	if (ndi_prop_update_int(DDI_DEV_T_NONE, dip, "target", target) !=
	    DDI_PROP_SUCCESS)
		return (DDI_FAILURE);
	if (ndi_prop_update_int(DDI_DEV_T_NONE, dip, "lun", lun) !=
	    DDI_PROP_SUCCESS)
		return (DDI_FAILURE);
	if (ndi_prop_update_int(DDI_DEV_T_NONE, dip, "pm-capable", 1) !=
	    DDI_PROP_SUCCESS)
		return (DDI_FAILURE);
	if (ndi_prop_update_string_array(DDI_DEV_T_NONE, dip, "compatible",
	    compat, ncompat) != DDI_PROP_SUCCESS)
		return (DDI_FAILURE);

	return (DDI_SUCCESS);
}

static void
add_cmd_to_active_list(pvscsi_cmd_t *cmd)
{
	pvscsi_softc_t	*pvs = cmd->cmd_pvs;

	ASSERT(pvs);
	ASSERT(pvs->num_active_commands >= 0);
	ASSERT(mutex_owned(&pvs->mutex));

	if (!list_link_active(&(cmd)->active_list)) {
		list_insert_tail(&pvs->active_commands, cmd);
		pvs->num_active_commands++;
	}
}

/* Called under protection of 'pvs->mutex' */
static boolean_t
remove_command_from_active_list(pvscsi_cmd_t *cmd)
{
	pvscsi_softc_t	*pvs = cmd->cmd_pvs;

	ASSERT(pvs);
	ASSERT(mutex_owned(&pvs->mutex));
	if (list_link_active(&cmd->active_list)) {
		ASSERT(pvs->num_active_commands > 0);

		list_remove(&pvs->active_commands, cmd);
		pvs->num_active_commands--;
		return (B_TRUE);
	}

	return (B_FALSE);
}

/* Called under 'ndi_devi_enter()' lock held */
static pvscsi_device_t
*lookup_device(pvscsi_softc_t *pvs, int target, int lun)
{
	pvscsi_device_t *dev;

	for (dev = list_head(&pvs->devnodes); dev != NULL;
	    dev = list_next(&pvs->devnodes, dev)) {
		if (dev->target == target && dev->lun == lun)
			break;
	}

	return (dev);
}

static int
inquiry_target(pvscsi_softc_t *pvs, int target, int lun,
    int (*callback)(caddr_t), caddr_t callback_arg, struct scsi_inquiry *inq)
{
	struct scsi_address ap;
	uint8_t		cdb[CDB_GROUP0];
	int		len = sizeof (struct scsi_inquiry);
	int		ret = -1;
	struct buf	*b;
	struct scsi_pkt *pkt;

	ap.a_target = (ushort_t)target;
	ap.a_lun = (uint8_t)lun;
	ap.a_hba_tran = pvs->tran;

	if ((b = scsi_alloc_consistent_buf(&ap, (struct buf *)NULL, len, B_READ,
	    callback, callback_arg)) == NULL)
		return (-1);

	if ((pkt = scsi_init_pkt(&ap, (struct scsi_pkt *)NULL, b,
	    CDB_GROUP0, sizeof (struct scsi_arq_status), 0, 0,
	    callback, callback_arg)) == NULL)
		goto free_buf;

	cdb[0] = SCMD_INQUIRY;
	cdb[1] = 0;
	cdb[2] = 0;
	cdb[3] = (len & 0xff00) >> 8;
	cdb[4] = (len & 0x00ff);
	cdb[5] = 0;

	if (inq != NULL)
		bzero(inq, sizeof (*inq));
	bcopy(cdb, pkt->pkt_cdbp, CDB_GROUP0);
	bzero((struct scsi_inquiry *)b->b_un.b_addr, sizeof (*inq));

	if ((ret = scsi_poll(pkt)) == 0 && inq != NULL)
		bcopy(b->b_un.b_addr, inq, sizeof (*inq));

	scsi_free_consistent_buf(b);
	scsi_destroy_pkt(pkt);
	return (ret);
free_buf:
	scsi_free_consistent_buf(b);

	return (ret);
}

/* Called under 'ndi_devi_enter()' lock held */
static int
config_one(dev_info_t *pdip, pvscsi_softc_t *pvs, int target, int lun,
dev_info_t **childp)
{
	struct scsi_inquiry inq;
	pvscsi_device_t *devnode;
	char		*nodename = NULL;
	char		**compatible = NULL;
	int		ncompatible = 0;
	dev_info_t	*dip;
	int		r;

	if ((devnode = lookup_device(pvs, target, lun)) != NULL) {
		*childp = devnode->pdip;
		return (NDI_SUCCESS);
	}

	if (inquiry_target(pvs, target, lun, NULL_FUNC, 0, &inq) != 0)
		return (NDI_FAILURE);

	scsi_hba_nodename_compatible_get(&inq, NULL, inq.inq_dtype, NULL,
	    &nodename, &compatible, &ncompatible);
	if (nodename == NULL)
		return (NDI_FAILURE);

	if ((r = ndi_devi_alloc(pdip, nodename, DEVI_SID_NODEID, &dip)) ==
	    NDI_SUCCESS) {
		if (pvscsi_update_props(dip, compatible, ncompatible,
		    target, lun) != DDI_SUCCESS) {
			dev_err(pvs->dip, CE_WARN,
			    "failed to update props for device %d:%d",
			    target, lun);
			goto out;
		}

		devnode = kmem_zalloc(sizeof (*devnode), KM_NOSLEEP);
		if (devnode != NULL) {
			r = ndi_devi_online(dip, NDI_ONLINE_ATTACH);
			if (r != NDI_SUCCESS) {
				ndi_prop_remove_all(dip);
				(void) ndi_devi_free(dip);
				kmem_free(devnode, sizeof (*devnode));
				dev_err(pvs->dip, CE_WARN,
				    "failed to bring device %d:%d online",
				    target, lun);
			} else {
				devnode->target = target;
				devnode->lun = lun;
				devnode->pdip = dip;
				devnode->parent = pdip;
				list_insert_tail(&pvs->devnodes, devnode);

				if (childp != NULL)
					*childp = dip;
			}
		} else {
			ndi_prop_remove_all(dip);
			(void) ndi_devi_free(dip);
		}
	} else {
		dev_err(pvs->dip, CE_WARN,
		    "failed to allocate device instance");
	}
out:
	scsi_hba_nodename_compatible_free(nodename, compatible);

	return (r);
}

/* Called under 'ndi_devi_enter()' lock held */
static void
drop_devnode(pvscsi_softc_t *pvs, pvscsi_device_t *devnode)
{

	ASSERT(devnode->pdip);

	/*
	 * Make sure node is attached, otherwise it won't have
	 * related cache nodes to clean up.
	 */
	if (i_ddi_devi_attached(devnode->pdip)) {
		char	*devname;

		/* Get full devname */
		devname = kmem_alloc(MAXNAMELEN + 1, KM_SLEEP);
		(void) ddi_deviname(devnode->pdip, devname);
		/* Clean cache and name */
		(void) devfs_clean(devnode->parent, devname+1, DV_CLEAN_FORCE);
		kmem_free(devname, MAXNAMELEN + 1);
	}

	(void) ndi_devi_offline(devnode->pdip, NDI_DEVI_REMOVE);

	list_remove(&pvs->devnodes, devnode);
	kmem_free(devnode, sizeof (*devnode));
}

/* Called under 'ndi_devi_enter()' lock held */
static int
config_all(dev_info_t *pdip, pvscsi_softc_t *pvs)
{
	int		target, lun;
	pvscsi_device_t *devnode;

	for (target = 0; target < PVSCSI_MAXDEVS; target++) {
		devnode = lookup_device(pvs, target, 0);

		if (devnode == NULL) {
			/* No devices in the tree, try to probe it */
			if (config_one(pdip, pvs, target, 0, NULL) ==
			    NDI_SUCCESS) {
				for (lun = 1; lun < PVSCSI_MAXLUNS; lun++) {
					(void) config_one(pdip, pvs, target,
					    lun, NULL);
				}
			}
		} else {
			/* Device present in the tree, try to reprobe LUNs */
			if (inquiry_target(pvs, target, 0, NULL_FUNC, 0, NULL)
			    == 0) {
				/* The whole device is present, rescan LUNs */
				for (lun = 1; lun < PVSCSI_MAXLUNS; lun++) {
					if ((devnode = lookup_device(pvs,
					    target, lun)) != NULL) {
						if (inquiry_target(pvs, target,
						    lun, NULL_FUNC, 0,
						    NULL) != 0) {
							/*
							 * LUN has disappeared,
							 * drop it.
							 */
							drop_devnode(pvs,
							    devnode);
						}
					}
				}
			} else {
				/* Drop LUN #0 */
				drop_devnode(pvs, devnode);
				/* Drop the rest of the LUNs. */
				for (lun = 1; lun < PVSCSI_MAXLUNS; lun++) {
					devnode = lookup_device(pvs, target,
					    lun);
					if (devnode != NULL)
						drop_devnode(pvs, devnode);
				}
			}
		}
	}

	return (NDI_SUCCESS);
}

/* ARGSUSED hba_dip tgt_dip hba_tran */
static int
pvscsi_tgt_init(dev_info_t *hba_dip, dev_info_t *tgt_dip,
    scsi_hba_tran_t *hba_tran, struct scsi_device *sd)
{
	pvscsi_softc_t *pvs = SDEV2PRIV(sd);

	ASSERT(pvs != NULL);

	if (sd->sd_address.a_lun >= pvs->num_luns ||
	    sd->sd_address.a_target >= PVSCSI_MAXDEVS)
		return (DDI_FAILURE);

	return (DDI_SUCCESS);
}

/* ARGSUSED hba_dip tgt_dip hba_tran sd */
static void
pvscsi_tgt_free(dev_info_t *hba_dip, dev_info_t *tgt_dip,
		    scsi_hba_tran_t *hba_tran, struct scsi_device *sd)
{
}

static void
pvscsi_submit_nonrw_io(pvscsi_softc_t *pvs)
{

	pvscsi_reg_write(pvs, PVSCSI_REG_OFFSET_KICK_NON_RW_IO, 0);
}

static void
pvscsi_submit_rw_io(pvscsi_softc_t *pvs)
{

	pvscsi_reg_write(pvs, PVSCSI_REG_OFFSET_KICK_RW_IO, 0);
}

/* Called under protection of 'pvs->mtx' */
static void
pvscsi_submit_command(pvscsi_softc_t *pvs, pvscsi_cmd_t *cmd)
{
	struct scsi_pkt *pkt = CMD2PKT(cmd);

	/* Setup timeout before submitting actual I/O */
	cmd->timeout_lbolt = ddi_get_lbolt() + SEC_TO_TICK(pkt->pkt_time);
	pkt->pkt_state |= (STATE_GOT_BUS | STATE_GOT_TARGET | STATE_SENT_CMD);
	add_cmd_to_active_list(cmd);

	switch (cmd->pkt->pkt_cdbp[0]) {
	case SCMD_READ:
	case SCMD_WRITE:
	case SCMD_READ_G1:
	case SCMD_WRITE_G1:
	case SCMD_READ_G4:
	case SCMD_WRITE_G4:
	case SCMD_READ_G5:
	case SCMD_WRITE_G5:
		ASSERT(cmd->flags & PVSCSI_FLAG_DMA_VALID);
		pvscsi_submit_rw_io(pvs);
		break;
	default:
		pvscsi_submit_nonrw_io(pvs);
		break;
	}
}

static boolean_t
pvscsi_acquire_cmd_ctx(pvscsi_softc_t *pvs, pvscsi_cmd_t *cmd)
{
	pvscsi_cmd_ctx_t *ctx;

	if (list_is_empty(&pvs->cmd_ctx_pool))
		return (B_FALSE);

	ctx = (pvscsi_cmd_ctx_t *)list_remove_head(&pvs->cmd_ctx_pool);
	ASSERT(ctx != NULL);

	ctx->cmd = cmd;
	cmd->ctx = ctx;

	return (B_TRUE);
}

static void
__pvscsi_release_cmd_ctx(pvscsi_cmd_t *cmd)
{
	pvscsi_softc_t	*pvs = cmd->cmd_pvs;

	cmd->ctx->cmd = NULL;
	list_insert_tail(&pvs->cmd_ctx_pool, cmd->ctx);
	cmd->ctx = NULL;
}

static void
pvscsi_release_cmd_ctx(pvscsi_cmd_t *cmd)
{

	mutex_enter(&cmd->cmd_pvs->mutex);
	__pvscsi_release_cmd_ctx(cmd);
	mutex_exit(&cmd->cmd_pvs->mutex);
}

/* Called under protection of 'pvs->rx_mutex' */
static pvscsi_cmd_t
*drain_completion_ring(pvscsi_softc_t *pvs)
{
	pvscsi_cmd_t	**pnext_cmd = NULL;
	pvscsi_cmd_t	*cmd, *head = NULL;
	struct rings_state *sdesc = RINGS_STATE(pvs);
	uint32_t	e = sdesc->cmp_num_entries_log2;

	ASSERT(mutex_owned(&pvs->rx_mutex));

	while (sdesc->cmp_cons_idx != sdesc->cmp_prod_idx) {
		pvscsi_cmd_ctx_t *ctx;
		struct ring_cmp_desc *cdesc;
		long		c;
		boolean_t	removed;

		cdesc = CMP_RING(pvs) + (sdesc->cmp_cons_idx & MASK(e));
		membar_consumer();

		c = cdesc->context;
		ctx = pvscsi_resolve_context(pvs, c);
		ASSERT(ctx);

		if ((cmd = ctx->cmd) != NULL) {
			cmd->next_cmd = NULL;

			/* Save command status for further processing */
			cmd->cmp_stat.host_status = cdesc->host_status;
			cmd->cmp_stat.scsi_status = cdesc->scsi_status;
			cmd->cmp_stat.data_len = cdesc->data_len;

			dev_err(pvs->dip, CE_WARN, "aborting command: %p",
			    (void *)cmd);

			/* Mark this command as arrived from hardware */
			cmd->flags |= PVSCSI_FLAG_HW_STATUS;

			/* Remove command from active list. */
			mutex_enter(&pvs->mutex);
			removed = remove_command_from_active_list(cmd);
			mutex_exit(&pvs->mutex);

			if (removed) {
				if (head == NULL) {
					head = cmd;
					head->tail_cmd = cmd;
				} else {
					head->tail_cmd = cmd;
				}

				if (pnext_cmd == NULL) {
					pnext_cmd = &cmd->next_cmd;
				} else {
					*pnext_cmd = cmd;
					pnext_cmd = &cmd->next_cmd;
				}
			}
		}

		membar_producer();
		sdesc->cmp_cons_idx++;
	}

	return (head);
}

/* Called under protection of 'cmd->pvs->rx_mutex', 'cmd->pvs->tx_mutex' */
static int
pvscsi_abort_cmd(pvscsi_cmd_t *cmd, pvscsi_cmd_t **pending_cmds)
{
	pvscsi_softc_t	*pvs = cmd->cmd_pvs;
	pvscsi_cmd_t	*done_cmds;
	struct cmd_desc_abort_cmd acmd;
	pvscsi_cmd_t	*c;

	dev_err(pvs->dip, CE_WARN, "aborting command %p", (void *)cmd);

	ASSERT(mutex_owned(&pvs->rx_mutex));
	ASSERT(mutex_owned(&pvs->tx_mutex));

	/*
	 * Get 'pre-cancel' list of completed commands. Target command
	 * can be on it (which means that it was completed before
	 * cancellation.
	 */
	*pending_cmds = done_cmds = drain_completion_ring(pvs);
	for (c = done_cmds; c != NULL; c = c->next_cmd) {
		if (c == cmd) {
			/*
			 * Command was completed by the HBA, can't cancel.
			 * Return: 'pre_cancel'.
			 */
			dev_err(pvs->dip, CE_WARN, "[A] 1");
			return (CMD_CMPLT);
		}
	}

	/* Was target command actually scheduled by the HBA? */
	if (pvscsi_lookup_context(pvs, cmd) == NULL) {
		/*
		 * No active I/O context for the command, can't cancel.
		 * Return: 'pre_cancel'.
		 */
		dev_err(pvs->dip, CE_WARN, "[A] 2");
		return (CMD_CMPLT);
	}

	/* Cancel the command in HBA */
	bzero(&acmd, sizeof (acmd));
	acmd.target = cmd->cmd_target;
	acmd.context = pvscsi_map_context(pvs, cmd->ctx);
	pvscsi_write_cmd_desc(pvs, PVSCSI_CMD_ABORT_CMD, &acmd,
	    sizeof (acmd));

	/* Check 'post-cancel' commands */
	if ((done_cmds = drain_completion_ring(pvs)) != NULL) {
		/* Return: 'post_cancel' -> 'pre_cancel' */
		done_cmds->tail_cmd->next_cmd = *pending_cmds;
		*pending_cmds = done_cmds;

		/* Check 'post-cancel' commands for target command */
		for (c = done_cmds; c != NULL; c = c->next_cmd) {
			if (c == cmd) {
				/*
				 * Target command was completed before it was
				 * actually aborted by the HBA.
				 */
				dev_err(pvs->dip, CE_WARN, "[A] 4");
				return (CMD_CMPLT);
			}
		}
		/* No target command found among the completed commands */
		dev_err(pvs->dip, CE_WARN, "[A] 5");
	}

	/* Release I/O context */
	mutex_enter(&pvs->mutex);
	if (cmd->ctx)
		__pvscsi_release_cmd_ctx(cmd);

	/* Remove command from the list of active commands */
	(void) remove_command_from_active_list(cmd);
	mutex_exit(&pvs->mutex);

	/* Insert our command in the beginning of the list */
	cmd->next_cmd = *pending_cmds;
	*pending_cmds = cmd;

	dev_err(pvs->dip, CE_WARN, "[A] 7");

	return (CMD_ABORTED);
}

/* ARGSUSED pvs */
static void
pvscsi_map_buffers(pvscsi_softc_t *pvs, pvscsi_cmd_t *cmd,
    struct ring_req_desc *rdesc)
{
	int	i;

	ASSERT(cmd->ctx);
	ASSERT(cmd->cmd_cookiec > 0 && cmd->cmd_cookiec <=
	    PVSCSI_MAX_SG_SIZE);

	rdesc->data_len = cmd->cmd_dma_count;
	rdesc->data_addr = 0;

	if (cmd->cmd_dma_count == 0)
		return;

	if (cmd->cmd_cookiec > 1) {
		struct sg_element *sgl = CMD_CTX_SGLIST_VA(cmd->ctx);

		for (i = 0; i < cmd->cmd_cookiec; i++) {
			sgl[i].addr = cmd->cached_cookies[i].dmac_laddress;
			sgl[i].length = cmd->cached_cookies[i].dmac_size;
			sgl[i].flags = 0;
		}
		rdesc->flags |= PVSCSI_FLAG_CMD_WITH_SG_LIST;
		rdesc->data_addr = (uint64_t)CMD_CTX_SGLIST_PA(cmd->ctx);
	} else {
		rdesc->data_addr = cmd->cached_cookies[0].dmac_laddress;
	}
}

static uint64_t
pvscsi_map_context(pvscsi_softc_t *pvs, pvscsi_cmd_ctx_t *io_ctx)
{

	return (io_ctx - pvs->cmd_ctx + 1);
}

/*
 * This function can do only RO access to pvs, because
 * it is widely used without holding 'pvs->mutex'.
 */
static pvscsi_cmd_ctx_t *
pvscsi_resolve_context(pvscsi_softc_t *pvs, uint64_t ctx)
{

	if (ctx > 0 && ctx <= pvs->req_depth)
		return (&pvs->cmd_ctx[ctx - 1]);
	else
		return (NULL);
}

/* ARGSUSED pvs */
static pvscsi_cmd_ctx_t *
pvscsi_lookup_context(pvscsi_softc_t *pvs, pvscsi_cmd_t *cmd)
{
	pvscsi_cmd_ctx_t *ctx, *end;

	end = &pvs->cmd_ctx[pvs->req_depth];
	for (ctx = pvs->cmd_ctx; ctx < end; ctx++) {
		if (ctx->cmd == cmd)
			return (ctx);
	}
	return (NULL);
}

static void
pvscsi_dev_reset(pvscsi_softc_t *pvs, int target)
{
	struct cmd_desc_reset_device cmd = { 0 };

	cmd.target = target;
	pvscsi_write_cmd_desc(pvs, PVSCSI_CMD_RESET_DEVICE, &cmd, sizeof (cmd));
}

/* Must be called with intrs disabled! */
static int
pvscsi_poll_cmd(pvscsi_softc_t *pvs, pvscsi_cmd_t *cmd)
{
	int		i;
	int		cycles = (cmd->pkt->pkt_time * 1000000) / USECS_TO_WAIT;
	boolean_t	saw_irq;
	pvscsi_cmd_t	*drained;
	struct scsi_pkt *pkt = CMD2PKT(cmd);

	ASSERT(pvs->intr_lock_counter > 0);

	/*
	 * Make sure we're not missing any commands completed
	 * concurrently before we have actually disabled IRQs.
	 */
	mutex_enter(&pvs->rx_mutex);
	drained = drain_completion_ring(pvs);
	mutex_exit(&pvs->rx_mutex);

	COMPLETE_CHAINED_COMMANDS(drained);

	while (!(cmd->flags & PVSCSI_FLAG_DONE)) {
		saw_irq = B_FALSE;

		/* Wait for IRQ to arrive */
		for (i = 0; i < cycles; i++) {
			uint32_t	status;

			mutex_enter(&pvs->rx_mutex);
			mutex_enter(&pvs->intr_mutex);
			status = pvscsi_read_intr_status(pvs);

			if ((status & PVSCSI_INTR_ALL_SUPPORTED) != 0) {
				/* Check completion ring */
				mutex_exit(&pvs->intr_mutex);
				drained = drain_completion_ring(pvs);
				mutex_exit(&pvs->rx_mutex);
				saw_irq = B_TRUE;
				break;
			} else {
				mutex_exit(&pvs->intr_mutex);
				mutex_exit(&pvs->rx_mutex);
				drv_usecwait(USECS_TO_WAIT);
			}
		}

		if (saw_irq) {
			/*
			 * IRQ arrived. Give another chance to the command
			 * (during the next loop iteration). But prior doing it
			 * complete everything awaiting on completion list.
			 */
			COMPLETE_CHAINED_COMMANDS(drained);
		} else {
			/* No IRQs arrived from device during the timeout */
			mutex_enter(&pvs->tx_mutex);
			mutex_enter(&pvs->rx_mutex);

			if (cmd->flags & PVSCSI_FLAGS_COMPLETION) {
				/*
				 * Command was cancelled asynchronously.
				 * No commands awaiting for complete - all
				 * commands that completed before our
				 * command were drained by the initiator
				 * of our command's cancellation.
				 */
				drained = NULL;
			} else {
				/*
				 * Command is still active. Last chance - being
				 * completed during explicit command
				 * cancellation.
				 */
				if ((pvscsi_abort_cmd(cmd, &drained)) ==
				    CMD_ABORTED) {
					/*
					 * Cancellation confirmed - command was
					 * really cancelled in hardware.
					 */
					pkt->pkt_state |= (STAT_TIMEOUT |
					    STAT_ABORTED);
					pkt->pkt_statistics |= (STAT_TIMEOUT|
					    STAT_ABORTED);
					pkt->pkt_reason = CMD_TIMEOUT;
				}
			}
			mutex_exit(&pvs->rx_mutex);
			mutex_exit(&pvs->tx_mutex);

			/*
			 * Complete commands that might be on completion list.
			 * Target command can also be on the list in case it was
			 * lucky to complete before it was actually cancelled.
			 */
			COMPLETE_CHAINED_COMMANDS(drained);
			break;
		}
	}

	return (TRAN_ACCEPT);
}

/* Called under protection of 'pvs->tx_mutex' */
static int
pvscsi_queue_cmd(pvscsi_softc_t *pvs, pvscsi_cmd_t *cmd)
{
	struct rings_state *sdesc;
	struct ring_req_desc *rdesc;
	uint32_t	req_entries;
	pvscsi_cmd_ctx_t *io_ctx = cmd->ctx;

	sdesc = RINGS_STATE(pvs);
	req_entries = sdesc->req_num_entries_log2;

	if ((sdesc->req_prod_idx - sdesc->cmp_cons_idx) >= (1 << req_entries)) {
		dev_err(pvs->dip, CE_WARN, "no free I/O slots available");
		return (TRAN_BUSY);
	}

	cmd->flags |= PVSCSI_FLAG_TRANSPORT;

	rdesc = REQ_RING(pvs) + (sdesc->req_prod_idx & MASK(req_entries));

	bzero(&rdesc->lun, sizeof (rdesc->lun));

	rdesc->bus = 0; /* Currently only bus #0 is supported (by the Spec.) */
	rdesc->target = cmd->cmd_target;

	rdesc->lun[1] = cmd->cmd_lun;

	if ((cmd->flags & PVSCSI_FLAG_XARQ) != 0) {
		bzero((void*)cmd->arq_buf->b_un.b_addr, SENSE_BUFFER_SIZE);
		rdesc->sense_len = SENSE_BUFFER_SIZE;
		rdesc->sense_addr = cmd->arq_cookie.dmac_laddress;
	} else {
		rdesc->sense_len = 0;
		rdesc->sense_addr = 0;
	}

	rdesc->vcpu_hint = CPU->cpu_id;
	rdesc->cdb_len = cmd->cmdlen;
	bcopy(cmd->cmd_cdb, rdesc->cdb, cmd->cmdlen);

	/* Setup tag info */
	if (cmd->flags & PVSCSI_FLAG_TAG)
		rdesc->tag = cmd->tag;
	else
		rdesc->tag = MSG_SIMPLE_QTAG;

	/* Setup I/O direction and map data buffers */
	if (cmd->flags & PVSCSI_FLAG_DMA_VALID) {
		if (cmd->flags & PVSCSI_FLAG_IO_READ)
			rdesc->flags = PVSCSI_FLAG_CMD_DIR_TOHOST;
		else
			rdesc->flags = PVSCSI_FLAG_CMD_DIR_TODEVICE;
		pvscsi_map_buffers(pvs, cmd, rdesc);
	} else {
		rdesc->flags = 0;
	}

	rdesc->context = pvscsi_map_context(pvs, io_ctx);

	membar_producer();
	sdesc->req_prod_idx++;
	membar_producer();

	return (TRAN_ACCEPT);
}

/* Called under protection of 'pvs->tx_mutex' and 'pvs->rx_mutex' */
static int
__pvscsi_abort_all(struct scsi_address *ap, pvscsi_softc_t *pvs,
	pvscsi_cmd_t **pending_cmds, int marker_flag)
{
	pvscsi_cmd_t	*pending_head, *pending;
	pvscsi_cmd_t	*cmd;
	int		active_cmds;

	ASSERT(mutex_owned(&pvs->rx_mutex));
	ASSERT(mutex_owned(&pvs->tx_mutex));

	pending_head = NULL;
	active_cmds = pvs->num_active_commands;

	/*
	 * Try to abort all active commands, merging commands waiting
	 * for completion into a single list to complete them at one
	 * time when mutex is released.
	 */
	while (active_cmds > 0) {
		boolean_t	our_packet;

		mutex_enter(&pvs->mutex);
		cmd = list_remove_head(&pvs->active_commands);
		ASSERT(cmd);

		active_cmds--;
		if (ap != NULL) {
			our_packet = (ap->a_target == cmd->cmd_target &&
			    ap->a_lun == cmd->cmd_lun);
		} else {
			our_packet = B_TRUE;
		}

		if (our_packet) {
			int	rc, c;

			pvs->num_active_commands--;
			c = pvs->num_active_commands;
			mutex_exit(&pvs->mutex);

			rc = pvscsi_abort_cmd(cmd, &pending);
			if (rc == CMD_ABORTED) {
				/*
				 * Assume command is completely cancelled now,
				 * so mark it as requested.
				 */
				cmd->flags |= marker_flag;
			}

			active_cmds -= (c - pvs->num_active_commands);

			/*
			 * Now merge current pending commands with
			 * previous ones.
			 */
			if (pending_head == NULL) {
				pending_head = pending;
			} else {
				if (pending != NULL) {
					pending_head->tail_cmd->next_cmd =
					    pending;
					pending_head->tail_cmd =
					    pending->tail_cmd;
				}
			}
		} else {
			list_insert_tail(&pvs->active_commands, cmd);
			mutex_exit(&pvs->mutex);
		}
	}

	*pending_cmds = pending_head;

	return (1);
}

/* Called under 'pvs->stallq_mutex' */
static void
__remove_command_from_stalled_list(pvscsi_cmd_t *cmd)
{
	pvscsi_softc_t	*pvs = cmd->cmd_pvs;

	ASSERT(pvs);

	if (CMD_ON_STALLED_LIST(cmd)) {
		ASSERT(pvs->num_stalled_commands > 0);

		list_remove(&pvs->stalled_commands, cmd);
		pvs->num_stalled_commands--;
		cmd->flags &= ~PVSCSI_FLAG_STALLED;
		cmd->next_cmd = NULL;
		cmd->tail_cmd = cmd;
	}
}

/* Called under 'pvs->stallq_mutex' */
static pvscsi_cmd_t *
__extract_command_from_stalled_list(pvscsi_softc_t *pvs)
{
	pvscsi_cmd_t	*cmd;

	ASSERT(pvs);

	cmd = list_remove_head(&pvs->stalled_commands);
	if (cmd) {
		ASSERT(pvs->num_stalled_commands > 0);

		pvs->num_stalled_commands--;
		cmd->flags &= ~PVSCSI_FLAG_STALLED;
	}

	return (cmd);
}

static void
notify_quiesce_waiters(pvscsi_softc_t *pvs)
{

	mutex_enter(&pvs->mutex);
	if (pvs->num_active_commands == 0 &&
	    (pvs->flags & PVSCSI_HBA_QUIESCE_PENDING) != 0) {
		pvs->flags &= ~PVSCSI_HBA_QUIESCE_PENDING;
		cv_broadcast(&pvs->quiescevar);
	}
	mutex_exit(&pvs->mutex);
}

static int
pvscsi_abort(struct scsi_address *ap, struct scsi_pkt *pkt)
{
	pvscsi_cmd_t	*pending_cmds;
	pvscsi_softc_t	*pvs = ap->a_hba_tran->tran_hba_private;
	boolean_t	wakeup_quiesced = B_FALSE;
	int		rc;

	if (pkt != NULL) {
		/* Abort single command */
		pvscsi_cmd_t *cmd = PKT2CMD(pkt);

		mutex_enter(&pvs->tx_mutex);
		mutex_enter(&pvs->rx_mutex);
		mutex_enter(&pvs->stallq_mutex);
		if (CMD_ON_STALLED_LIST(cmd)) {
			__remove_command_from_stalled_list(cmd);
			mutex_exit(&pvs->stallq_mutex);
			pending_cmds = cmd;
			rc = CMD_ABORTED;
		} else {
			mutex_exit(&pvs->stallq_mutex);
			rc = pvscsi_abort_cmd(cmd, &pending_cmds);

			/* Take into account pending quiesce requests */
			wakeup_quiesced = SHOULD_WAKE_QUIESCERS(pvs);
		}

		if (rc == CMD_ABORTED) {
			/* Assume command is completely cancelled now */
			cmd->flags |= PVSCSI_FLAG_ABORTED;
		}
		mutex_exit(&pvs->rx_mutex);
		mutex_exit(&pvs->tx_mutex);

		COMPLETE_CHAINED_COMMANDS(pending_cmds);
	} else {
		/* Abort all commands for this target/lun */
		pvscsi_cmd_t	*pending_stalled;
		pvscsi_cmd_t	*c;

		mutex_enter(&pvs->tx_mutex);
		mutex_enter(&pvs->rx_mutex);

		/* First, abort all commands on the bus */
		(void) __pvscsi_abort_all(ap, pvs, &pending_cmds,
		    PVSCSI_FLAG_ABORTED);

		/* Second, abort all commands in stalled queue */
		mutex_enter(&pvs->stallq_mutex);
		pending_stalled = __extract_command_from_stalled_list(pvs);
		if (pending_stalled) {
			for (c = pending_stalled; c != NULL; ) {
				c->flags |= PVSCSI_FLAG_ABORTED;
				c->next_cmd =
				    __extract_command_from_stalled_list(pvs);
				c = c->next_cmd;
			}
		}
		mutex_exit(&pvs->stallq_mutex);

		/* Take into account pending quiesce requests */
		wakeup_quiesced = SHOULD_WAKE_QUIESCERS(pvs);
		mutex_exit(&pvs->rx_mutex);
		mutex_exit(&pvs->tx_mutex);

		COMPLETE_CHAINED_COMMANDS(pending_cmds);
		COMPLETE_CHAINED_COMMANDS(pending_stalled);
	}

	if (wakeup_quiesced)
		notify_quiesce_waiters(pvs);

	return (1);
}

static void
__add_command_to_stalled_list(pvscsi_softc_t *pvs, pvscsi_cmd_t *cmd)
{

	ASSERT(pvs);
	ASSERT(pvs->num_stalled_commands >= 0);
	ASSERT((cmd->flags & PVSCSI_FLAG_STALLED) == 0);
	ASSERT(mutex_owned(&pvs->stallq_mutex));

	if (!list_link_active(&(cmd)->active_list)) {
		cmd->flags |= PVSCSI_FLAG_STALLED;
		list_insert_tail(&pvs->stalled_commands, cmd);
		pvs->num_stalled_commands++;
	}
}


static void
add_command_to_stalled_list(pvscsi_softc_t *pvs,
			    pvscsi_cmd_t *cmd)
{

	mutex_enter(&pvs->stallq_mutex);
	__add_command_to_stalled_list(pvs, cmd);
	mutex_exit(&pvs->stallq_mutex);
}

static int
__pvscsi_transport_command(pvscsi_softc_t *pvs, pvscsi_cmd_t *cmd,
    boolean_t use_stallq, boolean_t *reinserted)
{
	int		ret;
	boolean_t	free_ctx = B_FALSE;

	if (ddi_in_panic())
		return (TRAN_ACCEPT);

	mutex_enter(&pvs->tx_mutex);
	mutex_enter(&pvs->mutex);
	if (!pvscsi_acquire_cmd_ctx(pvs, cmd)) {
		/* Slow path if allocation fails */
		mutex_enter(&pvs->stallq_mutex);
		if (!pvscsi_acquire_cmd_ctx(pvs, cmd)) {
			dev_err(pvs->dip, CE_WARN, "no free ctx available");
			/* Keep the other mutex locked */
			mutex_exit(&pvs->mutex);
			mutex_exit(&pvs->tx_mutex);
			goto add_stalled;
		}
		mutex_exit(&pvs->stallq_mutex);
	}
	mutex_exit(&pvs->mutex);

	if (pvscsi_queue_cmd(pvs, cmd) != TRAN_ACCEPT) {
		/* Slow path */
		mutex_enter(&pvs->stallq_mutex);
		if (pvscsi_queue_cmd(pvs, cmd) != TRAN_ACCEPT) {
			dev_err(pvs->dip, CE_WARN, "failed to queue cmd");
			mutex_exit(&pvs->tx_mutex);
			free_ctx = B_TRUE;
			goto add_stalled;
		}
		mutex_exit(&pvs->stallq_mutex);
	}

	/* 'tx_mutex' is held */
	mutex_enter(&pvs->mutex);
	pvscsi_submit_command(pvs, cmd);
	mutex_exit(&pvs->mutex);

	mutex_exit(&pvs->tx_mutex);

	if (reinserted != NULL)
		*reinserted = B_FALSE;

	return (TRAN_ACCEPT);

add_stalled:
	/* stallq_mutex must be held when reaching these lines */
	if (free_ctx)
		pvscsi_release_cmd_ctx(cmd);

	if (use_stallq) {
		__add_command_to_stalled_list(pvs, cmd);
		ret = TRAN_ACCEPT;
	} else {
		ret = TRAN_BUSY;
	}
	mutex_exit(&pvs->stallq_mutex);

	if (reinserted != NULL)
		*reinserted = (ret == TRAN_ACCEPT);

	return (ret);
}

static void
__prepare_pkt(pvscsi_cmd_t *cmd)
{
	struct scsi_pkt	*pkt = CMD2PKT(cmd);

	/*
	 * Reinitialize some fields because the packet may
	 * have been resubmitted.
	 */
	pkt->pkt_reason = CMD_CMPLT;
	pkt->pkt_state = 0;
	pkt->pkt_statistics = 0;

	/* Zero status byte */
	*(pkt->pkt_scbp) = 0;

	if (cmd->flags & PVSCSI_FLAG_DMA_VALID) {
		ASSERT(cmd->cmd_dma_count != 0);
		pkt->pkt_resid = cmd->cmd_dma_count;

		/*
		 * Consistent packets need to be sync'ed first
		 * (only for data going out).
		 */
		if ((cmd->flags & PVSCSI_FLAG_IO_IOPB) != 0) {
			(void) ddi_dma_sync(cmd->cmd_handle, 0, 0,
			    DDI_DMA_SYNC_FORDEV);
		}
	}
}

static int
pvscsi_start(struct scsi_address *ap, struct scsi_pkt *pkt)
{
	pvscsi_softc_t	*pvs = ap->a_hba_tran->tran_hba_private;
	pvscsi_cmd_t	*cmd = PKT2CMD(pkt);
	boolean_t	handle_cmd;
	boolean_t	poll = ((pkt->pkt_flags & FLAG_NOINTR) != 0);
	int		rc = TRAN_ACCEPT;

	ASSERT(cmd->pkt == pkt);
	ASSERT(cmd->cmd_pvs == pvs);

	__prepare_pkt(cmd);

	cmd->cmd_target = ap->a_target;
	cmd->cmd_lun = ap->a_lun;

	if (poll) {
		/* Disable IRQs from the hardware */
		mutex_enter(&pvs->intr_mutex);
		pvs->num_pollers++;
		pvscsi_mask_intr(pvs);
		mutex_exit(&pvs->intr_mutex);
	}

	mutex_enter(&pvs->mutex);
	if (HBA_IS_QUIESCED(pvs)) {
		/* TODO Handle stalled poll requests properly */
		add_command_to_stalled_list(pvs, cmd);
		mutex_exit(&pvs->mutex);
		handle_cmd = B_FALSE;
	} else {
		mutex_exit(&pvs->mutex);
		rc = __pvscsi_transport_command(pvs, cmd, !poll, NULL);
		handle_cmd = B_TRUE;
	}

	if (poll && handle_cmd && (rc == TRAN_ACCEPT))
		rc = pvscsi_poll_cmd(pvs, cmd);

	if (poll && handle_cmd) {
		pvscsi_cmd_t	*drained;
		boolean_t	wakeup_quiesced;

		/* Enable IRQs from the hardware */
		mutex_enter(&pvs->intr_mutex);
		pvs->num_pollers--;
		pvscsi_unmask_intr(pvs);
		mutex_exit(&pvs->intr_mutex);

		mutex_enter(&pvs->rx_mutex);
		drained = drain_completion_ring(pvs);
		mutex_exit(&pvs->rx_mutex);

		mutex_enter(&pvs->mutex);
		/* Take into account pending quiesce requests */
		wakeup_quiesced = SHOULD_WAKE_QUIESCERS(pvs);
		mutex_exit(&pvs->mutex);

		COMPLETE_CHAINED_COMMANDS(drained);

		if (wakeup_quiesced)
			notify_quiesce_waiters(pvs);
	}

	return (rc);
}

/* Called under 'pvs->mtx' */
static void
__notify_stallq_thread(pvscsi_softc_t *pvs)
{

	ASSERT(pvs != NULL);
}

static int
pvscsi_reset_generic(pvscsi_softc_t *pvs, struct scsi_address *ap)
{
	pvscsi_cmd_t	*done_before, *aborted;
	boolean_t	bus_reset = (ap == NULL);
	int		flags;

	flags = bus_reset ? PVSCSI_FLAG_RESET_BUS : PVSCSI_FLAG_RESET_DEV;

	mutex_enter(&pvs->tx_mutex);
	mutex_enter(&pvs->rx_mutex);
	/* Try to process pending requests */
	done_before = drain_completion_ring(pvs);

	/* Abort all pending requests */
	(void) __pvscsi_abort_all(ap, pvs, &aborted, flags);

	/* Reset at hardware level */
	if (bus_reset) {
		pvscsi_bus_reset(pvs);
		/* Should never happen after bus reset */
		ASSERT(drain_completion_ring(pvs) == NULL);
	} else {
		pvscsi_dev_reset(pvs, ap->a_target);
	}
	mutex_exit(&pvs->rx_mutex);
	mutex_exit(&pvs->tx_mutex);

	/* Process all pending commands */
	COMPLETE_CHAINED_COMMANDS(done_before);
	COMPLETE_CHAINED_COMMANDS(aborted);

	return (1);
}

static int
pvscsi_reset(struct scsi_address *ap, int level)
{
	pvscsi_softc_t	*pvs = AP2PRIV(ap);

	switch (level) {
	case RESET_ALL:
		return (pvscsi_reset_generic(pvs, NULL));
	case RESET_TARGET:
		ASSERT(ap != NULL);
		return (pvscsi_reset_generic(pvs, ap));
	default:
		return (0);
	}
}

/* ARGSUSED ap, tgtonly */
static int
pvscsi_getcap(struct scsi_address *ap, char *cap, int tgtonly)
{
	pvscsi_softc_t	*pvs = ap->a_hba_tran->tran_hba_private;

	if (!cap)
		return (B_FALSE);

	switch (scsi_hba_lookup_capstr(cap)) {
	case SCSI_CAP_ARQ:
		return ((pvs->flags & PVSCSI_HBA_AUTO_REQUEST_SENSE) != 0);
	case SCSI_CAP_UNTAGGED_QING:
		return (B_TRUE);
	default:
		return (-1);
	}
}

/* ARGSUSED ap tgtonly */
static int
pvscsi_setcap(struct scsi_address *ap, char *cap, int value, int tgtonly)
{
	pvscsi_softc_t	*pvs = ap->a_hba_tran->tran_hba_private;

	if (!cap)
		return (B_FALSE);

	switch (scsi_hba_lookup_capstr(cap)) {
	case SCSI_CAP_ARQ:
		mutex_enter(&pvs->mutex);
		if (value == 0)
			pvs->flags &= ~PVSCSI_HBA_AUTO_REQUEST_SENSE;
		else
			pvs->flags |= PVSCSI_HBA_AUTO_REQUEST_SENSE;
		mutex_exit(&pvs->mutex);
		return (B_TRUE);
	default:
		break;
	}

	return (B_FALSE);
}

static void
pvscsi_cmd_ext_free(pvscsi_cmd_t *cmd)
{
	struct scsi_pkt *pkt = CMD2PKT(cmd);

	if (cmd->flags & PVSCSI_FLAG_CDB_EXT) {
		kmem_free(pkt->pkt_cdbp, cmd->cmdlen);
		cmd->flags &= ~PVSCSI_FLAG_CDB_EXT;
	}
	if (cmd->flags & PVSCSI_FLAG_SCB_EXT) {
		kmem_free(pkt->pkt_scbp, cmd->statuslen);
		cmd->flags &= ~PVSCSI_FLAG_SCB_EXT;
	}
	if (cmd->flags & PVSCSI_FLAG_PRIV_EXT) {
		kmem_free(pkt->pkt_private, cmd->tgtlen);
		cmd->flags &= ~PVSCSI_FLAG_PRIV_EXT;
	}
}

/* ARGSUSED pvs */
static int
pvscsi_cmd_ext_alloc(pvscsi_softc_t *pvs, pvscsi_cmd_t *cmd, int kf)
{
	void		*buf;
	struct scsi_pkt *pkt = CMD2PKT(cmd);

	if (cmd->cmdlen > sizeof (cmd->cmd_cdb)) {
		if ((buf = kmem_zalloc(cmd->cmdlen, kf)) == NULL)
			return (NULL);
		pkt->pkt_cdbp = buf;
		cmd->flags |= PVSCSI_FLAG_CDB_EXT;
	}

	if (cmd->statuslen > sizeof (cmd->cmd_scb)) {
		if ((buf = kmem_zalloc(cmd->statuslen, kf)) == NULL)
			goto out;
		pkt->pkt_scbp = buf;
		cmd->flags |= PVSCSI_FLAG_SCB_EXT;
		cmd->cmd_rqslen = (cmd->statuslen - sizeof (cmd->cmd_scb));
	}

	if (cmd->tgtlen > sizeof (cmd->tgt_priv)) {
		if ((buf = kmem_zalloc(cmd->tgtlen, kf)) == NULL)
			goto out;
		pkt->pkt_private = buf;
		cmd->flags |= PVSCSI_FLAG_PRIV_EXT;
	}

	return (DDI_SUCCESS);
out:
	pvscsi_cmd_ext_free(cmd);

	return (NULL);
}

static struct scsi_pkt *
pvscsi_init_pkt(struct scsi_address *ap, struct scsi_pkt *pkt, struct buf *bp,
    int cmdlen, int statuslen, int tgtlen, int flags,
    int (*callback)(), caddr_t arg)
{
	int		kf = (callback == SLEEP_FUNC) ? KM_SLEEP: KM_NOSLEEP;
	pvscsi_softc_t 	*pvs;
	pvscsi_cmd_t	*cmd;
	boolean_t	is_new;
	int		rc, i;

	pvs = ap->a_hba_tran->tran_hba_private;
	ASSERT(pvs != NULL);

	if (ap->a_lun >= pvs->num_luns) {
		dev_err(pvs->dip, CE_WARN, "bad lun provided: %d (MAX: %d)",
		    ap->a_lun, pvs->num_luns);
		return (NULL);
	}

	/* Allocate a new SCSI packet */
	if (pkt == NULL) {
		ddi_dma_handle_t saved_handle, saved_arq_handle;
		struct buf *saved_arqbuf;
		ddi_dma_cookie_t saved_arq_cookie;

		if ((cmd = kmem_cache_alloc(pvs->cmd_cache, kf)) == NULL)
			return (NULL);

		saved_handle = cmd->cmd_handle;
		saved_arq_handle = cmd->arq_handle;
		saved_arqbuf = cmd->arq_buf;
		saved_arq_cookie = cmd->arq_cookie;

		bzero(cmd, sizeof (pvscsi_cmd_t) -
		    sizeof (cmd->cached_cookies));

		cmd->cmd_pvs = pvs;
		cmd->cmd_handle = saved_handle;
		cmd->arq_handle = saved_arq_handle;
		cmd->arq_buf = saved_arqbuf;
		cmd->arq_cookie = saved_arq_cookie;

		pkt = &cmd->cached_pkt;
		pkt->pkt_ha_private = (opaque_t)cmd;
		pkt->pkt_address = *ap;
		pkt->pkt_scbp = (uint8_t *)&cmd->cmd_scb;
		pkt->pkt_cdbp = (uint8_t *)&cmd->cmd_cdb;
		pkt->pkt_private = (opaque_t)&cmd->tgt_priv;

		cmd->tgtlen = tgtlen;
		cmd->statuslen = statuslen;
		cmd->cmdlen = cmdlen;
		cmd->pkt = pkt;
		cmd->ctx = NULL;

		is_new = B_TRUE;

		/* Allocate extended buffers */
		if ((cmdlen > sizeof (cmd->cmd_cdb)) ||
		    (statuslen > sizeof (cmd->cmd_scb)) ||
		    (tgtlen > sizeof (cmd->tgt_priv))) {
			if (pvscsi_cmd_ext_alloc(pvs, cmd, kf) != DDI_SUCCESS) {
				dev_err(pvs->dip, CE_WARN,
				    "extent allocation failed");
				goto out;
			}
		}
	} else {
		cmd = PKT2CMD(pkt);
		/* Clear non-persistent command flags */
		cmd->flags &= PVSCSI_FLAGS_PERSISTENT;
		is_new = B_FALSE;
	}

	ASSERT((cmd->flags & PVSCSI_FLAG_TRANSPORT) == 0);

	if (flags & PKT_XARQ)
		cmd->flags |= PVSCSI_FLAG_XARQ;

	/* Handle partial DMA transfers */
	if (cmd->cmd_nwin > 0) {
		if (++cmd->cmd_winindex >= cmd->cmd_nwin)
			return (NULL);
		if (ddi_dma_getwin(cmd->cmd_handle, cmd->cmd_winindex,
		    &cmd->cmd_dma_offset, &cmd->cmd_dma_len,
		    &cmd->cmd_cookie, &cmd->cmd_cookiec) == DDI_FAILURE)
			return (NULL);
		goto handle_dma_cookies;
	}

	/* Setup data buffer. */
	if (bp != NULL && bp->b_bcount > 0 &&
	    (cmd->flags & PVSCSI_FLAG_DMA_VALID) == 0) {
		int	dma_flags;

		/*
		 * TODO Add buffers support. See scsa1394_cmd_buf_dma_alloc()
		 * for details.
		 */
		if (bp->b_flags & B_READ) {
			cmd->flags |= PVSCSI_FLAG_IO_READ;
			dma_flags = DDI_DMA_READ;
		} else {
			cmd->flags &= ~PVSCSI_FLAG_IO_READ;
			dma_flags = DDI_DMA_WRITE;
		}

		if (flags & PKT_CONSISTENT) {
			cmd->flags |= PVSCSI_FLAG_IO_IOPB;
			dma_flags |= DDI_DMA_CONSISTENT;
		}

		if (flags & PKT_DMA_PARTIAL)
			dma_flags |= DDI_DMA_PARTIAL;

		/*
		 * TODO Setup buffer's DMA resources properly.
		 * See mptsas_scsi_init_pkt().
		 */
		ASSERT(cmd->cmd_handle != NULL);

		rc = ddi_dma_buf_bind_handle(cmd->cmd_handle, bp,
		    dma_flags, callback, arg, &cmd->cmd_cookie,
		    &cmd->cmd_cookiec);
		if (rc == DDI_DMA_PARTIAL_MAP) {
			cmd->cmd_winindex = 0;
			(void) ddi_dma_numwin(cmd->cmd_handle, &cmd->cmd_nwin);
			(void) ddi_dma_getwin(cmd->cmd_handle,
			    cmd->cmd_winindex, &cmd->cmd_dma_offset,
			    &cmd->cmd_dma_len, &cmd->cmd_cookie,
			    &cmd->cmd_cookiec);
		} else if (rc && (rc != DDI_DMA_MAPPED)) {
			switch (rc) {
			case DDI_DMA_NORESOURCES:
				bioerror(bp, 0);
				break;
			case DDI_DMA_BADATTR:
			case DDI_DMA_NOMAPPING:
				bioerror(bp, EFAULT);
				break;
			case DDI_DMA_TOOBIG:
			default:
				bioerror(bp, EINVAL);
				break;
			}
			cmd->flags &= ~PVSCSI_FLAG_DMA_VALID;
			goto out;
		}

handle_dma_cookies:
		ASSERT(cmd->cmd_cookiec > 0);
		if (cmd->cmd_cookiec > PVSCSI_MAX_SG_SIZE) {
			dev_err(pvs->dip, CE_WARN,
			    "big cookie count: %d (max %d)",
			    cmd->cmd_cookiec, PVSCSI_MAX_SG_SIZE);
			bioerror(bp, EINVAL);
			goto out;
		}

		cmd->flags |= PVSCSI_FLAG_DMA_VALID;
		cmd->cmd_dma_count = cmd->cmd_cookie.dmac_size;
		cmd->cmd_total_dma_count += cmd->cmd_cookie.dmac_size;

		cmd->cached_cookies[0] = cmd->cmd_cookie;

		/*
		 * Calculate total anount of bytes for this I/O and
		 * store cookies for further processing.
		 */
		for (i = 1; i < cmd->cmd_cookiec; i++) {
			ddi_dma_nextcookie(cmd->cmd_handle, &cmd->cmd_cookie);

			cmd->cached_cookies[i] = cmd->cmd_cookie;
			cmd->cmd_dma_count += cmd->cmd_cookie.dmac_size;
			cmd->cmd_total_dma_count += cmd->cmd_cookie.dmac_size;
		}

		pkt->pkt_resid = (bp->b_bcount - cmd->cmd_total_dma_count);
	}

	return (pkt);
out:
	if (is_new) {
		/*
		 * TODO Implement proper buffer cleanup
		 * (including DMA deallocation).
		 */
		pvscsi_cmd_ext_free(cmd);
		kmem_cache_free(pvs->cmd_cache, cmd);
	}

	return (NULL);
}

static void
pvscsi_destroy_pkt(struct scsi_address *ap, struct scsi_pkt *pkt)
{
	pvscsi_cmd_t	*cmd = PKT2CMD(pkt);
	pvscsi_softc_t	*pvs = ap->a_hba_tran->tran_hba_private;

	ASSERT(cmd->cmd_pvs == pvs);

	if (cmd->ctx)
		pvscsi_release_cmd_ctx(cmd);

	if (cmd->flags & PVSCSI_FLAGS_EXT)
		pvscsi_cmd_ext_free(cmd);

	kmem_cache_free(pvs->cmd_cache, cmd);
}

/* ARGSUSED ap */
static void
pvscsi_dmafree(struct scsi_address *ap, struct scsi_pkt *pkt)
{
	pvscsi_cmd_t	*cmd = PKT2CMD(pkt);

	if ((cmd->flags & PVSCSI_FLAG_DMA_VALID) != 0) {
		(void) ddi_dma_unbind_handle(cmd->cmd_handle);
		cmd->flags &= ~PVSCSI_FLAG_DMA_VALID;
	}
}

/* ARGSUSED ap pkt */
static void
pvscsi_sync_pkt(struct scsi_address *ap, struct scsi_pkt *pkt)
{
}

/* ARGSUSED ap flag callback arg */
static int
pvscsi_reset_notify(struct scsi_address *ap, int flag,
	void (*callback)(caddr_t), caddr_t arg)
{

	return (DDI_FAILURE);
}

/* ARGSUSED dip */
static int
pvscsi_hba_quiesce(dev_info_t *dip)
{
	pvscsi_softc_t	*pvs;
	scsi_hba_tran_t *tran;

	if ((tran = ddi_get_driver_private(dip)) == NULL ||
	    (pvs = TRAN2PRIV(tran)) == NULL)
		return (-1);

	mutex_enter(&pvs->mutex);
	if (!HBA_IS_QUIESCED(pvs))
		pvs->flags |= PVSCSI_HBA_QUIESCED;

	/* Outstanding commands present, wait */
	if (pvs->num_active_commands != 0) {
		pvs->flags |= PVSCSI_HBA_QUIESCE_PENDING;
		cv_wait(&pvs->quiescevar, &pvs->mutex);
		ASSERT(pvs->num_active_commands == 0);
	}
	mutex_exit(&pvs->mutex);

	return (0);
}

static void
__fire_stalled_queue(pvscsi_softc_t *pvs, boolean_t can_reinsert)
{
	pvscsi_cmd_t	*cmd;
	boolean_t	stallq_fired = B_TRUE;
	int		rc;
	boolean_t	reinserted;

	while (stallq_fired) {
		mutex_enter(&pvs->stallq_mutex);
		cmd = __extract_command_from_stalled_list(pvs);
		mutex_exit(&pvs->stallq_mutex);

		if (cmd == NULL)
			break;

		rc = __pvscsi_transport_command(pvs, cmd, can_reinsert,
		    &reinserted);
		stallq_fired = (rc == TRAN_ACCEPT && reinserted == B_FALSE);

		/* Transport failed, reinsert */
		if (!stallq_fired)
			add_command_to_stalled_list(pvs, cmd);
	}
}

static int
pvscsi_hba_unquiesce(dev_info_t *dip)
{
	pvscsi_softc_t	*pvs;
	scsi_hba_tran_t *tran;

	if ((tran = ddi_get_driver_private(dip)) == NULL ||
	    (pvs = TRAN2PRIV(tran)) == NULL)
		return (-1);

	mutex_enter(&pvs->mutex);
	if (!HBA_IS_QUIESCED(pvs)) {
		mutex_exit(&pvs->mutex);
		return (0);
	}
	ASSERT(pvs->num_active_commands == 0);
	pvs->flags &= ~PVSCSI_HBA_QUIESCED;
	mutex_exit(&pvs->mutex);

	__fire_stalled_queue(pvs, B_TRUE);

	return (0);
}

static int
pvscsi_bus_config(dev_info_t *pdip, uint_t flags, ddi_bus_config_op_t op,
    void *arg, dev_info_t **childp)
{
	int		ret = NDI_FAILURE;
	int		circ = 0;
	pvscsi_softc_t	*pvs;
	scsi_hba_tran_t *tran;

	tran = ddi_get_driver_private(pdip);
	pvs = tran->tran_hba_private;

	ndi_devi_enter(pdip, &circ);
	switch (op) {
	case BUS_CONFIG_ONE:
		ret = config_one(pdip, pvs, 0, 0, childp);
		break;
	case BUS_CONFIG_DRIVER:
	case BUS_CONFIG_ALL:
		ret = config_all(pdip, pvs);
		break;
	default:
		ret = NDI_FAILURE;
		break;
	}

	if (ret == NDI_SUCCESS)
		ret = ndi_busop_bus_config(pdip, flags, op, arg, childp, 0);
	ndi_devi_exit(pdip, circ);

	return (ret);
}

static int
pvscsi_tgt_probe(struct scsi_device *sd, int (*callback)())
{

	return (scsi_hba_probe(sd, callback));
}

static int
pvscsi_hba_setup(pvscsi_softc_t *pvs)
{
	scsi_hba_tran_t *hba_tran;
	int		tran_flags;

	hba_tran = pvs->tran = scsi_hba_tran_alloc(pvs->dip,
	    SCSI_HBA_CANSLEEP);
	ASSERT(pvs->tran != NULL);

	hba_tran->tran_hba_private = pvs;
	hba_tran->tran_tgt_private = NULL;

	hba_tran->tran_tgt_init	= pvscsi_tgt_init;
	hba_tran->tran_tgt_free	= pvscsi_tgt_free;
	hba_tran->tran_tgt_probe = pvscsi_tgt_probe;

	hba_tran->tran_start = pvscsi_start;
	hba_tran->tran_reset = pvscsi_reset;
	hba_tran->tran_abort = pvscsi_abort;
	hba_tran->tran_getcap = pvscsi_getcap;
	hba_tran->tran_setcap = pvscsi_setcap;
	hba_tran->tran_init_pkt = pvscsi_init_pkt;
	hba_tran->tran_destroy_pkt = pvscsi_destroy_pkt;

	hba_tran->tran_dmafree = pvscsi_dmafree;
	hba_tran->tran_sync_pkt = pvscsi_sync_pkt;
	hba_tran->tran_reset_notify = pvscsi_reset_notify;

	hba_tran->tran_quiesce = pvscsi_hba_quiesce;
	hba_tran->tran_unquiesce = pvscsi_hba_unquiesce;
	hba_tran->tran_bus_reset = NULL;

	hba_tran->tran_add_eventcall = NULL;
	hba_tran->tran_get_eventcookie = NULL;
	hba_tran->tran_post_event = NULL;
	hba_tran->tran_remove_eventcall = NULL;

	hba_tran->tran_bus_config = pvscsi_bus_config;

	hba_tran->tran_interconnect_type = INTERCONNECT_SAS;

	tran_flags = (SCSI_HBA_TRAN_SCB | SCSI_HBA_TRAN_CDB |
	    SCSI_HBA_TRAN_CLONE);

	if (scsi_hba_attach_setup(pvs->dip, &pvs->msg_dma_attr,
	    hba_tran, tran_flags) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to attach HBA");
		scsi_hba_tran_free(hba_tran);
		pvs->tran = NULL;
		return (-1);
	}

	return (0);
}

static int
pvscsi_setup_dma_buffer(size_t length, pv_dma_buf_t *buf, int consistency,
int rw, pvscsi_softc_t *pvs)
{
	/* DMA access attributes for descriptors */
	static ddi_device_acc_attr_t attrs = {
		DDI_DEVICE_ATTR_V0,
		DDI_STRUCTURE_LE_ACC,
		DDI_STRICTORDER_ACC,
		DDI_DEFAULT_ACC,
	};
	ddi_dma_cookie_t cookie;
	uint_t		ccount;

	if ((ddi_dma_alloc_handle(pvs->dip, &pvscsi_ring_dma_attr,
	    DDI_DMA_SLEEP, NULL, &buf->dma_handle)) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to allocate DMA handle");
		return (DDI_FAILURE);
	}

	if ((ddi_dma_mem_alloc(buf->dma_handle, length, &attrs, consistency,
	    DDI_DMA_SLEEP, NULL, &buf->addr, &buf->real_length,
	    &buf->acc_handle)) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN,
		    "failed to allocate %ld bytes for DMA buffer", length);
		ddi_dma_free_handle(&buf->dma_handle);
		return (DDI_FAILURE);
	}

	if ((ddi_dma_addr_bind_handle(buf->dma_handle, NULL, buf->addr,
	    buf->real_length, consistency | rw, DDI_DMA_SLEEP, NULL, &cookie,
	    &ccount)) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to bind DMA buffer");
		ddi_dma_free_handle(&buf->dma_handle);
		ddi_dma_mem_free(&buf->acc_handle);
		return (DDI_FAILURE);
	}

	/* TODO Support multipart SG regions */
	ASSERT(ccount == 1);

	buf->pa = cookie.dmac_laddress;

	return (DDI_SUCCESS);
}

static void
pvscsi_free_dma_buffer(pv_dma_buf_t *buf)
{

	ddi_dma_free_handle(&buf->dma_handle);
	ddi_dma_mem_free(&buf->acc_handle);
}

static int
pvscsi_setup_sg(pvscsi_softc_t *pvs)
{
	int		i, j = 0;
	pvscsi_cmd_ctx_t *ctx;
	size_t		size = pvs->req_depth * sizeof (pvscsi_cmd_ctx_t);

	if ((pvs->cmd_ctx = kmem_alloc(size, KM_SLEEP)) == NULL) {
		dev_err(pvs->dip, CE_WARN,
		    "failed to allocate %ld bytes for cmd ctx", size);
		return (DDI_FAILURE);
	}
	bzero(pvs->cmd_ctx, size);

	ctx = pvs->cmd_ctx;
	for (i = 0; i < pvs->req_depth; ++i, ++ctx) {
		list_insert_tail(&pvs->cmd_ctx_pool, ctx);

		if (pvscsi_setup_dma_buffer(PAGE_SIZE, &ctx->dma_buf,
		    DDI_DMA_CONSISTENT, DDI_DMA_RDWR, pvs) != DDI_SUCCESS)
			goto cleanup;
		j++;
	}

	return (DDI_SUCCESS);
cleanup:
	for (; i >= 0; --i, --ctx) {
		list_remove(&pvs->cmd_ctx_pool, ctx);
		pvscsi_free_dma_buffer(&ctx->dma_buf);
	}
	kmem_free(pvs->cmd_ctx, size);

	return (DDI_FAILURE);
}

static void
pvscsi_free_sg(pvscsi_softc_t *pvs)
{
	pvscsi_cmd_ctx_t *ctx = pvs->cmd_ctx;
	int		i;

	for (i = 0; i < pvs->req_depth; ++i, ++ctx) {
		list_remove(&pvs->cmd_ctx_pool, ctx);
		pvscsi_free_dma_buffer(&ctx->dma_buf);
	}

	kmem_free(pvs->cmd_ctx, pvs->req_pages << PAGE_SHIFT);
}

static void
pvscsi_free_rings(pvscsi_softc_t *pvs)
{

	pvscsi_free_dma_buffer(&pvs->msg_ring_buf);
	pvscsi_free_dma_buffer(&pvs->cmp_ring_buf);
	pvscsi_free_dma_buffer(&pvs->req_ring_buf);
	pvscsi_free_dma_buffer(&pvs->rings_state_buf);
}

static int
pvscsi_allocate_rings(pvscsi_softc_t *pvs)
{

	/* Allocate DMA buffer for rings state */
	if (pvscsi_setup_dma_buffer(PAGE_SIZE, &pvs->rings_state_buf,
	    DDI_DMA_CONSISTENT, DDI_DMA_RDWR, pvs) != DDI_SUCCESS)
		goto out;

	/* Allocate DMA buffer for request ring */
	pvs->req_pages = MIN(PVSCSI_MAX_NUM_PAGES_REQ_RING, pvscsi_ring_pages);
	pvs->req_depth = pvs->req_pages * PVSCSI_MAX_NUM_REQ_ENTRIES_PER_PAGE;

	if (pvscsi_setup_dma_buffer(pvs->req_pages * PAGE_SIZE,
	    &pvs->req_ring_buf, DDI_DMA_CONSISTENT, DDI_DMA_RDWR,
	    pvs) != DDI_SUCCESS)
		goto free_rings_state;

	/* Allocate completion ring */
	pvs->cmp_pages = MIN(PVSCSI_MAX_NUM_PAGES_CMP_RING,
	    pvscsi_ring_pages);
	if (pvscsi_setup_dma_buffer(pvs->cmp_pages * PAGE_SIZE,
	    &pvs->cmp_ring_buf, DDI_DMA_CONSISTENT, DDI_DMA_RDWR,
	    pvs) != DDI_SUCCESS)
		goto free_req_buf;

	/* Allocate message ring */
	pvs->msg_pages = MIN(PVSCSI_MAX_NUM_PAGES_MSG_RING,
	    pvscsi_ring_pages);
	if (pvscsi_setup_dma_buffer(pvs->msg_pages * PAGE_SIZE,
	    &pvs->msg_ring_buf, DDI_DMA_CONSISTENT, DDI_DMA_RDWR,
	    pvs) != DDI_SUCCESS)
		goto free_cmp_buf;

	return (DDI_SUCCESS);
free_cmp_buf:
	pvscsi_free_dma_buffer(&pvs->cmp_ring_buf);
free_req_buf:
	pvscsi_free_dma_buffer(&pvs->req_ring_buf);
free_rings_state:
	pvscsi_free_dma_buffer(&pvs->rings_state_buf);
out:
	return (DDI_FAILURE);
}

static int
pvscsi_setup_rings(pvscsi_softc_t *pvs)
{
	struct cmd_desc_setup_rings cmd = { 0 };
	struct cmd_desc_setup_msg_ring cmd_msg = { 0 };
	int		i;
	uint64_t	base;

	cmd.rings_state_ppn = pvs->rings_state_buf.pa >> PAGE_SHIFT;
	cmd.req_ring_num_pages = pvs->req_pages;
	cmd.cmp_ring_num_pages = pvs->cmp_pages;

	/* Setup request ring */
	base = pvs->req_ring_buf.pa;
	for (i = 0; i < pvs->req_pages; i++) {
		cmd.req_ring_ppns[i] = base >> PAGE_SHIFT;
		base += PAGE_SIZE;
	}

	/* Setup completion ring */
	base = pvs->cmp_ring_buf.pa;
	for (i = 0; i < pvs->cmp_pages; i++) {
		cmd.cmp_ring_ppns[i] = base >> PAGE_SHIFT;
		base += PAGE_SIZE;
	}

	(void) memset(RINGS_STATE(pvs), 0, PAGE_SIZE);
	(void) memset(REQ_RING(pvs), 0, pvs->req_pages * PAGE_SIZE);
	(void) memset(CMP_RING(pvs), 0, pvs->cmp_pages * PAGE_SIZE);

	/* Issue SETUP command */
	pvscsi_write_cmd_desc(pvs, PVSCSI_CMD_SETUP_RINGS, &cmd, sizeof (cmd));

	/* Setup message ring explicitly */
	cmd_msg.num_pages = pvs->msg_pages;
	base = pvs->msg_ring_buf.pa;

	for (i = 0; i < pvs->msg_pages; i++) {
		cmd_msg.ring_ppns[i] = base >> PAGE_SHIFT;
		base += PAGE_SIZE;
	}
	(void) memset(MSG_RING(pvs), 0, pvs->msg_pages * PAGE_SIZE);

	pvscsi_write_cmd_desc(pvs, PVSCSI_CMD_SETUP_MSG_RING, &cmd_msg,
	    sizeof (cmd_msg));

	return (DDI_SUCCESS);
}

static int
pvscsi_setup_io(pvscsi_softc_t *pvs)
{
	int		offset, rcount, rn, type;
	pci_regspec_t	*regs;
	off_t		regsize;
	uint_t		regs_length;
	int		ret = DDI_FAILURE;

	if (ddi_prop_lookup_int_array(DDI_DEV_T_ANY, pvs->dip,
	    DDI_PROP_DONTPASS, "reg", (int **)&regs,
	    &regs_length) != DDI_PROP_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to lookup 'reg' property");
		return (ret);
	}

	rcount = regs_length * sizeof (int) / sizeof (pci_regspec_t);

	for (offset = PCI_CONF_BASE0; offset <= PCI_CONF_BASE5; offset += 4) {
		for (rn = 0; rn < rcount; ++rn) {
			if (PCI_REG_REG_G(regs[rn].pci_phys_hi) == offset) {
				type = regs[rn].pci_phys_hi & PCI_ADDR_MASK;
				break;
			}
		}

		if (rn >= rcount)
			continue;

		if (type != PCI_ADDR_IO) {
			if (ddi_dev_regsize(pvs->dip, rn,
			    &regsize) != DDI_SUCCESS) {
				dev_err(pvs->dip, CE_WARN,
				    "failed to get size of reg %d", rn);
				goto out;
			}
			if (regsize == PVSCSI_MEM_SPACE_SIZE) {
				if (ddi_regs_map_setup(pvs->dip, rn,
				    &pvs->mmio_base, 0, 0,
				    &pvscsi_mmio_attr,
				    &pvs->mmio_handle) != DDI_SUCCESS) {
					dev_err(pvs->dip, CE_WARN,
					    "failed to map MMIO BAR");
					goto out;
				}
				ret = DDI_SUCCESS;
				break;
			}
		}
	}

out:
	ddi_prop_free(regs);

	return (ret);
}

static int
pvscsi_unmask_irq(pvscsi_softc_t *pvs)
{
	int	rc, irq_caps;

	if ((rc = ddi_intr_get_cap(pvs->intr_htable[0], &irq_caps)) !=
	    DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to get IRQ caps");
		return (DDI_FAILURE);
	}

	if (irq_caps & DDI_INTR_FLAG_BLOCK) {
		rc = ddi_intr_block_enable(pvs->intr_htable, pvs->intr_cnt);
	} else {
		int i;

		for (i = 0; i < pvs->intr_cnt; i++) {
			rc = ddi_intr_enable(pvs->intr_htable[i]);
			if (rc != DDI_SUCCESS) {
				dev_err(pvs->dip, CE_WARN,
				    "failed to unleash non-block IRQ");

				while (--i >= 0) {
					(void) ddi_intr_disable(
					    pvs->intr_htable[i]);
				}
				break;
			}
		}
	}

	if (rc == DDI_SUCCESS)
		__pvscsi_unmask_intr(pvs);

	return (rc);
}

static void
pvscsi_process_irq_deffered(pvscsi_softc_t *pvs)
{
	pvscsi_cmd_t	**pnext_cmd = NULL;
	pvscsi_cmd_t	*cmds_for_workers[MAX_WORKER_THREADS];
	struct rings_state *sdesc = RINGS_STATE(pvs);
	uint32_t	e = sdesc->cmp_num_entries_log2;
	int		slot = 0, item = 0;
	boolean_t	is_new_slot = B_TRUE;
	pvscsi_cmd_t	*cmd;

	bzero(cmds_for_workers, sizeof (cmds_for_workers));

	mutex_enter(&pvs->rx_mutex);
	while (sdesc->cmp_cons_idx != sdesc->cmp_prod_idx) {
		pvscsi_cmd_ctx_t *ctx;
		struct ring_cmp_desc *cdesc;
		boolean_t	removed;

		cdesc = CMP_RING(pvs) + (sdesc->cmp_cons_idx & MASK(e));
		membar_consumer();

		ctx = pvscsi_resolve_context(pvs, cdesc->context);
		ASSERT(ctx != NULL);

		if ((cmd = ctx->cmd) == NULL) {
			dev_err(pvs->dip, CE_WARN,
			    "cancelled command in completion ring");
		} else {
			cmd->next_cmd = NULL;
			/* Save command status for further processing */
			cmd->cmp_stat.host_status = cdesc->host_status;
			cmd->cmp_stat.scsi_status = cdesc->scsi_status;
			cmd->cmp_stat.data_len = cdesc->data_len;
			/* Remove command from active list */
			mutex_enter(&pvs->mutex);
			removed = remove_command_from_active_list(cmd);
			mutex_exit(&pvs->mutex);

			if (!removed)
				goto next;

			/* Mark this command as arrived from hardware */
			cmd->flags |= PVSCSI_FLAG_HW_STATUS;

			if (is_new_slot) {
				if (cmds_for_workers[slot] != NULL) {
					cmds_for_workers[slot]->
					    tail_cmd->next_cmd = cmd;
				} else {
					cmds_for_workers[slot] = cmd;
				}
				pnext_cmd = &cmd->next_cmd;
				is_new_slot = B_FALSE;
			} else {
				*pnext_cmd = cmd;
				pnext_cmd = &cmd->next_cmd;
			}

			item++;
			cmds_for_workers[slot]->tail_cmd = cmd;

			if (item == pvs->worker_threshold) {
				item = 0;
				slot++;
				is_new_slot = B_TRUE;

				if (slot == pvs->num_workers)
					slot = 0;
			}
		}
next:
		membar_producer();
		sdesc->cmp_cons_idx++;
	}
	mutex_exit(&pvs->rx_mutex);

	/*
	 * Now go through the completed requests and schedule actions
	 * to handle them in a separate kernel thread.
	 */
	for (slot = 0; slot < pvs->num_workers; slot++) {
		pvscsi_worker_state_t *ws;

		if ((cmd = cmds_for_workers[slot]) == NULL)
			break;

		ws = &pvs->workers_state[slot];

		mutex_enter(&ws->mtx);
		if (ws->head_cmd == NULL) {
			ws->head_cmd = cmd;
			ws->tail_cmd = cmd->tail_cmd;
		} else {
			ws->tail_cmd->next_cmd = cmd;
			ws->tail_cmd = cmd->tail_cmd;
		}

		if (!(ws->flags & PVSCSI_IRQ_WORKER_ACTIVE))
			cv_signal(&ws->cv);
		mutex_exit(&ws->mtx);
	}
}

static void
pvscsi_process_irq_immediately(pvscsi_softc_t *pvs)
{
	pvscsi_cmd_t	*pending_cmds;
	boolean_t	fire_stallq, wakeup_quiesced;

	mutex_enter(&pvs->rx_mutex);
	pending_cmds = drain_completion_ring(pvs);
	mutex_exit(&pvs->rx_mutex);

	mutex_enter(&pvs->mutex);
	fire_stallq = !HBA_IS_QUIESCED(pvs);

	/* Take into account pending quiesce requests */
	wakeup_quiesced = SHOULD_WAKE_QUIESCERS(pvs);
	mutex_exit(&pvs->mutex);

	/* Don't replay commands if HBA is quiesced */
	if (fire_stallq)
		__fire_stalled_queue(pvs, B_FALSE);

	COMPLETE_CHAINED_COMMANDS(pending_cmds);

	if (wakeup_quiesced)
		notify_quiesce_waiters(pvs);
}

/* ARGSUSED arg2 */
static uint32_t
pvscsi_irq_handler(caddr_t arg1, caddr_t arg2)
{
	pvscsi_softc_t	*pvs = (pvscsi_softc_t *)arg1;
	uint32_t	status;
	boolean_t	handled;

	ASSERT(pvs->num_pollers >= 0);

	mutex_enter(&pvs->intr_mutex);
	if (pvs->num_pollers > 0) {
		mutex_exit(&pvs->intr_mutex);
		return (DDI_INTR_CLAIMED);
	}

	if (pvs->msi_enable) {
		handled = B_TRUE;
	} else {
		status = pvscsi_read_intr_status(pvs);
		handled = (status & PVSCSI_INTR_ALL_SUPPORTED) != 0;
		if (handled)
			pvscsi_write_intr_status(pvs, status);
	}
	mutex_exit(&pvs->intr_mutex);

	if (handled) {
		if (pvs->num_workers != 0)
			pvscsi_process_irq_deffered(pvs);
		else
			pvscsi_process_irq_immediately(pvs);
	}

	return (handled ? DDI_INTR_CLAIMED : DDI_INTR_UNCLAIMED);
}

static int
pvscsi_install_irq_handler(pvscsi_softc_t *pvs, int type)
{
	int	nirqs = 0;
	int	navail = 0;
	int	nactual = 0;

	if (ddi_intr_get_nintrs(pvs->dip, type, &nirqs) != DDI_SUCCESS ||
	    nirqs != 1) {
		dev_err(pvs->dip, CE_WARN,
		    "failed to get number of IRQs of type %d", type);
		return (DDI_FAILURE);
	}

	if (ddi_intr_get_navail(pvs->dip, type, &navail) != DDI_SUCCESS ||
	    navail != 1) {
		dev_err(pvs->dip, CE_WARN,
		    "failed to get number of available IRQs of type %d", type);
		return (DDI_FAILURE);
	}

	pvs->intr_size = nirqs * sizeof (ddi_intr_handle_t);
	if ((pvs->intr_htable = kmem_alloc(pvs->intr_size, KM_SLEEP)) == NULL) {
		dev_err(pvs->dip, CE_WARN,
		    "failed to allocate %d bytes for IRQ hashtable",
		    pvs->intr_size);
		return (DDI_FAILURE);
	}

	if (ddi_intr_alloc(pvs->dip, pvs->intr_htable, type, 0, nirqs,
	    &nactual, DDI_INTR_ALLOC_NORMAL) != DDI_SUCCESS || nactual != 1) {
		dev_err(pvs->dip, CE_WARN,
		    "failed to allocate %d IRQs (or improper number of IRQs "
		    "provided: %d)", nirqs, nactual);
		goto free_htable;
	}

	pvs->intr_cnt = nactual;

	if (ddi_intr_get_pri(pvs->intr_htable[0],
	    (uint_t *)&pvs->intr_pri) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to get interrupt priority");
		goto free_irqs;
	}

	if (ddi_intr_add_handler(pvs->intr_htable[0], pvscsi_irq_handler,
	    (caddr_t)pvs, NULL) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to add IRQ handler");
		goto free_irqs;
	}

	return (DDI_SUCCESS);
free_irqs:
	(void) ddi_intr_free(pvs->intr_htable[0]);
free_htable:
	kmem_free(pvs->intr_htable, pvs->intr_size);

	return (DDI_FAILURE);
}

static void
pvscsi_free_io(pvscsi_softc_t *pvs)
{

	ddi_regs_map_free(&pvs->mmio_handle);
}

static void
vmw_shutdown_irq_workers(pvscsi_softc_t *pvs)
{
	int	i;

	if (pvs->num_workers > 0) {
		for (i = 0; i < pvs->num_workers; i++) {
			pvscsi_worker_state_t *ws = &pvs->workers_state[i];

			/* Grab the mutex for synchronization condvar */
			mutex_enter(&pvs->mutex);

			/* Request thread shutdown */
			mutex_enter(&ws->mtx);
			ws->flags |= PVSCSI_IRQ_WORKER_SHUTDOWN;
			cv_signal(&ws->cv);
			mutex_exit(&ws->mtx);

			/* Wait for notification from the thread */
			cv_wait(&pvs->syncvar, &pvs->mutex);
			mutex_exit(&pvs->mutex);

			/*
			 * Now we can safely destroy the rest of thread's
			 * resources.
			 */
			cv_destroy(&ws->cv);
			mutex_destroy(&ws->mtx);
		}

		/* Free data structures used by IRQ threads */
		kmem_free(pvs->workers_state, pvs->num_workers *
		    sizeof (pvscsi_worker_state_t));
	}

	/* Finally, shutdown watchdog thread */
	mutex_enter(&pvs->mutex);
	pvs->flags |= PVSCSI_DRIVER_SHUTDOWN;
	cv_signal(&pvs->wd_condvar);

	/* Wait for notification from the thread */
	cv_wait(&pvs->syncvar, &pvs->mutex);
	mutex_exit(&pvs->mutex);
}

static void
pvscsi_free_irq_resources(pvscsi_softc_t *pvs)
{

	(void) ddi_intr_disable(pvs->intr_htable[0]);
	(void) ddi_intr_remove_handler(pvs->intr_htable[0]);
	(void) ddi_intr_free(pvs->intr_htable[0]);
	kmem_free(pvs->intr_htable, pvs->intr_size);
}

static int
pvscsi_setup_irq(pvscsi_softc_t *pvs)
{
	int	irq_types, rc;

	if (ddi_intr_get_supported_types(pvs->dip,
	    &irq_types) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN,
		    "failed to acquire supported IRQ types");
		return (DDI_FAILURE);
	}

	if ((irq_types & DDI_INTR_TYPE_MSI) && pvs->msi_enable) {
		rc = pvscsi_install_irq_handler(pvs, DDI_INTR_TYPE_MSI);
		if (rc == DDI_SUCCESS) {
			pvs->irq_type = DDI_INTR_TYPE_MSI;
		} else {
			dev_err(pvs->dip, CE_WARN,
			    "failed to install MSI interrupt handler");
		}
	}

	if ((irq_types & DDI_INTR_TYPE_FIXED) && (pvs->irq_type == 0)) {
		rc = pvscsi_install_irq_handler(pvs, DDI_INTR_TYPE_FIXED);
		if (rc == DDI_SUCCESS) {
			pvs->irq_type = DDI_INTR_TYPE_FIXED;
		} else {
			dev_err(pvs->dip, CE_WARN,
			    "failed to install FIXED interrupt handler");
		}
	}

	return (pvs->irq_type == 0 ? DDI_FAILURE : DDI_SUCCESS);
}

static void
pvscsi_scsi_good_cmd(pvscsi_cmd_t *cmd, uint8_t status)
{
	struct scsi_pkt *pkt = CMD2PKT(cmd);

	pkt->pkt_state |= (STATE_GOT_BUS | STATE_GOT_TARGET | STATE_SENT_CMD |
	    STATE_GOT_STATUS);
	if (cmd->flags & (PVSCSI_FLAG_DMA_VALID))
		pkt->pkt_state |= STATE_XFERRED_DATA;
	pkt->pkt_reason = CMD_CMPLT;
	pkt->pkt_resid = 0;
	*(pkt->pkt_scbp) = status;
}

static void
pvscsi_set_hw_command_status(pvscsi_cmd_t *cmd)
{
	uchar_t		scsi_status = cmd->cmp_stat.scsi_status;
	uint32_t	host_status = cmd->cmp_stat.host_status;
	struct scsi_pkt *pkt = CMD2PKT(cmd);
	pvscsi_softc_t	*pvs = cmd->cmd_pvs;

	if (scsi_status != STATUS_GOOD &&
	    (host_status == BTSTAT_SUCCESS ||
	    (host_status == BTSTAT_LINKED_COMMAND_COMPLETED) ||
	    (host_status == BTSTAT_LINKED_COMMAND_COMPLETED_WITH_FLAG))) {

		if (scsi_status == STATUS_CHECK) {
			struct scsi_arq_status *astat = (void*)(pkt->pkt_scbp);
			uint8_t		*sensedata;
			int		arq_size;

			*pkt->pkt_scbp = scsi_status;
			pkt->pkt_state |= STATE_ARQ_DONE;

			if ((cmd->flags & PVSCSI_FLAG_XARQ) != 0) {
				arq_size = (cmd->cmd_rqslen >=
				    SENSE_BUFFER_SIZE) ? SENSE_BUFFER_SIZE :
				    cmd->cmd_rqslen;

				astat->sts_rqpkt_resid = SENSE_BUFFER_SIZE -
				    arq_size;
				sensedata = (uint8_t *)&astat->sts_sensedata;
				bcopy(cmd->arq_buf->b_un.b_addr, sensedata,
				    arq_size);

				pkt->pkt_state |= STATE_XARQ_DONE;
			} else {
				astat->sts_rqpkt_resid = 0;
			}

			astat->sts_rqpkt_statistics = 0;
			astat->sts_rqpkt_reason = CMD_CMPLT;
			(*(uint8_t *)&astat->sts_rqpkt_status) = STATUS_GOOD;
			astat->sts_rqpkt_state  = STATE_GOT_BUS |
			    STATE_GOT_TARGET | STATE_SENT_CMD |
			    STATE_XFERRED_DATA | STATE_GOT_STATUS;
		}

		pvscsi_scsi_good_cmd(cmd, scsi_status);
	} else {
		switch (host_status) {
		case BTSTAT_SUCCESS:
		case BTSTAT_LINKED_COMMAND_COMPLETED:
		case BTSTAT_LINKED_COMMAND_COMPLETED_WITH_FLAG:
			pvscsi_scsi_good_cmd(cmd, STATUS_GOOD);
			break;
		case BTSTAT_DATARUN:
			pkt->pkt_reason = CMD_DATA_OVR;
			pkt->pkt_state |= (STATE_GOT_BUS | STATE_GOT_TARGET |
			    STATE_SENT_CMD | STATE_GOT_STATUS |
			    STATE_XFERRED_DATA);
			pkt->pkt_resid = 0;
			break;
		case BTSTAT_DATA_UNDERRUN:
			pkt->pkt_reason = pkt->pkt_state |= (STATE_GOT_BUS |
			    STATE_GOT_TARGET | STATE_SENT_CMD |
			    STATE_GOT_STATUS);
			pkt->pkt_resid = cmd->dma_count -
			    cmd->cmp_stat.data_len;
			if (pkt->pkt_resid != cmd->dma_count)
				pkt->pkt_state |= STATE_XFERRED_DATA;
			break;
		case BTSTAT_SELTIMEO:
			pkt->pkt_reason = CMD_DEV_GONE;
			pkt->pkt_state |= STATE_GOT_BUS;
			break;
		case BTSTAT_TAGREJECT:
			pkt->pkt_reason = CMD_TAG_REJECT;
			pkt->pkt_state |= (STATE_GOT_BUS | STATE_GOT_TARGET |
			    STATE_SENT_CMD | STATE_GOT_STATUS);
			break;
		case BTSTAT_BADMSG:
			pkt->pkt_reason = CMD_BADMSG;
			pkt->pkt_state |= (STATE_GOT_BUS | STATE_GOT_TARGET |
			    STATE_SENT_CMD | STATE_GOT_STATUS);
			break;
		case BTSTAT_SENTRST:
		case BTSTAT_RECVRST:
		case BTSTAT_BUSRESET:
			pkt->pkt_reason = CMD_RESET;
			pkt->pkt_state |= (STATE_GOT_BUS | STATE_GOT_TARGET |
			    STATE_SENT_CMD | STATE_GOT_STATUS);
			break;
		case BTSTAT_ABORTQUEUE:
			pkt->pkt_reason = CMD_ABORTED;
			pkt->pkt_state |= (STATE_GOT_BUS | STATE_GOT_TARGET |
			    STATE_SENT_CMD | STATE_GOT_STATUS);
			break;
		case BTSTAT_HAHARDWARE:
		case BTSTAT_INVPHASE:
		case BTSTAT_HATIMEOUT:
		case BTSTAT_NORESPONSE:
		case BTSTAT_DISCONNECT:
		case BTSTAT_HASOFTWARE:
		case BTSTAT_BUSFREE:
		case BTSTAT_SENSFAILED:
			pkt->pkt_reason = CMD_TRAN_ERR;
			pkt->pkt_state |= (STATE_GOT_BUS | STATE_GOT_TARGET |
			    STATE_SENT_CMD | STATE_GOT_STATUS);
			break;
		default:
			dev_err(pvs->dip, CE_WARN,
			    "unknown host status code: %d", host_status);
			pkt->pkt_reason = CMD_TRAN_ERR;
			pkt->pkt_state |= (STATE_GOT_BUS | STATE_GOT_TARGET |
			    STATE_SENT_CMD | STATE_GOT_STATUS);
			break;
		}
	}
}

static void
pvscsi_set_command_status(pvscsi_cmd_t *cmd)
{
	int	stats;

	if (cmd->flags & PVSCSI_FLAG_HW_STATUS) {
		pvscsi_set_hw_command_status(cmd);
	} else {
		ASSERT(cmd->flags & PVSCSI_FLAGS_NON_HW_COMPLETION);

		if (cmd->flags & PVSCSI_FLAG_TIMED_OUT) {
			cmd->pkt->pkt_reason = CMD_TIMEOUT;
			cmd->pkt->pkt_statistics |= (STAT_TIMEOUT|STAT_ABORTED);
		} else if (cmd->flags & PVSCSI_FLAG_ABORTED) {
			cmd->pkt->pkt_reason = CMD_ABORTED;
			cmd->pkt->pkt_statistics |= (STAT_TIMEOUT|STAT_ABORTED);
		} else if (cmd->flags & PVSCSI_FLAGS_RESET) {
			cmd->pkt->pkt_reason = CMD_RESET;
			if (cmd->flags & PVSCSI_FLAG_RESET_BUS)
				stats = STAT_BUS_RESET;
			else
				stats = STAT_DEV_RESET;
			cmd->pkt->pkt_statistics |= stats;
		}
	}
}

static void
pvscsi_complete_command(pvscsi_cmd_t *cmd)
{
	struct scsi_pkt *pkt = CMD2PKT(cmd);

	if (pkt) {
		if ((cmd->flags & PVSCSI_FLAG_IO_IOPB) &&
		    (cmd->flags & PVSCSI_FLAG_IO_READ)) {
			(void) ddi_dma_sync(cmd->cmd_handle, 0, 0,
			    DDI_DMA_SYNC_FORCPU);
		}

		/* Release I/O context */
		if (cmd->ctx)
			pvscsi_release_cmd_ctx(cmd);

		pvscsi_set_command_status(cmd);
		cmd->flags |= PVSCSI_FLAG_DONE;
		cmd->flags &= ~PVSCSI_FLAG_TRANSPORT;
		membar_producer();

		if (((pkt->pkt_flags & FLAG_NOINTR) == 0) && pkt->pkt_comp)
			(*pkt->pkt_comp)(pkt);
	}
}

static void
pvscsi_wd_thread(pvscsi_softc_t *pvs)
{
	pvscsi_cmd_t	*expired, *c, *cn, **pnext;
	clock_t		now;

	mutex_enter(&pvs->mutex);
	for (;;) {
		expired = NULL;
		pnext = NULL;
		now = ddi_get_lbolt();

		for (c = list_head(&pvs->active_commands); c != NULL; ) {
			cn = list_next(&pvs->active_commands, c);

			/*
			 * Commands with 'FLAG_NOINTR' are watched using their
			 * own timeouts, so we should not touch them.
			 */
			if ((c->pkt->pkt_flags & FLAG_NOINTR) == 0 &&
			    now > c->timeout_lbolt) {
				dev_err(pvs->dip, CE_WARN,
				    "expired command: %p (%ld > %ld)",
				    (void *)c, now, c->timeout_lbolt);

				(void) remove_command_from_active_list(c);

				if (expired == NULL)
					expired = c;

				if (pnext == NULL) {
					pnext = &c->next_cmd;
				} else {
					*pnext = c;
					pnext = &c->next_cmd;
				}
			}
			c = cn;
		}
		mutex_exit(&pvs->mutex);

		/* Now cancel all expired commands */
		if (expired != NULL) {
			struct scsi_address sa = {0};

			/* Build a fake SCSI address */
			sa.a_hba_tran = pvs->tran;

			while (expired != NULL) {
				c = expired->next_cmd;

				sa.a_target = expired->cmd_target;
				sa.a_lun = expired->cmd_lun;

				(void) pvscsi_abort(&sa, CMD2PKT(expired));
				expired = c;
			}
		}

		mutex_enter(&pvs->mutex);
		if ((pvs->flags & PVSCSI_DRIVER_SHUTDOWN) != 0) {
			/* Finish job, keep mutex locked */
			break;
		}
		if (cv_reltimedwait(&pvs->wd_condvar, &pvs->mutex,
		    SEC_TO_TICK(1), TR_CLOCK_TICK) > 0) {
			/* Explicitly woken up, finish job, keep mutex locked */
			break;
		}
	}

	/* Confirm thread termination. We come here only with locked mutex. */
	cv_signal(&pvs->syncvar);
	mutex_exit(&pvs->mutex);
}

static void
pvscsi_irq_worker_fn(pvscsi_worker_state_t *ws)
{
	boolean_t	active = B_TRUE;
	pvscsi_cmd_t	*cmd;
	int		active_cycles = 0;
	boolean_t	stallq_fired;
	pvscsi_softc_t	*pvs = ws->pvs;
	int		rc;

	while (active) {
		/*
		 * Inner cycle is used for firing stalled commands when
		 * there are no commands to complete.
		 */
		while (B_TRUE) {
			mutex_enter(&ws->mtx);
			if (!ws->head_cmd && !(ws->flags &
			    PVSCSI_IRQ_WORKER_SHUTDOWN)) {
				active_cycles = 0;

				/* Don't replay commands if HBA is quiesced */
				if (HBA_IS_QUIESCED(pvs))
					goto wait_for_packet;

				stallq_fired = B_FALSE;

				/*
				 * No processed commands to complete, try to run
				 * one stalled command before going to sleep.
				 */
				mutex_enter(&pvs->stallq_mutex);
				cmd = __extract_command_from_stalled_list(pvs);
				mutex_exit(&pvs->stallq_mutex);

				/*
				 * TODO: Take into account command cancellation
				 * in this moment, i.e. when the command doesn't
				 * belong to any lists.
				 */
				if (cmd) {
					rc = __pvscsi_transport_command(pvs,
					    cmd, B_FALSE, NULL);
					stallq_fired = (rc == TRAN_ACCEPT);

					/* Transport failed, reinsert */
					if (!stallq_fired) {
						add_command_to_stalled_list(pvs,
						    cmd);
					}
				}

				if (stallq_fired) {
					/*
					 * Fired a command from stalled queue.
					 * Drop mutex to allow IRQ handler
					 * assign us more commands to
					 * complete before doing next
					 * iteration.
					 */
					mutex_exit(&ws->mtx);
					continue;
				}
wait_for_packet:
				ws->flags &= ~PVSCSI_IRQ_WORKER_ACTIVE;
				cv_wait(&ws->cv, &ws->mtx);
			}
			/* Have something to process, keep mutex locked */
			break;
		}

		if (ws->flags & PVSCSI_IRQ_WORKER_SHUTDOWN)
			active = B_FALSE;

		if (active_cycles >= 3) {
			/*
			 * See pending stalled commands for a long time,
			 * try to wake up a thread to handle stalled queue.
			 */
			mutex_enter(&pvs->mutex);
			if (!STALLQ_IS_EMPTY(pvs))
				__notify_stallq_thread(pvs);
			mutex_exit(&pvs->mutex);
		}

		cmd = ws->head_cmd;
		if (cmd) {
			ws->head_cmd = ws->tail_cmd = NULL;

			if (active)
				ws->flags |= PVSCSI_IRQ_WORKER_ACTIVE;
			mutex_exit(&ws->mtx);

			COMPLETE_CHAINED_COMMANDS(cmd);
			active_cycles++;
		} else {
			/* Only release mutex, no commands to process */
			mutex_exit(&ws->mtx);
		}
	}

	/* Confirm thread termination */
	mutex_enter(&ws->pvs->mutex);
	cv_signal(&ws->pvs->syncvar);
	mutex_exit(&ws->pvs->mutex);
}

static int
pvscsi_setup_irq_workers(pvscsi_softc_t *pvs)
{
	int	i;

	if (pvs->num_workers > 0) {
		if ((pvs->workers_state = kmem_alloc(pvs->num_workers *
		    sizeof (pvscsi_worker_state_t), KM_SLEEP)) == NULL)
			return (DDI_FAILURE);

		/* Launch worker threads */
		for (i = 0; i < pvs->num_workers; i++) {
			pvscsi_worker_state_t *ws = &pvs->workers_state[i];

			cv_init(&ws->cv, "pvscsi worker cv", CV_DRIVER, NULL);
			mutex_init(&ws->mtx, "pvscsi worker mutex",
			    MUTEX_DRIVER, NULL);
			ws->flags = 0;
			ws->head_cmd = ws->tail_cmd = NULL;
			ws->pvs = pvs;
			ws->id = i;
			ws->thread = thread_create(NULL, 0,
			    pvscsi_irq_worker_fn, ws, 0, &p0, TS_RUN,
			    pvs->worker_thread_priority);
		}
	}

	/* Launch watchdog thread */
	pvs->wd_thread = thread_create(NULL, 0, pvscsi_wd_thread, pvs, 0, &p0,
	    TS_RUN, minclsyspri);

	return (DDI_SUCCESS);
}

static int
cmd_cache_constructor(void *buf, void *cdrarg, int kmflags)
{
	pvscsi_softc_t	*pvs = cdrarg;
	pvscsi_cmd_t	*cmd = (pvscsi_cmd_t *)buf;
	struct scsi_address ap;
	int		cookiec;
	int (*callback)(caddr_t) = (kmflags == KM_SLEEP) ? DDI_DMA_SLEEP :
	    DDI_DMA_DONTWAIT;

	ap.a_hba_tran = pvs->tran;
	ap.a_target = 0;
	ap.a_lun = 0;

	/* Allocate a DMA handle for data transfers */
	if ((ddi_dma_alloc_handle(pvs->dip, &pvs->io_dma_attr, callback,
	    NULL, &cmd->cmd_handle)) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to allocate DMA handle");
		return (-1);
	}

	/* Setup ARQ buffer. */
	if ((cmd->arq_buf = scsi_alloc_consistent_buf(&ap, (struct buf *)NULL,
	    SENSE_BUFFER_SIZE, B_READ, callback, NULL)) == NULL) {
		dev_err(pvs->dip, CE_WARN, "failed to allocate ARQ buffer");
		goto free_handle;
	}

	if (ddi_dma_alloc_handle(pvs->dip, &pvs->msg_dma_attr,
	    callback, NULL, &cmd->arq_handle) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN,
		    "failed to allocate DMA handle for ARQ buffer");
		goto free_arq_buf;
	}

	if (ddi_dma_buf_bind_handle(cmd->arq_handle, cmd->arq_buf,
	    (DDI_DMA_READ | DDI_DMA_CONSISTENT), callback, NULL,
	    &cmd->arq_cookie, (uint_t *)&cookiec) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to bind ARQ buffer");
		goto free_arq_handle;
	}
	ASSERT(cookiec == 1);

	return (0);
free_arq_handle:
	ddi_dma_free_handle(&cmd->arq_handle);
free_arq_buf:
	scsi_free_consistent_buf(cmd->arq_buf);
free_handle:
	ddi_dma_free_handle(&cmd->cmd_handle);

	return (-1);
}

/* ARGSUSED cdrarg */
static void
cmd_cache_destructor(void *buf, void *cdrarg)
{
	pvscsi_cmd_t	*cmd = (pvscsi_cmd_t *)buf;

	if (cmd->cmd_handle) {
		(void) ddi_dma_unbind_handle(cmd->cmd_handle);
		ddi_dma_free_handle(&cmd->cmd_handle);
		cmd->cmd_handle = NULL;
	}

	if (cmd->arq_handle) {
		(void) ddi_dma_unbind_handle(cmd->arq_handle);
		ddi_dma_free_handle(&cmd->arq_handle);
		cmd->arq_handle = NULL;
	}

	if (cmd->arq_buf) {
		scsi_free_consistent_buf(cmd->arq_buf);
		cmd->arq_buf = NULL;
	}
}

static int
__pvscsi_parse_config(pvscsi_softc_t *pvs, dev_info_t *dip)
{

	if ((pvs->num_workers = ddi_prop_get_int(DDI_DEV_T_ANY, dip, 0,
	    "num_irq_workers", 0)) < 0)
		pvs->num_workers = 0;

	pvs->worker_thread_priority = ddi_prop_get_int(DDI_DEV_T_ANY, dip, 0,
	    "irq_worker_priority", 0);
	if (pvs->worker_thread_priority < MINCLSYSPRI ||
	    pvs->worker_thread_priority > MAXCLSYSPRI)
		pvs->worker_thread_priority = MINCLSYSPRI;

	pvs->num_workers = MIN(pvs->num_workers, ncpus_online);

	return (DDI_SUCCESS);
}

static int
pvscsi_attach(dev_info_t *dip, ddi_attach_cmd_t cmd)
{
	int		instance;
	pvscsi_softc_t	*pvs;
	char		buf[32];

	/* Invoke iport attach if this is an iport node */
	if (scsi_hba_iport_unit_address(dip) != NULL)
		return (pvscsi_iport_attach(dip));

	switch (cmd) {
	case DDI_ATTACH:
	case DDI_RESUME:
		break;
	default:
		return (DDI_FAILURE);
	}

	instance = ddi_get_instance(dip);

	/* Allocate softstate information */
	if (ddi_soft_state_zalloc(pvscsi_sstate, instance) != DDI_SUCCESS) {
		cmn_err(CE_WARN,
		    "ddi_soft_state_zalloc() failed for instance %d", instance);
		return (DDI_FAILURE);
	}

	if ((pvs = ddi_get_soft_state(pvscsi_sstate, instance)) == NULL) {
		cmn_err(CE_WARN, "failed to get soft state for instance %d",
		    instance);
		goto fail;
	}

	/* First, try to setup all property-based variables */
	if (__pvscsi_parse_config(pvs, dip) != DDI_SUCCESS) {
		cmn_err(CE_WARN, "failed to parse configuration file");
		goto fail;
	}

	/*
	 * Indicate that we are 'sizeof (scsi_*(9S))' clean, we use
	 * scsi_pkt_size() instead.
	 */
	scsi_size_clean(dip);

	/* Setup HBA instance */
	pvs->instance = instance;
	pvs->dip = dip;
	pvs->msg_dma_attr = pvscsi_msg_dma_attr;
	pvs->ring_dma_attr = pvscsi_ring_dma_attr;
	pvs->io_dma_attr = pvscsi_io_dma_attr;
	pvs->msi_enable = 1; /* TODO Setup as a property */
	pvs->num_luns = PVSCSI_MAXLUNS;
	pvs->worker_threshold = WORKER_THREAD_THRESHOLD;
	mutex_init(&pvs->mutex, "pvscsi instance mutex", MUTEX_DRIVER, NULL);
	mutex_init(&pvs->intr_mutex, "pvscsi instance IRQ mutex", MUTEX_DRIVER,
	    NULL);
	mutex_init(&pvs->rx_mutex, "pvscsi rx ring mutex", MUTEX_DRIVER, NULL);
	mutex_init(&pvs->tx_mutex, "pvscsi tx ring mutex", MUTEX_DRIVER, NULL);
	mutex_init(&pvs->stallq_mutex, "pvscsi instance stallq mutex",
	    MUTEX_DRIVER, NULL);
	list_create(&pvs->cmd_ctx_pool, sizeof (pvscsi_cmd_ctx_t),
	    offsetof(pvscsi_cmd_ctx_t, list));
	list_create(&pvs->devnodes, sizeof (pvscsi_device_t),
	    offsetof(pvscsi_device_t, list));
	list_create(&pvs->active_commands, sizeof (pvscsi_cmd_t),
	    offsetof(pvscsi_cmd_t, active_list));
	list_create(&pvs->stalled_commands, sizeof (pvscsi_cmd_t),
	    offsetof(pvscsi_cmd_t, active_list));
	cv_init(&pvs->syncvar, "pvscsi synchronization cv", CV_DRIVER, NULL);
	cv_init(&pvs->wd_condvar, "pvscsi watchdog cv", CV_DRIVER, NULL);
	cv_init(&pvs->quiescevar, "pvscsi quiesce cv", CV_DRIVER, NULL);

	(void) sprintf(buf, "pvscsi%d_cache", instance);
	pvs->cmd_cache = kmem_cache_create(buf, sizeof (pvscsi_cmd_t), 0,
	    cmd_cache_constructor, cmd_cache_destructor, NULL, (void *)pvs,
	    NULL, 0);
	if (pvs->cmd_cache == NULL) {
		dev_err(pvs->dip, CE_WARN,
		    "failed to create a cache for SCSI commands");
		goto fail;
	}

	if ((pvscsi_setup_io(pvs)) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to setup I/O region");
		goto free_cache;
	}

	pvscsi_hba_reset(pvs);

	if ((pvscsi_allocate_rings(pvs)) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to allocate DMA rings");
		goto free_io;
	}

	if ((pvscsi_setup_rings(pvs)) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to configure DMA rings");
		goto free_rings;
	}

	if (pvscsi_setup_irq(pvs) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to setup IRQs");
		goto clear_rings;
	}

	if (pvscsi_setup_sg(pvs) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to setup S/G");
		goto clear_irq;
	}

	if (pvscsi_setup_irq_workers(pvs) != DDI_SUCCESS) {
		dev_err(pvs->dip, CE_WARN, "failed to setup IRQ workers");
		goto clear_sg;
	}

	if (pvscsi_hba_setup(pvs) != 0) {
		dev_err(pvs->dip, CE_WARN, "failed to setup HBA");
		goto clear_irq_workers;
	}

	if (pvscsi_unmask_irq(pvs) == DDI_SUCCESS) {
		return (DDI_SUCCESS);
	}

clear_irq_workers:
	vmw_shutdown_irq_workers(pvs);
clear_sg:
	pvscsi_free_sg(pvs);
clear_irq:
	pvscsi_free_irq_resources(pvs);
clear_rings:
	pvscsi_hba_reset(pvs);
free_rings:
	pvscsi_free_rings(pvs);
free_io:
	pvscsi_free_io(pvs);
free_cache:
	kmem_cache_destroy(pvs->cmd_cache);
fail:
	ddi_soft_state_free(pvscsi_sstate, instance);

	return (DDI_FAILURE);
}

static int
pvscsi_do_detach(dev_info_t *dip)
{
	int instance;
	pvscsi_softc_t *pvs;

	instance = ddi_get_instance(dip);
	if ((pvs = ddi_get_soft_state(pvscsi_sstate, instance)) == NULL) {
		cmn_err(CE_WARN, "failed to get soft state for instance %d",
		    instance);
		return (DDI_FAILURE);
	}

	pvscsi_hba_reset(pvs);
	pvscsi_free_irq_resources(pvs);

	/* Destroy all unused fields */
	vmw_shutdown_irq_workers(pvs);
	pvscsi_free_sg(pvs);
	pvscsi_free_rings(pvs);
	pvscsi_free_io(pvs);
	kmem_cache_destroy(pvs->cmd_cache);
	mutex_destroy(&pvs->mutex);
	mutex_destroy(&pvs->intr_mutex);
	mutex_destroy(&pvs->rx_mutex);
	cv_destroy(&pvs->syncvar);
	cv_destroy(&pvs->wd_condvar);
	cv_destroy(&pvs->quiescevar);

	ddi_soft_state_free(pvscsi_sstate, instance);

	return (DDI_SUCCESS);
}

static int
pvscsi_detach(dev_info_t *devi, ddi_detach_cmd_t cmd)
{

	switch (cmd) {
	case DDI_DETACH:
		return (pvscsi_do_detach(devi));
	default:
		return (DDI_FAILURE);
	}
}

static int
pvscsi_ioctl(dev_t dev, int cmd, intptr_t data, int mode, cred_t *credp,
    int *rval)
{
	int		ret;

	if (ddi_get_soft_state(pvscsi_sstate, getminor(dev)) == NULL) {
		cmn_err(CE_WARN, "invalid device instance: %d", getminor(dev));
		return (ENXIO);
	}

	/* Try to handle command in a common way */
	if ((ret = scsi_hba_ioctl(dev, cmd, data, mode, credp, rval)) != ENOTTY)
		return (ret);

	cmn_err(CE_WARN, "unsupported IOCTL command: 0x%X", cmd);

	return (ENXIO);
}

/* ARGSUSED dip component level */
static int
pvscsi_power(dev_info_t *dip, int component, int level)
{

	return (DDI_SUCCESS);
}


/*
 * We can't sleep in this function since it gets called when the system is
 * single-threaded at high PIL with preemption disabled.
 */
static int
pvscsi_quiesce(dev_info_t *devi)
{
	scsi_hba_tran_t *tran;
	pvscsi_softc_t	*pvs;

	if ((tran = ddi_get_driver_private(devi)) == NULL)
		return (DDI_SUCCESS);

	if ((pvs = tran->tran_hba_private) == NULL)
		return (DDI_SUCCESS);

	/* Mask all interrupts from device */
	__pvscsi_mask_intr(pvs);

	/* Reset the whole HBA */
	pvscsi_hba_reset(pvs);

	return (DDI_SUCCESS);
}

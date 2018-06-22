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
 * Copyright 2018 Nexenta Systems, Inc.
 */

/*
 * This file contains all routines necessary to interface with SCSA trans.
 */
#include <smartpqi.h>

/*
 * []------------------------------------------------------------------[]
 * | Forward declarations for SCSA trans routines.			|
 * []------------------------------------------------------------------[]
 */
static int pqi_scsi_tgt_init(dev_info_t *hba_dip, dev_info_t *tgt_dip,
    scsi_hba_tran_t *hba_tran, struct scsi_device *sd);
static int pqi_start(struct scsi_address *ap, struct scsi_pkt *pkt);
static int pqi_scsi_reset(struct scsi_address *ap, int level);
static int pqi_scsi_abort(struct scsi_address *ap, struct scsi_pkt *pkt);
static int pqi_scsi_getcap(struct scsi_address *ap, char *cap, int tgtonly);
static int pqi_scsi_setcap(struct scsi_address *ap, char *cap, int value,
    int tgtonly);
static struct scsi_pkt *pqi_init_pkt(struct scsi_address *ap,
    struct scsi_pkt *pkt, struct buf *bp, int cmdlen, int statuslen, int tgtlen,
    int flags,  int (*callback)(), caddr_t arg);
static void pqi_destroy_pkt(struct scsi_address *ap, struct scsi_pkt *pkt);
static void pqi_dmafree(struct scsi_address *ap, struct scsi_pkt *pkt);
static void pqi_sync_pkt(struct scsi_address *ap, struct scsi_pkt *pkt);
static int pqi_reset_notify(struct scsi_address *ap, int flag,
    void (*callback)(caddr_t), caddr_t arg);
static int pqi_quiesce(dev_info_t *dip);
static int pqi_unquiesce(dev_info_t *dip);
static int pqi_bus_config(dev_info_t *pdip, uint_t flag,
    ddi_bus_config_op_t op, void *arg, dev_info_t **childp);

/* ---- Support method declaration ---- */
static int config_one(dev_info_t *pdip, pqi_state_t s,  pqi_device_t,
    dev_info_t **childp);
static void abort_all(struct scsi_address *ap, pqi_state_t s);
static int cmd_ext_alloc(pqi_cmd_t cmd, int kf);
static void cmd_ext_free(pqi_cmd_t cmd);
static boolean_t is_physical_dev(pqi_device_t d);

int
smartpqi_register_hba(pqi_state_t s)
{
	scsi_hba_tran_t		*tran;
	int			flags;

	tran = s->s_tran = scsi_hba_tran_alloc(s->s_dip, SCSI_HBA_CANSLEEP);
	if (tran == NULL)
		return (FALSE);

	tran->tran_hba_private		= s;
	tran->tran_tgt_private		= NULL;

	tran->tran_tgt_init		= pqi_scsi_tgt_init;
	tran->tran_tgt_free		= NULL;
	tran->tran_tgt_probe		= scsi_hba_probe;

	tran->tran_start		= pqi_start;
	tran->tran_reset		= pqi_scsi_reset;
	tran->tran_abort		= pqi_scsi_abort;
	tran->tran_getcap		= pqi_scsi_getcap;
	tran->tran_setcap		= pqi_scsi_setcap;
	tran->tran_bus_config		= pqi_bus_config;

	tran->tran_init_pkt		= pqi_init_pkt;
	tran->tran_destroy_pkt		= pqi_destroy_pkt;
	tran->tran_dmafree		= pqi_dmafree;
	tran->tran_sync_pkt		= pqi_sync_pkt;

	tran->tran_reset_notify		= pqi_reset_notify;
	tran->tran_quiesce		= pqi_quiesce;
	tran->tran_unquiesce		= pqi_unquiesce;
	tran->tran_bus_reset		= NULL;

	tran->tran_add_eventcall	= NULL;
	tran->tran_get_eventcookie	= NULL;
	tran->tran_post_event		= NULL;
	tran->tran_remove_eventcall	= NULL;
	tran->tran_bus_config		= pqi_bus_config;
	tran->tran_interconnect_type	= INTERCONNECT_SAS;

	flags = SCSI_HBA_TRAN_CLONE;
	if (scsi_hba_attach_setup(s->s_dip, &s->s_msg_dma_attr, tran,
	    flags) != DDI_SUCCESS) {
		dev_err(s->s_dip, CE_NOTE, "scsi_hba_attach_setup failed");
		scsi_hba_tran_free(s->s_tran);
		s->s_tran = NULL;
		return (FALSE);
	}
	return (TRUE);
}

void
smartpqi_unregister_hba(pqi_state_t s)
{
	if (s->s_tran == NULL)
		return;
	scsi_hba_tran_free(s->s_tran);
	s->s_tran = NULL;
}

/*
 * tran_tgt_init(9E) - target device instance initialization
 */
/*ARGSUSED*/
static int
pqi_scsi_tgt_init(dev_info_t *hba_dip, dev_info_t *tgt_dip,
    scsi_hba_tran_t *hba_tran, struct scsi_device *sd)
{
	if (sd->sd_address.a_target >= PQI_MAXTGTS) {
		return (DDI_FAILURE);
	} else {
		return (DDI_SUCCESS);
	}
}

/*
 * Notes:
 *      - transport the command to the addressed SCSI target/lun device
 *      - normal operation is to schedule the command to be transported,
 *        and return TRAN_ACCEPT if this is successful.
 *      - if NO_INTR, tran_start must poll device for command completion
 */
/*ARGSUSED*/
static int
pqi_start(struct scsi_address *ap, struct scsi_pkt *pkt)
{
	boolean_t	poll	= ((pkt->pkt_flags & FLAG_NOINTR) != 0);
	int		rc;
	pqi_cmd_t	cmd	= PKT2CMD(pkt);
	pqi_state_t	s	= ap->a_hba_tran->tran_hba_private;
	ksema_t		poll_sema;

	ASSERT3P(cmd->pc_pkt, ==, pkt);
	ASSERT3P(cmd->pc_softc, ==, s);

	if (pqi_is_offline(s))
		return (TRAN_FATAL_ERROR);

	/*
	 * Reinitialize some fields because the packet may have been
	 * resubmitted.
	 */
	pkt->pkt_reason = CMD_CMPLT;
	pkt->pkt_state = 0;
	pkt->pkt_statistics = 0;

	/* ---- Zero status byte ---- */
	*(pkt->pkt_scbp) = 0;

	if ((cmd->pc_flags & PQI_FLAG_DMA_VALID) != 0) {
		ASSERT(cmd->pc_dma_count);
		pkt->pkt_resid = cmd->pc_dma_count;

		/* ---- Sync consistent packets first (only write data) ---- */
		if (((cmd->pc_flags & PQI_FLAG_IO_IOPB) != 0) ||
		    ((cmd->pc_flags & PQI_FLAG_IO_READ) == 0)) {
			(void) ddi_dma_sync(cmd->pc_dmahdl, 0, 0,
			    DDI_DMA_SYNC_FORDEV);
		}
	}

	cmd->pc_target = ap->a_target;

	mutex_enter(&s->s_mutex);
	if (HBA_IS_QUIESCED(s) && !poll) {
		mutex_exit(&s->s_mutex);
		return (TRAN_BUSY);
	}
	mutex_exit(&s->s_mutex);

	if (poll) {
		sema_init(&poll_sema, 0, NULL, SEMA_DRIVER, NULL);
		cmd->pc_poll = &poll_sema;
	}
	pqi_cmd_sm(cmd, PQI_CMD_QUEUED);

	rc = pqi_transport_command(s, cmd);

	if (poll) {
		boolean_t	qnotify;

		if (rc == TRAN_ACCEPT)
			sema_p(&poll_sema);

		sema_destroy(&poll_sema);

		mutex_enter(&s->s_mutex);
		qnotify = HBA_QUIESCED_PENDING(s);
		mutex_exit(&s->s_mutex);

		if (qnotify)
			pqi_quiesced_notify(s);
	}

	return (rc);
}

/*ARGSUSED*/
static int
pqi_scsi_reset(struct scsi_address *ap, int level)
{
	return (FALSE);
}

/*
 * abort handling:
 *
 * Notes:
 *      - if pkt is not NULL, abort just that command
 *      - if pkt is NULL, abort all outstanding commands for target
 */
/*ARGSUSED*/
static int
pqi_scsi_abort(struct scsi_address *ap, struct scsi_pkt *pkt)
{
	boolean_t	qnotify	= B_FALSE;
	pqi_state_t	s	= ADDR2PQI(ap);

	if (pkt != NULL) {
		/* ---- Abort single command ---- */
		pqi_cmd_t	cmd = PKT2CMD(pkt);
		pqi_fail_cmd(cmd);
	} else {
		abort_all(ap, s);
	}
	qnotify = HBA_QUIESCED_PENDING(s);

	if (qnotify)
		pqi_quiesced_notify(s);
	return (1);
}

/*
 * capability handling:
 * (*tran_getcap).  Get the capability named, and return its value.
 */
/*ARGSUSED*/
static int
pqi_scsi_getcap(struct scsi_address *ap, char *cap, int tgtonly)
{
	pqi_state_t s = ap->a_hba_tran->tran_hba_private;

	if (cap == NULL)
		return (-1);
	switch (scsi_hba_lookup_capstr(cap)) {
		case SCSI_CAP_LUN_RESET:
			return ((s->s_flags & PQI_HBA_LUN_RESET_CAP) != 0);
		case SCSI_CAP_ARQ:
			return ((s->s_flags & PQI_HBA_AUTO_REQUEST_SENSE) != 0);
		case SCSI_CAP_UNTAGGED_QING:
			return (1);
		default:
			return (-1);
	}
}

/*
 * (*tran_setcap).  Set the capability named to the value given.
 */
/*ARGSUSED*/
static int
pqi_scsi_setcap(struct scsi_address *ap, char *cap, int value, int tgtonly)
{
	pqi_state_t	s	= ADDR2PQI(ap);
	int		rval	= FALSE;

	if (cap == NULL)
		return (-1);

	switch (scsi_hba_lookup_capstr(cap)) {
		case SCSI_CAP_ARQ:
			if (value)
				s->s_flags |= PQI_HBA_AUTO_REQUEST_SENSE;
			else
				s->s_flags &= ~PQI_HBA_AUTO_REQUEST_SENSE;
			rval = 1;
			break;

		case SCSI_CAP_LUN_RESET:
			if (value)
				s->s_flags |= PQI_HBA_LUN_RESET_CAP;
			else
				s->s_flags &= ~PQI_HBA_LUN_RESET_CAP;
			break;

		default:
			break;
	}

	return (rval);
}

/*ARGSUSED*/
int
pqi_cache_constructor(void *buf, void *un, int flags)
{
	pqi_cmd_t		c	= (pqi_cmd_t)buf;
	pqi_state_t		s	= un;
	int			(*callback)(caddr_t);

	c->pc_softc = s;
	callback = (flags == KM_SLEEP) ? DDI_DMA_SLEEP : DDI_DMA_DONTWAIT;

	/* ---- Allocate a DMA handle for data transfers ---- */
	if (ddi_dma_alloc_handle(s->s_dip, &s->s_msg_dma_attr, callback,
	    NULL, &c->pc_dmahdl) != DDI_SUCCESS) {
		dev_err(s->s_dip, CE_WARN, "Failed to alloc dma handle");
		return (-1);
	}
	pqi_cmd_sm(c, PQI_CMD_CONSTRUCT);

	return (0);
}

/*ARGSUSED*/
void
pqi_cache_destructor(void *buf, void *un)
{
	pqi_cmd_t	cmd = buf;
	if (cmd->pc_dmahdl != NULL) {
		(void) ddi_dma_unbind_handle(cmd->pc_dmahdl);
		ddi_dma_free_handle(&cmd->pc_dmahdl);
		cmd->pc_dmahdl = NULL;
	}
}

/*
 * tran_init_pkt(9E) - allocate scsi_pkt(9S) for command
 *
 * One of three possibilities:
 *      - allocate scsi_pkt
 *      - allocate scsi_pkt and DMA resources
 *      - allocate DMA resources to an already-allocated pkt
 */
/*ARGSUSED*/
static struct scsi_pkt *
pqi_init_pkt(struct scsi_address *ap, struct scsi_pkt *pkt,
    struct buf *bp, int cmdlen, int statuslen, int tgtlen, int flags,
    int (*callback)(), caddr_t arg)
{
	pqi_cmd_t	cmd;
	pqi_state_t	s;
	int		kf = (callback == SLEEP_FUNC) ? KM_SLEEP : KM_NOSLEEP;
	boolean_t	is_new = B_FALSE;
	int		rc,
			i;
	pqi_device_t	devp;

	s = ap->a_hba_tran->tran_hba_private;

	if (pkt == NULL) {
		ddi_dma_handle_t	saved_dmahdl;
		pqi_cmd_state_t		saved_state;

		if ((devp = pqi_find_target_dev(s, ap->a_target)) == NULL)
			return (NULL);
		if ((cmd = kmem_cache_alloc(s->s_cmd_cache, kf)) == NULL)
			return (NULL);

		is_new = B_TRUE;
		saved_dmahdl = cmd->pc_dmahdl;
		saved_state = cmd->pc_cmd_state;

		(void) memset(cmd, 0, sizeof (*cmd));

		cmd->pc_dmahdl = saved_dmahdl;
		cmd->pc_cmd_state = saved_state;

		cmd->pc_device = devp;
		cmd->pc_pkt = &cmd->pc_cached_pkt;
		cmd->pc_softc = s;
		cmd->pc_tgtlen = tgtlen;
		cmd->pc_statuslen = statuslen;
		cmd->pc_cmdlen = cmdlen;
		cmd->pc_dma_count = 0;

		pkt = cmd->pc_pkt;
		pkt->pkt_ha_private = cmd;
		pkt->pkt_address = *ap;
		pkt->pkt_scbp = (uint8_t *)&cmd->pc_cmd_scb;
		pkt->pkt_cdbp = cmd->pc_cdb;
		pkt->pkt_private = (opaque_t)cmd->pc_tgt_priv;

		if (cmdlen > sizeof (cmd->pc_cdb) ||
		    statuslen > sizeof (cmd->pc_cmd_scb) ||
		    tgtlen > sizeof (cmd->pc_tgt_priv)) {
			if (cmd_ext_alloc(cmd, kf) != DDI_SUCCESS) {
				dev_err(s->s_dip, CE_WARN,
				    "extent allocation failed");
				goto out;
			}
		}
	} else {
		cmd = PKT2CMD(pkt);
		cmd->pc_flags &= PQI_FLAGS_PERSISTENT;
	}
	pqi_cmd_sm(cmd, PQI_CMD_INIT);

	/* ---- Handle partial DMA transfer ---- */
	if (cmd->pc_nwin > 0) {
		if (++cmd->pc_winidx >= cmd->pc_nwin)
			return (NULL);
		if (ddi_dma_getwin(cmd->pc_dmahdl, cmd->pc_winidx,
		    &cmd->pc_dma_offset, &cmd->pc_dma_len, &cmd->pc_dmac,
		    &cmd->pc_dmaccount) == DDI_FAILURE)
			return (NULL);
		goto handle_dma_cookies;
	}

	/* ---- Setup data buffer ---- */
	if (bp != NULL && bp->b_bcount > 0 &&
	    (cmd->pc_flags & PQI_FLAG_DMA_VALID) == 0) {
		int	dma_flags;

		ASSERT(cmd->pc_dmahdl != NULL);

		if ((bp->b_flags & B_READ) != 0) {
			cmd->pc_flags |= PQI_FLAG_IO_READ;
			dma_flags = DDI_DMA_READ;
		} else {
			cmd->pc_flags &= ~PQI_FLAG_IO_READ;
			dma_flags = DDI_DMA_WRITE;
		}
		if ((flags & PKT_CONSISTENT) != 0) {
			cmd->pc_flags |= PQI_FLAG_IO_IOPB;
			dma_flags |= DDI_DMA_CONSISTENT;
		}
		if ((flags & PKT_DMA_PARTIAL) != 0) {
			dma_flags |= DDI_DMA_PARTIAL;
		}
		rc = ddi_dma_buf_bind_handle(cmd->pc_dmahdl, bp,
		    dma_flags, callback, arg, &cmd->pc_dmac,
		    &cmd->pc_dmaccount);

		if (rc == DDI_DMA_PARTIAL_MAP) {
			(void) ddi_dma_numwin(cmd->pc_dmahdl, &cmd->pc_nwin);
			cmd->pc_winidx = 0;
			(void) ddi_dma_getwin(cmd->pc_dmahdl, cmd->pc_winidx,
			    &cmd->pc_dma_offset, &cmd->pc_dma_len,
			    &cmd->pc_dmac, &cmd->pc_dmaccount);
		} else if (rc != 0 && rc != DDI_DMA_MAPPED) {
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
			goto out;
		}

handle_dma_cookies:
		ASSERT(cmd->pc_dmaccount > 0);
		if (cmd->pc_dmaccount >
		    (sizeof (cmd->pc_cached_cookies) /
		    sizeof (ddi_dma_cookie_t))) {
			dev_err(s->s_dip, CE_WARN,
			    "invalid cookie count: %d", cmd->pc_dmaccount);
			    goto out;
		}
		if (cmd->pc_dmaccount >
		    (s->s_sg_chain_buf_length / sizeof (pqi_sg_entry_t))) {
			dev_err(s->s_dip, CE_WARN,
			    "Cookie(0x%x) verses SG(0x%lx) mismatch",
			    cmd->pc_dmaccount,
			    (unsigned long int)s->s_sg_chain_buf_length /
			    sizeof (pqi_sg_entry_t));
			goto out;
		}

		cmd->pc_flags |= PQI_FLAG_DMA_VALID;
		cmd->pc_dma_count = cmd->pc_dmac.dmac_size;
		cmd->pc_cached_cookies[0] = cmd->pc_dmac;

		for (i = 1; i < cmd->pc_dmaccount; i++) {
			ddi_dma_nextcookie(cmd->pc_dmahdl, &cmd->pc_dmac);
			cmd->pc_cached_cookies[i] = cmd->pc_dmac;
			cmd->pc_dma_count += cmd->pc_dmac.dmac_size;
		}

		pkt->pkt_resid = bp->b_bcount - cmd->pc_dma_count;
	}

	return (pkt);
out:
	if (is_new == B_TRUE)
		pqi_destroy_pkt(ap, pkt);
	return (NULL);
}

/*
 * tran_destroy_pkt(9E) - scsi_pkt(9s) deallocation
 *
 * Notes:
 *      - also frees DMA resources if allocated
 *      - implicit DMA synchonization
 */
/*ARGSUSED*/
static void
pqi_destroy_pkt(struct scsi_address *ap, struct scsi_pkt *pkt)
{
	pqi_cmd_t	c = PKT2CMD(pkt);
	pqi_state_t	s = ADDR2PQI(ap);

	if ((c->pc_flags & PQI_FLAG_DMA_VALID) != 0) {
		c->pc_flags &= ~PQI_FLAG_DMA_VALID;
		(void) ddi_dma_unbind_handle(c->pc_dmahdl);
	}
	cmd_ext_free(c);
	pqi_cmd_sm(c, PQI_CMD_DESTRUCT);

	kmem_cache_free(s->s_cmd_cache, c);
}

/*
 * tran_dmafree(9E) - deallocate DMA resources allocated for command
 */
/*ARGSUSED*/
static void
pqi_dmafree(struct scsi_address *ap, struct scsi_pkt *pkt)
{
	pqi_cmd_t	cmd = PKT2CMD(pkt);

	if (cmd->pc_flags & PQI_FLAG_DMA_VALID) {
		cmd->pc_flags &= ~PQI_FLAG_DMA_VALID;
		(void) ddi_dma_unbind_handle(cmd->pc_dmahdl);
	}
}

/*
 * tran_sync_pkt(9E) - explicit DMA synchronization
 */
/*ARGSUSED*/
static void
pqi_sync_pkt(struct scsi_address *ap, struct scsi_pkt *pkt)
{
	pqi_cmd_t	cmd = PKT2CMD(pkt);

	if (cmd->pc_dmahdl != NULL) {
		(void) ddi_dma_sync(cmd->pc_dmahdl, 0, 0,
		    (cmd->pc_flags & PQI_FLAG_IO_READ) ? DDI_DMA_SYNC_FORCPU :
		    DDI_DMA_SYNC_FORDEV);
	}
}

static int
pqi_reset_notify(struct scsi_address *ap, int flag,
    void (*callback)(caddr_t), caddr_t arg)
{
	pqi_state_t	s = ADDR2PQI(ap);

	return (scsi_hba_reset_notify_setup(ap, flag, callback, arg,
	    &s->s_mutex, &s->s_reset_notify_listf));
}

/*
 * Device / Hotplug control
 */
/*ARGSUSED*/
static int
pqi_quiesce(dev_info_t *dip)
{
	pqi_state_t	s;
	scsi_hba_tran_t	*tran;

	if ((tran = ddi_get_driver_private(dip)) == NULL ||
	    (s = TRAN2PQI(tran)) == NULL)
		return (-1);

	mutex_enter(&s->s_mutex);
	if (!HBA_IS_QUIESCED(s))
		s->s_flags |= PQI_HBA_QUIESCED;

	if (s->s_cmd_queue_len != 0) {
		/* ---- Outstanding commands present, wait ---- */
		s->s_flags |= PQI_HBA_QUIESCED_PENDING;
		cv_wait(&s->s_quiescedvar, &s->s_mutex);
		ASSERT0(s->s_cmd_queue_len);
	}
	mutex_exit(&s->s_mutex);

	return (0);
}

/*ARGSUSED*/
static int
pqi_unquiesce(dev_info_t *dip)
{
	pqi_state_t	s;
	scsi_hba_tran_t	*tran;

	if ((tran = ddi_get_driver_private(dip)) == NULL ||
	    (s = TRAN2PQI(tran)) == NULL)
		return (-1);

	mutex_enter(&s->s_mutex);
	if (!HBA_IS_QUIESCED(s)) {
		mutex_exit(&s->s_mutex);
		return (0);
	}
	ASSERT0(s->s_cmd_queue_len);
	s->s_flags &= ~PQI_HBA_QUIESCED;
	mutex_exit(&s->s_mutex);

	return (0);
}

/*ARGSUSED*/
static int
pqi_bus_config(dev_info_t *pdip, uint_t flag,
    ddi_bus_config_op_t op, void *arg, dev_info_t **childp)
{
	scsi_hba_tran_t	*tran;
	pqi_state_t	s;
	int		circ,
			ret = NDI_FAILURE;
	long		target;
	char		*p;
	pqi_device_t	d;

	tran = ddi_get_driver_private(pdip);
	s = tran->tran_hba_private;
	if (pqi_is_offline(s))
		return (NDI_FAILURE);

	ndi_devi_enter(pdip, &circ);
	switch (op) {
		case BUS_CONFIG_ONE:
			if ((p = strrchr((char *)arg, '@')) != NULL &&
			    ddi_strtol(p + 1, NULL, 16, &target) == 0) {
				d = pqi_find_target_dev(s, target);
				if (d != NULL) {
					ret = config_one(pdip, s, d, childp);
				}
			}
			break;

		case BUS_CONFIG_DRIVER:
		case BUS_CONFIG_ALL:
			ret = pqi_config_all(pdip, s);
			break;
		default:
			ret = NDI_FAILURE;
	}
	if (ret == NDI_SUCCESS)
		ret = ndi_busop_bus_config(pdip, flag, op, arg, childp, 0);
	ndi_devi_exit(pdip, circ);

	return (ret);
}

pqi_device_t
pqi_find_target_dev(pqi_state_t s, int target)
{
	pqi_device_t d;

	/*
	 * Should switch to indexed array of devices that can grow
	 * as needed.
	 */
	for (d = list_head(&s->s_devnodes); d != NULL;
	    d = list_next(&s->s_devnodes, d)) {
		if (d->pd_target == target)
			break;
	}
	return (d);
}

int
pqi_config_all(dev_info_t *pdip, pqi_state_t s)
{
	pqi_device_t d;

	for (d = list_head(&s->s_devnodes); d != NULL;
	    d = list_next(&s->s_devnodes, d)) {
		(void) config_one(pdip, s, d, NULL);
	}

	return (NDI_SUCCESS);
}

void
pqi_quiesced_notify(pqi_state_t s)
{
	mutex_enter(&s->s_mutex);
	if (s->s_cmd_queue_len == 0 &&
	    (s->s_flags & PQI_HBA_QUIESCED_PENDING) != 0) {
		s->s_flags &= ~PQI_HBA_QUIESCED_PENDING;
		cv_broadcast(&s->s_quiescedvar);
	}
	mutex_exit(&s->s_mutex);
}

/*
 * []------------------------------------------------------------------[]
 * | Support routines used only by the trans_xxx routines		|
 * []------------------------------------------------------------------[]
 */

/*ARGSUSED*/
static void
abort_all(struct scsi_address *ap, pqi_state_t s)
{
	pqi_device_t	devp;

	if ((devp = pqi_find_target_dev(s, ap->a_target)) == NULL)
		return;

	pqi_fail_drive_cmds(devp);
}

static int
config_one(dev_info_t *pdip, pqi_state_t s, pqi_device_t d,
    dev_info_t **childp)
{
	char			**compatible	= NULL,
				*nodename	= NULL;
	dev_info_t		*dip;
	int			ncompatible	= 0;
	struct scsi_inquiry	inq;

	/* ---- For now ignore logical devices ---- */
	if (is_physical_dev(d) == B_FALSE)
		return (NDI_FAILURE);

	/* ---- Inquiry target ---- */
	if (pqi_scsi_inquiry(s, d, 0, &inq, sizeof (inq)) == B_FALSE) {
		if (d->pd_pdip != NULL) {
			/* ---- Target disappeared, remove references ---- */
			if (i_ddi_devi_attached(d->pd_pdip)) {
				char *devname;
				devname = kmem_zalloc(MAXPATHLEN, KM_SLEEP);
				/* ---- Get full name ---- */
				(void) ddi_deviname(d->pd_pdip, devname);
				/* ---- Clean cache and name ---- */
				(void) devfs_clean(d->pd_parent, devname + 1,
				    DV_CLEAN_FORCE);
				kmem_free(devname, MAXPATHLEN);
			}

			d->pd_pdip = NULL;
		}
		return (NDI_FAILURE);
	} else if (d->pd_pdip != NULL) {
		if (childp != NULL)
			*childp = d->pd_pdip;
		return (NDI_SUCCESS);
	}

	/* ---- At this point we have a new device not in our list ---- */
	scsi_hba_nodename_compatible_get(&inq, NULL, inq.inq_dtype, NULL,
	    &nodename, &compatible, &ncompatible);
	if (nodename == NULL)
		return (NDI_FAILURE);

	if (ndi_devi_alloc(pdip, nodename, DEVI_SID_NODEID, &dip) !=
	    NDI_SUCCESS) {
		dev_err(s->s_dip, CE_WARN, "failed to alloc device instance");
		goto free_nodename;
	}

	/*
	 * Need to think about device replacement and should the driver
	 * attempt to reuse vacated LUNs?
	 */
	d->pd_target = s->s_next_lun++;
	d->pd_pdip = dip;
	d->pd_parent = pdip;

	if (ndi_prop_update_string(DDI_DEV_T_NONE, dip, "device-tpye",
		"scsi") != DDI_PROP_SUCCESS ||
	    ndi_prop_update_int(DDI_DEV_T_NONE, dip,
		"target", d->pd_target) != DDI_PROP_SUCCESS ||
	    ndi_prop_update_int(DDI_DEV_T_NONE, dip,
		"lun", 0) != DDI_PROP_SUCCESS ||
	    ndi_prop_update_int(DDI_DEV_T_NONE, dip,
		"pm_capable", 1) != DDI_PROP_SUCCESS ||
	    ndi_prop_update_string_array(DDI_DEV_T_NONE, dip,
		"compatible", compatible, ncompatible) != DDI_PROP_SUCCESS) {

		dev_err(s->s_dip, CE_WARN,
		    "failed to update props for target %d", d->pd_target);
		goto free_devi;
	}

	if (ndi_devi_online(dip, NDI_ONLINE_ATTACH) != NDI_SUCCESS) {
		dev_err(s->s_dip, CE_WARN, "Failed to online target %d",
		    d->pd_target);
		goto free_devi;
	}

	if (childp != NULL)
		*childp = dip;

	scsi_hba_nodename_compatible_free(nodename, compatible);

	return (NDI_SUCCESS);

free_devi:
	ndi_prop_remove_all(dip);
	(void) ndi_devi_free(dip);
	d->pd_pdip = NULL;
free_nodename:
	scsi_hba_nodename_compatible_free(nodename, compatible);

	return (NDI_FAILURE);
}

static void
cmd_ext_free(pqi_cmd_t cmd)
{
	struct scsi_pkt *pkt = CMD2PKT(cmd);

	if ((cmd->pc_flags & PQI_FLAG_CDB_EXT) != 0) {
		kmem_free(pkt->pkt_cdbp, cmd->pc_cmdlen);
		cmd->pc_flags &= ~PQI_FLAG_CDB_EXT;
	}
	if ((cmd->pc_flags & PQI_FLAG_SCB_EXT) != 0) {
		kmem_free(pkt->pkt_scbp, cmd->pc_statuslen);
		cmd->pc_flags &= ~PQI_FLAG_SCB_EXT;
	}
	if ((cmd->pc_flags & PQI_FLAG_PRIV_EXT) != 0) {
		kmem_free(pkt->pkt_private, cmd->pc_tgtlen);
		cmd->pc_flags &= ~PQI_FLAG_PRIV_EXT;
	}
}

static int
cmd_ext_alloc(pqi_cmd_t cmd, int kf)
{
	struct scsi_pkt		*pkt = CMD2PKT(cmd);
	void			*buf;

	if (cmd->pc_cmdlen > sizeof (cmd->pc_cdb)) {
		if ((buf = kmem_zalloc(cmd->pc_cmdlen, kf)) == NULL)
			return (DDI_FAILURE);
		pkt->pkt_cdbp = buf;
		cmd->pc_flags |= PQI_FLAG_CDB_EXT;
	}

	if (cmd->pc_statuslen > sizeof (cmd->pc_cmd_scb)) {
		if ((buf = kmem_zalloc(cmd->pc_statuslen, kf)) == NULL)
			goto out;
		pkt->pkt_scbp = buf;
		cmd->pc_flags |= PQI_FLAG_SCB_EXT;
		cmd->pc_cmd_rqslen = (cmd->pc_statuslen -
		    sizeof (cmd->pc_cmd_scb));
	}

	if (cmd->pc_tgtlen > sizeof (cmd->pc_tgt_priv)) {
		if ((buf = kmem_zalloc(cmd->pc_tgtlen, kf)) == NULL)
			goto out;
		pkt->pkt_private = buf;
		cmd->pc_flags |= PQI_FLAG_PRIV_EXT;
	}

	return (DDI_SUCCESS);

out:
	cmd_ext_free(cmd);

	return (DDI_FAILURE);
}

static boolean_t
is_physical_dev(pqi_device_t d)
{
	return (d->pd_phys_dev ? B_TRUE : B_FALSE);
}

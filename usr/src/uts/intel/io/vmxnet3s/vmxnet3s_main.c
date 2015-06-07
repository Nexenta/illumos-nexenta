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

#include <sys/kmem.h>
#include <sys/mac_provider.h>
#include <sys/note.h>
#include <sys/vlan.h>

#include <vm/seg_kmem.h>

#include "vmxnet3s.h"

static ddi_dma_attr_t vmxnet3s_dma_attrs_tx = {
	DMA_ATTR_V0,		/* dma_attr_version */
	0x0000000000000000ull,	/* dma_attr_addr_lo */
	0xFFFFFFFFFFFFFFFFull,	/* dma_attr_addr_hi */
	0xFFFFFFFFFFFFFFFFull,	/* dma_attr_count_max */
	0x0000000000000001ull,	/* dma_attr_align */
	0x0000000000000001ull,	/* dma_attr_burstsizes */
	0x00000001,		/* dma_attr_minxfer */
	0x000000000000FFFFull,	/* dma_attr_maxxfer */
	0xFFFFFFFFFFFFFFFFull,	/* dma_attr_seg */
	32,			/* dma_attr_sgllen */
	0x00000001,		/* dma_attr_granular */
	0			/* dma_attr_flags */
};

/*
 * Fetch the statistics of a vmxnet3s device.
 */
static int
vmxnet3s_m_getstat(void *data, uint_t stat, uint64_t *val)
{
	vmxnet3s_softc_t *dp = data;
	upt1_txstats_t	*txstats;
	upt1_rxstats_t	*rxstats;

	if (!dp->enabled)
		return (DDI_FAILURE);

	txstats = &VMXNET3_TQDESC(dp)->stats;
	rxstats = &VMXNET3_RQDESC(dp)->stats;

	/* Touch the related register */
	switch (stat) {
	case MAC_STAT_MULTIRCV:
	case MAC_STAT_BRDCSTRCV:
	case MAC_STAT_MULTIXMT:
	case MAC_STAT_BRDCSTXMT:
	case MAC_STAT_NORCVBUF:
	case MAC_STAT_IERRORS:
	case MAC_STAT_NOXMTBUF:
	case MAC_STAT_OERRORS:
	case MAC_STAT_RBYTES:
	case MAC_STAT_IPACKETS:
	case MAC_STAT_OBYTES:
	case MAC_STAT_OPACKETS:
		VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_CMD, VMXNET3_CMD_GET_STATS);
		break;
	case MAC_STAT_IFSPEED:
	case MAC_STAT_COLLISIONS:
	case ETHER_STAT_LINK_DUPLEX:
		/* nothing */
		break;
	default:
		return (DDI_FAILURE);
	}

	/* Fetch the corresponding stat */
	switch (stat) {
	case MAC_STAT_IFSPEED:
		*val = dp->linkspeed;
		break;
	case MAC_STAT_MULTIRCV:
		*val = rxstats->mcastp;
		break;
	case MAC_STAT_BRDCSTRCV:
		*val = rxstats->bcastp;
		break;
	case MAC_STAT_MULTIXMT:
		*val = txstats->mcastp;
		break;
	case MAC_STAT_BRDCSTXMT:
		*val = txstats->bcastp;
		break;
	case MAC_STAT_NORCVBUF:
		*val = rxstats->oobp;
		break;
	case MAC_STAT_IERRORS:
		*val = rxstats->errp;
		break;
	case MAC_STAT_NOXMTBUF:
		*val = txstats->discardp;
		break;
	case MAC_STAT_OERRORS:
		*val = txstats->errp;
		break;
	case MAC_STAT_COLLISIONS:
		*val = 0;
		break;
	case MAC_STAT_RBYTES:
		*val = rxstats->lrobytes +
		    rxstats->ucastb +
		    rxstats->mcastb +
		    rxstats->bcastb;
		break;
	case MAC_STAT_IPACKETS:
		*val = rxstats->lropkts +
		    rxstats->ucastp +
		    rxstats->mcastp +
		    rxstats->bcastp;
		break;
	case MAC_STAT_OBYTES:
		*val = txstats->tsob +
		    txstats->ucastb +
		    txstats->mcastb +
		    txstats->bcastb;
		break;
	case MAC_STAT_OPACKETS:
		*val = txstats->tsop +
		    txstats->ucastp +
		    txstats->mcastp +
		    txstats->bcastp;
		break;
	case ETHER_STAT_LINK_DUPLEX:
		*val = LINK_DUPLEX_FULL;
		break;
	default:
		ASSERT(B_FALSE);
	}

	return (DDI_SUCCESS);
}

/*
 * Allocate and initialize the shared data structures
 * of a vmxnet3s device.
 */
static int
vmxnet3s_prepare_drivershared(vmxnet3s_softc_t *dp)
{
	vmxnet3s_drvshared_t *ds;
	size_t		allocsz = sizeof (vmxnet3s_drvshared_t);

	if (vmxnet3s_alloc1(dp, &dp->shareddata, allocsz,
	    B_TRUE) != DDI_SUCCESS)
		return (DDI_FAILURE);

	ds = VMXNET3_DS(dp);
	(void) memset(ds, 0, allocsz);

	allocsz = sizeof (vmxnet3s_txqdesc_t) + sizeof (vmxnet3s_rxqdesc_t);
	if (vmxnet3s_alloc128(dp, &dp->qdescs, allocsz,
	    B_TRUE) != DDI_SUCCESS) {
		vmxnet3s_free(&dp->shareddata);
		return (DDI_FAILURE);
	}
	(void) memset(dp->qdescs.buf, 0, allocsz);

	ds->magic = VMXNET3_REV1_MAGIC;

	/* Take care of most of devread */
	ds->devread.misc.drvinfo.version = BUILD_NUMBER_NUMERIC;
	if (sizeof (void *) == 4)
		ds->devread.misc.drvinfo.gos.gosbits = VMXNET3_GOS_BITS_32;
	else if (sizeof (void *) == 8)
		ds->devread.misc.drvinfo.gos.gosbits = VMXNET3_GOS_BITS_64;
	else
		ASSERT(B_FALSE);

	ds->devread.misc.drvinfo.gos.gostype = VMXNET3_GOS_TYPE_SOLARIS;
	ds->devread.misc.drvinfo.gos.gosver = 10;
	ds->devread.misc.drvinfo.vmxnet3srevspt = 1;
	ds->devread.misc.drvinfo.uptverspt = 1;

	ds->devread.misc.uptfeatures = UPT1_F_RXCSUM;
	ds->devread.misc.mtu = dp->cur_mtu;

	/* XXX ds->devread.misc.maxnumrxsg */
	ds->devread.misc.numtxq = 1;
	ds->devread.misc.numrxq = 1;
	ds->devread.misc.queuedescpa = dp->qdescs.bufpa;
	ds->devread.misc.queuedesclen = allocsz;

	/* txq and rxq information is filled in other functions */

	ds->devread.intrconf.automask = (dp->intrmaskmode == VMXNET3_IMM_AUTO);
	ds->devread.intrconf.numintrs = 1;
	/* XXX ds->intr.modlevels */
	ds->devread.intrconf.eventintridx = 0;

	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_DSAL,
	    VMXNET3_ADDR_LO(dp->shareddata.bufpa));
	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_DSAH,
	    VMXNET3_ADDR_HI(dp->shareddata.bufpa));

	return (DDI_SUCCESS);
}

/*
 * Destroy the shared data structures of a vmxnet3s device.
 */
static void
vmxnet3s_destroy_drivershared(vmxnet3s_softc_t *dp)
{

	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_DSAL, 0);
	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_DSAH, 0);

	vmxnet3s_free(&dp->qdescs);
	vmxnet3s_free(&dp->shareddata);
}

/*
 * Allocate and initialize the command ring of a queue.
 */
static int
vmxnet3s_alloc_cmdring(vmxnet3s_softc_t *dp, vmxnet3s_cmdring_t *cmdring)
{
	size_t	ringsize = cmdring->size * sizeof (vmxnet3s_txdesc_t);

	if (vmxnet3s_alloc512(dp, &cmdring->dma, ringsize,
	    B_TRUE) != DDI_SUCCESS)
		return (DDI_FAILURE);

	(void) memset(cmdring->dma.buf, 0, ringsize);
	cmdring->avail = cmdring->size;
	cmdring->next2fill = 0;
	cmdring->gen = VMXNET3_INIT_GEN;

	return (DDI_SUCCESS);
}

/*
 * Allocate and initialize the completion ring of a queue.
 */
static int
vmxnet3s_alloc_compring(vmxnet3s_softc_t *dp, vmxnet3s_compring_t *compring)
{
	size_t	ringsize = compring->size * sizeof (vmxnet3s_txcompdesc_t);

	if (vmxnet3s_alloc512(dp, &compring->dma, ringsize,
	    B_TRUE) != DDI_SUCCESS)
		return (DDI_FAILURE);

	(void) memset(compring->dma.buf, 0, ringsize);
	compring->next2comp = 0;
	compring->gen = VMXNET3_INIT_GEN;

	return (DDI_SUCCESS);
}

void
vmxnet3s_txcache_release(vmxnet3s_softc_t *dp)
{
	int		i;
	int		rc;
	vmxnet3s_txcache_t *cache = &dp->txcache;

	/* Unmap pages */
	hat_unload(kas.a_hat, cache->window, ptob(cache->num_pages),
	    HAT_UNLOAD_UNLOCK);
	vmem_free(heap_arena, cache->window, ptob(cache->num_pages));

	/* Free pages */
	for (i = 0; i < cache->num_pages; i++) {
		rc = page_tryupgrade(cache->pages[i]);
		if (!rc) {
			page_unlock(cache->pages[i]);
			while (!page_lock(cache->pages[i], SE_EXCL, NULL,
			    P_RECLAIM))
				;
		}
		page_free(cache->pages[i], 0);
	}
	page_unresv(cache->num_pages);

	kmem_free(cache->pages, cache->num_pages * sizeof (page_t *));
	kmem_free(cache->page_maps, cache->num_pages * sizeof (page_t *));
	kmem_free(cache->nodes,
	    cache->num_nodes * sizeof (vmxnet3s_txcache_node_t));
}

int
vmxnet3s_txcache_init(vmxnet3s_softc_t *dp, vmxnet3s_txq_t *txq)
{
	int		i;
	int		ndescrs;
	int		node;
	page_t		*page;
	struct seg	kseg;
	vmxnet3s_txcache_t *cache = &dp->txcache;
	dev_info_t	*dip = dp->dip;

	cache->num_pages = ((txq->cmdring.size * VMXNET3_HDR_COPY_SIZE) +
	    (PAGESIZE - 1)) / PAGESIZE;

	/* Allocate pages */
	if (!page_resv(cache->num_pages, KM_SLEEP)) {
		dev_err(dip, CE_WARN, "failed to reserve %d pages",
		    cache->num_pages);
		goto out;
	}

	if (!page_create_wait(cache->num_pages, 0)) {
		dev_err(dip, CE_WARN, "failed to create %d pages",
		    cache->num_pages);
		goto unresv_pages;
	}

	cache->pages = kmem_zalloc(cache->num_pages * sizeof (page_t *),
	    KM_SLEEP);

	cache->page_maps = kmem_zalloc(cache->num_pages * sizeof (page_t *),
	    KM_SLEEP);

	kseg.s_as = &kas;
	for (i = 0; i < cache->num_pages; i++) {
		page = page_get_freelist(&kvp, 0, &kseg, (caddr_t)(i*PAGESIZE),
		    PAGESIZE, 0, NULL);
		if (page == NULL) {
			page = page_get_cachelist(&kvp, 0, &kseg,
			    (caddr_t)(i * PAGESIZE), 0, NULL);
			if (page == NULL)
				goto free_pages;
			if (!PP_ISAGED(page))
				page_hashout(page, NULL);
		}
		PP_CLRFREE(page);
		PP_CLRAGED(page);
		cache->pages[i] = page;
	}

	for (i = 0; i < cache->num_pages; i++)
		page_downgrade(cache->pages[i]);

	/* Allocate virtual address range for mapping pages */
	cache->window = vmem_alloc(heap_arena, ptob(cache->num_pages),
	    VM_SLEEP);
	ASSERT(cache->window);

	cache->num_nodes = txq->cmdring.size;

	/* Map pages */
	for (i = 0; i < cache->num_pages; i++) {
		cache->page_maps[i] = cache->window + ptob(i);
		hat_devload(kas.a_hat, cache->page_maps[i], ptob(1),
		    cache->pages[i]->p_pagenum,
		    PROT_READ | PROT_WRITE | HAT_STRICTORDER,
		    HAT_LOAD_LOCK);
	}

	/* Now setup cache items */
	cache->nodes = kmem_zalloc(txq->cmdring.size *
	    sizeof (vmxnet3s_txcache_node_t), KM_SLEEP);

	ndescrs = txq->cmdring.size;
	node = 0;
	for (i = 0; i < cache->num_pages; i++) {
		caddr_t		va;
		int		j;
		int		lim;
		uint64_t	pa;

		lim = (ndescrs <= VMXNET3_TX_CACHE_ITEMS_PER_PAGE) ? ndescrs :
		    VMXNET3_TX_CACHE_ITEMS_PER_PAGE;
		va = cache->page_maps[i];
		pa = cache->pages[i]->p_pagenum << PAGESHIFT;

		for (j = 0; j < lim; j++) {
			cache->nodes[node].pa = pa;
			cache->nodes[node].va = va;

			pa += VMXNET3_HDR_COPY_SIZE;
			va += VMXNET3_HDR_COPY_SIZE;
			node++;
		}
		ndescrs -= lim;
	}
	return (DDI_SUCCESS);

free_pages:
	page_create_putback(cache->num_pages - i);
	while (--i >= 0) {
		if (!page_tryupgrade(cache->pages[i])) {
			page_unlock(cache->pages[i]);
			while (!page_lock(cache->pages[i], SE_EXCL, NULL,
			    P_RECLAIM))
				;
		}
		page_free(cache->pages[i], 0);
	}
	kmem_free(cache->pages, cache->num_pages * PAGESIZE);
unresv_pages:
	page_unresv(cache->num_pages);
out:
	cache->num_pages = cache->num_nodes = 0;

	return (DDI_FAILURE);
}


/*
 * Initialize the tx queue of a vmxnet3s device.
 */
static int
vmxnet3s_prepare_txq(vmxnet3s_softc_t *dp)
{
	vmxnet3s_txqdesc_t *tqdesc = VMXNET3_TQDESC(dp);
	vmxnet3s_txq_t *txq = &dp->txq;

	ASSERT(!(txq->cmdring.size & VMXNET3_RING_SIZE_MASK));
	ASSERT(!(txq->compring.size & VMXNET3_RING_SIZE_MASK));
	ASSERT(!txq->cmdring.dma.buf && !txq->compring.dma.buf);

	if (vmxnet3s_alloc_cmdring(dp, &txq->cmdring) != DDI_SUCCESS)
		goto error;

	tqdesc->conf.txringbasepa = txq->cmdring.dma.bufpa;
	tqdesc->conf.txringsize = txq->cmdring.size;
	tqdesc->conf.dataringbasepa = 0;
	tqdesc->conf.dataringsize = 0;

	if (vmxnet3s_alloc_compring(dp, &txq->compring) != DDI_SUCCESS)
		goto error_cmdring;

	tqdesc->conf.compringbasepa = txq->compring.dma.bufpa;
	tqdesc->conf.compringsize = txq->compring.size;

	txq->metaring = kmem_zalloc(txq->cmdring.size *
	    sizeof (vmxnet3s_metatx_t), KM_SLEEP);

	if (vmxnet3s_txcache_init(dp, txq) != DDI_SUCCESS)
		goto error_mpring;

	if (vmxnet3s_txq_init(dp, txq) != DDI_SUCCESS)
		goto error_txcache;

	return (DDI_SUCCESS);

error_txcache:
	vmxnet3s_txcache_release(dp);
error_mpring:
	kmem_free(txq->metaring, txq->cmdring.size *
	    sizeof (vmxnet3s_metatx_t));
	vmxnet3s_free(&txq->compring.dma);
error_cmdring:
	vmxnet3s_free(&txq->cmdring.dma);
error:
	return (DDI_FAILURE);
}

/*
 * Initialize the rx queue of a vmxnet3s device.
 */
static int
vmxnet3s_prepare_rxq(vmxnet3s_softc_t *dp)
{
	vmxnet3s_rxqdesc_t *rqdesc = VMXNET3_RQDESC(dp);
	vmxnet3s_rxq_t *rxq = &dp->rxq;

	ASSERT(!(rxq->cmdring.size & VMXNET3_RING_SIZE_MASK));
	ASSERT(!(rxq->compring.size & VMXNET3_RING_SIZE_MASK));
	ASSERT(!rxq->cmdring.dma.buf && !rxq->compring.dma.buf);

	if (vmxnet3s_alloc_cmdring(dp, &rxq->cmdring) != DDI_SUCCESS)
		goto error;

	rqdesc->conf.rxringbasepa[0] = rxq->cmdring.dma.bufpa;
	rqdesc->conf.rxringsize[0] = rxq->cmdring.size;
	rqdesc->conf.rxringbasepa[1] = 0;
	rqdesc->conf.rxringsize[1] = 0;

	if (vmxnet3s_alloc_compring(dp, &rxq->compring) != DDI_SUCCESS)
		goto error_cmdring;

	rqdesc->conf.compringbasepa = rxq->compring.dma.bufpa;
	rqdesc->conf.compringsize = rxq->compring.size;

	rxq->bufring = kmem_zalloc(rxq->cmdring.size *
	    sizeof (vmxnet3s_bufdesc_t), KM_SLEEP);

	if (vmxnet3s_rxq_init(dp, rxq) != DDI_SUCCESS)
		goto error_bufring;

	return (DDI_SUCCESS);

error_bufring:
	kmem_free(rxq->bufring, rxq->cmdring.size *
	    sizeof (vmxnet3s_bufdesc_t));
	vmxnet3s_free(&rxq->compring.dma);
error_cmdring:
	vmxnet3s_free(&rxq->cmdring.dma);
error:
	return (DDI_FAILURE);
}

/*
 * Destroy the tx queue of a vmxnet3s device.
 */
static void
vmxnet3s_destroy_txq(vmxnet3s_softc_t *dp)
{
	vmxnet3s_txq_t *txq = &dp->txq;

	ASSERT(txq->metaring);
	ASSERT(txq->cmdring.dma.buf && txq->compring.dma.buf);

	vmxnet3s_txq_fini(dp, txq);

	kmem_free(txq->metaring, txq->cmdring.size *
	    sizeof (vmxnet3s_metatx_t));

	vmxnet3s_free(&txq->cmdring.dma);
	vmxnet3s_free(&txq->compring.dma);

	vmxnet3s_txcache_release(dp);
}

/*
 * Destroy the rx queue of a vmxnet3s device.
 */
static void
vmxnet3s_destroy_rxq(vmxnet3s_softc_t *dp)
{
	vmxnet3s_rxq_t *rxq = &dp->rxq;

	ASSERT(rxq->bufring);
	ASSERT(rxq->cmdring.dma.buf && rxq->compring.dma.buf);

	vmxnet3s_rxq_fini(dp, rxq);

	kmem_free(rxq->bufring, rxq->cmdring.size *
	    sizeof (vmxnet3s_bufdesc_t));

	vmxnet3s_free(&rxq->cmdring.dma);
	vmxnet3s_free(&rxq->compring.dma);
}

/*
 * Apply new RX filters settings to a vmxnet3s device.
 */
static void
vmxnet3s_refresh_rxfilter(vmxnet3s_softc_t *dp)
{
	vmxnet3s_drvshared_t *ds = VMXNET3_DS(dp);

	ds->devread.rxfilterconf.rxmode = dp->rxmode;
	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_CMD, VMXNET3_CMD_UPDATE_RX_MODE);
}

/*
 * Fetch the link state of a vmxnet3s device.
 */
static void
vmxnet3s_refresh_linkstate(vmxnet3s_softc_t *dp)
{
	uint32_t	ret32;

	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_CMD, VMXNET3_CMD_GET_LINK);
	ret32 = VMXNET3_BAR1_GET32(dp, VMXNET3_REG_CMD);
	if (ret32 & 1) {
		dp->linkstate = LINK_STATE_UP;
		dp->linkspeed = (ret32 >> 16) * 1000000ULL;
	} else {
		dp->linkstate = LINK_STATE_DOWN;
		dp->linkspeed = 0;
	}
}

/*
 * Start a vmxnet3s device: allocate and initialize the shared data
 * structures and send a start command to the device.
 */
static int
vmxnet3s_m_start(void *data)
{
	vmxnet3s_rxqdesc_t *rqdesc;
	vmxnet3s_txqdesc_t *tqdesc;
	int		txqsize;
	int		rxqsize;
	uint32_t	ret32;
	vmxnet3s_softc_t *dp = data;
	dev_info_t	*dip = dp->dip;

	/* Allocate vmxnet3s's shared data and advertise its PA */
	if (vmxnet3s_prepare_drivershared(dp) != DDI_SUCCESS)
		goto error;
	tqdesc = VMXNET3_TQDESC(dp);
	rqdesc = VMXNET3_RQDESC(dp);

	/* Create and initialize the tx queue */
	txqsize = vmxnet3s_getprop(dp, "TxRingSize", 32, 4096,
	    VMXNET3_DEF_TX_RING_SIZE);
	if (!(txqsize & VMXNET3_RING_SIZE_MASK)) {
		dp->txq.cmdring.size = txqsize;
		dp->txq.compring.size = txqsize;
		dp->txq.sharedctrl = &tqdesc->ctrl;
		if (vmxnet3s_prepare_txq(dp) != DDI_SUCCESS)
			goto error_shared_data;
	} else {
		dev_err(dip, CE_WARN, "invalid tx ring size (%d)", txqsize);
		goto error_shared_data;
	}

	/* Create and initialize the rx queue */
	rxqsize = vmxnet3s_getprop(dp, "RxRingSize", 32, 4096,
	    VMXNET3_DEF_RX_RING_SIZE);
	if (!(rxqsize & VMXNET3_RING_SIZE_MASK)) {
		dp->rxq.cmdring.size = rxqsize;
		dp->rxq.compring.size = rxqsize;
		dp->rxq.sharedctrl = &rqdesc->ctrl;
		if (vmxnet3s_prepare_rxq(dp) != DDI_SUCCESS)
			goto error_tx_queue;
	} else {
		dev_err(dip, CE_WARN, "invalid rx ring size (%d)", rxqsize);
		goto error_tx_queue;
	}

	/* Allocate the Tx DMA handle */
	if (ddi_dma_alloc_handle(dp->dip, &vmxnet3s_dma_attrs_tx, DDI_DMA_SLEEP,
	    NULL, &dp->txdmahdl) != DDI_SUCCESS)
		goto error_rx_queue;

	/* Activate the device */
	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_CMD, VMXNET3_CMD_ACTIVATE_DEV);
	ret32 = VMXNET3_BAR1_GET32(dp, VMXNET3_REG_CMD);
	if (ret32) {
		dev_err(dip, CE_WARN, "failed to activate device: 0x%x", ret32);
		goto error_txhandle;
	}
	dp->enabled = B_TRUE;

	VMXNET3_BAR0_PUT32(dp, VMXNET3_REG_RXPROD, dp->txq.cmdring.size-1);

	/* Update the RX filters, must be done after ACTIVATE_DEV */
	dp->rxmode = VMXNET3_RXM_UCAST | VMXNET3_RXM_BCAST;
	vmxnet3s_refresh_rxfilter(dp);

	/* Get the link state now because no events will be generated */
	vmxnet3s_refresh_linkstate(dp);
	mac_link_update(dp->mac, dp->linkstate);

	/* Unmask the interrupt */
	VMXNET3_BAR0_PUT32(dp, VMXNET3_REG_IMR, 0);

	return (DDI_SUCCESS);

error_txhandle:
	ddi_dma_free_handle(&dp->txdmahdl);
error_rx_queue:
	vmxnet3s_destroy_rxq(dp);
error_tx_queue:
	vmxnet3s_destroy_txq(dp);
error_shared_data:
	vmxnet3s_destroy_drivershared(dp);
error:
	return (DDI_FAILURE);
}

/*
 * Stop a vmxnet3s device: send a stop command to the device and
 * de-allocate the shared data structures.
 */
static void
vmxnet3s_m_stop(void *data)
{
	vmxnet3s_softc_t *dp = data;

	/*
	 * Take 2 locks related to asynchronous events.
	 * These events should always check dp->dev_enabled before poking dp.
	 */
	mutex_enter(&dp->intrlock);
	mutex_enter(&dp->rxpoollock);
	VMXNET3_BAR0_PUT32(dp, VMXNET3_REG_IMR, 1);
	dp->enabled = B_FALSE;
	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_CMD, VMXNET3_CMD_QUIESCE_DEV);
	mutex_exit(&dp->rxpoollock);
	mutex_exit(&dp->intrlock);

	ddi_dma_free_handle(&dp->txdmahdl);

	vmxnet3s_destroy_rxq(dp);
	vmxnet3s_destroy_txq(dp);

	vmxnet3s_destroy_drivershared(dp);
}

/*
 * Set or unset promiscuous mode on a vmxnet3s device.
 */
static int
vmxnet3s_m_setpromisc(void *data, boolean_t promisc)
{
	vmxnet3s_softc_t *dp = data;

	if (promisc)
		dp->rxmode |= VMXNET3_RXM_PROMISC;
	else
		dp->rxmode &= ~VMXNET3_RXM_PROMISC;

	vmxnet3s_refresh_rxfilter(dp);

	return (DDI_SUCCESS);
}

/*
 * Add or remove a multicast address from/to a vmxnet3s device.
 */
static int
vmxnet3s_m_multicst(void *data, boolean_t add, const uint8_t *macaddr)
{
	int		ret = DDI_SUCCESS;
	uint16_t	macidx;
	size_t		allocsz;
	vmxnet3s_dmabuf_t newmftbl;
	vmxnet3s_softc_t *dp = data;

	/*
	 * First lookup the position of the given MAC to check if it is
	 * present in the existing MF table.
	 */
	for (macidx = 0; macidx < dp->mftbl.buflen; macidx += 6) {
		if (memcmp(&dp->mftbl.buf[macidx], macaddr, 6) == 0)
			break;
	}

	/*
	 * Check for 2 situations we can handle gracefully by bailing out:
	 * adding an already existing filter or removing a non-existing one.
	 */
	if (add && macidx < dp->mftbl.buflen)
		goto done;
	if (!add && macidx == dp->mftbl.buflen)
		goto done;

	/* Create the new MF table */
	if ((allocsz = dp->mftbl.buflen + (add ? 6 : -6)) != 0) {
		ret = vmxnet3s_alloc1(dp, &newmftbl, allocsz, B_TRUE);
		ASSERT(ret == DDI_SUCCESS);
		if (add) {
			(void) memcpy(newmftbl.buf, dp->mftbl.buf,
			    dp->mftbl.buflen);
			(void) memcpy(newmftbl.buf + dp->mftbl.buflen,
			    macaddr, 6);
		} else {
			(void) memcpy(newmftbl.buf, dp->mftbl.buf, macidx);
			(void) memcpy(newmftbl.buf + macidx,
			    dp->mftbl.buf + macidx + 6,
			    dp->mftbl.buflen - macidx - 6);
		}
	} else {
		newmftbl.buf = NULL;
		newmftbl.bufpa = 0;
		newmftbl.buflen = 0;
	}

	/*
	 * Now handle 2 corner cases: if we're creating the first filter or
	 * removing the last one, we have to update rxmode accordingly.
	 */
	if (add && newmftbl.buflen == 6) {
		ASSERT(!(dp->rxmode & VMXNET3_RXM_MCAST));
		dp->rxmode |= VMXNET3_RXM_MCAST;
		vmxnet3s_refresh_rxfilter(dp);
	}
	if (!add && dp->mftbl.buflen == 6) {
		ASSERT(newmftbl.buf == NULL);
		ASSERT(dp->rxmode & VMXNET3_RXM_MCAST);
		dp->rxmode &= ~VMXNET3_RXM_MCAST;
		vmxnet3s_refresh_rxfilter(dp);
	}

	/* Now replace the old MF table with the new one */
	if (dp->mftbl.buf)
		vmxnet3s_free(&dp->mftbl);
	dp->mftbl = newmftbl;
	VMXNET3_DS(dp)->devread.rxfilterconf.mftblpa = newmftbl.bufpa;
	VMXNET3_DS(dp)->devread.rxfilterconf.mftbllen = newmftbl.buflen;

done:
	/* Always update the filters */
	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_CMD, VMXNET3_CMD_UPDATE_MAC_FILTERS);

	return (ret);
}

/*
 * Set the mac address of a vmxnet3s device.
 */
static int
vmxnet3s_m_unicst(void *data, const uint8_t *macaddr)
{
	uint32_t	val32;
	vmxnet3s_softc_t *dp = data;

	val32 = *((uint32_t *)(macaddr + 0));
	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_MACL, val32);
	val32 = *((uint16_t *)(macaddr + 4));
	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_MACH, val32);

	(void) memcpy(dp->macaddr, macaddr, 6);

	return (DDI_SUCCESS);
}

/*
 * Get capabilities of vmxnet3s device.
 */
static boolean_t
vmxnet3s_m_getcapab(void *data, mac_capab_t capab, void *arg)
{
	boolean_t	ret;
	vmxnet3s_softc_t *dp = data;

	switch (capab) {
	case MAC_CAPAB_HCKSUM: {
		uint32_t	*txflags = arg;

		*txflags = HCKSUM_INET_PARTIAL;
		ret = B_TRUE;
		break;
	}
	case MAC_CAPAB_LSO: {
		mac_capab_lso_t *lso = arg;

		lso->lso_flags = LSO_TX_BASIC_TCP_IPV4;
		lso->lso_basic_tcp_ipv4.lso_max = IP_MAXPACKET;
		ret = vmxnet3s_getprop(dp, "EnableLSO", 0, 1, 1);
		break;
	}
	default:
		ret = B_FALSE;
	}

	return (ret);
}

/*
 * Reset vmxnet3s device. Only to be used when the device is wedged.
 */
static void
vmxnet3s_reset(void *data)
{
	vmxnet3s_softc_t *dp = data;

	vmxnet3s_m_stop(dp);
	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_CMD, VMXNET3_CMD_RESET_DEV);
	(void) vmxnet3s_m_start(dp);
}

/*
 * Process pending events on a vmxnet3s device.
 */
static boolean_t
vmxnet3s_intr_events(vmxnet3s_softc_t *dp)
{
	vmxnet3s_drvshared_t *ds = VMXNET3_DS(dp);
	boolean_t	link_state_changed = B_FALSE;
	uint32_t	events = ds->ecr;

	if (events) {
		if (events & (VMXNET3_ECR_RQERR | VMXNET3_ECR_TQERR)) {
			VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_CMD,
			    VMXNET3_CMD_GET_QUEUE_STATUS);
			(void) ddi_taskq_dispatch(dp->resettaskq,
			    vmxnet3s_reset, dp, DDI_NOSLEEP);
		}
		if ((events & VMXNET3_ECR_LINK) != 0) {
			vmxnet3s_refresh_linkstate(dp);
			link_state_changed = B_TRUE;
		}
		VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_ECR, events);
	}

	return (link_state_changed);
}

/*
 * Interrupt handler of a vmxnet3s device.
 */
/* ARGSUSED data2 */
static uint_t
vmxnet3s_intr(caddr_t data1, caddr_t data2)
{
	vmxnet3s_softc_t *dp = (void *) data1;

	mutex_enter(&dp->intrlock);

	if (dp->enabled) {
		boolean_t link_state_changed;
		boolean_t must_update_tx;
		mblk_t *mps;

		if (dp->intrtype == DDI_INTR_TYPE_FIXED &&
		    !VMXNET3_BAR1_GET32(dp, VMXNET3_REG_ICR)) {
			goto intr_unclaimed;
		}

		if (dp->intrmaskmode == VMXNET3_IMM_ACTIVE)
			VMXNET3_BAR0_PUT32(dp, VMXNET3_REG_IMR, 1);

		link_state_changed = vmxnet3s_intr_events(dp);
		must_update_tx = vmxnet3s_tx_complete(dp, &dp->txq);
		mps = vmxnet3s_rx_intr(dp, &dp->rxq);

		mutex_exit(&dp->intrlock);
		VMXNET3_BAR0_PUT32(dp, VMXNET3_REG_IMR, 0);

		if (link_state_changed)
			mac_link_update(dp->mac, dp->linkstate);
		if (must_update_tx)
			mac_tx_update(dp->mac);
		if (mps)
			mac_rx(dp->mac, NULL, mps);

		return (DDI_INTR_CLAIMED);
	}

intr_unclaimed:
	mutex_exit(&dp->intrlock);

	return (DDI_INTR_UNCLAIMED);
}

/* ARGSUSED */
static int
vmxnet3s_m_setprop(void *arg, const char *propname, mac_prop_id_t propnum,
    uint_t propvalsize, const void *propval)
{
	vmxnet3s_softc_t *dp = arg;
	uint32_t	new_mtu;
	int		ret = 0;
	boolean_t	do_reset = B_FALSE;

	switch (propnum) {
	case MAC_PROP_MTU:
		new_mtu = *(uint32_t *)propval;
		if (new_mtu == dp->cur_mtu)
			return (0);
		if (new_mtu > VMXNET3_MAX_MTU)
			return (EINVAL);
		if (dp->enabled) {
			do_reset = B_TRUE;
			vmxnet3s_m_stop(dp);
			VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_CMD,
			    VMXNET3_CMD_RESET_DEV);
		}
		dp->cur_mtu = new_mtu;
		if (do_reset)
			ret = vmxnet3s_m_start(dp);
		if (ret == DDI_SUCCESS)
			(void) mac_maxsdu_update(dp->mac, new_mtu);
		break;
	default:
		return (ENOTSUP);
	}

	return (0);
}

/* ARGSUSED */
static int
vmxnet3s_m_getprop(void *arg, const char *propname, mac_prop_id_t propnum,
    uint_t propvalsize, void *propval)
{
	vmxnet3s_softc_t *dp = arg;
	int		ret = 0;

	switch (propnum) {
	case MAC_PROP_SPEED:
		*(uint64_t *)propval = 10000000ULL;
		break;
	case MAC_PROP_STATUS:
		*(link_state_t *)propval = dp->linkstate;
		break;
	default:
		ret = ENOTSUP;
	}

	return (ret);
}

/* ARGSUSED */
static void
vmxnet3s_m_propinfo(void *arg, const char *propname, mac_prop_id_t propnum,
    mac_prop_info_handle_t prh)
{

	switch (propnum) {
	case MAC_PROP_MTU:
		mac_prop_info_set_range_uint32(prh, ETHERMTU,
		    VMXNET3_MAX_MTU);
		break;
	}
}

static mac_callbacks_t vmxnet3s_m_callbacks = {
	MC_GETCAPAB | MC_PROPERTIES,
	vmxnet3s_m_getstat,	/* mc_getstat */
	vmxnet3s_m_start,	/* mc_start */
	vmxnet3s_m_stop,	/* mc_stop */
	vmxnet3s_m_setpromisc,	/* mc_setpromisc */
	vmxnet3s_m_multicst,	/* mc_multicst */
	vmxnet3s_m_unicst,	/* mc_unicst */
	vmxnet3s_m_tx,		/* mc_tx */
	NULL,			/* reserved */
	NULL,			/* mc_ioctl */
	vmxnet3s_m_getcapab,	/* mc_getcapab */
	NULL,			/* reserved */
	NULL,			/* reserved */
	vmxnet3s_m_setprop,	/* mc_setprop */
	vmxnet3s_m_getprop,	/* mc_getprop */
	vmxnet3s_m_propinfo	/* mc_propinfo */
};

/*
 * Probe and attach a vmxnet3s instance to the stack.
 */
static int
vmxnet3s_attach(dev_info_t *dip, ddi_attach_cmd_t cmd)
{
	vmxnet3s_softc_t *dp;
	mac_register_t	*macp;
	uint16_t	vendorid;
	uint16_t	devid;
	uint16_t	ret16;
	uint32_t	ret32;
	int		ret;
	uint_t		uret;

	if (cmd != DDI_ATTACH)
		goto error;

	/* Allocate the soft state */
	dp = kmem_zalloc(sizeof (vmxnet3s_softc_t), KM_SLEEP);

	dp->dip = dip;
	dp->instance = ddi_get_instance(dip);

	ddi_set_driver_private(dip, dp);

	/* Get access to the PCI bus configuration space */
	if (pci_config_setup(dip, &dp->pcihdl) != DDI_SUCCESS)
		goto error_soft_state;

	/* Make sure the chip is a vmxnet3s device */
	vendorid = pci_config_get16(dp->pcihdl, PCI_CONF_VENID);
	devid = pci_config_get16(dp->pcihdl, PCI_CONF_DEVID);
	if (vendorid != PCI_VENDOR_ID_VMWARE ||
	    devid != PCI_DEVICE_ID_VMWARE_VMXNET3)
		goto error_pci_config;

	/* Make sure we can access the registers through the I/O space */
	ret16 = pci_config_get16(dp->pcihdl, PCI_CONF_COMM);
	ret16 |= PCI_COMM_IO | PCI_COMM_ME;
	pci_config_put16(dp->pcihdl, PCI_CONF_COMM, ret16);

	/* Map the I/O space in memory */
	if (ddi_regs_map_setup(dip, 1, &dp->bar0, 0, 0, &vmxnet3s_dev_attr,
	    &dp->bar0hdl) != DDI_SUCCESS) {
		dev_err(dip, CE_WARN, "failed to set up mapping for BAR0");
		goto error_pci_config;
	}

	if (ddi_regs_map_setup(dip, 2, &dp->bar1, 0, 0, &vmxnet3s_dev_attr,
	    &dp->bar1hdl) != DDI_SUCCESS) {
		dev_err(dip, CE_WARN, "failed to set up mapping for BAR1");
		goto error_regs_map_0;
	}

	/* Check the version number of the virtual device */
	if (VMXNET3_BAR1_GET32(dp, VMXNET3_REG_VRRS) & 1)
		VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_VRRS, 1);
	else
		goto error_regs_map_1;

	if (VMXNET3_BAR1_GET32(dp, VMXNET3_REG_UVRS) & 1)
		VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_UVRS, 1);
	else
		goto error_regs_map_1;

	/* Read the MAC address from the device */
	ret32 = VMXNET3_BAR1_GET32(dp, VMXNET3_REG_MACL);
	*((uint32_t *)(dp->macaddr + 0)) = ret32;
	ret32 = VMXNET3_BAR1_GET32(dp, VMXNET3_REG_MACH);
	*((uint16_t *)(dp->macaddr + 4)) = ret32;

	/* Register with MAC framework */
	if ((macp = mac_alloc(MAC_VERSION)) == NULL) {
		dev_err(dip, CE_WARN, "mac_alloc failed");
		goto error_regs_map_1;
	}

	dp->cur_mtu = ETHERMTU;

	macp->m_type_ident = MAC_PLUGIN_IDENT_ETHER;
	macp->m_driver = dp;
	macp->m_dip = dip;
	macp->m_instance = 0;
	macp->m_src_addr = dp->macaddr;
	macp->m_dst_addr = NULL;
	macp->m_callbacks = &vmxnet3s_m_callbacks;
	macp->m_min_sdu = 0;
	macp->m_max_sdu = dp->cur_mtu;
	macp->m_margin = VLAN_TAGSZ;
	macp->m_pdata = NULL;
	macp->m_pdata_size = 0;

	ret = mac_register(macp, &dp->mac);
	mac_free(macp);
	if (ret != DDI_SUCCESS) {
		dev_err(dip, CE_WARN, "mac_register failed");
		goto error_regs_map_1;
	}

	/*
	 * Register the interrupt(s) in this order of preference:
	 * MSI-X, MSI, INTx
	 */
	VMXNET3_BAR1_PUT32(dp, VMXNET3_REG_CMD, VMXNET3_CMD_GET_CONF_INTR);
	ret32 = VMXNET3_BAR1_GET32(dp, VMXNET3_REG_CMD);
	switch (ret32 & 0x3) {
	case VMXNET3_IT_AUTO:
	case VMXNET3_IT_MSIX:
		dp->intrtype = DDI_INTR_TYPE_MSIX;
		if (ddi_intr_alloc(dip, &dp->intrhdl, dp->intrtype, 0,
		    1, &ret, DDI_INTR_ALLOC_STRICT) == DDI_SUCCESS)
			break;
		/* FALLTHROUGH */
	case VMXNET3_IT_MSI:
		dp->intrtype = DDI_INTR_TYPE_MSI;
		if (ddi_intr_alloc(dip, &dp->intrhdl, dp->intrtype, 0,
		    1, &ret, DDI_INTR_ALLOC_STRICT) == DDI_SUCCESS)
			break;
		/* FALLTHROUGH */
	case VMXNET3_IT_INTX:
		dp->intrtype = DDI_INTR_TYPE_FIXED;
		if (ddi_intr_alloc(dip, &dp->intrhdl, dp->intrtype, 0,
		    1, &ret, DDI_INTR_ALLOC_STRICT) == DDI_SUCCESS)
			break;
		/* FALLTHROUGH */
	default:
		goto error_mac;
	}

	if ((dp->intrmaskmode = (ret32 >> 2) & 0x3) == VMXNET3_IMM_LAZY)
		goto error_intr;

	if (ddi_intr_get_pri(dp->intrhdl, &uret) != DDI_SUCCESS)
		goto error_intr;

	/* Create a task queue to reset the device if it wedges */
	if ((dp->resettaskq = ddi_taskq_create(dip, "vmxnet3s_reset_task", 1,
	    TASKQ_DEFAULTPRI, 0)) == NULL)
		goto error_intr;

	/*
	 * Initialize our mutexes now that we know the interrupt priority
	 * This _must_ be done before ddi_intr_enable()
	 */
	mutex_init(&dp->intrlock, NULL, MUTEX_DRIVER, DDI_INTR_PRI(uret));
	mutex_init(&dp->txlock, NULL, MUTEX_DRIVER, DDI_INTR_PRI(uret));
	mutex_init(&dp->rxpoollock, NULL, MUTEX_DRIVER, DDI_INTR_PRI(uret));

	if (ddi_intr_add_handler(dp->intrhdl, vmxnet3s_intr,
	    dp, NULL) != DDI_SUCCESS)
		goto error_mutexes;

	if (ddi_intr_get_cap(dp->intrhdl, &dp->intrcap) != DDI_SUCCESS)
		goto error_intr_handler;

	if (dp->intrcap & DDI_INTR_FLAG_BLOCK) {
		if (ddi_intr_block_enable(&dp->intrhdl, 1) != DDI_SUCCESS)
			goto error_intr_handler;
	} else {
		if (ddi_intr_enable(dp->intrhdl) != DDI_SUCCESS)
			goto error_intr_handler;
	}

	return (DDI_SUCCESS);

error_intr_handler:
	(void) ddi_intr_remove_handler(dp->intrhdl);
error_mutexes:
	mutex_destroy(&dp->rxpoollock);
	mutex_destroy(&dp->txlock);
	mutex_destroy(&dp->intrlock);
	ddi_taskq_destroy(dp->resettaskq);
error_intr:
	(void) ddi_intr_free(dp->intrhdl);
error_mac:
	(void) mac_unregister(dp->mac);
error_regs_map_1:
	ddi_regs_map_free(&dp->bar1hdl);
error_regs_map_0:
	ddi_regs_map_free(&dp->bar0hdl);
error_pci_config:
	pci_config_teardown(&dp->pcihdl);
error_soft_state:
	kmem_free(dp, sizeof (vmxnet3s_softc_t));
error:
	return (DDI_FAILURE);
}

/*
 * Detach a vmxnet3s instance from the stack.
 */
static int
vmxnet3s_detach(dev_info_t *dip, ddi_detach_cmd_t cmd)
{
	vmxnet3s_softc_t *dp = ddi_get_driver_private(dip);
	int		retries = 0;

	if (cmd != DDI_DETACH)
		return (DDI_FAILURE);

	while (dp->rxnumbufs) {
		if (retries++ < 10)
			delay(drv_usectohz(1000000));
		else
			return (DDI_FAILURE);
	}

	if (dp->intrcap & DDI_INTR_FLAG_BLOCK)
		(void) ddi_intr_block_disable(&dp->intrhdl, 1);
	else
		(void) ddi_intr_disable(dp->intrhdl);
	(void) ddi_intr_remove_handler(dp->intrhdl);
	(void) ddi_intr_free(dp->intrhdl);

	(void) mac_unregister(dp->mac);

	if (dp->mftbl.buf)
		vmxnet3s_free(&dp->mftbl);

	mutex_destroy(&dp->rxpoollock);
	mutex_destroy(&dp->txlock);
	mutex_destroy(&dp->intrlock);
	ddi_taskq_destroy(dp->resettaskq);

	ddi_regs_map_free(&dp->bar1hdl);
	ddi_regs_map_free(&dp->bar0hdl);
	pci_config_teardown(&dp->pcihdl);

	kmem_free(dp, sizeof (vmxnet3s_softc_t));

	return (DDI_SUCCESS);
}

/*
 * Structures used by module loader
 */
#define	VMXNET3_IDENT "VMware EtherAdapter v3"

DDI_DEFINE_STREAM_OPS(
	vmxnet3s_dev_ops,
	nulldev,
	nulldev,
	vmxnet3s_attach,
	vmxnet3s_detach,
	nodev,
	NULL,
	D_NEW | D_MP,
	NULL,
	ddi_quiesce_not_supported);

static struct modldrv vmxnet3s_modldrv = {
	&mod_driverops,			/* drv_modops */
	VMXNET3_IDENT,			/* drv_linkinfo */
	&vmxnet3s_dev_ops		/* drv_dev_ops */
};

static struct modlinkage vmxnet3s_modlinkage = {
	MODREV_1,			/* ml_rev */
	{ &vmxnet3s_modldrv, NULL }	/* ml_linkage */
};

/* Module load entry point */
int
_init(void)
{
	int	ret;

	mac_init_ops(&vmxnet3s_dev_ops, VMXNET3_MODNAME);
	ret = mod_install(&vmxnet3s_modlinkage);
	if (ret != DDI_SUCCESS)
		mac_fini_ops(&vmxnet3s_dev_ops);

	return (ret);
}

/* Module unload entry point */
int
_fini(void)
{
	int	ret;

	ret = mod_remove(&vmxnet3s_modlinkage);
	if (ret == DDI_SUCCESS)
		mac_fini_ops(&vmxnet3s_dev_ops);

	return (ret);
}

/* Module info entry point */
int
_info(struct modinfo *modinfop)
{

	return (mod_info(&vmxnet3s_modlinkage, modinfop));
}

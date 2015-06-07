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

#include "vmxnet3s.h"

static void	vmxnet3s_put_rxbuf(vmxnet3s_rxbuf_t *rxbuf);

/*
 * Allocate new rxbuf from memory. All its fields are set except
 * for its associated mblk which has to be allocated later.
 */
static vmxnet3s_rxbuf_t *
vmxnet3s_alloc_rxbuf(vmxnet3s_softc_t *dp, boolean_t cansleep)
{
	vmxnet3s_rxbuf_t *rxbuf;
	int		flag = cansleep ? KM_SLEEP : KM_NOSLEEP;

	if ((rxbuf = kmem_zalloc(sizeof (vmxnet3s_rxbuf_t), flag)) == NULL)
		return (NULL);

	if (vmxnet3s_alloc1(dp, &rxbuf->dma, (dp->cur_mtu + 18),
	    cansleep) != DDI_SUCCESS) {
		kmem_free(rxbuf, sizeof (vmxnet3s_rxbuf_t));
		return (NULL);
	}

	rxbuf->freecb.free_func = vmxnet3s_put_rxbuf;
	rxbuf->freecb.free_arg = (caddr_t)rxbuf;
	rxbuf->dp = dp;

	atomic_inc_32(&dp->rxnumbufs);

	return (rxbuf);
}

/*
 * Free rxbuf.
 */
static void
vmxnet3s_free_rxbuf(vmxnet3s_softc_t *dp, vmxnet3s_rxbuf_t *rxbuf)
{

	vmxnet3s_free(&rxbuf->dma);
	kmem_free(rxbuf, sizeof (vmxnet3s_rxbuf_t));

#ifndef DEBUG
	atomic_dec_32(&dp->rxnumbufs);
#else
	{
		uint32_t nv = atomic_dec_32_nv(&dp->rxnumbufs);
		ASSERT(nv != (uint32_t)-1);
	}
#endif
}

/*
 * Return a rxbuf to the pool or free it.
 */
static void
vmxnet3s_put_rxbuf(vmxnet3s_rxbuf_t *rxbuf)
{
	vmxnet3s_softc_t *dp = rxbuf->dp;
	vmxnet3s_rxpool_t *rxpool = &dp->rxpool;

	mutex_enter(&dp->rxpoollock);
	if (dp->enabled && rxpool->nbufs < rxpool->nbufslimit) {
		rxbuf->next = rxpool->listhead;
		rxpool->listhead = rxbuf;
		mutex_exit(&dp->rxpoollock);
	} else {
		mutex_exit(&dp->rxpoollock);
		vmxnet3s_free_rxbuf(dp, rxbuf);
	}
}

/*
 * Get an unused rxbuf from either the pool or from memory.
 * The returned rxbuf has a mblk associated with it.
 */
static vmxnet3s_rxbuf_t *
vmxnet3s_get_rxbuf(vmxnet3s_softc_t *dp, boolean_t cansleep)
{
	vmxnet3s_rxbuf_t *rxbuf;
	vmxnet3s_rxpool_t *rxpool = &dp->rxpool;

	mutex_enter(&dp->rxpoollock);
	if (rxpool->listhead) {
		rxbuf = rxpool->listhead;
		rxpool->listhead = rxbuf->next;
		mutex_exit(&dp->rxpoollock);
	} else {
		mutex_exit(&dp->rxpoollock);
		if ((rxbuf = vmxnet3s_alloc_rxbuf(dp, cansleep)) == NULL)
			goto done;
	}

	ASSERT(rxbuf);

	rxbuf->mblk = desballoc((uchar_t *)rxbuf->dma.buf,
	    rxbuf->dma.buflen, BPRI_MED, &rxbuf->freecb);
	if (!rxbuf->mblk) {
		vmxnet3s_put_rxbuf(rxbuf);
		rxbuf = NULL;
	}

done:
	return (rxbuf);
}

/*
 * Populate a Rx descriptor with a new rxbuf.
 */
static int
vmxnet3s_rx_populate(vmxnet3s_softc_t *dp, vmxnet3s_rxq_t *rxq,
    uint16_t idx, boolean_t cansleep)
{
	int		ret = DDI_SUCCESS;
	vmxnet3s_rxbuf_t *rxbuf;

	if ((rxbuf = vmxnet3s_get_rxbuf(dp, cansleep)) != NULL) {
		vmxnet3s_cmdring_t *cmdring = &rxq->cmdring;
		vmxnet3s_gendesc_t *rxdesc = VMXNET3_GET_DESC(cmdring, idx);

		rxq->bufring[idx].rxbuf = rxbuf;
		rxdesc->rxd.addr = rxbuf->dma.bufpa;
		rxdesc->rxd.len = rxbuf->dma.buflen;
		/* rxdesc->rxd.btype = 0; */
		membar_producer();
		rxdesc->rxd.gen = cmdring->gen;
	} else {
		ret = DDI_FAILURE;
	}

	return (ret);
}

/*
 * Initialize a rxq by populating the whole Rx ring with rxbufs.
 */
int
vmxnet3s_rxq_init(vmxnet3s_softc_t *dp, vmxnet3s_rxq_t *rxq)
{
	vmxnet3s_cmdring_t *cmdring = &rxq->cmdring;

	do {
		if (vmxnet3s_rx_populate(dp, rxq, cmdring->next2fill,
		    B_TRUE) != DDI_SUCCESS)
			goto error;
		VMXNET3_INC_RING_IDX(cmdring, cmdring->next2fill);
	} while (cmdring->next2fill);

	dp->rxpool.nbufslimit = vmxnet3s_getprop(dp, "RxBufPoolLimit",
	    0, cmdring->size * 10, cmdring->size * 2);

	return (DDI_SUCCESS);

error:
	while (cmdring->next2fill) {
		VMXNET3_DEC_RING_IDX(cmdring, cmdring->next2fill);
		vmxnet3s_free_rxbuf(dp, rxq->bufring[cmdring->next2fill].rxbuf);
	}

	return (DDI_FAILURE);
}

/*
 * Finish a rxq by freeing all the related rxbufs.
 */
void
vmxnet3s_rxq_fini(vmxnet3s_softc_t *dp, vmxnet3s_rxq_t *rxq)
{
	vmxnet3s_rxpool_t *rxpool = &dp->rxpool;
	vmxnet3s_rxbuf_t *rxbuf;
	uint_t	i;

	ASSERT(!dp->enabled);

	/* First the rxpool */
	while (rxpool->listhead) {
		rxbuf = rxpool->listhead;
		rxpool->listhead = rxbuf->next;
		vmxnet3s_free_rxbuf(dp, rxbuf);
	}

	/* Then the ring */
	for (i = 0; i < rxq->cmdring.size; i++) {
		rxbuf = rxq->bufring[i].rxbuf;
		ASSERT(rxbuf);
		ASSERT(rxbuf->mblk);
		/*
		 * Here, freemsg() will trigger a call to vmxnet3s_put_rxbuf()
		 * which will then call vmxnet3s_free_rxbuf() because
		 * the underlying device is disabled.
		 */
		freemsg(rxbuf->mblk);
	}
}

/*
 * Determine if a received packet was checksummed by the Vmxnet3
 * device and tag the mp appropriately.
 */
/* ARGSUSED */
static void
vmxnet3s_rx_hwcksum(vmxnet3s_softc_t *dp, mblk_t *mp,
    vmxnet3s_gendesc_t *compdesc)
{
	uint32_t	flags = 0;

	if (!compdesc->rcd.cnc) {
		if (compdesc->rcd.v4 && compdesc->rcd.ipc) {
			flags |= HCK_IPV4_HDRCKSUM;
			if ((compdesc->rcd.tcp || compdesc->rcd.udp) &&
			    compdesc->rcd.tuc)
				flags |= HCK_FULLCKSUM | HCK_FULLCKSUM_OK;
		}

		(void) hcksum_assoc(mp, NULL, NULL, 0, 0, 0, 0, flags, 0);
	}
}

/*
 * Interrupt handler for Rx. Look if there are any pending Rx and
 * put them in mplist.
 */
mblk_t *
vmxnet3s_rx_intr(vmxnet3s_softc_t *dp, vmxnet3s_rxq_t *rxq)
{
	vmxnet3s_compring_t *compring = &rxq->compring;
	vmxnet3s_cmdring_t *cmdring = &rxq->cmdring;
	vmxnet3s_rxqctrl_t *rxqctrl = rxq->sharedctrl;
	vmxnet3s_gendesc_t *compdesc;
	mblk_t		*mplist = NULL;
	mblk_t		**mplisttail = &mplist;

	ASSERT(mutex_owned(&dp->intrlock));

	compdesc = VMXNET3_GET_DESC(compring, compring->next2comp);
	while (compdesc->rcd.gen == compring->gen) {
		mblk_t		*mp = NULL;
		mblk_t		**mptail = &mp;
		boolean_t	mpvalid = B_TRUE;
		boolean_t	eop;

		ASSERT(compdesc->rcd.sop);

		do {
			uint16_t	rxdidx = compdesc->rcd.rxdidx;
			vmxnet3s_rxbuf_t *rxbuf = rxq->bufring[rxdidx].rxbuf;
			mblk_t		*mblk = rxbuf->mblk;
			vmxnet3s_gendesc_t *rxdesc;

			while (compdesc->rcd.gen != compring->gen) {
				/*
				 * H/W may be still be in the middle of
				 * generating this entry, so hold on until
				 * the gen bit is flipped.
				 */
				membar_consumer();
			}
			ASSERT(compdesc->rcd.gen == compring->gen);
			ASSERT(rxbuf);
			ASSERT(mblk);

			/* Some Rx descriptors may have been skipped */
			while (cmdring->next2fill != rxdidx) {
				rxdesc = VMXNET3_GET_DESC(cmdring,
				    cmdring->next2fill);
				rxdesc->rxd.gen = cmdring->gen;
				VMXNET3_INC_RING_IDX(cmdring,
				    cmdring->next2fill);
			}

			eop = compdesc->rcd.eop;

			/*
			 * Now we have a piece of the packet in the rxdidx
			 * descriptor. Grab it only if we achieve to replace
			 * it with a fresh buffer.
			 */
			if (vmxnet3s_rx_populate(dp, rxq, rxdidx, B_FALSE)
			    == DDI_SUCCESS) {
				/* Success, we can chain the mblk with the mp */
				mblk->b_wptr = mblk->b_rptr + compdesc->rcd.len;
				*mptail = mblk;
				mptail = &mblk->b_cont;
				ASSERT(*mptail == NULL);

				if (eop) {
					if (!compdesc->rcd.err) {
						/*
						 * Tag the mp if it was
						 * checksummed by the H/W
						 */
						vmxnet3s_rx_hwcksum(dp, mp,
						    compdesc);
					} else {
						mpvalid = B_FALSE;
					}
				}
			} else {
				/*
				 * Keep the same buffer, we still need to flip
				 * the gen bit
				 */
				rxdesc = VMXNET3_GET_DESC(cmdring, rxdidx);
				rxdesc->rxd.gen = cmdring->gen;
				mpvalid = B_FALSE;
			}

			VMXNET3_INC_RING_IDX(compring, compring->next2comp);
			VMXNET3_INC_RING_IDX(cmdring, cmdring->next2fill);
			compdesc = VMXNET3_GET_DESC(compring,
			    compring->next2comp);
		} while (!eop);

		if (mp) {
			if (mpvalid) {
				*mplisttail = mp;
				mplisttail = &mp->b_next;
				ASSERT(*mplisttail == NULL);
			} else {
				/* This message got holes, drop it */
				freemsg(mp);
			}
		}
	}

	if (rxqctrl->updaterxprod) {
		uint32_t	rxprod;

		/*
		 * All buffers are actually available, but we can't tell that to
		 * the device because it may interpret that as an empty ring.
		 * So skip one buffer.
		 */
		if (cmdring->next2fill)
			rxprod = cmdring->next2fill - 1;
		else
			rxprod = cmdring->size - 1;
		VMXNET3_BAR0_PUT32(dp, VMXNET3_REG_RXPROD, rxprod);
	}

	return (mplist);
}

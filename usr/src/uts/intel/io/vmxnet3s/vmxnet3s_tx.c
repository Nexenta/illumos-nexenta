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

#include <sys/note.h>

#include "vmxnet3s.h"

typedef enum vmxnet3s_txstatus {
	VMXNET3_TX_OK,
	VMXNET3_TX_FAILURE,
	VMXNET3_TX_PULLUP,
	VMXNET3_TX_RINGFULL
} vmxnet3s_txstatus_t;

typedef struct vmxnet3s_offload {
	uint16_t	om;
	uint16_t	hlen;
	uint16_t	msscof;
} vmxnet3s_offload_t;

/*
 * Initialize a txq. Currently nothing needs to be done.
 */
/* ARGSUSED dp txq */
int
vmxnet3s_txq_init(vmxnet3s_softc_t *dp, vmxnet3s_txq_t *txq)
{

	return (DDI_SUCCESS);
}

/*
 * Finish a txq by freeing all pending Tx.
 */
void
vmxnet3s_txq_fini(vmxnet3s_softc_t *dp, vmxnet3s_txq_t *txq)
{
	uint_t	i;

	ASSERT(!dp->enabled);

	for (i = 0; i < txq->cmdring.size; i++) {
		mblk_t *mp = txq->metaring[i].mp;
		if (mp)
			freemsg(mp);
	}
}

void
mac_lso_get(mblk_t *mp, uint32_t *mss, uint32_t *flags)
{

	ASSERT(DB_TYPE(mp) == M_DATA);

	if (flags != NULL) {
		*flags = DB_CKSUMFLAGS(mp) & HW_LSO;
		if ((*flags != 0) && (mss != NULL))
			*mss = (uint32_t)DB_LSOMSS(mp);
	}
}

/*
 * Build the offload context of a msg.
 */
/* ARGSUSED */
static int
vmxnet3s_tx_prepare_offload(vmxnet3s_softc_t *dp, vmxnet3s_offload_t *ol,
    mblk_t *mp, int *to_copy)
{
	int		ret = 0;
	uint32_t	start;
	uint32_t	stuff;
	uint32_t	value;
	uint32_t	flags;
	uint32_t	lsoflags;
	uint32_t	mss;

	ol->om = VMXNET3_OM_NONE;
	ol->hlen = 0;
	ol->msscof = 0;

	hcksum_retrieve(mp, NULL, NULL, &start, &stuff, NULL, &value, &flags);

	mac_lso_get(mp, &mss, &lsoflags);
	if (lsoflags & HW_LSO)
		flags |= HW_LSO;

	if (flags) {
		struct ether_vlan_header *eth = (void *) mp->b_rptr;
		uint8_t		ethlen;

		if (eth->ether_tpid == htons(ETHERTYPE_VLAN))
			ethlen = sizeof (struct ether_vlan_header);
		else
			ethlen = sizeof (struct ether_header);

		if (flags & HCK_PARTIALCKSUM) {
			ol->om = VMXNET3_OM_CSUM;
			ol->hlen = start + ethlen;
			ol->msscof = stuff + ethlen;
		}
		if (flags & HW_LSO) {
			mblk_t		*mblk = mp;
			uint8_t		*ip;
			uint8_t		*tcp;
			uint8_t		iplen;
			uint8_t		tcplen;

			/*
			 * Copy e1000g's behavior:
			 * - Do not assume all the headers are in the same mblk.
			 * - Assume each header is always within one mblk.
			 * - Assume the ethernet header is in the first mblk.
			 */
			ip = mblk->b_rptr + ethlen;
			if (ip >= mblk->b_wptr) {
				mblk = mblk->b_cont;
				ip = mblk->b_rptr;
			}
			iplen = IPH_HDR_LENGTH((ipha_t *)ip);
			tcp = ip + iplen;
			if (tcp >= mblk->b_wptr) {
				mblk = mblk->b_cont;
				tcp = mblk->b_rptr;
			}
			tcplen = TCP_HDR_LENGTH((tcph_t *)tcp);
			/* Careful, '>' instead of '>=' here */
			if (tcp + tcplen > mblk->b_wptr)
				mblk = mblk->b_cont;

			ol->om = VMXNET3_OM_TSO;
			ol->hlen = ethlen + iplen + tcplen;
			ol->msscof = DB_LSOMSS(mp);

			if (mblk != mp)
				ret = ol->hlen;
			else
				*to_copy = ol->hlen;
		}
	}

	return (ret);
}

/*
 * Map a msg into the Tx command ring of a vmxnet3s device.
 */
static vmxnet3s_txstatus_t
vmxnet3s_tx_one(vmxnet3s_softc_t *dp, vmxnet3s_txq_t *txq,
    vmxnet3s_offload_t *ol, mblk_t *mp, int to_copy)
{
	int		ret = VMXNET3_TX_OK;
	uint_t	frags = 0, totlen = 0;
	vmxnet3s_cmdring_t *cmdring = &txq->cmdring;
	vmxnet3s_txqctrl_t *txqctrl = txq->sharedctrl;
	vmxnet3s_gendesc_t *txdesc;
	uint16_t	sopidx;
	uint16_t	eopidx;
	uint8_t		sopgen;
	uint8_t		curgen;
	mblk_t		*mblk;
	uint_t	len;
	size_t		offset = 0;

	mutex_enter(&dp->txlock);

	sopidx = eopidx = cmdring->next2fill;
	sopgen = cmdring->gen;
	curgen = !cmdring->gen;

	mblk = mp;
	len = MBLKL(mblk);

	if (to_copy) {
		uint32_t	dw2;
		uint32_t	dw3;

		ASSERT(len >= to_copy);

		if (cmdring->avail <= 1) {
			dp->txmustresched = B_TRUE;
			ret = VMXNET3_TX_RINGFULL;
			goto error;
		}
		totlen += to_copy;

		len -= to_copy;
		offset = to_copy;

		bcopy(mblk->b_rptr, dp->txcache.nodes[sopidx].va, to_copy);

		eopidx = cmdring->next2fill;
		txdesc = VMXNET3_GET_DESC(cmdring, eopidx);

		ASSERT(txdesc->txd.gen != cmdring->gen);

		txdesc->txd.addr = dp->txcache.nodes[sopidx].pa;
		dw2 = to_copy;
		dw2 |= curgen << VMXNET3_TXD_GEN_SHIFT;
		txdesc->dword[2] = dw2;
		ASSERT(txdesc->txd.len == to_copy || txdesc->txd.len == 0);
		dw3 = 0;
		txdesc->dword[3] = dw3;

		VMXNET3_INC_RING_IDX(cmdring, cmdring->next2fill);
		curgen = cmdring->gen;

		frags++;
	}

	for (; mblk != NULL; mblk = mblk->b_cont, len = mblk ? MBLKL(mblk) : 0,
	    offset = 0) {
		ddi_dma_cookie_t cookie;
		uint_t cookiecount;

		if (len)
			totlen += len;
		else
			continue;

		if (ddi_dma_addr_bind_handle(dp->txdmahdl, NULL,
		    (caddr_t)mblk->b_rptr + offset, len,
		    DDI_DMA_RDWR | DDI_DMA_STREAMING, DDI_DMA_DONTWAIT, NULL,
		    &cookie, &cookiecount) != DDI_DMA_MAPPED) {
			ret = VMXNET3_TX_FAILURE;
			goto error;
		}

		ASSERT(cookiecount);

		do {
			uint64_t	addr = cookie.dmac_laddress;
			size_t		len = cookie.dmac_size;

			do {
				uint32_t	dw2;
				uint32_t	dw3;
				size_t		chunklen;

				ASSERT(!txq->metaring[eopidx].mp);
				ASSERT(cmdring->avail - frags);

				if (frags >= cmdring->size - 1 || (ol->om !=
				    VMXNET3_OM_TSO &&
				    frags >= VMXNET3_MAX_TXD_PER_PKT)) {
					(void) ddi_dma_unbind_handle(
					    dp->txdmahdl);
					ret = VMXNET3_TX_PULLUP;
					goto error;
				}
				if (cmdring->avail - frags <= 1) {
					dp->txmustresched = B_TRUE;
					(void) ddi_dma_unbind_handle(
					    dp->txdmahdl);
					ret = VMXNET3_TX_RINGFULL;
					goto error;
				}

				if (len > VMXNET3_MAX_TX_BUF_SIZE)
					chunklen = VMXNET3_MAX_TX_BUF_SIZE;
				else
					chunklen = len;

				frags++;
				eopidx = cmdring->next2fill;

				txdesc = VMXNET3_GET_DESC(cmdring, eopidx);
				ASSERT(txdesc->txd.gen != cmdring->gen);

				/* txd.addr */
				txdesc->txd.addr = addr;
				/* txd.dw2 */
				dw2 = chunklen == VMXNET3_MAX_TX_BUF_SIZE ? 0 :
				    chunklen;
				dw2 |= curgen << VMXNET3_TXD_GEN_SHIFT;
				txdesc->dword[2] = dw2;
				ASSERT(txdesc->txd.len == len ||
				    txdesc->txd.len == 0);
				/* txd.dw3 */
				dw3 = 0;
				txdesc->dword[3] = dw3;

				VMXNET3_INC_RING_IDX(cmdring,
				    cmdring->next2fill);
				curgen = cmdring->gen;

				addr += chunklen;
				len -= chunklen;
			} while (len);

			if (--cookiecount)
				ddi_dma_nextcookie(dp->txdmahdl, &cookie);
		} while (cookiecount);

		(void) ddi_dma_unbind_handle(dp->txdmahdl);
	}

	/* Update the EOP descriptor */
	txdesc = VMXNET3_GET_DESC(cmdring, eopidx);
	txdesc->dword[3] |= VMXNET3_TXD_CQ | VMXNET3_TXD_EOP;

	/* Update the SOP descriptor. Must be done last */
	txdesc = VMXNET3_GET_DESC(cmdring, sopidx);
	if (ol->om == VMXNET3_OM_TSO &&
	    txdesc->txd.len != 0 &&
	    txdesc->txd.len < ol->hlen) {
		ret = VMXNET3_TX_FAILURE;
		goto error;
	}
	txdesc->txd.om = ol->om;
	txdesc->txd.hlen = ol->hlen;
	txdesc->txd.msscof = ol->msscof;
	membar_producer();
	txdesc->txd.gen = sopgen;

	/* Update the meta ring & metadata */
	txq->metaring[sopidx].mp = mp;
	txq->metaring[eopidx].sopidx = sopidx;
	txq->metaring[eopidx].frags = frags;
	cmdring->avail -= frags;
	if (ol->om == VMXNET3_OM_TSO) {
		txqctrl->txnumdeferred += (totlen - ol->hlen + ol->msscof - 1) /
		    ol->msscof;
	} else {
		txqctrl->txnumdeferred++;
	}

	goto done;

error:
	/* Reverse the generation bits */
	while (sopidx != cmdring->next2fill) {
		VMXNET3_DEC_RING_IDX(cmdring, cmdring->next2fill);
		txdesc = VMXNET3_GET_DESC(cmdring, cmdring->next2fill);
		txdesc->txd.gen = !cmdring->gen;
	}

done:
	mutex_exit(&dp->txlock);

	return (ret);
}

/*
 * Send packets on a vmxnet3s device.
 */
mblk_t *
vmxnet3s_m_tx(void *data, mblk_t *mps)
{
	vmxnet3s_softc_t *dp = data;
	vmxnet3s_txq_t *txq = &dp->txq;
	vmxnet3s_cmdring_t *cmdring = &txq->cmdring;
	vmxnet3s_txqctrl_t *txqctrl = txq->sharedctrl;
	vmxnet3s_txstatus_t status = VMXNET3_TX_OK;
	mblk_t		*mp;

	ASSERT(mps != NULL);

	do {
		vmxnet3s_offload_t ol;
		int		pullup;
		int		to_copy;

		mp = mps;
		mps = mp->b_next;
		mp->b_next = NULL;

		if (DB_TYPE(mp) != M_DATA) {
			/*
			 * XXX M_PROTO mblks can be passed for some reason.
			 * Drop them because we don't understand them and
			 * their contents are not Ethernet frames anyway.
			 */
			ASSERT(B_FALSE);
			freemsg(mp);
			continue;
		}

		/*
		 * Prepare the offload while we're still handling the original
		 * message -- msgpullup() discards the metadata afterwards.
		 */
		to_copy = 0;
		pullup = vmxnet3s_tx_prepare_offload(dp, &ol, mp, &to_copy);
		if (pullup) {
			mblk_t *new_mp = msgpullup(mp, pullup);
			freemsg(mp);
			if (new_mp) {
				mp = new_mp;
				to_copy = pullup;
			} else {
				continue;
			}
		}

		/*
		 * Try to map the message in the Tx ring.
		 * This call might fail for non-fatal reasons.
		 */
		status = vmxnet3s_tx_one(dp, txq, &ol, mp, to_copy);
		if (status == VMXNET3_TX_PULLUP) {
			/*
			 * Try one more time after flattening
			 * the message with msgpullup().
			 */
			if (mp->b_cont != NULL) {
				mblk_t *new_mp = msgpullup(mp, -1);
				freemsg(mp);
				if (new_mp) {
					mp = new_mp;
					status = vmxnet3s_tx_one(dp, txq, &ol,
					    mp, to_copy);
				} else {
					continue;
				}
			}
		}
		if (status != VMXNET3_TX_OK && status != VMXNET3_TX_RINGFULL) {
			/* Fatal failure, drop it */
			freemsg(mp);
		}
	} while (mps && status != VMXNET3_TX_RINGFULL);

	if (status == VMXNET3_TX_RINGFULL) {
		mp->b_next = mps;
		mps = mp;
	} else {
		ASSERT(!mps);
	}

	/* Notify the device */
	mutex_enter(&dp->txlock);
	if (txqctrl->txnumdeferred >= txqctrl->txthreshold) {
		txqctrl->txnumdeferred = 0;
		VMXNET3_BAR0_PUT32(dp, VMXNET3_REG_TXPROD, cmdring->next2fill);
	}
	mutex_exit(&dp->txlock);

	return (mps);
}

/*
 * Parse a transmit queue and complete packets.
 */
boolean_t
vmxnet3s_tx_complete(vmxnet3s_softc_t *dp, vmxnet3s_txq_t *txq)
{
	vmxnet3s_cmdring_t *cmdring = &txq->cmdring;
	vmxnet3s_compring_t *compring = &txq->compring;
	vmxnet3s_gendesc_t *compdesc;
	boolean_t	completedtx = B_FALSE;
	boolean_t	ret = B_FALSE;

	mutex_enter(&dp->txlock);

	compdesc = VMXNET3_GET_DESC(compring, compring->next2comp);
	while (compdesc->tcd.gen == compring->gen) {
		vmxnet3s_metatx_t *sopmetadesc, *eopmetadesc;
		uint16_t	sopidx;
		uint16_t	eopidx;
		mblk_t		*mp;

		eopidx = compdesc->tcd.txdidx;
		eopmetadesc = &txq->metaring[eopidx];
		sopidx = eopmetadesc->sopidx;
		sopmetadesc = &txq->metaring[sopidx];

		ASSERT(eopmetadesc->frags);
		cmdring->avail += eopmetadesc->frags;

		ASSERT(sopmetadesc->mp);
		mp = sopmetadesc->mp;
		freemsg(mp);

		eopmetadesc->sopidx = 0;
		eopmetadesc->frags = 0;
		sopmetadesc->mp = NULL;

		completedtx = B_TRUE;

		VMXNET3_INC_RING_IDX(compring, compring->next2comp);
		compdesc = VMXNET3_GET_DESC(compring, compring->next2comp);
	}

	if (dp->txmustresched && completedtx) {
		dp->txmustresched = B_FALSE;
		ret = B_TRUE;
	}

	mutex_exit(&dp->txlock);

	return (ret);
}

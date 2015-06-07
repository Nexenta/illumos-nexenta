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
 * Source file containing the implementation of the driver
 * helper functions
 */

#include <oce_impl.h>

/*
 * function to breakup a block of memory into pages and return the address
 * in an array
 *
 * dbuf - pointer to structure describing DMA-able memory
 * pa_list - [OUT] pointer to an array to return the PA of pages
 * list_size - number of entries in pa_list
 */
void
oce_page_list(oce_dma_buf_t *dbuf,
    struct phys_addr *pa_list, int list_size)
{
	int i = 0;
	uint64_t paddr = 0;

	ASSERT(dbuf != NULL);
	ASSERT(pa_list != NULL);

	paddr = DBUF_PA(*dbuf);
	for (i = 0; i < list_size; i++) {
		pa_list[i].lo = ADDR_LO(paddr);
		pa_list[i].hi = ADDR_HI(paddr);
		paddr += PAGE_4K;
	}
} /* oce_page_list */

void
oce_gen_hkey(char *hkey, int key_size)
{
	int i;
	int nkeys = key_size/sizeof (uint32_t);
	for (i = 0; i < nkeys; i++) {
		(void) random_get_pseudo_bytes(
		    (uint8_t *)&hkey[i * sizeof (uint32_t)],
		    sizeof (uint32_t));
	}
}

int
oce_atomic_reserve(uint32_t *count_p, uint32_t n)
{
	uint32_t oldval;
	uint32_t newval;

	/*
	 * ATOMICALLY
	 */
	do {
		oldval = *count_p;
		if (oldval < n)
			return (-1);
		newval = oldval - n;

	} while (atomic_cas_32(count_p, oldval, newval) != oldval);

	return (newval);
}


/*
 * function to insert vtag to packet
 *
 * mp - mblk pointer
 * vlan_tag - tag to be inserted
 *
 * return none
 */
void
oce_insert_vtag(mblk_t *mp, uint16_t vlan_tag)
{
	struct ether_vlan_header  *evh;
	(void) memmove(mp->b_rptr - VTAG_SIZE,
	    mp->b_rptr, 2 * ETHERADDRL);
	mp->b_rptr -= VTAG_SIZE;
	evh = (struct ether_vlan_header *)(void *)mp->b_rptr;
	evh->ether_tpid = htons(VLAN_TPID);
	evh->ether_tci = htons(vlan_tag);
}

/*
 * function to strip  vtag from packet
 *
 * mp - mblk pointer
 *
 * return none
 */

void
oce_remove_vtag(mblk_t *mp)
{
	(void) memmove(mp->b_rptr + VTAG_SIZE, mp->b_rptr,
	    ETHERADDRL * 2);
	mp->b_rptr += VTAG_SIZE;
}

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
 * Driver Utility  function prototypes
 */

#ifndef _OCE_UTILS_H_
#define	_OCE_UTILS_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/types.h>
#include <sys/list.h>

/* logging macro */
#define	MOD_CONFIG	0x0001
#define	MOD_TX		0x0002
#define	MOD_RX		0x0004
#define	MOD_ISR		0x0008

#define	OCE_DEFAULT_LOG_SETTINGS	(CE_WARN	|	\
	((MOD_CONFIG | MOD_TX | MOD_RX) << 16UL))

#define	OCE_MAX_LOG_SETTINGS		(CE_IGNORE | ((MOD_CONFIG | MOD_TX | \
	MOD_RX | MOD_ISR) << 16UL))

#define	oce_log(dev_p, level, module, fmt, arg...) {	\
	if (dev_p) {					\
		if ((dev_p->mod_mask & module) && 	\
		    (dev_p->severity < CE_IGNORE) && 	\
		    ((uint32_t)level >= dev_p->severity)) 	\
			cmn_err(level, "%s[%d]: " fmt, OCE_MOD_NAME,	\
			    dev_p->dev_id, ## arg);			\
	} else {							\
		cmn_err(level, "%s[%d]: " fmt, OCE_MOD_NAME,		\
		    0, ## arg);						\
	}								\
}


/* Time related */
#define	OCE_USDELAY(x) drv_usecwait((x))
#define	OCE_MSDELAY(x) OCE_USDELAY((x) * 1000)

/* Misc Macros */
#define	OCE_LOG2(x) (highbit((x)) - 1)
#define	ADDR_LO(addr) (uint32_t)BMASK_32(addr) /* low 32 bits */
#define	ADDR_HI(addr) (uint32_t)BMASK_32((addr >> 32)) /* high 32 bits */
#define	ADDR_64(_HI, _LO) ((uint64_t)(((uint64_t)(_HI) << 32)|(_LO)))
#define	voidptr(x)	(void *)((x))
#define	u32ptr(x)	(uint32_t *)voidptr((x))
#define	ptrtou32(x)	(uint32_t)((uint32_t *)(void *)(x))

#define	PAGE_4K		(0x1UL << 12)
#define	OFFSET_IN_4K_PAGE(addr) ((off_t)((uint64_t)addr & (PAGE_4K - 1)))
#define	OCE_NUM_PAGES(size) howmany(size, PAGE_4K)


/* Utility Functions */

#define	OCE_DW_SWAP(datap, length)	{			\
	int len;	                                \
	uint32_t *wptr = (uint32_t *)(datap);                 \
	len = (length) + (((length)  %4) ? (4  - (4 %(length))) : 0); \
	for (len = len/4; len > 0; len--) {		\
		*wptr = LE_32(*wptr);			\
		wptr++;	                    \
	}							        \
}


#ifdef _BIG_ENDIAN
#define	DW_SWAP(_PTR, _LEN) OCE_DW_SWAP(_PTR, _LEN)
#else
#define	DW_SWAP(_PTR, _LEN)
#endif

/* externs for  list manipulation functions */

int oce_atomic_reserve(uint32_t *count_p, uint32_t n);

void oce_gen_hkey(char *hkey, int key_size);
void oce_insert_vtag(mblk_t *mp, uint16_t vlan_tag);
void oce_remove_vtag(mblk_t *mp);

#ifdef __cplusplus
}
#endif

#endif /* _OCE_UTILS_H_ */

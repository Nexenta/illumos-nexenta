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
 * Header file related to Ring handling
 *
 */

#ifndef _OCE_RING_H_
#define	_OCE_RING_H_

/*
 * helper functions
 */
void oce_group_rings(struct oce_dev *dev);
boolean_t oce_fill_rings_capab(struct oce_dev *, mac_capab_rings_t *);

/*
 * mac_capab_rings_t member functions
 */
void oce_get_ring(void *, mac_ring_type_t, const int, const int,
    mac_ring_info_t *, mac_ring_handle_t);
void oce_get_group(void *, mac_ring_type_t, const int, mac_group_info_t *,
    mac_group_handle_t);


/*
 * Ring level operations
 */
int oce_ring_start(mac_ring_driver_t, uint64_t);
void oce_ring_stop(mac_ring_driver_t);
mblk_t *oce_ring_tx(void *, mblk_t *);
mblk_t *oce_ring_rx_poll(void *, int);
uint_t oce_ring_common_drain(struct oce_eq *);
int oce_ring_intr_enable(mac_intr_handle_t);
int oce_ring_intr_disable(mac_intr_handle_t);
int oce_ring_rx_stat(mac_ring_driver_t, uint_t, uint64_t *);
int oce_ring_tx_stat(mac_ring_driver_t, uint_t, uint64_t *);


/*
 * Group level operations
 */
int oce_m_start_group(mac_group_driver_t);
void oce_m_stop_group(mac_group_driver_t);
int oce_group_addmac(void *, const uint8_t *);
int oce_group_remmac(void *, const uint8_t *);

#endif /* _OCE_RING_H_ */

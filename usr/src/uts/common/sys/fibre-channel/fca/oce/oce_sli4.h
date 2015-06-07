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
 * Header file containing the definitions specific to
 * SLI4 hardware
 */

#ifndef _OCE_SLI4_H_
#define	_OCE_SLI4_H_

/*			SLI_INTF		*/
#define	SLI_INTF_REG_OFFSET		0x58
#define	SLI_INTF_VALID_MASK		0xE0000000
#define	SLI_INTF_VALID			0xC0000000
#define	SLI_INTF_HINT2_MASK		0x1F000000
#define	SLI_INTF_HINT2_SHIFT		24
#define	SLI_INTF_HINT1_MASK		0x00FF0000
#define	SLI_INTF_HINT1_SHIFT		16
#define	SLI_INTF_FAMILY_MASK		0x00000F00
#define	SLI_INTF_FAMILY_SHIFT		8
#define	SLI_INTF_IF_TYPE_MASK		0x0000F000
#define	SLI_INTF_IF_TYPE_SHIFT		12
#define	SLI_INTF_REV_MASK		0x000000F0
#define	SLI_INTF_REV_SHIFT		4
#define	SLI_INTF_FT_MASK		0x00000001

/* SLI family */
#define	BE_SLI_FAMILY			0x0
#define	LANCER_A0_SLI_FAMILY		0xA

#define	LANCER_A0_CHIP(device)				\
	(device->sli_family == LANCER_A0_SLI_FAMILY)

/* Lancer SLIPORT_CONTROL SLIPORT_STATUS registers */
#define	SLIPORT_STATUS_OFFSET		0x404
#define	SLIPORT_CONTROL_OFFSET		0x408

#define	SLIPORT_STATUS_ERR_MASK		0x80000000
#define	SLIPORT_STATUS_RN_MASK		0x01000000
#define	SLIPORT_STATUS_RDY_MASK		0x00800000
#define	SLI_PORT_CONTROL_IP_MASK	0x08000000
#define	LANCER_IP_RESET					\
	(OCE_DB_WRITE32(dev, SLIPORT_CONTROL_OFFSET, SLI_PORT_CONTROL_IP_MASK))

/* Lancer POST offset in DB BAR */
#define	MPU_EP_SEMAPHORE_IF_TYPE2_OFFSET	0x400
#define	EP_SEMAPHORE_POST_STAGE_MASK	0x0000FFFF
#define	EP_SEMAPHORE_POST_ERR_MASK	0x1
#define	EP_SEMAPHORE_POST_ERR_SHIFT	31

/* Lancer POST Timeout */
#define	SLIPORT_READY_TIMEOUT		500

#endif /* _OCE_SLI4_H_ */

/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License, Version 1.0 only
 * (the "License").  You may not use this file except in compliance
 * with the License.
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
/*	Copyright (c) 1990, 1991 UNIX System Laboratories, Inc.	*/

/*	Copyright (c) 1984, 1986, 1987, 1988, 1989, 1990 AT&T	*/
/*	  All Rights Reserved	*/

#ifndef _SYS_ASCII_H
#define	_SYS_ASCII_H

#ifdef	__cplusplus
extern "C" {
#endif

#define	A_NUL	0	/* ^ @ */
#define	A_SOH	1	/* ^ A */
#define	A_STX	2	/* ^ B */
#define	A_ETX	3	/* ^ C */
#define	A_EOT	4	/* ^ D */
#define	A_ENQ	5	/* ^ E */
#define	A_ACK	6	/* ^ F */
#define	A_BEL	7	/* ^ G */
#define	A_BS	8	/* ^ H */
#define	A_HT	9	/* ^ I */
#define	A_NL	10	/* ^ J */
#define	A_LF	10	/* ^ J */
#define	A_VT	11	/* ^ K */
#define	A_FF	12	/* ^ L */
#define	A_NP	12	/* ^ L */
#define	A_CR	13	/* ^ M */
#define	A_SO	14	/* ^ N */
#define	A_SI	15	/* ^ O */
#define	A_DLE	16	/* ^ P */
#define	A_DC1	17	/* ^ Q */
#define	A_DC2	18	/* ^ R */
#define	A_DC3	19	/* ^ S */
#define	A_DC4	20	/* ^ T */
#define	A_NAK	21	/* ^ U */
#define	A_SYN	22	/* ^ V */
#define	A_ETB	23	/* ^ W */
#define	A_CAN	24	/* ^ X */
#define	A_EM	25	/* ^ Y */
#define	A_SUB	26	/* ^ Z */
#define	A_ESC	27	/* ^ [ */
#define	A_FS	28	/* ^ \ */
#define	A_GS	29	/* ^ ] */
#define	A_RS	30	/* ^ ^ */
#define	A_US	31	/* ^ _ */
#define	A_DEL	127	/* ^ ? */
#define	A_PAD	0x80	/* ESC @ */
#define	A_HOP	0x81	/* ESC A */
#define	A_BPH	0x82	/* ESC B */
#define	A_NBH	0x83	/* ESC C */
#define	A_IND	0x84	/* ESC D */
#define	A_NEL	0x85	/* ESC E */
#define	A_SSA	0x86	/* ESC F */
#define	A_ESA	0x87	/* ESC G */
#define	A_HTS	0x88	/* ESC H */
#define	A_HTJ	0x89	/* ESC I */
#define	A_VTS	0x8a	/* ESC J */
#define	A_PLD	0x8b	/* ESC K */
#define	A_PLU	0x8c	/* ESC L */
#define	A_RI	0x8d	/* ESC M */
#define	A_SS2	0x8e	/* ESC N */
#define	A_SS3	0x8f	/* ESC O */
#define	A_DCS	0x90	/* ESC P */
#define	A_PU1	0x91	/* ESC Q */
#define	A_PU2	0x92	/* ESC R */
#define	A_STS	0x93	/* ESC S */
#define	A_CCH	0x94	/* ESC T */
#define	A_MW	0x95	/* ESC U */
#define	A_SPA	0x96	/* ESC V */
#define	A_EPA	0x97	/* ESC W */
#define	A_SOS	0x98	/* ESC X */
#define	A_SGCI	0x99	/* ESC Y */
#define	A_SCI	0x9a	/* ESC Z */
#define	A_CSI	0x9b	/* ESC [ */
#define	A_ST	0x9c	/* ESC \ */
#define	A_OSC	0x9d	/* ESC ] */
#define	A_PM	0x9e	/* ESC ^ */
#define	A_APC	0x9f	/* ESC _ */

#ifdef	__cplusplus
}
#endif

#endif /* _SYS_ASCII_H */

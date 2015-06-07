/*
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * BSD 3 Clause License
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *      - Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *      - Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *      - Neither the name of Sun Microsystems, Inc. nor the
 *      names of its contributors may be used to endorse or promote products
 *      derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY SUN MICROSYSTEMS, INC. ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL SUN MICROSYSTEMS, INC. BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright 2015 Nexenta Systems, Inc. All rights reserved.
 */

#ifndef _NDMP_PROCESS_HDLR_TABLE_H
#define	_NDMP_PROCESS_HDLR_TABLE_H

/*
 * Some of the variables declared here also used by dump.c
 * Macros and variable required by main.c
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>
#include <ndmp.h>

#define	MAX_ARGS 40
#define	FILE_SYS 0
#define	INTERFACE 1
#define	ERROR_MSG 2
#define	LOG_FILE 3
#define	TAPEDEV 4
#define	SRC_MC 5
#define	DEST_MC 6
#define	SRCUSER 7
#define	SRCPSWD 8
#define	DESTUSR 9
#define	DESTPSWD 10
#define	ROBOT 11
#define	CONFFILE 12
#define	RECORDSIZE 13
#define	WINDOWSIZE 14
#define	ADDRTYPE 15
#define	RESTOREPATH 16
#define	TAPEMODE 17
#define	LOGLEVEL 18
#define	MOVER_MODE 19
#define	ADDR_TYPE 20
#define	BACKUP_TYPE 21
#define	MTIO_OP 22
#define	CDB 23
#define	WRITE_DATA 24
#define	DEVICE 25
#define	NDMPAUTH 26
#define	NDMPVERSION 27
#define	AUTHDIGEST 28
#define	CHALLENGE 29
#define	SUBMSG 30

#define	RELEASE1 1
#define	RELEASE2 2

typedef void PrintNdmpMsgFunc(FILE *out, void *ndmpMsg);

#ifdef __cplusplus
}
#endif

#endif /* _NDMP_PROCESS_HDLR_TABLE_H */

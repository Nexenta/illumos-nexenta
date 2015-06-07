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

#ifndef _NDMP_COMM_LIB_H
#define	_NDMP_COMM_LIB_H

/*
 * Library functions exposed. These functions are used by
 * mainly data and mover interfaces.
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <ndmp.h>
#include <process_hdlr_table.h>

#define	NDMP_TIME_OUT 5
#define	STD_BACKUP_TYPE_DUMP 1
#define	STD_BACKUP_TYPE_TAR 2

void print_ndmp_u_quad(FILE *outstream, ndmp_u_quad quad_t);
void print_ndmp_pval(FILE *outstream, ndmp_pval *pval);
void print_ndmp_tcp_addr(FILE *outstream, ndmp_tcp_addr *tcp_addr);
void print_ndmp_addr(FILE *outstream, ndmp_addr *addr);
ndmp_auth_type strToNdmpAuthType(char *str);
void print_ndmp_addr_type(FILE *outstream, ndmp_addr_type addr);
char *ndmpDataOperationToStr(ndmp_data_operation, char *);
char *ndmpDataStateToStr(ndmp_data_state, char *);
char *ndmpDataHaltReasonToStr(ndmp_data_halt_reason, char *);
ndmp_mover_state strToNdmpMoverState(char *);
ndmp_mover_pause_reason strToNdmpMoverPauseReason(char *);
ndmp_mover_halt_reason strToNdmpMoverHaltReason(char *);
char *ndmpMoverModeToStr(ndmp_mover_mode);
char *ndmpMoverStateToStr(ndmp_mover_state, char *);
char *ndmpMoverPauseReasonToStr(ndmp_mover_pause_reason, char *);
char *ndmpMoverHaltReasonToStr(ndmp_mover_halt_reason, char *);
ndmp_mover_mode strToNdmpMoverMode(char *);
ndmp_addr_type
convert_addr_type(char *);
ndmp_mover_mode
convert_mover_mode(char *);
int
convert_butype(char *);
int
print_intl_result(int, FILE *);
int
print_cleanup_result(int, FILE *);
int
print_intl_result(int, FILE *);
char *
ndmp_err_to_string(ndmp_error);
int
print_test_result(int, FILE *);
ndmp_tape_mtio_op
convert_tape_mtio_op(char *);
#ifdef __cplusplus
}
#endif

#endif /* _NDMP_COMM_LIB_H */

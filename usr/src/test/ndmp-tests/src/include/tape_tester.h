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

#ifndef _TAPE_TESTER_H
#define	_TAPE_TESTER_H

/*
 * Function declaration used by tape interface.
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <process_hdlr_table.h>
#include <ndmp_connect.h>

int tape_open_core(ndmp_error, char *, char *, FILE *, conn_handle *);
int tape_close_core(ndmp_error, FILE *, conn_handle *);
int
inf_tape_close(ndmp_error, char *, FILE *,  conn_handle *);
int
inf_tape_execute_cdb(ndmp_error, char *, char *, FILE *,  conn_handle *);
int
inf_tape_get_state(ndmp_error, char *, FILE *,  conn_handle *);
int
inf_tape_mtio(ndmp_error, char *, char *, FILE *,  conn_handle *);
int
inf_tape_open(ndmp_error, char *, char *, FILE *,  conn_handle *);
int
inf_tape_read(ndmp_error, char *, FILE *,  conn_handle *);
int
inf_tape_write(ndmp_error, char *, char *, FILE *,  conn_handle *);
int
tape_mtio_core(ndmp_error, char *, FILE *, conn_handle *);

#ifdef __cplusplus
}
#endif

#endif /* _TAPE_TESTER_H */

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

#ifndef _MOVER_H
#define	_MOVER_H

/*
 * Function declarations and constants used by mover and other
 * interface.
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <log.h>
#include <ndmp_connect.h>

#define	STD_REC_SIZE 8192
#define	STD_WIN_SIZE 8192000

extern int
inf_mover_set_rec_size(ndmp_error, char *, char *, FILE *, conn_handle *);
extern int
inf_mover_set_window_size(ndmp_error, char *,
    char *, FILE *,  conn_handle *);
extern int
inf_mover_connect(ndmp_error, char *, char *, char **,
    FILE *,  conn_handle *);
int
inf_mover_listen(ndmp_error, char *, char *, char *, FILE *,  conn_handle *);
extern int
inf_mover_read(ndmp_error, char *,
    FILE *,  conn_handle *);
extern int
inf_mover_get_state(ndmp_error, char *,
    FILE *,  conn_handle *);
extern int
inf_mover_continue(ndmp_error, char *,
    char *, FILE *,  conn_handle *);
extern int
inf_mover_close(ndmp_error, char *,
    char *, FILE *,  conn_handle *);
extern int
inf_mover_abort(ndmp_error, char *,
    FILE *,  conn_handle *);
extern int
inf_mover_stop(ndmp_error, char *,
    FILE *,  conn_handle *);

extern int
mover_set_window_core(ndmp_error, ndmp_u_quad *,
    ndmp_u_quad *, FILE *, conn_handle *);

extern int
mover_set_rec_size_core(ndmp_error, ulong_t,
    FILE *, conn_handle *);

extern int
mover_abort_core(ndmp_error, FILE *, conn_handle *);

extern int
mover_stop_core(ndmp_error, FILE *, conn_handle *);

extern int
mover_listen_core(ndmp_error, ndmp_mover_mode,
    ndmp_addr_type, void **, FILE *, conn_handle *);

ndmp_mover_state
get_mover_state(FILE *, conn_handle *);
#ifdef __cplusplus
}
#endif

#endif /* _MOVER_H */

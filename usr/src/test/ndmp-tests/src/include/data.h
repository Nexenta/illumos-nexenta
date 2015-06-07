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

#ifndef _DATA_H
#define	_DATA_H

#include <ndmp_connect.h>
#include <ndmp.h>

/*
 * Function declarations and constants for data
 * and other interface.
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	DATA_NVAL_LEN   5
/* NDMP_DATA_GET_STATE */

int
inf_data_abort(ndmp_error, char *, char *, FILE *, conn_handle *);
extern int
inf_data_get_state(ndmp_error, FILE *,  conn_handle *);
extern int
inf_data_connect(ndmp_error, char *, char *, char *, FILE *,  conn_handle *);
extern int
inf_data_listen(ndmp_error, char *, char *, FILE *,  conn_handle *);
extern int
inf_data_start_backup(ndmp_error, char *, char *, char *,
    FILE *,  conn_handle *);
int
inf_data_start_recover(ndmp_error, char *, char *,
    char *, FILE *,  conn_handle *);
int
inf_data_start_recover_filehist(ndmp_error, char *,
    char *, char *, FILE *,  conn_handle *);

extern int
data_start_backup_core(ndmp_error, char *, char *,
    FILE *, conn_handle *);
extern int
data_start_recover_core(ndmp_error, ndmp_message, char *, char *, FILE *,
    conn_handle *);
int
data_listen_core(ndmp_error, ndmp_addr_type, ndmp_addr **,
    FILE *, conn_handle *);
extern int
data_abort_core(ndmp_error, FILE *, conn_handle *);
extern int
data_stop_core(ndmp_error, FILE *, conn_handle *);
extern int
data_abort_core(ndmp_error, FILE *, conn_handle *);
int
data_connect_core(ndmp_error, ndmp_addr_type, void *, FILE *, conn_handle *);
int
data_start_recover_intl(ndmp_error, char *, FILE *, conn_handle *);
int
data_start_recover_cleanup(ndmp_error, FILE *, conn_handle *);
int
inf_data_get_env(ndmp_error, char *, char *, FILE *, conn_handle *);
int
inf_data_stop(ndmp_error, char *, FILE *, conn_handle *);
#ifdef __cplusplus
}
#endif

#endif /* _DATA_H */

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

#ifndef _NDMP_LIB_H
#define	_NDMP_LIB_H

/*
 * Macros and functions used by tape and scsi interfaces.
 * Some of them are also used by data and mover.
 */

#ifdef __cplusplus
extern "C" {
#endif

#include<stdio.h>
#include <ndmp_connect.h>
#include <ndmp.h>

#define	CDB_SIZE		6
#define	INQUIRYCDB		0
#define	UNLOADCDB		1
#define	MODESELECTCDB		2
#define	MODESENSECDB		3
#define	READCDB			4
#define	READBLOCKLIMITSCDB	5
#define	REWINDCDB		6
#define	SPACECDB		7
#define	TESTUNITREADYCDB	8
#define	WRITECDB		9
#define	WRITEFILEMARKSCDB	10
#define	MOVEMEDIUMCDB		11
#define	REQUESTSENSECDB		12
#define	SETTARGETPORTGROUPSCDB	13
#define	READELEMENTSTATUSCDB	14
#define	LOADCDB			15

typedef struct capability {
    uint_t capability_len;
    ndmp_pval *capability_val;
} capability;

typedef struct caplist {
    uint_t caplist_len;
    ndmp_device_capability *caplist_val;
} caplist;

typedef struct ext_version {
    uint_t ext_version_len;
    ushort_t *ext_version_val;
} ext_version;

typedef struct ndmp_selected_ext {
    uint_t ndmp_selected_ext_len;
    ndmp_class_version *ndmp_selected_ext_val;
} ndmp_selected_ext;

typedef struct class_list {
    uint_t class_list_len;
    ndmp_class_list *class_list_val;
} class_list;

typedef struct scsi_info {
    uint_t scsi_info_len;
    ndmp_device_info *scsi_info_val;
} scsi_info;

typedef struct tape_info {
    uint_t tape_info_len;
    ndmp_device_info *tape_info_val;
} tape_info;

typedef struct fs_info {
    uint_t fs_info_len;
    ndmp_fs_info *fs_info_val;
}fs_info;

typedef struct butype_info {
    uint_t butype_info_len;
    ndmp_butype_info *butype_info_val;
} butype_info;

typedef struct datain {
    uint_t datain_len;
    char *datain_val;
} datain;

typedef struct ext_sense {
    uint_t ext_sense_len;
    char *ext_sense_val;
} ext_sense;

typedef struct data_in {
    uint_t data_in_len;
    char *data_in_val;
} data_in;

typedef struct cdb {
    uint_t cdb_len;
    char *cdb_val;
} cdb;

typedef struct dataout {
    uint_t dataout_len;
    char *dataout_val;
} dataout;

typedef struct addr_types {
    uint_t addr_types_len;
    ndmp_addr_type *addr_types_val;
} addr_types;

/* Print functions start============= */
void    print_class_list(FILE *, class_list *);
void    print_scsi_info(FILE *out, scsi_info *scsiInfo);
void    print_tape_info(FILE *out, tape_info *tapeInfo);
void    print_fs_info(FILE *out, fs_info *fsInfo);
void    print_butype_info(FILE *out, butype_info *butypeInfo);
void    print_datain(FILE *out, void *rep, int);
void    print_ext_sense(FILE *out, void *rep);
void    print_data_in(FILE *out,  ndmp_tape_read_reply *rep);
void    print_ndmp_auth_data(FILE *out, ndmp_auth_data *auth_data);
void    print_addr_types(FILE *out, addr_types *addrType);
void    print_ndmp_auth_attr(FILE *out, ndmp_auth_attr *auth_attr);
/* Print functions end============= */

/* Memory cleaning functions start */
void clear_tape_write_request(void *);
void clear_execute_cdb_request(void *);
void clear_scsi_open_request(void *);
void clear_connect_client_auth_request(void *);
void clear_data_start_backup_request(void *);
void clear_data_start_recover_request(void *);
void clear_mover_connect_request(void *);

void clear_tape_read_reply(void *);
void clear_execute_cdb_reply(void *);
void clear_config_get_host_info(void *);
void clear_config_get_server_info(void *);
void clear_config_get_butype_info(void *);
void clear_config_get_fs_info(void *);
void clear_config_get_tape_info(void *);
void clear_config_get_scsi_info(void *);
void clear_connect_client_auth(void *);
void clear_connect_server_auth(void *, FILE *);
void clear_data_listen(void *);
void clear_data_get_state(void *);
void clear_data_get_env(void *);
void clear_mover_get_state(void *);
void clear_mover_listen(void *);
/* Memory cleaning functions end */

int getCdbNum(char *);
int create_cdb(cdb *, int);

#ifdef __cplusplus
}
#endif

#endif /* _NDMP_LIB_H */

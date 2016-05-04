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
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NFSTCL4_H
#define	_NFSTCL4_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <limits.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "tcl.h"
#include "nfs4_prot.h"

/* default NFS port to be used */
#define	NFS_PORT	2049

/* tcl procedure structure */
struct nfsproc {
	char *name;
	int (*func)();
};
typedef struct nfsproc NFSPROC;

/* nfsv4 operations structure */
struct nfsop {
	char *name;
	int (*func)();
};
typedef struct nfsop NFSOP;

/* attribute information structure */
struct attrinfo {
	char *name;
	int (*defunc)();
	int (*enfunc)();
};
typedef struct attrinfo ATTRINFO;

/* procedures of tcl commands */
extern int nfs_connect();
extern int nfs_disconnect();
extern int nfs_compound();
extern int nfs_nullproc();

/* nfsv4 operation/result functions */
extern int Access();
extern int Close();
extern int Commit();
extern int Create();
extern int Delegpurge();
extern int Delegreturn();
extern int Getattr();
extern int Getfh();
extern int Illegal();
extern int Link();
extern int Lock();
extern int Lockt();
extern int Locku();
extern int Lookup();
extern int Lookupp();
extern int Nverify();
extern int Open();
extern int Openattr();
extern int Open_confirm();
extern int Open_downgrade();
extern int Putfh();
extern int Putpubfh();
extern int Putrootfh();
extern int Read();
extern int Readdir();
extern int Readlink();
extern int Remove();
extern int Release_lockowner();
extern int Rename();
extern int Renew();
extern int Restorefh();
extern int Savefh();
extern int Secinfo();
extern int Setattr();
extern int Setclientid();
extern int Setclientid_confirm();
extern int Verify();
extern int Write();

extern int Access_res();
extern int Close_res();
extern int Commit_res();
extern int Create_res();
extern int Delegpurge_res();
extern int Getattr_res();
extern int Getfh_res();
extern int Illegal_res();
extern int Link_res();
extern int Lock_res();
extern int Lockt_res();
extern int Locku_res();
extern int Lookup_res();
extern int Lookupp_res();
extern int Nverify_res();
extern int Open_res();
extern int Openattr_res();
extern int Open_confirm_res();
extern int Open_downgrade_res();
extern int Putfh_res();
extern int Putpubfh_res();
extern int Putrootfh_res();
extern int Read_res();
extern int Readdir_res();
extern int Readlink_res();
extern int Release_lockowner_res();
extern int Remove_res();
extern int Rename_res();
extern int Renew_res();
extern int Restorefh_res();
extern int Savefh_res();
extern int Secinfo_res();
extern int Setattr_res();
extern int Setclientid_res();
extern int Setclientid_confirm_res();
extern int Verify_res();
extern int Write_res();
extern int compound_result();
extern void op_createcom();

/* attribute encode/decode functions */
extern int de_bool();
extern int de_time();
extern int de_uint64();
extern int de_uint32();
extern int de_type();
extern int de_bitmap();
extern int de_fsid();
extern int de_fhandle();
extern int de_mode();
extern int de_specdata();
extern int de_utf8string();
extern int de_stat4();
extern int de_unimpl();
extern int attr_decode();
extern int de_acl();
extern int de_fslocation();

extern int en_unimpl();
extern int en_uint64();
extern int en_uint32();
extern int en_type();
extern int en_bool();
extern int en_mode();
extern int en_specdata();
extern int en_time();
extern int en_timeset();
extern int en_utf8string();
extern int en_fhandle();
extern int en_fsid();
extern int en_stat4();
extern int attr_encode();
extern int en_acl();

/* utilities functions */
extern void prn_attrname();
extern int name2bit();
extern char *bit2name();
extern int names2alist();
extern char *errstr();
extern nfsstat4 str2err(char *);
extern char *bin2hex();
extern char *hex2bin();
extern int getbit();
extern void setbit();
extern utf8string *str2utf8();
extern char *utf82str();
extern char *itoa();
extern int str2pathname();
extern int names2bitmap();
extern char *access2name();
extern char *prn_ace4();
extern int substitution();
char *find_file(char *file, char *mypath, char *mysep);
extern int str2stateid();

/* ACL print functions */
extern char *out_ace4();
extern void out_ace4_type();
extern void out_ace4_flag();
extern void out_ace4_mask();
extern void ace4_check();

extern nfs_argop4 *new_argop();

/* functions for Open/Delegation */
extern int set_openclaim();
extern int set_opentype();
extern int set_owner();

#ifdef __cplusplus
}
#endif

#endif /* _NFSTCL4_H */

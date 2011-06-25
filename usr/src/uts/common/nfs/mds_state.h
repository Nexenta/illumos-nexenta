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
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _MDS_STATE_H
#define	_MDS_STATE_H

#ifdef	__cplusplus
extern "C" {
#endif

#include <sys/id_space.h>
#include <nfs/nfs4_db_impl.h>
#include <nfs/ds_prot.h>
#include <nfs/range.h>

#define	LO_GRANTED		0x00000001
#define	LO_RECALL_INPROG	0x00000002
#define	LO_RECALLED		0x00000004
#define	LO_RETURNED		0x00000008

struct mds_layout;

typedef struct mds_layout_grant {
	rfs4_dbe_t	*lo_dbe;
	stateid_t	lo_stateid;
	uint32_t	lo_status;
	kmutex_t	lo_lock;
	struct {
		uint32_t	lr_seqid;
		uint32_t	lr_reply;
	}		 lo_rec;
	struct mds_layout	*lo_lop;
	rfs4_client_t   *lo_cp;
	rfs4_file_t	*lo_fp;
	rfs41_grant_list_t lo_clientgrantlist;
	rfs41_grant_list_t lo_grant_list;
	nfs_range_t	*lo_range;
} mds_layout_grant_t;

#define	lor_seqid	lo_rec.lr_seqid
#define	lor_reply	lo_rec.lr_reply

typedef struct mds_ever_grant {
	rfs4_dbe_t	*eg_dbe;
	rfs4_client_t   *eg_cp;
	union {
		fsid_t	fsid;
		int64_t	key;
	} eg_un;
} mds_ever_grant_t;

#define	eg_fsid	eg_un.fsid
#define	eg_key	eg_un.key

/*
 * A ds_owner has a list of ds_addrlist entries and
 * a list of ds_guid entries. As an entry is added into
 * a list, it will bump the refcnts in both the ds_owner
 * and itself. It does this to prevent both references
 * from becoming invalid.
 *
 * This sounds nasty and recursive. It is. If an entry
 * destroy function is called without going through the
 * external linked list release functions, well, this
 * is your only warning not to do that.
 */
typedef struct ds_owner {
	rfs4_dbe_t	*dbe;
	time_t		last_access;
	char		*identity;
	ds_id		ds_id;
	ds_verifier	verifier;
	uint32_t	dsi_flags;
	list_t		ds_addrlist_list;
	list_t		ds_guid_list;
} ds_owner_t;

/*
 * Mapping of MDS_SID(s) (the MDS storage identifier) to
 * ds_guid; Saved on disk, held in memory for replies to
 * DS_REPORTAVAIL and DS_MAP_MDSSID.
 */
typedef struct {
	rfs4_dbe_t		*dbe;
	struct ds_guid_map	ds_map;
} mds_mapzap_t;

#define	MDS_DSI_REBOOTED	1

/*
 * Allow 4 bits for ds_validuse, the rest is
 * for our use.
 */
#define	MDS_DEV_DS_MASK		0x0000000F
#define	MDS_DEV_SKIP_ME		0x00000010
#define	MDS_DEV_NEW		0x00000020

#define	MDS_SET_DS_FLAGS(dst, flg) \
	dst = (dst & ~MDS_DEV_DS_MASK) | (MDS_DEV_DS_MASK & flg);

/*
 * Tracks the state 'handed out' to the data-server.
 */
typedef struct {
	rfs4_dbe_t	*dbe;
	ds_owner_t   	*ds_owner;
} mds_ds_state_t;

struct mds_adddev_args {
	int	dev_id;
	char	*dev_netid;
	char	*dev_addr;
	char	*ds_addr;
};

/*
 * Identify the dataset...
 */


typedef ds_guid ds_guid_t;

/*
 * Tracks the mds_sid to data-server guid, and
 * associated attributes.
 */
typedef struct {
	rfs4_dbe_t 	*dbe;
	ds_owner_t 	*ds_owner;
	list_node_t	ds_guid_next;
	ds_guid_t	ds_guid;	/* This is the mds_dataset_id */
	utf8string	ds_dataset_name;	/* Name of the dataset */
	uint_t    	ds_attr_len;
	ds_zfsattr 	*ds_attr_val;	/* XXX Should this be more general? */
	uint64_t	space_total;
	uint64_t	space_free;
} ds_guid_info_t;

/*
 * A small structure passed in the ds_storinfo create
 * entry.
 */
typedef struct {
	struct ds_storinfo	*si;
	ds_owner_t		*ds_owner;
} pinfo_create_t;

extern ds_guid_info_t *mds_find_ds_guid_info_by_id(ds_guid_t *guid);
extern int uaddr2sockaddr(int, char *, void *, in_port_t *);
extern bool_t rfs41_invalid_expiry(rfs4_entry_t);

#ifdef	__cplusplus
}
#endif

#endif /* _MDS_STATE_H */

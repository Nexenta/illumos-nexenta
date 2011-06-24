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
 *
 * Copyright 2011 Nexenta, Inc.  All rights reserved.
 */

#ifndef __NFS41_LAYOUT_H__
#define	__NFS41_LAYOUT_H__

#define	MDS_MAX_LAYOUT_DEVS 16

/*
 * A means to plop the internal uint32_t device
 * id into an OTW 128 bit device id
 */
typedef union {
	struct {
		uint32_t pad0;
		uint32_t pad1;
		uint32_t pad2;
		uint32_t did;
	} i;
	deviceid4 did4;
} ba_devid_t;

extern void mds_set_deviceid(id_t, deviceid4 *);

/*
 * mds_mpd:
 *
 * The fields mdp_encoded_* are in fact the already
 * encoded value for a nfsv4_1_file_layout_ds_addr4
 */
struct rfs4_dbe_t;
struct mds_sid;

typedef struct mds_mpd {
	rfs4_dbe_t	*mpd_dbe;
	id_t		mpd_id;
	uint_t		mpd_encoded_len;
	char		*mpd_encoded_val;
	list_t		mpd_layouts_list;
} mds_mpd_t;

/*
 * Used to build the reply to getdevicelist
 */
typedef struct mds_device_list {
	int		mdl_count;
	deviceid4	*mdl_dl;
} mds_device_list_t;

typedef struct layout_core {
	length4		lc_stripe_unit;
	int		lc_stripe_count;
	struct mds_sid	*lc_mds_sids;
} layout_core_t;

/*
 * mds_layout has the information for the layout that has been
 * allocated by the SPE. It is represented by the structure
 * "struct odl" or on-disk-layout the odl will be plopped
 * onto stable storage, once we know that a data-server
 * has requested verification for an IO operation.
 * --
 * stripe_unit gets plopped into a nfl_util4 in the returned
 * layout information;
 * --
 * lo_flags carries if we want dense or sparse data at the
 * data-servers and also if we wish the  NFS Client to commit
 * through the MDS or Data-servers.
 */
typedef struct mds_layout {
	rfs4_dbe_t	*mlo_dbe;
	int		mlo_id;
	layouttype4 	mlo_type;
	layout_core_t	mlo_lc;
	uint32_t	mlo_flags;
	mds_mpd_t	*mlo_mpd;
	id_t		mlo_mpd_id;
	list_node_t	mpd_layouts_next;
} mds_layout_t;

/* Functions */

extern mds_layout_t *pnfs_get_mds_layout(vnode_t *);
extern mds_layout_t *pnfs_add_mds_layout(vnode_t *, layout_core_t *);
extern void pnfs_delete_mds_layout(vnode_t *);
extern int pnfs_save_mds_layout(mds_layout_t *, vnode_t *);

extern void mds_layout_get(mds_layout_t *);
extern void mds_layout_put(mds_layout_t *);

extern int mds_get_odl(vnode_t *, mds_layout_t **);
extern void mds_nuke_layout(nfs_server_instance_t *, uint32_t);

extern void nfs41_layout_init(nfs_server_instance_t *);
extern void nfs41_device_init(nfs_server_instance_t *);

#endif	/* __NFS41_LAYOUT_H__ */

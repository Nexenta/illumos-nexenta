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
 * Use is subject to license terms.
 */

#ifndef __NFS41_DS_ADDR_H__
#define	__NFS41_DS_ADDR_H__

/*
 * ds_addrlist:
 *
 * This list is updated via the control-protocol
 * message DS_REPORTAVAIL.
 */
struct ds_owner;
struct mds_sid;

typedef struct ds_addlist {
	rfs4_dbe_t		*dbe;
	netaddr4		dev_addr;
	struct knetconfig	*dev_knc;
	struct netbuf		*dev_nb;
	uint_t			dev_flags;
	uint32_t		ds_port_key;
	uint64_t		ds_addr_key;
	struct ds_owner		*ds_owner;
	list_node_t		ds_addrlist_next;
} ds_addrlist_t;

extern ds_addrlist_t *mds_find_ds_addrlist(nfs_server_instance_t *, uint32_t);
extern ds_addrlist_t *mds_find_ds_addrlist_by_mds_sid(struct mds_sid *);
extern ds_addrlist_t *mds_find_ds_addrlist_by_uaddr(nfs_server_instance_t *,
    char *);
extern void mds_ds_addrlist_rele(ds_addrlist_t *);
extern void nfs41_ds_addr_init(nfs_server_instance_t *);

#endif	/* __NFS41_DS_ADDR_H__ */

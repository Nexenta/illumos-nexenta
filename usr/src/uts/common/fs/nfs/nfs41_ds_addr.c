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

#include <nfs/nfs4.h>
#include <nfs/mds_state.h>
#include <nfs/nfs41_ds_addr.h>
#include <nfs/nfs_config.h>

ds_addrlist_t *
mds_find_ds_addrlist_by_mds_sid(struct mds_sid *sid)
{
	ds_addrlist_t	*dp = NULL;
	ds_guid_info_t	*pgi;
	ds_owner_t	*dop;
	ds_guid_t	guid;

	/*
	 * Warning, do not, do not ever, free this guid!
	 */
	guid.stor_type = ZFS;
	guid.ds_guid_u.zfsguid.zfsguid_len = sid->len;
	guid.ds_guid_u.zfsguid.zfsguid_val = sid->val;

	/*
	 * First we need to find the ds_guid_info_t which
	 * corresponds to this mds_sid.
	 */
	pgi = mds_find_ds_guid_info_by_id(&guid);
	if (pgi == NULL)
		return (NULL);

	dop = pgi->ds_owner;
	if (!dop)
		goto error;

	/*
	 * XXX: If a ds_owner has multiple addresses, then just grab the first
	 * we find.
	 */
	dp = list_head(&dop->ds_addrlist_list);
	if (dp)
		rfs4_dbe_hold(dp->dbe);

error:

	rfs4_dbe_rele(pgi->dbe);
	return (dp);
}

ds_addrlist_t *
mds_find_ds_addrlist(nfs_server_instance_t *instp, uint32_t id)
{
	ds_addrlist_t *dp;
	bool_t create = FALSE;

	dp = (ds_addrlist_t *)rfs4_dbsearch(instp->ds_addrlist_idx,
	    (void *)(uintptr_t)id, &create, NULL, RFS4_DBS_VALID);
	return (dp);
}

void
mds_ds_addrlist_rele(ds_addrlist_t *dp)
{
	rfs4_dbe_rele(dp->dbe);
}

/*
 * -----------------------------------------------
 * MDS: DS_ADDR tables.
 * -----------------------------------------------
 *
 */

static uint32_t
ds_addrlist_hash(void *key)
{
	return ((uint32_t)(uintptr_t)key);
}

static bool_t
ds_addrlist_compare(rfs4_entry_t u_entry, void *key)
{
	ds_addrlist_t *dp = (ds_addrlist_t *)u_entry;

	return (rfs4_dbe_getid(dp->dbe) == (int)(uintptr_t)key);
}

static void *
ds_addrlist_mkkey(rfs4_entry_t entry)
{
	ds_addrlist_t *dp = (ds_addrlist_t *)entry;

	return ((void *)(uintptr_t)rfs4_dbe_getid(dp->dbe));
}

/*ARGSUSED*/
static bool_t
ds_addrlist_create(rfs4_entry_t u_entry, void *arg)
{
	ds_addrlist_t *dp = (ds_addrlist_t *)u_entry;
	struct mds_adddev_args *u_dp = (struct mds_adddev_args *)arg;

	dp->dev_addr.na_r_netid = kstrdup(u_dp->dev_netid);
	dp->dev_addr.na_r_addr = kstrdup(u_dp->dev_addr);
	dp->ds_owner = NULL;
	dp->dev_knc = NULL;
	dp->dev_nb = NULL;
	dp->ds_addr_key = 0;
	dp->ds_port_key = 0;

	return (TRUE);
}

/*ARGSUSED*/
static void
ds_addrlist_destroy(rfs4_entry_t u_entry)
{
	ds_addrlist_t *dp = (ds_addrlist_t *)u_entry;
	int	i;
	nfs_server_instance_t	*instp;

	instp = dbe_to_instp(u_entry->dbe);

	rw_enter(&instp->ds_addrlist_lock, RW_WRITER);
	if (dp->ds_owner != NULL) {
		list_remove(&dp->ds_owner->ds_addrlist_list, dp);
		rfs4_dbe_rele(dp->ds_owner->dbe);
		dp->ds_owner = NULL;
	}
	rw_exit(&instp->ds_addrlist_lock);

	if (dp->dev_addr.na_r_netid) {
		i = strlen(dp->dev_addr.na_r_netid) + 1;
		kmem_free(dp->dev_addr.na_r_netid, i);
	}

	if (dp->dev_addr.na_r_addr) {
		i = strlen(dp->dev_addr.na_r_addr) + 1;
		kmem_free(dp->dev_addr.na_r_addr, i);
	}

	if (dp->dev_knc != NULL)
		kmem_free(dp->dev_knc, sizeof (struct knetconfig));

	if (dp->dev_nb != NULL) {
		if (dp->dev_nb->buf)
			kmem_free(dp->dev_nb->buf, dp->dev_nb->maxlen);
		kmem_free(dp->dev_nb, sizeof (struct netbuf));
	}
}

static uint32_t
ds_addrlist_addrkey_hash(void *key)
{
	return ((uint32_t)(uintptr_t)key);
}

static void *
ds_addrlist_addrkey_mkkey(rfs4_entry_t entry)
{
	ds_addrlist_t *dp = (ds_addrlist_t *)entry;

	return (&dp->ds_addr_key);
}

/*
 * Only compare the address portion and not the
 * port info. We do this because the DS may
 * have rebooted and gotten a different port
 * number.
 *
 * XXX: What happens if we have multiple DSes
 * on one box? I.e., a valid case for the same
 * IP, but different ports?
 */
static int
ds_addrlist_addrkey_compare(rfs4_entry_t entry, void *key)
{
	ds_addrlist_t *dp = (ds_addrlist_t *)entry;
	uint64_t addr_key = *(uint64_t *)key;

	return (addr_key == dp->ds_addr_key);
}

/*
 * Data server addresses.
 */
void
nfs41_ds_addr_init(nfs_server_instance_t *instp)
{
	instp->ds_addrlist_tab = rfs4_table_create(instp,
	    "DSaddrlist", instp->reap_time, 2, ds_addrlist_create,
	    ds_addrlist_destroy, rfs41_invalid_expiry, sizeof (ds_addrlist_t),
	    MDS_TABSIZE, MDS_MAXTABSZ, 200);

	instp->ds_addrlist_idx = rfs4_index_create(instp->ds_addrlist_tab,
	    "dsaddrlist-idx", ds_addrlist_hash, ds_addrlist_compare,
	    ds_addrlist_mkkey, TRUE);

	instp->ds_addrlist_addrkey_idx =
	    rfs4_index_create(instp->ds_addrlist_tab,
	    "dsaddrlist-addrkey-idx", ds_addrlist_addrkey_hash,
	    ds_addrlist_addrkey_compare, ds_addrlist_addrkey_mkkey, FALSE);
}

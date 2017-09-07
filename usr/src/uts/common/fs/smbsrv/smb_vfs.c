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
 * Copyright (c) 2007, 2010, Oracle and/or its affiliates. All rights reserved.
 * Copyright 2017 Nexenta Systems, Inc.  All rights reserved.
 */

#include <sys/vfs.h>
#include <smbsrv/smb_ktypes.h>
#include <smbsrv/smb_kproto.h>

static void smb_vfs_destroy(smb_vfs_t *);

/*
 * smb_vfs_rele_all()
 *
 * Release all holds on root vnodes of file systems which were taken
 * due to the existence of at least one enabled share on the file system.
 * Called at driver close time.
 */
void
smb_vfs_rele_all(smb_export_t *se)
{
	smb_vfs_t	*smb_vfs;

	smb_llist_enter(&se->e_vfs_list, RW_WRITER);
	while ((smb_vfs = smb_llist_head(&se->e_vfs_list)) != NULL) {

		ASSERT(smb_vfs->sv_magic == SMB_VFS_MAGIC);
		DTRACE_PROBE1(smb_vfs_rele_all_hit, smb_vfs_t *, smb_vfs);
		smb_llist_remove(&se->e_vfs_list, smb_vfs);
		smb_vfs_destroy(smb_vfs);
	}
	smb_llist_exit(&se->e_vfs_list);
}

static void
smb_vfs_destroy(smb_vfs_t *smb_vfs)
{
	VN_RELE(smb_vfs->sv_rootvp);
	smb_vfs->sv_magic = (uint32_t)~SMB_VFS_MAGIC;
	kmem_cache_free(smb_kshare_cache_vfs, smb_vfs);
}

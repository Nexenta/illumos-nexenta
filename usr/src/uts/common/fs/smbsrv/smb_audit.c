/*
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 */

/*
 * Copyright 2018 Nexenta Systems, Inc.  All rights reserved.
 */

#include <smbsrv/smb_ktypes.h>
#include <smbsrv/smb_kproto.h>
#include <smbsrv/smb_fsops.h>

#include <c2/audit.h>
#include <c2/audit_kernel.h>

boolean_t
smb_audit_init(smb_request_t *sr)
{
	t_audit_data_t *tad;

	if (AU_ZONE_AUDITING(NULL) && sr->session->dialect >= SMB_VERS_2_BASE) {
		tad = T2A(curthread);
		tad->tad_sacl_ctrl = SACL_AUDIT_ON;
		bzero(&tad->tad_sacl_mask, sizeof (tad->tad_sacl_mask));
		return (B_TRUE);
	}
	return (B_FALSE);
}

void
smb_audit_fini(smb_request_t *sr, uint32_t desired, smb_node_t *node,
    boolean_t success)
{
	char *truepath;
	t_audit_data_t *tad;

	if (!AU_ZONE_AUDITING(NULL))
		return;

	tad = T2A(curthread);

	truepath = kmem_alloc(SMB_MAXPATHLEN, KM_SLEEP);
	/* We don't keep the resolved pathname around, so get it from here */
	smb_node_getpath_nofail(node, smb_audit_rootvp(sr), truepath,
	    SMB_MAXPATHLEN);
	audit_sacl(truepath, sr->user_cr, desired, success,
	    &tad->tad_sacl_mask);
	tad->tad_sacl_ctrl = SACL_AUDIT_NONE;
	kmem_free(truepath, SMB_MAXPATHLEN);
}

boolean_t
smb_audit_rename_init(smb_request_t *sr)
{
	t_audit_data_t *tad;

	if (AU_ZONE_AUDITING(NULL) && sr->session->dialect >= SMB_VERS_2_BASE) {
		tad = T2A(curthread);
		tad->tad_sacl_ctrl = SACL_AUDIT_NO_SRC;
		bzero(&tad->tad_sacl_mask, sizeof (tad->tad_sacl_mask));
		bzero(&tad->tad_sacl_mask_src, sizeof (tad->tad_sacl_mask_src));
		bzero(&tad->tad_sacl_mask_dest,
		    sizeof (tad->tad_sacl_mask_dest));
		return (B_TRUE);
	}
	return (B_FALSE);
}

void
smb_audit_rename_fini(smb_request_t *sr, char *src, smb_node_t *dir, char *dest,
    boolean_t success, boolean_t isdir)
{
	char *truepath;
	t_audit_data_t *tad;

	if (!AU_ZONE_AUDITING(NULL))
		return;

	tad = T2A(curthread);
	if (src != NULL) {
		audit_sacl(src, sr->user_cr, ACE_DELETE, success,
		    &tad->tad_sacl_mask_src);
	}
	if (dest != NULL) {
		audit_sacl(dest, sr->user_cr, ACE_DELETE, success,
		    &tad->tad_sacl_mask_dest);
	}

	truepath = kmem_alloc(SMB_MAXPATHLEN, KM_SLEEP);
	/* We don't keep the resolved pathname around, so get it from here */
	smb_node_getpath_nofail(dir, smb_audit_rootvp(sr), truepath,
	    SMB_MAXPATHLEN);
	audit_sacl(truepath, sr->user_cr,
	    isdir ? ACE_ADD_SUBDIRECTORY : ACE_ADD_FILE,
	    success, &tad->tad_sacl_mask);
	tad->tad_sacl_ctrl = SACL_AUDIT_NONE;
	kmem_free(truepath, SMB_MAXPATHLEN);
}

void
smb_audit_save()
{
	t_audit_data_t *tad;
	if (AU_ZONE_AUDITING(NULL)) {
		tad = T2A(curthread);
		tad->tad_sacl_backup = tad->tad_sacl_ctrl;
		tad->tad_sacl_ctrl = SACL_AUDIT_NONE;
	}
}

void
smb_audit_load()
{
	t_audit_data_t *tad = T2A(curthread);
	if (AU_ZONE_AUDITING(NULL) && tad->tad_sacl_backup != SACL_AUDIT_NONE)
		tad->tad_sacl_ctrl = tad->tad_sacl_backup;
}

vnode_t *
smb_audit_rootvp(smb_request_t *sr)
{
	return (AU_AUDIT_PERZONE() ?
	    sr->sr_server->si_root_smb_node->vp : rootdir);
}

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

/* ARGSUSED */
boolean_t
smb_audit_init(smb_request_t *sr)
{
	return (B_FALSE);
}

/* ARGSUSED */
void
smb_audit_fini(smb_request_t *sr, uint32_t desired, smb_node_t *node,
    boolean_t success)
{
}

/* ARGSUSED */
boolean_t
smb_audit_rename_init(smb_request_t *sr)
{
	return (B_FALSE);
}

/* ARGSUSED */
void
smb_audit_rename_fini(smb_request_t *sr, char *src, smb_node_t *dir, char *dest,
    boolean_t success, boolean_t isdir)
{
}

/* ARGSUSED */
void
smb_audit_save()
{
}

/* ARGSUSED */
void
smb_audit_load()
{
}

/* ARGSUSED */
vnode_t *
smb_audit_rootvp(smb_request_t *sr)
{
	return (NULL);
}

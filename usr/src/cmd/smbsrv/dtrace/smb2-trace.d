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
 * Copyright 2017 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * Example using the "smb2" dtrace provider.
 * Traces all SMB commands.
 *
 * All these probes provide:
 *	args[0]  conninfo_t
 *	args[1]  smb2opinfo_t
 * Some also provide one of: (not used here)
 *	args[2]  smb_open_args_t
 *	args[2]  smb_rw_args_t
 */

/*
 * Unfortunately, trying to write this as:
 *	smb2:::op-*-start {}
 *	smb2:::op-*-done {}
 * fails to compile with this complaint:
 *	dtrace: failed to compile script smb2-trace.d: line 41:
 *	args[ ] may not be referenced because probe description
 *	smb2:::op-*-start matches an unstable set of probes
 *
 * Not clear why listing them all is necessary,
 * but that works.
 */

smb2:::op-Cancel-start,
smb2:::op-ChangeNotify-start,
smb2:::op-Close-start,
smb2:::op-Create-start,
smb2:::op-Echo-start,
smb2:::op-Flush-start,
smb2:::op-Ioctl-start,
smb2:::op-Lock-start,
smb2:::op-Logoff-start,
smb2:::op-Negotiate-start,
smb2:::op-OplockBreak-start,
smb2:::op-QueryDirectory-start,
smb2:::op-QueryInfo-start,
smb2:::op-Read-start,
smb2:::op-SessionSetup-start,
smb2:::op-SetInfo-start,
smb2:::op-TreeConnect-start,
smb2:::op-TreeDisconnect-start,
smb2:::op-Write-start
{
	printf("clnt=%s mid=0x%x uid=0x%x tid=0x%x\n",
	       args[0]->ci_remote,
	       args[1]->soi_mid,
	       args[1]->soi_uid,
	       args[1]->soi_tid);
}

smb2:::op-Cancel-done,
smb2:::op-ChangeNotify-done,
smb2:::op-Close-done,
smb2:::op-Create-done,
smb2:::op-Echo-done,
smb2:::op-Flush-done,
smb2:::op-Ioctl-done,
smb2:::op-Lock-done,
smb2:::op-Logoff-done,
smb2:::op-Negotiate-done,
smb2:::op-OplockBreak-done,
smb2:::op-QueryDirectory-done,
smb2:::op-QueryInfo-done,
smb2:::op-Read-done,
smb2:::op-SessionSetup-done,
smb2:::op-SetInfo-done,
smb2:::op-TreeConnect-done,
smb2:::op-TreeDisconnect-done,
smb2:::op-Write-done
{
	printf("clnt=%s mid=0x%x status=0x%x\n",
	       args[0]->ci_remote,
	       args[1]->soi_mid,
	       args[1]->soi_status);
}

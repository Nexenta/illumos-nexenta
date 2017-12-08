#!/usr/sbin/dtrace -s
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
 * Developer dtrace program for smbsrv
 * Usage: dtrace -s smbsrv.d
 */

self int trace;
self int mask;

/*
 * Trace almost everything
 */
fbt:smbsrv::entry
{
	self->trace++;
}

/*
 * If traced and not masked, print entry/return
 */
fbt:smbsrv::entry
/self->trace > 0 && self->mask == 0/
{
	printf("\t0x%x", arg0);
	printf("\t0x%x", arg1);
	printf("\t0x%x", arg2);
	printf("\t0x%x", arg3);
	printf("\t0x%x", arg4);
	printf("\t0x%x", arg5);
}

/*
 * Mask (don't print) all function calls below these functions.
 * These make many boring, repetitive function calls like
 * smb_mbtowc, mbc_marshal_...
 */
fbt::smb_mbc_vdecodef:entry,
fbt::smb_mbc_vencodef:entry,
fbt::smb_msgbuf_decode:entry,
fbt::smb_msgbuf_encode:entry,
fbt::smb_strlwr:entry,
fbt::smb_strupr:entry,
fbt::smb_wcequiv_strlen:entry
{
	self->mask++;
}

/*
 * Now inverses of above, unwind order.
 */

fbt::smb_mbc_vdecodef:return,
fbt::smb_mbc_vencodef:return,
fbt::smb_msgbuf_decode:return,
fbt::smb_msgbuf_encode:return,
fbt::smb_strlwr:return,
fbt::smb_strupr:return,
fbt::smb_wcequiv_strlen:return
{
	self->mask--;
}

fbt:smbsrv::return
/self->trace > 0 && self->mask == 0/
{
	printf("\t0x%x", arg1);
}

fbt:smbsrv::return
{
	self->trace--;
}

/*
 * Use the "smb" dtrace provider.
 */

smb:::op-CheckDirectory-start,
smb:::op-Close-start,
smb:::op-CloseAndTreeDisconnect-start,
smb:::op-ClosePrintFile-start,
smb:::op-Create-start,
smb:::op-CreateDirectory-start,
smb:::op-CreateNew-start,
smb:::op-CreateTemporary-start,
smb:::op-Delete-start,
smb:::op-DeleteDirectory-start,
smb:::op-Echo-start,
smb:::op-Find-start,
smb:::op-FindClose-start,
smb:::op-FindClose2-start,
smb:::op-FindUnique-start,
smb:::op-Flush-start,
smb:::op-GetPrintQueue-start,
smb:::op-Invalid-start,
smb:::op-Ioctl-start,
smb:::op-LockAndRead-start,
smb:::op-LockByteRange-start,
smb:::op-LockingX-start,
smb:::op-LogoffX-start,
smb:::op-Negotiate-start,
smb:::op-NtCancel-start,
smb:::op-NtCreateX-start,
smb:::op-NtRename-start,
smb:::op-NtTransact-start,
smb:::op-NtTransactCreate-start,
smb:::op-NtTransactSecondary-start,
smb:::op-Open-start,
smb:::op-OpenPrintFile-start,
smb:::op-OpenX-start,
smb:::op-ProcessExit-start,
smb:::op-QueryInformation-start,
smb:::op-QueryInformation2-start,
smb:::op-QueryInformationDisk-start,
smb:::op-Read-start,
smb:::op-ReadRaw-start,
smb:::op-ReadX-start,
smb:::op-Rename-start,
smb:::op-Search-start,
smb:::op-Seek-start,
smb:::op-SessionSetupX-start,
smb:::op-SetInformation-start,
smb:::op-SetInformation2-start,
smb:::op-Transaction-start,
smb:::op-Transaction2-start,
smb:::op-Transaction2Secondary-start,
smb:::op-TransactionSecondary-start,
smb:::op-TreeConnect-start,
smb:::op-TreeConnectX-start,
smb:::op-TreeDisconnect-start,
smb:::op-UnlockByteRange-start,
smb:::op-Write-start,
smb:::op-WriteAndClose-start,
smb:::op-WriteAndUnlock-start,
smb:::op-WritePrintFile-start,
smb:::op-WriteRaw-start,
smb:::op-WriteX-start
{
	printf("clnt=%s mid=0x%x uid=0x%x tid=0x%x\n",
	       args[0]->ci_remote,
	       args[1]->soi_mid,
	       args[1]->soi_uid,
	       args[1]->soi_tid);
}

smb:::op-CheckDirectory-done,
smb:::op-Close-done,
smb:::op-CloseAndTreeDisconnect-done,
smb:::op-ClosePrintFile-done,
smb:::op-Create-done,
smb:::op-CreateDirectory-done,
smb:::op-CreateNew-done,
smb:::op-CreateTemporary-done,
smb:::op-Delete-done,
smb:::op-DeleteDirectory-done,
smb:::op-Echo-done,
smb:::op-Find-done,
smb:::op-FindClose-done,
smb:::op-FindClose2-done,
smb:::op-FindUnique-done,
smb:::op-Flush-done,
smb:::op-GetPrintQueue-done,
smb:::op-Invalid-done,
smb:::op-Ioctl-done,
smb:::op-LockAndRead-done,
smb:::op-LockByteRange-done,
smb:::op-LockingX-done,
smb:::op-LogoffX-done,
smb:::op-Negotiate-done,
smb:::op-NtCancel-done,
smb:::op-NtCreateX-done,
smb:::op-NtRename-done,
smb:::op-NtTransact-done,
smb:::op-NtTransactCreate-done,
smb:::op-NtTransactSecondary-done,
smb:::op-Open-done,
smb:::op-OpenPrintFile-done,
smb:::op-OpenX-done,
smb:::op-ProcessExit-done,
smb:::op-QueryInformation-done,
smb:::op-QueryInformation2-done,
smb:::op-QueryInformationDisk-done,
smb:::op-Read-done,
smb:::op-ReadRaw-done,
smb:::op-ReadX-done,
smb:::op-Rename-done,
smb:::op-Search-done,
smb:::op-Seek-done,
smb:::op-SessionSetupX-done,
smb:::op-SetInformation-done,
smb:::op-SetInformation2-done,
smb:::op-Transaction-done,
smb:::op-Transaction2-done,
smb:::op-Transaction2Secondary-done,
smb:::op-TransactionSecondary-done,
smb:::op-TreeConnect-done,
smb:::op-TreeConnectX-done,
smb:::op-TreeDisconnect-done,
smb:::op-UnlockByteRange-done,
smb:::op-Write-done,
smb:::op-WriteAndClose-done,
smb:::op-WriteAndUnlock-done,
smb:::op-WritePrintFile-done,
smb:::op-WriteRaw-done,
smb:::op-WriteX-done
{
	printf("clnt=%s mid=0x%x status=0x%x\n",
	       args[0]->ci_remote,
	       args[1]->soi_mid,
	       args[1]->soi_status);
}

/*
 * Use the "smb2" dtrace provider.
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

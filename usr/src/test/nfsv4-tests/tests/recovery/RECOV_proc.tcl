#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

# TESTROOT directory; must be set in the environment already
set TESTROOT $env(TESTROOT)

# include common code and init environment
source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]

# TCL procedure for OPEN operation testing
# NFSv4 constant:
set OPEN4_RESULT_CONFIRM        2

set SRVPROG srv_ckshare

#---------------------------------------------------------
# Test procedure to close the file; but also Open_confirm (if needed).
#  Usage: ckclose nfh rflags seqid sid
#         nfh:         the filehandle to be closed
#        rflags:  the rflags for OPEN_CONFIRM
#        seqid:   the sequence id
#        sid:     the state id 
#
#  Return: 
#        true:          Close succeed
#        false:         things failed during the process
#
proc ckclose {nfh rflags seqid sid} {
    global DEBUG OPEN4_RESULT_CONFIRM

    set cont true
    if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
        putmsg stderr 1 "  Open_confirm $sid $seqid"
        set res [compound {Putfh $nfh; Open_confirm $sid $seqid}]
        if {$status != "OK"} {
            putmsg stderr 0 \
                "\t Test FAIL: Open_confirm failed, status=($status)."
            putmsg stderr 1 "\t   res=($res)"
            set cont false
        }
        set sid [lindex [lindex $res 1] 2]
        incr seqid
    }
    # verify the filehandle of OPEN is good to close and same as LOOKUP
    if {$cont == "true"} {
        # Close the file
        putmsg stderr 1 "  Close $seqid $sid"
        set res [compound {Putfh $nfh; Close $seqid $sid}]
        if {$status != "OK"} {
            putmsg stderr 0 \
                "\t Test FAIL: Close failed, status=($status)."
            putmsg stderr 1 "\t   res=($res)"
            set cont false
        }
    }
    return $cont
}

#-----------------------------------------------------------------------
# Test procedure to check if the grace period is end or not
#  Usage: ckgrace_period [type]
#	type	exit status type if the checking fail, default UNRESOLVED
#
#  Return: 
#       nothing
#
proc ckgrace_period {{type UNRESOLVED}} {
    global MNTPTR DELM

    if {[catch {exec echo "xxx" > $MNTPTR${DELM}wait_for_grace} msg]} {
        putmsg stdout 0 "Failed to check the grace period"
        putmsg stdout 0 "\t msg=($msg)"
        file delete $MNTPTR${DELM}wait_for_grace
        cleanup $type
    }
    file delete $MNTPTR${DELM}wait_for_grace
}

#-----------------------------------------------------------------------
# Test procedure to disconnect and exit with specific status
#  Usage: cleanup exit_status
#
#  Return: 
#       nothing
#
proc cleanup {exit_status} {
    Disconnect
    exit $exit_status
}

#-----------------------------------------------------------------------
# Test procedure to reboot the server
#  Usage: reboot_server TmpFile tag
#	TmpFile	the temp file for logging the output of the command
#	tag	the test case name which calls this procedure
#
#  Return: 
#       nothing
#
proc reboot_server {TmpFile tag} {
    global SERVER UNRESOLVED

    if {[catch {exec isserverup reboot 2> $TmpFile} msg]} {
        putmsg stdout 0 "$tag: Reboot the server $SERVER"
        putmsg stdout 0 "\t Test UNRESOLVED: failed to reboot server $SERVER"
        putmsg stdout 0 "\t msg=($msg)"
        putmsg stderr 0 "\t err=([exec cat $TmpFile])"
        file delete $TmpFile
        if { [file exists $TmpFile] != 0 } {
            putmsg stdout 0 "\t WARNING: TmpFile=($TmpFile) was not removed"
            putmsg stdout 0 "\t   please cleanup manually."
        }
        cleanup $UNRESOLVED
    }
    file delete $TmpFile
    if { [file exists $TmpFile] != 0 } {
        putmsg stdout 0 "\t WARNING: TmpFile=($TmpFile) was not removed"
        putmsg stdout 0 "\t   please cleanup manually."
    }
}

#-----------------------------------------------------------------------
# Test procedure to check if the nfsd is up or not
#  Usage: is_nfsd_up tag
#	tag	the test case name which calls this procedure
#
#  Return: 
#       nothing
#
proc is_nfsd_up {tag} {
    global BASEDIRS NOTICEDIR UNRESOLVED

    set i 0
    set path "$BASEDIRS $NOTICEDIR DONE_reboot"
    set res [compound {Putrootfh; foreach c $path {Lookup $c}; Getfh}]
    while { $status != "OK" } {
        if { $i < 300 } {
            incr i
            after 1000
            set res [compound {Putrootfh; foreach c $path {Lookup $c}; Getfh}]
        } else {
            putmsg stdout 0 "$tag: Reboot: nfsd failed"
            putmsg stdout 0 "\t Test UNRESOLVED: server reboot failed"
            putmsg stdout 0 "\t status=$status"
            putmsg stdout 0 "\t res=$res"
            cleanup $UNRESOLVED
        }
    }
}

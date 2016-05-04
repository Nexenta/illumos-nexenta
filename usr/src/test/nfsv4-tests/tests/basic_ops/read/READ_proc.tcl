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
# Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# TCL procedure for READ operation testing

#---------------------------------------------------------
# Test procedure to Open and Read a file and check for len and EOF flag.
#  Usage: ckread dfh fname off cnt expcode explen expeof prn
# 	dfh:	 the directory filehandle where $fname located
# 	fname:	 the filename of the file to be Opened/Read
#	off:	 the offset to Read
#	cnt:	 the count of bytes to Read
#	expcode: the expected status code from the Read op
#	explen:  the expected length Read
#	expeof:  the expected EOF flag from Read op
#	prn:  	 the flag to print PASS/FAIL message
#
#  Return: 
#	0:  	Write success
#	-1: 	things failed during the process
#
proc ckread {dfh fname off cnt expcode explen expeof {prn 0}} {
    global DEBUG

    # First set/get the clientid
    set owner "[pid]-[expr int([expr [expr rand()] * 100000000])]"
    set clientid [getclientid $owner 0 0 0]
    if {$clientid == -1} {
	putmsg stderr 0 "\t Test UNRESOLVED: getclientid failed"
	return -1
    }
    set cid_owner "$clientid $owner"

    # Now open the file for read
    set otype 0
    set nfh [basic_open $dfh $fname $otype $cid_owner open_sid oseqid status\
	10 0 600 0 1]
    if {$nfh == -1} {
	putmsg stderr 0 \
		"\t Test UNRESOLVED: basic_open() failed, status=$status"
	return -1
    }

    # Now read the file
    if {($cnt == 0) || (($cnt > 1) && ($cnt < 32768))} {
        set rres [compound {Putfh $nfh; Read "$open_sid" $off $cnt}]
	set rstatus $status
      	  putmsg stdout 2 "\nRead {$open_sid} $off $cnt ..."
      	  putmsg stdout 2 "Res: $rres"
    } else {
        set eof "false"
        while {$eof != "true"} {
            set rres [compound {Putfh $nfh; Read "$open_sid" $off $cnt}]
	    set rstatus $status
      	      putmsg stdout 2 "\nRead {$open_sid} $off $cnt ..."
      	      putmsg stdout 2 "Res: $rres"
	    set eof [lindex [lindex [lindex [lindex $rres 1] 2] 0 ] 1]
	    set off [expr $off + $cnt] 
	}
    }
    set oseqid [expr $oseqid + 1]
    set res [compound {Putfh $nfh; Close $oseqid $open_sid}]
      putmsg stdout 2 "\nClose $oseqid $open_sid ... "
      putmsg stdout 2 "Res: $res"

    # Now check for expected results
    if {$rstatus != $expcode} {
	putmsg stderr 0 \
		"\t Test FAIL: Read returned ($status), expected ($expcode)"
	putmsg stderr 1 "\t   res=($rres)"
	putmsg stderr 1 "  "
	return -1
    } else {
	set len [lindex [lindex [lindex [lindex $rres 1] 2] 1 ] 1]
	set eof [lindex [lindex [lindex [lindex $rres 1] 2] 0 ] 1]
        if {($explen != -1) && ($len != $explen)} {
            putmsg stderr 0 \
	    "\t Test FAIL: Read returned len=($len), expected=($explen)"
	    putmsg stderr 1 "  "
            return -1
        } 
        if {("$expeof" != "") && ("$eof" != "$expeof")} {
            putmsg stderr 0 \
	    "\t Test FAIL: Read returned eof=($eof), expected=($expeof)"
	    putmsg stderr 1 "  "
            return -1
        } 
	if {$prn == 0} {
            putmsg stdout 0 "\t Test PASS"
	}
	return 0
    }
}

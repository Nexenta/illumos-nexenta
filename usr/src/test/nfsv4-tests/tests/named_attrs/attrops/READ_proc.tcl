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
    global DEBUG OPEN4_RESULT_CONFIRM

    # Open the file for read
    set owner "[pid]-[expr int([expr [expr rand()] * 100000000])]"
    set clientid [getclientid $owner]
      putmsg stdout 2 "\ngetclientid $owner ..."
    set oseqid 1
    set otype 0
    set mode 0664
    set oclaim 0
    set res [compound {Putfh $dfh; 
        Open $oseqid 1 0 {$clientid $owner} \
        {$otype 0 {{mode $mode} {size $size}}} {$oclaim $fname};
	Getfh; Getattr {mode}}]
      putmsg stdout 2 "\nOpen $fname ..."
      putmsg stdout 2 "Res: $res"
      if {$status != "OK"} {
	putmsg stderr 0 "\t Test UNRESOLVED: Open failed"
	putmsg stdout 0 "\t   Open ($fname) returned $status"
	putmsg stderr 0 "\t Res=($res)\n"
	return -1
      }
    set open_sid [lindex [lindex $res 1] 2]
    set rflags [lindex [lindex $res 1] 4] 
    set nfh [lindex [lindex $res 2] 2]
    set attr [lindex [lindex $res 3] 2]
    incr oseqid
    if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	set res [compound {Putfh $nfh; Open_confirm "$open_sid" $oseqid}]
	  putmsg stdout 2 "\nOpen_confirm {$open_sid} $oseqid ..."
	  putmsg stdout 2 "Res: $res"
	if {$status != "OK"} {
	    putmsg stderr 0 "\t Test UNRESOLVED: Open_confirm failed"
	    putmsg stdout 0 "\t   Open_confirm returned $status"
	    putmsg stderr 0 "\t Res=($res)\n"
	    return -1
	}
	set open_sid [lindex [lindex $res 1] 2]
	incr oseqid
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
	if {$prn == 0} {
            putmsg stdout 0 "\t Test PASS"
	}
	return 0
    }
}

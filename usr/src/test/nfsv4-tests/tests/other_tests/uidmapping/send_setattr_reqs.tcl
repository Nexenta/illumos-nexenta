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
# send_setattr_reqs.tcl - loop to send multiple SETATTR requests 
# to generate server side kernel upcall to nfsmapid
#
# Usage: 
#    nfsh send_setattr_reqs.tcl <file_path> <number_of_reqs>
#       file_path - path to the testfile
#       number_of_reqs - the number of requests to be sent. 

# Get the TESTROOT directory
set TESTROOT $env(TESTROOT)

source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]
source [file join ${TESTROOT} lcltools]

# setting local variables
set TNAME $argv0

if { $argc != 2 } {
   putmsg stderr 0 "$TNAME <file_path> <number_of_reqs>"
   putmsg stderr 0 "\tfile_path - path to the testfile"
   putmsg stderr 0 "\tnumber_of_reqs - the number of requests to be sent."
   exit $UNINITIATED
}

set TESTFILE [lindex $argv 0]
set LOOP [lindex $argv 1]

putmsg stdout 0 "\n"
putmsg stdout 0 "$TNAME: sending $LOOP SETATTR requests to server to genereate kernel upcalls to nfsmapid"

# connect to the test server
Connect

set comp [ path2comp $TESTFILE $DELM ]
set domain $env(Cdomain)
set stateid {0 0}
set exp "* {Setattr BADOWNER {}}"

set i 0
while { ${i} < $LOOP } {
    set fowner "fakeuser${i}@$domain"
    if { [ catch { 
       set res [ compound {
          Putrootfh; foreach c $comp {Lookup $c};
          Setattr $stateid {{owner $fowner}}}]}]} { 
       putmsg stderr 0 "\tERROR: rpc call failed for fakeuser${i}@$domain"
       putmsg stderr 0 "\tresult: $res"
       Disconnect
       exit $FAIL
    } 

    # get server's reply, check the result
    if { ![string match $exp $res] } {
       putmsg stderr 0 "\tERROR: unexpected return result for fakeuser${i}@$domain"
       putmsg stderr 0 "\tresult: $res"
       Disconnect
       exit $FAIL
    }

    set fgroup "fakegroup${i}@$domain"
    if { [ catch { 
       set res [compound {
          Putrootfh; foreach c $comp {Lookup $c};
          Setattr $stateid {{owner_group $fgroup}}}]}]} {
       putmsg stderr 0 "\tERROR: rpc call failed for fakegroup${i}@$domain"
       putmsg stderr 0 "\tresult: $res"
       Disconnect
       exit $FAIL
    }

    # get server's reply, check the result
    if { ![string match $exp $res] } {
       putmsg stderr 0 "\tERROR: unexpected return result for fakegroup${i}@$domain"
       putmsg stderr 0 "\tresult: $res"
       Disconnect
       exit $FAIL
    }

	incr i
}

putmsg stdout 0 "$TNAME: test run completed successfully"

# disconnect and exit
Disconnect
exit $PASS

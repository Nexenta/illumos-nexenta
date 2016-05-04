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
# NFSv4 RENAME operation test - negative tests

# include all test enironment
source RENAME.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Rename with newname not empty, expect NOTEMPTY|EXIST
set expcode "NOTEMPTY|EXIST"
set ASSERTION "Rename with newname not empty, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Rename $env(LARGEDIR) $env(DIR0755)}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "$env(LARGEDIR)"}]
      if { $status == "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: oldname is gone after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	  logres PASS
      }
  }


# b: try to Rename when FS has no more quota, expect DQUOT
set expcode "DQUOT"
set ASSERTION "Rename while target has no more quota, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
putmsg stdout 0 \
	"\t Test UNSUPPORTED: Invalid for Solaris."
putmsg stdout 1 "\t\t Solaris server does not require disk allocation."


# c: try to Rename when FS has no more inode, expect NOSPC
set expcode "NOSPC"
set ASSERTION "Rename while target FS has no more inode, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
#set nsfh [get_fh [path2comp $env(NSPCDIR) $DELM]]
#set res [compound {Putfh $nsfh; Savefh; Rename $env(RWFILE) "RendirC.[pid]" }]
#set cont [ckres "Rename" $status $expcode $res $FAIL]
## check oldname still exist
#  if {! [string equal $cont "false"]} {
#      set res [compound {Putfh $bfh; Lookup "$env(RWFILE)"}]
#      if { $status == "NOENT" } {
#	  putmsg stderr 0 "\t Test FAIL: oldname is gone after Rename failed"
#	  putmsg stderr 1 "\t   res=($res)"
#      } else {
#	logres PASS
#      }
#  }
putmsg stdout 0 \
	"\t Test UNSUPPORTED: Invalid for Solaris."
putmsg stdout 1 "\t\t Solaris server does not require disk allocation."


# h: try to Rename when FS is READONLY, expect ROFS
set expcode "ROFS"
set ASSERTION "Rename while target FS is READONLY, expect $expcode"
putmsg stdout 0 "$TNAME{h}: $ASSERTION"
set rofh [get_fh [path2comp $env(ROFSDIR) $DELM]]
set res [compound {Putfh $rofh; Savefh; Rename $env(DIR0755) "Newd"}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $rofh; Lookup "$env(DIR0755)"}]
      if { $status == "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: oldname is gone after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS

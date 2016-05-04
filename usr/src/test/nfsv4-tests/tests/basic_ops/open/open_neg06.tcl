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
# NFSv4 OPEN operation test - negative tests
#	Verify server returns correct errors with negative requests.

# include all test enironment
source OPEN.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set oseqid 1
set owner "$TNAME-OpenOwner"


# Start testing
# --------------------------------------------------------------
# a: Open without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Open without Putrootfh, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Open $oseqid 3 0 "$cid $owner-a" \
	{0 0 {{mode 0644}}} {0 $env(ROFILE)}}]
ckres "Open" $status $expcode $res $PASS


# The following assertions testing SHARE_DENIED
# First OPEN/CREATE a file w/SHARE_DENY_BOTH:
putmsg stdout 0 "  ** First OPEN/CREATE a file w/SHARE_DENY_BOTH;"
set expcode "SHARE_DENIED"
set Tfile "$TNAME.[pid]-DenyBoth"
set tag "OPEN-DenyBoth"
set res [compound {Putfh $bfh; Open $oseqid 2 3 "$cid $Tfile" \
	{1 0 {{mode 0664}}} {0 "$Tfile"}; Getfh}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Setup UNRESOLVED: Open(SHARE_DENY_BOTH) failed"
	putmsg stderr 0 "\t\t  Assertions(e, f, g, h) will not run"
	putmsg stderr 1 "\t\t  Res=($res)"
} else {
  set stateid [lindex [lindex $res 1] 2]
  set rflags [lindex [lindex $res 1] 4] 
  set nfh [lindex [lindex $res 2] 2]

  set norun 0
  # should confirm if needed:
  if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	incr oseqid
	set res [compound {Putfh $nfh; Open_confirm $stateid $oseqid}]
        if {$status != "OK"} {
		putmsg stdout 0 \
		    "  Setup UNRESOLVED: Open_confirm failed, status=($status)."
		putmsg stderr 0 "\t\t  Assertions(e, f, g, h) will not run"
		putmsg stderr 1 "\t\t  Res=($res)"
		set norun 1
	}
	set stateid [lindex [lindex $res 1] 2]
  }

  if { $norun == 0} {
  # Now run the assertions for SHARE_DENY_BOTH:
  putmsg stdout 0 \
	"  ** then following assertions(e,f,g,h) testing Open(SHARE_DENIED):"

  # e: Open(NOCREATE) w/accsss=read, deny=both, expect SHARE_DENIED
  set ASSERTION "Open(NOCREATE) w/access=read, deny=both, expect $expcode"
  set tag "$TNAME{e}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res2 [compound {Putfh $bfh; Open 10 1 0 "$cid $tag.1" \
	{0 0 {{mode 0644}}} {0 "$Tfile"}; Getfh}]
  ckres "Open" $status $expcode $res $PASS


  # f: Open(NOCREATE) w/accsss=write, deny=none, expect SHARE_DENIED
  set ASSERTION "Open(NOCREATE) w/access=write, deny=none, expect $expcode"
  set tag "$TNAME{f}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res2 [compound {Putfh $bfh; Open 10 2 0 "$cid $tag.2" \
	{0 0 {{mode 0644}}} {0 "$Tfile"}; Getfh}]
  ckres "Open" $status $expcode $res $PASS

  # g: Open(NOCREATE) w/accsss=both, deny=read, expect SHARE_DENIED
  set ASSERTION "Open(NOCREATE) w/access=both, deny=write, expect $expcode"
  set tag "$TNAME{g}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res2 [compound {Putfh $bfh; Open 10 3 1 "$cid $tag.3" \
	{0 0 {{mode 0644}}} {0 "$Tfile"}; Getfh}]
  ckres "Open" $status $expcode $res $PASS

  # h: Open(NOCREATE) w/accsss=both, deny=write, expect SHARE_DENIED
  set ASSERTION "Open(NOCREATE) w/access=both, deny=read, expect $expcode"
  set tag "$TNAME{h}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res2 [compound {Putfh $bfh; Open 10 3 2 "$cid $tag.4" \
	{0 0 {{mode 0644}}} {0 "$Tfile"}; Getfh}]
  ckres "Open" $status $expcode $res $PASS

  # Close the orginal OPEN file
  incr oseqid
  set res [compound {Putfh $nfh; Close $oseqid "$stateid"}]

  }
}


# Now try OPEN/CREATE a file w/SHARE_DENY_WRITE:
putmsg stdout 0 "  ** Now OPEN/CREATE a file w/SHARE_DENY_WRITE;"
putmsg stdout 0 "  ** the assertions(m,n) testing Open(SHARE_DENIED):"
set expcode "SHARE_DENIED"
set Tfile2 "$TNAME.[pid]-DenyWrite"
set res [compound {Putfh $bfh; Open $oseqid 3 2 "$cid $Tfile2" \
	{1 0 {{mode 0664}}} {0 "$Tfile2"}; Getfh}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Setup UNRESOLVED: Open(SHARE_DENY_WRITE) failed"
	putmsg stderr 0 "\t\t  Assertions(m, n) will not run"
	putmsg stderr 1 "\t\t  Res=($res)"
} else {
  set stateid [lindex [lindex $res 1] 2]
  set rflags [lindex [lindex $res 1] 4] 
  set nfh [lindex [lindex $res 2] 2]

  set norun 0
  # should confirm if needed:
  if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	incr oseqid
	set res [compound {Putfh $nfh; Open_confirm $stateid $oseqid}]
        if {$status != "OK"} {
		putmsg stdout 0 \
		    "  Setup UNRESOLVED: Open_confirm failed, status=($status)."
		putmsg stderr 0 "\t\t  Assertions(m, n) will not run"
		putmsg stderr 1 "\t\t  Res=($res)"
		set norun 1
	}
	set stateid [lindex [lindex $res 1] 2]
  }

  if { $norun == 0} {
  # Now run the assertions for SHARE_DENY_BOTH:

  # m: Open(NOCREATE) w/accsss=RW, deny=none, expect SHARE_DENIED
  set ASSERTION "Open(NOCREATE) w/access=RW, deny=none, expect $expcode"
  set tag "$TNAME{m}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res2 [compound {Putfh $bfh; Open 20 3 0 "$cid $tag.10" \
	{0 0 {{mode 0644}}} {0 "$Tfile2"}; Getfh}]
  ckres "Open" $status $expcode $res $PASS

  # n-1: Make the open owner valid (prepare for the replay OPEN op - "n1")
  set ASSERTION "Open an existing file (create valid open-owner), expect OK"
  set tag "$TNAME{n-1}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set oowner22 "$TNAME.[pid].22"
  set no_n1 0
  set fhn_1 \
  [basic_open $bfh $env(RWFILE) 0 "$cid $oowner22" osid_n1 oseqid_n1 status] 
  if {$fhn_1 == -1} {
      putmsg stderr 0 "\t Test UNRESOLVED: basic_open failed, status=($status)"
      putmsg stderr 0 "\t      and assertion <n1> below will not be run"
      set no_n1 1
  } else {
      logres "PASS"
  }
  if {[should_seqid_incr $status] == 1} {
      incr oseqid_n1
  }

  # n: Open(CREATE/UNCHECKED) w/accsss=W, deny=none, expect SHARE_DENIED
  set ASSERTION "Open(CREATE/UNCHECKED) w/access=W, deny=none, expect $expcode"
  set tag "$TNAME{n}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res2 [compound {Putfh $bfh; Open $oseqid_n1 2 0 "$cid $oowner22" \
	{1 0 {{mode 0644}}} {0 "$Tfile2"}; Getfh}]
  ckres "Open" $status $expcode $res $PASS

  # Close the orginal OPEN file
  incr oseqid
  set res [compound {Putfh $nfh; Close $oseqid "$stateid"}]
  if {$status != "OK"} {
      putmsg stderr 0 "  ** Closing the orginal file for <n1>"
      putmsg stderr 0 "\t WARNING: Close failed, status=($status)"
      putmsg stderr 0 "\t      and assertion <n1> below will not be run"
      set no_n1 1
  }

  if {$no_n1 == 0} {
      # n1: Replay {n}, open(CREATE/UNCHECKED), expect SHARE_DENIED
      set ASSERTION "Replay {n} Open(CREATE/UNCHECKED), expect $expcode"
      set tag "$TNAME{n1}"
      putmsg stdout 0 "$tag: $ASSERTION"
      set res2 [compound {Putfh $bfh; Open $oseqid_n1 2 0 "$cid $oowner22" \
	    {1 0 {{mode 0644}}} {0 "$Tfile2"}; Getfh}]
      ckres "Open-replay" $status $expcode $res2 $PASS

      # now close the dummy fh
      incr oseqid_n1
      set res3 [compound {Putfh $fhn_1; Close $oseqid_n1 $osid_n1}]
      putmsg stdout 1 "Final close on dummy fh, res=($res3)"
  }
 }
}


# Now try OPEN/CREATE a file w/SHARE_DENY_READ:
putmsg stdout 0 "  ** Now OPEN/CREATE a file w/SHARE_DENY_READ;"
putmsg stdout 0 "  ** the assertions(r,s) testing Open(SHARE_DENIED):"
set expcode "SHARE_DENIED"
set Tfile3 "$TNAME.[pid]-DenyRead"
set oseqid 100
set res [compound {Putfh $bfh; Open $oseqid 3 1 "$cid $Tfile3" \
	{1 0 {{mode 0664}}} {0 "$Tfile3"}; Getfh}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Setup UNRESOLVED: Open(SHARE_DENY_READ) failed"
	putmsg stderr 0 "\t\t  Assertions(r, s) will not run"
	putmsg stderr 0 "\t\t  Res=($res)"
} else {
  set stateid [lindex [lindex $res 1] 2]
  set rflags [lindex [lindex $res 1] 4] 
  set nfh [lindex [lindex $res 2] 2]
  set norun 0
  # should confirm if needed:
  if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	incr oseqid
	set res [compound {Putfh $nfh; Open_confirm $stateid $oseqid}]
        if {$status != "OK"} {
		putmsg stdout 0 \
		    "  Setup UNRESOLVED: Open_confirm failed, status=($status)."
		putmsg stderr 0 "\t\t  Assertions(r, s) will not run"
		putmsg stderr 1 "\t\t  Res=($res)"
		set norun 1
	}
	set stateid [lindex [lindex $res 1] 2]
  }

  if { $norun == 0} {
  # Now run the assertions for SHARE_DENY_BOTH:

  # r: Open(NOCREATE) w/accsss=RW, deny=none, expect SHARE_DENIED
  set ASSERTION "Open(NOCREATE) w/access=RW, deny=none, expect $expcode"
  set tag "$TNAME{r}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res2 [compound {Putfh $bfh; Open 30 3 0 "$cid $tag.01" \
	{0 0 {{mode 0644}}} {0 "$Tfile3"}; Getfh}]
  ckres "Open" $status $expcode $res $PASS


  # s: Open(CREATE/UNCHECKED) w/accsss=R, deny=none, expect SHARE_DENIED
  set ASSERTION "Open(CREATE/UNCHECKED) w/access=R, deny=none, expect $expcode"
  set tag "$TNAME{s}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res2 [compound {Putfh $bfh; Open 50 1 0 "$cid $tag.12" \
	{0 0 {{mode 0644}}} {0 "$Tfile3"}; Getfh}]
  ckres "Open" $status $expcode $res $PASS

  # Close the orginal OPEN file
  incr oseqid
  set res [compound {Putfh $nfh; Close $oseqid "$stateid"}]
  }
}

# The following assertion test self 'deny'
putmsg stdout 0 "  ** The following assertion test 'self-deny' ..."
set expcode "SHARE_DENIED"
set tag "$TNAME{u}"
set As "Doing the following with same open-owner, expect $expcode\n"
set As "$As\tOPEN(acc=R,deny=N), OPEN(acc=W,deny=N), should get OK\n"
set ASSERTION "$As\tthen OPEN(acc=W,deny=W) should be denied"
putmsg stdout 0 "$tag: $ASSERTION"
set Tfileu "$tag-SelfDeny"
set oou "$Tfileu"
set fh1 [basic_open $bfh $Tfileu 1 "$cid $oou" osid oseqid status \
	1 0 0666 0 1 0 0] 
if { $fh1 == -1 } {
    putmsg stderr 0 "\t Test UNRESOLVED: "
    putmsg stderr 0 "\t   basic_open(acc=R,deny=N) failed, status=($status)"
} else {
    incr oseqid
    set fh2 [basic_open $bfh $Tfileu 0 "$cid $oou" osid oseqid status \
	$oseqid 0 0666 0 2 0 0] 
    if { $fh2 == -1 } {
	putmsg stderr 0 "\t Test UNRESOLVED: "
	putmsg stderr 0 "\t   basic_open(acc=W,deny=N) failed, status=($status)"
    } else {
	incr oseqid
    	set fh3 [basic_open $bfh $Tfileu 0 "$cid $oou" osid oseqid status \
		$oseqid 0 0666 0 2 2 0] 
	if { $status != $expcode } {
		putmsg stderr 0 "\t Test FAIL: basic_open(acc=W,deny=W) failed"
		putmsg stderr 0 "\t   status=($status), expected=($expcode)"
	} else {
		logres "PASS"
	}
    }
}

# --------------------------------------------------------------
# Now cleanup, and removed created tmp file
set res [compound {Putfh $bfh; Remove $Tfile; Remove $Tfile2; \
	Remove $Tfile3; Remove $Tfileu}]
if {($status != "OK") && ($status != "NOENT")} {
        putmsg stderr 0 "\t WARNING: cleanup to remove created tmp file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS

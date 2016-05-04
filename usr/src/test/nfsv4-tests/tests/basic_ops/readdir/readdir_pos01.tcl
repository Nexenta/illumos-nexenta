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
# NFSv4 READDIR operation test - positive tests

# include all test enironment
source READDIR.env

Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Readdir of a small dir w/simple attrs, expect OK
set expcode "OK"
set ASSERTION "Readdir of a small dir w/simple attrs, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set attrs "type mode"
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getfh;
	Readdir 0 0 2048 2048 $attrs; Getfh}]
set cont [ckres "Readdir" $status $expcode $res $FAIL]
# verify the readdir results
  if {! [string equal $cont "false"]} {
    # check of eof, should be true for small directory
    set eof [lindex [lindex $res 3] 4]
    if {! [string equal $eof "true"]} {
	putmsg stderr 0 "\t Test FAIL: eof flag is not true."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "\t   eof=($eof)"
	set cont false
    } else {
      # verify the attributes returned
      set rdres [lindex [lindex $res 3] 3]
      foreach d $rdres {
	set al [lindex $d 2]
	foreach a $al {
	  set an [lindex $a 0]
	  if {! [string equal $an "type"] && ! [string equal $an "mode"]} {
	    putmsg stderr 0 "\t Test FAIL: attr(type|mode) was not returned."
	    putmsg stderr 1 "\t   an=($an)"
	    putmsg stderr 1 "\t   dir-entry=($d)"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	    set cont false
	    break
	  }
	}
      }
    }
  }
# verify FH is not changed after successful Readdir op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# b: Readdir of a dir w/r-x access, expect OK
set expcode "OK"
set ASSERTION "Readdir of a dir w/r-x access, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set attrs "fh_expire_type"
set res [compound {Putfh $bfh; Lookup $env(DIR0755); Getfh;
	Readdir 0 0 512 512 $attrs; Getfh}]
set cont [ckres "Readdir" $status $expcode $res $FAIL]
# verify the readdir results
  if {! [string equal $cont "false"]} {
      # verify the attributes returned
      set rdres [lindex [lindex $res 3] 3]
      foreach d $rdres {
	set al [lindex $d 2]
	foreach a $al {
	  set an [lindex $a 0]
	  if {! [string equal $an "fh_expire_type"]} {
	    putmsg stderr 0 \
		"\t Test FAIL: attr(fh_expire_type) was not returned."
	    putmsg stderr 1 "\t   an=($an)"
	    putmsg stderr 1 "\t   dir-entry=($d)"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	    set cont false
	    break
	  }
	}
      }
  }
# verify FH is not changed after successful Readdir op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# c: Readdir w/largedir can continue reading, expect OK
set expcode "OK"
set ASSERTION "Readdir w/largedir can continue reading, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set dfh [get_fh "$BASEDIRS $env(LARGEDIR)"]
set cookie 0
set verf 0
set eof false
set count_ent 0
while {$eof != "true"} {
    set res [compound {Putfh $dfh; 
	Readdir $cookie $verf 1024 1024 {size time_modify}; Getfh}]
    set cont [ckres "Readdir" $status $expcode $res $FAIL]

    # verify eof is set correctly for continue reading
    set eof [lindex [lindex $res 1] 4]
    set verf [lindex [lindex $res 1] 2]
    # verify the attributes returned
    set rdres [lindex [lindex $res 1] 3]
    foreach d $rdres {
	incr count_ent
	if {$count_ent >= 20000} {
		# got too many entries, something is wrong
		# to quit the while
		set eof "true"
		set count_ent -1
		set errormsg "Too many directory entries"
		break
	}
	set al [lindex $d 2]
	foreach a $al {
	  set an [lindex $a 0]
	  if {! [string equal $an "size"] && 
		! [string equal $an "time_modify"]} {
	    putmsg stderr 0 \
		"\t Test FAIL: attr(size|time_modify) was not returned."
	    putmsg stderr 1 "\t   an=($an)"
	    putmsg stderr 1 "\t   dir-entry=($d)"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	    set cont false
	    # to quit the while
	    set eof "true"
	    break
	  }
	}
    }
    set cookie [lindex [lindex $rdres end] 0]
}
# check problem was not attributes related (message already printed).
if {$count_ent == -1} {
	putmsg stderr 0 "\t Test FAIL: $errormsg"
} else {
	# verify FH is not changed after successful Readdir op
	set fh1 [lindex [lindex $res 2] 2]
	fh_equal $fh1 $dfh $cont $PASS
}


# d: Readdir down a long path based on FH attr, expect OK
set expcode "OK"
set ASSERTION "Readdir down a long path based on FH attr, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set dlist [path2comp $env(LONGDIR) $DELM]
set first [lindex $dlist 0]
set dlast [lindex $dlist end]
set nfh [get_fh "$BASEDIRS $first"]
foreach d [lrange $dlist 1 end ] {
    set res [compound {Putfh $nfh; 
	Readdir 0 0 513 1024 filehandle; Getfh}]
    putmsg stdout 1 "d=<$d> res=<$res>"
    set cont [ckres "Readdir/$d" $status $expcode $res $FAIL] 
    if {$cont == "true"} {
	set gfh [lindex [lindex $res 2] 2]
	set rdres [lindex [lindex $res 1] 3]
	foreach en $rdres {
	    # find the entry of next nodes and get its FH
	    if {[lindex $en 1] == "$d"} {
		set nfh [lindex [lindex [lindex $en 2] 0] 1]
		break
	    }
	}
	# if not the last node, the path is broken
	if {($nfh == $gfh) && ($d != $dlast)} {
	    putmsg stderr 0 "\t Test UNRESOLVED: can't find next node."
	    putmsg stderr 0 "\t	  d=<$d>, dlast=<$dlast>"
	    putmsg stderr 0 "\t	  nfh=<$nfh>"
	    putmsg stderr 0 "\t	  gfh=<$gfh>"
	    putmsg stderr 1 "\t	res=<$res>"
	    set cont "false"
	    break
	} else {
	    set gfh $nfh
	}
    } else {
	break
    }
}
# finally verify the FH of last node
if {$cont == "true"} {
    set efh [get_fh "$BASEDIRS [path2comp $env(LONGDIR) $DELM]"]
    if {$gfh != $efh} {
	putmsg stderr 0 "\t Test FAIL: incorrect FH of last node."
	putmsg stderr 1 "\t	expected=($efh)"
	putmsg stderr 1 "\t	gottheFH=($gfh)"
    } else {
	logres PASS
    }
}


# i: Readdir w/dircount=0, expect OK
# XXX spec says: p164 "Since it is a hint, it may be possible that
#     a dircount value is zero".
set expcode "OK"
set ASSERTION "Readdir w/dircount=0, expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
set attrs "named_attr"
set dircount 0
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getfh;
	Readdir 0 0 $dircount 512 $attrs; Getfh}]
set cont [ckres "Readdir" $status $expcode $res $FAIL]
# verify the readdir results
  if {! [string equal $cont "false"]} {
    # check of eof, should be true for small directory
    set eof [lindex [lindex $res 3] 4]
    if {! [string equal $eof "true"]} {
	putmsg stderr 0 "\t Test FAIL: eof flag is not true."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "\t   eof=($eof)"
	set cont false
    } else {
      # verify the attributes returned
      set rdres [lindex [lindex $res 3] 3]
      foreach d $rdres {
	set al [lindex $d 2]
	foreach a $al {
	  set an [lindex $a 0]
	  if {! [string equal $an "named_attr"]} {
	    putmsg stderr 0 "\t Test FAIL: attr(named_attr) was not returned."
	    putmsg stderr 1 "\t   an=($an)"
	    putmsg stderr 1 "\t   dir-entry=($d)"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	    set cont false
	    break
	  }
	}
      }
    }
  }
# verify FH is not changed after successful Readdir op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# m: Readdir w/rdattr_error set, expect OK
# XXX Even getattr may fail, but Readdir should return OK.
set expcode "OK"
set ASSERTION "Readdir w/rdattr_error set, expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
set attrs "acl named_attr hidden fs_locations rdattr_error"
set res [compound {Putfh $bfh; Getfh;
	Readdir 0 0 2048 2048 $attrs; Getfh}]
set cont [ckres "Readdir" $status $expcode $res $FAIL]
# verify FH is not changed after successful Readdir op
  set fh1 [lindex [lindex $res 1] 2]
  set fh2 [lindex [lindex $res 3] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# n: Readdir with maxcount>32K, expect OK
set expcode "OK"
set ASSERTION "Readdir with maxcount > 32K, $expcode"
set tag "$TNAME{n}"
putmsg stdout 0 "$tag: $ASSERTION"
set maxcount 66688
set res [compound {Putfh $bfh; Getfh;
	Readdir 0 0 2048 $maxcount {type size mode}; Getfh}]
set cont [ckres "Readdir" $status $expcode $res $FAIL]
# verify FH is not changed after successful Readdir op
  set fh1 [lindex [lindex $res 1] 2]
  set fh2 [lindex [lindex $res 3] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# o: Readdir without any attr request for regular dir, expect OK
set expcode "OK"
set ASSERTION "Readdir regular dir w/no attribute request, expect $expcode"
set tag "$TNAME{o}"
putmsg stdout 0 "$tag: $ASSERTION"
set dfh [get_fh "$BASEDIRS $env(LARGEDIR)"]
set cookie 0
set verf 0
# first get some subdir names
set res [compound {Putfh $dfh; Readdir $cookie $verf 1024 4097 {type}}]
putmsg stderr 1 "First Readdir w/type attr, res=$res"
set cont [ckres "Readdir" $status $expcode $res $FAIL]
if {! [string equal $cont "false"]} {
    # then Readdir of the subdirs without attr
    set rdres [lindex [lindex $res 1] 3]
    foreach en $rdres {
	set dname [lindex $en 1]
	set dtype [lindex [lindex [lindex $en 2] 0] 1]
	putmsg stderr 1 "dname=$dname, dtype=$dtype"
	# only interested in type=dir
	if { "$dtype" == "dir"} {
	    set res2 [compound {Putfh $dfh; Lookup $dname; Getfh;
		Readdir $cookie $verf 1024 1023 {}; Getfh}]
	    putmsg stderr 1 "  res=$res2"
	    set cont [ckres "Readdir-$dname" $status $expcode $res $FAIL]
	    # only need to print one FAIL message
	    if {[string equal $cont "false"]} {
		break
	    }
    	    set rdres2 [lindex [lindex $res 3] 3]
    	    foreach en $rdres2 {
		set dname [lindex $en 1]
		set en_attr [lindex [lindex $en 2] 0]
		putmsg stderr 1 "entry=$en, en_attr=<$en_attr>"
		if { "x$en_attr" != "x"} {
	    	    putmsg stderr 0 \
			"\t Test FAIL: server unexpectedly returned attr:"
	    	    putmsg stderr 0 \
			"\t\t for entry($dname) with attr($en_attr)."
	    	    set cont "false"
	    	    break
	        }
	    }
	    if {[string equal $cont "false"]} {
		break
	    }
	    set fh1 [lindex [lindex $res 2] 2]
	    set fh2 [lindex [lindex $res 4] 2]
	    set cont [fh_equal $fh1 $fh2 $cont $FAIL]
	}
    }
    if {! [string equal $cont "false"]} {
    	ckres "Readdir2" $status $expcode $res $PASS
    }
}


# p: Readdir Named-attr dir without any attr request, expect OK
set expcode "OK"
set ASSERTION "Readdir named-attr dir w/no attribute request, expect $expcode"
set tag "$TNAME{p}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ATTRFILE); Openattr f; 
	Getfh; Readdir 0 0 1023 1025 {}; Getfh }]
putmsg stderr 1 "Readdir($env(ATTRFILE)), res=$res"
set cont [ckres "Readdir" $status $expcode $res $FAIL]
# Now verify server returned no attribute
if {! [string equal $cont "false"]} {
    set rdres [lindex [lindex $res 4] 3]
    foreach en $rdres {
	set dname [lindex $en 1]
	set en_attr [lindex [lindex $en 2] 0]
	putmsg stderr 1 "entry=$en, en_attr=<$en_attr>"
	if { "x$en_attr" != "x"} {
	    putmsg stderr 0 "\t Test FAIL: server unexpectedly returned attr:"
	    putmsg stderr 0 "\t\t for entry($dname) with attr($en_attr)."
	    set cont "false"
	    break
	}
    }
    if {! [string equal $cont "false"]} {
	# verify FH is not changed after successful Readdir op
	set fh1 [lindex [lindex $res 3] 2]
	set fh2 [lindex [lindex $res 5] 2]
	fh_equal $fh1 $fh2 $cont $PASS
    }
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS

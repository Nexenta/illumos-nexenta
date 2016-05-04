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
# NFSv4 SETATTR operation test - negative tests
#	verify SERVER errors returned with invalid Setattr op.

# include all test enironment
source SETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set tpid [pid]
set bfh [get_fh "$BASEDIRS"]
# create a tmp file and a tmp dir for manipulation
set tmpF "Sattr_tmpF.$tpid"
set ffh [creatv4_file [file join $BASEDIR $tmpF]]
if { $ffh == $NULL } {
	putmsg stdout 0 "$TNAME: test setup - creatv4_file"
        putmsg stderr 0 "\t Test UNINITIATED: unable to create tmp file."
	putmsg stderr 1 "  "
	exit $UNINITIATED
}
set tmpD Sattr_tmpD.$tpid
set res [compound {Putfh $bfh; Create $tmpD {{mode 0711}} d; Getfh}]
if { "$status" != "OK" } {
	putmsg stdout 0 "$TNAME: test setup - mkdir"
        putmsg stderr 0 "\t Test UNINITIATED: unable to create tmp dir."
        putmsg stderr 0 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $UNINITIATED
} else {
 	set dfh [lindex [lindex $res 2] 2]
}


# Start testing
# --------------------------------------------------------------
# a: Setattr size on a dir, expect ISDIR
set expcode "ISDIR"
set ASSERTION "Setattr size on a dir, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set stateid {0 0}
set res [compound {Putfh $dfh; Setattr $stateid {{size 888}}; Getattr size}]
ckres "Setattr" $status $expcode $res $PASS


# b's: Setattr mandatory(RO-attr) on file/dir, expect INVAL
set expcode "INVAL"
# list of the mandatory attributes, except supported_attrs and size
set ma "type fh_expire_type change link_support symlink_support named_attr"
set mandattrs "$ma fsid unique_handles lease_time rdattr_error filehandle"
set i 1
set stateid {0 0}
foreach attr $mandattrs {
    set tag "$TNAME{b$i}"
    # randomly set cfh to file or dir
    set j [expr int([expr [expr rand()] * 100000000])]
    if {[expr $j % 2] == 0} {
	set nfh $ffh
	set obj "file"
    } else {
	set nfh $dfh
	set obj "dir"
    }
    set ASSERTION "Setattr{$attr, mandatory RO-attr} on a $obj, expect $expcode"
    putmsg stdout 0 "$tag: $ASSERTION"
    # Use GETATTR to get the attribute value to set
    set res [compound {Putfh $ffh; Getattr $attr}]
    putmsg stdout 1 "Getattr res=($res)"
    if {$status != "OK"} {
	putmsg stdout 0 "\t Test UNRESOVED: unable to get ($attr)"
	putmsg stdout 0 "\t\t$res"
    } else {
  	set attrval [lindex [lindex $res 1] 2]
	putmsg stdout 1 "attr=$attr, av=$attrval"
    	set res [compound {Putfh $ffh; Setattr $stateid $attrval}]
        ckres "Setattr" $status $expcode $res $PASS
    }
    incr i
}

# c's: Setattr time related RO-attrs on dir/file, expect INVAL
set expcode "INVAL|ATTRNOTSUPP"
set timeattrs "access backup create delta metadata modify"
set i 1
set stateid {0 0}
set ntime "[clock seconds] 0"
foreach attr $timeattrs {
    set nattr "time_$attr"
    set tag "$TNAME{c$i}"
    # randomly set cfh to file or dir
    set j [expr int([expr [expr rand()] * 100000000])]
    if {[expr $j % 2] == 0} {
	set nfh $dfh
	set obj "dir"
    } else {
	set nfh $ffh
	set obj "file"
    }
    putmsg stdout 0 "$tag: $ASSERTION"
    set ASSERTION "Setattr{$nattr, RO-attr} on a $obj, expect $expcode"
    putmsg stdout 1 "Putfh $nfh; Setattr $stateid {{$nattr {$ntime}}}"
    set res [compound {Putfh $nfh; Setattr $stateid {{$nattr {$ntime}}}}]
    ckres "Setattr" $status $expcode $res $PASS
    incr i
}

# d's: Setattr recommended(number, RO-attr) on file/dir, expect INVAL
set expcode "INVAL|ATTRNOTSUPP"
# list of the recommended RO-only number attributes
set ran "aclsupport fileid files_avail files_free files_total"
set ran "$ran maxfilesize maxlink maxname maxread maxwrite numlinks"
set ran "$ran quota_avail_hard quota_avail_soft quota_used"
set ran "$ran space_avail space_free space_total space_used mounted_on_fileid"
set recmnattrs "$ran"
set i 1
set stateid {0 0}
foreach attr $recmnattrs {
    set tag "$TNAME{d$i}"
    # randomly set cfh to file or dir
    set j [expr int([expr [expr rand()] * 100000000])]
    if {[expr $j % 2] == 0} {
	set nfh $dfh
	set obj "dir"
    } else {
	set nfh $ffh
	set obj "file"
    }
    set ASSERTION \
	"Setattr{$attr, recommented RO-attr} on a $obj, expect $expcode"
    putmsg stdout 0 "$tag: $ASSERTION"
    putmsg stdout 1 "Putfh $nfh; Setattr $stateid {{$attr 100}}"
    set res [compound {Putfh $nfh; Setattr $stateid {{$attr 100}}}]
    ckres "Setattr" $status $expcode $res $PASS
    incr i
}

# e's: Setattr recommended(bool, RO-attr) on file/dir, expect INVAL
set expcode "INVAL|ATTRNOTSUPP"
# list of the recommended RO-only bool attributes
set rab "cansettime case_insensitive case_preserving chown_restricted"
set recmbattrs "$rab homogeneous no_trunc"
set i 1
set stateid {0 0}
foreach attr $recmbattrs {
    set tag "$TNAME{e$i}"
    # randomly set cfh to file or dir
    set j [expr int([expr [expr rand()] * 100000000])]
    if {[expr $j % 2] == 0} {
	set nfh $dfh
	set obj "dir"
    } else {
	set nfh $ffh
	set obj "file"
    }
    set ASSERTION \
	"Setattr{$attr, recommented RO-attr} on a $obj, expect $expcode"
    putmsg stdout 0 "$tag: $ASSERTION"
    putmsg stdout 1 "Putfh $nfh; Setattr $stateid {{$attr 100}}"
    set res [compound {Putfh $nfh; Setattr $stateid {{$attr true}}}]
    ckres "Setattr" $status $expcode $res $PASS
    incr i
}

# f's: Setattr recommended(other, RO-attr) on file/dir, expect INVAL
set expcode "INVAL|ATTRNOTSUPP"
# list of the recommended RO-only other attrs, except fs_locations (not in nfsh)
set recmoattrs "rawdev"
set i 1
set stateid {0 0}
foreach attr $recmoattrs {
    set tag "$TNAME{f$i}"
    # randomly set cfh to file or dir
    set j [expr int([expr [expr rand()] * 100000000])]
    if {[expr $j % 2] == 0} {
	set nfh $dfh
	set obj "dir"
    } else {
	set nfh $ffh
	set obj "file"
    }
    set ASSERTION \
	"Setattr{$attr, recommented RO-attr} on a $obj, expect $expcode"
    putmsg stdout 0 "$tag: $ASSERTION"
    if { "$attr" == "rawdev" } {
	set nattr "{$attr {0 100}}"
    }
    putmsg stdout 1 "Putfh $nfh; Setattr $stateid $nattr"
    set res [compound {Putfh $nfh; Setattr $stateid $nattr}]
    ckres "Setattr" $status $expcode $res $PASS
    incr i
}

# h: Setattr size on a symlink file, expect INVAL
set expcode "INVAL"
set ASSERTION "Setattr size symlink file, expect $expcode"
set tag "$TNAME{h}"
putmsg stdout 0 "$tag: $ASSERTION"
set stateid {0 0}
set res [compound {Putfh $bfh; Create newl {{mode 0777}} l $tmpF; 
	Setattr $stateid {{size 1000}}}]
ckres "Setattr" $status $expcode $res $PASS

# i: Setattr w/very big size on a file,
#	expect FBIG for UFS
#	expect OK for ZFS

# UFS supports filesize range: 0-(2^40-1)
# ZFS supports filesize range: 0-(2^63-1)
# so if 2^40-1 < $nsize < 2^63, UFS should return FBIG,
# but ZFS should return OK

if $IsZFS {
    set expcode "OK"
} else {
    set expcode "FBIG"
}
set ASSERTION "Setattr w/very big size on a file, expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
# Open the tmp file
set clientid [getclientid $tpid]
set oseqid 1
set otype 0
set res [compound {Putfh $bfh; 
	Open $oseqid 3 0 {$clientid $tpid} {$otype 0 0} {0 $tmpF}; Getfh}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Test UNRESOLVED: Open failed, status=($status)."
	putmsg stderr 1 "\t    res=($res)."
} else {
    set open_sid [lindex [lindex $res 1] 2]
    set rflags [lindex [lindex $res 1] 4] 
    set nfh [lindex [lindex $res 2] 2]
    incr oseqid
    if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	set res [compound {Putfh $nfh; Open_confirm "$open_sid" $oseqid}]
	set open_sid [lindex [lindex $res 1] 2]
	incr oseqid
    }
    set nsize [string repeat "8" 19]
    set res [compound {Putfh $nfh; Setattr $open_sid {{size $nsize}}}]
    ckres "Setattr" $status $expcode $res $PASS
    compound {Putfh $nfh; Close $oseqid $open_sid}
}


# m: Setattr to a file owned by others, expect PERM
set expcode "PERM"
set ASSERTION "Setattr to a file owned by others, expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
set stateid {0 0}
set res [compound {Putfh $bfh; Lookup $env(DIR0777);
	Setattr $stateid {{mode 0715}}}]
ckres "Setattr" $status $expcode $res $PASS


# --------------------------------------------------------------
# Final cleanup
# cleanup remove the created file
set res [compound {Putfh $bfh; Remove $tmpF; Remove $tmpD; Remove newl}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created dir failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $WARNING
}
# disconnect and exit
Disconnect
exit $PASS

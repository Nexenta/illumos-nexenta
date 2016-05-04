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
# NFSv4 READDIR operation test - negative tests
#	verify SERVER errors returned with invalid Getattr.

# include all test enironment
source READDIR.env

Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# setting parameters for the basic_open function
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stdout 0 "\t Test UNINITIATED: unable to get clientid"
	exit $UNINITIATED
}
set owner "$TNAME-OpenOwner"
set otype 1;#   create file
set ctype 0;#   create unchecked
set seqid 1
set close 1;#   close after create
set mode 666
set size 0
set access 3;#  R/W access
set deny 0;#    deny none

# Start testing
# --------------------------------------------------------------
# a: Readdir with a file filehandle, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Readdir with a file filehandle, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(RWFILE)";
	Readdir 0 0 512 1024 type}]
ckres "Readdir" $status $expcode $res $PASS


# b: Readdir with a symldir filehandle, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Readdir with a symldir filehandle, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(SYMLDIR)";
	Readdir 0 0 512 1024 type}]
ckres "Readdir" $status $expcode $res $PASS


# c: Readdir with a FIFO filehandle, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Readdir with a FIFO filehandle, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(FIFOFILE)";
	Readdir 0 0 512 1024 type}]
ckres "Readdir" $status $expcode $res $PASS


# e: Readdir with cookie=1, expect OK|BAD_COOKIE
#    Spec says, arg.cookie of 1 should not be used.
set expcode "OK|BAD_COOKIE"
set ASSERTION "Readdir with cookie=1, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set cookie 1
set res [compound {Putfh $bfh; 
	Readdir $cookie 0 1024 8192 {time_modify type}}]
ckres "Readdir" $status $expcode $res $PASS


# f: Readdir with cookie=2, expect OK|BAD_COOKIE
#    Spec says, arg.cookie of 2 should not be used.
set expcode "OK|BAD_COOKIE"
set ASSERTION "Readdir with cookie=2, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set cookie 2
set res [compound {Putfh $bfh; 
	Readdir $cookie 0 1024 8192 {size acl filehandle}}]
ckres "Readdir" $status $expcode $res $PASS


# i: Readdir with maxcount=0, expect TOOSMALL
set expcode "TOOSMALL"
set ASSERTION "Readdir with maxcount=0, expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
set dircount 1024
set maxcount 0
set res [compound {Putfh $bfh; Readdir 0 0 $dircount $maxcount type}]
ckres "Readdir" $status $expcode $res $PASS


# j: Readdir with maxcount=1, expect TOOSMALL
set expcode "TOOSMALL"
set ASSERTION "Readdir with maxcount=1, expect $expcode"
set tag "$TNAME{j}"
putmsg stdout 0 "$tag: $ASSERTION"
set dircount 1024
set maxcount 1
set res [compound {Putfh $bfh; Readdir 0 0 $dircount $maxcount type}]
ckres "Readdir" $status $expcode $res $PASS


# k: Readdir with maxcount=smallest for OTW entry, expect TOOSMALL
set expcode "TOOSMALL"
set ASSERTION "Readdir with maxcount=smallest for OTW entry, expect $expcode"
set tag "$TNAME{k}"
putmsg stdout 0 "$tag: $ASSERTION"
set dircount 1024
set maxcount 23
set res [compound {Putfh $bfh; Readdir 0 0 $dircount $maxcount type}]
ckres "Readdir" $status $expcode $res $PASS


# l: Readdir with maxcount=24 bytes, but entry name in dir > 4 bytes, 
#	expect TOOSMALL for Solaris, but maybe OK for other vendors.
set expcode "TOOSMALL|OK"
set A "Readdir w/maxcount=24 bytes, but entry name in dir > 4 bytes;\n"
set ASSERTION "$A \t\texpect TOOSMALL for Solaris, maybe OK for other vendors"
set tag "$TNAME{l}"
putmsg stdout 0 "$tag: $ASSERTION"
set dircount 1024
set maxcount 24
set res [compound {Putfh $bfh; Lookup $env(ATTRFILE); Openattr f;
	Readdir 0 0 $dircount $maxcount type}]
if { $env(SRVOS) == "Solaris" } {
	ckres "Readdir" $status "TOOSMALL" $res $PASS
} else {
	ckres "Readdir" $status $expcode $res $PASS
}


# Following assertions assume "root" is a pesudo node:
# p: Readdir root (pesudo node) with maxcount=0, expect TOOSMALL
set expcode "TOOSMALL"
set ASSERTION "Readdir root (pesudo node) with maxcount=0, expect $expcode"
set tag "$TNAME{p}"
putmsg stdout 0 "$tag: $ASSERTION"
set dircount 8192
set maxcount 0
set res [compound {Putrootfh; Readdir 0 0 $dircount $maxcount type}]
ckres "Readdir" $status $expcode $res $PASS


# q: Readdir root (pesudo node) with maxcount=1, expect TOOSMALL
set expcode "TOOSMALL"
set ASSERTION "Readdir root (pesudo node) with maxcount=1, expect $expcode"
set tag "$TNAME{q}"
putmsg stdout 0 "$tag: $ASSERTION"
set dircount 8192
set maxcount 1
set res [compound {Putrootfh; Readdir 0 0 $dircount $maxcount type}]
ckres "Readdir" $status $expcode $res $PASS


# r: Readdir root (pesudo node) with maxcount=23, expect TOOSMALL
set expcode "TOOSMALL"
set ASSERTION "Readdir root (pesudo node) with maxcount=23, expect $expcode"
set tag "$TNAME{r}"
putmsg stdout 0 "$tag: $ASSERTION"
set dircount 8192
set maxcount 23
set res [compound {Putrootfh; Readdir 0 0 $dircount $maxcount type}]
ckres "Readdir" $status $expcode $res $PASS

# t: Readdir of large filename with maxcount=48, expect TOOSMALL
set tag "$TNAME{t}"
set expcode "TOOSMALL"
set ASSERTION \
    "Readdir of large file name with maxcount=48, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"
set ndir "newtd.[pid]"
set res [compound {Putfh $bfh; Create $ndir {{mode 0755}} d; Getfh}]
putmsg stdout 1 "compound {Putfh $bfh;"
putmsg stdout 1 "\t Create $ndir {{mode 0755}} d; Getfh}"
if {$status != "OK"} {
    putmsg stderr 0 "\t Test UNINITIATED: "
    putmsg stderr 0 "\t   Create failed, status=($status)"
} else {
    set nfh [lindex [lindex $res 2] 2]
    set TFILE "012345678901234567890123456789012345678901234567890123456789"
    set fh1 [basic_open $nfh $TFILE $otype "$cid $owner" osid oseqid \
        status $seqid $close $mode $size $access $deny $ctype]
    if { $fh1 == -1 } {
	putmsg stderr 0 "\t Test UNINITIATED: "
	putmsg stderr 0 \
	    "\t   basic_open(acc=R/W,deny=N) failed, status=($status)"
    } else {
        set dircount 1024
        set maxcount 48
        set res [compound {Putfh $nfh;
            Readdir 0 0 $dircount $maxcount type}]
	putmsg stdout 1 "compound {Putfh $nfh;"
	putmsg stdout 1 "\t Readdir 0 0 $dircount $maxcount type}"
        ckres "Readdir" $status $expcode $res $PASS

	# Now cleanup, and remove created tmp file
	set res [compound {Putfh $nfh; Remove $TFILE}]
	putmsg stdout 1 "compound {Putfh $nfh;"
	putmsg stdout 1 "\t Remove $TFILE}"
	if {$status != "OK"} {
	    putmsg stderr 0 "\t WARNING: cleanup to remove created tmp file failed"
	    putmsg stderr 0 "\t          status=$status; please cleanup manually."
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
        }
    }

    # Now cleanup, and remove created tmp directory
    set res [compound {Putfh $bfh; Remove $ndir}]
    putmsg stdout 1 "compound {Putfh $bfh;"
    putmsg stdout 1 "\t Remove $ndir}"
    if {$status != "OK"} {
	putmsg stderr 0 "\t WARNING: cleanup to remove created tmp directory failed"
	putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
    }
}

# u1: Readdir of first file name with maxcount=96, expect OK,
# u2: Readdir of second file name with maxcount=96, expect TOOSMALL,
#     {u2} depends on {u1}; if {u1} fails, {u2} will skip.
set tag "$TNAME{u1}"
set expcode "OK"
set attr "type size mode owner_group"
set dircount 1024
set maxcount 96
set ASSERTION \
    "Readdir of first file name with maxcount=$maxcount, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"
set ndir "newtd1.[pid]"
set res [compound {Putfh $bfh; Create $ndir {{mode 0755}} d; Getfh}]
putmsg stdout 1 "compound {Putfh $bfh;"
putmsg stdout 1 "\t Create $ndir {{mode 0755}} d; Getfh}"
if {$status != "OK"} {
    putmsg stderr 0 "\t Test UNINITIATED: "
    putmsg stderr 0 "\t   Create failed, status=($status)"
} else {
    set nfh [lindex [lindex $res 2] 2]
    set TFILE1 "01"
    incr oseqid;#   oseqid is returned from previous basic_open call
    set fh1 [basic_open $nfh $TFILE1 $otype "$cid $owner" osid oseqid \
        status $oseqid $close $mode $size $access $deny $ctype]
    if { $fh1 == -1 } {
	putmsg stderr 0 "\t Test UNINITIATED: "
	putmsg stderr 0 \
	    "\t basic_open(acc=R/W,deny=N) failed, status=($status)"
    } else {
	set res [compound {Putfh $nfh; \
	    Readdir 0 0 $dircount $maxcount $attr}]
        putmsg stdout 1 "compound {Putfh $nfh;"
        putmsg stdout 1 "\t Readdir 0 0 $dircount $maxcount $attr}"
        if {$status == $expcode} {
            putmsg stdout 0 "\t Test PASS"
	    
   	    # remove created tmp file 1
	    set res [compound {Putfh $nfh; Remove $TFILE1}]
	    putmsg stdout 1 "compound {Putfh $nfh;"
	    putmsg stdout 1 "\t Remove $TFILE1}"
	    if {$status != "OK"} {
	        putmsg stderr 0 \
		    "\t WARNING: cleanup to remove created tmp file 1 failed"
	        putmsg stderr 0 \
		    "\t          status=$status; please cleanup manually."
	        putmsg stderr 1 "\t   res=($res)"
	        putmsg stderr 1 "  "
            }

	    # u2: Readdir of second file name with maxcount=96,
	    #     expect TOOSMALL.  
	    #  The assertion will return UNRESOLVED if u1 fails

	    set tag "$TNAME{u2}"
	    set expcode1 "TOOSMALL"
	    set A "Readdir of second file name with maxcount=$maxcount,"
	    set ASSERTION "$A expect $expcode1"
	    putmsg stdout 0 "$tag: $ASSERTION"

            set TFILE2 \
                "012345678901234567890123456789012345678901234567890123456789"
            incr oseqid
            set fh2 [basic_open $nfh $TFILE2 $otype "$cid $owner" osid oseqid \
	        status $oseqid $close $mode $size $access $deny $ctype]
            if { $fh2 == -1 } {
	        putmsg stderr 0 "\t Test UNINITIATED: "
	        putmsg stderr 0 \
	 	    "\t basic_open(acc=R/W,deny=N) failed, status=($status)"
	    } else {
	        set cookie [lindex [lindex [lindex [lindex $res 1] 3] 0] 0]
	        set res [compound {Putfh $nfh; \
	  	    Readdir $cookie 0 $dircount $maxcount $attr}]
		putmsg stdout 1 "compound {Putfh $nfh;"
		putmsg stdout 1 "\tReaddir $cookie 0 $dircount $maxcount $attr}"
		ckres "Readdir" $status $expcode1 $res $PASS
	       
	        # Now cleanup, and remove created tmp file 2
	        set res [compound {Putfh $nfh; Remove $TFILE2}]
	        putmsg stdout 1 "compound {Putfh $nfh;"
	        putmsg stdout 1 "\t Remove $TFILE2}"
	        if {$status != "OK"} {
		    putmsg stderr 0 \
		        "\t WARNING: cleanup to remove created tmp file 2 failed"
		    putmsg stderr 0 \
			    "\t          status=$status; please cleanup manually."
		    putmsg stderr 1 "\t   res=($res)"
		    putmsg stderr 1 "  "
    	        }
	    }
	} else {
		putmsg stdout 0 \
		    "\t Test FAIL: Readdir returned ($status), expected ($expcode)"
	        set tag "$TNAME{u2}"
	        set expcode1 "TOOSMALL"
   	        # continue cleanup, to remove created tmp file 1
	        set res [compound {Putfh $nfh; Remove $TFILE1}]

	        set A "Readdir of second file name with maxcount=$maxcount,"
	        set ASSERTION "$A expect $expcode1"
		putmsg stdout 0 "$tag: $ASSERTION"
		putmsg stdout 0 \
		   "\t Test UNRESOLVED: assertion depends on {u1} which failed."
	}
    }

    # finally remove parent tmp directory
    set res [compound {Putfh $bfh; Remove $ndir}]
    putmsg stdout 1 "compound {Putfh $bfh;"
    putmsg stdout 1 "\t Remove $ndir}"
    if {$status != "OK"} {
	putmsg stderr 0 \
		"\t WARNING: cleanup to remove created tmp directory failed"
	putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
    }
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS

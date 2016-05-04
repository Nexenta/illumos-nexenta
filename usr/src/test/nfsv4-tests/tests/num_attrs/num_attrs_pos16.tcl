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
# NFSv4 numbered attributes:
#
# a: Test get attr FATTR4_FILES_AVAIL which should be small limit, expect OK
# b: Test get attr FATTR4_FILES_FREE which should be small limit, expect OK
# c: Test get attr FATTR4_FILES_TOTAL on the filesystem, expect OK
#

set TESTROOT $env(TESTROOT)
set delm $env(DELM)

# include common code and init section
source ${TESTROOT}${delm}tcl.init
source ${TESTROOT}${delm}testproc

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set expcode "OK"

# Get testfile pathname
set bfh [get_fh "$BASEDIRS"]

# Start testing
# ---------------------------------------------------------------
# a:Test get attr FATTR4_FILES_AVAIL which should be small limit, expect OK

set tag "$TNAME{a}"
set ASSERTION "Test get attr FATTR4_FILES_AVAIL from server, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

# Get files available from server
set avail [ exec df -e ${MNTPTR} | grep -v ifree | awk {{print $2}} ]
set attr {files_avail}
putmsg stderr 1 "avail=<$avail>, attr=<$attr>"

set PID [pid]
set nflist "newf1.$PID newf2.$PID newf3.$PID newf4.$PID newf5.$PID"

set sid {0 0}
foreach nf $nflist {
	set tfile "[creatv4_file "$BASEDIR${delm}$nf"]"
	set res [ compound {Putfh $tfile; Write $sid 0 f a \
		"This is just a test to add some data for $tag"}]
	putmsg stderr 1 "WRITE res: $res"
	after 10000
}

# Get the attribute after the new files are created with data
set res [compound {Putfh $tfile; Getattr $attr}]
set cont [ckres "Getattr/$attr" $status $expcode $res $FAIL]

if { [string equal $cont "true"] == 1 } {
	set attrval1 [ extract_attr [lindex [lindex $res 1] 2] $attr ]

	# Verify Getattr files_avail new attr value has decreased after 
	# more new files created 
	if { $avail <= $attrval1 } {
		putmsg stdout 0  \
		  "\t Test FAIL: expected attrval1 files available to decrease"
		putmsg stderr 1 "avail returned $avail"
        	putmsg stderr 1 "attrval1 returned $attrval1"
        	putmsg stderr 1 "\t\t Res: $res"
		set cont false
	}

	# Delete the new files
	putmsg stderr 1 "Remove the newly created files ..."
	set res [compound {Putfh $bfh; foreach nf $nflist {Remove $nf}}]
	if {$status != "OK"} {
		putmsg stdout 0 \
			"WARNING: remove files returned status=$status"
		putmsg stderr 1 "\t\t Res: $res"
	}

	if { [string equal $cont "true"] == 1 } {
		after 50000

		# Get files_avail for file object after new files are deleted
		set res [compound {
        		Putfh $bfh;
        		Lookup $env(TEXTFILE);
        		Getfh;
        		Getattr $attr
			}]
		set cont2 [ckres "Getattr/attr2" $status $expcode $res $FAIL]
		set attrval2 [ extract_attr [lindex [lindex $res 3] 2] $attr ]

		if { [string equal $cont2 "true"] == 1 } {
			# Verify Getattr files_avail attr value increased after
			#	files deleted
			if { $attrval1 >= $attrval2 } {
				putmsg stderr 1 "attrval1 returned $attrval1"
				putmsg stderr 1 "attrval2 returned $attrval2"
				putmsg stderr 1 "\t\t Res: $res"
				putmsg stdout 0 \
		"\t Test FAIL: expected attrval2 files available to increase"
			} else {
				prn_attrs [lindex [lindex $res 3] 2]
				putmsg stdout 0 "\t Test PASS"
			}
		}

	}

}


# ---------------------------------------------------------------
# b:Test get attr FATTR4_FILES_FREE which should be small limit, expect OK

set tag "$TNAME{b}"
set ASSERTION \
    "Test get attr FATTR4_FILES_FREE which should be small limit, expect OK"
putmsg stdout 0 "$tag: $ASSERTION"

# Get number of files free from the server itself
set expval [ exec df -e ${MNTPTR} | tail +2 | awk {{print $2}} ]

# Setup testfile for attribute purposes
set attr {files_free}
putmsg stderr 1 "expval=<$expval>, attr=<$attr>"

#Get the attribute of the test file
set res [compound {
        Putfh $bfh;
        Lookup $env(TEXTFILE);
        Getfh;
        Getattr $attr
	}]
set cont [ckres "Getattr/$attr" $status $expcode $res $FAIL]

if { [string equal $cont "true"] == 1 } {
	set attrval [ extract_attr [lindex [lindex $res 3] 2] $attr ]

	if { [string equal $expval $attrval ] } { 
		prn_attrs [lindex [lindex $res 3] 2]
		putmsg stdout 0 "\t Test PASS"
	} else {
		putmsg stdout 0 \
		  "\t Test FAIL: expected value $expval not equal to attr" 
		putmsg stderr 1 "attrval returned $attrval"
                putmsg stderr 1 "\t\t Res: $res"
	}

}

# ---------------------------------------------------------------
# c:Test get attr FATTR4_FILES_TOTAL on the filesystem, expect OK

set tag "$TNAME{c}"
set ASSERTION "Test get attr FATTR4_FILES_TOTAL on the filesystem, expect OK"
putmsg stdout 0 "$tag: $ASSERTION"

# Get total number of file slots on filesystem
set expval [ exec df -t ${MNTPTR} | grep total | awk {{print $4}} ]

# Setup testfile for attribute purposes
set attr {files_total}
putmsg stderr 1 "expval=<$expval>, attr=<$attr>"

#Get the attribute of the test file
set res [compound {
        Putfh $bfh;
        Lookup $env(TEXTFILE);
        Getfh;
        Getattr $attr
	}]
set cont [ckres "Getattr/$attr" $status $expcode $res $FAIL]

if { [string equal $cont "true"] == 1 } {
	set attrval [ extract_attr [lindex [lindex $res 3] 2] $attr ]
	if { [string equal $expval $attrval ] } {
		prn_attrs [lindex [lindex $res 3] 2]
		putmsg stdout 0 "\t Test PASS" 
	} else {
		putmsg stdout 0 \
		  "\t Test FAIL: expected $expval total files on Getattr" 
		putmsg stderr 1 "expected value = $expval" 
		putmsg stderr 1 "getattr returned $attrval"
	}

}

Disconnect 
exit $PASS


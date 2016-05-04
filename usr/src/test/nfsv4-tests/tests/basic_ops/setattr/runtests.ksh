#! /usr/bin/ksh -p
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
# control program for SETATTR op tests


[[ -n $DEBUG && $DEBUG != 0 ]] && set -x

NAME=$(basename $0)
DIR=$(dirname $0)
CDIR=$(pwd)
TESTROOT=${TESTROOT:-"$CDIR/../../"}
TESTTAG="SETATTR"
TESTLIST=$(egrep -v "^#|^  *$" ${TESTTAG}.flist)

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
CONFIGFILE=/var/tmp/nfsv4/config/config.suite
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

#source support functions
TESTSH="$TESTROOT/testsh"
. $TESTSH

iscipso=0
is_cipso "vers=4" $SERVER
if (( $? == $CIPSO_NFSV4 )); then
	iscipso=1

	# We need to do "Setattr" operation in non-global zone
        # for TX test, so add two tcl scripts to the zone.

	# setattr_pos02{a}
	cat > $ZONE_PATH/root/setattr_pos02 << __EOF
connect $SERVER
set res [compound {Putfh \$env(qfh); Lookup \$env(tf); \
	Setattr {0 0} {{mode \$env(mode)}}; Getattr mode}]
puts "\$status \$res"
disconnect
__EOF

	# setattr_neg04{a}
	cat > $ZONE_PATH/root/setattr_neg04 << __EOF
connect $SERVER
# first get clientid
set verifier "[pid][expr int([expr [expr rand()] * 100000000])]"
set res [compound {Setclientid \$verifier \$env(owner) {0 0 0}}]
if {\$status == "OK"} {
	set clientid [lindex [lindex [lindex \$res 0] 2] 0]
	set verifier [lindex [lindex [lindex \$res 0] 2] 1]
} else {
	puts stderr "Setclientid failed, status=\$status, res=\$res"
	exit
}
set res [compound {Setclientid_confirm \$clientid \$verifier}]
# Secondly do "Open" to get stateid
set res [compound {Putfh \$env(qfh); Open 1 3 0 "\$clientid \$env(owner)" \
	{0 0 {{mode 664} {size 0}}} {0 \$env(tf)}; Getfh}]
set stateid [lindex [lindex \$res 1] 2]
set rflags [lindex [lindex \$res 1] 4]
set nfh [lindex [lindex \$res 2] 2]
set OPEN4_RESULT_CONFIRM 2
if {[expr \$rflags & \$OPEN4_RESULT_CONFIRM] == \$OPEN4_RESULT_CONFIRM} {
	set res [compound {Putfh \$nfh; Open_confirm \$stateid 2}] 
	if {\$status != "OK"} {
		puts stderr "Open_confirm failed. status=(\$status). res=\$res"
		exit
	}
	set stateid [lindex [lindex \$res 1] 2]
}
# Finally do "Setattr"
set res [compound {Putfh \$nfh; Setattr \$stateid {{size \$env(fsize)}}}]
if {\$status != "DQUOT"} {
	puts stderr "\t Test Fail: Setattr return \$status, expected DQUOT"
} else {
	puts stdout "\t Test PASS"
	set res [compound {Putfh \$nfh; Close 3 \$stateid}]
}
disconnect
__EOF

fi

# Start the tests with some information
echo
echo "Testing at CLIENT=[$CLIENT] to SERVER=[$SERVER]"
echo "Started $TESTTAG op tests at [$(date)] ..."
echo

# Now ready to run the tests
(
for t in $TESTLIST; do
	# Need to switch to $TUSER2 for quota testing
	grep QUOT $t >/dev/null 2>&1
	rc=$?
	grep $TUSER2 /etc/passwd >/dev/null 2>&1
	rc=$(( $rc + $iscipso + $? ))
	if (( $rc == 0 )); then
		su $TUSER2 -c "(. $CONFIGFILE; \
			$TESTROOT/nfsh $t)"
	else
		$TESTROOT/nfsh $t
	fi
done
)

[[ $iscipso == 1 ]] && rm $ZONE_PATH/root/setattr_pos02 \
	$ZONE_PATH/root/setattr_neg04

echo
echo "Testing ends at [$(date)]."
echo 
exit $PASS

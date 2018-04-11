#!/usr/bin/ksh -p
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

###############################################################################
# start __stf_assertion__
#
# ASSERTION: pg_pattern_name_012
#
# DESCRIPTION:
#	Verify the property group name pattern when the explicitly setting
#	all the attributes the list of names that do not fit the proper
#	name pattern, should fail.
#
# STRATEGY:
#	Import the default service and verify the pattern is correct.
#
# end __stf_assertion__
###############################################################################

# Load the helper functions
. ${STF_SUITE}/${STF_EXEC}/../include/templates.kshlib

# Initialize test result
typeset -i RESULT=$STF_PASS

trap cleanup 0 1 2 15

# make sure that the environment is sane - svc.configd is up and running
check_gl_env
if [ $? -ne 0 ] 
then
	echo "--DIAG:
	Invalid test environment - svc.configd not available"

	RESULT=$STF_UNRESOLVED
	exit $RESULT
fi

extract_assertion_info $ME

assertion=pg_pattern_name_012

typeset -i test_id=1

readonly registration_template=${MANIFEST}
readonly registration_file=/tmp/pg_pattern_name_012.xml
readonly test_service=${SERVICE}

service_exists $test_service
if [ $? -eq 0 ]
then
	service_delete $test_service

	service_exists $test_service
	if [ $? -eq 0 ]
	then
		echo "-- DIAG: [${assertion}]" \
		"	Could not remove service"

		RESULT=$STF_UNRESOLVED
		cleanup
	fi
fi

PG_NAMES="_foo .foo -foo _foo,bar .foo,bar -foo,bar"
PG_NAMES="$PG_NAMES f.foo 1,bar 123foo foo,123bar"
PG_NAMES="$PG_NAMES %foo %foo,bar foo,%bar foo,b%ar"
PG_NAMES="$PG_NAMES 1.foo,bar"

for PG_NAME in $PG_NAMES
do
	echo "--INFO : Verify that property group name $PG_NAME fails"

	manifest_generate $registration_template \
		PGNAME="name='$PG_NAME'" \
		PGTYPE="type='application'" \
		PGTARGET="target='instance'" \
		PGREQUIRED="required='false'" > $registration_file

	manifest_purgemd5 $registration_file

	#
	# Note: Import fails but returns a 0 status, so check the
	# OUTFILE and ERRFILE for failure lines
	#
	verify_import neg $registration_file $test_service $OUTFILE $ERRFILE
	if [ $? -ne 0 ]
	then
		service_delete $test_service

		service_exists $test_service
		if [ $? -eq 0 ]
		then
			echo "--DIAG: Unable to remove the service"
			cleanup
		fi
	else
		echo "-- INFO: $PG_NAME svccfg import failed"

	fi

	echo "\n"
done

service_cleanup $test_service

trap 0 1 2 15

exit $RESULT
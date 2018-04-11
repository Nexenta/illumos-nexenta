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
# ASSERTION: prop_pattern_choices_028
#
# DESCRIPTION:
#	Verify the property name pattern when the explicitly setting
#	all the attributes, with constraints, values, and include values set
#	to values.
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

assertion=prop_pattern_choices_028

typeset -i test_id=1

readonly registration_template=${MANIFEST}
readonly registration_file=/tmp/prop_pattern_choices_028.xml
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

PG_NAME="foo"
PROP_NAME="bar"
CHOICE_VALUE="foobar"

constvname=`$NAME_GEN 8`
constmin="20"
constmax="50"
CONSTRAINT="<constraints>\\
		<value name='$constvname' />\\
		<range min='$constmin' max='$constmax' />\\
	</constraints>"

MLINECONSTRAINT="\$CONSTRAINT"

vname1=`$NAME_GEN 8`
vname2=`$NAME_GEN 8`
VALUES="<values>\\
		<value name='$vname1'>\\
			<common_name>\\
				<loctext xml:lang='C'>\\
					Test Value $vname1\\
				</loctext>\\
			</common_name>\\
		</value>\\
		<value name='$vname2'>\\
			<common_name>\\
				<loctext xml:lang='C'>\\
					Test Value $vname2\\
				</loctext>\\
			</common_name>\\
		</value>\\
	</values>"

MLINEVALUES="\$VALUES"

INCLUDE_VALUES="<include_values type='values' />"

manifest_generate $registration_template \
	PROPNAME="name='$PROP_NAME'" \
	PROPTYPE="type='astring'" \
	PROPREQUIRED="required='true'" \
	PROPVALUES="$MLINEVALUES" \
	CONSTRAINTS="$MLINECONSTRAINT" \
	CHOICEVALUE="<value name='$CHOICE_VALUE' />" \
	CHOICERANGE="" \
	INCVALUES="$INCLUDE_VALUES" > $registration_file

manifest_purgemd5 $registration_file

verify_import pos $registration_file $test_service $OUTFILE $ERRFILE
if [ $? -ne 0 ]; then
	cleanup
fi

echo "--INFO: Validate the property pattern choices when setting attributes"
pgn=${PROP_PREFIX_NT}${PG_NAME}_${PROP_NAME}
verify_prop $test_service $pgn/choices_include_values astring values
verify_prop $test_service $pgn/choices_name astring ${CHOICE_VALUE}

service_cleanup $test_service

trap 0 1 2 15

exit $RESULT
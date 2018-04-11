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
# 
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

#This function is to cleanup the leftovers by this test

function cleanup {
	service_cleanup $service_test1
	service_cleanup $service_test2
	/usr/bin/rm -f $svccfg_add_script1
	/usr/bin/rm -f $svccfg_add_script2
}

###############################################################################
# start __stf_assertion__
#
# ASSERTION: svcadm_enable_012
#
# DESCRIPTION:
#	svcadm enable <FMRI list> should succeed
# STRATEGY:
#	- Check for test setup.
#	- Configure a service 'foo$$1' using svccfg
#	- configure another service foo$$2 using svccfg
#	- Enable them using svcadm
#	- Make sure their state is online
#	- svcadm enable <fmrilist> and make sure it exits 0.
#	- Make sure state is online.
#
# COMMANDS: svcadm(1)
#
# end __stf_assertion__
################################################################################

# First load up definitions of STF result variables like STF_PASS etc.
. ${STF_TOOLS}/include/stf.kshlib

# Load up definitions of shell functionality common to all smf sub-suites.
. ${STF_SUITE}/include/gltest.kshlib

# Define Variables
readonly assertion=svcadm_enable_012
readonly svccfg_add_script1=/var/tmp/svcadm_enable_012.$$.config1
readonly svccfg_add_script2=/var/tmp/svcadm_enable_012.$$.config2
readonly service_test1=foo$$1
readonly service_test2=foo$$2
readonly instance_test=instance$$
readonly fmri1=svc:/$service_test1:$instance_test
readonly fmri2=svc:/$service_test2:$instance_test
readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})

# gltest.kshlib functions to extract and print assertion information
# from this source script.
extract_assertion_info $ME

# Initialize test result to pass.
typeset -i RESULT=${STF_UNRESOLVED}

# Set a trap to execute the cleanup function when specified signals
# are received.
trap cleanup 0 1 2 15

# Exit code for individual commands.
typeset -i tmp_rc=0

# Make sure we run as root
if ! /usr/bin/id | grep "uid=0(root)" > /dev/null 2>&1
then
        echo "--DIAG: [$assertion]
        This test must be run from root."
	print_result $RESULT
	exit $RESULT
fi


# Execute environmental sanity checks.
check_gl_env
tmp_rc=$?
if [[ $tmp_rc -ne 0 ]]
then
    echo "--DIAG: [$assertion]
	Invalid smf environment, quitting."
    print_result $RESULT
    exit $RESULT
fi

# Create the svccfg add script which will add entities to the
# repository for this test case.

echo "--INFO: [${assertion}]
	configure $service_test1 using svccfg"

cat > $svccfg_add_script1 <<EOF
add $service_test1
select $service_test1
add $instance_test
EOF

echo "--INFO: [${assertion}]
	configure $service_test2 using svccfg"

cat > $svccfg_add_script2 <<EOF
add $service_test2
select $service_test2
add $instance_test
EOF

#Add objects to repository

echo "--INFO: [${assertion}]
	Adding entities <$service_test1> to repository using svccfg"

/usr/sbin/svccfg -f $svccfg_add_script1 >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "--DIAG: [$assertion]
	Adding entities using svccfg failed."
	print_result $RESULT
	exit $RESULT
fi
#Add objects to repository

echo "--INFO: [${assertion}]
	Adding entities <$service_test2> to repository using svccfg"

/usr/sbin/svccfg -f $svccfg_add_script2 >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "--DIAG: [$assertion]
	Adding entities using svccfg failed."
	print_result $RESULT
fi

echo "--INFO: [${assertion}]
	enable services using svcadm enable fmrilist"

#Enable the service using svcadm enable <fmrilist>?
/usr/sbin/svcadm enable $fmri1 $fmri2 >/dev/null 2>&1
if [ $? -ne 0 ]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
	svcadm enable $fmri1 $fmri2 should succeed with return 0"
	print_result $RESULT
	exit $RESULT
fi

#Wait just for sometime, let the service STATE gets updated

echo "--INFO: [${assertion}]
	Wait until state transition gets completed"

service_wait_state $fmri1 online
if [ $? -ne 0 ]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
	<$fmri1> is not online"
	print_result $RESULT
	exit $RESULT
fi

service_wait_state $fmri2 online
if [ $? -ne 0 ]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
	<$fmri2> is not online"
	print_result $RESULT
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	Assertion proved"


RESULT=$STF_PASS
print_result $RESULT
exit $RESULT
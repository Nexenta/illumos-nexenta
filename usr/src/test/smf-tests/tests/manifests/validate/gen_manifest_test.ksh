#! /usr/bin/ksh
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

#
# DESCRIPTION :
#	Generate a list of manifests and services that a validation
#	can be run against to check for errors, and warnings.
#	Any warning or failure from manifests on the system will
#	need to be noted.
#	While not really a testable noting of services without
#	manifests and vice versa will be made as well as the
#	counts of service/manifests.  This will be so that stored
#	test logs can be reviewed against newer test logs for
#	changes.
#
# STRATEGY :
#	A manifest must be un-modified from the base install of
#	that manifest.  
#
#	- Get a list of all the services on the system
#	- Get a list of all the manifests in the MANIFESTPATH
#	- Associate each manifest with a service and add to the
#		test list in the form of :
#			manifest:service
#	- For each service left over add to the test list in the
#		form of :
#			:service
#	- For each manifest left over add to the test list in the
#		form of :
#			manifest:
#
#	- for each entry in the test list validate each of the
#		entries and report anomolies, in the manifest
#		and/or the service.
#
#	- for the single manifest or service entries make note
#		of these for additional reference.
#

SERVICELIST=/var/tmp/scftest_servicelist.$$

#
# Get the list of services
#
cnt=1
rm -f $SERVICELIST
/bin/svcs -aH | grep -v legacy_run | grep -v refresh | awk '{print $3}' > $SERVICELIST 2>/dev/null

#
# Get the list of manifesets and associate them with a known
# service, removing the service from the service list, and
# adding the manfiest:service to the test list
#
# For any manifest that doesn't map to a know service just add
# the manifest to the test list for just manifest validation.
#
for MANIFESTDIR in `echo $MANIFESTPATH | sed -e 's/:/ /'`
do
	for MANIFESTFILE in `find $MANIFESTDIR -type f`
	do
		MYFMRI=`svccfg inventory $MANIFESTFILE`
		if [ $? -eq 0 ]; then
			TESTARGS="$MANIFESTFILE"
			MYFMRI=`echo $MYFMRI | \
			    awk '{for (i = 1; i < NF; i++) print $i}'`
			for INST in $MYFMRI
			do
				grep -w $INST $SERVICELIST > /dev/null 2>&1
				if [ $? -eq 0 ]; then
					TESTARGS="$TESTARGS $INST"
					grep -vw $INST $SERVICELIST > \
					    ${SERVICELIST}.tmp
					mv ${SERVICELIST}.tmp $SERVICELIST
				fi
			done
			eval stf_addassert -u root -t 'test_${cnt}' \
			    -c 'runtest $TESTARGS'
		fi
		(( cnt = $cnt + 1 ))
	done
done


#
# Add a test for each of the services that do not have a
# known maniftest location.
#
exec 3<${SERVICELIST}
while read -u3 line
do
	eval stf_addassert -u root -t 'test_${cnt}' -c 'runtest $line'
	(( cnt = $cnt + 1 ))
done

rm -f $SERVICELIST

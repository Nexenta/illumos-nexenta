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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)tc_zones_share.ksh	1.6	09/08/16 SMI"
#

#
# zones test case
#

tet_startup="startup"
tet_cleanup="cleanup"

iclist="ic1 ic2 ic3"
ic1="zone_disable001"
ic2="zone_remove001"
ic3="zone_move001"

#
# Here we need to source the configure file and do the initial
# setup for the tests.
# 	Initial Setup steps :
#		- check for legacy share commands and setup
#		- Create file systems
#		
function startup {
        tet_infoline "Checking environment and runability"
        share_startup
	if (( $? == 0 )); then
		tet_infoline "Creating the zone ..."
		if [[ $report_only != TRUE ]]; then
			zones_min_setup testzone1 ${MP[3]}
			if (( $? != 0 )); then
				tet_infoline "create zone failed"
				cancel_tests
				return
			fi
		fi
	fi
}

function cleanup {
	[[ $report_only != TRUE ]] && zones_min_cleanup testzone1 ${MP[3]}
        share_cleanup
	rm -f $SHR_TMPDIR/share_tests_zone*

	# Should recover the needed zfs in case of it was destroyed by zone
        # uninstall, otherwise, zone cannot be created with the same zone path
	# in the next time run, and other tests will be effected too if run
	# them after zone tests run. Especially in opensolaris, zones must be
	# installed within a ZFS file system, otherwise the zone install
	# command will generate the error "no zonepath dataset".
	if [[ $setup_once == TRUE ]]; then
		$DF -F zfs ${MP[3]} > /dev/null 2>&1
		if (( $? != 0 )); then
			typeset zfspool="share_pool"
			[[ -n $ZFSPOOL ]] && zfspool=$ZFSPOOL
			create_zfs_fs $zfspool ${MP[3]} 1g
			if (( $? != 0 )); then
				cti_result FAIL \
					"failed to recover zfs<${MP[3]}>"
				return 1
			fi
		fi
	fi
}

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/zones/tp_zones_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/zones/tp_zones_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/zones/tp_zones_003

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common
. ${TET_SUITE_ROOT}/sharefs-tests/lib/zones_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh

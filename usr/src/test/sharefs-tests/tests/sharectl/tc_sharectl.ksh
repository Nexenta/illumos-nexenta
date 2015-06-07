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
# ident	"@(#)tc_sharectl.ksh	1.5	09/08/01 SMI"
#

#
# Sharectl test case
#

tet_startup="startup"
tet_cleanup="cleanup"

iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8 ic9 ic10 ic11 ic12 ic13 ic14"
iclist="$iclist ic15 ic16 ic17 ic18 ic19 ic20 ic21 ic22 ic23 ic24 ic25"
iclist="$iclist ic26 ic27 ic28 ic29 ic30 ic31 ic32 ic33 ic34 ic35 ic36"
iclist="$iclist ic37 ic38"
ic1="sharectl001"
ic2="sharectl002"
ic3="sharectl003"
ic4="sharectl004"
ic5="sharectl005"
ic6="sharectl006"
ic7="sharectl006"
ic8="sharectl008"
ic9="sharectl009"
ic10="sharectl010"
ic11="sharectl011"
ic12="sharectl012"
ic13="sharectl013"
ic14="sharectl014"
ic15="sharectl015"
ic16="sharectl016"
ic17="sharectl017"
ic18="sharectl018"
ic19="sharectl019"
ic20="sharectl020"
ic21="sharectl021"
ic22="sharectl022"
ic23="sharectl023"
ic24="sharectl024"
ic25="sharectl025"
ic26="sharectl026"
ic27="sharectl027"
ic28="sharectl028"
ic29="sharectl029"
ic30="sharectl030"
ic31="sharectl031"
ic32="sharectl032"
ic33="sharectl033"
ic34="sharectl034"
ic35="sharectl035"
ic36="sharectl036"
ic37="sharectl037"
ic38="sharectl038"

#
# Here we need to source the configure file and do the initial
# setup for the tests.
# 	Initial Setup steps :
#		- check environment to see if we even need to run (checkenv)
#		- check for legacy share commands and setup
#		- Create file system 
#		
function startup {
        tet_infoline "Checking environment and runability"
        share_startup
	$CP /etc/default/nfs /etc/default/nfs.sharectl_test.orig
	$SHARECTL get nfs > $sharectl_orig
}

function cleanup {
        share_cleanup
	mv /etc/default/nfs.sharectl_test.orig /etc/default/nfs
	svcadm disable svc:/network/nfs/server
	svcadm enable svc:/network/nfs/server

	#
	# Need to potentially clear the maintenance mode for the
	# nfs/nlockmgr service due to issues with restarting
	# the services too quickly.
	#
	svcs nfs/nlockmgr | grep maintenance > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		svcadm clear svc:/network/nfs/nlockmgr > /dev/null 2>&1
		tet_infoline "WARNING!: the nfs/nlockmgr was in " \
			"maintenance mode."
	fi
}

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_003
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_004
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_005
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_006
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_007
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_008
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_009
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_010
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_011
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_012
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_013
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_014
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_015
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_016
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_017
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_018
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_019
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_020
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_021
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_022
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_023
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_024
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_025
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_026
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_027
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_028
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_029
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_030
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_031
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_032
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_033
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_034
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_035
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_036
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_037
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharectl/tp_sharectl_038

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/lib/ksh/tetapi.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh

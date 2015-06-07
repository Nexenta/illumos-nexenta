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
# ident	"@(#)configure.ksh	1.7	09/08/11 SMI"
#

#
# Create the configuration file based on passed in variables
# or those set in the tetexec.cfg file.
#

tet_startup="startup"
tet_cleanup=""

iclist="ic1 ic2"
ic1="configure"
ic2="unconfigure"

#
# Check to see if the configure file variable is set,
# and if not then set to the default value
#
[[ -z $SHR_TMPDIR ]] && SHR_TMPDIR=/var/tmp/share
[[ -z $configfile ]] && configfile=$SHR_TMPDIR/test_config

#
# In order to complete the creation of the config file
#	- create directory if needed
#	- confirm ability to create file
#	- parse the TESTDIR variable and set ZFSPOOL variable accordingly
#	- write config file with variable settings
#	- create new zfs pool if TESTDIR is UFS based
#	- setup test file systems if user choose to build them only once
#
function configure {
	# share cannot be done by ordinary user
	is_root
	# share is not supported in non-global zone
	ck_zone

	# create needed test directories
	if [[ ! -d $TESTDIR ]]; then
	    mkdir -p $TESTDIR
	    if (( $? != 0 )); then
		cti_result FAIL "failed to create $TESTDIR directory"
		return
	    fi
	fi

	if [[ -d $SHR_TMPDIR ]]; then
	    chmod 0777 $SHR_TMPDIR
	    if (( $? != 0 )); then
		cti_result FAIL "failed to set permission of $SHR_TMPDIR to 777"
		return
	    fi
	else
	    mkdir -pm 0777 $SHR_TMPDIR
	    if (( $? != 0 )); then
		cti_result FAIL "failed to create $SHR_TMPDIR directory"
		return
	    fi
	fi

	# check if the test suite had been configured already
	if [[ -f $configfile ]]; then
		tet_infoline "This test suite had already been configured."
		tet_infoline "to unconfigure the test suite use:"
		tet_infoline "   run_test -L $SHR_TMPDIR -F $configfile " \
					"share unconfigure"
		tet_infoline "or supply an alternate config file by using:"
		tet_infoline "   run_test -L $SHR_TMPDIR -v " \
					"configfile=<filename> share configure"
		tet_result FAIL
		return
	else
		touch ${configfile}
		if (( $? != 0 )); then
			cti_result FAIL "Could not create the configuration \
				file: $configfile"
			return
		fi
		rm -f ${configfile}
	fi

	# set the config file template variable to the test_config template
	# file, and check if it exists
	configfile_tmpl=${TET_SUITE_ROOT}/sharefs-tests/config/test_config.tmpl
	if [[ ! -f $configfile_tmpl ]]; then
		cti_result FAIL "There is no template config file to \
			create config from."
		return
        fi

	# check if the TESTDIR has enough space to create test file systems
	df -h $TESTDIR > $SHR_TMPDIR/df.out.$$
	typeset avail_space=$(tail -1 $SHR_TMPDIR/df.out.$$ | awk '{print $4}')
	typeset -i avail_num=${avail_space%?}
	if [[ $avail_space == *"K" || $avail_space == *"M" ]] || (( \
		$avail_num < 2 )); then
		cti_reportfile $SHR_TMPDIR/df.out.$$ "df -h $TESTDIR"
		typeset errmsg="ERROR: the test directory<$TESTDIR> does not"
		errmsg="$errmsg have enough space available for testing, please"
		errmsg="$errmsg provide an alternative test directory (reset"
		errmsg="$errmsg TESTDIR var) which has 2G free space at least"
		cti_result FAIL "$errmsg"
		rm -f $SHR_TMPDIR/df.out.$$
		return
	else
		rm -f $SHR_TMPDIR/df.out.$$
	fi

	# get fs type and set ZFSPOOL variable
	typeset strfs=$(get_fstype $TESTDIR)
	if (( $? != 0 )); then
		cti_result FAIL "get_fstype<$TESTDIR> failed -"
		tet_infoline "expect OKAY, but got <$strfs>"
		return
	fi
	typeset fs_type=$(echo $strfs | awk '{print $2}')
	if [[ $fs_type == ufs ]]; then
		ZFSPOOL=""	

		# create new zpool from file
		zpool list | grep share_pool > /dev/null 2>&1
		if (( $? != 0 )); then
			typeset F_ZPOOL=$TESTDIR/newzpool.file.$$
			mkfile 1536m $F_ZPOOL
			if (( $? != 0 )); then
				cti_result FAIL \
					"failed to create 1536m file<$F_ZPOOL>"
				return
			fi
			create_zpool -f share_pool $F_ZPOOL
			if (( $? != 0 )); then
				cti_result FAIL \
					"failed to create zpool<share_pool>"
				return
			fi
		else
			cti_result FAIL "share_pool pool already exists"
			return
		fi
	elif [[ $fs_type == zfs ]]; then
		#
		# Do not assume that all the existing pool can be used for testing.
		# Should always create a test pool for testing.
		#
		# The old code always uses root pool for testing purpose
		# which is dangerous and always trashes the root pool after test.
		#
		# To fix the problem, always create a separate test pool
		#
		ZFSPOOL=test_pool
		TESTPOOL_VDEV=$TESTDIR/testpool.file.$$
		mkfile 2g $TESTPOOL_VDEV
		create_zpool -f $ZFSPOOL $TESTPOOL_VDEV
		if (( $? != 0 )); then
			cti_result FAIL \
				"failed to create zpool<test_pool>"
			return
		fi
	else
		cti_result FAIL "TESTDIR<$TESTDIR> is based $fs_type, \
			but this test suite only supports UFS and ZFS!"
		return
	fi

        exec 3<$configfile_tmpl
        while :
	do
                read -u3 line
                if [[ $? = 1 ]]
                then
                        break
                fi
                if [[ "$line" = *([     ]) || "$line" = *([     ])#* ]]
                then
                        echo $line
                        continue
                fi

                variable_name=`echo $line | awk -F= '{print $1}'`
                eval variable_value=\${$variable_name}
                if [[ -z $variable_value ]]
                then
                        echo "$line"
                else
                        echo $variable_name=$variable_value
                fi
        done > $configfile

	# record CTI_LOGDIR variable used by run_test command at configure phase
	# to configuration file for saving results of later phases to the same
	# directory if user does not specify the log directory again in other
	# run_test commands
	typeset cti_logdir=$(dirname $CTI_LOGDIR)
	[[ $cti_logdir != "/var/tmp" ]] && \
		echo "CTI_LOGDIR=$cti_logdir" >> $configfile

	chmod 0444 $configfile

	if [[ -n $setup_once && $setup_once != "TRUE" ]]; then
		cti_result PASS "share test suite is ready to run!"
		return
	fi

	build_fs
	if (( $? != 0 )); then
		cti_result FAIL "failed to build test file systems"
		return
	fi

	cti_result PASS "share test suite is ready to run!"
}

#
# NAME
#	unconfig_test_pool
#
# DESCRIPTION
#	This function is used to cleanup and destroy the pools 
#	created for testing.  The function takes <poolname>
#	as the only argument.
#
function unconfig_test_pool {
	POOL=$1

	umount /$POOL
	if (( $? != 0 )); then
		tet_infoline "WARNING: unable to umount $POOL"
	fi
	zpool destroy -f $POOL
	[[ $? != 0 ]] && tet_infoline \
	"WARNING: unable to remove $POOL"
}

#
# NAME
#       unconfig_test_suite
#
# DESCRIPTION
#       The test purpose the test suite calls to un-initialize and
#       configure the test suite.
#
function unconfigure {
	typeset -i ret=0

	# clean up test fs
	[[ $setup_once == "TRUE" ]] && clean_fs

	# delete zfs test pools if needed
	zpool list share_pool > /dev/null 2>&1
	if (( $? == 0 )); then
		unconfig_test_pool share_pool	
	fi

	zpool list test_pool > /dev/null 2>&1
	if (( $? == 0 )); then
		unconfig_test_pool test_pool	
	fi

	# remove temporary test directory if it is empty,
	# but it will not be removed if it contains test result(s)
	rmdir $SHR_TMPDIR > /dev/null 2>&1

        #
        # Remove the test dir and configuration file provided, and verify
        # the results of the dir/file removal.
        #
	rm -fr $TESTDIR
	ret=$((ret + $?))
	[[ -d $TESTDIR ]] && tet_infoline \
			"WARNING: unable to remove $TESTDIR directory"
        rm -f $configfile
	ret=$((ret + $?))
	[[ -f $configfile ]] && tet_infoline \
			"WARNING: unable to remove $configfile file"

	if (( $ret == 0 )); then
                cti_result PASS "unconfigure share test suite successfully"
        else
                cti_result FAIL "something was wrong during unconfigure, \
			please have a check and do cleanup manually if needed"
        fi
}

function startup {
	tet_infoline "Create config file $configfile"
}

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common
. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh

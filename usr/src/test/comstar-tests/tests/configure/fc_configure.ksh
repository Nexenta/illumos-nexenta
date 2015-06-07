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
# ident	"@(#)fc_configure.ksh	1.6	09/08/26 SMI"
#

#
# Create the configuration file based on passed in variables
# or those set in the configuration file provided by run_test
# file.
#

#
# Use the same mechanism as a test suite, use a test purpose
# for the configuration processes.   The first is to do the
# configuration and the second test purpose is to unconfigure
# the test suite.
#
iclist="ic1 ic2"
ic1=config_test_suite
ic2=unconfig_test_suite
#
# NAME
#	createconfig
#
# DESCRIPTION
#	Take the current configuration based on the config file provided
# 	and create the configuration based on variables passed in.
#
function createconfig
{
	if [ ! -f $configfile_tmpl ]
	then
		cti_report "There is no template config file to create config from."
		configresult="FAIL"
		return
	fi

	if [ -f $configfile ]
	then
		cti_report "Test Suite already configured."
		cti_report "to unconfigure the test suite use :"
		cti_report "   run_test comstar fc_unconfigure"
		cti_report " or supply an alternate configfile name by using :"
		cti_report "   run_test -v configfile=<filename> comstar fc_configure"
		configresult="FAIL"
		return
	else
		touch ${configfile}
		if [ $? -ne 0 ]
		then
			cti_report "Could not create the configuration file"
			configresult="FAIL"
			return
		fi
	fi

	exec 3<$configfile_tmpl
	while :
	do
		read -u3 line
		if [[ $? = 1 ]]
		then
			break
		fi
		if [[ "$line" = *([ 	]) || "$line" = *([ 	])#* ]]
		then
			echo $line
			continue
		fi

                variable_name=${line%%=*}
                variable_name=${variable_name##*([      ])}
                variable_name=${variable_name%%*([      ])}
              	eval variable_value="\${$variable_name}"

		if [[ -z $variable_value ]];then
			echo "$line"
		else
			echo $variable_name=$variable_value
		fi
	done > $configfile
}

#
# NAME
#	config_test_suite
#
# DESCRIPTION
#	The test purpose the test suite calls to initialize and
# 	configure the test suite. 
#
function config_test_suite
{
	#
	# Check to see if the config file variable is not set,
	# and if not the set to the default value
	#
	if [ -z $configfile ]
	then
		configfile=${CTI_SUITE}/config/test_config
	fi

	#
	# set the config file template variable to the test_config
	# template file.
	#
	configfile_tmpl=${CTI_SUITE}/config/fc_test_config.tmpl

	#
	# Call the createconfig function to actually process the variables
	# and process the template and create the configuration file used
	# by the test suite.
	#
	createconfig

	#
	# Verify that the configuration results are PASS or FAIL.
	# Report the results tot he end user.
	#
	if [ "$configresult" = "FAIL" ]
	then
		rm -f $configfile
		cti_report "FAIL - Unable to configure test suite."
		cti_fail
	else
		cti_report "PASS - Configured test suite."
		cti_pass
	fi
}

#
# NAME
#	unconfig_test_suite
#
# DESCRIPTION
#	The test purpose the test suite calls to un-initialize and
# 	configure the test suite. 
#
function unconfig_test_suite
{
	#
	# Check to see if the config file variable is not set,
	# and if not the set to the default value
	#
	if [ -z $configfile ]
	then
		configfile=${CTI_SUITE}/config/test_config
	fi

	#
	# Remove the configuration file provided, and verify the results
	# of the file removal.
	#
	rm -f $configfile
	if [ $? -eq 0 ]
	then
		cti_report "PASS - $configfile removed."
		cti_pass
	else
		cti_report "FAIL - unable to remove $configfile"
		cti_fail
	fi
}

. ${CTI_ROOT}/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh


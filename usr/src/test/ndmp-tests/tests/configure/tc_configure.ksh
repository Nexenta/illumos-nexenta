#! /usr/bin/ksh -p
#
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

#
# BSD 3 Clause License
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#       - Redistributions of source code must retain the above copyright
#         notice, this list of conditions and the following disclaimer.
#
#       - Redistributions in binary form must reproduce the above copyright
#         notice, this list of conditions and the following disclaimer in
#         the documentation and/or other materials provided with the
#         distribution.
#
#       - Neither the name of Sun Microsystems, Inc. nor the
#         names of its contributors may be used to endorse or promote products
#         derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY SUN MICROSYSTEMS, INC. "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL SUN MICROSYSTEMS, INC. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

#
# Create the configuration file based on passed in variables
# or those set in the tetexec.cfg file.
#
#
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

tet_startup="startup"
tet_cleanup=""

iclist="ic1 ic2"
ic1="createconfig"
ic2="unconfigure"

#
# In order to complete the creation of the config file
# 	- create directory if needed
#	- confirm ability to create file
#	- parse the share_disk variable and create the appropriate entries.
#	- Add the comment 
#	- Add device entries to the config file
#
createconfig()
{
	#
	# Check to see if the configure file variable is not set,
	# and if not the set to the default value
	#
	if [[ -z $configfile ]]
	then
		configfile=${CTI_SUITE}/config/test_config
	fi

	#
	# set the config file template variable to the test_config
	# template file.
	#
	configfile_tmpl=${CTI_SUITE}/config/test_config.tmpl

	#
	# Commented code will be used if required in future
	#
	:'if [ -f $configfile ]
	then
		tet_infoline "Test Suite already configured."
		tet_infoline "to unconfigure the test suite use :"
		tet_infoline "   run_test ndmp unconfigure"
		tet_infoline " or supply an alternate config file name by using :"
		tet_infoline "   run_test -v config file=<filename> ndmp configure"
		return
	else
		touch ${configfile}
		if [ $? -ne 0 ]
		then
			tet_infoline "Could not create the configuration file"
			return
		fi
		rm -f ${configfile}
	fi
	'
	touch ${configfile}

	if [ ! -f $configfile_tmpl ]
	then
		tet_infoline "There is no template config file to create config from."
		tet_result FAIL
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

	tet_infoline "Created $configfile"
	tet_result PASS
}

#
# NAME
#       unconfig_test_suite
#
# DESCRIPTION
#       The test purpose the test suite calls to un-initialize and
#       configure the test suite.
#
unconfigure() {
        #
        # Check to see if the configure file variable is not set,
        # and if not the set to the default value
        #
        if [[ -z $configfile ]]
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
                tet_infoline "PASS - $configfile removed."
                tet_result PASS
        else
                tet_infoline "FAIL - unable to remove $configfile"
                tet_result FAIL
        fi
}

startup()
{
	tet_infoline "Create config file $configfile"
}

#. ${TET_SUITE_ROOT}/share/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh

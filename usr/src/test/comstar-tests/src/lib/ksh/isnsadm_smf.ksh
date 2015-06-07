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

ISNS_SMF="network/isns_server"
ISNS_MANIFEST="/lib/svc/manifest/network/isns_server.xml"

#
# NAME
#	isns_smf_enable
#
# SYNOPSIS
#	isns_smf_enable
#
# DESCRIPTION:
#	This function executes enable method for testing.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function isns_smf_enable 
{
	typeset isns_server=$1
	isns_smf_snap $isns_server
	CMD="$SVCADM enable -rs $ISNS_SMF"
	cti_report "Executing: $CMD"
	run_rsh_cmd $isns_server "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $ISNS_SMF smf service can NOT be enabled"
		return 
	fi	
	verify_isns_enable $isns_server	
	if [ $? -eq 0 ];then
		cti_pass "$ISNS_SMF smf enable method testing passed."
	else
		cti_fail "FAIL - $ISNS_SMF smf enable method testing failed."
	fi
	
	# Enable default domain	
	CMD="$ISNSADM enable-dd-set Default"
	cti_report "Executing: $CMD on $isns_server"
	run_rsh_cmd $isns_server "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - Default domain can NOT be enabled"
		return 
	fi	

}
#
# NAME
#	isns_smf_disable
#
# SYNOPSIS
#	isns_smf_disable
#
# DESCRIPTION:
#	This function executes disable method for testing.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function isns_smf_disable 
{
	typeset isns_server=$1
	isns_smf_snap $isns_server
	CMD="$SVCADM disable -s $ISNS_SMF"
	cti_report "Executing: $CMD"
	run_rsh_cmd $isns_server "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $ISNS_SMF smf service can NOT be disabled"
		return 
	fi	
	verify_isns_disable $isns_server	
	if [ $? -eq 0 ];then
		cti_pass "$ISNS_SMF smf disable method testing passed."
	else
		cti_fail "FAIL - $ISNS_SMF smf disable method testing failed."
	fi
}

#
# NAME
#	isns_smf_snap
#
# SYNOPSIS
#	isns_smf_snap
#
# DESCRIPTION:
#	This function save the timestamp into temporary variables.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	void
#
function isns_smf_snap 
{
	typeset isns_server=$1
	typeset CMD="$SVCS | grep $ISNS_SMF | \
	    grep -v grep | awk '{print \$2}'"
	run_rsh_cmd $isns_server "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - can not list the $ISNS_SMF smf service information"
		return 
	fi	
	ISNS_SMF_START_TIME=`get_cmd_stdout`	
}


#
# NAME
#	verify_isns_enable
# DESCRIPTION
#	Verify that the isns enable operation successfully or not.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	Sets the result code
#	0 - isns enable operation succeed
#	1 - isns enable operation fail
function verify_isns_enable 
{
	typeset isns_server=$1
	typeset CMD="$SVCS | grep $ISNS_SMF | \
	    grep -v grep | grep online | awk '{print \$2}'"
	run_rsh_cmd $isns_server "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - can not list the $ISNS_SMF smf service information"
		return 1
	fi	
	ISNS_SMF_CURRENT_TIME=`get_cmd_stdout`
	if [ -z "$ISNS_SMF_START_TIME" ];then
		if [ -n "$ISNS_SMF_CURRENT_TIME" ];then
			cti_report "PASS - svcadm enable $ISNS_SMF passed from disable to enable."
			return 0
		else
			cti_report "FAIL - $ISNS_SMF smf is not started/online (enable)."
			return 1
		fi
	elif [ -n "$ISNS_SMF_START_TIME" ];then
		if [ "$ISNS_SMF_CURRENT_TIME" = "$ISNS_SMF_START_TIME" ];then
			cti_report "PASS - svcadm enable $ISNS_SMF passed from enable to enable."
			return 0
		else
			cti_report "FAIL - $ISNS_SMF smf is restarted/online (enable)."
			return 1
		fi
	else
		cti_report "FAIL - $ISNS_SMF smf is invalid (enable)."
		return 1
	fi
}

#
# NAME
#	verify_isns_disable
# DESCRIPTION
#	Verify that the isns disable operation successfully or not.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	Sets the result code
#	0 - isns disable operation succeed
#	1 - isns disable operation fail
function verify_isns_disable 
{
	typeset isns_server=$1
	typeset CMD="$SVCS | grep $ISNS_SMF | \
	    grep -v grep | grep online | awk '{print \$2}'"
	run_rsh_cmd $isns_server "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - can not list the $ISNS_SMF smf service information"
		return 1
	fi	
	ISNS_SMF_CURRENT_TIME=`get_cmd_stdout`
	if [ -z "$ISNS_SMF_CURRENT_TIME" ];then
		if [ -n "$ISNS_SMF_START_TIME" ];then
			cti_report "PASS - svcadm enable $ISNS_SMF passed "\
				"from enable to disable."
			return 0
		else
			cti_report "PASS - svcadm disable $ISNS_SMF passed"\
				"from disable to disable."
			return 0
		fi
	else
		cti_report "FAIL - $ISNS_SMF service is not stopped after disable.."
		return 1
	fi
}

#
# NAME
#	isns_smf_reload
#
# SYNOPSIS
#	isns_smf_reload
#
# DESCRIPTION:
#	This function clean up all the persitent data in target host and
#	reload the stmf service as a cleaned one
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function isns_smf_reload 
{	
	typeset isns_server=$1
	typeset CMD="$SVCCFG delete -f $ISNS_SMF"
	run_rsh_cmd $isns_server "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - delete smf entry $ISNS_MANIFEST failed."
		return 1
	fi
	cti_report "isns_server smf delete method testing passed."
	typeset CMD="rm -rf /etc/isns/isnsdata*"
	run_rsh_cmd $isns_server "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - delete the isns data xml depository failed."
		return 1
	fi	
	typeseet CMD="$SVCCFG import $ISNS_MANIFEST"
	run_rsh_cmd $isns_server "$CMD"
	if [ $? -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - import smf entry $ISNS_MANIFEST failed."
		return 1
	fi
	cti_report "$ISNS_SMF smf import method testing passed."
	return 0
}
#
# NAME
#	isns_cleanup
#
# SYNOPSIS
#	isns_cleanup
#
# DESCRIPTION:
#	This function clean up all the objects related to isns server
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function isns_cleanup
{
	typeset isns_server=$1
	isns_smf_disable $isns_server
	sleep 5
	isns_smf_reload $isns_server
	sleep 1
	isns_smf_enable $isns_server
	sleep 5
}
#
# NAME
#	isnsadm_verify
# DESCRIPTION
#	iterate all the isns servers to verify the target node list
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	Sets the result code
#	void
#
function isnsadm_verify 
{
	typeset isns_server
	for isns_server in $DEFAULTS_ISNS_SERVER
	do
		echo "$isns_server" | grep ":" >/dev/null 2>&1
		if [ $? -eq 0 ];then
			isns_server=$(echo $isns_server | cut -d: -f1)
		fi
		compare_isns $isns_server
	done
}
#
# NAME
#	compare_isns
# DESCRIPTION
#	Compare the actual node list of default discovery domian to what 
#	the test suite thinks the node list should be within the specified isns.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	Sets the result code
#	void
#
function compare_isns
{
	typeset isns_server=$1
	typeset server=$(format_shellvar $isns_server)
	cti_report "Executing: isnsadm_verify $isns_server start"
	typeset cmd="${ISNSADM} list-dd -v Default"
	typeset Default_fnd=0
	typeset Node_fnd=0
	eval chk_NODES="\"\$ISNS_${server}_TARGET\""
	run_rsh_cmd $isns_server "$cmd"
	get_cmd_stdout | while read line
	do
		if [ $Default_fnd -eq 0 ];then
			echo $line | grep "DD name: Default" > /dev/null 2>&1
			if [ $? -eq 0 ];then
				Default_fnd=1
			fi
			continue
		fi
		echo $line | grep "iSCSI name:" > /dev/null 2>&1
		if [ $? -eq 0 ];then
			Node_fnd=0
			chk_NODE=`echo $line | sed -e 's/ *iSCSI name: //'`
			unset NODE_list
			for chk_node in $chk_NODES
			do
				if [ "$chk_node" = "$chk_NODE" ];then
					Node_fnd=1
				else
					NODE_list="$NODE_list $chk_node"
				fi
			done
			if [ $Node_fnd -eq 0 ];then
				cti_fail "WARNING: TARGET NODE $chk_NODE is in "\
					"listed output but not in stored info."
			fi
			chk_nodes="$NODE_list"
		fi
	done 

	if [ "$chk_nodes" ];then
		cti_fail "WARNING: TARGETS NODES $chk_nodes are in "\
			"stored info but not in listed output."
	fi
	cti_report "Executing: isnsadm_verify $isns_server end"
}

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

if [ "$TARGET_TYPE" = "FC" ];then
	MPXIO_CONF=/kernel/drv/fp.conf
elif [ "$TARGET_TYPE" = "FCOE" ];then
	MPXIO_CONF=/kernel/drv/fp.conf
elif [ "$TARGET_TYPE" = "ISCSI" ];then
	MPXIO_CONF=/kernel/drv/iscsi.conf
else
	cti_report "Not valid TARGET_TYPE"
fi
#
# NAME
#	stmsboot_enable_mpxio()
# DESCRIPTION
#	some protocols like iSCSI are not supported by stmfsboot,
#	to modify the configuration file is the common way to handle
# ARGUMENT
#	$1 - HOSTNAME
#
# RETURN
#	0 - enable mpxio and reboot passed.
#	1 - enable mpxio and reboot failed.
#
function stmsboot_enable_mpxio
{
	typeset HOSTNAME=$1

	check_enable_mpxio $HOSTNAME
	if [ $? -eq 0 ];then
		cti_report "$HOSTNAME: enable mpxio already"
		return 0
	else
		typeset CMD="sed -e"
		CMD="$CMD 's/^mpxio-disable=\"yes\"/mpxio-disable=\"no\"/g'"
		CMD="$CMD $MPXIO_CONF"
		run_rsh_cmd $HOSTNAME "$CMD"
		if [ `get_cmd_retval` -eq 0 ];then
			scp $CMD_STDOUT root@$HOSTNAME:$MPXIO_CONF
			host_reboot $HOSTNAME -r
		fi
		run_rsh_cmd $HOSTNAME \
			"grep '^mpxio-disable=\"no\"' $MPXIO_CONF"
		if [ `get_cmd_retval` -ne 0 ];then
			cti_fail "FAIL - stmsboot enable mpxio failed."			
			return 1
		fi
	fi
	cti_report "$HOSTNAME: stmsboot enable mpxio"	
	return 0	
	
}

#
# NAME
#	stmsboot_disable_mpxio()
# DESCRIPTION
#	some protocols like iSCSI are not supported by stmfsboot,
#	to modify the configuration file is the common way to handle
#
# ARGUMENT
#	$1 - HOSTNAME
#
# RETURN
#	0 - disable mpxio and reboot passed.
#	1 - disable mpxio and reboot failed.
#
function stmsboot_disable_mpxio
{
	typeset HOSTNAME=$1

	check_disable_mpxio $HOSTNAME
	if [ $? -eq 0 ];then
		cti_report "$HOSTNAME: disable mpxio already"
		return 0
	else
		typeset CMD="sed -e"
		CMD="$CMD 's/^mpxio-disable=\"no\"/mpxio-disable=\"yes\"/g'"
		CMD="$CMD $MPXIO_CONF"
		run_rsh_cmd $HOSTNAME "$CMD"
		if [ `get_cmd_retval` -eq 0 ];then
			scp $CMD_STDOUT root@$HOSTNAME:$MPXIO_CONF
			host_reboot $HOSTNAME -r
		fi

		run_rsh_cmd $HOSTNAME \
			"grep '^mpxio-disable=\"yes\"' $MPXIO_CONF"
		if [ `get_cmd_retval` -ne 0 ];then
			cti_fail "FAIL - stmsboot disable mpxio failed."
			return 1
		fi
	fi
	cti_report "$HOSTNAME: stmsboot disable mpxio"	
	return 0	
	
}


#
# NAME
#	check_enable_mpxio()
# DESCRIPTION
#	check the mpxio enable option in its relevant onfiguration file
#
# ARGUMENT
#	$1 - HOSTNAME
#
# RETURN
#	0 - mpxio is already enabled
#	1 - mpxio is already disabled
#
function check_enable_mpxio
{
	typeset HOSTNAME=$1

	run_rsh_cmd $HOSTNAME "grep '^mpxio-disable=\"no\"' $MPXIO_CONF"
	if [ `get_cmd_retval` -ne 0 ];then
		return 1
	else
		return 0	
	fi
	
}

#
# NAME
#	check_disable_mpxio()
# DESCRIPTION
#	check the mpxio disable option in its relevant onfiguration file
#
# ARGUMENT
#	$1 - HOSTNAME
#
# RETURN
#	0 - mpxio is already disabled
#	1 - mpxio is already enabled
#
function check_disable_mpxio
{
	typeset HOSTNAME=$1

	run_rsh_cmd $HOSTNAME "grep '^mpxio-disable=\"yes\"' $MPXIO_CONF"
	if [ `get_cmd_retval` -ne 0 ];then
		return 1
	else
		return 0	
	fi
	
}
	

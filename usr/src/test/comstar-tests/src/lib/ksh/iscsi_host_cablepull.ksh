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

#
#
# NAME
#       iscsi_initiator_portal_up_down_io()
# DESCRIPTION
#       plumb/un-plumb the initiator portal to run the failover
#
# ARGUMENT
#	$1 - initiator host
#	$2 - the seconds of initiaotr portal up/down intervals
#	$3 - test rounds for initiator portal up/down
#
# RETURN
#       1 failed
#       0 successful
#
function iscsi_initiator_portal_up_down_io
{
	typeset host_name=$1
	typeset intervals=$2
	typeset max_iter=$3
	cti_report "Start host side cable pull with "\
		"ifconfig plumb/un-plumb tests on host $host_name."
	
	typeset portal_list=$(get_portal_list $host_name)
	cti_report "INFO - $host_name is being used by test suite"\
	    "for rlogin, skip the up/down operation"
	portal_list=$(echo "$portal_list" | sed -e "s/$host_name//g")

	typeset iter=1
	typeset t_portal
	while [ $iter -le $max_iter ]	
	do
		cti_report "Executing: running initiator portal up - down to "\
			"verify failover with $max_iter round "\
			"and $intervals intervals"
		for t_portal in $portal_list
		do
	
			ifconfig_down_portal $host_name $t_portal
			cti_report "sleep $intervals intervals after un-plumb initiator portal"
			sleep $intervals

			ifconfig_up_portal $host_name $t_portal
			cti_report "sleep $intervals intervals after plumb initiator portal"
			sleep $intervals
		done
		(( iter+=1 ))
	done
}

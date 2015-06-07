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
# ident	"@(#)tp_zones_named_001.ksh	1.2	08/12/19 SMI"
#

LOGFILE=${LOGDIR}/mkdir.out
. ${TET_SUITE_ROOT}/lofi-tests/lib/fs_common

#
# start __stc_assertion__
#
# ASSERTION: zones_named_001
#
# DESCRIPTION:
#	In a non-global zone, the lofiadm command should fail.
#
# STRATEGY:
#	- Make sure we're operating in a named zone.
#	- Execute the lofiadm command with no arguments.  The command is
#	  expected to fail.
#
# end __stc_assertion__
#
function tp_zones_named_001 {
	typeset cmd
	typeset status=0

	typeset -r ASSERTION="zones_named_001"
	typeset -r TP_NAME=tp_${ASSERTION}
	typeset -r ME=$(whence -p ${0})
	extract_assertion_info $(dirname $ME)/$TP_NAME

	# Initialization
	cti_pass
	cti_assert $ASSERTION "lofiadm command should fail in non-global zone"

	# Make sure we're in a non-global zone
	global_zone_check
	if (( $? == 0 )); then
		cti_untested "Cannot execute this test in the global zone"
		return
	fi

	# Execute the lofiadm command
	cmd="lofiadm"
	record_cmd_execution "$cmd"
	cti_execute "PASS" "$cmd"

	if (( $? == 0 )); then
		cti_fail "'lofiadm' command succeeded when it was expected" \
		    "to fail"
		status=1
	else
		cti_pass "'lofiadm' command failed when executed in" \
		    "non-global zone, as expected"
	fi

	if [[ -n "$VERBOSE" ]] || (( $status != 0 )); then
		display_execution_record
	else
		delete_execution_record
	fi
}

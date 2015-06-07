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
# ident	"@(#)startup_cleanup_common.ksh	1.3	09/01/23 SMI"
#

#
# NAME
#	lofi_check
#
# SYNOPSIS
#	lofi_check
#
# DESCRIPTION
#	Make sure the system looks sane and usable from a lofi point
#	of view.  Expected to be called by startup() functions in 'tc' files.
#
# RETURN VALUES
#	0	Everything looks ok
#	1	Issue found with lofi
#
function lofi_check {
	typeset retval=0

	if [[ ! -x /usr/sbin/lofiadm ]]; then
		cti_report "/usr/sbin/lofiadm does not exist or is not" \
		    "executable"
		retval=1
	fi

	if [[ -d /dev/lofi ]]; then
		cti_report "Error: /dev/lofi already exists -- there appears" \
		    "to be a preexisting lofi config"
		cti_report "Delete any existing lofi devices and make sure" \
		    "that the /dev/lofi directory has been deleted as well"
		retval=1
	fi

	return $retval
}


#
# NAME
#	scratch_dir_check
#
# SYNOPSIS
#	scratch_dir_check
#
# DESCRIPTION
#	Verify that the SCRATCH_DIR variable has been set and points to
#	a valid location.
#
# RETURN VALUES
#	0	Verification of SCRATCH_DIR succeeded
#	1	Verification of SCRATCH_DIR failed
function scratch_dir_check {
	typeset status=0

	if [[ -n "$SCRATCH_DIR" ]]; then
		if [[ ! -d "$SCRATCH_DIR" ]]; then
			cti_report "Error: value of SCRATCH_DIR" \
			    "($SCRATCH_DIR) is not a directory"
			status=1
		fi
	else
		cti_report "Error: SCRATCH_DIR not set."
		status=1
	fi

	if (( $status != 0 )); then
		cti_report "The SCRATCH_DIR environment variable must point" \
		    "to a valid directory."
		cti_report "Set it either in" \
		    "\$TET_SUITE_ROOT/lofi/config/test_config or when" \
		    "invoking the test suite"
		cti_report "e.g. run_test -v SCRATCH_DIR=<value> lofi"
	fi

	return $status
}


#
# NAME
#	global_zone_check
#
# SYNOPSIS
#	global_zone_check
#
# DESCRIPTION
#	Check to see if we're running in the global zone
#
# RETURN VALUES
#	0	Running in global zone
#	1	Running in named zone
#
function global_zone_check {
	typeset -r ZONEADM=/usr/sbin/zoneadm

	if [[ -x $ZONEADM ]]; then
		# zoneadm executable exists.  Execute 'zoneadm list' and
		# see if the global zone is listed.  If so, we're running
		# in the global zone.  If not, we're running in a named zone.
		$ZONEADM list | grep global >/dev/null
		if (( $? == 0 )); then
			return 0
		else
			return 1
		fi
	else
		# No zoneadm executable on this system, so we must be
		# running in the equivelent of the global zone.
		return 0
	fi

}


#
# NAME
#	mnt_check
#
# SYNOPSIS
#	mnt_check
#
# DESCRIPTION
#	Verify that the directory /mnt exists and that there is not
#	currently a filesystem mounted there.
#
# RETURN VALUES
#	0	/mnt exists and no filesystem mounted
#	1	/mnt does not exist, or exists but has a filesystem
#		mounted.
#
function mnt_check {
	# Is /mnt a directory?
	if [[ ! -d /mnt ]]; then
		cti_report "Error: Directory /mnt does not exist.  This" \
		    "directory must exist for the tests to run."
		return 1
	fi

	# Is something currently mounted on /mnt?
	typeset mnt_fs=`awk ' { if ($2 == "/mnt") { print } } ' /etc/mnttab`
	if [[ -n "$mnt_fs" ]]; then
		cti_report "Error: /etc/mnttab indicates a filesystem is" \
		    "currently mounted on /mnt.  The filesystem must be" \
		    "unmounted before the tests can continue."
		return 1;
	fi

	return 0
}

#
# NAME
#	root_check
#
# SYNOPSIS
#	root_check
#
# DESCRIPTION
#	Verify if we're being executed with root permissions.
#
# RETURN VALUES
#	0	Executing as root
#	1	Not executing as root
#
function root_check {
	# Use /usr/xpg4/bin/id rather than /usr/bin/id as the latter does not
	# support the '-u' flag on s10.
	typeset uid=`/usr/xpg4/bin/id -u`
	if (( $uid == 0 )); then
		# Executing as root
		return 0
	else
		# Not executing as root
		cti_report "Error: Test suite must be executed with root" \
		    "permissions (uid reported as $uid, not 0)"
		return 1
	fi
}


#
# NAME
#	typical_startup_checks
#
# SYNOPSIS
#	typical_startup_checks
#
# DESCRIPTION
#	Run all of the typical startup checks.
#
# RETURN VALUES
#	0	All checks passed
#	non-0	One or more checks failed
#
function typical_startup_checks {
	typeset status=0
	typeset gzstatus

	scratch_dir_check
	(( status = $status + $? ))
	lofi_check
	(( status = $status + $? ))
	mnt_check
	(( status = $status + $? ))
	root_check
	(( status = $status + $? ))
	global_zone_check
	gzstatus=$?
	if (( $gzstatus != 0 )); then
		cti_report "Appear to be running in a named zone.  lofi is" \
		    "only supported in the global zone."
	fi
	(( status = $status + $gzstatus ))

	return $status
}

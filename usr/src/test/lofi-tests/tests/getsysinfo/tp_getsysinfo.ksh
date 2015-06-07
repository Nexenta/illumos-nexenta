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
# ident	"@(#)tp_getsysinfo.ksh	1.2	08/12/19 SMI"
#


LOGFILE=${LOGDIR}/mkdir.out

#
# NAME
#	gather_system_info
#
# SYNOPSIS
#	gather_system_info
#
# DESCRIPTION
#	This function gathers various hardware/software configuration
#	information about the system and places it in the TET execution
#	log.
#
# RETURN VALUE
#	undefined
#
function gather_system_info {
	#
	# Paths to system commands called by this script
	#
	CAT=/usr/bin/cat
	ISAINFO=/usr/bin/isainfo
	LS=/usr/bin/ls
	NAWK=/usr/bin/nawk
	NM=/usr/ccs/bin/nm
	PRTCONF=/usr/sbin/prtconf
	PSRINFO=/usr/sbin/psrinfo
	TMPDIR=/tmp
	UNAME=/usr/bin/uname

	# File to store temporary data in
	TMPFILE=${TMPDIR}/newinfo_tmp_$$
	
	# File to write output to
	OUTPUT=${TMPDIR}/sysinfo_$$
	
	# Divider for visual formatting
	DIVIDER="----------------------------------------------------------------------"
	

	#
	# Datestamp
	#
	DATE=`/usr/bin/date`
	echo "Date:         $DATE" >$OUTPUT
	
	#
	# Hostname
	#
	HOSTNAME=`/usr/bin/hostname`
	echo "System Name:  $HOSTNAME" >>$OUTPUT
	echo $DIVIDER >>$OUTPUT
	
	#
	# Identify the operating system.  Use 'uname -a' output and the
	# contents of /etc/release if it exists (present on 2.6 and later).
	#
	echo "Operating System:" >>$OUTPUT
	echo "  'uname -a' output:\n    \c" >>$OUTPUT
	$UNAME -a >>$OUTPUT
	if [[ -r /etc/release ]]; then
		echo "  Contents of /etc/release" >>$OUTPUT
		cat /etc/release >>$OUTPUT
	fi
	#
	# Use 'isainfo' to determine what version of the OS is running (32 or
	# 64 bit) on sparc systems.  This command doesn't exist prior to
	# Solaris 7, so make sure it exists before attempting to run it.
	#
	echo "  'isainfo' output:  \c" >>$OUTPUT
	if [[ -x $ISAINFO ]]; then
		ARCH=`$ISAINFO`
		echo $ARCH >>$OUTPUT
	else
		echo "Not available." >>$OUTPUT
	fi
	#
	# Try to determine if we're running a debug or non-debug kernel.  In
	# order to do so we need /usr/ccs/bin/nm which may or may not be
	# present depending on what install cluster was applied.
	#
	echo "  Kernel type (debug or non-debug):  \c" >>$OUTPUT
	if [[ -n "$ARCH" && -x $NM ]]; then
		if [[ "$ARCH" = "sparcv9 sparc" ]]; then
			MD_FILE=/kernel/drv/sparcv9/md
		elif [[ "$ARCH" = "amd64 i386" ]]; then
			MD_FILE=/kernel/drv/amd64/md
		else
			MD_FILE=/kernel/drv/md
		fi
		if /usr/ccs/bin/nm $MD_FILE | grep md_in_mx >/dev/null
		then
			echo "debug" >>$OUTPUT
		else
			echo "non-debug" >>$OUTPUT
		fi
	else
		echo "unknown (need $ISAINFO and $NM to determine)" >>$OUTPUT
	fi

	echo $DIVIDER >>$OUTPUT
	
	echo "Hardware:" >> $OUTPUT
	
	#
	# System type
	#
	$PRTCONF > $TMPFILE
	SYSTEM=`grep "^SUNW" $TMPFILE|$NAWK ' BEGIN { FS = "," } { print $2 } ' - `
	if [[ -z "$SYSTEM" ]]; then
		SYSTEM="(No Sun system hardware ID found in prtconf output)"
	fi
	echo "  System Type:  $SYSTEM" >>$OUTPUT
	
	#
	# Memory size
	#
	MEMORY=`grep "Memory size:" $TMPFILE|$NAWK ' BEGIN { FS = ":" } { print $2 }' -`
	echo "  Memory Size: $MEMORY" >>$OUTPUT
	
	#
	# Retrieve processor information
	#
	echo "CPU(s):       #      Type        Speed" >>$OUTPUT
	echo "|             ---  ----------  -------" >>$OUTPUT
	$PSRINFO -v >$TMPFILE
	$NAWK ' BEGIN { proc_count = 0 } { if ( $1 == "Status" )
		 {
		   arr[proc_count,0] = $5
		   proc_count++
		 }
		 if ( $3 == "processor" && $4 == "operates" )
		 {
		   arr[proc_count -1,1] = $2
		   arr[proc_count -1,2] = $6
		 }
	       }
	       END {
		 for ( i = 0; i < proc_count; i++ )
		 {
			printf("|             %-3d  %-10s  %s MHz\n",arr[i,0],arr[i,1],arr[i,2]);
		 }
	       } ' $TMPFILE >>$OUTPUT
	echo $DIVIDER >>$OUTPUT
	
	cti_reportfile $OUTPUT
	rm -f $TMPFILE $OUTPUT
}


#
# TET 'test purpose' function that's actually just a wrapper for the
# gather_system_info function.
#
function getsysinfo {
	cti_assert getsysinfo "Gather general system info for lofi tests"
	gather_system_info

	cti_pass
}

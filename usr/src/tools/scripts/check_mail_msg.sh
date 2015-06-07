#!/bin/sh
#
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#

#
# Copyright (c) 2013 by Delphix. All rights reserved.
# Copyright 2013 Nexenta Systems, Inc.  All rights reserved.
#

# This is a POST_NIGHTLY hook script to check the mail_msg file.
#
# Checks the given mail_msg file ($1) section starting $2 and ending $3
# If that section exists is non-empty, set the abort flag.
#
function check
{
	typeset mail_msg start end

	mail_msg="$1"
	start="==== $(echo "$2" | sed "s@/@\\\\/@") ===="
	end="==== $(echo "$3" | sed "s@/@\\\\/@") ===="

	if [[ ! -z "$(sed -n "/^$start\$/,/^$end\$/p" $mail_msg |\
		sed -e "/^$start\$/d" -e "/^$end\$/d" -e "/^$/d")" ]]; then
		echo "Noise in section: $2"
		touch $TMPDIR/abort
	fi
}

#
# Leave a copy of the mail_msg file in the top of the WS where it's
# easier for build automation to find it.  The Jenkins script may
# "cat $workspace/mail_msg.txt" after nightly runs so that it's
# "console" output shows any build noise, etc.
#
cd ${CODEMGR_WS}
cp ${LLOG}/mail_msg mail_msg.txt

# Check sections that should be empty:

check mail_msg.txt "Build errors" "Build warnings"
check mail_msg.txt "Build errors (DEBUG)" "Build warnings (DEBUG)"
check mail_msg.txt "Build errors (non-DEBUG)" "Build warnings (non-DEBUG)"

# nza-kernel has warnings.  Fix those, then uncomment these...
#check mail_msg.txt "Build warnings" "Elapsed build time"
#check mail_msg.txt "Build warnings (DEBUG)" "Elapsed build time (DEBUG)"
#check mail_msg.txt "Build warnings (non-DEBUG)" \
#		   "Elapsed build time (non-DEBUG)"

# nza-kernel has warnings.  Fix those, then uncomment these too.
#check mail_msg.txt "Validating manifests against proto area" \
#		   "Check ELF runtime attributes"
#check mail_msg.txt "lint warnings src" "lint noise differences src"
#check mail_msg.txt "cstyle/hdrchk errors" "Find core files"

if [ -f $TMPDIR/abort ]; then
	echo "\nmail_msg has noise. FAIL" >> mail_msg.txt
	exit 1
fi

exit 0

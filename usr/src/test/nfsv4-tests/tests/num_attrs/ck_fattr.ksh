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
# Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
#  Filesystem statistics program for NFSv4 numbered attributes tests:
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

if (( $# != 2 ))
then
        print -u2 "Usage: $0 <mountpt> <flag>"
        exit 1
fi
MNTPT=$1
FLAG=$2

nfsstat -m | nawk -v mount=$MNTPT -v flag=$FLAG '
$1 == mount,/^$/ {
        if ($1 == "Flags:") {
                num = split($2, flags, ",")
                for (i = 1; i <= num; i++) {
                        if (flags[i] == flag) {
                                val="true"
                        } else if (match(flags[i], flag "=")) {
                                val=flags[i]
                                sub(flag "=", "", val)
                        }
                }
        }
}

END {
	if (length(val) > 0) {
		print val
	} else {
		print ""
	}
} '

exit 0

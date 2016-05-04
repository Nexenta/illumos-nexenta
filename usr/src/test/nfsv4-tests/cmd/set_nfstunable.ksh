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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# set_nfstunable.ksh support script.
# Sets the specified nfs tunable in /etc/default/nfs to the provided value
#

[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

NAME=$(basename $0)

(( $# < 1 )) && echo "usage: $NAME tunable=value ..." && return -1

id | grep "0(root)" > /dev/null 2>&1
if (( $? != 0 )); then
        echo "Must be root to run this script."
        return 1
fi

function wait_now
{
    [[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
    (( $# < 2 )) && \
        echo "Usage: wait_now max_TIMER the_condition" && \
        return -1

    Timer=$1
    shift
    Wcond=$@

    i=0
    while (( i < Timer ))
    do
        eval $Wcond
        (( $? == 0 )) && return 0
        sleep 1
        i=$((i + 1))
    done
    echo "wait_now function failed"
    return $i
}

ret_value=""
set_value=""
check_tunable=""
check_value=""
for property in $*; do
	typeset -u tunable=$(echo $property | awk -F= '{print $1}')
	value=$(echo $property | awk -F= '{print $2}')

	orig=$(sharectl get -p $tunable nfs | awk -F= '{print $2}')
	if (( $? != 0 )); then
		print -u 2 "$NAME: failed to get the original value \
			of $tunable: $orig"
		return 1
	fi
	if [[ -z $orig ]]; then
		case $tunable in
			SERVER_VERSMIN | CLIENT_VERSMIN )
				orig=2
				;;
			SERVER_VERSMAX | CLIENT_VERSMAX )
				orig=4
				;;
			SERVER_DEDEGATION )
				orig=on
				;;
			* )
				;;
		esac
	fi

	# check if the value equals the original value
	if [[ $value != $orig ]]; then
		ret_value="$ret_value $tunable=$orig"
		set_value="$set_value -p $tunable=$value"
		check_tunable="$check_tunable -p $tunable"
		check_value="$check_value $tunable=$value"
	fi
done

if [[ -n $set_value ]]; then
	sharectl set $set_value nfs
	if (( $? != 0 )); then
		print -u 2 "$NAME: failed to set the nfs tunable: $set_value"
		return 1
	fi
	wait_now 10 \
	    "[[ \$(echo \$(sharectl get $check_tunable nfs)) == $check_value ]]"
	if (( $? != 0 )); then
		print -u 2 "$NAME: the nfs tunable has not been updated even
		after 10 seconds: $(sharectl get $check_tunable nfs)"
		return 1
	fi
	echo $ret_value
fi
return 0

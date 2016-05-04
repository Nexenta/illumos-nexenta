#!/usr/bin/ksh -p
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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# libmapid02.sh - libmapid tests for the following configuration:
#
#       NFSMAPID_DOMAIN   DNS TXT RR      DNS domain  NIS domain
#       ===============   ==============  ==========  ==========
#       No                Yes             Yes         Yes
#

[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

# set up script execution environment
. ./dom_env

# should run as root
is_root "$NAME{setup}:" "All tests for domain affected"

# comment out NFSMAPID_DOMAIN string in /etc/default/nfs
comm_domain_default_nfs

# refresh nfsmapid
mapid_service refresh $TIMEOUT "failed to refresh mapid service" \
    "ERROR" || exit $UNINITIATED

# start libmapid_syscfgd.ksh on the background
libmapid_syscfgd >/dev/null 2>&1 &
sleep 2
ins=$(ps -ef | grep libmapid_syscfgd | grep -v grep | wc -l)
(( "$ins" == 1 ))
ckreturn $? "$ins instances of libmapid_syscfgd found" /dev/null "ERROR" \
    || exit $UNINITIATED

# assertion list
ASSERTIONS=${ASSERTIONS:-"a b c"}

# generate assertion descriptions
gen_assert_desc $NAME "as_"

#
# Assertion definition
#

# as_a: No domain in /etc/default/nfs, DNS up, TXT RR present, call 
#	mapid_get_domain(), get TXT RR
function as_a {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=$txt_rr
	assertion a "$(get_assert_desc a)" $exp

	# Get mapid domain
	act=$(./get_domain)
	ckreturn $? "get_domain utility failed" /dev/null "UNRESOLVED" \
	   || return $UNRESOLVED

	# check assertion
	ckres2 "get_domain" "$act" "$exp" "domains differ" || return $FAIL
}

# as_b: No domain in /etc/default/nfs, DNS up, TXT RR present, call
#       mapid_derive_domain(), get TXT RR
function as_b {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=$txt_rr
	assertion b "$(get_assert_desc b)" $exp

	# Get mapid domain
	act=$(./derive_domain_dl)
	ckreturn $? "derive_domain_dl utility failed" /dev/null "UNRESOLVED" \
	   || return $UNRESOLVED

	# check assertion
	ckres2 "derive_domain_dl" "$act" "$exp" "domains differ" || return $FAIL
}

# as_c: No domain in /etc/default/nfs, then it is added, the callback function
#	passed to mapid_reeval_domain() is invoked
function as_c {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=0
	assertion c "$(get_assert_desc c)" $exp

	# setup and check callback function is called
	./reeval_callback libmapid_modify_nfscfg libmapid_restore_nfscfg \
	    >$LOGFILE 2>&1

	# Check Assertion
	ckres2 "reeval_callback" $? $exp "mapid_reeval_domain() failed" \
	    $LOGFILE || return $FAIL
}

#
# Run assertions
#

echo "\nLIBMAPID02 Starting Assertions\n"

for i in $ASSERTIONS
do
	eval as_${i} || print_state
done

echo "\nLIBMAPID02 assertions finished!\n"

# notify libmapid_syscfgd.ksh to exit
touch $TMPDIR/.libmapid/libmapid_quit
wait_now 10 "! pgrep -z $(zonename) libmapid_syscfgd >/dev/null" 

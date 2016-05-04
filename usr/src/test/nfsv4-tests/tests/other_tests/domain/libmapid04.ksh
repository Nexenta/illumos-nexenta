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
# Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# libmapid04.sh - libmapid tests for the following configuration:
#
#       NFSMAPID_DOMAIN   DNS TXT RR      DNS domain  NIS domain
#       ===============   ==============  ==========  ==========
#       No                No              No          Yes
#

[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

# set up script execution environment
. ./dom_env

# should run as root
is_root "$NAME{setup}:" "All tests for domain affected"

# comment out NFSMAPID_DOMAIN string in /etc/default/nfs
comm_domain_default_nfs

# remove /etc/resolv.conf
rm -f /etc/resolv.conf

# refresh nfsmapid
mapid_service refresh $TIMEOUT "failed to refresh mapid service" \
    "ERROR" || exit $UNINITIATED

# assertion list
ASSERTIONS=${ASSERTIONS:-"a b"}

# generate assertion descriptions
gen_assert_desc $NAME "as_"

#
# Assertion definition
#

# as_a: No domain in /etc/default/nfs, no /etc/resolv.conf, call 
#	mapid_get_domain(), get domain from NIS
function as_a {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=$nis_domain
	assertion a "$(get_assert_desc a)" $exp

	# Get mapid domain
	act=$(./get_domain)
	ckreturn $? "get_domain utility failed" /dev/null "UNRESOLVED" \
	   || return $UNRESOLVED

	# check assertion
	ckres2 "get_domain" "$act" "$exp" "domains differ" || return $FAIL
}

# as_b: No domain in /etc/default/nfs, no /etc/resolv.conf, call
#	mapid_derive_domain(), get domain from NIS
function as_b {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=$nis_domain
	assertion b "$(get_assert_desc b)" $exp

	# Get mapid domain
	act=$(./derive_domain_dl)
	ckreturn $? "derive_domain_dl utility failed" /dev/null "UNRESOLVED" \
	   || return $UNRESOLVED

	# check assertion
	ckres2 "derive_domain_dl" "$act" "$exp" "domains differ" || return $FAIL
}

#
# Run assertions
#

echo "\nLIBMAPID04 Starting Assertions\n"

for i in $ASSERTIONS
do
	eval as_${i} || print_state
done

echo "\nLIBMAPID04 assertions finished!\n"

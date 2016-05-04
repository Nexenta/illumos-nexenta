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
# nfsmapid04.sh - nfsmapid tests for the following configuration:
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

# get timeout value nfsmapid uses for domain checking
nfsdomain_tmout=$(get_nfsmapid_domain_tout_wrapper)

# comment out NFSMAPID_DOMAIN string in /etc/default/nfs
comm_domain_default_nfs

# remove /etc/resolv.conf
rm -f /etc/resolv.conf

# refresh nfsmapid server
mapid_service refresh $TIMEOUT "failed to refresh mapid service" \
    "UNRESOLVED" || exit $UNRESOLVED

# assertion list
ASSERTIONS=${ASSERTIONS:-"a"}

# generate assertion descriptions
gen_assert_desc $NAME "as_"

#
# Assertion definition
#

# as_a: No domain in /etc/default/nfs, no /etc/resolv.conf, get domain from NIS
function as_a {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

        exp=$nis_domain
        assertion a "$(get_assert_desc a)" $exp

        # Get mapid domain
        act=$(get_nfsmapid_domain)

        # Check Assertion
        ckres2 "get_nfsmapid_domain" "$act" "$exp" "domains differ" \
	    || return $FAIL
}

#
# Run assertions
#

echo "\nNFSMAPID04 Starting Assertions\n"

for i in $ASSERTIONS
do
	eval as_${i} || print_state
done

echo "\nNFSMAPID04 assertions finished!\n"

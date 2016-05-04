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
# nfsmapid02.sh - nfsmapid tests for the following configuration:
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

# get timeout value nfsmapid uses for domain checking
nfsdomain_tmout=$(get_nfsmapid_domain_tout_wrapper)

# comment out NFSMAPID_DOMAIN string in /etc/default/nfs
comm_domain_default_nfs

# refresh nfsmapid
mapid_service refresh $TIMEOUT "failed to refresh mapid service" \
    "ERROR" || exit $UNINITIATED

# assertion list
ASSERTIONS=${ASSERTIONS:-"a b c d e"}

# generate assertion descriptions
gen_assert_desc $NAME "as_"

#
# Assertion definition
#

# as_a: No domain in /etc/default/nfs, DNS up, TXT RR present, use TXT RR
function as_a {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

        exp=$txt_rr
        assertion a "$(get_assert_desc a)" $exp

        # Get mapid domain
        mapid_service refresh $TIMEOUT "failed to refresh mapid service" \
            "UNRESOLVED" || return $UNRESOLVED
        act=$(get_nfsmapid_domain)

        # Check Assertion
        ckres2 "get_nfsmapid_domain" "$act" "$exp" "domains differ"
}

# as_b1: Current domain is TXT RR, then DNS down. After nfscfg_domain_tmout
#	timer expires, cache is on and domain is still TXT RR
# as_b2: DNS still down. After nfscfg_domain_tmout timer expires, cache is
#	still on and domain is still TXT RR
function as_b {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x
	
	#
	# Assertion b1
	#

	exp=1
        assertion b1 "$(get_assert_desc b1)" $exp

	# Setup: disable DNS server
	dns_service disable $TIMEOUT "failed to disable dns service" \
	    "UNRESOLVED" || return $UNRESOLVED

	# Wait for timeout and then get cache flag
	sleep $nfsdomain_tmout
	domain=$(get_nfsmapid_domain)
	act=$(get_dns_txt_cache_flag)

	# First check cache
	ckres2 -s "get_dns_txt_cache_flag" "$act" "$exp" \
	    "cache should be on; $NAME{b2} skipped" || return $FAIL
	
	# Then check domain
	ckres2 "get_nfsmapid_domain" "$domain" "$txt_rr" \
	    "domains differ; $NAME{b2} skipped" || return $FAIL

	#
	# Assertion b2
	#
	exp=1
        assertion b2 "$(get_assert_desc b2)" $exp

	# Wait for timeout and then get cache flag
	sleep $nfsdomain_tmout
	domain=$(get_nfsmapid_domain)
	act=$(get_dns_txt_cache_flag)

	# First check cache
	ckres2 -s "get_dns_txt_cache_flag" "$act" "$exp" "cache should be off" \
	    || return $FAIL
	
	# Then check domain
	ckres2 "get_nfsmapid_domain" "$domain" "$txt_rr" "domains differ" \
	    || return $FAIL
}

# as_c: Current domain is TXT RR, then DNS down, refresh nfsmapid, cache is
#	off and and get domain from DNS domain
function as_c {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

        exp=0
        assertion c "$(get_assert_desc c)" $exp

	# Setup: disable DNS server
	dns_service disable $TIMEOUT "failed to disable dns service" \
	    "UNRESOLVED" || return $UNRESOLVED

	# Refresh nfsmapid and then get cache flag
	mapid_service refresh $timeout "failed to refresh mapid service" \
	    "UNRESOLVED" || return $UNRESOLVED
	domain=$(get_nfsmapid_domain)
        act=$(get_dns_txt_cache_flag)

	# First check cache
	ckres2 -s "get_dns_txt_cache_flag" "$act" "$exp" "cache should be off" \
	    || return $FAIL
	
	# Then check domain
	ckres2 "get_nfsmapid_domain" "$domain" "$dns_domain" "domains differ" \
	    || return $FAIL
}

# as_d: Current domain is TXT RR, DNS up, remove /etc/resolv.conf. After
#	nfscfg_domain_tmout timer expires, cache is off and get domain from NIS
function as_d {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

        exp=0
        assertion d "$(get_assert_desc d)" $exp

	# Setup: remove /etc/resolv.conf file
	rm -f /etc/resolv.conf

	# Wait for timeout and then get cache flag
        sleep $nfsdomain_tmout
	domain=$(get_nfsmapid_domain)
        act=$(get_dns_txt_cache_flag)
	
	# First check cache
	ckres2 -s "get_dns_txt_cache_flag" "$act" "$exp" "cache should be off" \
	    || return $FAIL
	
	# Then check domain
	ckres2 "get_nfsmapid_domain" "$domain" "$nis_domain" "domains differ" \
	    || return $FAIL
}

# as_e: Current domain is TXT RR, DNS up, modify /etc/resolv.conf to set an
#	invalid domain. After nfscfg_domain_tmout timer expires, cache is off
#	and domain is the new DNS domain
function as_e {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=0
        assertion e "$(get_assert_desc e)" $exp

	# Setup: modify /etc/resolv.conf to set an invalid domain
	new_dom_dns="x.y.z"
	chg_domain_dns $new_dom_dns

        # Wait for timeout and then get cache flag
        sleep $nfsdomain_tmout
	domain=$(get_nfsmapid_domain)
        act=$(get_dns_txt_cache_flag)

	# First check cache
	ckres2 -s "get_dns_txt_cache_flag" "$act" "$exp" "cache should be on" \
	    || return $FAIL
	
	# Then check domain
	ckres2 "get_nfsmapid_domain" "$domain" "$new_dom_dns" "domains differ" \
	    || return $FAIL
}

#
# Run assertions
#

save_state STATE_NFSMAPID02

echo "\nNFSMAPID02 Starting Assertions\n"

for i in $ASSERTIONS
do
	eval as_${i} || print_state
	restore_state STATE_NFSMAPID02
done

clear_state STATE_NFSMAPID02

echo "\nNFSMAPID02 assertions finished!\n"

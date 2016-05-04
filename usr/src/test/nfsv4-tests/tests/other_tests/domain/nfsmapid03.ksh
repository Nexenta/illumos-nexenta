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
# nfsmapid03.sh - nfsmapid tests for the following configuration:
#
#       NFSMAPID_DOMAIN   DNS TXT RR      DNS domain  NIS domain
#       ===============   ==============  ==========  ==========
#       No                No              Yes         Yes
# 
# Note that there are two ways to do the "DNS TXT RR not available" set up.
# One is to remove the TXT RR string in named configuration files, another way
# is to shutdown DNS server. Both of these two ways are used in test cases in
# this file.
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

# modify /var/named/dns.test.nfs.master to remove TXT RR
chg_txt_field_dns /var/named/dns.test.nfs.master dummy=none

# restart DNS server
dns_service restart $TIMEOUT "failed to restart dns service" \
    "UNRESOLVED" || exit $UNRESOLVED

# refresh nfsmapid server
mapid_service refresh $TIMEOUT "failed to refresh mapid service" \
    "UNRESOLVED" || exit $UNRESOLVED

# assertion list
ASSERTIONS=${ASSERTIONS:-"a b c d"}

# generate assertion descriptions
gen_assert_desc $NAME "as_"

#
# Assertion definition
#

# as_a: No domain in /etc/default/nfs, DNS up, no TXT RR, get domain from
#	/etc/resolv.conf
function as_a {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

        exp=$dns_domain
        assertion a "$(get_assert_desc a)" $exp

        # Get mapid domain
        act=$(get_nfsmapid_domain)

        # Check Assertion
        ckres2 "get_nfsmapid_domain" "$act" "$exp" "domains differ" \
	    || return $FAIL
}

# as_b1: Current domain is from /etc/default/nfs, change DNS domain to
#	an invalid value, use the new DNS domain value after
#	nfscfg_domain_tmout timer expires
# as_b2: DNS domain changes back to a valid value, read the new DNS domain
#	value and connect to the server to get TXT RR after nfscfg_domain_tmout
#	timer expires
#
# Nfsmapid has a daemon thread to check domain configuration changes on the
# system periodically(300 seconds by default). When it reads domain from 
# /etc/default/nfs or /etc/resolv.conf files, it check those files' mtime 
# first. If mtime wasn't changed, it just uses the cahced value; otherwise,
# it reads the new value from those files.
#
# If DNS domain changes(as happend in above case), nfsmapid will connect to
# the server to get the appropriate TXT RR, and use that as domain value.
#
# Test cases b1 and b2 tests the above behaviors.
function as_b {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	#
	# Assertion b1
	#

	new_dns_domain="new.domain.for.test"
        exp=$new_dns_domain
        assertion b1 "$(get_assert_desc b1)" $exp

	# Setup: change DNS domain to an invalid value
	chg_domain_dns $new_dns_domain

        # Wait for timeout and get mapid domain
	sleep $nfsdomain_tmout
        act=$(get_nfsmapid_domain)

        # Check Assertion
        ckres2 "get_nfsmapid_domain" "$act" "$exp" \
	    "domains differ; $NAME{b2} skipped" || return $FAIL

	#
	# Assertion b2
	#

	exp=$txt_rr
        assertion b2 "$(get_assert_desc b2)" $exp

	# Setup: change DNS domain back to a valid value, and add TXT RR
	chg_domain_dns $dns_domain
	chg_txt_field_dns /var/named/dns.test.nfs.master $txt_rr
        dns_service restart $TIMEOUT "failed to restart dns service" \
            "UNRESOLVED" || return $UNRESOLVED

        # Wait for timeout and get mapid domain
	sleep $nfsdomain_tmout
        act=$(get_nfsmapid_domain)

        # Check Assertion
        ckres2 "get_nfsmapid_domain" "$act" "$exp" "domains differ" \
	    || return $FAIL
}

# as_c1: No domain in /etc/default/nfs, DNS down, get domain from
#	/etc/resolv.conf
# as_c2: Then DNS up, use TXT RR as domain after 35 seconds
#
# If DNS is configured but the DNS server doesn't respond, nfsmapid starts
# a thread to check that every 30 seconds. This test case is designed to 
# test the polling behavior.
function as_c {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	#
	# Assertion c1
	#

        exp=$dns_domain
        assertion c1 "$(get_assert_desc c1)" $exp

	# Setup: disable DNS service
        dns_service disable $TIMEOUT "failed to disable dns service" \
            "UNRESOLVED" || return $UNRESOLVED

        # Get mapid domain
        mapid_service refresh $TIMEOUT "failed to refresh mapid service" \
            "UNRESOLVED" || return $UNRESOLVED
        act=$(get_nfsmapid_domain)

        # Check Assertion
        ckres2 "get_nfsmapid_domain" "$act" "$exp" \
	    "domains differ; $NAME{c2} skipped" || return $FAIL

	#
	# Assertion c2
	#

	exp=$txt_rr
        assertion c2 "$(get_assert_desc c2)" $exp

	# Setup: set TXT RR value and enable DNS service
	chg_txt_field_dns /var/named/dns.test.nfs.master $txt_rr
        dns_service enable $TIMEOUT "failed to enable dns service" \
            "UNRESOLVED" || return $UNRESOLVED

        # Get mapid domain
	sleep 35
        act=$(get_nfsmapid_domain)

        # Check Assertion
        ckres2 "get_nfsmapid_domain" "$act" "$exp" "domains differ" \
	    || return $FAIL
}

# as_d1: No domain in /etc/default/nfs, DNS up, no TXT RR, wait until
#	nfscfg_domain_tmout timer expires, get domain from DNS domain,
#	cache is off
# as_d2: Then add TXT RR and restart DNS server, wait until
#	nfscfg_domain_tmout timer expires, get domain from TXT RR, cache is on
function as_d {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	#
	# Assertion d1
	#

        exp=0
        assertion d1 "$(get_assert_desc d1)" $exp

        # Get mapid domain
	sleep $nfsdomain_tmout
	act=$(get_dns_txt_cache_flag)
        domain=$(get_nfsmapid_domain)

        # First check cache
        ckres2 -s "get_dns_txt_cache_flag" "$act" "$exp" \
	    "cache should be off; $NAME{d2} skipped" || return $FAIL

        # Then check domain
        ckres2 "get_nfsmapid_domain" "$domain" "$dns_domain" \
	    "domains differ; $NAME{d2} skipped" || return $FAIL

	#
	# Assertion d2
	#
	
	exp=1
        assertion d2 "$(get_assert_desc d2)" $exp

	# Setup: set TXT RR and restart DNS server
	chg_txt_field_dns /var/named/dns.test.nfs.master $txt_rr
        dns_service restart $TIMEOUT "failed to restart dns service" \
            "UNRESOLVED" || return $UNRESOLVED

	# Get mapid domain
	sleep $nfsdomain_tmout
	act=$(get_dns_txt_cache_flag)
        domain=$(get_nfsmapid_domain)

        # First check cache
        ckres2 -s "get_dns_txt_cache_flag" "$act" "$exp" "cache should be off" \
            || return $FAIL

        # Then check domain
        ckres2 "get_nfsmapid_domain" "$domain" "$txt_rr" "domains differ" \
	    || return $FAIL
}

# Run assertions
#

save_state STATE_NFSMAPID03

echo "\nNFSMAPID03 Starting Assertions\n"

for i in $ASSERTIONS
do
	eval as_${i} || print_state
	restore_state STATE_NFSMAPID03
done

clear_state STATE_NFSMAPID03

echo "\nNFSMAPID03 assertions finished!\n"

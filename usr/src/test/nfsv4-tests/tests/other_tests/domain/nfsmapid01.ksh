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
# nfsmapid01.sh - nfsmapid tests for the following configuration:
#
#       NFSMAPID_DOMAIN   DNS TXT RR      DNS domain  NIS domain
#       ===============   ==============  ==========  ==========
#       Yes               Yes             Yes         Yes
#

[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

# set up script execution environment
. ./dom_env

# should run as root
is_root "$NAME{setup}:" "All tests for domain affected"

# get timeout value nfsmapid uses for domain checking
nfsdomain_tmout=$(get_nfsmapid_domain_tout_wrapper)

# assertion list
ASSERTIONS=${ASSERTIONS:-"a b c d"}

# generate assertion descriptions
gen_assert_desc $NAME "as_"

#
# Assertion definition
#

# as_a: TXT RR present, get domain from /etc/default/nfs
function as_a {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=$nfsfile_domain
	assertion a "$(get_assert_desc a)" $exp

	# Get mapid domain
	mapid_service refresh $TIMEOUT "failed to refresh mapid service" \
	    "UNRESOLVED" || return $UNRESOLVED
	act=$(get_nfsmapid_domain)

	# check assertion
	ckres2 "get_nfsmapid_domain" "$act" "$exp" "domains differ" \
	    || return $FAIL
}

# as_b: No TXT record, get domain from /etc/default/nfs
function as_b {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=$nfsfile_domain
	assertion b "$(get_assert_desc b)" $exp

        # Setup: 
	#    - remove TXT RR in dns.nfs.test.mater file and restart dns server 
	chg_txt_field_dns /var/named/${dns_domain}.master dummy=none
	dns_service restart $TIMEOUT "failed to restart dns service"\
	    "UNRESOLVED" || return $UNRESOLVED

	# Get mapid domain
	mapid_service refresh $TIMEOUT "failed to refresh mapid service" \
	    "UNRESOLVED" || return $UNRESOLVED
	act=$(get_nfsmapid_domain)

	# Check assertion
	ckres2 "get_nfsmapid_domain" "$act" "$exp" "domains differ" \
	    || return $FAIL
}


# as_c: DNS down, get domain from /etc/default/nfs
function as_c {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=$(get_domain_default_nfs)
	assertion c "$(get_assert_desc c)" $exp

	# Setup:
	#    - shut down dns server(no access to txt record)
	dns_service disable $TIMEOUT "failed to disable dns service" \
	    "UNRESOLVED" || return $UNRESOLVED

	# Get mapid domain
	mapid_service refresh $TIMEOUT "failed to refresh mapid service" \
	    "UNRESOLVED" || return $UNRESOLVED
	act=$(get_nfsmapid_domain)

	# Check assertion
	ckres2 "get_nfsmapid_domain" "$act" "$exp" "domains differ" \
	    || return $FAIL
}

# as_d1: Remove domain from /etc/default/nfs, get domain from TXT RR after
#	nfscfg_domain_tmout timer expires
# as_d2: Add domain in /etc/default/nfs, get domain from that file again
#	after nfscfg_domain_tmout timer expires
# 
# nfsmapid has a daemon thread to handle SIGHUP and SIGTERM. This thread also
# has a timer for checking system configuration changes. If no signals arrives 
# when the timer expires, nfsmapid will call check_domain() to re-calculate
# nfs domain.
#
# Testcase {d1} and {d2} test the above the above timeout behavior.
function as_d {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	#
	# Assertion {d1}
	#
	exp=$txt_rr
	assertion d1 "$(get_assert_desc d1)" $exp

	# Setup:
	#    - comment out MAPID_DOMAIN entry in /etc/default/nfs
	comm_domain_default_nfs

	# Wait for timeout and then get mapid domain
	sleep $nfsdomain_tmout
	act=$(get_nfsmapid_domain)

	# Check assertion
	ckres2 "get_nfsmapid_domain" "$act" "$exp" \
	   "domains differ, $NAME{d2} skiped" /dev/null || return $FAIL

	#
	# Assertion {d2}
	#

	# restore /etc/default/nfs file
	uncomm_domain_default_nfs 

	exp=$nfsfile_domain
	assertion d2 "$(get_assert_desc d2)" $exp

	# Wait for timeout and then get mapid domain
	sleep $nfsdomain_tmout
	act=$(get_nfsmapid_domain)

	# Check assertion
	ckres2 "get_nfsmapid_domain" "$act" "$exp" "domains differ" \
	    || return $FAIL
}

#
# Run assertions
#

save_state STATE_NFSMAPID01

echo "\nNFSMAPID01 Starting Assertions\n"

for i in $ASSERTIONS
do
	eval as_${i} || print_state
        restore_state STATE_NFSMAPID01
done

clear_state STATE_NFSMAPID01

echo "\nNFSMAPID01 assertions finished!\n"

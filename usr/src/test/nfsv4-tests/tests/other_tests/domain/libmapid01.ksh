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
# libmapid01.sh - libmapid tests for the following configuration:
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

# assertion list
ASSERTIONS=${ASSERTIONS:-"a b c d e"}

# generate assertion descriptions
gen_assert_desc $NAME "as_"

#
# Assertion definition
#

# as_a: Has domain in /etc/default/nfs, call mapid_get_domain(), get domain
#	from the file 
function as_a {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=$nfsfile_domain
	assertion a "$(get_assert_desc a)" $exp

	# Get mapid domain
	act=$(./get_domain)
	ckreturn $? "get_domain utility failed" /dev/null "UNRESOLVED" \
	   || return $UNRESOLVED

	# check assertion
	ckres2 "get_domain" "$act" "$exp" "domains differ" || return $FAIL
}

# as_b: Has domain in /etc/default/nfs, call mapid_derive_domain(), get domain
#	from the file
function as_b {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=$nfsfile_domain
	assertion b "$(get_assert_desc b)" $exp

	# Get mapid domain
	act=$(./derive_domain_dl)
	ckreturn $? "derive_domain_dl utility failed" /dev/null "UNRESOLVED" \
	   || return $UNRESOLVED

	# check assertion
	ckres2 "derive_domain_dl" "$act" "$exp" "domains differ" || return $FAIL
}

# as_c1: Domain string is helloword, call mapid_stdchk_domain() to check it
# as_c2: Domain string is hello.world, call mapid_stdchk_domain() to check it
# as_c3: Domain string has uppercase character, call mapid_stdchk_domain()
#	to check it
# as_c4: Domain string has dash character, and the last character is a number,
#	call mapid_stdchk_domain() to check it
# as_c5: Domain string has 255 characters(max length), call 
#	mapid_stdchk_domain() to check it
# as_c6: Domain string has invalid character(space), call 
#	mapid_stdchk_domain() to check it
# as_c7: Domain string has invalid character(@), call mapid_stdchk_domain()
#	to check it
# as_c8: The first character of domain string is not alphabetic character, call
#	mapid_stdchk_domain() to check it
# as_c9: Domain string has trailing space, call mapid_stdchk_domain() to check
#	it
# as_c10: Domain string has invalid length(256 characters), call 
#	mapid_stdchk_domain() to check it
# as_c11: Domain string has invalid length(null string), call
#	mapid_stdchk_domain() to check it
# as_c12: Domain string is helloword, call mapid_stdchk_domain() to check it
function as_c {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	set -A assertions c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11 c12
	
	FIFTY_CHARS="x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x."
	TWOHUNDRED_CHARS=$FIFTY_CHARS$FIFTY_CHARS$FIFTY_CHARS$FIFTY_CHARS

	set -A dom_strings \
		"helloworld" \
		"hello.world" \
	        "HELLO.WORLD" \
	    	"hello-world.1234" \
		$TWOHUNDRED_CHARS$FIFTY_CHARS"12345" \
		"hello world" \
		"hello@world" \
		"1234.world" \
		"hello.worl-" \
		"hello.world " \
		$TWOHUNDRED_CHARS$FIFTY_CHARS"123456" \
		""

	set -A exp_results 1 1 1 1 1 0 0 1 0 0 -1 0

	x=0
	while (( $x < 12 )); do
		assertion "${assertions[$x]}a" \
		    "$(get_assert_desc ${assertions[$x]})" \
		    ${exp_results[$x]}
		res=$(./check_domain "${dom_strings[$x]}" ${exp_results[$x]})
		ckres2 "check_domain" $res ${exp_results[$x]} \
                   "mapid_stdchk_domain() failed on ${dom_strings[$x]}"

		assertion "${assertions[$x]}b" \
		    "$(get_assert_desc ${assertions[$x]}), using dl_open()" \
		    ${exp_results[$x]}
		res=$(./check_domain_dl "${dom_strings[$x]}" ${exp_results[$x]})
		ckres2 "check_domain_dl" $res ${exp_results[$x]} \
                   "mapid_stdchk_domain() failed on ${dom_strings[$x]}"

		x=$((x + 1))
	done
}

# as_d: Has domain in /etc/default/nfs, call mapid_derive_domain() 
#	simultaneously in different threads
function as_d {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=0
	assertion d "$(get_assert_desc d)" $exp

	# call mapid_get_domain() simultaneously and check the results
        ./get_domain_mt >$LOGFILE 2>&1

        # Check Assertion
        ckres2 "get_domain_mt" $? $exp "mapid_get_domain() failed" $LOGFILE \
	    || return $FAIL
}

# as_e: Call mapid_stdchk_domain() simultaneously in different threads
function as_e {
	[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

	exp=0
	assertion e "$(get_assert_desc e)" $exp

	# call mapid_stdchk_domain() simultaneously and check the results
        ./check_domain_mt >$LOGFILE 2>&1

        # Check Assertion
        ckres2 "reeval_callback" $? $exp "mapid_stdchk_domain() failed" \
	    $LOGFILE || return $FAIL
}

#
# Run assertions
#

echo "\nLIBMAPID01 Starting Assertions\n"

for i in $ASSERTIONS
do
	eval as_${i} || print_state
done

echo "\nLIBMAPID01 assertions finished!\n"

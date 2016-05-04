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
# runtests.ksh - control program for domain tests. This script sets up a 
#	basic environment where the other test scripts run. Below is the 
#	configuration of the environment("Yes" means it is set; otherwise
#	"No"):
#
#	NFSMAPID_DOMAIN   DNS TXT RR      DNS domain  NIS domain
#	===============   ==============  ==========  ==========
#	Yes		  Yes		  Yes	      Yes
#	

[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

# set up script execution environment
. ./dom_env

function cleanup
{
        # restore nfscfg_domain_tmout in /usr/lib/nfs/nfsmapid
	[[ $is_tmout_changed == 1 ]] && echo "nfscfg_domain_tmout?W 0t300" \
		| mdb -w /usr/lib/nfs/nfsmapid  > /dev/null

        # restore system files and services
        restore_state -c STATE_INITIAL
}

trap "cleanup" EXIT
trap "exit 1" HUP INT QUIT PIPE TERM

# should run as root
EXEC=""
id | grep "0(root)" > /dev/null 2>&1
if [[ $? != 0 ]]; then
        EXEC="/suexec"
fi

# save current system state
save_state STATE_INITIAL >$LOGFILE 2>&1
ckreturn $? "$NAME{setup}: failed to save system state" $LOGFILE "UNINITIATED" \
    || exit $UNINITIATED

# get a list of kornshell scripts
TESTLIST=${TESTLIST:-$(egrep -v "^#|^ *$" domain.flist)}

# check for cipso support
HOST=$(uname -n | cut -d. -f1)
is_cipso "vers=4" $HOST
if [[ $? == $CIPSO_NFSV4 ]]; then
        for t in $TESTLIST
        do
                echo "$t{all_tests}: DNS UNSUPPORTED under CIPSO Trusted Extensions"
                echo "\tTest UNSUPPORTED"
        done
	exit 0
fi

# setup DNS server on client
./dnscfg >$LOGFILE 2>&1
ckreturn $? "$NAME{setup}: failed to set up dns server" $LOGFILE "UNINITIATED" \
    || exit $UNINITIATED

dns_domain=$(get_domain_resolv 2>$LOGFILE)
ckreturn $? "NAME{setup}: failed to get DNS domain" $LOGFILE "UNINITIATED" \
    || exit $UNINITIATED

txt_rr=$(get_domain_txt_record $dns_domain 2>$LOGFILE)
ckreturn $? "NAME{setup}: failed to get text RR from local DNS server" $LOGFILE\
    "UNINITIATED" || exit $UNINITIATED

dns_server=$(uname -n | cut -d. -f1)

# If IPv6 is being used, force the server name name to be its IPv4 address.
# As DNS accesses used here are not going OTW, so there is no loss of coverage.
# See 5044318 and 5050132
getent ipnodes $dns_server 2>/dev/null | grep $dns_server \
    | grep ':' >/dev/null 2>&1
[[ $? == 0 ]] && dns_server=$(getent hosts $dns_server | awk '{print $1}')

echo "\nSet up DNS server on $dns_server for domain $dns_domain," \
    "the value for _nfsv4idmapdomain is $txt_rr."

# second DNS server
second_dns_server_info=$(get_second_dns_server)
[[ $? == 0 ]] && second_dns_server_available=1
if [[ $second_dns_server_available == 1 ]]; then
        second_dns_server=$(echo $second_dns_server_info | cut -d' ' -f1)
        second_dns_domain=$(echo $second_dns_server_info | cut -d' ' -f2)
        second_txt_rr=$(echo $second_dns_server_info | cut -d' ' -f3)

	echo "\nUse the second DNS server on $second_dns_server," \
	    "its domain is $second_dns_domain," \
	    "the value for _nfsv4idmapdomain is $second_txt_rr."
fi

# modify /etc/default/nfs to set NFSMAPID_DOMAIN
nfsfile_domain=domain.from.nfsfile
chg_domain_default_nfs $nfsfile_domain
mapid_service restart $TIMEOUT "failed to restart mapid service" \
    "UNINITIATED" || exit $UNINITIATED

# get NIS domain
nis_domain=$(get_domain_domainname)

# change nfscfg_domain_tmout value to reduce assertion execution time
DOMAIN_TMOUT=${DOMAIN_TMOUT:-10}
echo "nfscfg_domain_tmout?W 0t$DOMAIN_TMOUT" | mdb -w /usr/lib/nfs/nfsmapid \
    > $LOGFILE 2>&1
mapid_service restart $TIMEOUT "failed to restart mapid service" \
    "WARNING"
curval=$(echo "nfscfg_domain_tmout/D" | \
    mdb -p $(pgrep -z `zonename` -x nfsmapid) | \
    tail -1 | nawk '{print $2}')
if [[ $curval == $DOMAIN_TMOUT ]]; then
	is_tmout_changed=1
	echo "\nnfscfg_domain_tmout is $DOMAIN_TMOUT seconds."
else
	is_tmout_changed=0
	echo "\nWARNING: failed to change nfscfg_domain_tmout," \
	     "you are probably in sparse root zone."
	[[ "$DEUBG" == 1 ]] && cat $LOGFILE
	echo "\nCurrent zone: $(zonename), nfscfg_domain_tmout: $curval seconds"
fi
rm $LOGFILE

# export variables to test cases
export dns_server dns_domain txt_rr second_dns_server second_dns_domain \
    second_txt_rr nfsfile_domain nis_domain

export LD_LIBRARY_PATH=/usr/lib/nfs

# Start the tests with some information
echo " "
echo "Testing at CLIENT=[$CLIENT] with dns server setup at [$dns_server]"
echo "Started DOMAIN tests at [`date`] ..."
echo " "

save_state STATE_DOMAIN_TEST

for t in $TESTLIST
do
	${EXEC} ./$t
	st=$?
	if [[ $st != $PASS ]] && [[ $st != $FAIL ]]; then
		echo "\n$t{remaining_tests}: unexpected tests termination"
		echo "\tTest $(rc2str $st): $t terminated with status $st\n"
	fi
	restore_state STATE_DOMAIN_TEST
done

clear_state STATE_DOMAIN_TEST

echo " "
echo "Testing ends at [`date`]."
echo " "

exit 0

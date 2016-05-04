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
# dngcfg.ksh - sets up DNS server on the local host, and modifies 
#	/etc/resolv.conf to make the host use the local DNS server to 
#	resolve domain name.
#
#	The server's domain is "dns.test.nfs". The server has _nfsv4idmapdomain
#	defined, its initial value is "dns.test.nfs".
#
# Notes:
#    	The script modifies some files on the system and it doesn't back up
#    	them. The caller is responsible to do that and restore these files
#    	when necessary.

[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

# set up script execution environment
. ./dom_env

trap "rm -f $LOGFILE" EXIT

is_root "$NAME:" "All tests for domain affected"

# get IPv4 address of first network interface
ip_addr=$(ifconfig -a4 | egrep inet | egrep -v '127.0.0.1' | \
	  egrep -v '0.0.0.0' | awk '{print $2}' | head -1 \
	  2> $LOGFILE)
ckreturn $? "failed to get the host IP address" $LOGFILE "ERROR" \
    || return $FAIL

set -A ip_levels $(echo $ip_addr | sed -e "s/\./ /g")

# generate the string for reverse zone name
revzone="in-addr.arpa"
for i in 0 1 2; do
	revzone=${ip_levels[$i]}.$revzone
done

# populate named.conf file
sed -e "s/REVZONE/$revzone/g" ./named.conf.tmpl >/etc/named.conf 2> $LOGFILE
ckreturn $? "failed to create /etc/named.conf" $LOGFILE "ERROR" \
    || return $FAIL

# clean up /var/named directory
rm -rf /var/named 2>/dev/null
mkdir -m 0755 /var/named

node_revip=${ip_levels[3]}
node_name=$(uname -n | cut -d. -f1)
node_ipaddr=$ip_addr

# cycle through all zone template files to generate zone files, and 
# copy them under /var/named 
for tmpl in $(ls ./*.master.tmpl); do
	dest=$(echo $tmpl | sed 's/\.tmpl//')
	sed -e "s/NODE_REVIP/$node_revip/g" \
	    -e "s/NODE_NAME/$node_name/g" \
	    -e "s/NODE_IPADDR/$node_ipaddr/g" \
	    ./$tmpl >/var/named/$dest 2>$LOGFILE
	ckreturn $? "failed to create /var/named/$dest" $LOGFILE "ERROR" \
    	    || return $FAIL
done

# finally, populate /etc/resolv.conf accordingly
cat > /etc/resolv.conf << EOF
domain dns.test.nfs
nameserver $node_ipaddr
EOF
ckreturn $? "failed to create /etc/resolv.conf" $LOGFILE "ERROR" \
    || return $FAIL

# (re)start named server
dns_service restart 6 "failed to restart dns service" "ERROR" || return $FAIL

# check if the DNS server works properly. To do that, we call 
# get_domain_txt_record() to get the value of _nfsv4idmapdomain on local 
# DNS server.
i=0
while true; do
	sleep 1
	txt_rr=$(get_domain_txt_record "dns.test.nfs" 2>$LOGFILE)
	ckreturn $? "failed to get TXT RR from local DNS server" $LOGFILE \
	    "ERROR" || return $FAIL
	[[ "$txt_rr" == "domain.from.txt" ]] && exit
	(($i < 12)) || exit 1
	i=$((i + 1))
done

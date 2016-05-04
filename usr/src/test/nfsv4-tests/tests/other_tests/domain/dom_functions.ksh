#!/usr/bin/ksh
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
# dom_functions.sh - functions used to test the domain rules for nfsmapid
#
# Note: Some functions in this file uses ckreturn(), a function defined in 
# 	testsh.ksh. Please make sure you have already source'd that file 
#	before you source this file.

# print_state - dumps all information possibly used by nfsmapid to obtain a
#	domain value from different sources.
# all information is sent to stderr, return value is always 0
#

function print_state {
	echo "\n>>>>>>>>>>>>>>>>>>>>>> DEBUG INFORMATION <<<<<<<<<<<<<<<<<<<<<"
	echo "============== NFSMAPID_DOMAIN in /etc/default/nfs ============="
	grep NFSMAPID_DOMAIN /etc/default/nfs
	echo "======================= /etc/resolv.conf ======================="
	cat /etc/resolv.conf
	echo "=========== TXT RR in /var/named/dns.test.nfs.master ==========="
	grep TXT /var/named/${dns_domain}.master
	echo "======================= dns server state ======================="
	svcs -xv svc:/network/dns/server:default
	echo "========================== dig output =========================="
	get_domain_txt_record $dns_domain
	echo "========================== nis domain =========================="
	domainname
	echo "======================= nfs mapid domain ======================="
	cat /var/run/nfs4_domain
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> END <<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n" 
}


#
# get_domain_txt_record - gets a nfsmapid text record from a (local) DNS server
# Usage	get_domain_txt_record dns_domain
#	dns_domain	name of the dns_domain as specified in DNS files.
# function returns 0 on success or 1 on error, stdout has the value of the
#	text record on success, else stderr has a diagnostic message.

function get_domain_txt_record {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x
	n=get_domain_txt_record
	if [ $# -ne 1 ]; then
		echo "USAGE: $n dns_domain" >&2
		exit 1
	fi
	typeset dns_domain=$1
	if [ -z "$dns_domain" ]; then
		echo "\t$n ERROR: DNS domain parameter is \"$dns_domain\"" >&2
		return 1
	fi
	typeset serverName=`uname -n | cut -d. -f1`
        typeset server=`getent hosts $serverName | cut -f1`
        
	typeset type=TXT
	typeset keyword="_nfsv4idmapdomain"
        typeset ns=dig
     
       
        pgrep -z `zonename` named 2> /dev/null > /dev/null
        if [ $? -ne 0 ]; then
                sleep 3
                pgrep -z `zonename` named 2> /dev/null > /dev/null
                if [ $? -ne 0 ]; then
                        echo "\t$n ERROR: DNS server not running" >&2
                        return 1
                fi
        fi
      
        
	typeset res
	res=$($ns @$server 2>&1)
	if [ $? -ne 0 ]; then
		echo "$n ERROR cannot access DNS server \"$server\"" >&2
		printf "\tdig $server $server returned:\n%s\n" "$res" >&2 
		return 1
	fi
	typeset out=$($ns @$server $keyword.$dns_domain $type +domain=$dns_domain 2>&1)
        typeset keys
	keys=$(printf "%s\n" "$out" | grep $type | grep $keyword | grep -v ';')
	if [ $? -ne 0 ]; then
		echo "\t$n ERROR: DNS server \"$server\" did not have $type "\
			"records for \"$keyword\"" >&2
		printf "\t\tTXT records query results:\n%s\n" "$out" >&2 
                echo "===============================\n" >&2 
		return 1
	fi
	# if multiple records, use the last one 
	typeset key=$(printf "%s\n" "$keys" | tail -1) 
	typeset domain=$(echo $key | awk '{print $NF}' | awk -F= '{print $NF}' \
		| sed 's/"//g')
	if [ -z "$domain" ]; then
		echo "\t$n ERROR: $type \"$keyword\"record was empty" >&2
		printf "\t\trecords found were:\n%s\t<===\n" "$keys" >&2 
		echo "===============================\n" >&2 
		return 1
	fi
	typeset -l domain=$domain
	echo $domain
	return 0
}


#
# get_nfsmapid_domain - get nfsmapid domain from /var/run/nfs4_domain file
# Usage	get_nfsmapid_domain
# function returns 0 on success or 1 on error, stdout has the value of the
#	nfsmapid domain on success, else stderr has a diagnostic message.

function get_nfsmapid_domain {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=get_nfsmapid_domain
	if [ $# -ne 0 ]; then
		echo "USAGE: $n" >&2
		exit 1
	fi

        if [ ! -f /var/run/nfs4_domain ]; then
		echo "/var/run/nfs4_domain file doens't exist" >&2
		return 1
	fi

        cat /var/run/nfs4_domain
        return 0
}


#
# get_nfsmapid_domain_tout - uses mdb to get nfsmapid's global 
#				nfscfg_domain_tmout
# Usage	get_nfsmapid_domain_tout
# function returns 0 on success or 1 on error, stdout has the value of the
#	global nfscfg_domain_tmout on success, else stderr has a diagnostic
#	message.

function get_nfsmapid_domain_tout {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=get_nfsmapid_domain_tout
	if [ $# -ne 0 ]; then
		echo "USAGE: $n" >&2
		exit 1
	fi

	typeset dae=nfsmapid
	typeset var=nfscfg_domain_tmout
	typeset Pid=$(pgrep -z `zonename` -x $dae 2> /dev/null)
	if [ -z "$Pid" ] && [ $D -ne 0 ]; then
		echo "$n: $dae is not running" >&2
		return 1
	fi
        typeset line=$(echo "$var/D" | mdb -p $Pid 2> $TMPDIR/domain2.$$ | tail -1) 
        [ -n "$DEBUG" ] && [ $DEBUG != 0 ] && cat $TMPDIR/domain2.$$ 
        rm -f $TMPDIR/domain2.$$ >/dev/null 2>&1 
	# make sure we are getting valid results
	typeset st=$(echo $line | grep $dae | grep "$var:" | wc -w 2>/dev/null)
	if [ $st -ne 2 ]; then
		echo "$n: Cannot get symbol $var from $dae" >&2
		return 1
	fi
	typeset tout=$(echo $line | awk '{print $NF}')
	echo $tout
	return 0 
}


#
# get_domain_default_nfs - gets nfsmapid's domain from /etc/default/nfs 
# Usage	get_domain_default_nfs
# function returns 0 on success or 1 on error, stdout has the value of the
#	nfsmapid's domain on success, else stderr has a diagnostic message.

function get_domain_default_nfs {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=get_domain_default_nfs
	if [ $# -ne 0 ]; then
		echo "USAGE: $n" >&2
		exit 1
	fi

	file=/etc/default/nfs
	str=NFSMAPID_DOMAIN
	if [ ! -r $file ]; then
		[ $D -ne 0 ] && echo "$n: Cannot read \"$file\"" >&2
		return 1
	fi
	line=$(grep "^${str}=" $file)
	st=$?
	# domain not present
	if [ $st -ne 0 ]; then
		echo ""
		return 0
	fi
	# domain present
	domain=$(echo $line | awk -F= '{print $NF}')
	typeset -l domain=$domain
	echo $domain
	return 0
}


#
# get_domain_resolv - gets first item on search field, or domain value if
#	search field is not present, from file /etc/resolv.conf
# Usage	get_domain_resolv
# function returns 0 on success or 1 on error, stdout has the value of the
#	domain on success, else stderr has a diagnostic message.

function get_domain_resolv {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=get_domain_resolv
	if [ $# -ne 0 ]; then
		echo "USAGE: $n" >&2
		exit 1
	fi

	typeset file=/etc/resolv.conf
	if [ ! -r $file ] && [ $D -ne 0 ]; then
		echo "$n: Cannot read \"$file\"" >&2
		return 1
	fi
	#resp;ver gives preference to search over domain
	typeset str=search
	typeset line
	line=$(grep -i "^$str" $file)
	typeset st=$?
	typeset domain
	# search present
	if [ $st -eq 0 ]; then
		domain=$(echo $line | awk '{print $2}')
		typeset -l domain=$domain
		echo $domain
		return 0
	fi
	str=domain
	line=$(grep -i "^$str" $file)
	st=$?
	# domain present
	if [ $st -ne 0 ]; then
		echo ""
		return 0
	fi
	# domain present
	domain=$(echo $line | awk '{print $2}')
	typeset -l domain=$domain
	echo $domain
	return 0
}


#
# get_domain_domainname - gets domain value from command domainname
# Usage	get_domain_domainname
# function returns 0 on success or 1 on error, stdout has the value of the
#	domain on success, else stderr has a diagnostic message.

function get_domain_domainname {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x
	n=get_domain_domainname
	if [ $# -ne 0 ]; then
		echo "USAGE: $n" >&2
		exit 1
	fi

	typeset prog=domainname
	typeset str=domain

	typeset line=$(domainname)
	typeset st=$?
	# domain not set
	if [ $st -ne 0 ] || [ -z "$line" ]; then
		echo ""
		return 0
	fi
	# domain present
	typeset sdomain=$(echo $line | awk -F. '{for (i=2 ; i <= NF; i++) print $i}')
	typeset domain=$(echo $sdomain | sed 's/ /./g')
	echo $domain
	return 0
}


#
# remove_search_from_dns - removes the search field from the file
#	/etc/resolv.conf
# Usage	remove_search_from_dns
# function returns 0 on success or 1 on error and stderr has a diagnostic
#	message.

function remove_search_from_dns {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=chg_txt_field_dns
	if [ $# -ne 0 ]; then
		echo "USAGE: $n" >&2
		exit 1
	fi

	typeset file=/etc/resolv.conf
	typeset key=search
	sed "s/^${key}.*$//" $file > /tmp/resolv-new
	if [ $? -ne 0 ]; then
		echo "Could not remove $key entries in $file" >&2
		rm -f /tmp/resolv-new > /dev/null 2>&1
		return 1
	fi
	mv /tmp/resolv-new $file
	if [ $? -ne 0 ]; then
		echo "Could not remove $key entries in $file" >&2
		return 1
	fi
	return 0
}


#
# chg_txt_field_dns - change the value of a nfsmapid text record, or the name
#	and value of such text record for the specified master file.
# Usage	chg_txt_field_dns master_file {domain | field_name=value}
#	master_file	DNS named config master file to modify
#	domain		domain value for the nfsmapid text field
#	field_name=value new tag and value to replace the nfsmapid field
# function returns 0 on success or 1 on error and stderr has a diagnostic
#	message.

function chg_txt_field_dns {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=chg_txt_field_dns
	if [ $# -ne 2 ]; then
		echo "USAGE: $n master_file {domain | field_name=value}" >&2
		exit 1
	fi
	typeset file=$1
	if [ ! -r $file ]; then
		echo " Can not read master_file $file" >&2
		return 1
	fi

	typeset keyword
	typeset field
	typeset dns_txt=$2
	typeset res
	res=$(echo $dns_txt | egrep "[a-zA-Z0-9_-]+=.*" 2>&1)
	if [ $? -ne 0 ]; then
		keyword="_nfsv4idmapdomain"
		field="$dns_txt"
	else
		keyword="$(echo $dns_txt | awk -F= '{print $1}')"
		field="$(echo $dns_txt | awk -F= '{print $NF}')"
	fi
	
	nawk -v keyword="$keyword" -v field="$field" \
	     '( $2 == "IN" && $3 == "TXT" ) {        \
		  printf("%s", keyword);             \
		  for (i=2; i < NF; i++)             \
		      printf("\t%s", $i);            \
		  printf("\t%s\n", field); }         \
	      !( $2 == "IN" && $3 == "TXT" ) {       \
		  print $0; }' $file > /tmp/master-new
	if [ $? -ne 0 ]; then
		echo "Could not change ${str}... in $file" >&2
		return 1
	fi
	cp -p $file $file.old
	mv /tmp/master-new $file
	if [ $? -ne 0 ]; then
		echo "Could not change ${str}... in $file" >&2
		return 1
	fi
	return 0
}


#
# chg_domain_dns - change the value of the domain field for /etc/resolv.conf
# Usage	chg_domain_dns new_dns_domain
#	new_dns_domain	domain to replace current value
# function returns 0 on success or 1 on error and stderr has a diagnostic
#	message.

function chg_domain_dns {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=chg_domain_dns
	if [ $# -ne 1 ]; then
		echo "USAGE: $n dns_domain" >&2
		exit 1
	fi
	typeset dns_domain=$1
	typeset str=domain
	
	sed "s/^$str .*\$/$str $dns_domain/" \
        	/etc/resolv.conf > /tmp/resolv-new
	if [ $? -ne 0 ]; then
		echo "Could not change $str in /etc/resolv.conf" >&2
		return 1
	fi
	cp -p /etc/resolv.conf /etc/resolv.old
	mv /tmp/resolv-new /etc/resolv.conf
	if [ $? -ne 0 ]; then
		echo "Could not change $str in /etc/resolv.conf" >&2
		return 1
	fi
	return 0
}


#
# chg_server_dns - change the value of the nameserver field for /etc/resolv.conf
# Usage	chg_server_dns new_dns_server
#	new_dns_server	nameserver value to replace current value
# function returns 0 on success or 1 on error and stderr has a diagnostic
#	message.

function chg_server_dns {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=chg_server_dns
	if [ $# -ne 1 ]; then
		echo "USAGE: $n dns_server" >&2
		exit 1
	fi
	typeset server=$1
	typeset str=nameserver
	sed "s/^$str .*\$/$str $server/" \
        	/etc/resolv.conf > /tmp/resolv-new
	if [ $? -ne 0 ]; then
		echo "Could not change $str in /etc/resolv.conf" >&2
		return 1
	fi
	cp -p /etc/resolv.conf /etc/resolv.old
	mv /tmp/resolv-new /etc/resolv.conf
	if [ $? -ne 0 ]; then
		echo "Could not change $str in /etc/resolv.conf" >&2
		return 1
	fi
	return 0
}


#
# chg_domain_default_nfs - change the value of the variable NFSMAPID_DOMAIN for
#	/etc/default/nfs
# Usage	chg_domain_default_nfs domain
#	domain	new value for the nfsmapid domain
# function returns 0 on success or 1 on error and stderr has a diagnostic
#	message.

function chg_domain_default_nfs {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=chg_domain_default_nfs
	if [ $# -ne 1 ]; then
		echo "USAGE: $n domain" >&2
		exit 1
	fi
	typeset domain=$1
	typeset str=NFSMAPID_DOMAIN
	sed "/$str=.*/d" /etc/default/nfs > /tmp/nfs-new
	if [ $? -ne 0 ]; then
		echo "Could not generate tmp file for /etc/default/nfs" >&2
		return 1
	fi
	echo "$str=$domain" >> /tmp/nfs-new
	cp -p /etc/default/nfs /etc/default/nfs.old
	mv /tmp/nfs-new /etc/default/nfs
	if [ $? -ne 0 ]; then
		echo "Could not change $str in /etc/default/nfs" >&2
		return 1
	fi
	return 0
}


#
# comm_domain_default_nfs - comment the entry for the variable NFSMAPID_DOMAIN
#	in /etc/default/nfs
# Usage	comm_domain_default_nfs
# function returns 0 on success or 1 on error and stderr has a diagnostic
#	message.

function comm_domain_default_nfs {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=comm_domain_default_nfs

	sed 's/^NFSMAPID_DOMAIN=/\# NFSMAPID_DOMAIN=/' /etc/default/nfs \
        	> /tmp/nfs-new
	cp -p /etc/default/nfs /etc/default/nfs.old
	mv /tmp/nfs-new /etc/default/nfs
}


#
# uncomm_domain_default_nfs - uncomment the entry for the variable
#	NFSMAPID_DOMAIN in /etc/default/nfs
# Usage	uncomm_domain_default_nfs
# function returns 0 on success or 1 on error and stderr has a diagnostic
#	message.

function uncomm_domain_default_nfs {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=uncomm_domain_default_nfs

	sed 's/^\#[ \t]*NFSMAPID_DOMAIN=/NFSMAPID_DOMAIN=/' /etc/default/nfs \
		> /tmp/nfs-new
	cp -p /etc/default/nfs /etc/default/nfs.old
	mv /tmp/nfs-new /etc/default/nfs
}


#
# save_file - stores the source file to a temporal file, can only be used
#	for one file, and does not "overwrites" the temporal file, so multiple
#	consecutive calls have the same effect as the first call only. Must be
#	"reset" by a call to restore_file.
# Usage	save_file filename
#	filename	source file to be backup in the temporal file
# function returns 0 on success or 1 on error and stderr has a diagnostic
#	message.

function save_file {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=save_file
	if [ $# -ne 1 ]; then
		echo "USAGE: $n filename" >&2
		exit 1
	fi

	typeset TMPNAM="${TMPDIR}/temp_file.$(basename $1).NMAPID.$$"
	typeset file1=$1
	[ -e "$TMPNAM" ] && echo "$n: A file was already saved" && return 1
	[ ! -f "$file1" ] && echo "$n: $file1 not a regular file" && return 1
	res=$(cp -p $file1 $TMPNAM 2>&1)
	[ $? -ne 0 ] && echo "$n: $file1 could not be saved" && return 1
	return 0
}

#
# is_saved - checks if the specified file has been saved by save_file() or not.
#	When one calls save_file() to back up one file, its contents is 
#	stored in a temporal file under $TMPDIR, whose name follows an
#	implementation specific naming convention. What this function does is 
#	to check the existence of the temporal file. If it exists, the target
#	file is supposed to be saved.
# Usage	is_saved filename
#	filename 	The target file whose temporal file is checked
# function returns 0 if the specified file is saved or 1 if not.
function is_saved {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=is_saved
	if [ $# -ne 1 ]; then
                echo "USAGE: $n filename" >&2
                exit 1
        fi

	typeset TMPNAM="${TMPDIR}/temp_file.$(basename $1).NMAPID.$$"
	[ -e "$TMPNAM" ] && return 0
	return 1
}

#
# restore_file - restores the specified file from a temporal file, can only be
#	used to restore one file, and does not "destroys" the target file,
#	so  after the first call, multiple consecutive calls will fail.
#	Must be "set" by a call to save_file.
# Usage	restore_file filename
#	filename	Target file to be replaced by the temporal file
# function returns 0 on success or 1 on error and stderr has a diagnostic
#	message.

function restore_file {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
	n=restore_file
	if [ $# -ne 1 ]; then
		echo "USAGE: $n filename" >&2
		exit 1
	fi

	typeset TMPNAM="${TMPDIR}/temp_file.$(basename $1).NMAPID.$$"
	typeset file1=$1
	[ ! -e "$TMPNAM" ] && echo "$n: No file has been saved yet" && return 1
	res=$(/usr/bin/mv -f $TMPNAM $file1 2>&1)
	[ $? -ne 0 ] && echo "$n: $file1 could not be saved" && return 1
	return 0
}

# Function get_nfsmapid_domain_tout_wrapper
#     A simple wrapper around get_nfsmapid_domain_tout() function. This 
#     function calls get_nfsmapid_domain_tout() to get nfscfg_domain_tmout, 
#     increase it a bit, and then output it. If the call of 
#     get_nfsmapid_domain_tout() fails, the function output default value of
#     305 seconds, and if DEBUG is turned on, outputs error message on stderr.
# Usage
#     get_nfsmapid_domain_tout_wrapper 
# Return value
#     On success it output timeout value on stdout; On failure it outputs 
#     default timeout(305 seconds) on stdout, and error message on stderr.

function get_nfsmapid_domain_tout_wrapper {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x
	typeset timeout=$(get_nfsmapid_domain_tout 2>$TMPDIR/tout.err.$$)

	ckreturn $? "failed to get nfsmapid timeout value" \
	    $TMPDIR/tout.err.$$ "WARNING" || timeout=300

	rm -f $TMPDIR/tout.err.$$ >/dev/null 2>&1
	
	timeout=$(($timeout + 5))
	echo $timeout
}

# Function get_second_dns_server
#     This function searchs for another dns server(instead of the one that 
#     we set up locally)which have TXT record. It will first check 
#     if $DNS_SERVER have TXT record. If so, $DNS_SERVER is returned; Otherwise
#     129.149.246.6(sundns1.sfbay.sun.com) is checked. If that doesn't have 
#     TXT record either, the function fails.
# Usage
#     get_second_dns_server
# Return value
#     On success it outputs the second dns server, its domain,  and its txt 
#     record in the form of "server_name domain txt_record" and returns 0.
#     On failure it outputs nothing and returns 1.

function get_second_dns_server {
	[ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x
	n=get_second_dns_server

	#
	# Check if DNS_SERVER have TXT record
	#
	
	typeset dns_server_addr=$(getent hosts $DNS_SERVER | head -1 | cut  -f1)
	typeset txt_record
	typeset dns_domain
	typeset res

	if [[ -n "$dns_server_addr" ]]; then
		dns_domain=$(get_domain $dns_server_addr)
	fi

	if [[ -n "$dns_server_addr" && -n "$dns_domain" ]]; then
		res=$(/usr/sbin/nslookup -domain=$dns_domain \
	    	    -query=txt _nfsv4idmapdomain $DNS_SERVER \
	    	    | grep "_nfsv4idmapdomain.*text.*=" 2>&1)

		if [[ -n "$res" ]]; then 
			# the server has TXT RR for requested domain
			txt_record=$(echo $res | cut -d'"' -f2)
			echo "$dns_server_addr $dns_domain $txt_record"
			return 0
		fi 
	fi 

	# 
	# Then check 129.149.246.6 as last resort
	#

	res=$(/usr/sbin/nslookup -domain=sfbay.sun.com \
	    -query=txt _nfsv4idmapdomain 129.149.246.6 \
	    | grep "_nfsv4idmapdomain.*text.*=")

	if [[ -n "$res" ]]; then 
	        # the server has TXT RR for requested domain
		txt_record=$(echo $res | cut -d'"' -f2)
                echo "129.149.246.6 sfbay.sun.com $txt_record"
                return 0
        fi
	
	return 1
}

# Function mapid_service
#	refreshes, and restarts mapid service. The function is a wrapper
# 	around smf_fmri_transition_state(), which itself is a wrapper around
#	svcadm command. It helps to save some typing, as well as
#	to avoid the timing issue found when using smf_fmri_transition_state()
#	to restart mapid service
# Usage 
#  	mapid_service restart|refresh timeout errmsg result
# Return value
# 	function returns 0 on success 
#                     or 1 on error and stdout has a diagnostic message.

function mapid_service {
        [ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x && D=1
        n=mapid_service
        if (( $# < 3 )); then
                echo "USAGE: $n restart|refresh timeout errmsg result" >&2
                return 1
        fi

        typeset action=$1
        typeset timeout=$2
	typeset errmsg=$3
	(($# > 3 )) && typeset result=$4

	typeset logfile=$TMPDIR/mapid_service.tmp.$$
	typeset ret

        case $action in
            restart )
		smf_fmri_transition_state \
		    do svc:/network/nfs/mapid:default disabled $timeout \
		    >$logfile 2>&1
		ckreturn $? "$errmsg" $logfile $result || return 1

		smf_fmri_transition_state \
		    do svc:/network/nfs/mapid:default online $timeout \
		    >$logfile 2>&1
		ckreturn $? "$errmsg" $logfile $result || return 1
                ;;
	    refresh )
		# s10(up-to-u6) doesn't have "refresh" method for nfsmapid
		typeset os_rel=$(uname -r)
		if echo $os_rel | grep "5.10." >/dev/null 2>&1 || \
		   echo $os_rel | grep "5.11" >/dev/null 2>&1; 
		then
			svcadm refresh mapid >$logfile 2>&1 && sleep 3
			ckreturn $? "$errmsg" $logfile $result || return 1
		else
			# so we use kill, but need to make sure
			# the HUP signal is sent to the right process
			kill -HUP `cat /etc/svc/volatile/nfs-mapid.lock` \
				>$logfile 2>&1 && sleep 3
			ckreturn $? "$errmsg" $logfile $result || return 1
		fi
		;;
            * )
                echo "USAGE: $n restart|refresh timeout errmsg result" >&2
		return 1
                ;;
        esac
        
	rm -f $logfile >/dev/null 2>&1
        return 0
}

# Function dns_service 
#       enables, disables, and restarts dns service. This function is a
#	wrapper around smf_fmri_transition_state(), which itself is a wrapper
#	around svcadm. 
#
#	Notes: while I used "svcadm restart svc:/network/dns/server:default" 
#	to restart dns server set up by dnscfg.ksh, I found the command 
#	didn't always work. Normally it took much time than expected, 
#	sometimes the service was never brought up anymore. For that reason, 
#	I would implement restart action by first disabling and then 
#	enabling it.
# Usage 
#	dns_service enable|disable|restart timeout errmsg resstr
# Return value
#  	returns 0 on success or 1 on error and stdout has a diagnostic
#       message.

function dns_service {
        [ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x && D=1
        n=dns_service

        if (( $# < 3 )); then
            echo "USAGE: $n enable|disable|restart timeout errmsg [resstr]" >&2
            return 1
        fi

        typeset action=$1
        typeset timeout=$2
	typeset errmsg=$3
	(( $# > 3 )) && typeset resstr=$4
	typeset ret
	typeset logfile=$TMPDIR/dns_service.tmp.$$

        case $action in 
            enable )
                smf_fmri_transition_state \
		    do svc:/network/dns/server:default online ${timeout} \
                    >$logfile 2>&1
		ckreturn $? "$errmsg" $logfile $resstr || return 1
                ;;
            disable )
                smf_fmri_transition_state \
		    do svc:/network/dns/server:default disabled ${timeout} \
                    >$logfile 2>&1
		ckreturn $? "$errmsg" $logfile $resstr || return 1
                ;;
            restart )
                smf_fmri_transition_state \
		    do svc:/network/dns/server:default disabled ${timeout} \
                    >$logfile 2>&1
		ckreturn $? "$errmsg" $logfile $resstr || return 1

                smf_fmri_transition_state \
		    do svc:/network/dns/server:default online ${timeout} \
                    >$logfile 2>&1
		ckreturn $? "$errmsg" $logfile $resstr || return 1
                ;;      
            * )
                echo "USAGE: $n enable|disable|restart timeout" >&2
                return 1        
                ;;      
        esac
                        
	rm -f $logfile >/dev/null 2>&1
        return 0
}

#
# Function get_dns_txt_cache_flag
#       the function checks if we have access to dns_txt_cached variable 
#	in nfsmapid proccess via mdb. The varible is a flag in nfsmapid 
#	to indicate if the cached txt rr is valid or not. 
# Usage 
#       get_dns_txt_cache_flag
# Return Value
#       returns 0 on success, and output value of dns_txt_cached on stdout;
#       returns 1 on error, and output error message on stderr.

function get_dns_txt_cache_flag {
        [ -n "$DEBUG" ] && [ $DEBUG != 0 ] && set -x 
        n=get_dns_txt_cache_flag

        typeset logfile=$TMPDIR/txt.tmp.$$

        typeset daemon=nfsmapid
        typeset pid=$(pgrep -z `zonename` -x $daemon 2>/dev/null)
        if [[ -z "$pid" ]]; then 
                # no nfsmapid process found
                echo "$n: $daemon is not running" 1>&2
                return 1
        fi

        typeset var=dns_txt_cached
        typeset result=$(echo "$var/D" | mdb -p $pid 2>$logfile | tail -1)
        typeset found=$(echo $result | grep "$var:" | wc -w 2>/dev/null)
        if [[ $found -ne 2 ]]; then
                cat $logfile && rm -f $logfile
                echo "$n: Cannot get symbol $var from $daemon" >&2
                return 1
        fi 

        echo $result | nawk '{print $NF}'

	rm -f $logfile

        return 0
}

# save_state - saves the system's current state(files, smf services' state,
#	etc.), which can be restored later by calling restore_state(). 
#	The function takes one argument to name the state to be saved. User
#	can call this function consecutively to save system states at 
#	different stages during test script execution.
# Usage: save_state <state_name>
#	state_name - the name for the state
# function returns 0 on success or 1 on error, stderr has a diagnostic message
#	on error.
#

function save_state {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x 
	n=save_state
	logfile=$TMPDIR/save_state.$$

	if [[ $# != 1 ]]; then
		echo "USAGE: $n tag"
		return 1
	fi
	state_name=$1

	# create a temporary directory
	STATE_DIR=$TMPDIR/system_state.$$.$state_name
	rm -rf $STATE_DIR >$logfile 2>&1 \
	    && mkdir $STATE_DIR >$logfile 2>&1
	ckreturn $? "$n: failed to remove/create directory" $logfile "ERROR" \
	    || return 1

	# save /etc/default/nfs
	cp /etc/default/nfs $STATE_DIR/etc.default.nfs >$logfile 2>&1
	ckreturn $? "$n: failed to save /etc/default/nfs" $logfile "ERROR" \
	    || return 1

	# save /etc/resolv.conf if it exists
	if [[ -f /etc/resolv.conf ]]; then
		cp /etc/resolv.conf $STATE_DIR/etc.resolv.conf >$logfile 2>&1
		ckreturn $? "$n: failed to save /etc/resolv.conf" $logfile \
		    "ERROR" || return 1
	fi

	# save /etc/named.conf if it exists
	if [[ -f /etc/named.conf ]]; then
		cp /etc/named.conf $STATE_DIR/etc.named.conf >$logfile 2>&1
		ckreturn $? "$n: failed to save /etc/named.conf" $logfile \
		    "ERROR" || return 1
	fi

	# save /var/named directory if it exists
	if [[ -d /var/named ]]; then
		tar cf $STATE_DIR/var.named /var/named >$logfile 2>&1
		ckreturn $? "$n: failed to save /var/named" $logfile "ERROR" \
		    || return 1
	fi
	
	# save NIS domain
	domainname > $STATE_DIR/domainname

	rm -f $logfile
}

# restore_state - restore a system state which was previously saved by
#	save_state(). The function takes one argument, which specify the state 
#	to be restored. 
# Usage: restore_state -c <state_name>
#	-c  - If this option is set, this function not only restores the 
#	      original state on the system, but also removes the temporary 
#	      files used to save the state; otherwise, those files are not
#	      removed by default.
#	state_name - the name for the state
# function returns 0 on success or an non-zero value on error, stderr has a 
# diagnostic message on error.
#

function restore_state {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x 
	n=restore_state
	logfile=$TMPDIR/restore_state.$$

	if (( $# < 1 )); then
		echo "USAGE: $n -c state_name"
		return 1
	fi

	removefile=0
        if [[ "$1" == "-c" ]]; then
                removefile=1
                shift
        fi
	state_name=$1

	STATE_DIR=$TMPDIR/system_state.$$.$state_name
	if [[ ! -d $STATE_DIR ]]; then
		echo "$state_name state doesn't exists!"
		return 1
	fi
	ret=0
	
	# If any of the following operations fails, the function doesn't 
	# return immediately. Instead, it continues to restore the system
	# state as much as possible.

	# resotre /etc/default/nfs
	cp $STATE_DIR/etc.default.nfs /etc/default/nfs >$logfile 2>&1
	ckreturn $? "$n: failed to restore /etc/default/nfs" $logfile "ERROR" 
	ret=$((ret + $?))

	# restore /etc/resolv.conf if the back up exists
	if [[ -f $STATE_DIR/etc.resolv.conf ]]; then
		cp $STATE_DIR/etc.resolv.conf /etc/resolv.conf >$logfile 2>&1
		ckreturn $? "$n: failed to restore /etc/resolv.conf" $logfile \
		    "ERROR" 
		ret=$((ret + $?))
	else
		rm -f /etc/resolv.conf
	fi 

	# disable DNS server temporarily
	dns_service disable 6 "failed to disable dns service" "ERROR"
	ret=$((ret + $?))

	# restore /etc/named.conf if the back up exists
	if [[ -f $STATE_DIR/etc.named.conf ]]; then
		cp $STATE_DIR/etc.named.conf /etc/named.conf >$logfile 2>&1
		ckreturn $? "$n: failed to restore /etc/named.conf" $logfile \
		    "ERROR" 
		ret=$((ret + $?))
	else
		rm -f /etc/named.conf
	fi

	# restore /var/named directory if it exists
	if [[ -f $STATE_DIR/var.named ]]; then
		tar xf $STATE_DIR/var.named >$logfile 2>&1
		ckreturn $? "$n: failed to restore /var/named" $logfile "ERROR"
		ret=$((ret + $?))
	else
		rm -rf /var/named
		ret=$((ret + $?))
	fi

	# start dns server if necessary
	[[ -f /etc/named.conf ]] \
	    && dns_service enable 6 "failed to disable dns service" "ERROR"
	ret=$((ret + $?))

	# resotre NIS domain
	domainname $(cat $STATE_DIR/domainname) 2>$logfile
	ckreturn $? "$n: failed to restore NIS domain" $logfile "ERROR"
	ret=$((ret + $?))
 
	# restart mapid service
        mapid_service refresh 6 "failed to restart mapid service" "UNRESOLVED"
	ret=$((ret + $?))

	[[ $removefile -eq 1 ]] && rm -rf $STATE_DIR
	rm -f $logfile

	return $ret
}

# clear_state - clear a system state which was previously saved by
#	save_state(), which means, to remove the temporary files and directory
#	used for it.
# Usage: clear_state <state_name>
#	state_name - the name for the state
# function returns 0 on success or 1 if the state is unknown(that is, the 
# directory for it is not found).
#
function clear_state {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x 
	n=clear_state
	logfile=$TMPDIR/clear_state.$$

	if (( $# < 1 )); then
		echo "USAGE: $n state_name"
		return 1
	fi
	state_name=$1

	STATE_DIR=$TMPDIR/system_state.$$.$state_name
	if [[ ! -d $STATE_DIR ]]; then
		echo "$state_name state doesn't exists!"
		return 1
	fi

	rm -rf $STATE_DIR
}

# gen_assert_desc - generates assertion descriptions from the comments in
#	function headers.
# Usage: gen_assert_desc file keyword
#	file - the file to be scanned
#	prefix - the prefix of assertion names, which is used to construct
#		a pattern to search for assertion descriptions. It can be null.
# function always return 0.
#
function gen_assert_desc {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x 

	file=$1
	assert_prefix=$2

	grep "^# ${assert_prefix}.*: " $file >$TMPFILE 2>/dev/null
	set -A assert_names $(cat $TMPFILE | cut -d' ' -f2 | sed 's/://g')
	x=0
	while (( $x < ${#assert_names[*]} )); do
		assert_descs[$x]=$( \
		    nawk -v assert=${assert_names[$x]}             \
			'BEGIN { pattern = "# " assert ": "; }     \
		         (index($0, pattern ) != 0) {              \
			    $0 = substr($0, length(pattern)+1);    \
			    getline nextline;                      \
			    while (index(nextline, "#\t") != 0) {  \
			        $0 = $0 " " substr(nextline, 3);   \
			        getline nextline;                  \
		     	    }                                      \
			    print $0;                              \
		        }' $file)
		x=$((x + 1))
	done
	rm -f $TMPFILE
}

# get_assert_desc - gets assertion description from database generated by
#	gen_assert_desc(), for a specific assertion
# Usage: get_assert_desc assert
#	assert - the name of the assertion to be search for
# function always return 0.
#

function get_assert_desc {
        [[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x 

	assert=$assert_prefix$1

	x=0
	while (( $x < ${#assert_names[*]} )); do
		[[ ${assert_names[$x]} == "$assert" ]] \
		    && echo "${assert_descs[$x]}"
		x=$((x + 1))
	done
}

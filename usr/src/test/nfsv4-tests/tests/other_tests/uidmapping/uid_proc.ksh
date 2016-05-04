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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# uid_proc.ksh 
#     The file contains global variables and support functions uidmapping tests.
#     It contains three sections to help other scrips set up an initial 
#     scripting environment:
#
#        1) The 1st section sources necessary files
#	 2) The 2nd section defines variables 
#	 3) The 3rd section defines functions 
#
#     All other ksh scripts under "uidmapping" directory are expected to source
#     this file only.
#
# Note on temporary file management:
#     This file defines a ERRLOG variable, which is used by all scripts
#     under "uidmapping" directory as a temporary file to store error message. 
#     If a process creates that file(surely it will), it SHOULD remove that 
#     file when it exits no matter if it exits normally or it is interrupted.
#
#     However, for simplicity purpose, a function might exits without cleaning
#     up the temporary file it created. An example if set_local_domain() in 
#     this file and setup() in runtests.ksh file. If some commands failed
#     within those functions, they just return without any cleanup. That 
#     won't cause any problem since we have a per-process file clean up 
#     solution described above.

[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

#
# source necessary files 
#

NAME=$(basename $0)
CDIR=$(pwd)
TESTROOT=${TESTROOT:-"$CDIR/../../"}
TESTSH="$TESTROOT/testsh"

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
CONFIGFILE=/var/tmp/nfsv4/config/config.suite
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

# source useful functions
if [[ ! -f $TESTSH ]]; then
        echo "$NAME: TESTSH[$TESTSH] not found; test UNINITIATED."
        exit $UNINITIATED
fi

. $TESTSH

# 
# "Global" variables used by all scripts or functions
#

# test directory
TESTDIR=$ZONE_PATH/uidmapping

# testfile name. 
TESTFILE=uidmapping.$$.test

# positions of own and group fields in "ls -l" output
OWN=3
GRP=4

# temporary output file 
ERRLOG=$TMPDIR/uidmapping.$$.err

#
# Functions
#

# variables for backup files, used by set/restore_local_domain() functions
NFSCFG_BACKUP=$TMPDIR/uidmapping.nfscfg.backup
DNSCFG_BACKUP=$TMPDIR/uidmapping.dnscfg.backup
DNS_NOTCONFIGURED=$TMPDIR/uidmapping.dns_notconfigured
NIS_DOMAIN=$TMPDIR/uidmapping.nis_domain

# restart_mapid_service
#     The function restarts mapid service and verifies it has been 
#     restarted successfully. The function is designed to replace 
#     the usual "svcadm restart" command.
# usage:
#     restart_mapid_service
# return value:
#     0 on success; 1 on error

function restart_mapid_service
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	orig_pid=$(pgrep -z $(zonename) nfsmapid)

	svcadm restart svc:/network/nfs/mapid:default
	(( $? == 0)) || return 1

	# check daemon pid
	wait_now 10 "new_pid=\$(pgrep -z $(zonename) nfsmapid); \
	    [[ \$new_pid != $orig_pid ]]" || return 1
	# check service status
	wait_now 10 "st=\$(svcprop -p restarter/state nfs/mapid); \
	    [[ \$st == 'online' ]]" || return 1

	sleep 2
}

# set_local_domain
#     The function takes one argument and sets localhost's mapid domain
#     to it. If the argument is not null, it modifies /etc/default/nfs file; 
#     or else, it removes /etc/default/nfs and /etc/resolv.conf files and 
#     unsets nis domain.
#	
#     The original environment changed by this function can be 
#     restored by call of restore_local_domain(). These two functions are 
#     supposed to be used together.
# usage:
#     set_local_domain <new_domain>
# return value:
#     0 on success; 1 on error

function set_local_domain
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	# check arguments
	if (( $# != 1 )); then 
		echo "Usage: set_local_domain <new_domain>"
		return 1
	fi

	typeset new_domain=$1

	# Back up /etc/default/nfs
        cp -p /etc/default/nfs $NFSCFG_BACKUP 2>$ERRLOG
        ckreturn $? "could not back up /etc/default/nfs" $ERRLOG "ERROR" \
	    || return 1

	if [[ -n $new_domain ]]; then
		orig_pid=$(pgrep -z $(zonename) nfsmapid)
		# Set mapid domain
		sharectl set -p NFSMAPID_DOMAIN=$new_domain nfs 1>$ERRLOG 2>&1
		ckreturn $? "could not set domain for client" $ERRLOG "ERROR" \
	    	    || return 1
		wait_now 10 "[[ \$(sharectl get -p NFSMAPID_DOMAIN nfs | \
			awk -F= '{print \$2}') == $new_domain ]]"
		ckreturn $? "the nfs domain has not been updated even after \
			10 seconds" "ERROR" || return 1
		# check daemon pid
		wait_now 10 "new_pid=\$(pgrep -z $(zonename) nfsmapid); \
			[[ \$new_pid != $orig_pid ]]" || return 1
		# check service status
		wait_now 10 "st=\$(svcprop -p restarter/state nfs/mapid); \
			[[ \$st == 'online' ]]" || return 1
		sleep 2
	else
		# Back up DNS setting
		if [[ -f /etc/resolv.conf ]]; then
			# DNS was configured and thus needs to be backed up.
			cp -p /etc/resolv.conf $DNSCFG_BACKUP 2>$ERRLOG
			ckreturn $? "could not back up /etc/resolv.conf" \
			    $ERRLOG "ERROR" || return 1
		else
			# DNS wasn't configured. Mark that with a file
			touch $DNS_NOTCONFIGURED 2>$ERRLOG
			ckreturn $? \
			    "could not generate $DNS_NOTCONFIGURED" \
		    	    $ERRLOG "ERROR" || return 1
		fi

		# Back up NIS domain
		domainname | cat > $NIS_DOMAIN
		ckreturn $? "could not back up nis domain" "ERROR" || return 1

		# Set mapid domain
		grep -v "NFSMAPID_DOMAIN" /etc/default/nfs \
		    > $TMPDIR/uidmapping.$$.tmp 2>$ERRLOG \
		    && mv $TMPDIR/uidmapping.$$.tmp /etc/default/nfs 2>$ERRLOG \
       		    && rm -f /etc/resolv.conf 2>$ERRLOG \
		    && domainname "" 2>$ERRLOG \
		    && restart_mapid_service 2>$ERRLOG 
		ckreturn $? "could not set mapid domain to null" $ERRLOG \
		    "ERROR" || return 1
	fi

	# This function may exit on various errors, so it may fail to reach 
	# the following line and thus leave temporary error file unremoved.
	# However, it doesn't matter. Since this function is always supposed 
	# to be used together with restore_local_domain() function, which 
	# can help to do that if needed. 
	rm -f $ERRLOG
}

# restore_local_domain
#     the function restores the original environment changed by call of 
#     setup_local_domain().
# usage:
#     restore_local_domain
# return value:
#     0 on success; non-zero on error

function restore_local_domain
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	typeset ret=0

	# Restore /etc/default/nfs 
	if [[ -f $NFSCFG_BACKUP ]]; then
		# Restore the file
		mv $NFSCFG_BACKUP /etc/default/nfs 2>$ERRLOG
		ckreturn $? "could not restore /etc/default/nfs" $ERRLOG \
		    "WARNING" || ret=$((ret + 1))
	fi

	# Restore DNS configuration if necessary
	if [[ -f $DNS_NOTCONFIGURED ]]; then
		# no dns configuration at all
		rm -f $DNS_NOTCONFIGURED 2>$ERRLOG
		ckreturn $? "could not remove $DNS_NOTCONFIGURED" \
	    	    $ERRLOG "WARNING" || ret=$((ret + 1))
	elif [[ -f $DNSCFG_BACKUP ]]; then
		# Restore /etc/resolv.conf 
		mv $DNSCFG_BACKUP /etc/resolv.conf 2>$ERRLOG
		ckreturn $? "could not restore /etc/resolv.conf" \
		    $ERRLOG "WARNING" || ret=$((ret + 1))
	fi

	# Restore NIS domain if necessary
	if [[ -f $NIS_DOMAIN ]]; then
		domainname $(cat $NIS_DOMAIN) 2>$ERRLOG \
		    && rm -f $NIS_DOMAIN
		ckreturn $? "could not restore NIS domain" $ERRLOG "WARNING" \
		    || ret=$((ret + 1))
	fi

	# Restart nfsmapid
	restart_mapid_service 1>$ERRLOG 2>&1
	ckreturn $? "could not restart nfsmapid" $ERRLOG "WARNING" \
	    || ret=$((ret + 1))

	rm -f $ERRLOG

	return $ret
}

# get_free_id 
# 	This function returns a uid or gid which is unknown on 
#	both client and server. It does that by first trying an value 
#	large enough and check if it is mappable or not on server and client. 
#	If yes, it increases the value by one and try it again until the max 
#	try number is exceeded.
# Usage: get_free_id "UID"|"GID"
# Return Values:	    
#	On success, it returns 0 and outputs uid/gid on stdout;
#	On failure, it returns 1.

function get_free_id
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	# check arguments
	if (( $# != 1 )); then 
		echo "Usage: get_free_id \"UID\"|\"GID\""
		return 1
	fi

	# select different database based on query type
	idtype=$1
	case $idtype in 
		UID )
			database="passwd"
			;;
		GID )
			database="group"
			;;
		* )
			echo "Usage: get_free_id \"UID\"|\"GID\""
			return 1
			;;
	esac
	
	# 
	# The following code looks for an uid or gid unknown on both 
	# client and server. It picks up a number large enough(5000000)
	# and tries it first. If the number is not free, increases it by one
	# and tries again until the maximum retry number(100) is met. 
	#

	val=4999999
	st_server=0
	st_client=0

	while (( st_server != 2 || st_client != 2 ))
	do
		val=$((val + 1))
		if (( val >= 5000100 )); then
			# if not in the first 100 ids, assume other problem
			rm -f $ERRLOG
			return 1
		fi

		# check it on server side
		execute $SERVER root "getent $database $val" 1>/dev/null \
            	    2> $ERRLOG
		st_server=$?
		[[ $DEBUG != 0 ]] && cat $ERRLOG >&2

		# check it on client side
		getent $database $val 1>/dev/null 2>$ERRLOG
		st_client=$?
		[[ $DEBUG != 0 ]] && cat $ERRLOG >&2
	done

	echo $val

	rm -f $ERRLOG
	return 0
}

# print_state
#       This function prints the configuration of the test system, which can
#       be used to help to debug command failures. It currently does the
#       following and might be enhanced when necessary.
#          - print /var/run/nfs4_domain on client and server
#          - print users in /etc/passwd on client and server
# Usage: print_state
# Return Values:
#       it always returns 0.

function print_state
{
	echo "\n===================== DEBUG INFORMATION ====================="
	echo "nfs domain on client: $(cat /var/run/nfs4_domain)"
	echo "nfs domain on server: $(execute $SERVER root cat /var/run/nfs4_domain)"
	typeset MAPID_FMRI="svc:/network/nfs/mapid:default"
	echo "nfs/mapid on client:"
	svcs $MAPID_FMRI
	echo "nfs/mapid on server:"
	execute $SERVER root svcs $MAPID_FMRI
	users_on_client=$(cut -d: -f1 /etc/passwd)
	echo "users on client: " $users_on_client
	users_on_server=$(execute $SERVER root cut -d: -f1 /etc/passwd)
	echo "users on server: " $users_on_server
	echo "============================ END =============================\n"
}

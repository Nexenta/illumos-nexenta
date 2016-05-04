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
# uidmapping_pos05.ksh
#     This file contains positive testcases for the setup that client domain
#     is null. The testcases are divided into two groups, the first group 
#     are using chown/chgrp/ls to change user/group id and then verify it. 
#     They are:
#
#	{a} - user is known to both client and server.
#	{b} - group is known to both client and server.
#	{c} - user is unknown to server
#	{d} - user is unknown to client
#
#     The second group are using setfacl/getfacl to modify acl entries and
#     then verify it. They are:
#
#	{e} - user is known to both client and server.
#	{f} - group is known to both client and server.
#	{g} - user is unknown to server

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

trap "cleanup" EXIT
trap "exit 1" HUP INT QUIT PIPE TERM

NAME=`basename $0`
UIDMAPENV="./uid_proc"
UNINITIATED=6

# set up script running environment
if [ ! -f $UIDMAPENV ]; then
	echo "$NAME: UIDMAPENV[$UIDMAPENV] not found; test UNINITIATED."
	exit $UNINITIATED
fi
. $UIDMAPENV

ASSERTIONS=${ASSERTIONS:-"a b c d e f g"}
DESC="client mapid domain is NULL, "

function setup
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	# get the IP address of SERVER
	typeset srvipaddr=$(getent ipnodes $SERVER | head -1 | awk '{print $1}')

	is_cipso "vers=4" $SERVER
	if [ $? -eq $CIPSO_NFSV4 ]; then
		return 0
	fi

	# run test cases on shared directory
	cd $TESTDIR

	# set up client domain
	set_local_domain "" 2>$ERRLOG
	ckreturn $? "could not set up domain $Sdomain on client" \
		$ERRLOG "ERROR" || return 1

	# create test file
	touch $TESTFILE 2>$ERRLOG
	ckreturn $? "could not create $TESTFILE" $ERRLOG "ERROR" || return 1

	# when all naming services are down, there'll be no name->IP
	# translation; so we will use SERVER's IP for testing.
	SERVER=$srvipaddr
	execute $SERVER root "echo SERVER=$SERVER" >$ERRLOG 2>&1
	ckreturn $? "could not rsh to SERVER<$SERVER>" $ERRLOG "ERROR" || return 1
}

function cleanup
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	is_cipso "vers=4" $SERVER
	if [ $? -eq $CIPSO_NFSV4 ]; then
		return 0
	fi

	# we don't want user to interrupt cleanup procedure
	trap '' HUP INT QUIT PIPE TERM

	# remove testfile
	rm -f $TESTFILE
	ckreturn $? "could not remove $TESTFILE" $ERRLOG "WARNING"

	# Change to other directory
	cd $TESTROOT

	restore_local_domain 2>$ERRLOG
	ckreturn $? "could not restore local domain" $ERRLOG "WARNING"

	# remove temporary file
	rm -f $ERRLOG
	ckreturn $? "could not remove $ERRLOG" /dev/null "WARNING"
}

# 
# Assertions
# 

# a: user known to both client and server. Stringlized UID is sent 
# from client to server; user@domain is sent from server to client

function as_a
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	user=bin

	exp=$user
	desc="$DESC""user $user known to both client and server, "
	desc="$desc""change file owner(chown), "
	desc="$desc""check it on client and server(ls)"
	assertion a "$desc" $exp

	is_cipso "vers=4" $SERVER
	if [ $? -eq $CIPSO_NFSV4 ]; then
		echo "$NAME{a}: unsupported under CIPSO Trusted Extensions."
		echo "\tTEST UNSUPPORTED"
		return 1
	fi

	chown $user $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chown $TESTFILE" $ERRLOG "UNRESOLVED" \
		|| return 1
	
	# check it on server side
	res=$(execute $SERVER root "ls -l $ROOTDIR/$TESTFILE" | \
		nawk '{print $3}')
	if [ "$res" != "$exp" ]; then
		ckres2 uidmapping "$res" $exp "incorrect user name on server side"
		return 1
	fi

	# check it on client side
	res=$(ls -l $TESTFILE | nawk '{print $3}')
	ckres2 uidmapping "$res" $exp "incorrect user name on client side"
}

# b: group known to both client and server. Stringlized GID is sent 
# from client to server, group@domain is sent from server to client.

function as_b
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	group=uucp

	exp=$group
	desc="$DESC""group $group known to both client and server, "
	desc="$desc""change file owner_group(chgrp), "
	desc="$desc""check it on client and server(ls)"
	assertion b "$desc" $exp

	is_cipso "vers=4" $SERVER
	if [ $? -eq $CIPSO_NFSV4 ]; then
		echo "$NAME{b}: unsupported under CIPSO Trusted Extensions."
		echo "\tTEST UNSUPPORTED"
		return 1
	fi

	chgrp $group $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chown $TESTFILE" $ERRLOG "UNRESOLVED" \
		|| return 1
	
	# check it on server side
	res=$(execute $SERVER root "ls -l $ROOTDIR/$TESTFILE" | \
		nawk '{print $4}')
	if [ "$res" != "$exp" ]; then
		ckres2 uidmapping "$res" $exp "incorrect group name on server"
		return 1
	fi

	# check it on client side
	res=$(ls -l $TESTFILE | nawk '{print $4}')
	ckres2 uidmapping "$res" $exp "incorrect group name on client"
}

# c: user unknown to server. Stringlized UID is sent from client to server,
# stringlized UID is sent from server to client.
function as_c
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	user=$TUSERC
	userid=$TUSERCID

	#
	# Assertion c1
	#

	exp=$userid
	desc="$DESC""user $user unknown to server, "
	desc="$desc""change file owner(chown), "
	desc="$desc""check it on server(ls)"
	assertion c1 "$desc" $exp

	is_cipso "vers=4" $SERVER
	if [ $? -eq $CIPSO_NFSV4 ]; then
		echo "$NAME{c1}: unsupported under CIPSO Trusted Extensions."
		echo "\tTEST UNSUPPORTED"
		return 1
	fi

	chown $user $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chown $TESTFILE" $ERRLOG "UNRESOLVED" \
		|| return 1
	
	# Check it on server side
	result=$(execute $SERVER root "ls -l $ROOTDIR/$TESTFILE" | \
		nawk '{print $3}')
	ckres2 uidmapping "$result" $exp "incorrect user name on server"

	if [ "$result" != "$exp" ]; then
		echo "$NAME{c2}: skipped because {c1} failed"
		echo "\tTEST UNRESOLVED"
		return 1
	fi

	#
	# Assertion c2
	#

	exp=$user
	desc="$DESC""user $user unknown to server, "
	desc="$desc""change file owner(chown), "
	desc="$desc""check it on client(ls)"
	assertion c2 "$desc" $exp

	# Check it on client side
	res=$(ls -l $TESTFILE | nawk '{print $3}')
	ckres2 uidmapping "$res" $exp "incorrect user name on client"
}

# d: userid unknown to client. Stringlized UID is sent from client to 
# server, user@domain is sent from server to client.

function as_d
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	user=$TUSERS
	userid=$TUSERSID

	# 
	# Assertion d1
	#

	exp=$user
	desc="$DESC""uid $userid unknown to client, "
	desc="$desc""change file owner(chown), "
	desc="$desc""check it on server(ls)"
	assertion d1 "$desc" $exp

	is_cipso "vers=4" $SERVER
	if [ $? -eq $CIPSO_NFSV4 ]; then
		echo "$NAME{d1}: unsupported under CIPSO Trusted Extensions."
		echo "\tTEST UNSUPPORTED"
		return 1
	fi

	chown $userid $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chown $TESTFILE" $ERRLOG "UNRESOLVED" \
		|| return 1
	
	# Check it on server side
	result=$(execute $SERVER root "ls -l $ROOTDIR/$TESTFILE" | \
		nawk '{print $3}')
	ckres2 uidmapping "$result" $exp "incorrect user name on server"

	if [ "$result" != "$exp" ]; then
		echo "$NAME{d2}: skipped because {d1} failed"
		echo "\tTEST UNRESOLVED"
		return 1
	fi

	#
	# Assertion d2
	#

	exp="nobody"
	desc="$DESC""uid $userid unknown to client, "
	desc="$desc""change file owner(chown), "
	desc="$desc""check it on client(ls)"
	assertion d2 "$desc" $exp

	is_cipso "vers=4" $SERVER
	if [ $? -eq $CIPSO_NFSV4 ]; then
		echo "$NAME{d2}: unsupported under CIPSO Trusted Extensions."
		echo "\tTEST UNSUPPORTED"
		return 1
	fi

	# Check it on client side
	res=$(ls -l $TESTFILE | nawk '{print $3}')
	ckres2 uidmapping "$res" $exp "incorrect user name on client"
}

# e: user known to both client and server. Stringlized UID is sent 
# from client to server; user@domain is sent from server to client

function as_e
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
	
	user=sys
	
	exp=$user
	desc="$DESC""user $user known to both client and server, "
	desc="$desc""set user acl(setfacl), "
	desc="$desc""check it on server and client(getfacl)"
	assertion e "$desc" $exp

	is_cipso "vers=4" $SERVER
	if [ $? -eq $CIPSO_NFSV4 ]; then
		echo "$NAME{e}: unsupported under CIPSO Trusted Extensions."
		echo "\tTEST UNSUPPORTED"
		return 1
	fi

	setfacl -m user:$user:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacal $TESTFILE" $ERRLOG "UNRESOLVED" \
		|| return 1

	# check it on server side
	if [ $TestZFS -eq 1 ]; then
		# the remote file system is ZFS, using "ls -v" to get
		# file ACL
		res=$(execute $SERVER root "ls -v $ROOTDIR/$TESTFILE \
			| grep user:$user | head -1 |  cut -d: -f3")
	else 
		# the remote file system is UFS, using getacl to get
		# file ACL
		res=$(execute $SERVER root "getfacl $ROOTDIR/$TESTFILE \
			| grep user:$user | cut -d: -f2")
	fi

	if [ "$res" != "$exp" ]; then
		ckres2 uidmapping "$res" $exp "incorrect user name on server"
		return 1
	fi


	# check it on client side
	res=$(get_acl_val user:$user $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user name on client"
}

# f: group known to both client and server. Stringlized GID is sent 
# from client to server; group@domain is sent from server to client

function as_f
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
	
	group=nuucp
	
	exp=$group
	desc="$DESC""group $group known to both client and server, "
	desc="$desc""set group acl(setfacl), "
	desc="$desc""check it on server and client(getfacl)"
	assertion f "$desc" $exp

	is_cipso "vers=4" $SERVER
	if [ $? -eq $CIPSO_NFSV4 ]; then
		echo "$NAME{f}: unsupported under CIPSO Trusted Extensions."
		echo "\tTEST UNSUPPORTED"
		return 1
	fi

	setfacl -m group:$group:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacal $TESTFILE" $ERRLOG "UNRESOLVED" \
		|| return 1

	# check it on server side
	if [ $TestZFS -eq 1 ]; then
		# the remote file system is ZFS, using "ls -v" to get
		# file ACL
		res=$(execute $SERVER root "ls -v $ROOTDIR/$TESTFILE \
			| grep group:$group | head -1 |  cut -d: -f3")
	else
		# the remote file system is UFS, using getacl to get
		# file ACL
		res=$(execute $SERVER root "getfacl $ROOTDIR/$TESTFILE \
			| grep group:$group | cut -d: -f2")
	fi

	if [ "$res" != "$exp" ]; then
		ckres2 uidmapping "$res" $exp "incorrect group name on server"
		return 1
	fi

	# check it on client side
	res=$(get_acl_val group:$group $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect group name on client"
}

# g: user unknown to server. Stringlized UID is sent from client to server
# and vice versa.

function as_g
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
	
	user=$TUSERC
	userid=$TUSERCID

	# 
	# Assertion g1
	#
	
	exp=$userid
	desc="$DESC""user $user unknown to server, "
	desc="$desc""set user acl(setfacl), "
	desc="$desc""check it on server(getfacl)"
	assertion g1 "$desc" $exp

	is_cipso "vers=4" $SERVER
	if [ $? -eq $CIPSO_NFSV4 ]; then
		echo "$NAME{g1}: unsupported under CIPSO Trusted Extensions."
		echo "\tTEST UNSUPPORTED"
		return 1
	fi

	setfacl -m user:$user:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacal $TESTFILE" $ERRLOG "UNRESOLVED" \
		|| return 1

	# check it on server side
	if [ $TestZFS -eq 1 ]; then
		# the remote file system is ZFS, using "ls -v" to get
		# file ACL
		result=$(execute $SERVER root "ls -v $ROOTDIR/$TESTFILE \
			| grep user:$userid | head -1 |  cut -d: -f3")
	else
		# the remote file system is UFS, using getacl to get
		# file ACL
		result=$(execute $SERVER root "getfacl $ROOTDIR/$TESTFILE \
			| grep user:$userid | cut -d: -f2")
	fi

	ckres2 uidmapping "$result" $exp "incorrect user name on server"

	if [ "$result" != "$exp" ]; then
		echo "$NAME{g2}: skipped because {g1} failed"
		echo "\tTEST UNRESOLVED"
		return 1
	fi

	#
	# Assertion g2
	#

	exp=$user
	desc="$DESC""user $user unknown to server, "
	desc="$desc""set user acl(setfacl), "
	desc="$desc""check it on client(getfacl)"
	assertion g2 "$desc" $exp

	# check it on client side
	res=$(get_acl_val user:$user $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user name on client"
}

# h: user id unknown to client. Stringlized UID is sent from client to server,
# and user@domain is sent from server to client.
#
# Note: Due to bug 6261858, the assertion couldn't pass. Since there is 
# already a bug for it, to avoid unnecessary confusion, I didn't 
# implement it at this time. The comment is used as placeholder for future
# development of this assertion.

# setup 
setup || exit $UNINITIATED

# Main loop
for i in $ASSERTIONS
do
	as_$i || print_state
done

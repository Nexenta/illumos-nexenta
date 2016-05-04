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
# uidmapping_03.ksh  
#     This file contains positive testcases for the setup that both server 
#     and client have the same domain. The testcases are divided into two 
#     groups, the first group are using chown/chgrp/ls to change user/group
#     id and then verify it. They are:
#    
#       {a} - change owner to root and verify it
#	{b} - change group to root and verify it
#  	{c} - change owner to normal user(uucp) and verify it
#	{d} - change group to normal group(uucp) and verify it
#	{e} - change user and group at the same time and verify them
#	{f} - change owner to user id unknown to both client and server
#	{g} - change group to group id unknown to both client and server
#	{h} - change owner to user which has different ids on client and server
#	{i} - change owner to user known only to server
#
#     The second group are using setfacl/getfacl to modify acl entries and
#     then verify it. They are:
#
#	{j} - add acl entry for root user and verify it
#	{k} - add acl entry for root group and verify it
#	{l} - add acl entry for normal user(uucp) and verify it
#	{m} - add acl entry for normal group(uucp) and verify it
#	{n} - add acl entries for normal user and group at the same time
#	      and verify it
#	{o} - add acl entry for user id unknown to both client and server
#	{p} - add acl entry for group id unknown to both client and server
#	{q} - add acl entry for user which has different ids on client 
#	      and server

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

ASSERTIONS=${ASSERTIONS:-"a b c d e f g h i j k l m n o p q"}
DESC="client and server have the same mapid domain, "

function setup
{
        [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

        # run test cases on shared directory
        cd $TESTDIR

	if [ "$Sdomain" != "$Cdomain" ]; then
		# set up client domain
		set_local_domain $Sdomain 2>$ERRLOG 
		ckreturn $? "could not set up domain $Sdomain on client" \
		    $ERRLOG "ERROR" || return 1
	fi

	# create temporary file for testing
	touch $TESTFILE 2>$ERRLOG 
	ckreturn $? "could not create $TESTFILE" $ERRLOG "ERROR" || return 1
}

function cleanup
{
        [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

        # we don't want user can interrupt cleanup procedure 
        trap '' HUP INT QUIT PIPE TERM

	# remove testfile
	rm -f $TESTFILE 2>$ERRLOG
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
# assertions using chown/chgrp
#

function as_a
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	uid=0;user="root"

	exp=$user
	desc="$DESC""owner set to $uid(chown), "
	desc="$desc""check it on client(ls)"
	assertion a "$desc" $exp

	chown $uid $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chown $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_val $OWN $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user name"
}


function as_b
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	gid=0;group="root"

	exp=$group
	desc="$DESC""group set to $gid, "
	desc="$desc""check it on client(ls)"
	assertion b "$desc" $exp

	chgrp 0 $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chgrp $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1
	
	res=$(get_val $GRP $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect group name"
}


function as_c
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	uid=5;user="uucp"

	exp=$user
	desc="$DESC""known mapable user id $uid, "
	desc="$desc""change file owner(chown), "
	desc="$desc""check it on client(ls)"
	assertion c "$desc" $exp

	chown $uid $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chown $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_val $OWN $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user name"
}


function as_d
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	gid=5;group="uucp"

	exp=$group
	desc="$DESC""known mapable group id $gid, "
	desc="$desc""change file owner_group(chgrp), "
	desc="$desc""check it on client(ls)"
	assertion d "$desc" $exp

	chgrp $gid $TESTFILE
	ckreturn $? "could not chgrp $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_val $GRP $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect group name"
}


function as_e
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	user="nuucp";group="nuucp"

	# Assertion e1
	exp=$user
	desc="$DESC""known user $user and group $group, "
	desc="$desc""change file owner and owner_group(chown), "
	desc="$desc""check owner on client(ls)"
	assertion e1 "$desc" $exp

	chown nuucp:nuucp $TESTFILE
	ckreturn $? "could not chown $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_val $OWN $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user name"

	# Assertion e2
	exp=$group
	desc="$DESC""known user $user and group $group, "
	desc="$desc""change file owner and owner_group(chown), "
	desc="$desc""check group on client(ls)"
	assertion e2 "$desc" $exp

	res=$(get_val $GRP $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect group name"
}


function as_f
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	uid=$(get_free_id UID)
	ckreturn $? "could not find free uid on server and client" /dev/null \
	    "UNRESOLVED" || return 1

	exp=$uid
	desc="$DESC""user id $uid unmappable on client and server, "
	desc="$desc""change file owner(chown), "
	desc="$desc""check it on client(ls)"
	assertion f "$desc" $exp

	chown $uid $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chown $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_val $OWN $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user id"
}

function as_g
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	gid=$(get_free_id GID)
	ckreturn $? "could not find free gid on server and client" /dev/null \
	    "UNRESOLVED" || return 1

	exp=$gid
	desc="$DESC""group id $gid unmappable on client and server, "
	desc="$desc""change file owner_group(chgrp), "
	desc="$desc""check it on client(ls)"
	assertion g "$desc" $exp

	chgrp $gid $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chgrp $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_val $GRP $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect group id"
}


function as_h
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	uid=$TUSERCID3;user=$TUSERC3

	exp=$user
	desc="$DESC""common user $user but with different user ids, "
	desc="$desc""change file owner(chown), "
	desc="$desc""check it on client(ls)"
	assertion h "$desc" $exp

	chown $uid $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chown $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_val $OWN $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user name"
}

function as_i
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	uid=$TUSERSID;user="nobody"

	exp=$user
	desc="$DESC""user id only known to server: $uid, "
	desc="$desc""change file owner(chown), "
	desc="$desc""check it on client(ls)"
	assertion i "$desc" $exp

	chown $uid $TESTFILE 2>$ERRLOG
	ckreturn $? "could not chown $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_val $OWN $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user name"
}

# 
# assertions using acls
# 

function as_j
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	uid=0;user=root

	exp=$user
	desc="$DESC""user acl for user $uid set(setfacl), "
	desc="$desc""check user acl on client(getfacl)"
	assertion j "$desc" $exp

	setfacl -m user:$uid:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_acl_val user:$user $TESTFILE)
	ckres2 uidmapping "$res" $user "incorrect user name"

	setfacl -d user:$uid:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "WARNING" 
}


function as_k
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	gid=0;group=root

	exp=$group
	desc="$DESC""group acl for group $gid set(setfacl), "
        desc="$desc""check group acl on client(getfacl)"
	assertion k "$desc" $exp

	setfacl -m group:0:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_acl_val group:$group $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect group name"

	setfacl -d group:$gid:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "WARNING" 
}


function as_l
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	uid=5; user=uucp

	exp=$user
	desc="$DESC""known mapable user id $uid, "
	desc="$desc""set user acl(setfacl), "
	desc="$desc""check user acl on client(getfacl)"
	assertion l "$desc" $exp

	setfacl -m user:$uid:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_acl_val user:uucp $TESTFILE)
	ckres2 uidmapping "$res" $user "incorrect user name"

	setfacl -d user:$uid:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "WARNING" 
}


function as_m
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	gid=5; group=uucp

	exp=$group
	desc="$DESC""known mapable group id $gid, "
	desc="$desc""set group acl(setfacl), "
	desc="$desc""check group acl on client(getfacl)"
	assertion m "$desc" $exp

	setfacl -m group:$gid:r-x $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1
	
	res=$(get_acl_val group:$group $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect group name"

	setfacl -d group:$gid:r-x $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "WARNING" 
}


function as_n
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	user=nuucp; group=nuucp
	
	# assertion n1
	exp=$user
	desc="$DESC""known user $user and group $group, "
	desc="$desc""set user acl and group acl(setfacl), "
	desc="$desc""check user acl(getfacl)"
	assertion n1 "$desc" $exp

	setfacl -m user:nuucp:rw-,group:nuucp:r-x $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_acl_val user:$user $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user name"

	# assertion n2
	exp=$group
	desc="$DESC""known user $user and group $group, "
        desc="$desc""set user acl and group acl(setfacl), "
        desc="$desc""check group acl(getfacl)"
	assertion n2 "$desc" $exp

	res=$(get_acl_val group:$group $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect group name"

	setfacl -d user:nuucp:rw-,group:nuucp:r-x $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "WARNING"
}


function as_o
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	uid=$(get_free_id UID)
	ckreturn $? "could not find free uid on server and client" /dev/null \
	    "UNRESOLVED" || return 1

	exp=$uid
	desc="$DESC""user id $uid unmappable on server and client, "
	desc="$desc""set user acl(setfacl), "
	desc="$desc""check user acl on client(getfacl)"
	assertion o "$desc" $exp

	setfacl -m user:$uid:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_acl_val user:$uid $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user id"

	setfacl -d user:$uid:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "WARNING"
}

function as_p
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	gid=$(get_free_id GID)
	ckreturn $? "could not find free gid on server and client" /dev/null \
	    "UNRESOLVED" || return 1

	exp=$gid
	desc="$DESC""group id $gid unmappable on server and client, "
	desc="$desc""set group acl(setfacl), "
	desc="$desc""check group acl on client(getfacl)"
	assertion p "$desc" $exp

	setfacl -m group:$gid:r-x $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1

	res=$(get_acl_val group:$gid $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect group id"

	setfacl -d group:$gid:r-x $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "WARNING"
}


function as_q
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	uid=$TUSERCID3; user=$TUSERC3
	
	exp=$user
	desc="$DESC""common user but with different user ids: $uid, "
	desc="$desc""set user acl(setfacl), "
	desc="$desc""check user acl on client(getfacl)"
	assertion q "$desc" $exp

	setfacl -m user:$uid:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "UNRESOLVED" \
	    || return 1
	
	res=$(get_acl_val user:$user $TESTFILE)
	ckres2 uidmapping "$res" $exp "incorrect user name"
	
	setfacl -d user:$uid:rw- $TESTFILE 2>$ERRLOG
	ckreturn $? "could not setfacl $TESTFILE" $ERRLOG "WARNING"
}

# set up test environment
setup || exit $UNINITIATED

# main loop
for i in $ASSERTIONS
do
	as_$i || print_state
done

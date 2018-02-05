#!/bin/ksh -p
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
# Copyright (C) 2013 by Jim Klimov - implemented the previously absent
#    cloning of zones from specified snapshot, and avoidance of sys-unconfig
#
# Copyright 2018 Nexenta Systems, Inc. All rights reserved.

. /usr/lib/brand/ipkg/common.ksh

m_usage=$(gettext "clone {sourcezone}")
f_nosource=$(gettext "Error: unable to determine source zone dataset.")
f_badsource=$(gettext "Error: specified snapshot is invalid for this source zone.")
f_baddestpool=$(gettext "Error: Can not clone, source and target pools differ.")

ZFS=/usr/sbin/zfs
ZONEADM=/usr/sbin/zoneadm

# Clean up on failure
trap_exit()
{
	if (( $ZONE_IS_MOUNTED != 0 )); then
		error "$v_unmount"
		$ZONEADM -z $ZONENAME unmount
	fi

	exit $ZONE_SUBPROC_INCOMPLETE
}

# Set up ZFS dataset hierarchy for the zone.

ROOT="rpool/ROOT"

# Use clone or copy method to dupilcate zone datasets.
do_copy=false

# Other brand clone options are invalid for this brand.
while getopts "m:R:s:Xz:" opt; do
	case $opt in
		m)      case "$OPTARG" in
			"copy")
				ZONEPATH=`$ZONEADM -z $2 list -p | \
					awk -F: '{print $4}'`
				do_copy=true
				;;
			*)	fail_usage "";;
			esac
			;;
		R)	ZONEPATH="$OPTARG" ;;
		s)      case "$OPTARG" in
			*@*) # Full snapshot name was provided, or just "@snap"
			     # Split this into dataset name (even if empty) and
			     # snapshot name (also may be empty)
				SNAPNAME="`echo "$OPTARG" | sed 's/^[^@]*@//'`"
				REQUESTED_DS="`echo "$OPTARG" | sed 's/\([^@]*\)@.*$/\1/'`"
				;;
			*/*) # Only dataset name was passed, so we will make a
			     # snapshot there automatically and clone off it
				SNAPNAME=""
				REQUESTED_DS="$OPTARG"
				;;
			*)   # Only snapshot name was passed, so we will clone
			     # the source zone's active ZBE and this snapshot
				SNAPNAME="$OPTARG"
				REQUESTED_DS=""
				;;
			esac
			;;
		X)      NO_SYSUNCONFIG=yes ;;
		z)	ZONENAME="$OPTARG" ;;
		*)	fail_usage "";;
	esac
done
shift $((OPTIND-1))

if [ $# -ne 1 ]; then
	fail_usage "";
fi

sourcezone="$1"
get_current_gzbe

if [ -z "$REQUESTED_DS" ]; then
	# Find the active source zone dataset to clone.
	sourcezonepath=`$ZONEADM -z $sourcezone list -p | awk -F: '{print $4}'`
	if [ -z "$sourcezonepath" ]; then
		fail_fatal "$f_nosource"
	fi

	get_zonepath_ds $sourcezonepath
	get_active_ds $CURRENT_GZBE $ZONEPATH_DS

	spdir=`/usr/bin/dirname $sourcezonepath`
	get_zonepath_ds $spdir
	spdir_ds=$ZONEPATH_DS
else
	# Sanity-check the provided dataset (should exist and be an IPS ZBE)
	REQUESTED_DS="`echo "$REQUESTED_DS" | egrep '^.*/'"$sourcezone"'/ROOT/[^/]+$'`"
	if [ $? != 0 -o x"$REQUESTED_DS" = x ]; then
		fail_fatal "$f_badsource"
	fi
	$ZFS list -H -o \
		org.opensolaris.libbe:parentbe,org.opensolaris.libbe:active \
		"$REQUESTED_DS" > /dev/null || \
			fail_fatal "$f_badsource"
	ACTIVE_DS="$REQUESTED_DS"
fi

# Another sanity-check: requested snapshot exists for default or requested ZBE
if [ x"$SNAPNAME" != x ]; then
	$ZFS list -H "$ACTIVE_DS@$SNAPNAME" > /dev/null || \
		fail_fatal "$f_badsource"
fi

#
# Now set up the zone's datasets
#

#
# First make the top-level dataset.
#

pdir=`/usr/bin/dirname $ZONEPATH`
zpname=`/usr/bin/basename $ZONEPATH`

get_zonepath_ds $pdir
zpds=$ZONEPATH_DS

fail_zonepath_in_rootds $zpds

#
# Make sure zone is cloned within the same zpool
#
if [[ $do_copy != true ]]; then
	case $zpds in
		$spdir_ds)
			break
			;;
		*)
			fail_fatal "$f_baddestpool"
			break
			;;
	esac
fi

#
# We need to tolerate errors while creating the datasets and making the
# mountpoint, since these could already exist from some other BE.
#

$ZFS create $zpds/$zpname

$ZFS create -o mountpoint=legacy -o zoned=on $zpds/$zpname/ROOT

if [ x"$SNAPNAME" = x ]; then
	# make snapshot
	SNAPNAME=${ZONENAME}_snap
	SNAPNUM=0
	while [ $SNAPNUM -lt 100 ]; do
		$ZFS snapshot $ACTIVE_DS@$SNAPNAME
		if [ $? = 0 ]; then
			break
		fi
		SNAPNUM=`expr $SNAPNUM + 1`
		SNAPNAME="${ZONENAME}_snap$SNAPNUM"
	done

	# NOTE: This artificially limits us to 100 clones of a "golden" zone
	# into a same-named (test?) zone, unless clones are based on some
	# same snapshot via command-line
	if [ $SNAPNUM -ge 100 ]; then
		fail_fatal "$f_zfs_create"
	fi
fi

LOGFILE=$(/usr/bin/mktemp -t -p /var/tmp $ZONENAME.clone_log.XXXXXX)
if [[ -z "$LOGFILE" ]]; then
        fatal "$e_tmpfile"
fi
exec 2>>"$LOGFILE"

# do clone
#
# If there is already an existing zone BE for this zone it's likely it belongs
# to another global zone BE. If that is the case the name of the zone BE
# dataset is ajusted to avoid name collisions.
#
# If do_copy is set (the -m copy option was used) zfs send/recv is used so
# the zone can be cloned across pools.
#
BENAME=zbe
BENUM=0
while [ $BENUM -lt 100 ]; do
	if $do_copy; then
		log "Copy source zoneroot to new zoneroot"
		$ZFS send $ACTIVE_DS@$SNAPNAME | \
		$ZFS recv $zpds/$zpname/ROOT/$BENAME
		if [ $? = 0 ]; then
			$ZFS destroy $ACTIVE_DS@$SNAPNAME
			break
		fi
	else
		log "Clone zone root dataset"
		$ZFS clone $ACTIVE_DS@$SNAPNAME $zpds/$zpname/ROOT/$BENAME
		if [ $? = 0 ]; then
			break
		fi
	fi
	BENUM=`expr $BENUM + 1`
	BENAME="zbe-$BENUM"
done

if [ $BENUM -ge 100 ]; then
	fail_fatal "$f_zfs_create"
fi

$ZFS set $PROP_ACTIVE=on $zpds/$zpname/ROOT/$BENAME || \
	fail_incomplete "$f_zfs_create"

$ZFS set $PROP_PARENT=$CURRENT_GZBE $zpds/$zpname/ROOT/$BENAME || \
	fail_incomplete "$f_zfs_create"

$ZFS set canmount=noauto $zpds/$zpname/ROOT/$BENAME || \
	fail_incomplete "$f_zfs_create"

if [ ! -d $ZONEPATH/root ]; then
	/usr/bin/mkdir -p $ZONEPATH/root
	/usr/bin/chmod 700 $ZONEPATH
fi

ZONE_IS_MOUNTED=0
trap trap_exit EXIT

#
# Completion of unconfigure_zone will leave the zone root mounted for
# ipkg brand zones.  The root won't be mounted for labeled brand zones.
#
is_brand_labeled
(( $? == 0 )) && if [ x"$NO_SYSUNCONFIG" = xyes ]; then
	vlog "$v_mounting"
	ZONE_IS_MOUNTED=1
	$ZONEADM -z $ZONENAME mount -f || fatal "$e_badmount"
else
	unconfigure_zone
fi

trap - EXIT
exit $ZONE_SUBPROC_OK

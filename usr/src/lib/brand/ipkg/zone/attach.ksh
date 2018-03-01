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
# Copyright (c) 2008, 2011, Oracle and/or its affiliates. All rights reserved.
# Copyright 2015, OmniTI Computer Consulting, Inc. All rights reserved.
# Copyright 2018 Nexenta Systems, Inc. All rights reserved.
#

. /usr/lib/brand/ipkg/common.ksh

m_attach_log=$(gettext "Log File: %s")
m_zfs=$(gettext "A ZFS file system was created for the zone.")
m_usage=$(gettext  "attach [-a archive] [-d dataset] [-n] [-r zfs-recv] [-u]\n\tThe -a archive option specifies a tar file or cpio archive.\n\tThe -d dataset option specifies an existing dataset.\n\tThe -r zfs-recv option receives the output of a 'zfs send' command\n\tof an existing zone root dataset.\n\tThe -u option indicates that the software should be updated to match\n\tthe current host.")
m_attach_root=$(gettext "               Attach Path: %s")
m_attach_ds=$(gettext   "        Attach ZFS Dataset: %s")
m_gzinc=$(gettext       "       Global zone version: %s")
m_zinc=$(gettext        "   Non-Global zone version: %s")
m_need_update=$(gettext "                Evaluation: Packages in zone %s are out of sync with the global zone. To proceed, retry with the -u flag.")
m_cache=$(gettext       "                     Cache: Using %s.")
m_updating=$(gettext    "  Updating non-global zone: Output follows")
m_sync_done=$(gettext   "  Updating non-global zone: Zone updated.")
m_complete=$(gettext    "                    Result: Attach Succeeded.")
m_failed=$(gettext      "                    Result: Attach Failed.")

#
# These two messages are used by the install_image function in
# /usr/lib/brand/shared/common.ksh.  Yes, this is terrible.
#
installing=$(gettext    "                Installing: This may take several minutes...")
no_installing=$(gettext "                Installing: Using pre-existing data in zonepath")

f_sanity_variant=$(gettext "  Sanity Check: FAILED, couldn't determine %s from image.")
f_sanity_global=$(gettext  "  Sanity Check: FAILED, appears to be a global zone (%s=%s).")
f_update=$(gettext "Could not update attaching zone")
f_no_pref_publisher=$(gettext "Unable to get preferred publisher information for zone '%s'.")
f_nosuch_key=$(gettext "Failed to find key %s for global zone publisher")
f_nosuch_cert=$(gettext "Failed to find cert %s for global zone publisher")
f_ds_config=$(gettext  "Failed to configure dataset %s: could not set %s.")
f_no_active_ds_mounted=$(gettext  "Failed to locate any dataset mounted at %s.  Attach requires a mounted dataset.")

# Clean up on interrupt
trap_cleanup() {
	typeset msg=$(gettext "Installation cancelled due to interrupt.")

	log "$msg"

	# umount any mounted file systems
	umnt_fs

	trap_exit
}

# If the attach failed then clean up the ZFS datasets we created.
trap_exit() {
	if [[ $EXIT_CODE == $ZONE_SUBPROC_OK ]]; then
		# unmount the zoneroot if labeled brand
		is_brand_labeled
		(( $? == 1 )) && ( umount $ZONEROOT || \
		    log "$f_zfs_unmount" "$ZONEPATH/root" )
	else
		if [[ "$install_media" != "-" ]]; then
			/usr/lib/brand/ipkg/uninstall $ZONENAME $ZONEPATH -F
		else
			# Restore the zone properties for the pre-existing
			# dataset.
			if [[ -n "$ACTIVE_DS" ]]; then
				zfs set zoned=off $ACTIVE_DS
				(( $? != 0 )) && error "$f_ds_config" \
				    "$ACTIVE_DS" "zoned=off"
				zfs set canmount=on $ACTIVE_DS
				(( $? != 0 )) && error "$f_ds_config" \
				    "$ACTIVE_DS" "canmount=on"
				zfs set mountpoint=$ZONEROOT $ACTIVE_DS
				(( $? != 0 )) && error "$f_ds_config" \
				    "$ACTIVE_DS" "mountpoint=$ZONEROOT"
			fi
		fi
		log "$m_failed"
	fi

	exit $EXIT_CODE
}

EXIT_CODE=$ZONE_SUBPROC_USAGE
install_media="-"

trap trap_cleanup INT
trap trap_exit EXIT

#set -o xtrace

PKG="/usr/bin/pkg"
KEYDIR=/var/pkg/ssl

# If we weren't passed at least two arguments, exit now.
(( $# < 2 )) && exit $ZONE_SUBPROC_USAGE

ZONENAME="$1"
ZONEPATH="$2"
# XXX shared/common script currently uses lower case zonename & zonepath
zonename="$ZONENAME"
zonepath="$ZONEPATH"

shift; shift	# remove ZONENAME and ZONEPATH from arguments array

ZONEROOT="$ZONEPATH/root"
logdir="$ZONEROOT/var/log"

#
# Resetting GZ_IMAGE to something besides slash allows for simplified
# debugging of various global zone image configurations-- simply make
# an image somewhere with the appropriate interesting parameters.
#
GZ_IMAGE=${GZ_IMAGE:-/}
PKG_IMAGE=$GZ_IMAGE
export PKG_IMAGE

allow_update=0
noexecute=0

unset inst_type

typeset gz_incorporations=""
#
# $1 is an empty string to be populated with a list of incorporation
# fmris.
#
gather_incorporations() {
	typeset -n incorporations=$1
	typeset p=

	for p in \
	    $(LC_ALL=C $PKG search -Hl -o pkg.name \
	    ':pkg.depend.install-hold:core-os*');do
		incorporations="$incorporations $(get_pkg_fmri $p)"
	done
}

# Other brand attach options are invalid for this brand.
while getopts "a:d:nr:u" opt; do
	case $opt in
		a)
			if [[ -n "$inst_type" ]]; then
				fatal "$incompat_options" "$m_usage"
			fi
		 	inst_type="archive"
			install_media="$OPTARG"
			;;
		d)
			if [[ -n "$inst_type" ]]; then
				fatal "$incompat_options" "$m_usage"
			fi
		 	inst_type="directory"
			install_media="$OPTARG"
			;;
		n)	noexecute=1 ;;
		r)
			if [[ -n "$inst_type" ]]; then
				fatal "$incompat_options" "$m_usage"
			fi
		 	inst_type="stdin"
			install_media="$OPTARG"
			;;
		u)	allow_update=1 ;;
		?)	fail_usage "" ;;
		*)	fail_usage "";;
	esac
done
shift $((OPTIND-1))

if [[ $noexecute == 1 && -n "$inst_type" ]]; then
	fatal "$m_usage"
fi

[[ -z "$inst_type" ]] && inst_type="directory"

if [ $noexecute -eq 1 ]; then
	#
	# The zone doesn't have to exist when the -n option is used, so do
	# this work early.
	#

	# XXX There is no sw validation for IPS right now, so just pretend
	# everything will be ok.
	EXIT_CODE=$ZONE_SUBPROC_OK
	exit $ZONE_SUBPROC_OK
fi

LOGFILE=$(/usr/bin/mktemp -t -p /var/tmp $ZONENAME.attach_log.XXXXXX)
if [[ -z "$LOGFILE" ]]; then
	fatal "$e_tmpfile"
fi
exec 2>>"$LOGFILE"

log "$m_attach_log" "$LOGFILE"

#
# TODO - once sxce is gone, move the following block into
# usr/lib/brand/shared/common.ksh code to share with other brands using
# the same zfs dataset logic for attach. This currently uses get_current_gzbe
# so we can't move it yet since beadm isn't in sxce.
#

# Validate that the zonepath is not in the root dataset.
pdir=`dirname $ZONEPATH`
get_zonepath_ds $pdir
fail_zonepath_in_rootds $ZONEPATH_DS

EXIT_CODE=$ZONE_SUBPROC_NOTCOMPLETE

if [[ "$install_media" == "-" ]]; then
	#
	# Since we're using a pre-existing dataset, the dataset currently
	# mounted on the {zonepath}/root becomes the active dataset.  We
	# can't depend on the usual dataset attributes to detect this since
	# the dataset could be a detached zone or one that the user set up by
	# hand and lacking the proper attributes.  However, since the zone is
	# not attached yet, the 'install_media == -' means the dataset must be
	# mounted at this point.
	#
	ACTIVE_DS=`mount -p | nawk -v zroot=$ZONEROOT '{
	    if ($3 == zroot && $4 == "zfs")
		    print $1
	}'`

	[[ -z "$ACTIVE_DS" ]] && fatal "$f_no_active_ds_mounted" $ZONEROOT

	# Set up proper attributes on the ROOT dataset.
	get_zonepath_ds $ZONEPATH
	zfs list -H -t filesystem -o name $ZONEPATH_DS/ROOT >/dev/null 2>&1
	(( $? != 0 )) && fatal "$f_no_active_ds"

	# need to ensure zoned is off to set mountpoint=legacy.
	zfs set zoned=off $ZONEPATH_DS/ROOT
	(( $? != 0 )) && fatal "$f_ds_config" $ZONEPATH_DS/ROOT "zoned=off"

	zfs set mountpoint=legacy $ZONEPATH_DS/ROOT
	(( $? != 0 )) && fatal "$f_ds_config" $ZONEPATH_DS/ROOT \
	    "mountpoint=legacy"
	zfs set zoned=on $ZONEPATH_DS/ROOT
	(( $? != 0 )) && fatal "$f_ds_config" $ZONEPATH_DS/ROOT "zoned=on"

	#
	# We're typically using a pre-existing mounted dataset so setting the
	# following propery changes will cause the {zonepath}/root dataset to
	# be unmounted.  However, a p2v with an update-on-attach will have
	# created the dataset with the correct properties, so setting these
	# attributes won't unmount the dataset.  Thus, we check the mount
	# and attempt the remount if necessary.
	#
	get_current_gzbe
	zfs set $PROP_PARENT=$CURRENT_GZBE $ACTIVE_DS
	(( $? != 0 )) && fatal "$f_ds_config" $ACTIVE_DS \
	    "$PROP_PARENT=$CURRENT_GZBE"
	zfs set $PROP_ACTIVE=on $ACTIVE_DS
	(( $? != 0 )) && fatal "$f_ds_config" $ACTIVE_DS "$PROP_ACTIVE=on"
	zfs set canmount=noauto $ACTIVE_DS
	(( $? != 0 )) && fatal "$f_ds_config" $ACTIVE_DS "canmount=noauto"
	zfs set zoned=off $ACTIVE_DS
	(( $? != 0 )) && fatal "$f_ds_config" $ACTIVE_DS "zoned=off"
	zfs inherit mountpoint $ACTIVE_DS
	(( $? != 0 )) && fatal "$f_ds_config" $ACTIVE_DS "'inherit mountpoint'"
	zfs inherit zoned $ACTIVE_DS
	(( $? != 0 )) && fatal "$f_ds_config" $ACTIVE_DS "'inherit zoned'"

	mounted_ds=`mount -p | nawk -v zroot=$ZONEROOT '{
	    if ($3 == zroot && $4 == "zfs")
		    print $1
	}'`

	if [[ -z $mounted_ds ]]; then
		mount -F zfs $ACTIVE_DS $ZONEROOT || fatal "$f_zfs_mount"
	fi
else
	#
	# Since we're not using a pre-existing ZFS dataset layout, create
	# the zone datasets and mount them.  Start by creating the zonepath
	# dataset, similar to what zoneadm would do for an initial install.
	#
	zds=$(zfs list -H -t filesystem -o name $pdir 2>/dev/null)
	if (( $? == 0 )); then
		pnm=$(/usr/bin/basename $ZONEPATH)
		# The zonepath dataset might already exist.
		zfs list -H -t filesystem -o name $zds/$pnm >/dev/null 2>&1
		if (( $? != 0 )); then
			zfs create "$zds/$pnm"
			(( $? != 0 )) && fatal "$f_zfs_create"
			vlog "$m_zfs"
		fi
	fi

	create_active_ds
fi

#
# The zone's datasets are now in place.
#

log "$m_attach_root" "$ZONEROOT"
# note \n to add whitespace
log "$m_attach_ds\n" "$ACTIVE_DS"

install_image "$inst_type" "$install_media"

#
# End of TODO block to move to common code.
#

#
# Perform a sanity check to confirm that the image is not a global zone.
#
VARIANT=variant.opensolaris.zone
variant=$(LC_ALL=C $PKG -R $ZONEROOT variant -H $VARIANT)
[[ $? -ne 0 ]] && fatal "$f_sanity_variant" $VARIANT

echo $variant | IFS=" " read variantname variantval
[[ $? -ne 0 ]] && fatal "$f_sanity_variant"

# Check that we got the output we expect...
# XXX new pkg5 output is slightly different, ignore this check for now
#[[ $variantname = "$VARIANT" ]] || fatal "$f_sanity_variant" $VARIANT

# Check that the variant is non-global, else fail
[[ $variantval = "nonglobal" ]] || fatal "$f_sanity_global" $VARIANT $variantval

#
# Try to find the "entire" incorporation's FMRI in the gz.
#
gz_entire_fmri=$(get_entire_incorp)

#
# If entire isn't installed, create an array of global zone core-os
# incorporations.
#
if [[ -z $gz_entire_fmri ]]; then
	gather_incorporations gz_incorporations
fi

#
# We're done with the global zone: switch images to the non-global
# zone.
#
PKG_IMAGE="$ZONEROOT"

#
# Try to find the "entire" incorporation's FMRI in the ngz.
#
ngz_entire_fmri=$(get_entire_incorp)

[[ -n $gz_entire_fmri ]] && log "$m_gzinc" "$gz_entire_fmri"
[[ -n $ngz_entire_fmri ]] && log "$m_zinc" "$ngz_entire_fmri"

#
# Create the list of incorporations we wish to install/update in the
# ngz.
#
typeset -n incorp_list
if [[ -n $gz_entire_fmri ]]; then
    incorp_list=gz_entire_fmri
else
    incorp_list=gz_incorporations
fi

#
# If there is a cache, use it.
#
if [[ -f /var/pkg/pkg5.image && -d /var/pkg/publisher ]]; then
	PKG_CACHEROOT=/var/pkg/publisher
	export PKG_CACHEROOT
	log "$m_cache" "$PKG_CACHEROOT"
fi

LC_ALL=C $PKG copy-publishers-from $GZ_IMAGE

#
# Bring the ngz entire incorporation into sync with the gz as follows:
# - First compare the existence of entire in both global and non-global
#   zone and update the non-global zone accordingly.
# - Then, if updates aren't allowed check if we can attach because no
#   updates are required. If we can, then we are finished.
# - Finally, we know we can do updates and they are required, so update
#   all the non-global zone incorporations using the list we gathered
#   from the global zone earlier.
#
if [[ -z $gz_entire_fmri && -n $ngz_entire_fmri ]]; then
	if [[ $allow_update == 1 ]]; then
		log "$m_updating"
		LC_ALL=C $PKG uninstall entire || pkg_err_check "$f_update"
	else
		log "\n$m_need_update" "$ZONENAME"
		EXIT_CODE=$ZONE_SUBPROC_NOTCOMPLETE
		exit $EXIT_CODE
    fi
fi

if [[ $allow_update == 0 ]]; then
	LC_ALL=C $PKG install --accept --no-refresh -n $incorp_list
	if [[ $? == 4 ]]; then
		log "\n$m_complete"
		EXIT_CODE=$ZONE_SUBPROC_OK
		exit $EXIT_CODE
	else
		log "\n$m_need_update" "$ZONENAME"
		EXIT_CODE=$ZONE_SUBPROC_NOTCOMPLETE
		exit $EXIT_CODE
	fi
fi

#
# If the NGZ doesn't have entire, but the GZ does, then we have to install
# entire twice. First time we don't specify a version and let constraining
# incorporations determine the version. Second time, we try to install the
# same version as we have in the GZ.
#
if [[ -n $gz_entire_fmri && -z $ngz_entire_fmri ]]; then
	LC_ALL=C $PKG install --accept --no-refresh entire  || \
	    pkg_err_check "$f_update"
fi

LC_ALL=C $PKG install --accept --no-refresh $incorp_list  || \
    pkg_err_check "$f_update"

log "\n$m_sync_done"
log "$m_complete"

EXIT_CODE=$ZONE_SUBPROC_OK
exit $ZONE_SUBPROC_OK

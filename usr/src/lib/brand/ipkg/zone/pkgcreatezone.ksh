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
# Copyright (c) 2007, 2011, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2015, OmniTI Computer Consulting, Inc. All rights reserved.
# Copyright 2018 Nexenta Systems, Inc. All rights reserved.
#

#
# Resetting GZ_IMAGE to something besides slash allows for simplified
# debugging of various global zone image configurations-- simply make
# an image somewhere with the appropriate interesting parameters.
#
GZ_IMAGE=${GZ_IMAGE:-/}
PKG_IMAGE=$GZ_IMAGE
export PKG_IMAGE

. /usr/lib/brand/ipkg/common.ksh

f_a_obs=$(gettext "-a publisher=uri option is obsolete, use -P instead.")
f_pkg5_missing=$(gettext "pkg(5) does not seem to be present on this system.\n")
f_img=$(gettext "failed to create image\n")
f_pkg=$(gettext "failed to install package\n")
f_interrupted=$(gettext "Installation cancelled due to interrupt.\n")
f_bad_publisher=$(gettext "Syntax error in publisher information.")
f_no_entire_in_pref=$(gettext "Unable to locate the incorporation '%s' in the preferred publisher '%s'.\nUse -P to supply a publisher which contains this package.\n")

m_publisher=$(gettext   "   Publisher: Using %s (%s).")
m_cache=$(gettext       "       Cache: Using %s.")
m_image=$(gettext       "       Image: Preparing at %s.")
m_incorp=$(gettext      "Sanity Check: Looking for 'entire' incorporation.")
m_core=$(gettext	"  Installing: Packages (output follows)")
m_smf=$(gettext		" Postinstall: Copying SMF seed repository ...")
m_mannote=$(gettext     "        Note: Man pages can be obtained by installing pkg:/system/manual")

m_usage=$(gettext "\n        install [-h]\n        install [-c certificate_file] [-k key_file] [-P publisher=uri]\n                [-e extrapkg [...]]\n        install {-a archive|-d path} {-p|-u} [-s|-v]")

m_done=$(gettext      " done.")

trap_cleanup() {
	print "$f_interrupted"
	exit $int_code
}

int_code=$ZONE_SUBPROC_NOTCOMPLETE
trap trap_cleanup INT

extra_packages=""
ZONENAME=""
ZONEPATH=""
pub_and_origins=""

# Setup i18n output
TEXTDOMAIN="SUNW_OST_OSCMD"
export TEXTDOMAIN

KEYDIR=/var/pkg/ssl
PKG=/usr/bin/pkg

#
# Just in case.  This should probably be removed later.
#
[[ ! -x $PKG ]] && fail_incomplete "$f_pkg5_missing"

certfile="None"
keyfile="None"
unset install_archive
unset source_dir
unset msg
unset silent_mode
unset verbose_mode

while getopts "a:c:d:e:hk:P:pR:suvz:" opt; do
	case $opt in
		a)	# We're expecting a path to an archive
			if [[ ! -f $OPTARG ]]; then
				# If old style 'pub=uri' parameter then error.
				echo $OPTARG | egrep -s =
				if (( $? == 0 )); then
					fail_usage "$f_a_obs"
				fi
			fi
			install_archive="-a $OPTARG";;
		c)	certfile="$OPTARG" ;;
		d)	source_dir="-d $OPTARG";;
		e)	extra_packages="$extra_packages $OPTARG" ;;
		h)	fail_usage "";;
		k)	keyfile="$OPTARG" ;;
		P)	pub_and_origins="$OPTARG" ;;
		p)	preserve_zone="-p";;
		R)	ZONEPATH="$OPTARG" ;;
		s)	silent_mode=1;;
		u)	unconfig_zone="-u";;
		v)	verbose_mode="-v";;
		z)	ZONENAME="$OPTARG" ;;
		*)	fail_usage "";;
	esac
done
shift $((OPTIND-1))

if [[ -z $ZONEPATH || -z $ZONENAME ]]; then
	print -u2 "Brand error: No zone path or name"
	exit $ZONE_SUBPROC_USAGE
fi

# XXX shared/common script currently uses lower case zonename & zonepath
zonename="$ZONENAME"
zonepath="$ZONEPATH"

is_brand_labeled
brand_labeled=$?

ZONEROOT=$ZONEPATH/root
secinfo=""

# An image install can't use both -a AND -d...
[[ -n "$install_archive" && -n "$source_dir" ]] &&
    fail_usage "$f_incompat_options" "-a" "-d"

# The install can't be both verbose AND silent...
[[ -n $silent_mode && -n $verbose_mode ]] && \
    fail_usage "$f_incompat_options" "-s" "-v"

# The install can't both preserve and unconfigure
[[ -n $unconfig_zone && -n $preserve_zone ]] && \
    fail_usage "$f_incompat_options" "-u" "-p"

# IPS options aren't allowed when installing from a system image.
if [[ -n "$install_archive" || -n "$source_dir" ]]; then
	[[ -n $pub_and_origins ]] && fail_usage "$f_incompat_options" \
	    "-a|-d" "-P"
	[[ -n "$extra_packages" ]] && \
	    fail_usage "$f_incompat_options" "-a|-d" "-e"
	[[ "$certfile" != "None" ]] && \
	    fail_usage "$f_incompat_options" "-a|-d" "-c"
	[[ "$keyfile" != "None" ]] && \
	    fail_usage "$f_incompat_options" "-a|-d" "-k"
fi

# p2v options aren't allowed when installing from a repo.
if [[ -z $install_archive && -z $source_dir ]]; then
	[[ -n $preserve_zone || -n $unconfig_zone ]] && \
		fail_usage "$f_incompat_options" "default" "-p|-u"
fi

#
# Look for the 'entire' incorporation's FMRI in the current image; due to users
# doing weird machinations with their publishers, we strip off the publisher
# from the FMRI if it is present.
# It's ok to not find entire in the current image, since this means the user
# can install pre-release development bits for testing purposes.
#
# Comment out get_entire_incorp call below, would like to install only minimal set
# of packages into NexentaStor zone
#entire_fmri=$(get_entire_incorp)

#
# If we found an "entire" incorporation in the current image, then
# check to see if the user's choice of preferred publisher contains the
# version of the 'entire' incorporation needed.  This helps us to prevent
# mishaps in the event the user selected some weirdo publisher as their
# preferred one, or passed a preferred pub on the command line which doesn't
# have a suitable 'entire' in it.
#
if [[ -n $entire_fmri ]]; then
	# If we have a user-specified publisher and origin from -P, consult
	# only that one; otherwise any origin from the first publisher will do.
	list_origin=
	if [[ -n "$pub_and_origins" ]]; then
		#
		# Crack pub=url into two pieces.
		#
		echo $pub_and_origins | IFS="=" read publisher pub_origins
		if [[ -z $publisher || -z $pub_origins ]]; then
			fail_usage "$f_bad_publisher"
		fi
		list_origin="-g $pub_origins"
	else
		$PKG publisher -HPn -F tsv | cut -f1 | read publisher
	fi
	printf "$m_incorp\n"
	LC_ALL=C $PKG list $list_origin -af pkg://$publisher/$entire_fmri \
		> /dev/null 2>&1
	if [[ $? -ne 0 ]]; then
		fail_fatal "$f_no_entire_in_pref" $entire_fmri $publisher
	fi
fi

#
# Before installing the zone, set up ZFS dataset hierarchy for the zone root
# dataset.
#
create_active_ds

#
# If we're installing from an image, branch off to that installer.
#
if [[ -n $install_archive || -n $source_dir ]]; then
	/usr/lib/brand/ipkg/image_install $ZONENAME $ZONEPATH \
	    $install_archive $source_dir $verbose_mode $silent_mode \
	    $unconfig_zone $preserve_zone
	ii_result=$?

	if (( $ii_result != 0 )); then
		exit $ZONE_SUBPROC_NOTCOMPLETE
	fi
	exit $ZONE_SUBPROC_OK
fi

printf "$m_image\n" $ZONEROOT

# If we have a publisher specified by -P, pass it to image-create and use no
# other publishers. Otherwise, use all of the publishers from the GZ.
if [[ -n $pub_and_origins ]]; then
	LC_ALL=C $PKG image-create --zone --full -p $pub_and_origins \
	    $ZONEROOT || fail_incomplete "$f_img"
else
	LC_ALL=C $PKG image-create --zone --full $ZONEROOT \
	    || fail_incomplete "$f_img"
	LC_ALL=C $PKG -R $ZONEROOT copy-publishers-from $GZ_IMAGE \
	    || fail_incomplete "$f_img"
fi

# Change the value of PKG_IMAGE so that future PKG operation will work
# on the newly created zone rather than the global zone

PKG_IMAGE="$ZONEROOT"
export PKG_IMAGE

LC_ALL=C $PKG publisher -Hn -F tsv | cut -f1,7 | while read pub url; do
	printf "$m_publisher\n" $pub $url
done

if [[ -f /var/pkg/pkg5.image && -d /var/pkg/publisher ]]; then
	PKG_CACHEROOT=/var/pkg/publisher
	export PKG_CACHEROOT
	printf "$m_cache\n" $PKG_CACHEROOT
fi

printf "$m_core\n"
pkglist=""
if [[ -n $entire_fmri ]]; then
	pkglist="$pkglist $entire_fmri"
fi

pkglist="$pkglist
	pkg:///SUNWcs
	pkg:///SUNWcsd
	pkg:///system/network
	pkg:///service/file-system/nfs
	pkg:///network/ipfilter
	pkg:///system/extended-system-utilities
	pkg:///compress/bzip2
	pkg:///compress/gzip
	pkg:///compress/zip
	pkg:///compress/unzip
	pkg:///package/pkg"

#
# Get some diagnostic tools, truss, dtrace, etc.
#
pkglist="$pkglist
	pkg:/developer/linker
	pkg:/developer/dtrace"

#
# Needed for 'whois', 'snoop' I think; also provides rup, rmt, rsh etc.
#
pkglist="$pkglist
	pkg:/service/network/network-clients
	pkg:/network/ftp"

#
# Get at least one sensible shell, vim, openssh.
#
pkglist="$pkglist
	pkg:///shell/bash
	pkg:///shell/zsh
	pkg:///editor/vim
	pkg:///network/openssh
	pkg:///network/openssh-server"

#
# Get some name services and DNS.
#
pkglist="$pkglist
	pkg:/system/network/nis
	pkg:/network/dns/bind
	pkg:/naming/ldap"

#
# Get nfs client and autofs; it's a pain not to have them.
#
pkglist="$pkglist
	pkg:/system/file-system/autofs
	pkg:/system/file-system/nfs"

#
# Get routing daemons.  They're required for useful exclusive stack zones.
#
pkglist="$pkglist
	pkg:/system/network/routing"

#
# Get packages for TX zones if appropriate.
#
(( $brand_labeled == 1 )) && pkglist="$pkglist pkg:/system/trusted/trusted-nonglobal"

#
# Get man(1) but not the man pages
#
pkglist="$pkglist
	pkg:/text/doctools"

#
# Add in any extra packages requested by the user.
#
pkglist="$pkglist $extra_packages"

#
# Do the install; we just refreshed after image-create, so skip that.  We
# also skip indexing here, as that is also what the LiveCD does.
#
LC_ALL=C $PKG install --accept --no-index --no-refresh $pkglist || \
    pkg_err_check "$f_pkg"

printf "\n$m_mannote\n"

printf "$m_smf"
PROFILEDIR=etc/svc/profile
ln -s ns_files.xml $ZONEROOT/$PROFILEDIR/name_service.xml
ln -s generic_limited_net.xml $ZONEROOT/$PROFILEDIR/generic.xml
ln -s inetd_generic.xml $ZONEROOT/$PROFILEDIR/inetd_services.xml
ln -s platform_none.xml $ZONEROOT/$PROFILEDIR/platform.xml

# This was formerly done in i.manifest
repfile=$ZONEROOT/etc/svc/repository.db
cp $ZONEROOT/lib/svc/seed/nonglobal.db $repfile
chmod 0600 $repfile
chown root:sys $repfile

printf "$m_done\n"

# Clean up root as a role and jack if needed
if grep "^root::::type=role;" $ZONEROOT/etc/user_attr >/dev/null 2>&1; then
	printf "$m_brokenness\n"
	#
	# Remove "jack" user.
	#
	print "/^jack:/d\nw" | ed -s $ZONEROOT/etc/passwd
	chmod u+w $ZONEROOT/etc/shadow
	print "/^jack:/d\nw" | ed -s $ZONEROOT/etc/shadow
	chmod u-w $ZONEROOT/etc/shadow

	#
	# Set root from a role back to... not a role.  Grr.
	#
	print "s/^root::::type=role;/root::::/\nw" |
	    ed -s $ZONEROOT/etc/user_attr
fi

# If no password has been set, you'd have to log in with zlogin -S
# This is obtuse and highly undesireable.  A blank password is much
# better as it can only be used to zlogin the first time anyway
# and if someone were to turn on ssh (with PermitRootLogin yes)
# it would still prevent a remote login
sed -i -e 's%^root::%root:$5$kr1VgdIt$OUiUAyZCDogH/uaxH71rMeQxvpDEY2yX.x0ZQRnmeb9:%' $ZONEROOT/etc/shadow

#
# Labeled zones need to be able to modify /etc/gconf files, when gnome
# packages are installed in the zone.  Set up links in the zone to the
# global zone files -- this will provide default versions from the global
# zone, which can be modified by the zone, breaking the link.
if (( $brand_labeled == 1 )); then
	cd /etc/gconf
	for i in $(find .); do
		if [ ! -e $ZONEROOT/etc/gconf/$i ]; then
			if [ -d $i ]; then
				mkdir $ZONEROOT/etc/gconf/$i
			else
				ln -s /etc/gconf-global/$i \
				    $ZONEROOT/etc/gconf/$i
			fi
		fi
	done
fi

printf "$m_complete\n\n" ${SECONDS}
if (( $brand_labeled == 0 )); then
	printf "$m_postnote\n"
	printf "$m_postnote2\n"
else
	# Umount the dataset on the root.
	umount $ZONEROOT || printf "$f_zfs_unmount" "$ZONEPATH/root"
fi

exit $ZONE_SUBPROC_OK

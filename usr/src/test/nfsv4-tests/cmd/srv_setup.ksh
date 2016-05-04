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
# setup the $SERVER for testing NFS V4 protocols.
#

SETDEBUG
[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

NAME=$(basename $0)

id | grep "0(root)" > /dev/null 2>&1
if (( $? != 0 )); then
	echo "$NAME: ERROR - Must be root to run this script for setup."
	exit 1
fi

Usage="ERROR - Usage: $NAME -s | -c | -r \n
		-s: to setup this host w/v4 and share\n
		-r: to cleanup the LOFI/ZFS filesystems for recovery tests\n
		-c: to cleanup the server\n
"
if (( $# < 1 )); then
	echo "$NAME: ERROR - incorrect usage."
	echo $Usage
	exit 2
fi

ENVFILE=ENV_from_client
TMPDIR=Tmpdir_from_client
CONFIGDIR=CONFIGDIR_from_client
ZONE_PATH=ZONE_PATH_from_client

QUOTA_FMRI="svc:/network/nfs/rquota:default"
SMF_TIMEOUT=60

# source the environment/config file from client to be consistent
. $CONFIGDIR/$ENVFILE
. $CONFIGDIR/libsmf.shlib

iscipso=0
if [[ -x /usr/sbin/tninfo ]]; then
	/usr/sbin/tninfo -h $(uname -n) | grep cipso >/dev/null 2>&1
	if (( $? == 0 )); then
		iscipso=1
		if [[ -z $ZONE_PATH ]]; then
			echo "$NAME: ERROR - ZONE_PATH is null!"
			exit 2
		fi

		zlist=$(/usr/sbin/zoneadm list)
		if [[ -z $zlist ]]; then
			echo "$NAME: ERROR - no zones exist on server!"
			exit 2
		fi

		if [[ $zlist == global ]]; then
			echo "$NAME: ERROR - No non-global zones on server!"
			exit 2
		fi

		fnd=0
		for azone in $zlist
		do
			[[ $azone == global ]] && continue
			X=$(zoneadm -z $azone list -p | cut -d ":" -f 4)
			[[ -z $X ]] && continue
			X1=$(echo "$X" | sed -e 's/\// /g' | awk '{print $1}')
			X2=$(echo "$X" | sed -e 's/\// /g' | awk '{print $2}')
			Y1=$(echo "$ZONE_PATH" | sed -e 's/\// /g' | \
				awk '{print $1}')
			Y2=$(echo "$ZONE_PATH" | sed -e 's/\// /g' | \
				awk '{print $2}')
			if [[ $X1 == $Y1 && $X2 == $Y2 ]]; then
				fnd=1
				localzone=$azone
				break
			fi
		done

		if (( fnd == 0 )); then
			echo "$NAME: ERROR - ZONE_PATH doesn't match any zone!"
			exit 2
		fi
	fi
fi

function cleanup {
	rm -f $TMPDIR/*.$$
	exit $1
}

# quick function to create sub ZFS pool
function create_zpool
{
	[[ -n "$DEBUG" ]] && [[ "$DEBUG" != "0" ]] && set -x
	typeset Fname=create_zpool
	getopts fv opt
	case $opt in
	f) # create pool on file
		typeset pname=$2 fname=$3
		zpool create -f $pname $fname > $TMPDIR/zpool.out.$$ 2>&1
		if [[ $? != 0 ]]; then
			echo "$Fname: failed to create zpool -"
			cat $TMPDIR/zpool.out.$$
			zpool status $pname
			return 2
		fi
	;;
	v) # create pool on volume
		typeset size=$2 # size is in the form of 5m/2g
		typeset vname=$3
		typeset pname=$4
		echo "$NAME: Setting test filesystems with ZFS ..."
		zpool status > $TMPDIR/zstatus.out.$$ 2>&1
		grep "$vname" $TMPDIR/zstatus.out.$$ | \
			grep ONLINE >/dev/null 2>&1
		if [[ $? != 0 ]]; then
			zfs create -V $size $vname > $TMPDIR/zpool.out.$$ 2>&1
			if [[ $? != 0 ]]; then
				echo "$NAME: failed to create volume -"
				cat $TMPDIR/zpool.out.$$
				grep "same dev" $TMPDIR/zpool.out.$$ \
					> /dev/null 2>&1
				[[ $? == 0 ]] && zpool status
				return 2
			fi
			zpool create -f $pname /dev/zvol/dsk/$vname \
				> $TMPDIR/zpool.out.$$ 2>&1
			if [[ $? != 0 ]]; then
				echo "$NAME: failed to create sub zpool -"
				cat $TMPDIR/zpool.out.$$
				grep "same dev" $TMPDIR/zpool.out.$$ \
					> /dev/null 2>&1
				[[ $? == 0 ]] && zpool status
				return 2
			fi
		fi
	;;
	*)
		echo "$Fname: ERROR - incorrect usage."
		return 2
	;;
	esac

}

function destroy_zpool
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	# NSPCPOOL is always created; so need to destroy
	if [[ -n $NSPCPOOL ]]; then
		zpool destroy -f $NSPCPOOL >> $TMPDIR/zfsDes.out.$$ 2>&1
		if (( $? != 0 )); then
			echo "WARNING, failed to destroy [$NSPCPOOL];"
			cat $TMPDIR/zfsDes.out.$$
			echo "\t Please clean it up manually."
		fi
	fi

	ZFSn=$(zfs list | grep "$BASEDIR" | nawk '{print $1}')
	zfs destroy -f -r $ZFSn > $TMPDIR/zfsDes.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "WARNING, unable to cleanup [$BASEDIR];"
		cat $TMPDIR/zfsDes.out.$$
		echo "\t Please clean it up manually."
	fi
}

function create_test_fs
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	fsname=$1
	shift
	FSdir_opt=$*
	typeset ret=0

	if (( TestZFS == 1 )); then
		if [[ $fsname == NSPCDIR ]]; then
			typeset pool=NSPCpool
			mkfile 64m $BASEDIR/NSPCpoolfile
			create_zpool -f $pool $BASEDIR/NSPCpoolfile \
				> $TMPDIR/nspc.out.$$ 2>&1
			if [[ $? != 0 ]]; then
				echo "ERROR, unable to setup NSPC pool;"
				cat $TMPDIR/nspc.out.$$
				cleanup 3
			fi
			echo "NSPCPOOL=$pool; export NSPCPOOL" \
				>> $CONFIGDIR/$ENVFILE
			zfs set mountpoint=$NSPCDIR $pool \
				> $TMPDIR/$fsname.out.$$ 2>&1
			ret=$?
			chmod 0777 $NSPCDIR
		else
			create_zfs_fs $FSdir_opt > $TMPDIR/$fsname.out.$$ 2>&1
			ret=$?
		fi
	else
		$CONFIGDIR/setupFS -s $FSdir_opt > $TMPDIR/$fsname.out.$$ 2>&1
		ret=$?
	fi
	if (( $ret != 0 )); then
		echo "WARNING: unable to setup $fsname - "
		cat $TMPDIR/$fsname.out.$$
		cleanup $ret
	fi
}

function create_some_files 	# quick function to create some files
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	UDIR=$1

	head -88 $CONFIGDIR/setserver > $UDIR/$RWFILE
	chmod 0666 $UDIR/$RWFILE
	tail -38 $CONFIGDIR/setupFS > $UDIR/$ROFILE
	chmod 0444 $UDIR/$ROFILE
	mkdir -p $UDIR/$DIR0755/dir2/dir3
	chmod -R 0755 $UDIR/$DIR0755
	if (( TestZFS == 1 )); then
		ACLs=write_xattr/write_attributes/write_acl/add_file:allow
		chmod A+everyone@:${ACLs} $UDIR/$DIR0755 $UDIR/$RWFILE
	fi
	echo "this is the ext-attr file for $UDIR/$DIR0755" | \
		runat $UDIR/$DIR0755 "cat > $ATTRDIR_AT1; chmod 0777 ."
	runat $UDIR/$DIR0755 \
		"cp $ATTRDIR_AT1 $ATTRDIR_AT2; chmod 0 $ATTRDIR_AT2"
}

function create_zfs_fs 		# quick function to create ZFS filesystem
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	FSname=$1
	(( $# == 2 )) && FSsize=$2	# size is in the form of 5m/2g
	(( $# == 3 )) && FSmopt=$3	# remount option
	
	typeset -u ZName=$(basename $FSname)
	zfs create $ZFSPOOL/$ZName > $TMPDIR/czfs.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "create_zfs_fs failed to zfs create $ZFSPOOL/$ZName"
		cat $TMPDIR/czfs.out.$$
		return 2
	fi
	zfs set mountpoint=$FSname $ZFSPOOL/$ZName > $TMPDIR/szfs.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "create_zfs_fs failed to zfs set mountpoint=$FSname \c"
		echo "to $ZFSPOOL/$Zname"
		cat $TMPDIR/szfs.out.$$
		return 2
	fi
	chmod 777 $FSname
	ACLs=write_xattr/write_attributes/write_acl/add_file:allow
	chmod A+everyone@:${ACLs} $FSname

	if [[ -n $FSsize ]]; then
		zfs set quota=$FSsize $ZFSPOOL/$ZName > $TMPDIR/qzfs.out.$$ 2>&1
		if (( $? != 0 )); then
			echo "create_zfs_fs failed to zfs set quota=$FSsize"
			cat $TMPDIR/qzfs.out.$$
			return 2
		fi
		unset FSsize
	fi
	if [[ -n $FSmopt ]]; then
		zfs umount $ZFSPOOL/$ZName > $TMPDIR/mzfs.out.$$ 2>&1
		zfs mount -o $FSmopt $ZFSPOOL/$ZName >> $TMPDIR/mzfs.out.$$ 2>&1
		if (( $? != 0 )); then
			echo "create_zfs_fs failed to zfs remount $FSmopt"
			cat $TMPDIR/mzfs.out.$$
			return 2
		fi
		unset FSmopt
	fi
}


getopts scr opt
case $opt in
s)
	# Check if correct arch is in path (in case default got wrong value)
	arch=$(uname -p)
	if [[ $arch == sparc ]]; then
		arch2="i386"
	else
		arch2="sparc"
	fi
	# Make sure the wrong arch is not in string
	res=$(echo $CC_SRV | grep $arch2)
	if (( $? == 0 )); then
		OLD_CC=$CC_SRV;
		# try to fix by replacing with correct arch
		CC_SRV=$(echo $CC_SRV | sed "s/$arch2/$arch/g")
		sed "s@$OLD_CC@$CC_SRV@" $TMPDIR/$ENVFILE \
			> $TMPDIR/env.fil
		rm -f $TMPDIR/$ENVFILE
		mv $TMPDIR/env.fil $TMPDIR/$ENVFILE
	fi
	# Check if the specified compiler is available
	$CC_SRV -flags > $TMPDIR/cc-flags.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "WARNING: the compiler <$CC_SRV> failed to run"
		echo "\tsome tests may fail"
		echo "\t<cc -flags> output was:"
		cat $TMPDIR/cc-flags.out.$$
	fi

	cp -p /etc/passwd /etc/passwd.orig
	cp -p /etc/group /etc/group.orig
	# remove users left from setups not cleaned
	/usr/xpg4/bin/egrep -v "2345678." /etc/passwd.orig > /etc/passwd 2>&1
	/usr/xpg4/bin/egrep -v "2345678." /etc/group.orig > /etc/group 2>&1

	# add test users ... should be same as in $TESTHOST
	echo "$TUSER1:x:23456787:10:NFSv4 Test User 1:$TMPDIR:/bin/sh" \
		>>/etc/passwd
	echo "$TUSER2:x:23456788:10:NFSv4 Test User 2:$TMPDIR:/bin/sh" \
		>>/etc/passwd
	echo "$TUSER3:x:23456789:1:NFSv4 Test User 3:$TMPDIR:/bin/sh" \
		>>/etc/passwd
	#except this user
	echo "$TUSERS:x:$TUSERSID:10:NFSv4 Test User Server:$TMPDIR:/bin/sh" \
		>>/etc/passwd
	echo "$TUSERS2:x:$TUSERID:10:NFSv4 Test User Server 2:$TMPDIR:/bin/sh" \
		>>/etc/passwd
	echo \
		"$TUSERS3:x:$TUSERSID3:10:NFSv4 Test User Server 3:$TMPDIR:/bin/sh" \
		>>/etc/passwd
	echo "$UTF8_USR:x:$TUSERUTF8:$TUSERUTF8:uts8 USER 1:$TMPDIR:/sbin/sh"\
		>>/etc/passwd
	echo "$UTF8_USR::$TUSERUTF8:" >> /etc/group

	pwconv	# make sure shadow file match
	N=1
	n=$(/usr/xpg4/bin/egrep "2345678." /etc/group | wc -l | \
		nawk '{print $1}')
	if (( n != N )); then
		echo "$NAME: ERROR - adding test groups failed, \
			groups file shows n=$n not $N"
		cleanup 2
	fi
	n=$(/usr/xpg4/bin/egrep \
	"^$TUSER1|^$TUSER2|^$TUSER3|^$TUSERS|^$TUSERS2|^$TUSERS3" \
		/etc/shadow | wc -l | nawk '{print $1}')
	N=6
	if (( n != N )); then
		echo "$NAME: ERROR - adding normal test users failed, \
			shadow file shows n=$n not $N"
		cleanup 2
	fi
	res=$(locale | awk -F= '{print $2}' | grep -v "^$" | grep -v "C")
	if (( $? == 0 )); then
		echo "WARNING: locale not set to C. Some utf8 tests may fail."
		[[ $DEBUG != 0 ]] && echo "locale = $(locale)\n"
	else
		# this test is broken with some locales, so only execute
		n=$(/usr/xpg4/bin/egrep "^$(echo $UTF8_USR)" /etc/shadow | \
			wc -l | nawk '{print $1}')
		N=1
		if (( n != N )); then
			echo "$NAME: ERROR - adding UTF8 test users failed, \
				shadow file shows n=$n not $N"
			[[ $DEBUG != 0 ]] && echo "locale = $(locale)\n"
			cleanup 2
		fi
	fi

	# check if the nfs tunable values meet the requirement, if not,
	# set the new values and save the old values to .nfs.flg file
	if [[ ! -f $CONFIGDIR/$SERVER.nfs.flg ]]; then
		res=$($CONFIGDIR/set_nfstunable SERVER_VERSMIN=2 SERVER_VERSMAX=4)
		if (( $? != 0 )); then
			echo "ERROR: cannot set the specific nfs tunable on $SERVER"
			cleanup 1
		else
			[[ -n $res ]] && echo $res > $CONFIGDIR/$SERVER.nfs.flg
		fi
	fi

	# backup BASEDIR if it exists
	rm -fr $BASEDIR.Saved > /dev/null 2>&1
	[[ -d $BASEDIR ]] && mkdir -m 0777 $BASEDIR.Saved && \
		mv $BASEDIR/* $BASEDIR.Saved > /dev/null 2>&1

	# Create pre-defined test files/directories in $BASEDIR
	if (( TestZFS == 1 )); then
		# check first and create the pool only when it's not yet available
		if [[ -z $ZFSDISK ]]; then
			echo "$NAME: setup failed at $SERVER -"
			echo "\tmust define a valid ZFSDISK=<$ZFSDISK> \c"
			cleanup 2
		fi

		zpool status > $TMPDIR/zstatus.out.$$ 2>&1
		grep "$ZFSDISK" $TMPDIR/zstatus.out.$$ |grep ONLINE >/dev/null 2>&1
		if (( $? != 0 )); then
			echo "$NAME: zpool<$ZFSDISK> is not online -"
			cat $TMPDIR/zstatus.out.$$
			cleanup 2
		fi
		ZFSPOOL=$ZFSDISK; export ZFSPOOL

		echo "$NAME: Setting test filesystems with ZFS ..."
		create_zfs_fs $BASEDIR > $TMPDIR/zfs.out.$$ 2>&1
		if (( $? != 0 )); then
			echo "$NAME: failed to create_zfs_fs $BASEDIR -"
			cat $TMPDIR/zfs.out.$$
			cleanup 2
		fi
		# set aclinherit as "passthrough", which causes sub-dirs
		# and sub-files to inherit all inheritable ACL entries
		# without any modifications;
		# used for acl test
		typeset -u ZName=$(basename $BASEDIR)
		zfs set aclinherit=passthrough $ZFSPOOL/$ZName \
			> $TMPDIR/setprop.out.$$ 2>&1
		if (( $? != 0 )); then
			echo "$NAME: WARNING - Failed to set zfs property aclinherit \c"
			echo "to <passthrough> for $BASEDIR in $SERVER.  \c"
			echo "Some acl tests may fail."
			cat $TMPDIR/setprop.out.$$
		fi
		# verify the property is set to passthrough
		aclprop=$(zfs get -H -o value aclinherit $ZFSPOOL/$ZName 2>&1)
		if [[ $? != 0 || $aclprop != passthrough ]]; then
			echo "$NAME: WARNING - Failed to get zfs property aclinherit. \c"
			echo "Expected value is <passthrough>, while returned <$aclprop>"
			echo "Some acl tests may fail."
		fi
	fi

	# create test files/directories in the BASEDIR
	$CONFIGDIR/mk_srvdir $BASEDIR > $TMPDIR/mkbd.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "$NAME: ERROR - failed to create test files/dirs in $BASEDIR"
		cat $TMPDIR/mkbd.out.$$
		cleanup 99
	fi

	# share $BASEDIR with "-p" option for NFS testing;
	# such that when it's enabled by smf it's persistent, even with reboot
	share -F nfs -p -o rw $BASEDIR
	share | grep "$BASEDIR" > /dev/null 2>&1
	if (( $? != 0 )); then
		echo "$NAME: ERROR - failed to share <$BASEDIR>, aborting ..."
		share
		cleanup 99
	fi

	if (( TestZFS != 1 )); then
		# Create other FSs (with LOFI) for testing of different areas.
		SRVTESTDIR=$BASEDIR/LOFI_FILES; export SRVTESTDIR
		mkdir -m 0777 -p $SRVTESTDIR
	fi

	# ROFS test dir
	create_test_fs ROFSDIR $ROFSDIR 5m
	create_some_files $ROFSDIR
	$CONFIGDIR/operate_dir "share" $ROFSDIR "ro"

	# Create an FS to be exported with root access
	create_test_fs ROOTDIR $ROOTDIR
	create_some_files $ROOTDIR
	$CONFIGDIR/operate_dir "share" $ROOTDIR "anon=0"

	# PUBLIC test dir
	create_test_fs PUBTDIR $PUBTDIR
	$CONFIGDIR/mk_srvdir $PUBTDIR > $TMPDIR/cfpubt.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "WARNING, unable to create files/dirs in [$PUBTDIR];"
		cat $TMPDIR/cfpubt.out.$$
		echo "\t testing in the area may fail."
	fi
	$CONFIGDIR/operate_dir "share" $PUBTDIR "rw,public"

	# NSPCDIR test dir
	create_test_fs NSPCDIR $NSPCDIR
	# Create few test files/dirs first
	create_some_files $NSPCDIR
	# Also fill up the FS here
	$CONFIGDIR/fillDisk $NSPCDIR
	$CONFIGDIR/operate_dir "share" $NSPCDIR

	# KRB5 test dir
	create_test_fs KRB5DIR $KRB5DIR
	$CONFIGDIR/mk_srvdir $KRB5DIR > $TMPDIR/cfkrb5.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "WARNING, unable to create files/dirs in [$KRB5DIR];"
		cat $TMPDIR/cfkrb5.out.$$
		echo "\t testing in the area may fail."
	fi
	# XXX test system needs to be able to kinit in order to share w/krb5
	#$CONFIGDIR/operate_dir "share" $KRB5DIR "sec=krb5:krb5i:krb5p"

	# SSPC test dir
	create_test_fs SSPCDIR $SSPCDIR
	$CONFIGDIR/mk_srvdir $SSPCDIR > $TMPDIR/cfsspc.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "WARNING, unable to create files/dirs in [$SSPCDIR];"
		cat $TMPDIR/cfsspc.out.$$
		echo "\t testing in the area may fail."
	fi
	$CONFIGDIR/operate_dir "share" $SSPCDIR

	# QUOTA test dir
	create_test_fs QUOTADIR $QUOTADIR 5m
	$CONFIGDIR/mk_srvdir $QUOTADIR > $TMPDIR/cfpubt.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "WARNING, unable to create files/dirs in [$QUOTADIR];"
		cat $TMPDIR/cfpubt.out.$$
		echo "\t testing in the area may fail."
	fi
	touch $QUOTADIR/quotas
	if (( TestZFS != 1 )); then
		# also set quota for $TUSER2 and fill the quotas:
		quotaoff $QUOTADIR
		edquota $TUSER2 << __END > /dev/null 2>&1
:s/hard = 0/hard = 5/g
:wq
__END
		quotaon $QUOTADIR
		smf_fmri_transition_state do $QUOTA_FMRI online $SMF_TIMEOUT
		if [[ $? != 0 ]]; then
			echo "$NAME: ERROR - unable to start $QUOTA_FMRI"
			echo "\t testing in the area may fail."
		fi
	fi
	if (( iscipso == 1 )); then
		ZONEDIR=${QUOTADIR#$ZONE_PATH/root}
		zlogin $localzone "su $TUSER2 -c \
			\"cd $ZONEDIR; \
			touch file_$TUSER2.1 file_$TUSER2.2 file_$TUSER2.3; \
			mkfile 4k file_$TUSER2.4\""
	else
		su $TUSER2 -c \
			"cd $QUOTADIR; \
			touch file_$TUSER2.1 file_$TUSER2.2 file_$TUSER2.3; \
			mkfile 4k file_$TUSER2.4"
	fi
	if (( TestZFS == 1 )); then
		$CONFIGDIR/fillDisk $QUOTADIR
	fi
	$CONFIGDIR/operate_dir "share" $QUOTADIR

	# SSPCDIR2 test dir
	create_test_fs SSPCDIR2 $SSPCDIR2 3m
	$CONFIGDIR/operate_dir "share" $SSPCDIR2

	# SSPCDIR3 test dir with noxattr
	create_test_fs SSPCDIR3 $SSPCDIR3 6m noxattr
	$CONFIGDIR/operate_dir "share" $SSPCDIR3

	# NOTSHDIR - test requirement not to share this UFS
	create_test_fs NOTSHDIR $NOTSHDIR
	create_some_files $NOTSHDIR

	# and some symlinks for mounting symlink testing
	ln -s $BASEDIR/$LONGDIR $BASEDIR/symldir2
	ln -s $BASEDIR/nosuchdir $BASEDIR/syml_nodir
	ln -s $NOTSHDIR/$RWFILE $BASEDIR/syml_nofile
	ln -s $SSPCDIR2 $BASEDIR/syml_sh_fs
	if (( iscipso == 1 )); then
		ln -s $ZONE_PATH/root/usr/lib $BASEDIR/syml_outns
	else
		ln -s /usr/lib $BASEDIR/syml_outns
	fi
	ln -s $NOTSHDIR $BASEDIR/syml_nosh_fs
	ln -s $NOTSHDIR $NOTSHDIR/syml_shnfs

	cd $BASEDIR
	ln -s ./$DIR0755 syml_dotd
	ln -s ./$DIR0755/../$RWFILE syml_dotf
	Last=$(basename $SSPCDIR3)
	ln -s $SSPCDIR3/../$Last syml_dotdot

	# check for correct register on protocols and version 4
	# give some time to nfsd to register protocols
	sleep 1
	rpcinfo -p | grep nfs | awk '{print $2}' | grep 4 \
		> $TMPDIR/rpcinfoT.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "$NAME: ERROR - nfs did not register on $SERVER with v4"
		cat $TMPDIR/rpcinfoT.out.$$
		cleanup 1
	fi

	# also return the server's grace period
	grace=$($CONFIGDIR/get_tunable rfs4_grace_period K 2> $TMPDIR/dmerr.out.$$)
	if (( $? != 0 )); then
		echo "$NAME: ERROR - cannot get grace_period in $SERVER"
		echo "Output was:\n$grace\n"
		echo "Stderr was:"
		cat $TMPDIR/dmerr.out.$$
		cleanup 2
	else
		echo "SERVER_GRACE_PERIOD=$grace"
		[[ $DEBUG != 0 ]] && cat $TMPDIR/dmerr.out.$$
	fi
	# and server's NFS mapid domain
	Sdomain=$(cat /var/run/nfs4_domain 2> $TMPDIR/dmerr.out.$$)
	if (( $? != 0 )); then
		echo "$NAME: ERROR - failed to get NFS mapid domain in $SERVER"
		echo "Output was:\nSdomain=<$Sdomain>\n"
		echo "Stderr was:"
		cat $TMPDIR/dmerr.out.$$
		cleanup 2
	else
		echo "SERVER_NFSmapid_Domain=$Sdomain"
	fi

	echo "Done - setup daemons and shared $BASEDIR OKAY."
	rm -f $CONFIGDIR/._DONE_cleanup_LOFI_for_recovery
	;;

r)
	SHARE_LIST="$SSPCDIR3 $SSPCDIR2 $SSPCDIR $PUBTDIR $QUOTADIR"
	SHARE_LIST="$SHARE_LIST $NSPCDIR $ROFSDIR $ROOTDIR $KRB5DIR"
	for fs in $SHARE_LIST $NOTSHDIR; do
		# unshare FS if is shared, before clean it up
		share | awk '{print $2}' | grep -w "$fs" > /dev/null 2>&1
		if (( $? == 0 )); then
		    $CONFIGDIR/operate_dir "unshare" $fs > \
		        $TMPDIR/unshare.out.$$ 2>&1
		    if (( $? != 0 )); then
		        echo "$NAME: WARNING - failed to unshare [$fs]"
		        cat $TMPDIR/unshare.out.$$
		        echo "\trecovery tests may have problems after \c"
		        echo "rebooting the server"
		    fi
		fi
		if (( TestZFS == 1 )); then
		    Zfs=$(df -h $fs | grep -v 'Mounted on' | nawk '{print $1}')
		    zfs destroy -f -r $Zfs > $TMPDIR/zfsDes.out.$$ 2>&1
		    if (( $? != 0 )); then
		        echo "WARNING, unable to cleanup [$fs];"
		        cat $TMPDIR/zfsDes.out.$$
		        echo "\trecovery tests may have problems \c"
		        echo "after rebooting the server"
		    else
		        rm -fr $fs > /dev/null 2>&1
		    fi
		else
		    $CONFIGDIR/setupFS -c $fs > $TMPDIR/cleanFS.out.$$ 2>&1
		    if (( $? != 0 )); then
		        echo "WARNING, unable to cleanup [$fs];"
		        cat $TMPDIR/cleanFS.out.$$
		        echo "\trecovery tests may have problems \c"
		        echo "after rebooting the server"
		    fi
		fi
	done
	echo "Done - cleanup LOFI/ZFS FS's OKAY."
	touch $CONFIGDIR/._DONE_cleanup_LOFI_for_recovery
	;;

c)
	# restore nfs tunable values
	if [[ -f $CONFIGDIR/$SERVER.nfs.flg ]]; then
		res=$(cat $CONFIGDIR/$SERVER.nfs.flg)
		[[ -n $res ]] && $CONFIGDIR/set_nfstunable $res \
			> $TMPDIR/nfs.out.$$ 2>&1
		if (( $? != 0 )); then
			echo "WARNING: restoring nfs tunable failed on $SERVER:"
			cat $TMPDIR/nfs.out.$$
			echo "Please restore the following nfs tunable manually: $res"
		fi
		rm -f $CONFIGDIR/$SERVER.nfs.flg > /dev/null 2>&1
	fi

	res=$(mv /etc/passwd.orig /etc/passwd 2>&1)
	res=$(mv /etc/group.orig /etc/group 2>&1)
	res=$(chmod 444 /etc/passwd /etc/group 2>&1)
	res=$(pwconv 2>&1)
	res=$(/usr/xpg4/bin/egrep "2345678." /etc/passwd > $TMPDIR/pwerr.out.$$)
	n=$(cat $TMPDIR/pwerr.out.$$ | wc -l | nawk '{print $1}')
	if (( n != 0 )); then
		echo "WARNING: removing test users failed, \
			remove the following users manually:"
		cat $TMPDIR/pwerr.out.$$
		echo "\n"
	fi
	res=$(/usr/xpg4/bin/egrep "2345678." /etc/group > $TMPDIR/grperr.out.$$)
	n=$(cat $TMPDIR/grperr.out.$$ | wc -l | nawk '{print $1}')
	if (( n != 0 )); then
		echo "WARNING: removing test groups failed, \
			remove the following groups manually:"
		cat $TMPDIR/grperr.out.$$
		echo "\n"
	fi

	if [[ ! -f $CONFIGDIR/._DONE_cleanup_LOFI_for_recovery ]]; then
		SHARE_LIST="$SSPCDIR3 $SSPCDIR2 $SSPCDIR $PUBTDIR $QUOTADIR"
		SHARE_LIST="$SHARE_LIST $NSPCDIR $ROFSDIR $ROOTDIR $KRB5DIR"
		for fs in $SHARE_LIST; do
			# need to check if KRB5DIR is shared
			[[ $fs == $KRB5DIR ]] && break
			$CONFIGDIR/operate_dir "unshare" $fs \
				> $TMPDIR/unshare.out.$$ 2>&1
			if (( $? != 0 )); then
				echo "$NAME: ERROR - failed to unshare [$fs]"
				cat $TMPDIR/unshare.out.$$
			fi
		done
		if (( TestZFS == 1 )); then
			for dir in $SHARE_LIST $NOTSHDIR; do
				ZFSn=$(zfs list | grep "$dir" | \
					nawk '{print $1}')
				if [[ -n $ZFSn ]]; then
				    zfs destroy -f -r $ZFSn \
					> $TMPDIR/zfsDes.out.$$ 2>&1
				    if (( $? != 0 )); then
					echo "WARNING, unable to cleanup [$dir]"
					cat $TMPDIR/zfsDes.out.$$
					echo "\t Please clean it up manually."
				    else
					rm -fr $dir
				    fi
				fi
			done
		else
			for dir in $SHARE_LIST $NOTSHDIR; do
				$CONFIGDIR/setupFS -c $dir \
					> $TMPDIR/cleanFS.out.$$ 2>&1
				if (( $? != 0 )); then
					echo "WARNING, unable to cleanup [$dir]"
					cat $TMPDIR/cleanFS.out.$$
					echo "\t Please clean it up manually."
				fi
			done
		fi
	fi

	unshare -p $BASEDIR > $TMPDIR/unshareb.out.$$ 2>&1
	if [[ $? != 0 ]]; then
		echo "$NAME: ERROR - failed to unshare $BASEDIR"
		cat $TMPDIR/unshareb.out.$$
	fi
	smf_fmri_transition_state do $QUOTA_FMRI disabled $SMF_TIMEOUT
	if [[ $? != 0 ]]; then
		echo "$NAME: ERROR - unable to disable $QUOTA_FMRI"
		echo "\t testing in the area may fail."
	fi

	if (( TestZFS == 1 )); then
		destroy_zpool
	fi
	rm -rf $BASEDIR

	echo "Done - cleanup test filesystems/daemons OKAY"
	rm -rf $CONFIGDIR/* $TMPDIR
	exit 0
	;;

\?)
	echo $Usage
	exit 2
	;;
esac

cleanup 0

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
# NFSv4 server name space test - positive tests
#

[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

NAME=`basename $0`
CDIR=`pwd`
NSPC=`echo $NAME | sed 's/./ /g'`

# Source for common functions
. $TESTROOT/testsh

# check for root to run 
is_root $NAME "NFSv4 server namespace share test."

TMPmnt=$ZONE_PATH/$NAME.$$
mkdir -m 0777 -p $TMPmnt
# do not prepend $ZONE_PATH to TMPmnt-2
# It has already been done
TMPmnt2=$TMPmnt-2
mkdir -m 0777 -p $TMPmnt2

doSHDIR=._doShare_Dir_.
DOSHARE=$MNTPTR/$doSHDIR
[[ ! -d $DOSHARE ]] && mkdir -m 0777 -p $DOSHARE

allunsupp=0
is_cipso "vers=4" $SERVER
if [ $? -eq $CIPSO_NFSV4 ]; then
	cipso_check_mntpaths $BASEDIR $TMPmnt
	if [ $? -ne 0 ]; then
		allunsupp=1
		echo "$NAME: UNSUPPORTED"
		echo "$NAME: CIPSO NFSv4 requires non-global zone mount dirs."
		echo "$NSPC  The server's BASEDIR and client's MNTPTR"
		echo "$NSPC  must contain path legs with matching"
		echo "$NSPC  non-global zone paths."
		echo "$NSPC: Please try again ..."
	fi
fi

# Function to to check the DONE file (provided by the "doshare" program in server,
# is available before checking its status
# Usage: ckDone st msg nock_flag
# 	where:	"st" is the status to check
#		"msg" is the message to print after checking the status
#		"nock_flag" is the flag not to check status when provided
function ckDONE
{
    [[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
    st=$1
    msg=$2
    i=0 	# set a time limit as well (1 min)
    while [[ ! -s $DOSHARE/DONE ]] && ((i<20)) 
    do
	((i=i+1))
	sleep 3
    done
    [[ $# == 3 ]] && return $i	# just return if we do not need to check status
    if [[ -s $DOSHARE/DONE ]]; then
	if [[ $st == OK ]]; then
	    grep "$st" $DOSHARE/DONE > /dev/null 2>&1
	else
	    grep "$st" $DOSHARE/DONE | grep "fail" > /dev/null 2>&1
	fi
        ckreturn $? "\"$msg\"" $DOSHARE/DONE
	i=$?
	rm -f $DOSHARE/DONE
    else
	ckreturn $i "\"$msg\"" $DOSHARE/DONE
    fi
    return $i
}

# Function to check for mount/umount of the path & the access to mount point
# Usage: ckMNT_ACC mopt srvp mptr afile umnt
# 	where:	"mopt" is the mount options to be used in mount command
#		"srvp" is the server's path to be used in mount command
#		"mptr" is the client mount point to be used in mount command
#		"afile" is an option to provide a file to check the access
#		"umnt" is the flag to signal if umount (of $mptr) is needed
#			skip umount if "no" is specified
function ckMNT_ACC
{
    [[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
    mopt=$1
    srvp=$2
    mptr=$3
    afile=""
    [[ $# == 4 ]] && afile=$4
    umnt="yes"
    [[ $# == 5 ]] && umnt=$5
    accr=0

    # First mount the server path with the options
    mount -o $mopt $SERVER:$srvp $mptr > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount <$mopt, $SERVER:$srvp> failed" $TMPDIR/$NAME.mnt.$$
    [[ $? != 0 ]] && return $FAIL

    # check the mount point or specified file/dir
    Acc_file=$mptr
    [[ -n $afile ]] && Acc_file=$afile 
    if [[ ! -f $Acc_file ]]; then
	ls -ltaF $Acc_file > $TMPDIR/$NAME.ls-ltaF.$$ 2>&1
	ckreturn $? "ls -ltaF $Acc_file failed" $TMPDIR/$NAME.ls-ltaF.$$
    	accr=$?
    else 	# is a file, open/read it
	cat $Acc_file > $TMPDIR/$NAME.cat.$$ 2>&1
    	ckreturn $? "cat $Acc_file failed" $TMPDIR/$NAME.cat.$$
    	accr=$?
    fi


    if [[ $umnt != no ]]; then
	umount $mptr > $TMPDIR/$NAME.umnt.$$ 2>&1
    	ckreturn $? "umount $mptr FAILed" $TMPDIR/$NAME.umnt.$$
    	[[ $? != 0 ]] && return $FAIL
    fi

    return $accr
}


# Start test assertions here
# ----------------------------------------------------------------------
# a: Server share/unshare a rw'able file, expect succeed
function assertion_a
{
    [[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
    ASSERTION="Server share/unshare a file, expect succeed"
    echo "$NAME{a}: $ASSERTION"
    SRVPATH=$NOTSHDIR/$RWFILE

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $UNSUPPORTED
    fi

    # signal $SERVER to share the file
    echo $SRVPATH > $DOSHARE/share 2> $TMPDIR/$NAME.share.$$
    ckreturn $? "signal server to share" $TMPDIR/$NAME.share.$$ "UNRESOLVED"
    [[ $? != 0 ]] && return $UNRESOLVED
    ckDONE "OK" "share $SRVPATH failed"
    [[ $? != 0 ]] && return $FAIL

    # Test it with mount, access and umount
    ckMNT_ACC "vers=4,rw" $SRVPATH $TMPmnt
    [[ $? != 0 ]] && return $FAIL

    # and finally signal to unshare it from SERVER
    echo "$SRVPATH" > $DOSHARE/unshare 2> $TMPDIR/$NAME.unshare.$$
    ckreturn $? "signal server to unshare" $TMPDIR/$NAME.unshare.$$
    [[ $? != 0 ]] && return $FAIL
    ckDONE "OK" "unshare $SRVPATH failed"
    [[ $? != 0 ]] && return $FAIL

    echo "\t Test PASS"
}


# f: Server share/unshare a file, try mount it w/v3&4, expect succeed
function assertion_f
{
    [[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
    ASSERTION="Server share/unshare a file mount it w/v3&4, expect succeed"
    echo "$NAME{f}: $ASSERTION"
    SRVPATH=$NOTSHDIR/$ROFILE

    # signal $SERVER to share the file
    echo "$SRVPATH" > $DOSHARE/share 2> $TMPDIR/$NAME.share.$$
    ckreturn $? "signal server to share" $TMPDIR/$NAME.share.$$ "UNRESOLVED"
    [[ $? != 0 ]] && return $UNRESOLVED
    ckDONE "OK" "share $SRVPATH failed"
    [[ $? != 0 ]] && return $FAIL

    # Test it with the mount v3 on the $SRVPATH
    ckMNT_ACC "vers=3,rw" $SRVPATH $TMPmnt $TMPmnt "no"
    [[ $? != 0 ]] && return $FAIL

    # Test it with the mount v4 on the $SRVPATH
    ckMNT_ACC "vers=4,rw" $SRVPATH $TMPmnt2 $TMPmnt2 "no"
    [[ $? != 0 ]] && return $FAIL

    # umount both mount points
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount $TMPmnt failed" $TMPDIR/$NAME.umnt.$$
    [[ $? != 0 ]] && return $FAIL
    umount $TMPmnt2 > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount $TMPmnt2 failed" $TMPDIR/$NAME.umnt.$$
    [[ $? != 0 ]] && return $FAIL

    # and finally signal to unshare it from SERVER
    echo "$SRVPATH" > $DOSHARE/unshare 2> $TMPDIR/$NAME.unshare.$$
    ckreturn $? "signal server to unshare" $TMPDIR/$NAME.unshare.$$
    [[ $? != 0 ]] && return $FAIL
    ckDONE "OK" "unshare $SRVPATH failed"
    [[ $? != 0 ]] && return $FAIL

    echo "\t Test PASS"
}

# g: Server share/unshare a file, try mount it w/v4&2, expect succeed
function assertion_g
{
    [[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
    ASSERTION="Server share/unshare a file mount it w/v4&2, expect succeed"
    echo "$NAME{g}: $ASSERTION"
    SRVPATH=$NOTSHDIR/$RWFILE

    is_cipso "vers=2" $SERVER
    if [ $? -eq $CIPSO_NFSV2 ]; then
        echo "$NAME{g}: CIPSO NFSv2 is not supported under Trusted Extensions."
	echo "\t Test UNSUPPORTED"
        return $UNSUPPORTED
    fi

    # signal $SERVER to share the file
    echo "$SRVPATH" > $DOSHARE/share 2> $TMPDIR/$NAME.share.$$
    ckreturn $? "signal server to share" $TMPDIR/$NAME.share.$$ "UNRESOLVED"
    [[ $? != 0 ]] && return $UNRESOLVED
    ckDONE "OK" "share $SRVPATH failed"
    [[ $? != 0 ]] && return $FAIL

    # Test it with the mount v4 on the $SRVPATH
    ckMNT_ACC "vers=4,ro" $SRVPATH $TMPmnt $TMPmnt "no"
    [[ $? != 0 ]] && return $FAIL

    # Test it with the mount v2 on the $SRVPATH
    ckMNT_ACC "vers=2,rw" $SRVPATH $TMPmnt2 $TMPmnt2 "no"
    [[ $? != 0 ]] && return $FAIL

    # umount both mount points
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount $TMPmnt failed" $TMPDIR/$NAME.umnt.$$
    [[ $? != 0 ]] && return $FAIL
    umount $TMPmnt2 > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount $TMPmnt2 failed" $TMPDIR/$NAME.umnt.$$
    [[ $? != 0 ]] && return $FAIL

    # and finally signal to unshare it from SERVER
    echo "$SRVPATH" > $DOSHARE/unshare 2> $TMPDIR/$NAME.unshare.$$
    ckreturn $? "signal server to unshare" $TMPDIR/$NAME.unshare.$$
    [[ $? != 0 ]] && return $FAIL
    ckDONE "OK" "unshare $SRVPATH failed"
    [[ $? != 0 ]] && return $FAIL

    echo "\t Test PASS"
}

# i: Server share dir under shared FS and unshare, expect just fail
function assertion_i
{
    [[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
    ASSERTION="Server share dir under shared FS and unshare, expect fail"
    echo "$NAME{i}: $ASSERTION"
    SRVPATH=$BASEDIR/$DIR0777

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $UNSUPPORTED
    fi

    # signal $SERVER to share the file
    echo "$SRVPATH" > $DOSHARE/share 2> $TMPDIR/$NAME.share.$$
    ckreturn $? "signal server to share" $TMPDIR/$NAME.share.$$ "UNRESOLVED"
    [[ $? != 0 ]] && return $UNRESOLVED
    ckDONE "share" "share $SRVPATH did not fail as expected"
    [[ $? != 0 ]] && return $FAIL

    # try unshare it from SERVER
    echo "$SRVPATH" > $DOSHARE/unshare 2> $TMPDIR/$NAME.unshare.$$
    ckreturn $? "signal server to unshare" $TMPDIR/$NAME.unshare.$$
    [[ $? != 0 ]] && return $FAIL
    ckDONE "unshare" "unshare $SRVPATH did not fail as expected"
    [[ $? != 0 ]] && return $FAIL

    echo "\t Test PASS"
}

# m: Server share/unshare a symlink dir in namespace, expect succeed
function assertion_m
{
    [[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
    ASSERTION="Server share/unshare a symlink dir in namespace, expect succeed"
    echo "$NAME{m}: $ASSERTION"
    SRVPATH=$NOTSHDIR/syml_shnfs

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $UNSUPPORTED
    fi

    # signal $SERVER to share the file
    echo "$SRVPATH" > $DOSHARE/share 2> $TMPDIR/$NAME.share.$$
    ckreturn $? "signal server to share" $TMPDIR/$NAME.share.$$ "UNRESOLVED"
    [[ $? != 0 ]] && return $UNRESOLVED
    ckDONE "OK" "share $SRVPATH failed"
    [[ $? != 0 ]] && return $FAIL

    # Test it with mount, access and umount
    ckMNT_ACC "vers=4,rw" $SRVPATH $TMPmnt $TMPmnt/$DIR0755/dir2
    [[ $? != 0 ]] && return $FAIL

    # and finally signal to unshare it from SERVER
    echo "$SRVPATH" > $DOSHARE/unshare 2> $TMPDIR/$NAME.unshare.$$
    ckreturn $? "signal server to unshare" $TMPDIR/$NAME.unshare.$$
    [[ $? != 0 ]] && return $FAIL
    ckDONE "OK" "unshare $SRVPATH failed"
    [[ $? != 0 ]] && return $FAIL

    echo "\t Test PASS"
}

# n: Server share a symlink outside namespace for client to mount, expect fail
function assertion_n
{
    [[ -n $DEBUG ]] && [ $DEBUG != 0 ] && set -x
    ASSERTION="Server share a symlink outside namespace, client to mount"
    ASSERTION="$ASSERTION, expect fail"
    echo "$NAME{n}: $ASSERTION"
    SRVPATH=$ZONE_PATH/ck_symlink

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $UNSUPPORTED
    fi

    # signal $SERVER to share the file
    echo "$SRVPATH" > $DOSHARE/share 2> $TMPDIR/$NAME.share.$$
    ckreturn $? "signal server to share" $TMPDIR/$NAME.share.$$ "UNRESOLVED"
    [[ $? != 0 ]] && return $UNRESOLVED
    ckDONE "OK" "share $SRVPATH failed"
    [[ $? != 0 ]] && return $FAIL

    # Test it with the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt2 > $TMPDIR/$NAME.mnt.$$ 2>&1
    if [[ $? == 0 ]]; then
	echo "\t Test FAIL: mounting <$SRVPATH> did not fail"
	cat $TMPDIR/$NAME.mnt.$$
	return $FAIL
    fi

    # verify the mount point is not NFS mounted
    df -F nfs $TMPmnt2 > $TMPDIR/$NAME.ck.$$ 2>&1
    if [[ $? == 0 ]]; then
	echo "\t Test FAIL: mount point <$TMPmnt2> should not be NFS"
	cat $TMPDIR/$NAME.ck.$$
	return $FAIL
    fi

    # and finally signal to unshare it from SERVER
    echo "$SRVPATH" > $DOSHARE/unshare 2> $TMPDIR/$NAME.unshare.$$
    ckreturn $? "signal server to unshare" $TMPDIR/$NAME.unshare.$$
    [[ $? != 0 ]] && return $FAIL
    ckDONE "OK" "unshare $SRVPATH failed"
    [[ $? != 0 ]] && return $FAIL

    echo "\t Test PASS"
}


# Start main program here:
# ----------------------------------------------------------------------
# start a doshare program in server for sharing/unsharing
PROG=doshare
rm -f $TMPDIR/$PROG
sed -e "s%_doSHareDir_%$BASEDIR/$doSHDIR%" \
    -e "s%_zonePATH_%$ZONE_PATH%" $PROG > $TMPDIR/$PROG
if [ $? -ne 0 ]; then
	echo "$NAME: can't setup [$PROG] file."
	echo "\t Test UNINITIATED"
	exit $UNINITIATED
fi
rcp $TMPDIR/$PROG $SERVER:$TMPDIR > $TMPDIR/$NAME.rcp.$$ 2>&1
if [[ $? != 0 ]]; then
	echo "$NAME: Test UNINITIATED"
	echo "\t failed to copy $PROG to $SERVER - \c"
	cat $TMPDIR/$NAME.rcp.$$
	exit $OTHER
fi
rsh -n $SERVER "chmod +x ${TMPDIR}/$PROG; ${TMPDIR}/$PROG &" \
	> $TMPDIR/$NAME.rsh.$$ 2>&1 &
sleep 5	
grep $PROG $TMPDIR/$NAME.rsh.$$ | grep running > /dev/null 2>&1
if [[ $? != 0 ]]; then
	echo "$NAME: Test UNINITIATED"
	echo "\t failed to run $PROG at $SERVER - \c"
	cat $TMPDIR/$NAME.rsh.$$
	exit $OTHER
fi

# run all assertions
assertion_a
ret=$?
if [[ $ret != 0 ]] && [[ $ret != $UNSUPPORTED ]]; then
	umount -f $TMPmnt > /dev/null 2>&1
    	echo "$SRVPATH" > $DOSHARE/unshare
	ckDONE "OK" "don't check error" 3
fi

assertion_f
ret=$?
if [[ $ret != 0 ]] && [[ $ret != $UNSUPPORTED ]]; then
	umount -f $TMPmnt > /dev/null 2>&1
	umount -f $TMPmnt2 > /dev/null 2>&1
    	echo "$SRVPATH" > $DOSHARE/unshare 
	ckDONE "OK" "don't check error" 3
fi

assertion_g
ret=$?
if [[ $ret != 0 ]] && [[ $ret != $UNSUPPORTED ]]; then
	umount -f $TMPmnt > /dev/null 2>&1
	umount -f $TMPmnt2 > /dev/null 2>&1
    	echo "$SRVPATH" > $DOSHARE/unshare > /dev/null 2>&1
	ckDONE "OK" "don't check error" 3
fi

assertion_i

assertion_m
[[ $? != 0 ]] && umount -f $TMPmnt > /dev/null 2>&1

assertion_n
[[ $? != 0 ]] && umount -f $TMPmnt2 > /dev/null 2>&1

# cleanup PROG from server
echo "killushare" > $DOSHARE/killushare 2>&1
ckDONE "OK" "don't check error" 3

# cleanup here
rmdir $TMPmnt $TMPmnt2 
rm -f $TMPDIR/$NAME.*.$$ $TMPDIR/$PROG
rm -fr $DOSHARE

exit 0

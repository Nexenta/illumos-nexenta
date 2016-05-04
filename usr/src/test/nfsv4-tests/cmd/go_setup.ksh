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
# Setup server test files/directories, export them, and check
# that NFSv4 is registered.

[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

NAME=$(basename $0)
CDIR=$(dirname $0)
NSPC=$(echo $NAME | sed 's/./ /g')
TMPDIR=${TMPDIR:-"/var/tmp"}
DEBUG=${DEBUG:-"0"}; export DEBUG	# export it for tcl.init

# ================================ include =================================== #
# sourcing framework global environment variables
ENVFILE="./nfs4test.env"
if [[ ! -f $ENVFILE ]]; then
        echo "$NAME: ENVFILE[$ENVFILE] not found;"
        echo "\texit UNINITIATED."
        exit 6
fi
. $ENVFILE

# sourcing support functions
LIBFILE="./testsh"
if [[ ! -f $LIBFILE ]]; then
        echo "$NAME: LIBFILE[$LIBFILE] not found;"
        echo "\texit UNINITIATED."
        exit $UNINITIATED
fi
. $LIBFILE

# check v4config file
V4CFGFILE="./v4test.cfg"
if [[ ! -f $V4CFGFILE ]]; then
        echo "$NAME: V4CFGFILE[$V4CFGFILE] not found;"
        echo "\texit UNINITIATED."
        exit $UNINITIATED
fi
. $V4CFGFILE

# =============================== functions ================================== #
function cleanup { # ensure umount MNTPTR & exit
	[[ -n $DEBUG && $DEBUG != 0 ]] && set -x

	mount -p | grep -w "$MNTPTR" > /dev/null 2>&1
	if (( $? != 0 )); then
		rm -f $TMPDIR/*.$$
        	exit $1
	fi

        # Need to unmount the test directory
        umount $MNTPTR > $TMPDIR/$NAME.umount.$$ 2>&1
        if (( $? != 0 )); then
                echo "$NAME: cleanup - umount $MNTPTR failed"
                cat $TMPDIR/$NAME.umount.$$
	fi

	rm -f $TMPDIR/*.$$
        exit $1
}

# get full name of machine
function get_fullname {
	[[ -n $DEBUG && $DEBUG != 0 ]] && set -x

	typeset mach=$1
	typeset res=$(get_domain $mach "FQDN")

	# if get_domain give no results, use the orginal value.
	[[ -z $res ]] && res=$mach
	echo $res

	ping $res > /dev/null 2>&1
	return $?
}

# ================================= main ===================================== #
# must be root to run
id | grep "0(root)" > /dev/null 2>&1
if (( $? != 0 )); then
        echo "$NAME: Must be root to run this script."
	echo "\texit UNINITIATED."
        exit $UNINITIATED 
fi

# create config dir and config file
CONFIGDIR=$(dirname $CONFIGFILE)
[[ ! -d $CONFIGDIR ]] && mkdir -p $CONFIGDIR
cat > $CONFIGFILE << __EOF__
# Do NOT modify this file directly,
# as it is created and only maintained by $NAME.
#
PATH=/usr/bin:/usr/sbin:/usr/lib/nfs:\$PATH; export PATH
DEBUG=$DEBUG; export DEBUG
CONFIGDIR=$CONFIGDIR; export CONFIGDIR
__EOF__
cat $V4CFGFILE | grep -v "^#" | sed '/^$/d' >> $CONFIGFILE
cat $ENVFILE | grep -v "^#" | sed -e '/^$/d' \
	-e '/^BASEDIR=/d' -e '/^ROOTDIR=/d' -e '/^ROFSDIR=/d' \
	-e '/^NSPCDIR=/d' -e '/^QUOTADIR=/d' -e '/^PUBTDIR=/d' \
	-e '/^KRB5DIR=/d' -e '/^SSPCDIR=/d' -e '/^SSPCDIR2=/d' \
	-e '/^SSPCDIR3=/d' -e '/^NOTSHDIR=/d' >> $CONFIGFILE
cat >> $CONFIGFILE << __EOF__
BASEDIR=$BASEDIR; export BASEDIR
ROOTDIR=$ROOTDIR; export ROOTDIR
ROFSDIR=$ROFSDIR; export ROFSDIR
NSPCDIR=$NSPCDIR; export NSPCDIR
QUOTADIR=$QUOTADIR; export QUOTADIR
PUBTDIR=$PUBTDIR; export PUBTDIR
KRB5DIR=$KRB5DIR; export KRB5DIR
SSPCDIR=$SSPCDIR; export SSPCDIR
SSPCDIR2=$SSPCDIR2; export SSPCDIR2
SSPCDIR3=$SSPCDIR3; export SSPCDIR3
NOTSHDIR=$NOTSHDIR; export NOTSHDIR
__EOF__

# create the tmp directory if it doesn't exist.
DATETAG=$(date +"%y-%m-%d-%H-%M-%S" | sed 's/-//'g)
TMPDIR=$TMPDIR/TMPDIR-nfsv4-$DATETAG 
[[ ! -d $TMPDIR ]] && mkdir -p $TMPDIR
TMPDIR=$TMPDIR; export TMPDIR # export it for tcl.init
echo "TMPDIR=$TMPDIR; export TMPDIR" >> $CONFIGFILE

# create name of LOGDIR, JOURNAL_SETUP, JOURNAL_CLEANUP
#LOGDIR=$LOGDIR/journal.$DATETAG.$(uname -p)
echo "LOGDIR=$LOGDIR; export LOGDIR" >> $CONFIGFILE
JOURNAL_SETUP=$LOGDIR/journal.setup
echo "JOURNAL_SETUP=$JOURNAL_SETUP; export JOURNAL_SETUP"  >> $CONFIGFILE
JOURNAL_CLEANUP=$LOGDIR/journal.cleanup
echo "JOURNAL_CLEANUP=$JOURNAL_CLEANUP; export JOURNAL_CLEANUP" >> $CONFIGFILE

# check the basic env variables - SERVER CLIENT
if [[ -z $SERVER ]]; then
	echo "$NAME: SERVER must be defined."
	echo "\texit UNINITIATED."
	cleanup $UNINITIATED
fi
ping $SERVER > $TMPDIR/ping.out.$$ 2>&1
if (( $? != 0 )); then
	echo "$NAME: SERVER=<$SERVER> not responding."
	echo "\texit UNINITIATED."
	cleanup $UNINITIATED
fi
SERVER=$(get_fullname $SERVER)
if (( $? != 0 )); then
        echo "$NAME: get_fullname for SERVER<$SERVER> failed."
	echo "\texit UNINITIATED."
	cleanup $UNINITIATED
fi
SERVER=$SERVER; export SERVER # export it for tcl.init
echo "SERVER=$SERVER; export SERVER" >> $CONFIGFILE

CLIENT=$(get_fullname $(uname -n))
if (( $? != 0 )); then
        echo "$NAME: get_fullname for CLIENT<$CLIENT> failed."
	echo "\texit UNINITIATED."
	exit $UNINITIATED
fi
echo "CLIENT=$CLIENT; export CLIENT" >> $CONFIGFILE

tUDP=udp
tTCP=tcp
[[ $TRANSPORT == *6 ]] && tUDP=udp6 && tTCP=tcp6

# Solaris NFS server does not support UDP
if [[ $SRVOS == Solaris && $TRANSPORT = @(udp|udp6) ]]; then
	echo "$NAME: SRVOS<$SRVOS> does not support TRANSPORT<$TRANSPORT>\c"
	echo "for NFSv4;"
	echo "\tTesting is terminated."
	cleanup $UNSUPPORTED
fi

# check to support TX
[[ -z $NFSMOPT ]] && TMPNFSMOPT="vers=4" || TMPNFSMOPT=$NFSMOPT
iscipso=0
is_cipso "$TMPNFSMOPT" $SERVER
ret=$?
if (( ret == CIPSO_NFSV2 )); then
	echo "$NAME: CIPSO NFSv2 not supported under Trusted Extensions"
	echo "\texit UNSUPPORTED."
	cleanup $UNSUPPORTED
fi

if (( ret == CIPSO_NFSV4 || ret == CIPSO_NFSV3 )); then
	cipso_check_mntpaths $BASEDIR $MNTPTR
	if (( $? != 0 )); then
        	echo "$NAME: UNSUPPORTED"
		echo "$NAME: CIPSO NFSv4/v3 requires non-global zone mount dirs."
		echo "$NSPC  The server's BASEDIR and client's MNTPTR"
		echo "$NSPC  must contain path legs with matching"
		echo "$NSPC  non-global zone paths."
		echo "$NSPC: Please try again ..."
		cleanup $UNSUPPORTED
	fi
	iscipso=1
fi

# Get the nfsv4shell program over if we do not have it yet
if [[ ! -x $TESTROOT/nfsh || ! -f $TESTROOT/tclprocs ]]; then
	echo "$NAME: ERROR - Can't find nfsv4shell programs from $TESTROOT."
	echo "\tPlease check if <nfsh> and <tclprocs> are installed properly"
	cleanup $UNINITIATED
fi

if (( iscipso == 1 )); then
	ZONENAME=$(echo "$ZONE_PATH" | sed -e 's/\// /g' | awk '{print $2}')
	echo "ZONENAME=$ZONENAME; export ZONENAME" >> $CONFIGFILE
	cp $TESTROOT/nfsh $ZONE_PATH/root/
	cp $TESTROOT/tclprocs $ZONE_PATH/root/
fi

# Create a wrapper to start programs as root
echo '#!/bin/sh -p\nexec $*' > /suexec
chmod 7555 /suexec

# setup the server ... add environment variables to srv_setup script:
rm -f $TMPDIR/setserver
sed -e "s%Tmpdir_from_client%$TMPDIR%" \
	-e "s%ENV_from_client%$(basename $CONFIGFILE)%" \
	-e "s%CONFIGDIR_from_client%$CONFIGDIR%" \
	-e "s%ZONE_PATH_from_client%$ZONE_PATH%" \
	-e "s%SETDEBUG%$SETD%" srv_setup > $TMPDIR/setserver
if (( $? != 0 )); then
        echo "$NAME: can't setup [setserver] file."
        cleanup $UNINITIATED
fi

execute $SERVER root "mkdir -m 0777 -p $TMPDIR $CONFIGDIR" > /dev/null 2>&1

# get test filesystem type from server
scp getTestFSType root@$SERVER:$CONFIGDIR> $TMPDIR/$NAME.rcp.$$ 2>&1
if (( $? != 0 )); then
	echo "$NAME: copying file<getTestFSType> to $SERVER failed:"
	cat $TMPDIR/$NAME.rcp.$$
	cleanup $UNINITIATED
fi

execute $SERVER root \
	"export DEBUG=$DEBUG; \
	/usr/bin/ksh $CONFIGDIR/getTestFSType $BASEDIR" \
	> $TMPDIR/$NAME.rsh.out.$$ 2> $TMPDIR/$NAME.rsh.err.$$
ret=$?
[[ -n $DEBUG && $DEBUG != 0 ]] && cat $TMPDIR/$NAME.rsh.err.$$
grep "^OKAY " $TMPDIR/$NAME.rsh.out.$$ > /dev/null 2>&1
if (( $? != 0 || ret != 0 )); then
	echo "$NAME: execute <getTestFSType> failed on <$SERVER>"
	cat $TMPDIR/$NAME.rsh.out.$$
	cat $TMPDIR/$NAME.rsh.err.$$
	cleanup $UNINITIATED
fi

strfs=$(cat $TMPDIR/$NAME.rsh.out.$$)
fs_type=$(echo $strfs | awk '{print $2}')
if [[ $fs_type == "ufs" ]]; then
	TestZFS=0
elif [[ $fs_type == "zfs" ]]; then
	TestZFS=1
else
	TestZFS=2
fi
if [[ $TestZFS == 2 ]]; then # fs is neither zfs nor ufs
	echo "$NAME: BASEDIR<$BASEDIR> on server<$SERVER> is based $fs_type,"
	echo "\t this test suite only supports UFS and ZFS!"
	cleanup $UNSUPPORTED
fi
if [[ $TestZFS == 1 ]]; then # fs is zfs
	zpool_name=$(echo $strfs | awk '{print $3}')
	ZFSDISK=$zpool_name
	echo "ZFSDISK=$ZFSDISK; export ZFSDISK" >> $CONFIGFILE
	zpool_stat=$(echo $strfs | awk '{print $4}')
	if [[ $zpool_stat != "ONLINE" ]]; then
		echo "$NAME: BASEDIR<$BASEDIR> on server<$SERVER> is based ZFS,"
		echo "\t but zpool<$zpool_name> is not online: $zpool_stat"
		cat $TMPDIR/rsh.out.$$
		cleanup $UNTESTED
	fi
fi
TestZFS=$TestZFS; export TestZFS # export it for tcl.init 
echo "# What type of filesystem will run over: 0-UFS 1-ZFS" >> $CONFIGFILE
echo "TestZFS=$TestZFS; export TestZFS=$TestZFS" >> $CONFIGFILE

# ... now setup the $SERVER
echo "Setting up server [$SERVER] now:"
echo "\ttest filesystem is based <$BASEDIR> and whose fs is <$fs_type>"
echo "\tthis will take a while. Please be patient ..."
# copy server programs over to $SERVER for setup
scp $TMPDIR/setserver ./mk_srvdir ./fillDisk ./setupFS \
	./get_tunable ./set_nfstunable $CONFIGFILE ./libsmf.shlib \
	./operate_dir root@$SERVER:$CONFIGDIR > $TMPDIR/rcp.out.$$ 2>&1
if (( $? != 0 )); then
	echo "$NAME: copying files to $SERVER failed:"
	cat $TMPDIR/rcp.out.$$
	cleanup $OTHER
fi

execute $SERVER root "/usr/bin/ksh $CONFIGDIR/setserver -s" \
	> $TMPDIR/rsh.out.$$ 2>&1
ret=$?
grep "OKAY" $TMPDIR/rsh.out.$$ > /dev/null 2>&1
if (( $? == 0 && ret == 0 )); then
	# If server returned some warning, print it out
	grep "WARNING" $TMPDIR/rsh.out.$$ > /dev/null 2>&1
	if (( $? == 0 )); then
		echo "$NAME: setup $SERVER have warnings:"
		grep WARNING $TMPDIR/rsh.out.$$
	fi
	[[ $DEBUG != 0 ]] && cat $TMPDIR/rsh.out.$$
else
	grep "ERROR" $TMPDIR/rsh.out.$$ > /dev/null 2>&1
	if (( $? == 0 )); then
		echo "$NAME: setup $SERVER had errors:"
	else
		echo "$NAME: setup $SERVER failed:"
	fi
	cat $TMPDIR/rsh.out.$$
	cleanup $OTHER
fi

# Record shared information in journal file for debugging
grep "^SHARE" $TMPDIR/rsh.out.$$

# Save the server's NFS mapid domain
NFSmapid_domain=$(grep "^SERVER_NFSmapid_Domain=" $TMPDIR/rsh.out.$$ |\
	awk -F\= '{print $2}')
if [[ $? != 0 || -z $NFSmapid_domain ]]; then
	echo "$NAME: setup failed:"
	echo "ERROR: could not get SERVER<$SERVER>'s NFS mapid domain"
	grep "^SERVER"  $TMPDIR/rsh.out.$$
	cleanup $OTHER
fi

# check if the nfs tunable values meet the requirement, if not,
# set the new values and save the old values to .nfs.flg file
if [[ ! -f $CONFIGDIR/$CLIENT.nfs.flg ]]; then
    res=$(./set_nfstunable CLIENT_VERSMIN=2 CLIENT_VERSMAX=4 \
	NFSMAPID_DOMAIN=$NFSmapid_domain 2> $TMPDIR/svars.out.$$)
    if (( $? != 0 )); then
	echo "ERROR: cannot set the specific nfs tunable on $CLIENT"
	cat $TMPDIR/svars.out.$$
        echo "\texit UNINITIATED."
        cleanup $UNINITIATED
    else
	[[ -n $res ]] && echo $res > $CONFIGDIR/$CLIENT.nfs.flg
    fi
fi

# Now setup the client
echo "Setting up client [$CLIENT] now."
cp -p /etc/passwd /etc/passwd.orig
cp -p /etc/group /etc/group.orig
# remove users left from setups not cleaned
/usr/xpg4/bin/egrep -v "2345678." /etc/passwd.orig > /etc/passwd 2>&1
/usr/xpg4/bin/egrep -v "2345678." /etc/group.orig > /etc/group 2>&1
# add test users ... should be same as in $SERVER
echo "$TUSER1:x:23456787:10:NFSv4 Test User 1:$TMPDIR:/usr/bin/ksh" \
	>> /etc/passwd
echo "$TUSER2:x:23456788:10:NFSv4 Test User 2:$TMPDIR:/usr/bin/ksh" \
	>> /etc/passwd
echo "$TUSER3:x:23456789:1:NFSv4 Test User 3:$TMPDIR:/usr/bin/ksh" \
	>> /etc/passwd
#except this entry
echo "$TUSERC:x:$TUSERCID:10:NFSv4 Test User Client:$TMPDIR:/usr/bin/ksh" \
	>> /etc/passwd
echo "$TUSERC2:x:$TUSERID:10:NFSv4 Test User Client 2:$TMPDIR:/usr/bin/ksh" \
	>> /etc/passwd
echo "$TUSERC3:x:$TUSERCID3:10:NFSv4 Test User Client 3:$TMPDIR:/usr/bin/ksh" \
	>> /etc/passwd
echo "$UTF8_USR:x:$TUSERUTF8:$TUSERUTF8:uts8 USER 1:$TMPDIR:/sbin/sh" \
	>> /etc/passwd
echo "$UTF8_USR::$TUSERUTF8:" >> /etc/group

pwconv	# make sure shadow file match
N=1
n=$(/usr/xpg4/bin/egrep "2345678." /etc/group | wc -l | nawk '{print $1}')
if (( n != N )); then
        echo "ERROR: "\
	"$NAME: adding test groups failed, groups file shows n=$n not $N"
        cleanup $OTHER
fi
N=6
n=$(/usr/xpg4/bin/egrep \
	"^$TUSER1|^$TUSER2|^$TUSER3|^$TUSERC|^$TUSERC2|^$TUSERC3" \
	/etc/shadow | wc -l | nawk '{print $1}')
if (( n != N )); then
        echo "ERROR: "\
	"$NAME: adding normal test users failed, shadow file shows n=$n not $N"
        cleanup $OTHER
fi

res=$(locale | awk -F= '{print $2}' | grep -v "^$" | grep -v -w "C")
if (( $? == 0 )); then
	echo "WARNING: locale not set to C. Some utf8 tests may fail."
	[[ $DEBUG != 0 ]] && echo "locale = $(locale)\n"
else
	# this test is broken with some locales, so execute only with lang=C
	N=1
	n=$(/usr/xpg4/bin/egrep "^$(echo $UTF8_USR)" /etc/shadow | wc -l | \
		nawk '{print $1}')
	if (( n != N )); then
		echo "ERROR: $NAME: adding UTF8 test users failed, \
			shadow file shows n=$n not $N"
		[[ $DEBUG != 0 ]] && echo "locale = $(locale)\n"
        	cleanup $OTHER
	fi
fi

# NULL $TUSER2's passwd for QUOTA testing:
sed "s/^$TUSER2:x:/$TUSER2::/" /etc/shadow > $TMPDIR/shadow.out.$$
mv $TMPDIR/shadow.out.$$ /etc/shadow
chmod 0400 /etc/shadow

# get server lease time period
$TESTROOT/nfsh $TESTROOT/getleasetm > $TMPDIR/getls.out1.$$ 2>&1
LEASE_TIME=$(egrep "^[0-9]+" $TMPDIR/getls.out1.$$ 2>$TMPDIR/getls.err.$$)
if (( $? != 0 )); then
	# get a default
	LEASE_TIME=90
	grep "ld.so.1: nfsh:" $TMPDIR/getls.out1.$$ \
		grep "No such file" > /dev/null 2>&1
	if (( $? != 0 )); then
		echo "$NAME: UNINITIATED - \c"
		echo "TCL library is NOT installed in client <$CLIENT>"
		echo "nfsv4shell<nfsh> failed to run:"
		echo "  \c"
		cat $TMPDIR/getls.out1.$$
		echo ""
		cleanup $UNINITIATED
	else
		echo "Warning: could not get lease time from server $SERVER:"
		echo "stderr = <$(cat $TMPDIR/getls.err.$$)>"
	fi
fi
rm -f $TMPDIR/getls.*.$$ > /dev/null 2>&1
# check if grace period is different from the lease period
grace=$(grep "^SERVER_GRACE_PERIOD=" $TMPDIR/rsh.out.$$ | awk -F\= '{print $2}')
if [[ $? != 0 || -z $grace ]]; then
	echo "WARNING: could not get $SERVER's grace period"
	echo
	# use same default for grace as for LEASE_TIME (90 seconds)
	grace=90
else
	# use upper case
	typeset -u grace
	# convert from hex to dec
	grace=$(echo "ibase=16\n$grace\n" | bc)
fi
if (( LEASE_TIME != grace )); then
	echo "IMPORTANT WARNING: server $SERVER internal variables modified:"
	echo "\tlease time ($LEASE_TIME) != grace time ($grace)"
	echo "\tit is recommended to set them to the same value,"
	echo "\totherwise some tests may fail. Assuming the largest value"
	(( LEASE_TIME < grace )) && LEASE_TIME=$grace
	echo "\ttrying to prevent failures ($LEASE_TIME seconds)"
fi
echo "LEASE_TIME=$LEASE_TIME; export LEASE_TIME" >> $CONFIGFILE

# mount the server testdir in /mnt;
[[ ! -d $MNTPTR ]] && mkdir -m 777 $MNTPTR > /dev/null 2>&1

# check $SERVER support both tcp and udp
# Trusted Extensions doesn't support CIPSO NFSv4 UDP
is_cipso "vers=4" $SERVER
if (( $? == CIPSO_NOT )); then
	umount -f $MNTPTR >/dev/null 2>&1
	mount -o proto=$tUDP $SERVER:$BASEDIR $MNTPTR \
	    > $TMPDIR/$NAME.mnt.$$ 2>&1
	if (( $? != 0 )); then
		echo "$NAME: UNINITIATED - \c"
		echo "[mount -o proto=$tUDP $SERVER:$BASEDIR $MNTPTR] failed"
		cat $TMPDIR/$NAME.mnt.$$
		cleanup $UNINITIATED
	fi
fi

#Trusted Extensions support CIPSO NFSv3 UDP
is_cipso "vers=3" $SERVER
if (( $? == CIPSO_NFSV3 )); then
        umount -f $MNTPTR >/dev/null 2>&1
        mount -o proto=$tUDP,vers=3 $SERVER:$BASEDIR $MNTPTR \
            > $TMPDIR/$NAME.mnt.$$ 2>&1
        if (( $? != 0 )); then
                echo "$NAME: UNINITIATED - \c"
                echo "[mount -o proto=$tUDP,vers=3 $SERVER:$BASEDIR $MNTPTR]" \
                    "failed"
                cat $TMPDIR/$NAME.mnt.$$
                cleanup $UNINITIATED
        fi
fi

umount -f $MNTPTR >/dev/null 2>&1
mount -o proto=$tTCP $SERVER:$BASEDIR $MNTPTR \
	> $TMPDIR/$NAME.mnt.$$ 2>&1
if (( $? != 0 )); then
        echo "$NAME: UNINITIATED - \c"
	echo "[mount -o proto=$tTCP $SERVER:$BASEDIR $MNTPTR] failed"
        cat $TMPDIR/$NAME.mnt.$$
        cleanup $UNINITIATED
fi

umount -f $MNTPTR >/dev/null 2>&1
mount -F nfs -o $NFSMOPT $SERVER:$BASEDIR $MNTPTR \
	> $TMPDIR/$NAME.mnt.$$ 2>&1
if (( $? != 0 )); then
        echo "$NAME: UNINITIATED - can't mount [$SERVER:$BASEDIR] on [$MNTPTR]"
        cat $TMPDIR/$NAME.mnt.$$
        cleanup $UNINITIATED
fi
[[ -z $NFSMOPT ]] && NFSMOPT="default"
echo "mount [NFSMOPT:$NFSMOPT] [$SERVER:$BASEDIR] on [$MNTPTR] OK"

# Check the grace period as well, just in case
echo "xxx" > $MNTPTR/wait_for_grace
rm -f $MNTPTR/wait_for_grace > /dev/null 2>&1

echo "$NAME: SERVER=$SERVER setup OK!!"
echo "$NAME: CLIENT=$CLIENT ready for testing!!"

# print client and server information
echo "====================== TEST SUITE VERSION =====================" 
grep "^STC_VERSION" ./STC.INFO
echo "====================== CLIENT INFO ============================" 
uname -a; isainfo; domainname; zonename
echo "NFSmapid_domain=$NFSmapid_domain"
echo "====================== MOUNT  INFO ============================" 
nfsstat -m $MNTPTR

echo "====================== SERVER INFO ============================" 
execute $SERVER root "uname -a; isainfo; domainname; zonename"
if [[ $TestZFS == "1" ]]; then
echo "====================== ZFS    INFO ============================" 
	execute $SERVER root "df -lhF zfs"	
else
echo "====================== UFS    INFO ============================" 
	execute $SERVER root "df -lhF ufs"
fi
echo "====================== SHARE  INFO ============================" 
execute $SERVER root "share"

echo "$NAME: PASS"
cleanup $PASS

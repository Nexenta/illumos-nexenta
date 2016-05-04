#! /usr/bin/ksh
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
# Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x


NAME=`basename $0`
CDIR=`pwd`

id | grep "0(root)" > /dev/null 2>&1
if [ $? -ne 0 ]; then
        echo "$NAME: This script require root permission to run."
        exit 99
fi

PATH=/usr/bin:/usr/sbin:$PATH; export PATH
DOSHARE=_doSHareDir_
SHFiles=$DOSHARE/_ShFiles
ZONEPATH=_zonePATH_

if [ "X$ZONEPATH" != "X" ]; then
	ZONEROOT=$ZONEPATH/root
else
	ZONEROOT=""
fi

[ ! -d $DOSHARE ] && mkdir -m 0777 -p $DOSHARE || chmod 0777 $DOSHARE
echo "doshare is now running ..."
> $SHFiles

while :; do
	sleep 2
	# exit if DOSHARE directory is removed from client
	[ ! -d $DOSHARE ] && exit 2
	action=`ls -d $DOSHARE/*are 2>/dev/null | nawk -F\/ '{print $NF}'`
	sleep 2		# allow client writes path to this file on server

	case $action in
	  share)
		spath=`cat $DOSHARE/share`
		echo $spath | grep "ck_symlink" > /dev/null 2>&1
		[ $? -eq 0 ] && ln -s $ZONEROOT/usr/lib $spath
		share $spath > $DOSHARE/DONE 2>&1
		if [ $? -ne 0 ]; then
		    echo "share <$spath> failed." >> $DOSHARE/DONE 2>&1
		else 
		    ckPath=$spath
		    Type=`ls -l $spath | cut -c 1`
		    [ "$Type" = "l" ] && \
			ckPath=`ls -l $spath | awk '{print $NF}'`
		    share | grep "$ckPath" > $DOSHARE/DONE 2>&1
		    if [ $? -ne 0 ]; then
			echo "<$spath> not in share table" >> $DOSHARE/DONE 2>&1
		    else
			echo "share <$spath> OK in `uname -n`" \
				> $DOSHARE/DONE 2>&1
			echo "$spath" >> $SHFiles
			sleep 1		# allow DONE file write to client
		    fi
		fi
		rm -f $DOSHARE/share
		;;
	  unshare)
		spath=`cat $DOSHARE/unshare`
		ckPath=$spath
		Type=`ls -l $spath | cut -c 1`
		[ "$Type" = "l" ] && \
			ckPath=`ls -l $spath | awk '{print $NF}'`
		unshare $ckPath > $DOSHARE/DONE 2>&1
		if [ $? != 0 ]; then
		    echo "unshare <$spath> failed." >> $DOSHARE/DONE 2>&1
		else
		    share | grep "$ckPath" > $DOSHARE/DONE 2>&1
		    if [ $? -eq 0 ]; then
			echo "<$ckPath> is still in share table." \
				>> $DOSHARE/DONE 2>&1
		    else
			echo "unshare <$ckPath> OK in `uname -n`" \
				> $DOSHARE/DONE 2>&1
			sleep 1		# allow DONE file write to client
		    fi
		fi
		echo $spath | grep "ck_symlink" > /dev/null 2>&1
		[ $? -eq 0 ] && rm -f $spath
		rm -f $DOSHARE/unshare
		;;
	  killushare)
		for spath in `sort $SHFiles | uniq`
		do
			unshare $spath > /dev/null 2>&1
		done
		echo "doshare is now killed ..." > $DOSHARE/DONE 2>&1
		exit 0
		;;
	  *)
		continue
		;;

	esac
done

exit 0

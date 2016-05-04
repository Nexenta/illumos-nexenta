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
# A script to kill and restart nfsd upon request

[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

. $TESTROOT/libsmf.sh

NAME=$(basename $0)

id | grep "0(root)" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
        echo "$NAME: Must have root permission to run this script"
        exit 99
fi

PATH=/usr/bin:/usr/sbin:$PATH
export PATH

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
CONFIGFILE=/var/tmp/nfsv4/config/config.suite
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

NOTICEDIR=$TMPDIR/.libmapid
[[ ! -d $NOTICEDIR ]] && mkdir -m 0777 -p $NOTICEDIR || chmod 0777 $NOTICEDIR

trap 'cd $NOTICEDIR; rm -f nfsd* DONE* *.$$; exit 99' 2 3 9

while true; do 
	sleep 2
	action=`ls -d $NOTICEDIR/libmapid* 2>/dev/null | nawk -F\/ '{print $NF}'`
	
	case $action in 

	   libmapid_modify_nfscfg)
		rm -f $NOTICEDIR/DONE

		cp /etc/default/nfs $TMPDIR/etc.default.nfs.$$.orig \
		    && sed '/NFSMAPID_DOMAIN/d' /etc/default/nfs \
			> $TMPDIR/etc.default.nfs.$$.temp \
		    && mv $TMPDIR/etc.default.nfs.$$.temp /etc/default/nfs \
		    && echo "NFSMAPID_DOMAIN=libmapid.test.domain" >> /etc/default/nfs
		if [[ $? -eq 0 ]]; then
			echo "Modify /etc/default/nfs ... OK" >  $NOTICEDIR/DONE
		else
		        echo "Modify /etc/default/nfs ... FAILED" > $NOTICEDIR/DONE
		fi

		rm -f $NOTICEDIR/libmapid_modify_nfscfg 
		;;

	   libmapid_restore_nfscfg)
		rm -f $NOTICEDIR/DONE

		mv $TMPDIR/etc.default.nfs.$$.orig /etc/default/nfs
		if [[ $? -eq 0 ]]; then
			echo "Restore /etc/default/nfs...OK">$NOTICEDIR/DONE
		else
			echo "Restore /etc/default/nfs...FAILED">$NOTICEDIR/DONE
		fi

		rm -f $NOTICEDIR/libmapid_restore_nfscfg 
		;;

	   libmapid_start_dns)
		rm -f $NOTICEDIR/DONE
		
                smf_fmri_transition_state \
                    do svc:/network/dns/server:default online 120 
		if [ $? -eq 0 ]; then
			echo "Start DNS...OK" > $NOTICEDIR/DONE
		else
			echo "Start DNS...FAILED" > $NOTICEDIR/DONE
		fi

	 	rm -f $NOTICEDIR/libmapid_start_dns
		;;
		
	   libmapid_shutdown_dns)
		rm -f $NOTICEDIR/DONE
		
                smf_fmri_transition_state \
                    do svc:/network/dns/server:default disabled 120 
		if [[ $? -eq 0 ]]; then
			echo "Shutdown DNS...OK" > $NOTICEDIR/DONE
		else
			echo "Shutdown DNS...FAILED" > $NOTICEDIR/DONE
		fi

	 	rm -f $NOTICEDIR/libmapid_shutdown_dns
		;;

	   libmapid_quit)
		rm -rf $NOTICEDIR;
		break;;

	   *)
		continue;;
	esac
done
exit 0

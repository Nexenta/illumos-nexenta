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
# ident	"@(#)zones_common.ksh	1.5	09/08/23 SMI"
#

#
# Common functions to create and work with zones.
#

unset GZONEINTERFACE
unset GZONEDEVICE
unset LZONEINTERFACE
ZONECFGFILE=$SHR_TMPDIR/share_tests_zonecfg.file
ZONELOGFILE=$SHR_TMPDIR/share_tests_zonecfg.log
ZONETMPFILE=$SHR_TMPDIR/share_tests_zone.tmp

#
# NAME
#	zone_boot
#
# DESCRIPTION
#	Boot the zone and monitor the zone to make sure all smf 
#	functions have started.  Need to do the check twice to 
#	make sure that if the system reboots do to init state 
#	changes from the first boot after install, the system 
#	handles this properly.
#
function zone_boot {
	typeset zb_zone_name=$1

	$ZONEADM -z $zb_zone_name boot > $ZONELOGFILE 2>&1
	if (( $? != 0 )); then
		cti_reportfile $ZONELOGFILE "zone<$zb_zone_name> boot failed"
		return 1
	fi

	typeset -i zb_zone_booted=0
	typeset -i zb_zone_sendm=0
	while (( $zb_zone_booted < 120 )); do
		#
		# Give the zone a second to get some work done and then
		# check.
		#
		sleep 5
		#
		# Disable sendmail (but only do it once) to save some
		# time on the zone boot.  This can be removed and
		# use of the exclude package when 4963323 rfe is
		# applied.
		#
		if (( $zb_zone_sendm == 0 )); then
			$ZLOGIN $zb_zone_name /usr/sbin/svcadm \
			    disable sendmail > /dev/null 2>&1
			(( $? == 0 )) && zb_zone_sendm=1
		fi
		zlogin $zb_zone_name /bin/svcs multi-user > $ZONETMPFILE 2>&1
		grep online $ZONETMPFILE > /dev/null 2>&1
		if (( $? == 0 )); then
			#
			# Sleep for a bit to make sure we are not in the
			# middle of a reboot, before attempting to get the
			# second status.
			#
			sleep 5
			return 0
		else
			zb_zone_booted=$((zb_zone_booted + 1))
		fi
	done

	cti_reportfile $ZONETMPFILE \
		"timed out<10 minutes>: multi-user has not been online"
	return 1
}

#
# NAME
#	zones_min_setup
#
# DESCRIPTION
#	Create a file system with minimal setup.  No additional file systems
#	or networks configured.
#
function zones_min_setup {
	typeset zms_zone_name=$1
	typeset zms_zone_path=$2

	if [[ $TET_ZONE_LEAVE == True ]]; then
		$ZONEADM -z $zms_zone_name list > /dev/null 2>&1
		if (( $? == 0 )); then
			zone_boot $zms_zone_name
			return $?
		fi
	fi

	tet_infoline "Setting up a minimal zone to test sharemgr"

	# set perms on the paths
	tet_infoline " - $CHMOD 700 $zms_zone_path"
	$CHMOD 700 $zms_zone_path > $ZONELOGFILE 2>&1
	if (( $? != 0 )); then
		cti_reportfile $ZONELOGFILE "chmod $zms_zone_path failed"
		return 1
	fi
	typeset ppath=$(dirname $zms_zone_path)
	tet_infoline " - $CHMOD 755 $ppath"
	$CHMOD 755 $ppath > $ZONELOGFILE 2>&1
	if (( $? != 0 )); then
		cti_reportfile $ZONELOGFILE "chmod $ppath failed"
		return 1
	fi

	# Create the config file
	$CAT << __EOF__ > $ZONECFGFILE
create
set zonepath=$zms_zone_path
set autoboot=false
commit
__EOF__

	tet_infoline " Creating zone using following config file:"
	infofile "  " $ZONECFGFILE
	# Call zonecfg and check if the zone is configured as expected
	tet_infoline " - $ZONECFG -z $zms_zone_name -f $ZONECFGFILE"
	$ZONECFG -z $zms_zone_name -f $ZONECFGFILE > $ZONELOGFILE 2>&1
	if (( $? != 0 )); then
		cti_reportfile $ZONELOGFILE "zonecfg $zms_zone_name failed"
		return 1
	fi
	$ZONECFG -z $zms_zone_name verify >> $ZONELOGFILE 2>&1
	if (( $? != 0 )); then
		cti_reportfile $ZONELOGFILE \
			"wrong in the configuration of zone $zms_zone_name"
		return 1
	fi
	$ZONEADM -z $zms_zone_name list -p >> $ZONELOGFILE 2>&1
	typeset cur_stat=$(tail -1 $ZONELOGFILE | awk -F: '{print $3}')
	if (( $? != 0 )) || [[ $cur_stat != configured ]]; then
		cti_reportfile $ZONELOGFILE \
			"wrong state: expect <configured> but got <$cur_stat>"
		return 1
	fi

	# Call zone install and check if the zone is installed as expected
	tet_infoline " - $ZONEADM -z $zms_zone_name install"
	$ZONEADM -z $zms_zone_name install > $ZONELOGFILE 2>&1 &
	typeset -i zi_ret=$? zi_pid=$!
	pgrep zoneadm | grep -w $zi_pid > /dev/null 2>&1
	if (( $? != 0 || $zi_ret != 0 )); then
		cti_reportfile $ZONELOGFILE "install zone $zms_zone_name failed"
		return 1
	fi
	wait_now 3600 "! pgrep zoneadm | grep -w $zi_pid > /dev/null 2>&1" 60
	if (( $? != 0 )); then
		cti_reportfile $ZONELOGFILE \
		    "timed out<1 hour>: install zone<$zms_zone_name> failed"
		tet_infoline "please have a check and do cleanup manually"
		kill -9 $zi_pid
		return 1
	fi
	$ZONEADM -z $zms_zone_name list -p >> $ZONELOGFILE 2>&1
	cur_stat=$(tail -1 $ZONELOGFILE | awk -F: '{print $3}')
	if (( $? != 0 )) || [[ $cur_stat != installed ]]; then
		cti_reportfile $ZONELOGFILE \
			"wrong state: expect <installed> but got <$cur_stat>"
		return 1
	fi

	# Call zone ready and check if the zone is ready as expected
	# this step is must for opensolaris
	tet_infoline " - $ZONEADM -z $zms_zone_name ready"
	$ZONEADM -z $zms_zone_name ready > $ZONELOGFILE 2>&1
	if (( $? != 0 )); then
		cti_reportfile $ZONELOGFILE "ready zone $zms_zone_name failed"
		return 1
	fi
	$ZONEADM -z $zms_zone_name list -p >> $ZONELOGFILE 2>&1
	cur_stat=$(tail -1 $ZONELOGFILE | awk -F: '{print $3}')
	if (( $? != 0 )) || [[ $cur_stat != ready ]]; then
		cti_reportfile $ZONELOGFILE \
			"wrong state: expect <ready> but got <$cur_stat>"
		return 1
	fi

	# Setup the sysidcfg
	zms_sysidcfg="$zms_zone_path/root/etc/sysidcfg"
	zms_password=`$GREP "root:" /etc/shadow | $AWK -F':' '{print $2}'`
	echo "system_locale=C" > $zms_sysidcfg 2>$ZONELOGFILE
	if (( $? != 0 )); then
		cti_reportfile $ZONELOGFILE "create file $zms_sysidcfg failed"
		return 1
	fi
	echo "terminal=xterm" >> $zms_sysidcfg
	echo "network_interface=none {" >> $zms_sysidcfg
	echo "hostname=$zms_zone_name" >> $zms_sysidcfg
	echo "}" >> $zms_sysidcfg
	echo "name_service=NONE" >> $zms_sysidcfg
	# here set fixed root password to sysidcfg for now until bug 6863728
	# is fixed
	echo "root_password=wqm70K1OlX8Xk" >> $zms_sysidcfg
	echo "security_policy=NONE" >> $zms_sysidcfg
	echo "timezone=$TZ" >> $zms_sysidcfg
	echo "nfs4_domain=dynamic" >> $zms_sysidcfg

	# Call zone boot and check if the zone is running
	tet_infoline " - $ZONEADM -z $zms_zone_name boot"
	zone_boot $zms_zone_name
	if (( $? != 0 )); then
		tet_infoline "boot zone<$zms_zone_name> failed"
		return 1
	fi
	$ZONEADM -z $zms_zone_name list -p >> $ZONELOGFILE 2>&1
	cur_stat=$(tail -1 $ZONELOGFILE | awk -F: '{print $3}')
	if (( $? != 0 )) || [[ $cur_stat != running ]]; then
		cti_reportfile $ZONELOGFILE \
			"wrong state: expect <running> but got <$cur_stat>"
		return 1
	fi

	# Install sharemgr
	tet_infoline " - $CP $SHAREMGR $zms_zone_path/root"
	$CP $SHAREMGR $zms_zone_path/root > $ZONELOGFILE 2>&1
	if (( $? != 0 )); then
		cti_reportfile $ZONELOGFILE \
			"cp $SHAREMGR $zms_zone_path/root failed"
		return 1
	fi

	return 0
}

#
# NAME
#	zones_min_cleanup
#
# DESCRIPTION
#	Remove the minimum zone created in the zones_min_setup() function.
#
function zones_min_cleanup {
	zmc_zone_name=$1
	zmc_zone_path=$2

	if [[ $TET_ZONE_LEAVE == True ]]; then
		$ZONEADM -z $zmc_zone_name halt > $ZONELOGFILE 2>&1
		return
	fi

	tet_infoline "Cleaning up a minimal zone to test sharemgr"

	# Call halt of zone
	tet_infoline " - $ZONEADM -z $zmc_zone_name halt"
	$ZONEADM -z $zmc_zone_name halt > $ZONELOGFILE 2>&1
	typeset -i zc_ret=$?

	# Call uninstall of zone
	tet_infoline " - $ZONEADM -z $zmc_zone_name uninstall -F"
	$ZONEADM -z $zmc_zone_name uninstall -F >> $ZONELOGFILE 2>&1
	zc_ret=$((zc_ret + $?))

	# Remove the zone
	tet_infoline " - $ZONECFG -z $zmc_zone_name delete -F"
	$ZONECFG -z $zmc_zone_name delete -F >> $ZONELOGFILE 2>&1
	zc_ret=$((zc_ret + $?))
	(( $zc_ret != 0 )) && cti_reportfile $ZONELOGFILE \
		"WARNING: find error during zone cleanup"

	$RM -rf $zmc_zone_path > /dev/null 2>&1

	[[ -n $GZONEDEVICE ]] && $IFCONFIG $GZONEDEVICE unplumb
}

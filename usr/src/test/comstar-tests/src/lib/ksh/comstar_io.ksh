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

DISKOMIZER=/opt/SUNWstc-diskomizer/bin/diskomizer

FC_DISKOMIZER_STDOUT=/var/tmp/disko_fc.stdout
FC_DISKOMIZER_STDERR=/var/tmp/disko_fc.stderr
FC_DISKOMIZER_CFG=${CTI_SUITE}/config/fc_disko.cfg

FCOE_DISKOMIZER_STDOUT=/var/tmp/disko_fcoe.stdout
FCOE_DISKOMIZER_STDERR=/var/tmp/disko_fcoe.stderr
FCOE_DISKOMIZER_CFG=${CTI_SUITE}/config/fcoe_disko.cfg

ISCSI_DISKOMIZER_STDOUT=/var/tmp/disko_iscsi.stdout
ISCSI_DISKOMIZER_STDERR=/var/tmp/disko_iscsi.stderr
ISCSI_DISKOMIZER_CFG=${CTI_SUITE}/config/iscsi_disko.cfg

if [ "$TARGET_TYPE" = "FC" ];then
	DISKOMIZER_STDOUT=$FC_DISKOMIZER_STDOUT
	DISKOMIZER_STDERR=$FC_DISKOMIZER_STDERR
elif [ "$TARGET_TYPE" = "FCOE" ];then
	DISKOMIZER_STDOUT=$FCOE_DISKOMIZER_STDOUT
	DISKOMIZER_STDERR=$FCOE_DISKOMIZER_STDERR
elif [ "$TARGET_TYPE" = "ISCSI" ];then
	DISKOMIZER_STDOUT=$ISCSI_DISKOMIZER_STDOUT
	DISKOMIZER_STDERR=$ISCSI_DISKOMIZER_STDERR
else
	cti_unresolved "WARNING - un-defined variable TARGET_TYPE:"\
	    "$TARGET_TYPE. Please re-configure the configuration file"
fi

# NAME
#       check_disko_pkg
#
# DESCRIPTION
#       Determine if diskomizer has been installed.
#       If not installed exit test.
#
# ARGUMENT
#       $1 - HOSTNAME
#
# RETURN
#	0 - the diskomizer pkg is installed.
#	1 - the diskomizer pkg is not installed.
#
function check_disko_pkg
{
	typeset HOSTNAME=$1
	cti_report "Check $DISKOMIZER installed"
	run_rsh_cmd $HOSTNAME "$LS $DISKOMIZER"
	if [ `get_cmd_retval` -ne 0 ] ; then
		cti_fail "FAIL - $HOSTNAME: $DISKOMIZER utility " \
			"is not installed."
		return 1
	fi
	return 0
}

#
# NAME
#       start_disko
#
# DESCRIPTION
#       Start a diskomizer run.  global LUNLIST is used by this routine
#
# ARGUMENT
#       $1 - HOSTNAME
#
# RETURN
#	0 - no errors were encountered during diskomizer run.
#	1 - errors were encountered during diskomizer run.
#
function start_disko
{
	typeset HOSTNAME=$1
	check_disko_pkg $HOSTNAME
	if [ $? -ne 0 ];then
		return 1
	fi
	if [ "$TARGET_TYPE" = "FC" ];then
		typeset TMP_CFG=$FC_DISKOMIZER_CFG
		host_reboot $HOSTNAME -r		
		list_disko_fc_lun $HOSTNAME
	elif [ "$TARGET_TYPE" = "FCOE" ];then
		typeset TMP_CFG=$FCOE_DISKOMIZER_CFG
		host_reboot $HOSTNAME 
		list_disko_fc_lun $HOSTNAME
	elif [ "$TARGET_TYPE" = "ISCSI" ];then
		typeset TMP_CFG=$ISCSI_DISKOMIZER_CFG
		list_disko_iscsi_lun $HOSTNAME
	else
		cti_unresolved "WARNING - un-defined variable TARGET_TYPE:"\
		    "$TARGET_TYPE. Please re-configure the configuration file"
	fi
	typeset CFG_FILE=`basename $TMP_CFG`
	cp $TMP_CFG $LOGDIR
	chmod 644 $LOGDIR/$CFG_FILE
	cti_appendfile $LOGDIR/$CFG_FILE 1 "DEVICE= \\"
	if [ -n "$LUNLIST" ];then
		for lun in $LUNLIST
		do
			fs_verify_label $HOSTNAME $lun
			if [ $? -ne 0 ];then
				cti_fail "FAIL - Skip running diskomizer "\
					"with LU $lun label error"
				NO_IO=0
			else
				cti_appendfile $LOGDIR/$CFG_FILE 1 "$lun \\"
			fi
		done
		TMP_CFG=/var/tmp/$CFG_FILE
		typeset cmd="test -f $TMP_CFG"
		cmd="$cmd & rm -rf $TMP_CFG" 
		run_rsh_cmd $HOSTNAME "$cmd"
		scp $LOGDIR/$CFG_FILE root@$HOSTNAME:/var/tmp

		cti_report "Start diskomizer on $HOSTNAME"

		typeset r_cmd="$DISKOMIZER"
		r_cmd="$r_cmd -f $TMP_CFG"
		r_cmd="$r_cmd > $DISKOMIZER_STDOUT"
		r_cmd="$r_cmd 2> $DISKOMIZER_STDERR"


		run_rsh_cmd $HOSTNAME "$r_cmd" >/dev/null 2>&1 &

		sleep 30  
		cmd="ps -ef | grep -v grep | grep -c diskomizer"
		run_rsh_cmd $HOSTNAME "$cmd"
		typeset proc_num=`get_cmd_stdout`
		if [ $proc_num -eq 0 ] ; then
			cti_fail "FAIL - $HOSTNAME : "\
				"Start diskomizer failed: process not found"
			report_err "$cmd"
			NO_IO=0
			return 1
		fi
	else
		cti_fail "FAIL - $HOSTNAME : Start diskomizer failed: "\
			"device not found"
		NO_IO=0
		return 1
	fi
	NO_IO=1
	return 0

}

#
# NAME
#       stop_disko
#
# DESCRIPTION
#       function to kill existing diskomizer processes.
#
# ARGUMENT
#       $1 - HOSTNAME
#
# RETURN
#	0 - the diskomizer PID was successfully killed.
#	1 - failed to kill the diskomizer process.
#
function stop_disko
{
        typeset HOSTNAME=$1
        cti_report "Stop diskomizer on $HOSTNAME"
	typeset r_cmd="ps -ef | grep -v grep | grep diskomizer"
	r_cmd="$r_cmd | awk '{print \$2}' | while read pid;"
	r_cmd="$r_cmd do /usr/bin/kill -9 \$pid; done"
	run_rsh_cmd $HOSTNAME  "$r_cmd"
        sleep 150		

        typeset cmd="ps -ef | grep -v grep | grep diskomizer"
        run_rsh_cmd $HOSTNAME "$cmd"
        
	cti_report "INFO - diskomizer stdout and stderr are stored at $LOGDIR_TCCDLOG"
	scp root@$HOSTNAME:$DISKOMIZER_STDERR \
		$LOGDIR_TCCDLOG/`basename \
		${DISKOMIZER_STDERR}`.${HOSTNAME}.${tc_id} >/dev/null 2>&1
	scp root@$HOSTNAME:$DISKOMIZER_STDOUT \
		$LOGDIR_TCCDLOG/`basename \
		${DISKOMIZER_STDOUT}`.${HOSTNAME}.${tc_id} >/dev/null 2>&1
       
        typeset proc_num=`get_cmd_stdout | grep -c diskomizer`
	if [ $proc_num -eq 0 ];then
		return 0
	fi	

	cti_report "Stop diskomizer on $HOSTNAME again"
	typeset r_cmd="ps -ef | grep -v grep | grep diskomizer"
	r_cmd="$r_cmd | awk '{print \$2}' | while read pid;"
	r_cmd="$r_cmd do /usr/bin/kill -9 \$pid; done"
	run_rsh_cmd $HOSTNAME  "$r_cmd"

        sleep 5
        typeset proc_num=`get_cmd_stdout | grep -c diskomizer`
        if [ $proc_num -ne 0 ];then
                cti_reportfile $CMD_STDOUT "Defunct diskomizer Process List"
                cti_fail "FAIL - $HOSTNAME : Stop diskomizer failed"
                return 1
        fi
        return 0

}

#
# NAME
#       list_disko_fc_lun
#
# DESCRIPTION
#       function to get the list of devices of fc target to
#       run diskomizer.
#
# ARGUMENT
#       $1 - HOSTNAME
#
# RETURN
#	0 - device list obtained and echoed. 
#	1 - failed to obtain device list.
#
function list_disko_fc_lun
{
	typeset HOSTNAME=$1
	cti_report "Check the fc lun list on host $HOSTNAME"

	# leadville bug to trigger the discovery start
	leadville_bug_trigger $HOSTNAME
	# trigger end

	typeset cmd="/usr/sbin/luxadm probe"
	run_rsh_cmd $HOSTNAME "$cmd"
	typeset lun_num=`get_cmd_stdout | grep Logical |grep -c dsk`
	if [ $lun_num -eq 0 ] ; then
		cti_fail "FAIL - $HOSTNAME : fail to get LUN LIST"
		report_err "$cmd"
		return 1
	else		
		LUNLIST=`get_cmd_stdout | grep Logical |grep dsk | cut -f 2 -d: | sort -u` 
		set -A tmp_lunlist `echo $LUNLIST`
		typeset -i exist_num=${#tmp_lunlist[@]}
		if [  $exist_num -ne $VOL_MAX ];then
			cti_report "WARNING - $HOSTNAME: fail to get $VOL_MAX LUNs"\
				"with only $exist_num LUNs available"
			return 1
		else
			cti_report "INFO - $HOSTNAME : "\
				"to run diskomizer on $exist_num LUNs"
		fi
	
		return 0
	fi
}

#
# NAME
#       list_disko_iscsi_lun
#
# DESCRIPTION
#       function to get the list of devices of iscsi target to
#       run diskomizer.
#
# ARGUMENT
#       $1 - HOSTNAME
#
# RETURN
#	0 - device list obtained and echoed. 
#	1 - failed to obtain device list.
#
function list_disko_iscsi_lun
{
	typeset HOSTNAME=$1
	cti_report "Check the iscsi lun list on host $HOSTNAME"

	typeset cmd="$DEVFSADM -Ci iscsi"
	cti_report "Executing: $cmd on $HOSTNAME"
	run_rsh_cmd $HOSTNAME "$cmd"
	
	#devlink generator needs a couple seconds
	sleep 60
	
	# if the initiator is mpxio_disabled, I/O running should be
	# run through only one of the target ports and portals
	check_enable_mpxio $HOSTNAME
	if [ $? -eq 0 ];then
		cmd="$ISCSIADM list target -S"
		run_rsh_cmd $HOSTNAME "$cmd"
	else
		# iscsi multipath is based on portal and target port
		G_TARGET=`echo $G_TARGET|grep iqn`
		set -A g_targets $G_TARGET
		cmd="$ISCSIADM list target -S ${g_targets[0]}"
		run_rsh_cmd $HOSTNAME "$cmd"
		typeset firstnullpos=`get_cmd_stdout | sed -n "/^ *$/=" | head -1`
		if [ -n "$firstnullpos" ];then
			get_cmd_stdout | sed -n "1,${firstnullpos}p" \
			    >$LOGDIR/mpxio_disable.lun
			cp $LOGDIR/mpxio_disable.lun $CMD_STDOUT
		fi
	fi
	typeset lun_num=`get_cmd_stdout | grep Device | awk '{print $NF}' | sort -u | grep -c dsk`
	if [ $lun_num -eq 0 ] ; then
		cti_fail "FAIL - $HOSTNAME : fail to get LUN LIST"
		report_err "$cmd"
		return 1
	else		
		LUNLIST=`get_cmd_stdout | grep Device | awk '{print $NF}' | sort -u` 
		set -A tmp_lunlist `echo $LUNLIST`
		typeset -i exist_num=${#tmp_lunlist[@]}
		if [ "$DEV_TYPE" = "B" ];then
			set -A bdevs $BDEVS
			typeset vol_max=${#bdevs[@]}
		elif [ "$DEV_TYPE" = "R" ];then
			set -A rdevs $RDEVS
			typeset vol_max=${#rdevs[@]}
		else
			typeset vol_max=$VOL_MAX
		fi
		if [  $exist_num -ne $vol_max ];then
			cti_report "WARNING - $HOSTNAME: fail to get $vol_max LUNs"\
				"with only $exist_num LUNs available"
			return 1
		else
			cti_report "INFO - $HOSTNAME : "\
				"to run diskomizer on $exist_num LUNs"
		fi
	
		return 0
	fi
}
#
# NAME
#       verify_disko
#
# DESCRIPTION
#       verify the diskomizer run with errors
#
# ARGUMENT
#       $1 - HOSTNAME
#
# RETURN
#	0 - no errors
#	1 - error message found
#
function verify_disko
{
	
	typeset HOSTNAME=$1
	run_rsh_cmd $HOSTNAME " test -s $DISKOMIZER_STDERR "
	if [ `get_cmd_retval` -eq 0 ]; then

		typeset cmd="egrep 'Diffs file dumped' $DISKOMIZER_STDERR"
		cmd="$cmd | cut -d ' ' -f8 |head -1"                           
		run_rsh_cmd $HOSTNAME "$cmd"               
		typeset diffs_file=`get_cmd_stdout`
		typeset diffs_disko=$LOGDIR_TCCDLOG/diffs_disko.${tc_id}

		if [ -n "$diffs_file" ];then
			scp root@$HOSTNAME:$diffs_file $diffs_disko
			if [ -s $diffs_disko ] ; then
				cti_report "INFO - diffs file was copied to : "\
					"$diffs_disko from host $HOSTNAME"
			fi
		fi
				
		cmd="egrep \"error opening|corruption detected|no devices\" $DISKOMIZER_STDERR"
		ssh $HOSTNAME "$cmd"
		if [ $? -eq 0 ]; then
			cti_fail "FAIL - $HOSTNAME : diskomizer report error"
			cti_fail "FAIL - $HOSTNAME : see $DISKOMIZER_STDERR"
			return 1
		fi		
	fi
	typeset cmd="rm -rf $DISKOMIZER_STDOUT $DISKOMIZER_STDERR"
	run_rsh_cmd $HOSTNAME "$cmd"
	return 0
}



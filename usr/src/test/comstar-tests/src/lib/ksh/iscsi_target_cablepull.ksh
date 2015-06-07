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

#
#
# NAME
#       iscsi_target_portal_up_down_io
# DESCRIPTION
#       iscsi target cable pull tests with plumb/un-plumb target portal and
#	diskomizer I/O
#
# ARGUMENT
#       $1 - target host
#       $2 - the seconds of target portal up/down intervals
#       $3 - test rounds for target portal up/down
#
# RETURN
#       1 failed
#       0 successful
#
function iscsi_target_portal_up_down_io
{
	typeset host_name=$1
	typeset intervals=$2
	typeset max_iter=$3
	cti_report "Start target side cable pull with"\
	    "ifconfig plumb/un-plumb tests on host $host_name."
	
	typeset portal_list=$(get_portal_list $host_name)
	cti_report "INFO - $host_name is being used by test suite"\
	    "for rlogin, skip the up/down operation"
	portal_list=$(echo "$portal_list" | sed -e "s/$host_name//g")
	typeset t_portal
	typeset iter=1
	while [ $iter -le $max_iter ]	
	do
		cti_report "Executing: running target portal up - down to"\
		    "verify failover with $iter round"\
		    "and $intervals intervals"
		for t_portal in $portal_list
		do
	
			ifconfig_down_portal $host_name $t_portal
			cti_report "sleep $intervals intervals after un-plumb target portal"
			sleep $intervals

			ifconfig_up_portal $host_name $t_portal
			cti_report "sleep $intervals intervals after plumb target portal"
			sleep $intervals
		done
		(( iter+=1 ))
	done
}

#
# NAME
#       iscsi_target_port_online_offline_io
# DESCRIPTION
#       iscsi target cable pull tests with online/offline target node and
#	diskomizer I/O
#
# ARGUMENT
#       $1 - target host
#       $2 - the seconds of target port online/offline intervals
#       $3 - test rounds for target port online/offline
#
# RETURN
#       1 failed
#       0 successful
#
function iscsi_target_port_online_offline_io
{
	typeset host_name=$1
	typeset intervals=$2
	typeset max_iter=$3
	cti_report "Start host side cable pull with"\
		"stmfadm online/offline tests on host $host_name."
	
	typeset iter=1
	typeset t_target
	while [ $iter -le $max_iter ]	
	do
		cti_report "Executing: running target portal offline - online"\
		    "to verify failover with $iter round and $intervals intervals"
		for t_target in $G_TARGET
		do
		
			typeset cmd="$STMFADM offline-target $t_target"
			cti_report "$cmd"
			run_ksh_cmd "$cmd"
			if [ `get_cmd_retval` -ne 0 ];then
				report_err "$cmd"
				cti_fail "WARNING - Can not offline iscsi target port"
			fi
			cti_report "sleep $intervals intervals after offline target port"
			sleep $intervals
	
			typeset cmd="$STMFADM online-target $t_target"
			cti_report "$cmd"
			run_ksh_cmd "$cmd"
			if [ `get_cmd_retval` -ne 0 ];then
				report_err "$cmd"
				cti_fail "WARNING - Can not online iscsi target port"
			fi
			typeset cmd="$ISCSIADM modify -t enable"
			cti_report "$cmd"
			run_rsh_cmd $ISCSI_IHOST "$cmd"

			cti_report "sleep $intervals intervals after online target port"

			sleep $intervals
		done
		(( iter+=1 ))
	done
}

#
# NAME
#       iscsi_target_port_delete_create_io
# DESCRIPTION
#       iscsi target cable pull tests with create/delete target node and
#	diskomizer I/O
#
# ARGUMENT
#       $1 - target host
#       $2 - the seconds of target port delete/create intervals
#       $3 - test rounds for target port delete/create
#
# RETURN
#       1 failed
#       0 successful
#
function iscsi_target_port_delete_create_io
{
	typeset host_name=$1
	typeset intervals=$2
	typeset max_iter=$3
	cti_report "Start host side cable pull with"\
	    "itadm create/delete target tests on host $host_name."
	
	typeset iter=1
	typeset t_target
	while [ $iter -le $max_iter ]	
	do
		cti_report "Executing: running target portal delete - create to"\
		    "verify failover with $iter round"\
		    "and $intervals intervals"
		for t_target in $G_TARGET
		do
		
			typeset cmd="$ITADM delete-target -f $t_target"
			cti_report "$cmd"
			run_ksh_cmd "$cmd"
			if [ `get_cmd_retval` -ne 0 ];then
				report_err "$cmd"
				cti_fail "WARNING - Can not delete iscsi target port"
			fi
			cti_report "sleep $intervals intervals after delete target port"
			sleep $intervals
	
			typeset t_t=$(format_shellvar $(format_scsiname $t_target))
			eval typeset t_tpg="\${TARGET_${t_t}_TPG}"
			t_tpg=$(unique_list "$t_tpg" " " "," | sed -e "s/,$//g")
			if [ "$t_tpg" = "default" ]; then
				typeset cmd="$ITADM create-target -n $t_target"
			else
				typeset cmd="$ITADM create-target -n $t_target -t $t_tpg"
			fi

			cti_report "$cmd"
			run_ksh_cmd "$cmd"
			if [ `get_cmd_retval` -ne 0 ];then
				report_err "$cmd"
				cti_fail "WARNING - Can not create iscsi target port"
			fi
			typeset cmd="$ISCSIADM modify -t enable"
			cti_report "$cmd"
			run_rsh_cmd $ISCSI_IHOST "$cmd"
			cti_report "sleep $intervals intervals after create target port"
			sleep $intervals

		done

		(( iter+=1 ))
	done
}

#
# NAME
#       iscsi_target_stmf_enable_disable_io
# DESCRIPTION
#       iscsi target cable pull tests with enable/disable stmf smf service and
#	with diskomizer I/O
#
# ARGUMENT
#       $1 - target host
#       $2 - the seconds of stmf enable/disable intervals
#       $3 - test rounds for stmf enable/disable 
#
# RETURN
#       1 failed
#       0 successful
#
function iscsi_target_stmf_enable_disable_io
{
	typeset host_name=$1
	typeset intervals=$2
	typeset max_iter=$3
	cti_report "Start host side cable pull with"\
	    "svcadm enable/disable $STMF_SMF tests on host $host_name."

	typeset iter=1
	while [ $iter -le $max_iter ]	
	do
		cti_report "Executing: running $STMF_SMF enable - disable to"\
		    "verify failover with $iter round"\
		    "and $intervals intervals"
	
		stmf_smf_disable
		cti_report "sleep $intervals intervals after disable $STMF_SMF"
		sleep $intervals

		stmf_smf_enable		
		cti_report "sleep $intervals intervals after enable $STMF_SMF"
		sleep $intervals

		# iscsi initiator needs the explicit discovery
		typeset cmd="$ISCSIADM modify -t enable"
		cti_report "$cmd"
		run_rsh_cmd $ISCSI_IHOST "$cmd"

		(( iter+=1 ))
	done

}

#
# NAME
#       iscsi_target_port_online_offline
# DESCRIPTION
#       iscsi target cable pull tests with online/offline target node and
#       without diskomizer I/O
#
# ARGUMENT
#       $1 - target host
#       $2 - the seconds of target port online/offline intervals
#       $3 - test rounds for target port online/offline
#
# RETURN
#       1 failed
#       0 successful
#
function iscsi_target_port_online_offline
{
        typeset host_name=$1
        typeset intervals=$2
        typeset max_iter=$3
        cti_report "Start host side cable pull with"\
                "stmfadm online/offline tests on host $host_name."

        set -A target $G_TARGET
        typeset target_num=${#target[@]}
        
        typeset iter=1
        while [ $iter -le $max_iter ]   
        do
                cti_report "Executing: running target port online - offline to"\
                    "verify failover with $iter round"\
                    "and $intervals intervals"
                for t_target in $G_TARGET
                do      
                        typeset cmd="$STMFADM offline-target $t_target"
                        cti_report "$cmd"
                        run_ksh_cmd "$cmd"
                        if [ `get_cmd_retval` -ne 0 ];then
                                report_err "$cmd"
                                cti_fail "WARNING - Can not offline iscsi target port"
                        fi
                done

                cti_report "sleep $intervals intervals after offline target port"
                sleep $intervals

                typeset cmd="$STMFADM list-target -v"
                run_ksh_cmd "$cmd"
                typeset offline_num=$(get_cmd_stdout | grep -c Offline)
                if [ $offline_num != $target_num ];then
                        cti_fail "WARNING - There should be $target_num target ports"\
                            "offline on iscsi target host after offline-target, but"\
                            "only $offline_num target ports now"
                        report_err "$cmd"
                fi
        
                for t_target in $G_TARGET
                do      
                        typeset cmd="$STMFADM online-target $t_target"
                        cti_report "$cmd"
                        run_ksh_cmd "$cmd"
                        if [ `get_cmd_retval` -ne 0 ];then
                                report_err "$cmd"
                                cti_fail "WARNING - Can not online iscsi target port"
                        fi
                done

                cti_report "sleep $intervals intervals after online target port"
                sleep $intervals

                typeset cmd="$STMFADM list-target -v"
                run_ksh_cmd "$cmd"
                typeset online_num=$(get_cmd_stdout | grep -c Online)
                if [ $online_num != $target_num ];then
                        cti_fail "WARNING - There should be $target_num target ports"\
                            "online on iscsi target host after online-target, but"\
                            "only $online_num target ports now"
                        report_err "$cmd"
                fi

                (( iter+=1 ))
        done

}


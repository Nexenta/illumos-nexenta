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
# This file contains common functions and is meant to be sourced into
# the test case files.  These functions are used to verify the 
# configuration and state of the resources in use.
#
#
# NAME
#	itadm_verify
# DESCRIPTION
#	Compare the actual object list to what the test suite 
#	thinks the object list should be.
#	It works like the factory method pattern.
#
# RETURN
#	Sets the result code
#	void
#
function itadm_verify 
{
	typeset object=$1
	case $object in
		"target")
			itadm_verify_target
			stmfadm_verify_target
		;;
		"tpg")
			itadm_verify_tpg
		;;
		"initiator")
			itadm_verify_initiator
		;;
		"defaults")
			itadm_verify_defaults
		;;
		*)
			cti_report "itadm_vefiy: unkown option - $object"
		;;
	esac
}

#
# NAME
#	itadm_verify_target
# DESCRIPTION
#	Compare the actual target node list to what the test suite 
#	thinks the target node list should be.
#
# RETURN
#	Sets the result code
#	void
#
function itadm_verify_target 
{
	cti_report "Executing: itadm_verify_target start"
	
	compare_target
	
	for target in $G_TARGET
	do
		compare_target_property $target
	done
	cti_report "Executing: itadm_verify_target stop"
}

#
# NAME
#	compare_target
# DESCRIPTION
#	Compare the actual target node list to what test suite thinks the 
#	target node list should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_target 
{
	typeset cmd="${ITADM} list-target"
	typeset TARGET_fnd=0	
	typeset chk_TARGETS=$(trunc_space $G_TARGET)
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | while read line
	do
		if [ $TARGET_fnd -eq 0 ];then
			echo $line | grep "TARGET NAME" >/dev/null 2>&1
			if [ $? -eq 0 ];then
				TARGET_fnd=1
			fi
			continue
		fi
		if [ -z "$line" ]; then
			continue
		fi
		typeset TARGET_mfnd=0
		chk_TARGET=`echo $line | awk '{print $1}'`
		unset TARGET_list
		for chk_target in $chk_TARGETS
		do 
			if [ "$chk_target" = "$chk_TARGET" ];then
				TARGET_mfnd=1
			else
				TARGET_list="$TARGET_list $chk_target"
			fi
		done
		if [ $TARGET_mfnd -eq 0 ];then
			cti_fail "WARNING: TARGET $chk_TARGET is in "\
			    "listed output but not in stored info."
		fi
		chk_TARGETS="$TARGET_list"
	done

	if [ "$chk_TARGETS" ];then
		cti_fail "WARNING: TARGETS $chk_TARGETS are in "\
		    "stored info but not in listed output."
	fi
}	

#
# NAME
#	compare_target_property
# DESCRIPTION
#	Compare the actual target property information of the specified 
#	target node to what test suite thinks the target property should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_target_property 
{
	typeset target=$1
	typeset cmd="${ITADM} list-target -v $target"
	typeset TARGET_fnd=0	
	
	typeset val_com val_exp

	typeset t_target=$(format_shellvar $(format_scsiname $target))
	eval typeset chk_ALIAS=\"\$TARGET_${t_target}_ALIAS\"
	eval typeset chk_AUTH_VAL=\"\$TARGET_${t_target}_AUTH_VAL\"
	eval typeset chk_USER=\"\$TARGET_${t_target}_USER\"
	eval typeset chk_SECRET=\"\$TARGET_${t_target}_SECRET\"
	eval typeset chk_TPG=\"\$TARGET_${t_target}_TPG\"

	[[ -z "$chk_ALIAS" ]] && chk_ALIAS="<none>"
	[[ -z "$chk_AUTH_VAL" ]] && chk_AUTH_VAL="<none>"
	[[ -z "$chk_USER" ]] && chk_USER="<none>"
	[[ -z "$chk_SECRET" ]] && chk_SECRET="unset"
	[[ -z "$chk_TPG" ]] && chk_TPG="default"


	run_ksh_cmd "$cmd" 
	typeset l_ALIAS=$(get_cmd_stdout | awk '{if($1~/alias:/) print $NF}')
	typeset l_AUTH_VAL=$(get_cmd_stdout | awk '{if($1~/auth:/) print $0}' |\
	    awk '{if(NF==2) print $NF; else printf("%s %s" ,$(NF-1),$NF)}')
	typeset l_USER=$(get_cmd_stdout | awk '{if($1~/targetchapuser:/) print $NF}')
	typeset l_SECRET=$(get_cmd_stdout | awk '{if($1~/targetchapsecret:/) print $NF}')
	typeset l_TPG=$(get_cmd_stdout | awk '{if($1~/tpg-tags:/) print $0}' |\
	    sed -e "s/,/ /g" | awk '{for (i=1;i<=NF;i++) if ($i~/\=/) \
	    printf "%s,",$(i-1); printf "\n"}') 
	l_TPG=$(unique_list "$l_TPG" "," " ")
	[[ -z "$l_TPG" ]] && l_TPG="default"

	if [ "$chk_SECRET" = "unset" ];then
		val_com="$l_ALIAS $l_AUTH_VAL $l_USER $l_SECRET $l_TPG"
		val_exp="$chk_ALIAS $chk_AUTH_VAL $chk_USER $chk_SECRET $chk_TPG"
	else
		val_com="$l_ALIAS $l_AUTH_VAL $l_USER $l_TPG"
		val_exp="$chk_ALIAS $chk_AUTH_VAL $chk_USER $chk_TPG"
	fi
	
	val_com=$(echo "$val_com" | sed -e "s/[<>]//g" -e "s/-/none/g")
	val_exp=$(echo "$val_exp" | sed -e "s/[<>]//g" -e "s/-/none/g" )
	if [ "$val_exp" != "$val_com" ];then
		cti_fail "WARNING: TARGET $target Property [$val_com] is in"\
	 	    "listed output but not matched in stored info [$val_exp]."
	 fi

}
#
# NAME
#	itadm_verify_tpg
# DESCRIPTION
#	Compare the actual target portal group list to what the test suite 
#	thinks the target portal group list should be.
#
# RETURN
#	Sets the result code
#	void
#
function itadm_verify_tpg 
{
	cti_report "Executing: itadm_verify_tpg start"
	
	compare_tpg
	
	for tpg in $G_TPG
	do
		compare_tpg_portal $tpg
	done
	cti_report "Executing: itadm_verify_tpg stop"
}
#
# NAME
#	compare_tpg
# DESCRIPTION
#	Compare the actual target portal group list to what the test suite 
#	thinks the target portal group list should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_tpg 
{
	typeset cmd="${ITADM} list-tpg"
	typeset TPG_fnd=0	
	typeset chk_TPGS=$(trunc_space $G_TPG)
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | while read line
	do
		if [ $TPG_fnd -eq 0 ];then
			echo $line | grep "TARGET PORTAL GROUP" \
			    > /dev/null 2>&1
			if [ $? -eq 0 ];then
				TPG_fnd=1
			fi
			continue
		fi
		if [ -z "$line" ]; then
			continue
		fi
		chk_TPG=$(echo $line | awk '{print $1}')
		unset TPG_list
		typeset TPG_mfnd=0
		for chk_tpg in $chk_TPGS
		do 
			if [ "$chk_tpg" = "$chk_TPG" ];then
				TPG_mfnd=1
			else
				TPG_list="$TPG_list $chk_tpg"
			fi
		done
		if [ $TPG_mfnd -eq 0 ];then
			cti_fail "WARNING: TPG $chk_TPG is in "\
			    "listed output but not in stored info."
		fi
		chk_TPGS="$TPG_list"
	done

	if [ "$chk_TPGS" ];then
		cti_fail "WARNING: TPGS $chk_TPGS are in stored info "\
		    "but not in listed output."
	fi
}	

#
# NAME
#	compare_tpg_portal
# DESCRIPTION
#	Compare the actual target portal list of specified target portal group 
#	tag to what the test suite thinks the target portal list should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_tpg_portal 
{
	typeset tpg=$1
	typeset cmd="${ITADM} list-tpg -v $tpg"
	typeset TPG_fnd=0	
	typeset PORTAL_fnd=0
	eval chk_PORTALS=\"\$TPG_${tpg}_PORTAL\"
	chk_PORTALS=$(trunc_space $chk_PORTALS)
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | while read line
	do		
		if [ $TPG_fnd -eq 0 ];then
			typeset t_tpg=$(echo $line | awk '{print $1}')
			if [ "$tpg" = "$t_tpg" ];then
				TPG_fnd=1
			fi
			continue
		fi
		if [ -z "$line" ]; then
			continue
		fi
		chk_PORTAL=$(echo $line | awk '{print $NF}')
		chk_PORTAL=$(unique_list "$chk_PORTAL" "," " ")	
		for chk_portal in $chk_PORTAL
		do 
			PORTAL_fnd=0
			unset PORTAL_list
			for chk_portals in $chk_PORTALS
			do
				if [ "$chk_portals" = "$chk_portal" ];then
					PORTAL_fnd=1
				else
					PORTAL_list="$PORTAL_list $chk_portals"
				fi
			done
			if [ $PORTAL_fnd -eq 0 ];then
				cti_fail "WARNING: TPG-PORTAL $chk_portal is in"\
				    "listed output but not in stored info."
			fi
			chk_PORTALS="$PORTAL_list"
		done
	done

	if [ "$chk_PORTALS" ];then
		cti_fail "WARNING: TPG-PORTALS $chk_PORTALS are in stored info"\
		    "but not in listed output."
	fi
}

#
# NAME
#	itadm_verify_initiator
# DESCRIPTION
#	Compare the authorized iscsi initiator node list to what the test suite 
#	thinks the initiator node list should be.
#
# RETURN
#	Sets the result code
#	void
#
function itadm_verify_initiator 
{
	cti_report "Executing: itadm_verify_initiator start"
	
	compare_initiator
	
	for initiator in $TARGET_AUTH_INITIATOR
	do
		compare_initiator_property $initiator
	done
	cti_report "Executing: itadm_verify_initiator stop"

}
#
# NAME
#	compare_initiator
# DESCRIPTION
#	Compare the actual initiator node list to what test suite thinks the 
#	initiator node list should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_initiator
{
	typeset cmd="${ITADM} list-initiator"
	typeset INITIATOR_fnd=0	
	typeset chk_INITIATORS=$(trunc_space $TARGET_AUTH_INITIATOR)
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | while read line
	do
		if [ $INITIATOR_fnd -eq 0 ];then
			echo $line | grep "INITIATOR NAME" \
			    > /dev/null 2>&1
			if [ $? -eq 0 ];then
				INITIATOR_fnd=1
			fi
			continue
		fi
		if [ -z "$line" ]; then
			continue
		fi
		INITIATOR_mfnd=0
		chk_INITIATOR=`echo $line | awk '{print $1}'`
		unset INITIATOR_list
		for chk_initiator in $chk_INITIATORS
		do 
			if [ "$chk_initiator" = "$chk_INITIATOR" ];then
				INITIATOR_mfnd=1
			else
				INITIATOR_list="$INITIATOR_list $chk_initiator"
			fi
		done
		if [ $INITIATOR_mfnd -eq 0 ];then
			cti_fail "WARNING: INITIATOR $chk_INITIATOR is in "\
			    "listed output but not in stored info."
		fi
		chk_INITIATORS="$INITIATOR_list"
	done

	if [ "$chk_INITIATORS" ];then
		cti_fail "WARNING: INITIATORS $chk_INITIATORS are in stored info "\
		    "but not in listed output."
	fi
}	

#
# NAME
#	compare_initiator_property
# DESCRIPTION
#	Compare the actual initiator property information of the specified 
#	target node to what test suite thinks the initiator property should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_initiator_property 
{
	typeset initiator=$1
	typeset cmd="${ITADM} list-initiator -v $initiator"
	typeset INITIATOR_fnd=0	
	
	typeset t_initiator=$(format_shellvar $(format_scsiname $initiator))
	eval typeset chk_USER=\"\$TARGET_AUTH_INITIATOR_${t_initiator}_USER\"
	eval typeset chk_SECRET=\"\$TARGET_AUTH_INITIATOR_${t_initiator}_SECRET\"
	[[ -z "$chk_USER" ]] && chk_USER="<none>"
	[[ -z "$chk_SECRET" ]] && chk_SECRET="unset"

	run_ksh_cmd "$cmd" 
	typeset l_USER=$(get_cmd_stdout | sed -n '2,$p' | awk '{print $2}')
	typeset l_SECRET=$(get_cmd_stdout | sed -n '2,$p' | awk '{print $3}')

	if [ "$chk_SECRET" = "unset" ];then
		typeset val_com="$l_USER $l_SECRET"
		typeset val_exp="$chk_USER $chk_SECRET"
	else
		typeset val_com="$l_USER"
		typeset val_exp="$chk_USER"
	fi
	
	val_com=$(echo "$val_com" | sed -e "s/[<>]//g")
	val_exp=$(echo "$val_exp" | sed -e "s/[<>]//g")
	if [ "$val_exp" != "$val_com" ];then
		cti_fail "WARNING: INITIATOR $initiator Property [$val_com] is in"\
	 	    "listed output but not matched in stored info [$val_exp]."
	fi
}

#
# NAME
#	itadm_verify_defaults
# DESCRIPTION
#	Compare the default settings to what the test suite 
#	thinks the default settings should be.
#
# RETURN
#	Sets the result code
#	void
#
function itadm_verify_defaults 
{
	cti_report "Executing: itadm_verify_defaults start"
	typeset cmd="${ITADM} list-defaults"
	run_ksh_cmd "$cmd" 

	typeset val_com val_exp

	typeset chk_ALIAS="$DEFAULTS_ALIAS"
	typeset chk_AUTH="$DEFAULTS_AUTH"
	typeset chk_RSERVER="$DEFAULTS_RADIUS_SERVER"
	typeset chk_RSECRET="$DEFAULTS_RADIUS_SECRET"
	typeset chk_IENABLE="$DEFAULTS_ISNS_ENABLE"
	typeset chk_ISERVER="$DEFAULTS_ISNS_SERVER"
	

	[[ -z "$chk_ALIAS" ]] && chk_ALIAS="<none>"
	[[ -z "$chk_AUTH" ]] && chk_AUTH="<none>"
	[[ -z "$chk_RSERVER" ]] && chk_RSERVER="<none>"
	[[ -z "$chk_RSECRET" ]] && chk_RSECRET="unset"
	[[ -z "$chk_ISERVER" ]] && chk_ISERVER="<none>"

	typeset l_ALIAS=$(get_cmd_stdout | awk '{if($1~/alias:/) print $NF}')
	typeset l_AUTH=$(get_cmd_stdout | awk '{if($1~/auth:/) print $NF}')
	typeset l_RSERVER=$(get_cmd_stdout | awk '{if($1~/radiusserver:/) print $NF}')
	typeset l_RSECRET=$(get_cmd_stdout | awk '{if($1~/radiussecret:/) print $NF}')
	typeset l_IENABLE=$(get_cmd_stdout | awk '{if($1~/isns:/) print $NF}')
	typeset l_ISERVER=$(get_cmd_stdout | awk '{if($1~/isnsserver:/) print $NF}')

	l_RSERVER=$(unique_list "$l_RSERVER" "," " ")
	l_ISERVER=$(unique_list "$l_ISERVER" "," " ")

	typeset server=''
	typeset server_list=''
	if [[ "$( echo "$l_RSERVER" | egrep none)" == "" ]];then
		for server in $l_RSERVER
		do
			server=$(supply_default_port "$server" "radius")
			server_list="$server $server_list"
		done
		l_RSERVER=$(unique_list "$server_list" " " " ")
	fi
	
	server_list=''
	if [[ "$( echo "$l_ISERVER" | egrep none)" == "" ]];then
		for server in $l_ISERVER
		do
			server=$(supply_default_port "$server" "isns")
			server_list="$server $server_list"
		done
		l_ISERVER=$(unique_list "$server_list" " " " ") 
	fi

	if [ "$chk_RSECRET" = "unset" ];then
		val_com="$l_ALIAS $l_AUTH $l_RSERVER $l_RSECRET $l_IENABLE $l_ISERVER"
		val_exp="$chk_ALIAS $chk_AUTH $chk_RSERVER $chk_RSECRET $chk_IENABLE $chk_ISERVER"
	else
		val_com="$l_ALIAS $l_AUTH $l_RSERVER $l_RSECRET $l_IENABLE $l_ISERVER"
		val_exp="$l_ALIAS $chk_AUTH $chk_RSERVER set $chk_IENABLE $chk_ISERVER"
	fi

	val_com=$(echo "$val_com" | sed -e "s/[<>]//g")
	val_exp=$(echo "$val_exp" | sed -e "s/[<>]//g")
	if [ "$val_exp" != "$val_com" ];then
		cti_fail "WARNING: Default Settings Property [$val_com] is in"\
	 	    "listed output but not matched in stored info [$val_exp]."
	fi
	
	cti_report "Executing: itadm_verify_defaults end"
}

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
# NAME
#	itadm_create_info
# DESCRIPTION
# 	Store information about created objects based on information
# 	passed to the function as arguments.
#
# ARGUMENT
#	$1 - the valid object type
#	$2 - the overall command option
#
# RETURN
#	void
#
function itadm_create_info 
{
	typeset object=$1
	shift 1
	unset node_name
	case "$object" in
	"target")
		typeset options=$*
		typeset usage=":"
		usage="${usage}n:(node-name)"
		while getopts "$usage" option
		do
			case $option in
			n)
				typeset node_name=$OPTARG
				node_name=`format_scsiname $node_name`
				;;
			?)
				(( OPTIND = ${OPTIND} + 1 ))
				;;
			esac
		done
		if [ -z "$node_name" ];then
			#create default target node now
			$ITADM list-target | sed -n '2,$p' | awk '{print $1}' | \
			    while read target
			do
				echo "${G_TARGET}" | grep -w $target > \
				    /dev/null 2>&1
				if [ $? -ne 0 ];then
					node_name=$target
					break
				fi
			done
		fi
		echo $G_TARGET | grep -w $node_name > /dev/null 2>&1
		if [ $? -ne 0 ];then
			G_TARGET="$node_name $G_TARGET"
			update_target "$node_name" $options
		fi
		update_isns_targetlist
	;;
	"tpg")
		typeset tag=$1
		shift 1
		typeset options=$*
		echo "${G_TPG}" | grep -w $tag > /dev/null 2>&1
		if [ $? -ne 0 ];then
			G_TPG="$tag $G_TPG"
		fi
		typeset portal
		for portal in $options
		do
			eval t_plist="\${TPG_${tag}_PORTAL}"
			portal=$(supply_default_port "$portal" "sendTargets")
			echo "$t_plist" | grep -w $portal > /dev/null 2>&1
			if [ $? -ne 0 ];then
				eval TPG_${tag}_PORTAL="\"$portal $t_plist\""
			fi
		done
		eval t_plist="\${TPG_${tag}_PORTAL}"
		t_plist=$(unique_list "$t_plist" " " " ")
		eval TPG_${tag}_PORTAL="\"$t_plist\""
	;;
	"initiator")
		eval typeset node_name=\${$#}
		node_name=`format_scsiname $node_name`
		typeset options=$*
		echo $TARGET_AUTH_INITIATOR | grep -w $node_name > /dev/null 2>&1
		if [ $? -ne 0 ];then			
			# create the initiator node on target host
			TARGET_AUTH_INITIATOR="$node_name $TARGET_AUTH_INITIATOR"
		fi
		update_initiator "$node_name" $options
	;;
	*)
		cti_report "unknow object - $object"
	;;
	esac
}
#
# NAME
#	udpate_target
# DESCRIPTION
# 	Refresh target information about each property.
# 	iscsi node name is passed to the function as the only argument.
#
# ARGUMENT
#	$1 - iscsi target node name
#	$2 - the options of create subcommand
#
# RETURN
#	void
#
function update_target
{
	typeset node_name=$1
	typeset rebuild_node_name=$1
	shift 1

	typeset node_name=$(format_shellvar $(format_scsiname $node_name))

	eval DEFAULTS_AUTH="\${DEFAULTS_AUTH:=''}"
	eval DEFAULTS_ALIAS="\${DEFAULTS_ALIAS:=''}"
	
	typeset t_defaults_auth="$DEFAULTS_AUTH"
	[[ -z "$t_defaults_auth" ]] && t_defaults_auth="none"

	eval TARGET_${node_name}_AUTH="\${TARGET_${node_name}_AUTH:='default'}"
	eval TARGET_${node_name}_AUTH_VAL="\${TARGET_${node_name}_AUTH_VAL:='$t_defaults_auth (defaults)'}"
	eval TARGET_${node_name}_SECRET="\${TARGET_${node_name}_SECRET:=''}"
	eval TARGET_${node_name}_USER="\${TARGET_${node_name}_USER:=''}"
	eval TARGET_${node_name}_ALIAS="\${TARGET_${node_name}_ALIAS:=''}"
	eval TARGET_${node_name}_TPG="\${TARGET_${node_name}_TPG:='default'}"
	eval TARGET_${node_name}_TPG_VAL="\${TARGET_${node_name}_TPG_VAL:=''}"
	eval TARGET_${node_name}_ONLINE="\${TARGET_${node_name}_ONLINE:='Y'}"


	typeset usage=":"
	usage="${usage}a:(auth-method)"
	usage="${usage}s:(chap-secret)"
	usage="${usage}S:(chap-secret-file)"
	usage="${usage}u:(chap-user)"
	usage="${usage}n:(node-name)"
	usage="${usage}l:(alias)"
	usage="${usage}t:(tpg)"

	while getopts "$usage" option
	do
		case $option in
		a)
			eval TARGET_${node_name}_AUTH="$OPTARG"

                        if [ "$OPTARG" = "default" ];then
                                eval TARGET_${node_name}_AUTH_VAL=\"$t_defaults_auth \(defaults\)\"
                        else
                                eval TARGET_${node_name}_AUTH_VAL=\"$OPTARG\"
                        fi
			;;
		s|S)
			eval TARGET_${node_name}_SECRET="$OPTARG"
			;;
		n)
			;;
		u)
			eval TARGET_${node_name}_USER="$OPTARG"
			;;
		l)
			eval TARGET_${node_name}_ALIAS="$OPTARG"
			;;
		t)
			typeset tpg=$(unique_list "$OPTARG" "," " ")
			eval TARGET_${node_name}_TPG="\"$tpg\""
			;;
		?)
			(( OPTIND = ${OPTIND} + 1 ))
			;;
		esac
	done
	rebuild_target_tpg "$rebuild_node_name"

}
#
# NAME
#      rebuild_target_tpg 
# DESCRIPTION
#       Refresh target information about each property.
#       iscsi node name is passed to the function as the only argument.
#	tpg tag value is associated with specified target and not available when creation
#
# ARGUMENT
#       $1 - iscsi target node name
#
# RETURN
#       void
#
function rebuild_target_tpg 
{
	typeset target=$1
	typeset cmd="${ITADM} list-target -v $target"

	typeset t_target=$(format_shellvar $(format_scsiname $target))

	run_ksh_cmd "$cmd" 
	typeset l_TPG_VALUE=$(get_cmd_stdout | awk '{if($1~/tpg-tags:/) print $0}' |\
            sed -e "s/,/ /g" | awk '{for (i=1;i<=NF;i++) if ($i~/\=/) \
            printf "%s,",$(i+1); printf "\n"}')
        l_TPG_VALUE=$(unique_list "$l_TPG_VALUE" "," " ")
	[[ -z "$l_TPG_VALUE" ]] && l_TPG_VALUE=1
	eval TARGET_${t_target}_TPG_VAL=\"$l_TPG_VALUE\"
}
#
# NAME
#	unique_list
# DESCRIPTION
# 	Delete information about stored objects based on information
# 	passed to the function as arguments.
#
# ARGUMENT
#	$1 - the input string to be handled with
#	$2 - the token string for spliting
# RETURN
#	the output is the string with the same token separated
#
function unique_list 
{
	typeset input_string="$1"
	typeset input_token="$2"
	typeset output_token="$3"
	echo $(echo "$input_string" | tr "$input_token" '\n' | sort -u | \
	    tr '\n' "$output_token")
}
#
# NAME
#	copy_target
# DESCRIPTION
# 	assign all the properties of iscsi node1 to iscsi node2
#
# ARGUMENT
#	$1 - iscsi target node1 name
#	$2 - iscsi target node2 name
#
# RETURN
#	void
#
function copy_target
{
	typeset node_name1=$1
	typeset node_name2=$2

	typeset node_name1=$(format_shellvar $(format_scsiname $node_name1))
	typeset node_name2=$(format_shellvar $(format_scsiname $node_name2))

	eval TARGET_${node_name1}_AUTH="\${TARGET_${node_name2}_AUTH}"
	eval TARGET_${node_name1}_AUTH_VAL="\${TARGET_${node_name2}_AUTH_VAL}"
	eval TARGET_${node_name1}_SECRET="\${TARGET_${node_name2}_SECRET}"
	eval TARGET_${node_name1}_USER="\${TARGET_${node_name2}_USER}"
	eval TARGET_${node_name1}_ALIAS="\${TARGET_${node_name2}_ALIAS}"
	eval TARGET_${node_name1}_TPG="\${TARGET_${node_name2}_TPG}"
	eval TARGET_${node_name1}_TPG_VAL="\${TARGET_${node_name2}_TPG_VAL}"
	eval TARGET_${node_name1}_ONLINE="\${TARGET_${node_name2}_ONLINE}"

	
}
#
# NAME
#	itadm_delete_info
# DESCRIPTION
# 	Delete information about stored objects based on information
# 	passed to the function as arguments.
#
# ARGUMENT
#	$1 - the valid object type
#	$2 - the overall command option
#
# RETURN
#	void
#
function itadm_delete_info 
{
	typeset object=$1
	shift 1
	case "$object" in
	"target")		
		eval typeset t_object=\${$#}
		echo $G_TARGET | grep -w $t_object > /dev/null 2>&1
		if [ $? -eq 0 ];then
			G_TARGET=$(echo $G_TARGET | sed -e "s/\<$t_object\>//g" \
			    | sed 's/^ *//g')
			typeset object=$(format_shellvar \
			    $(format_scsiname $t_object))
			eval unset TARGET_${object}_AUTH
			eval unset TARGET_${object}_AUTH_VAL
			eval unset TARGET_${object}_SECRET
			eval unset TARGET_${object}_USER
			eval unset TARGET_${object}_ALIAS
			eval unset TARGET_${object}_TPG
			eval unset TARGET_${object}_TPG_VAL
			eval unset TARGET_${object}_ONLINE			
		fi
		update_isns_targetlist
	;;
	"tpg")
		eval typeset t_object=\${$#}
		echo $G_TPG | grep -w $t_object > /dev/null 2>&1
		if [ $? -eq 0 ];then
			G_TPG=$(echo $G_TPG | sed -e "s/\<$t_object\>//g" \
			    | sed 's/^ *//g')
			eval unset TPG_${t_object}_PORTAL
		fi
		# delete all the  associated target property of tpg list
		for target in $G_TARGET
		do
			eval tpg_list="\$TARGET_${target}_TPG"
			echo $tpg_list | grep -w $t_object > /dev/null 2>&1
			if [ $? -eq 0 ];then
				eval TARGET_${target}_TPG=\"$(echo $tpg_list | \
				    sed -e "s/\<$t_object\>//" | \
				    sed 's/^ *//g')\"
			fi
		done
	;;
	"initiator")		
		eval typeset t_object=\${$#}
		echo $TARGET_AUTH_INITIATOR | grep -w $t_object > /dev/null 2>&1
		if [ $? -eq 0 ];then
			TARGET_AUTH_INITIATOR=$(echo $TARGET_AUTH_INITIATOR | \
			    sed -e "s/\<$t_object\>//g" \
			    | sed 's/^ *//g')
			typeset object=$(format_shellvar \
			    $(format_scsiname $t_object))
			eval unset TARGET_AUTH_INITIATOR_${object}_SECRET
			eval unset TARGET_AUTH_INITIATOR_${object}_USER
		fi
	;;
	*)
		cti_report "unknow object - $object"
	;;
	esac
}

#
# NAME
#	itadm_modify_info
# DESCRIPTION
# 	Modify information about stored objects based on information
# 	passed to the function as arguments.
#
# ARGUMENT
#	$1 - the valid object type
#	$2 - the overall command option
#
# RETURN
#	void
#
function itadm_modify_info 
{
	typeset object=$1
	shift 1
	case "$object" in
	"target")	
		eval typeset node_name=\${$#}
		node_name=`format_scsiname $node_name`
		echo $G_TARGET | grep -w $node_name > /dev/null 2>&1
		if [ $? -eq 0 ];then			
			typeset options=$*
			unset n_node_name

			typeset usage=":"
			usage="${usage}n:(node-name)"

			while getopts "$usage" option
			do
				case $option in
				n)
					typeset n_node_name=$OPTARG
					n_node_name=`format_scsiname $n_node_name`
					;;
				?)
					(( OPTIND = ${OPTIND} + 1 ))
					;;
				esac
			done			
			if [ -n "$n_node_name" ];then

				copy_target "$n_node_name" "$node_name"

				itadm_delete_info target "$node_name"
				G_TARGET="$n_node_name $G_TARGET"

				update_target "$n_node_name" $options

			else
				update_target "$node_name" $options
			fi
		fi
		update_isns_targetlist
	;;
	"initiator")
		eval typeset node_name=\${$#}
		node_name=`format_scsiname $node_name`
		typeset options=$*
		echo $TARGET_AUTH_INITIATOR | grep -w $node_name > /dev/null 2>&1
		if [ $? -ne 0 ];then			
			# create the initiator node on target host
			TARGET_AUTH_INITIATOR="$node_name $TARGET_AUTH_INITIATOR"
		fi
		update_initiator "$node_name" $options
	;;
	"defaults")
		typeset options=$*
		update_defaults $options
	;;
	*)
		cti_report "unknow object - $object"
	;;
	esac
}

#
# NAME
#	udpate_initiator
# DESCRIPTION
# 	Refresh initiator information about each property.
# 	iscsi node name is passed to the function as the only argument.
#
# ARGUMENT
#	$1 - iscsi initiator node name
#	$2 - the options of create subcommand
#
# RETURN
#	void
#
function update_initiator
{
	typeset node_name=$1
	shift 1
	typeset node_name=$(format_shellvar $(format_scsiname $node_name))

	eval TARGET_AUTH_INITIATOR_${node_name}_SECRET="\${TARGET_AUTH_INITIATOR_${node_name}_SECRET:=''}"
	eval TARGET_AUTH_INITIATOR_${node_name}_USER="\${TARGET_AUTH_INITIATOR_${node_name}_USER:=''}"

	typeset usage=":"
	usage="${usage}s:(chap-secret)"
	usage="${usage}S:(chap-secret-file)"
	usage="${usage}u:(chap-user)"

	while getopts "$usage" option
	do
		case $option in
		s|S)
			typeset chap_secret=$OPTARG
			eval TARGET_AUTH_INITIATOR_${node_name}_SECRET="$chap_secret"
			;;
		u)
			typeset chap_user=$OPTARG
			eval TARGET_AUTH_INITIATOR_${node_name}_USER="$chap_user"
			;;
		?)
			(( OPTIND = ${OPTIND} + 1 ))
			;;
		esac
	done	
}

#
# NAME
#	udpate_defaults
# DESCRIPTION
# 	Refresh default settings of target information about each property.
#
# ARGUMENT
#	The default options and parameters
#
# RETURN
#	void
#
function update_defaults
{
	eval DEFAULTS_ALIAS="\${DEFAULTS_ALIAS:=''}"
	eval DEFAULTS_AUTH="\${DEFAULTS_AUTH:=''}"
	eval DEFAULTS_RADIUS_SERVER="\${DEFAULTS_RADIUS_SERVER:=''}"
	eval DEFAULTS_RADIUS_SECRET="\${DEFAULTS_RADIUS_SECRET:=''}"
	eval DEFAULTS_ISNS_ENABLE="\${DEFAULTS_ISNS_ENABLE:='disabled'}"
	eval DEFAULTS_ISNS_SERVER="\${DEFAULTS_ISNS_SERVER:=''}"

	typeset usage="a:(auth-method)r:(radius-server)d:(radius-secret)D:"
	usage="${usage}i:(isns)I:(isns-server)"

	typeset usage=":"
	usage="${usage}a:(auth-method)"
	usage="${usage}d:(radius-secret)"
	usage="${usage}D:(radius-secret-file)"
	usage="${usage}r:(radius-server)"
	usage="${usage}i:(isns)"
	usage="${usage}I:(isns-server)"

	while getopts "$usage" option
	do
		case $option in
		a)
			DEFAULTS_AUTH="$OPTARG"
			[[ "$OPTARG" == "none" ]] && DEFAULTS_AUTH=''

			# update each target node's chap auth method
			typeset node_name
			for node_name in $G_TARGET
			do
				typeset node=$(format_shellvar \
				    $(format_scsiname $node_name))
				eval typeset auth="\${TARGET_${node}_AUTH}"
				if [ "$auth" = "default" ];then
					eval TARGET_${node}_AUTH_VAL=\"$OPTARG \(defaults\)\"
				fi
			done
			;;
		d|D)
			DEFAULTS_RADIUS_SECRET="$OPTARG"
			;;
		r)
			DEFAULTS_RADIUS_SERVER=''
			typeset radius_server=$(unique_list "$OPTARG" "," " ")
			for server in $radius_server
			do
				server=$(supply_default_port "$server" "radius")
				DEFAULTS_RADIUS_SERVER="$server $DEFAULTS_RADIUS_SERVER"
			done
			DEFAULTS_RADIUS_SERVER=$(unique_list "$DEFAULTS_RADIUS_SERVER" " " " ")
			;;
		i)
			eval DEFAULTS_ISNS_ENABLE="${OPTARG}d"
			update_isns_targetlist
			;;
		I)
			DEFAULTS_ISNS_SERVER=''
			typeset isns_server=$(unique_list "$OPTARG" "," " ")
			for server in $isns_server
			do
				server=$(supply_default_port "$server" "isns")
				DEFAULTS_ISNS_SERVER="$server $DEFAULTS_ISNS_SERVER"
			done
			DEFAULTS_ISNS_SERVER=$(unique_list "$DEFAULTS_ISNS_SERVER" " " " ")
			update_isns_targetlist
			;;
		?)
			(( OPTIND = ${OPTIND} + 1 ))
			;;
		esac
	done	
}
#
# NAME
#	update_isns_targetlist
# DESCRIPTION
# 	ISNS Server should visit all the target nodes if isns discovery 
#	is enabled and all the nodes will be added into default discovery domain
#	by default in test suite
#
# ARGUMENT
#	The default options and parameters
#
# RETURN
#	void
#
function update_isns_targetlist
{
	typeset isns_server
	for isns_server in $DEFAULTS_ISNS_SERVER
	do
		echo "$isns_server" | grep ":" >/dev/null 2>&1
		if [ $? -eq 0 ];then
			isns_server=$(echo $isns_server | cut -d: -f1)
		fi
		typeset server=$(format_shellvar $isns_server)
		# totally to refresh for each isns server
		eval ISNS_${server}_TARGET=''
		# the below judgement is to make sure to clean up the target list
		# of each isns server if isns discovery is disabled
		if [ "$DEFAULTS_ISNS_ENABLE" = "disabled" ];then
			continue
		fi
		for node_name in $G_TARGET
		do
			#node_name=$(format_shellvar $(format_scsiname $node_name))
			typeset eval target_list="\${ISNS_${server}_TARGET}"
			echo "$target_list" | grep $node_name >/dev/null 2>&1
			if [ $? -ne 0 ];then
				eval ISNS_${server}_TARGET=\"$node_name $target_list\"
			fi
		done
	done
}

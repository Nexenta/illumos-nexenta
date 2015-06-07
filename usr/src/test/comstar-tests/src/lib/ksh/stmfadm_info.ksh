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
#	stmfadm_create_info
# DESCRIPTION
# 	Store information about created objects based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function stmfadm_create_info 
{
	typeset object=$1
	shift 1
	typeset options=$*
	eval typeset object_id=\${$#}

	echo $object_id |wc -c | read len
	if [ $len -gt 255 ];then
		typeset -L255 object_id="$object_id"
	fi

	case "$object" in
	"hg")
		echo "${G_HG}" | grep -w $object_id > /dev/null 2>&1
		if [ $? -ne 0 ];then
			G_HG="$object_id $G_HG"
		fi
		eval HG_${object_id}_guid="\${HG_${object_id}_guid:=''}"					
		eval HG_${object_id}_member="\${HG_${object_id}_member:=''}"
	;;
	"tg")
		echo "${G_TG}" | grep -w $object_id > /dev/null 2>&1
		if [ $? -ne 0 ];then
			G_TG="$object_id $G_TG"
		fi
		eval TG_${object_id}_guid="\${TG_${object_id}_guid:=''}"
		eval TG_${object_id}_member="\${TG_${object_id}_member:=''}"
	;;
	*)
		cti_report "unknow object - $object"
	;;
	esac
}


#
# NAME
#	stmfadm_delete_info
# DESCRIPTION
# 	Delete information about stored objects based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function stmfadm_delete_info 
{
	typeset object=$1
	shift 1
	typeset options=$*
	eval typeset object_id=\${$#}

	echo $object_id |wc -c | read len
	if [ $len -gt 255 ];then
		typeset -L255 object_id="$object_id"
	fi

	case "$object" in
	"hg")
		echo "${G_HG}" | grep -w $object_id > /dev/null 2>&1
		if [ $? -eq 0 ];then
			eval hg_list="\$HG_${object_id}_guid"
			if [ -z $hg_list ];then
				G_HG=`echo $G_HG | sed -e "s/\<$object_id\>//g"\
					| sed 's/^ *//g'`
				eval HG_${object_id}_member="\${HG_${object_id}_member:=''}"
				eval member_hglist="\$HG_${object_id}_member"
				member_hglist=`trunc_space "$member_hglist"`			
				typeset member_id
				for member_id in $member_hglist
				do
					typeset scsi_id=`format_scsiname \
						"$member_id"`
					typeset shell_id=`format_shellvar \
						"$scsi_id"`
					eval MEMBER_${shell_id}_hg=""
					stmfadm_remove_info hg-member \
						-g $object_id $member_id
				done
				eval HG_${object_id}_member=""
			fi


				
		fi
	;;
	"tg")
		echo "${G_TG}" | grep -w $object_id > /dev/null 2>&1
		if [ $? -eq 0 ];then
			eval tg_list="\$TG_${object_id}_guid"
			if [ -z $tg_list ];then
				G_TG=`echo $G_TG | sed -e "s/\<$object_id\>//g"\
					| sed 's/^ *//g'`
				eval TG_${object_id}_member="\${TG_${object_id}_member:=''}"
				eval member_tglist="\$TG_${object_id}_member"
				member_tglist=`trunc_space "$member_tglist"`
				typeset member_id
				for member_id in $member_tglist
				do
					typeset scsi_id=`format_scsiname \
						"$member_id"`
					typeset shell_id=`format_shellvar \
						"$scsi_id"`
					eval MEMBER_${shell_id}_tg=""
					stmfadm_remove_info tg-member -g \
						$object_id $member_id					
				done
				eval TG_${object_id}_member=""
			fi
		fi
	;;
	*)
		cti_report "unknow object - $object"
	;;
	esac
}

#
# NAME
#	stmfadm_add_info
# DESCRIPTION
# 	Add information about stored objects based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function stmfadm_add_info 
{
	typeset object=$1
	shift 1

	case "$object" in
	"hg-member")
	
		while getopts g: a_option
		do
			case $a_option in
			g) 
				hg_id=$OPTARG
			;;
			*)
				cti_report "stmfadm_add_info: "\
					"unknow option - $a_option"
			;;
			esac
		done

		shift 2
		member_id_iter=$*

		echo "${G_HG}" | grep -w $hg_id > /dev/null 2>&1
		if [ $? -eq 0 ];then
			eval HG_${hg_id}_member="\${HG_${hg_id}_member:=''}"
			eval hg_memberlist="\$HG_${hg_id}_member"
			typeset member_id			
			for member_id in $member_id_iter
			do
				typeset scsi_id=`format_scsiname "$member_id"`
				typeset shell_id=`format_shellvar "$scsi_id"`
				eval MEMBER_${shell_id}_hg="\${MEMBER_${shell_id}_hg:=''}"
				
				eval member_hglist="\$MEMBER_${shell_id}_hg"
				if [ -z $member_hglist ];then
					eval MEMBER_${shell_id}_hg=\"$hg_id\"
				else
					continue
				fi
					
				echo $hg_memberlist | grep $scsi_id \
					>/dev/null 2>&1
				if [ $? -ne 0 ] ; then
					eval HG_${hg_id}_member=\"$scsi_id \$HG_${hg_id}_member\"	
				fi				
			done			
		fi
	;;
	"tg-member")
		while getopts g: a_option
		do
			case $a_option in
			g) 
				tg_id=$OPTARG
			;;
			*)
				cti_report "stmfadm_add_info: "\
					"unknow option - $a_option"
			;;
			esac
		done

		shift 2
		member_id_iter=$*
		
		echo "${G_TG}" | grep -w $tg_id > /dev/null 2>&1
		if [ $? -eq 0 ];then
			eval TG_${tg_id}_member="\${TG_${tg_id}_member:=''}"
			eval tg_memberlist="\$TG_${tg_id}_member"
			typeset member_id			
			for member_id in $member_id_iter
			do
				typeset scsi_id=`format_scsiname "$member_id"`
				typeset shell_id=`format_shellvar "$scsi_id"`
				eval MEMBER_${shell_id}_tg="\${MEMBER_${shell_id}_tg:=''}"

				eval target_online="\${TARGET_${shell_id}_ONLINE}"
				oper_tgmember_allowed "add" "$target_online"
				if [ $? -ne 0 ]; then
					continue
				fi
				
				eval member_tglist="\$MEMBER_${shell_id}_tg"
				if [ -z $member_tglist ];then
					eval MEMBER_${shell_id}_tg=\"$tg_id\"
				else
					continue
				fi
					
				echo $tg_memberlist | grep $scsi_id \
					>/dev/null 2>&1
				if [ $? -ne 0 ] ; then
					eval TG_${tg_id}_member=\"$scsi_id \$TG_${tg_id}_member\"	
				fi				
			done			
		fi
	;;
	"view")
		unset lu_id
		unset tg_id
		unset hg_id
		lun_specified=1
		while getopts n:t:h: a_option
		do
			case $a_option in
			n) 
				lun_id=$OPTARG
				lun_specified=0
			;;
			t) 
				tg_id=$OPTARG
			;;
			h) 
				hg_id=$OPTARG
			;;
			*)
				cti_report "stmfadm_add_info: "\
					"unknow option - $a_option"
			;;
			esac
		done
		tg_id=${tg_id:="All"}
		hg_id=${hg_id:="All"}

		
		eval typeset guid=\${$#}

		typeset guid_found=1
		for vol in $G_VOL
		do
			eval t_guid="\$LU_${vol}_GUID"
			if [ "$t_guid" = "$guid" ];then
				guid_found=0
			fi
		done			

		if [ $guid_found -ne 0 ];then
			typeset -u t_guid=$guid
			eval LU_${t_guid}_ONLINE=N
		fi
		
		# initialize the variable once
		eval VIEW_${guid}_entry="\${VIEW_${guid}_entry:=''}"
		eval HG_${hg_id}_guid="\${HG_${hg_id}_guid:=''}"			
		eval TG_${tg_id}_guid="\${TG_${tg_id}_guid:=''}"
		
		eval LUN_${hg_id}_${tg_id}="\${LUN_${hg_id}_${tg_id}:=''}"
		eval LUN_All_${tg_id}="\${LUN_All_${tg_id}:=''}"
		eval LUN_${hg_id}_All="\${LUN_${hg_id}_All:=''}"
		eval LUN_All_All="\${LUN_All_All:=''}"
		
		eval entry_list="\$VIEW_${guid}_entry"
		eval hg_list="\$HG_${hg_id}_guid"
		hg_list=`trunc_space "$hg_list"`
		eval tg_list="\$TG_${tg_id}_guid"		
		tg_list=`trunc_space "$tg_list"`
		
		if [ -z "$entry_list" ];then
						
			create_view_entry "$lun_specified" \
				"$tg_id" "$hg_id" "$guid" "$lun_id"
			if [ $? -eq 1 ];then
				return
			fi
		else
			
			add_view_entry "$lun_specified" \
				"$entry_list" "$tg_id" "$hg_id" "$guid" \
				"$lun_id"
			if [ $? -eq 1 ];then
				return
			fi
			
		fi
	;;
	*)
		cti_report "unknow object - $object"
	;;
	esac
}
#
# NAME
#	create_view_entry
# DESCRIPTION
# 	create view entry to build the view entry list of specified guid
#
# RETURN
#	0	successful
#	1	failed
function create_view_entry
{
	typeset lun_specified="$1"
	typeset tg_id="$2"
	typeset hg_id="$3"
	typeset guid="$4"
	typeset lun_id="$5"
	if [ $lun_specified -eq 0 ];then
		# with -n option, check whether target and host group 
		# combination under this specified GUID is overlapped with the 
		# input view
		# if overlapped, the input view is the definite conflict, fail
		# if no overlapped, chech whether the input LU number is 
		# belonged to LU number in all GUIDs' target and host group 
		# combination despite of this specified GUID.
		# if belonged, the LU number can not be used, the input view is 
		# in conflict, fail
		# else, the input view is added.
		if [ $lun_id -ge 16384 ]; then
			return 
		fi
		if [ "$hg_id" != "All" -a "$tg_id" != "All" ];then
			for t_tg_id in $tg_id All
			do
				eval hgtg_lun="\$LUN_${hg_id}_${t_tg_id}"
				echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
				if [ $? -eq 0 ];then
					return
				fi
			done
			for t_hg_id in $hg_id All
			do
				eval hgtg_lun="\$LUN_${t_hg_id}_${tg_id}"
				echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
				if [ $? -eq 0 ];then
					return
				fi
			done
			eval hgtg_lun="\$LUN_All_All"
			echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
			if [ $? -eq 0 ];then
				return
			fi
		elif [	"$hg_id" != "All" -a "$tg_id" = "All" ];then
			for t_tg_id in $G_TG All
			do
				eval hgtg_lun="\$LUN_${hg_id}_${t_tg_id}"
				echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
				if [ $? -eq 0 ];then
					return
				fi
			done
			eval hgtg_lun="\$LUN_All_All"
			echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
			if [ $? -eq 0 ];then
				return
			fi
		elif [ "$hg_id" = "All" -a "$tg_id" != "All" ];then
			for t_hg_id in $G_HG All
			do
				eval hgtg_lun="\$LUN_${t_hg_id}_${tg_id}"
				echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
				if [ $? -eq 0 ];then
					return
				fi
			done
			eval hgtg_lun="\$LUN_All_All"
			echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
			if [ $? -eq 0 ];then
				return
			fi
		else
			for t_hg_id in $G_HG All
			do	
				for t_tg_id in $G_TG All
				do
					eval hgtg_lun="\$LUN_${t_hg_id}_${t_tg_id}"
					echo $hgtg_lun | grep -w $lun_id \
						>/dev/null 2>&1
					if [ $? -eq 0 ];then
						return
					fi
				done
			done
		fi
		eval hgtg_lun="\$LUN_${hg_id}_${tg_id}"		
		eval LUN_${hg_id}_${tg_id}=\"$lun_id $hgtg_lun\"
		$STMFADM list-view -l $guid | grep "View Entry" | awk \
			'{print $NF}' | while read ve
		do
			echo $ve_olist | grep -w $ve >/dev/null 2>&1
			if [ $? -ne 0 ];then
				break
			fi
		done
		eval VIEW_${guid}_entry=\"$ve:$hg_id:$tg_id:$lun_id $entry_list\"		
		
		eval HG_${hg_id}_guid=\"$guid $hg_list\"
		eval TG_${tg_id}_guid=\"$guid $tg_list\"	
			
	else
		
		typeset ve=`$STMFADM list-view -l $guid | \
			grep "View Entry" | awk '{print $NF}'`
		typeset lun_id=`$STMFADM list-view -l $guid | \
			grep "LUN" | awk '{print $NF}'`
		
		eval VIEW_${guid}_entry=\"$ve:$hg_id:$tg_id:$lun_id\"
				
		if [ "$hg_id" != "All" -a "$tg_id" != "All" ];then
			eval hgtg_lun="\$LUN_${hg_id}_${tg_id}"		
		elif [	"$hg_id" != "All" -a "$tg_id" = "All" ];then
			eval hgtg_lun="\$LUN_${hg_id}_All"
		elif [ "$hg_id" = "All" -a "$tg_id" != "All" ];then
			eval hgtg_lun="\$LUN_All_${tg_id}"
		else
			eval hgtg_lun="\$LUN_All_All"
		fi
		eval LUN_${hg_id}_${tg_id}=\"$lun_id $hgtg_lun\"
		eval HG_${hg_id}_guid=\"$guid $hg_list\"
		eval TG_${tg_id}_guid=\"$guid $tg_list\"		
	fi
	return 0
}
#
# NAME
#	add_view_entry
# DESCRIPTION
# 	add view entry to build the view entry list of specified guid
#
# RETURN
#	0	successful
#	1	failed
function add_view_entry
{
	typeset lun_specified="$1"
	typeset entry_list="$2"
	typeset tg_id="$3"
	typeset hg_id="$4"
	typeset guid="$5"
	typeset lun_id="$6"
	if [ $lun_specified -eq 0 ];then
		# with -n option, check whether target and host group 
		# combination under this specified GUID is overlapped with the
		# input view. 
		# if overlapped, the input view is the definite conflict one, fail
		# if no overlapped, chech whether the input LU number is 
		# belonged to LU number in all GUIDs' target and host group 
		# combination despite of this specified GUID.
		# if belonged, the LU number can not be used, the input view is 
		# in conflict, fail
		# else, the input view is added.
		if [ $lun_id -ge 16384 ]; then
			return 1
		fi
		
		unset ve_olist
		for entry in $entry_list
		do
			t_tg_id=$tg_id
			t_hg_id=$hg_id
			
			eval hg="`echo $entry | awk -F: '{print $2}'`"
			eval tg="`echo $entry | awk -F: '{print $3}'`"
			ve_olist="`echo $entry | awk -F: '{print $1}'` $ve_olist"

			if [ "$hg" = "All" ];then
				t_hg_id=$hg
			elif [ "$t_hg_id" = "All" ];then
				hg=$t_hg_id
			elif [ "$tg" = "All" ];then
				t_tg_id=$tg
			elif [ "$t_tg_id" = "All" ];then
				tg=$t_tg_id
			fi
					
			if [ "$hg" = "t_$hg_id" -a "$tg" = "$t_tg_id" ]; then
				return 1
			fi						
		done
		if [ "$hg_id" != "All" -a "$tg_id" != "All" ];then
			for t_tg_id in $tg_id All
			do
				eval hgtg_lun="\$LUN_${hg_id}_${t_tg_id}"
				echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
				if [ $? -eq 0 ];then
					return 1
				fi
			done
			for t_hg_id in $hg_id All
			do
				eval hgtg_lun="\$LUN_${t_hg_id}_${tg_id}"
				echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
				if [ $? -eq 0 ];then
					return 1
				fi
			done
			eval hgtg_lun="\$LUN_All_All"
			echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
			if [ $? -eq 0 ];then
				return 1
			fi
		elif [	"$hg_id" != "All" -a "$tg_id" = "All" ];then
			for t_tg_id in $G_TG All
			do
				eval hgtg_lun="\$LUN_${hg_id}_${t_tg_id}"
				echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
				if [ $? -eq 0 ];then
					return 1
				fi
			done
			eval hgtg_lun="\$LUN_All_All"
			echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
			if [ $? -eq 0 ];then
				return 1
			fi
		elif [ "$hg_id" = "All" -a "$tg_id" != "All" ];then
			for t_hg_id in $G_HG All
			do
				eval hgtg_lun="\$LUN_${t_hg_id}_${tg_id}"
				echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
				if [ $? -eq 0 ];then
					return 1
				fi
			done
			eval hgtg_lun="\$LUN_All_All"
			echo $hgtg_lun | grep -w $lun_id >/dev/null 2>&1
			if [ $? -eq 0 ];then
				return 1
			fi
		else
			for t_hg_id in $G_HG All
			do	
				for t_tg_id in $G_TG All
				do
					eval hgtg_lun="\$LUN_${t_hg_id}_${t_tg_id}"
					echo $hgtg_lun | grep -w $lun_id \
						>/dev/null 2>&1
					if [ $? -eq 0 ];then
						return 1
					fi
				done
			done
		fi
		eval hgtg_lun="\$LUN_${hg_id}_${tg_id}"		
		hgtg_lun=`trunc_space "$hgtg_lun"`
		eval LUN_${hg_id}_${tg_id}=\"$lun_id $hgtg_lun\"
		$STMFADM list-view -l $guid | grep "View Entry" | \
			awk '{print $NF}' | while read ve
		do
			echo $ve_olist | grep -w $ve >/dev/null 2>&1
			if [ $? -ne 0 ];then
				break
			fi
		done
		eval VIEW_${guid}_entry=\"$ve:$hg_id:$tg_id:$lun_id $entry_list\"		
		
		eval HG_${hg_id}_guid=\"$guid $hg_list\"
		eval TG_${tg_id}_guid=\"$guid $tg_list\"		
	else
		# without -n option, check whether target and host group 
		# combination under this specified GUID is overlapped with the 
		# input view
		# if no overlapped, the input view is not in conflict, the view 
		# is added with default LU number
		# if overlapped, the input view is the definite conflict one, 
		# fail
		typeset conflict=1
		unset ve_olist
		for entry in $entry_list
		do
			t_tg_id=$tg_id
			t_hg_id=$hg_id
			
			eval hg="`echo $entry | awk -F: '{print $2}'`"
			eval tg="`echo $entry | awk -F: '{print $3}'`"
			ve_olist="`echo $entry | awk -F: '{print $1}'` $ve_olist"

			if [ "$hg" = "All" ];then
				t_hg_id=$hg
			elif [ "$t_hg_id" = "All" ];then
				hg=$t_hg_id
			elif [ "$tg" = "All" ];then
				t_tg_id=$tg
			elif [ "$t_tg_id" = "All" ];then
				tg=$t_tg_id
			fi
			
			if [ "$hg" = "$t_hg_id" -a "$tg" = "$t_tg_id" ]; then
				return 1
			fi						
		done
		$STMFADM list-view -l $guid | grep "View Entry" | awk \
			'{print $NF}' | while read ve
		do
			echo $ve_olist | grep -w $ve >/dev/null 2>&1
			if [ $? -ne 0 ];then
				break
			fi
		done
		$STMFADM list-view -l $guid | awk '{print $NF}' | awk \
			'{if (NR%4==0) printf("%s\n",$0);else printf("%s:",$0);}'\
			| while read line
		do
			echo $line | grep ":$hg_id:$tg_id:" >/dev/null 2>&1
			if [ $? -eq 0 ];then
				lun_id=`echo $line | awk -F: '{print $4}'`
				break
			fi
		done
		eval VIEW_${guid}_entry=\"$ve:$hg_id:$tg_id:$lun_id $entry_list\"			
		
		if [ "$hg_id" != "All" -a "$tg_id" != "All" ];then
			eval hgtg_lun="\$LUN_${hg_id}_${tg_id}"		
		elif [	"$hg_id" != "All" -a "$tg_id" = "All" ];then
			eval hgtg_lun="\$LUN_${hg_id}_All"
		elif [ "$hg_id" = "All" -a "$tg_id" != "All" ];then
			eval hgtg_lun="\$LUN_All_${tg_id}"
		else
			eval hgtg_lun="\$LUN_All_All"
		fi
		eval LUN_${hg_id}_${tg_id}=\"$lun_id $hgtg_lun\"
		eval HG_${hg_id}_guid=\"$guid $hg_list\"
		eval TG_${tg_id}_guid=\"$guid $tg_list\"						

	fi
	return 0
}

#
# NAME
#	stmfadm_remove_info
# DESCRIPTION
# 	Remove information about stored objects based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function stmfadm_remove_info 
{
	typeset object=$1
	shift 1

	case "$object" in
	"hg-member")
	
		while getopts g: r_option
		do
			case $r_option in
			g) 
				hg_id=$OPTARG
			;;
			*)
				cti_report "stmfadm_remove_info: "\
					"unknow option - $r_option"
			;;
			esac
		done

		shift 2
		member_id_iter=$*

		echo "${G_HG}" | grep -w $hg_id > /dev/null 2>&1
		if [ $? -eq 0 ];then
			eval HG_${hg_id}_member="\${HG_${hg_id}_member:=''}"
			eval hg_memberlist="\$HG_${hg_id}_member"
			typeset member_id						
			for member_id in $member_id_iter
			do
				typeset scsi_id=`format_scsiname "$member_id"`
				typeset shell_id=`format_shellvar "$scsi_id"`

				eval MEMBER_${shell_id}_hg="\${MEMBER_${shell_id}_hg:=''}"
				
				eval member_hglist="\$MEMBER_${shell_id}_hg"
				member_hglist=`trunc_space "$member_hglist"`
				if [ "$member_hglist" = "$hg_id" ];then
					eval unset MEMBER_${shell_id}_hg
				else
					continue
				fi
					
				echo $hg_memberlist | grep $scsi_id \
					>/dev/null 2>&1
				if [ $? -eq 0 ] ; then
					eval HG_${hg_id}_member=\"`echo \
						$hg_memberlist | \
						sed -e "s/\<$scsi_id\>//" | \
						sed 's/^ *//g'`\"
				fi				
			done			
		fi
	;;
	"tg-member")
		while getopts g: r_option
		do
			case $r_option in
			g) 
				tg_id=$OPTARG
			;;
			*)
				cti_report "stmfadm_add_info: "\
					"unknow option - $r_option"
			;;
			esac
		done

		shift 2
		member_id_iter=$*

		echo "${G_TG}" | grep -w $tg_id > /dev/null 2>&1
		if [ $? -eq 0 ];then
			# initialize the variable once
			eval TG_${tg_id}_member="\${TG_${tg_id}_member:=''}"
			# get the variable value for usage
			eval tg_memberlist="\$TG_${tg_id}_member"
			typeset member_id			
			for member_id in $member_id_iter
			do
				typeset scsi_id=`format_scsiname "$member_id"`
				typeset shell_id=`format_shellvar "$scsi_id"`

				eval target_online="\${TARGET_${shell_id}_ONLINE}"
				oper_tgmember_allowed "remove" "$target_online"
				if [ $? -ne 0 ]; then
					continue
				fi

				#initialize the member group info
				eval MEMBER_${shell_id}_tg="\${MEMBER_${shell_id}_tg:=''}"
				
				# get the variable value for usage
				eval member_tglist="\$MEMBER_${shell_id}_tg"
				member_tglist=`trunc_space "$member_tglist"`
				if [ "$member_tglist" = "$tg_id" ];then
					eval unset MEMBER_${shell_id}_tg
				else
					continue
				fi
					
				echo $tg_memberlist | grep $scsi_id \
					>/dev/null 2>&1
				if [ $? -eq 0 ] ; then
					eval TG_${tg_id}_member=\"`echo $tg_memberlist | \
						sed -e "s/\<$scsi_id\>//" | \
						sed 's/^ *//g'`\"
				fi				
			done			
		fi
	;;
	"view")
		while getopts al: r_option
		do
			case $r_option in
			l) 
				guid=$OPTARG
			;;
			a) 
				
			;;
			*)
				cti_report "stmfadm_remove_info: "\
					"unknow option - $r_option"
			;;
			esac
		done
		
		shift 2
		ve_id_iter=$*

		typeset guid_found=1
		typeset vol
		for vol in $G_VOL
		do
			eval t_guid="\$LU_${vol}_GUID"
			if [ "$t_guid" = "$guid" ];then
				guid_found=0
				break
			fi
		done			
		if [ "$guid" != "-a" ];then
			eval entry_list="\$VIEW_${guid}_entry"	
			if [ -n "$entry_list" ] ;then
				guid_found=0
				break
			fi
		fi		
		if [ $guid_found -eq 0 ];then
			# initialize the variable once
			eval VIEW_${guid}_entry="\${VIEW_${guid}_entry:=''}"
			eval HG_${hg_id}_guid="\${HG_${hg_id}_guid:=''}"			
			eval TG_${tg_id}_guid="\${TG_${tg_id}_guid:=''}"

			eval entry_list="\$VIEW_${guid}_entry"
			eval hg_list="\$HG_${hg_id}_guid"
			eval tg_list="\$TG_${tg_id}_guid"		
			if [ -n "$entry_list" ];then
				delete_view_entry $# "$entry_list" "$ve_id_iter"
			fi
		fi	
	;;
	*)
		cti_report "unknow object - $object"
	;;
	esac
}
#
# NAME
#	delete_view_entry
# DESCRIPTION
# 	delete view entry to rebuild the view entry list of specified guid
#
# RETURN
#	0	successful
#	1	failed

function delete_view_entry
{
	typeset num=$1
	typeset entry_list="$2"
	typeset ve_id_iter="$3"
	if [ $num -eq 1 -a "$ve_id_iter" = "-a" ];then
		for entry in $entry_list
		do
			typeset ve=`echo $entry | awk -F: '{print $1}'` 
			eval hg_id=`echo $entry | awk -F: '{print $2}'` 
			eval tg_id=`echo $entry | awk -F: '{print $3}'` 
			eval lun_id=`echo $entry | awk -F: '{print $4}'` 
				
			eval hg_list="\$HG_${hg_id}_guid"
			eval tg_list="\$TG_${tg_id}_guid"		
				
			if [ "$hg_id" != "All" -a "$tg_id" != "All" ];then
				eval hgtg_lun="\$LUN_${hg_id}_${tg_id}"		
			elif [	"$hg_id" != "All" -a "$tg_id" = "All" ];then
				eval hgtg_lun="\$LUN_${hg_id}_All"
			elif [ "$hg_id" = "All" -a "$tg_id" != "All" ];then
				eval hgtg_lun="\$LUN_All_${tg_id}"
			else
				eval hgtg_lun="\$LUN_All_All"
			fi
			eval LUN_${hg_id}_${tg_id}=\"`echo $hgtg_lun | \
				sed -e "s/\<$lun_id\>//" | sed 's/^ *//g'`\"
			eval HG_${hg_id}_guid=\"`echo $hg_list | \
				sed -e "s/\<$guid\>//g" | sed 's/^ *//g'`\"
			eval TG_${tg_id}_guid=\"`echo $tg_list | \
				sed -e "s/\<$guid\>//g" | sed 's/^ *//g'`\"
			
			eval unset VIEW_${guid}_entry
		done
	else
		for entry in $entry_list
		do
			typeset ve=`echo $entry | awk -F: '{print $1}'` 
			echo $ve_id_iter | grep $ve >/dev/null 2>&1
			if [ $? -eq 0 ];then
				eval hg_id=`echo $entry | awk -F: '{print $2}'` 
				eval tg_id=`echo $entry | awk -F: '{print $3}'` 
				eval lun_id=`echo $entry | awk -F: '{print $4}'` 

				eval hg_list="\$HG_${hg_id}_guid"
				eval tg_list="\$TG_${tg_id}_guid"		
				eval t_entry_list="\$VIEW_${guid}_entry"
				eval VIEW_${guid}_entry=\"`echo $t_entry_list |\
					sed -e "s/\<$entry\>//" | \
					sed 's/^ *//g'`\"
							
				if [ "$hg_id" != "All" -a \
					"$tg_id" != "All" ];then
					eval hgtg_lun="\$LUN_${hg_id}_${tg_id}"		
				elif [	"$hg_id" != "All" -a \
					"$tg_id" = "All" ];then
					eval hgtg_lun="\$LUN_${hg_id}_All"
				elif [ "$hg_id" = "All" -a \
					"$tg_id" != "All" ];then
					eval hgtg_lun="\$LUN_All_${tg_id}"
				else
					eval hgtg_lun="\$LUN_All_All"
				fi
				eval LUN_${hg_id}_${tg_id}=\"`echo $hgtg_lun | \
					sed -e "s/\<$lun_id\>//" | \
					sed 's/^ *//g'`\"
				eval HG_${hg_id}_guid=\"`echo $hg_list | \
					sed -e "s/\<$guid\>//" | \
					sed 's/^ *//g'`\"
				eval TG_${tg_id}_guid=\"`echo $tg_list | \
					sed -e "s/\<$guid\>//" | \
					sed 's/^ *//g'`\"
			fi
		done
	fi
}
#
# NAME
#	stmfadm_online_info
# DESCRIPTION
# 	Store information about online objects based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function stmfadm_online_info 
{
	typeset object=$1
	shift 1

	check_stmf_disable
	if [ $? -eq 0 ];then
		return
	fi
	case "$object" in
	"lu")
		member_id_iter=$*
		for member_id in $member_id_iter
		do
			typeset -i found=0
			typeset vol
			for vol in $G_VOL
			do
				eval typeset t_guid=\$LU_${vol}_GUID
				if [ "$t_guid" = "$member_id" ];then
					found=1
					break
				fi
			done
			if [ $found -eq 1 ];then
				eval typeset -u u_guid=$member_id
				eval LU_${u_guid}_ONLINE=Y
			fi
		done
	;;
	"target")
		member_id_iter=$*
		typeset member_id
		for member_id in $member_id_iter
		do
			typeset scsi_id=`format_scsiname "$member_id"`
			typeset shell_id=`format_shellvar "$scsi_id"`
			echo $G_TARGET | grep $scsi_id >/dev/null 2>&1
			if [ $? -eq 0 ];then
				eval TARGET_${shell_id}_ONLINE=Y
			fi
		done
	;;
	esac
}

#
# NAME
#	stmfadm_offline_info
# DESCRIPTION
# 	Store information about offline objects based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function stmfadm_offline_info 
{
	typeset object=$1
	shift 1

	case "$object" in
	"lu")
		member_id_iter=$*
		for member_id in $member_id_iter
		do
			typeset -i found=0
			typeset vol
			for vol in $G_VOL
			do
				eval typeset t_guid=\$LU_${vol}_GUID
				if [ "$t_guid" = "$member_id" ];then
					found=1
					break
				fi
			done
			if [ $found -eq 1 ];then
				eval typeset -u u_guid=$member_id
				eval LU_${u_guid}_ONLINE=N
			fi
		done
	;;
	"target")
		member_id_iter=$*
		typeset member_id
		for member_id in $member_id_iter
		do
			typeset scsi_id=`format_scsiname "$member_id"`
			typeset shell_id=`format_shellvar "$scsi_id"`
			echo $G_TARGET | grep $scsi_id >/dev/null 2>&1
			if [ $? -eq 0 ];then
				eval TARGET_${shell_id}_ONLINE=N
			fi
		done
	;;
	esac
}

#
# NAME
#	oper_tgmember_allowed 
#
# SYNOPSIS
#	oper_tgmember_allowed <oper> <target_state>
#	[ options for 'add[remove] Y[N]' ]
#
# DESCRIPTION
#	Check whether stmfadm add/remove tg-member operation can be allowed
#
# RETURN
#	0 - the specified operation is allowed
#	1 - the specified operation is denied
function oper_tgmember_allowed
{
	typeset oper=$1
	typeset target_online=$2
	case "$TARGET_TYPE" in
	"ISCSI")
		check_stmf_disable
		typeset res1=$?
		check_iscsi_target_disable
		typeset res2=$?
		if [ "$oper" = "add" ];then
			return 0
		else
			if [ $res1 -ne 0 -a $res2 -ne 0\
			    -a "$target_online" = "Y" ];then
				return 1
			else
				return 0
			fi

		fi
	;;
	*)
		check_stmf_disable
		typeset res=$?
		if [ "$oper" = "add" ];then
			return 0
		else
			if [ $res -ne 0 -a "$target_online" = "Y" ];then
				return 1
			else
				return 0
			fi
		fi
	;;
	esac
}


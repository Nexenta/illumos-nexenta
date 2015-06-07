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
#	sbdadm_create_info
# DESCRIPTION
# 	Store information about stored objects based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function sbdadm_create_info 
{
	typeset option=$*
	while getopts s: option
	do
		case $option in
			s)	
				typeset size=$OPTARG
				;;
			*)
				cti_fail "FAIL - unknow option - $option"
				;;
		esac
	done
	
	eval typeset object=\${$#}
	typeset synopsis=`basename $object`
	echo "${G_VOL}" |grep -w $synopsis >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		G_VOL="$synopsis $G_VOL"
	fi

	echo $size | grep -i k >/dev/null 2>&1
	if [ $? -eq 0 ];then
		num=`echo $size |sed "s/k//g"`
		(( bytes=$num*1024))
	fi
	echo $size | grep -i m >/dev/null 2>&1
	if [ $? -eq 0 ];then
		num=`echo $size |sed "s/m//g"`
		(( bytes=$num*1048576))
	fi
	echo $size | grep -i g >/dev/null 2>&1
	if [ $? -eq 0 ];then
		num=`echo $size |sed "s/g//g"`
		(( bytes=$num*1073741824))
	fi
	echo $size | grep -i t >/dev/null 2>&1
	if [ $? -eq 0 ];then
		num=`echo $size |sed "s/t//g"`
		(( bytes=$num*1099511627776))
	fi
	eval typeset object=\${$#}		
	typeset synopsis=`basename $object`
	
	eval LU_${synopsis}_SOURCE="$object"
	eval LU_${synopsis}_SIZE="$bytes"
	eval LU_${synopsis}_GUID="`$SBDADM list-lu | \
		grep $object | awk '{print \$1}'`"
	eval LU_${synopsis}_IM_SIZE="$bytes"	
	eval LU_${synopsis}_IM_GUID="`$SBDADM list-lu | \
		grep $object  | awk '{print \$1}'`"	

	eval typeset -u u_guid="\$LU_${synopsis}_GUID"
	eval LU_${u_guid}_ONLINE=Y
}

#
# NAME
#	sbdadm_modify_info
# DESCRIPTION
# 	Modify information about modified objects based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function sbdadm_modify_info 
{
	typeset option=$*
	while getopts s: option
	do
		case $option in
			s)	
				typeset size=$OPTARG
				;;
			*)
				cti_fail "FAIL - unknow option - $option"
				;;
		esac
	done
	eval typeset object=\${$#}
	typeset synopsis=`basename $object`
	if [ "$object" = "$synopsis" ];then
		#it's GUID input
		for vol in $G_VOL
		do
			eval typeset t_guid=\$LU_${vol}_GUID
			if [ "$t_guid" = "$object" ];then
				object=$vol
				break
			fi
		done
	else
		#it's file full path input
		object=$synopsis
	fi

	echo $size | grep -i k >/dev/null 2>&1
	if [ $? -eq 0 ];then
		num=`echo $size |sed "s/k//g"`
		(( bytes=$num*1024))
	fi
	echo $size | grep -i m >/dev/null 2>&1
	if [ $? -eq 0 ];then
		num=`echo $size |sed "s/m//g"`
		(( bytes=$num*1048576))
	fi
	echo $size | grep -i g >/dev/null 2>&1
	if [ $? -eq 0 ];then
		num=`echo $size |sed "s/g//g"`
		(( bytes=$num*1073741824))
	fi
	echo $size | grep -i t >/dev/null 2>&1
	if [ $? -eq 0 ];then
		num=`echo $size |sed "s/t//g"`
		(( bytes=$num*1099511627776))
	fi
	eval LU_${object}_SIZE="$bytes"
	eval LU_${object}_IM_SIZE="$bytes"	

}

#
# NAME
#	sbdadm_delete_info
# DESCRIPTION
# 	Delete information about deleted objects based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function sbdadm_delete_info 
{
	typeset option=$*
	typeset keep_view=0
	while getopts k option
	do
		case $option in
			k)	
				typeset keep_view=1
				;;
			*)
				cti_fail "FAIL - unknow option - $option"
				;;
		esac
	done
	eval typeset guid=\${$#}
	typeset vol
	for vol in $G_VOL
	do
	
		eval typeset guid_iter=\$LU_${vol}_GUID
		if [ "$guid" = "$guid_iter" ];then
			if [ $keep_view -eq 0 ];then
				stmfadm_remove_info view -l $guid -a
			fi
			eval unset LU_${vol}_SOURCE
			eval unset LU_${vol}_SIZE
			eval unset LU_${vol}_GUID
			echo "${G_VOL}" |grep -w $vol >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				G_VOL=`echo $G_VOL | sed -e "s/\<$vol\>//g" | \
					sed 's/^ *//g'`
				typeset -u u_guid=$guid
				eval LU_${u_guid}_ONLINE=N
			fi		
			if [ $keep_view -eq 1 ];then
				compare_lu_view $guid
			fi
		fi
	done

}

#
# NAME
#	sbdadm_import_info
# DESCRIPTION
# 	Store information about stored objects based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function sbdadm_import_info 
{
	typeset option=$*
	
	eval typeset object=\${$#}
	typeset synopsis=`basename $object`
	echo "${G_VOL}" |grep -w $synopsis >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		G_VOL="$synopsis $G_VOL"
	fi

	eval LU_${synopsis}_SOURCE="$object"
	eval LU_${synopsis}_SIZE=\$LU_${synopsis}_IM_SIZE
	eval LU_${synopsis}_GUID=\$LU_${synopsis}_IM_GUID

	eval typeset -u u_guid="\$LU_${synopsis}_GUID"
	eval LU_${u_guid}_ONLINE=Y
}



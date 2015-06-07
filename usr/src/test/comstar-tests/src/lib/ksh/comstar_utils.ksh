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
#	random_string
#
# DESCRIPTION
# 	build a string with specified length which is consist of number and character
#
# RETURN
#	void
#
function random_string
{	
	max=$1
	index=0
	set -A CHARS 0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z
	len=${#CHARS[@]}
	(( max-=1 ))
	while [ $index -lt $max ]
	do
	        seed=`expr $RANDOM % $len`
	        printf "%c" ${CHARS[$seed]}
	        (( index+=1 ))
	done
}

#
# NAME
#	format_scsi
#
# DESCRIPTION
# 	build a string with iscsi name, wwn name which is used as group member
#
# RETURN
#	return the scsi name
#
function format_scsiname
{	
	typeset input=$*

	echo "$input" | grep "=" >/dev/null 2>&1
	if [ $? -eq 0 ];then
		prefix=`echo "$input" | cut -d= -f1`
		rest=`echo "$input" | cut -d= -f2-`
		if [ "$prefix" = "wwn" ];then
			typeset -u wwn=$rest
			scsi_name=wwn.$wwn

		elif [ "$prefix" = "iscsi" ];then
			scsi_name=$rest
		else
			scsi_name=""
		fi
	else
		prefix=`echo "$input" |cut -d. -f1`
		rest=`echo "$input" | cut -d. -f2-`
		if [ "$prefix" = "eui" ];then
			typeset -u eui=$rest
			scsi_name=eui.$eui
		elif [ "$prefix" = "iqn" ];then
			typeset -l iqn=$rest
			scsi_name=iqn.$iqn
		elif [ "$prefix" = "wwn" ];then
			typeset -u wwn=$rest
			scsi_name=wwn.$wwn
		else
			scsi_name=""
		fi
	fi
	echo $scsi_name
}


#
# NAME
#	format_shellvar
#
# DESCRIPTION
# 	transform the string to the appropriate shell variable name to be recognized.
#
# RETURN
#	void
#
function format_shellvar
{
	typeset input=$*
	shell_var=`echo "$input" | sed -e 's/[-:{},.]/_/g'`
	echo $shell_var
}

#
# NAME
#	trunc_space
#
# DESCRIPTION
# 	delete the extra spaces in the front and back of string
#
# RETURN
#	void
#
function trunc_space
{
	typeset -L input=$*
	typeset -R input=$input
	echo $input
}


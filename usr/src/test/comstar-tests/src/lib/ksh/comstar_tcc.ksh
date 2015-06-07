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
#       tp_export_tc
# DESCRIPTION
#       export the variable in test purpse to test case for 
#	the following test purpose usage.
# ARGUMENT
#	$* variable names which to be attempted to export 
#	to parent shell environment.
# RETURN
#       void
#
TP_ENV=$LOGDIR/tp.env
function tp_export_tc
{
	: > $TP_ENV
	varname=$*
	for varname in $*
	do
		eval typeset val="\$$varname"
		echo $varname=\"$val\" >> $TP_ENV
	done
}
#
# NAME
#       tc_load_tp
# DESCRIPTION
#       load the output of test purpose to initialize 
#	the environmental variables of test case.
# ARGUMENT
#	  void
# RETURN
#       void
#
function tc_load_tp
{
	test ! -s $TP_ENV && return
	grep -v '^#' $TP_ENV | while read line
	do
		typeset var=$(echo "$line" | cut -d= -f1)
		typeset val=$(echo "$line" | cut -d= -f2-)
		export $var="$val"
	done
	test -f $TP_ENV && rm -rf $TP_ENV 
}



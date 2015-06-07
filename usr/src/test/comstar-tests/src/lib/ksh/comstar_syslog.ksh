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

MSGFILE_HOST_FILE=/var/adm/messages
#
# NAME
#	msgfile_mark()
# DESCRIPTION
#	This function may be used by test cases to mark the beginning and 
#	end of the output recorded in the /var/adm/messages file of the
#	host specified by the HOSTNAME global.
#
# ARGUMENT
#	$1 - HOSTNAME
#	$2 - START | STOP
#	$3 - unique label
#
# RETURN
#	1 - unexpected argument (!START | !STOP)
#	0 - normal argument
#
function msgfile_mark
{
        typeset HOSTNAME=$1
        if [ "$2" == "START" ]; then
                run_rsh_cmd $HOSTNAME \
			"echo START___$3___$$___>> $MSGFILE_HOST_FILE"  
        elif [ "$2" == "STOP" ]; then
                run_rsh_cmd $HOSTNAME \
			"echo STOP___$3___$$___>> $MSGFILE_HOST_FILE"  
        else
                cti_report "WARNING: msgfile_mark: unexpected arg ($2)"
                return 1
        fi
        return 0
}

#
# NAME
#	msgfile_extract()
# DESCRIPTION
#	This function saves the contents of /var/adm/messages, as marked
#	by previous calls to msgfile_mark, from the host specified by the
#	HOSTNAME global variable to the file specified
#
#	Th $1 parameter must be a unique label in order to get the 
#	window expected.  If the same label was used previously, this
#	function will also save that window as well.
#
# ARGUMENT
#	$1 - unique label used to mark msgfile 
#	$2 - output file (full path/filename)
#
# RETURN
#	void
#
function msgfile_extract
{
	typeset HOSTNAME=$1
	typeset cmd="sed -n '/START___'\"$2\"'___'\"$$\"'___/"
	cmd="${cmd},/STOP___'\"$2\"'___'\"$$\"'___/p' $MSGFILE_HOST_FILE"
	run_rsh_cmd $HOSTNAME "$cmd"
	cp $CMD_STDOUT $LOGDIR_TCCDLOG/message.$1.$2
	cti_report "INFO - /var/adm/message on host $HOSTNAME "\
		"is stored at $LOGDIR_TCCDLOG/message.$1.$2"
}



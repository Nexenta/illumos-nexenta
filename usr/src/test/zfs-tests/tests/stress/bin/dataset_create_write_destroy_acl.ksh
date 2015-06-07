#!/usr/bin/ksh -p
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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)dataset_create_write_destroy_acl.ksh	1.3	07/10/09 SMI"
#

#
# create a truckload of files with ACLS and destroy them.
# Theoretically this test case should also verify that the storage
# pool space has not been diminished by this operation.
# @parameter: $1 the storage pool from which it draws the file systems.
# @return: 0 if all the work completed OK.
# @use: TEST_BASE_DIR TOTAL_COUNT ZFS RM MKDIR CP GETENT
# 

typeset -i runat=0
typeset -i scaledcount
typeset dataset=$1
typeset ddirb=${TEST_BASE_DIR%%/}/acld.$$
typeset runpids=
typeset tfilesys=
typeset tmountpoint=

if [[ -z $dataset ]]; then
	NOTE "$fn: Insufficient parameters (need 1, got $#)"
	exit 1
fi

(( scaledcount = TOTAL_COUNT * 100 ))

function clean_entities
{
	[[ -n $runpids ]] && kill -9 $runpids
	[[ -d $tmountpoint ]] && $ZFS umount -f $tmountpoint
	[[ -n $tfilesys ]] && $ZFS destroy -f $tfilesys
	$RM -rf $tmountpoint $ddirb
}

log_onexit clean_entities

USE_F=""
while (( runat < scaledcount )); do
	typeset -i pid=
	typeset file=
	typeset group=
	typeset user=

	tfilesys=$dataset/$runat
	file=$mountpoint/file.$runat

	log_must $MKDIR -p $tmountpoint
	log_must $ZFS create $tfilesys
	log_must $ZFS mountpoint=$tmountpoint $tfilesys
	log_must $CP /etc/passwd $file

	for user in $($GETENT passwd | $AWK -F: '{print $1}'); do
		chmod A=user:$user:r--,user::rwx,group::r--,other::r--,mask:r--\
		 $file &
		runpids="$runpids $!"
	done
	for pid in $runpids; do
		wait $pid
		status=$?
		if (( status != 0 )); then
			log_note "chmod users: failed on $file " \
				"[$status]"
		fi
	done
	runpids=
	for group in $($GETENT groups | $AWK -F: '{print $1}'); do
	      chmod A=user::rwx,group:$group:r--,group::r--,other::r--,mask:r--\
	      $file &
		runpids="$runpids $!"
	done
	for pid in $runpids; do
		wait $pid
		status=$?
		if (( status != 0 )); then
			log_note "chmod groups: failed on $file" \
				" [$status]"
		fi
	done
	runpids=

	log_must $RM -f $file
        #
        # Does a forced unmount every second iteration
        #
        if [[ -n $USE_F ]] ; then
                USE_F=""
        else
                USE_F="-f"
        fi
	
	log_must $ZFS umount $USE_F $tmountpoint
	log_must $ZFS destroy $tfilesys
	log_must $RM -rf $tmountpoint

	tmountpoint=
	(( runat = runat + 1 ))
done

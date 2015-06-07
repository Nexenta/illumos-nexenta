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
# ident	"@(#)dataset_create_write_destroy_exattr.ksh	1.2	07/01/09 SMI"
#

#	Assertion: That creating and destroying datasets with
#	files that have attributes do not cause the depletion of
#	the storage pool space.
# @parameter: $1 the pool from which to draw the test file systems
# @return: 0 if all the work completed OK.
# @use: TOTAL_COUNT log_note log_assert ZFS MKDIR RM

. ${STF_SUITE}/include/libtest.shlib

typeset -i child=0
typeset -i count=0
typeset -i failures=0
typeset -i i=0
typeset dataset=$1
typeset ddirb=${TEST_BASE_DIR%%/}/dir.$$
typeset tmplogbase=/tmp/${0##*/}.$$
typeset pids=
typeset tfilesys=
typeset tmntpnt=

function remove_entities
{
	[[ -n $runpids ]] && kill -9 $runpids
	[[ -n $tmntpnt ]] && $ZFS umount -f $tmntpnt
	[[ -n $tfilesys ]] && $ZFS destroy -f $tfilesys
	[[ -d $tmntpnt ]] && $RM -rf $tmntpnt
}

# execute many runat commands.
# @parameter: $1 directory to perform the runat in
# @return: 0 if all the runats completed
# @use: count RUNAT CP
function many_runat
{
	typeset dir=$1
	typeset file=$dir/$$
	typeset -i iter=0
	typeset -i iter2=0
	typeset -i status=0
	typeset -i failed=0

	while (( iter <= count )); do
		log_must $MKFILE 1m $file
		iter2=0
		while (( iter2 <= iter )); do
			$RUNAT $file "$CP $file $iter"
			status=$?
			if (( $status != 0 )); then
				log_note "$RUNAT $file \"$CP $file $iter2\" " \
					"failed with $status"
				(( failed = failed + 1 ))
			fi
			(( iter2 = iter2 + 1 ))
		done
		(( iter = iter + 1 ))
		lockfs -f $dir 
		log_must $RM -f $file
	done
	if (( failed != 0 )); then
		return 1
	else
		return 0
	fi
}

log_onexit remove_entities

(( count = TOTAL_COUNT * NUM_CREATORS ))

while (( i < count )); do
	typeset -i j=0
	typeset -i pid=0
	tmntpnt=$ddirb.$i
	tfilesys=$dataset/tcwda.$$.$i

	log_must $MKDIR -p $tmntpnt
	log_must $ZFS create $tfilesys
	log_must $ZFS set mountpoint=$tmntpnt $tfilesys
	while (( j <= NUM_CREATORS )); do
		many_runat $tmntpnt >$tmplogbase.$j 2>&1 &
		pids="$pids $!"
		(( j = j + 1 ))
	done

	j=0
	for pid in $pids; do
		wait $pid
		status=$?
		if (( $status != 0 )); then
			log_note "exattr_create_destroy failed: $status"
			$CAT $tmplogbase.$j
			(( failures = failures + 1 ))
		fi
		log_must $RM -f $tmplogbase.$j
		(( j = j + 1 ))
	done
	pids=
	log_must $RM -rf $tmntpnt/*
	log_must $ZFS unmount $tmntpnt
	log_must $ZFS destroy $tfilesys
	log_must $RM -rf $tmntpnt
	tfilesys=
	tmntpnt=
	(( i = i + 1 ))
done

if (( failures > 0 )); then
	log_fail "There were $failures exattr failures in this run"
fi

log_pass

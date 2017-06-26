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

. ${STF_SUITE}/include/libtest.shlib

# Perform a bunch of read/writes on some newly created datasets.
# Create, mount and set the properties on a dataset before clobbering it
# with a bunch of cfile commands.
# @parameter: $1 the pool from which to draw these test file systems
# @return: 0 if all the work completed ok
# @use: NUM_CREATORS TOTAL_COUNT LOG COUNT
#    dataset_set_defaultproperties TEST_BASE_DIR

typeset -i runat=0
typeset -i block_size=$(pagesize)
typeset dataset=$1
typeset ddirb=${TEST_BASE_DIR%%/}/dir.$$
typeset fn=dataset_create_write_destroy
typeset runpids
typeset tfilesys=
typeset tmntpnt=

set -A sizes

function remove_entities
{
	[[ -n $runpids ]] && kill -9 $runpids
	[[ -d $tmntpnt ]] && zfs umount -f $tmntpnt
	[[ -n $tfilesys ]] && zfs destroy -f $tfilesys
	rm -rf $tmntpnt
}

log_onexit remove_entities

if [[ -z $dataset ]]; then
	log_note "$fn: Insufficient parameters (need 1, got $#)"
	exit 1
fi

while (( block_size <= MAX_BLOCKSIZE )); do
	# +A isn't append, this would be easier if it was.
	set -A sizes ${sizes[@]} $block_size
	(( block_size = block_size * 2 ))
done

(( count = TOTAL_COUNT * NUM_CREATORS ))

USE_F=""
while (( runat < count )); do
	typeset -i atfile=0
	typeset -i size=0
	typeset pid=

	tdir=$ddirb/$runat
	tfilesys=$dataset/file.$$.$runat

	log_must mkdir -p $tdir
	log_must zfs create $tfilesys
	log_must zfs set mountpoint=$tdir $tfilesys
	dataset_set_defaultproperties $tfilesys
	if (( $? != 0 )); then
		log_fail "dataset_set_defaultproperties failed"
	fi

	while (( atfile < NUM_CREATORS )); do
		file_write -o create -f $tdir/file${atfile} \
		    -b ${sizes[$size]} -d 0 -c $COUNT -wr &
		runpids="$! $runpids"
		(( size = size + 1 ))
		(( size > ${#sizes[@]} )) && size=0
		(( atfile = atfile + 1 ))
		log_must zfs snapshot $tfilesys@snap${atfile}
	done

	mkfile 1g $tdir/mkfile.out &
	runpids="$! $runpids"

	dd if=/dev/urandom of=$tdir/dd.out bs=512 oseek=$RANDOM count=10000 &
	runpids="$! $runpids"

	for sn in 1 2 3 4 5 6 7 8 9
	do
		log_must zfs snapshot $tfilesys@snap${atfile}.${sn}
		sleep 1
	done

	for pid in $runpids; do
		wait $pid
		typeset status=$?
		if [ $status -ne 0 ]; then
			log_note "file_write failed ($status)"
		fi
	done
	runpids=

	log_must rm -f $tdir/file*
	# Issue a forced unmount on every second iteration
	if [[ -n $USE_F ]] ; then
		USE_F=""
	else
		USE_F="-f"
	fi

	log_must zfs unmount $USE_F $tdir
	log_must zfs destroy -r $tfilesys
	log_must rm -rf $tdir
	tdir=
	tfilesys=
	(( runat = runat + 1 ))
done

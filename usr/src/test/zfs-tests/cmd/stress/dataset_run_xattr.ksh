#!/bin/ksh -p
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

. $STF_SUITE/include/libtest.shlib

# Perform a bunch of extended attribute test on some newly created filesystem.
# Create, mount and set the properties on a filesystem before clobbering it
# with a bunch of commands.
#
# @return: 0 if all the work completed ok

NUM_FILE=${NUM_FILE:-5}
NUM_ATTR=${NUM_ATTR:-20}
RES_DIR=${RES_DIR:-res}
INI_DIR=${INI_DIR:-init}
TST_DIR=${TST_DIR:-test}
TMP_DIR=${TMP_DIR:-tmp}

# Defined for saving files and attributes' cksum results.
set -A BEFORE_FCKSUM
set -A BEFORE_ACKSUM
set -A AFTER_FCKSUM
set -A AFTER_ACKSUM

# Get the specified item of the specified string
#
# $1:	Item number, count from 0.
# $2-n: strings
function getitem {
	typeset -i n=$1
	shift

	(( n += 1 ))
	eval echo \${$n}
}

# This function calculate the specified directory files checksum and write
# to the specified array.
#
# $1 directory in which the files will be cksum.
# $2 file array name which was used to store file cksum information.
# $3 attribute array name which was used to store attribute information.
function cksum_file {
	typeset dir=$1
	typeset farr_name=$2
	typeset aarr_name=$3

	[[ ! -d $dir ]] && return
	cd $dir
	typeset files=$(ls file*)

	typeset -i i=0
	typeset -i n=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $files)
		eval $farr_name[$i]=\$\(cksum $f\)

		typeset -i j=0
		while (( j < NUM_ATTR )); do
			eval $aarr_name[$n]=\$\(runat \$f cksum attribute.$j\)
			(( j += 1 ))
			(( n += 1 ))
		done

		(( i += 1 ))
	done
}

# This function compare two cksum results array.
#
# $1 The array name which stored the cksum before operation.
# $2 The array name which stored the cksum after operation.
function compare_cksum {
	typeset before=$1
	typeset after=$2
	eval typeset -i count=\${#$before[@]}

	typeset -i i=0
	while (( i < count )); do
		eval typeset var1=\${$before[$i]}
		eval typeset var2=\${$after[$i]}

		if [[ $var1 != $var2 ]]; then
			log_fail "($var1 != $var2)chksum failed."
		fi

		(( i += 1 ))
	done
}

# This function calculates all the files cksum information in current directory
# and outputs them to the specified file.
#
# $1 output file
function record_cksum {
	typeset outfile=$1

	[[ ! -d ${outfile%/*} ]] && mdkir -p ${outfile%/*}

	find . -depth -type f -exec cksum {} \; | sort > $outfile
	find . -depth -type f -xattr -exec runat {} cksum attribute \; | \
	    sort >> $outfile
}

# The clean_up function is called periodically throughout
# the script to either get rid of files that have already
# been used by other scripts or to get rid of the test
# files after the script is finished.
#
# $1 base directory
function clean_up {
	typeset basedir=$1
	if [[ -d $basedir ]]; then
		cd $basedir
		rm -rf $basedir/*
	fi
}

# The function create_files creates the directories and files that the script
# will operate on to test extended attribute functionality.
#
# $1 The basic directory in which to create directories and files.
function create_files {
	typeset basedir=$1
	typeset resdir=$basedir/$RES_DIR
	typeset initdir=$basedir/$INI_DIR
	typeset testdir=$basedir/$TST_DIR
	typeset tmpdir=$basedir/$TMP_DIR

	[[ ! -d $basedir ]] && mkdir -m 777 $basedir
	[[ ! -d $resdir  ]] && mkdir -m 777 $resdir
	[[ ! -d $initdir ]] && mkdir -m 777 $initdir
	[[ ! -d $testdir ]] && mkdir -m 777 $testdir
	[[ ! -d $tmpdir  ]] && mkdir -m 777 $tmpdir

	# Create the original file and its attribute files.
	[[ ! -a $resdir/file ]] && \
	    file_write -o create -f $resdir/file -b 1024 -d 0 -c 1
	[[ ! -a $resdir/attribute ]] && \
	    cp $resdir/file $resdir/attribute

	cd $initdir
	typeset -i i=0
	while (( i < NUM_FILE )); do
		typeset dstfile=$initdir/file.$$.$i
		cp $resdir/file $dstfile

		typeset -i j=0
		while (( j < NUM_ATTR )); do
			runat $dstfile \
			    cp $resdir/attribute ./attribute.$j
			(( j += 1 ))
		done

		(( i += 1 ))
	done
}

# The test_compress function tests the functionality of the compress and
# uncompress utility. The function verifies that compress will keep file
# attribute intact after the file is compressed and uncompressed.
#
# $1 Base directory for compress testing.
function test_compress
{
	log_assert "($$) Starting compress/uncompress test..."

	typeset basedir=$1
	typeset initdir=$basedir/$INI_DIR
	typeset testdir=$basedir/$TST_DIR

	create_files $basedir
	cksum_file $initdir BEFORE_FCKSUM BEFORE_ACKSUM

	compress $initdir/*
	mv $initdir/* $testdir
	uncompress $testdir/*

	cksum_file $testdir AFTER_FCKSUM AFTER_ACKSUM

	compare_cksum BEFORE_FCKSUM AFTER_FCKSUM
	compare_cksum BEFORE_ACKSUM AFTER_ACKSUM

	clean_up $basedir
	log_note "($$) Finished compress/uncompress test."
}

# The test_cp function tests the functionality of the cp
# utility.  The function tests the following:
#
#   * verifies that cp will include file attribute when
#     using the -@ flag
#   * verifies that cp will not be able to include file
#     attribute when attribute is unreadable (unless the
#     user is root)
#   * verifies that cp will not include file attribute
#     when the -@ flag is not present
function test_cp
{
	log_assert "($$) Starting cp test..."

	typeset basedir=$1
	typeset initdir=$basedir/$INI_DIR
	typeset testdir=$basedir/$TST_DIR

	log_note "Verify that 'cp -@' will include file attribute."
	create_files $basedir
	cksum_file $initdir BEFORE_FCKSUM BEFORE_ACKSUM

	#
	# Get initial directory files name and 'cp -@p' to the test directory.
	#
	typeset ini_files=$(ls $initdir/file*)
	typeset -i i=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $ini_files)
		cp -@p $f $testdir
		(( i += 1 ))
	done

	cksum_file $testdir AFTER_FCKSUM AFTER_ACKSUM
	compare_cksum BEFORE_FCKSUM AFTER_FCKSUM
	compare_cksum BEFORE_ACKSUM AFTER_ACKSUM

	clean_up $basedir

	log_note "Verifies that cp won't be able to include file" \
	    "attribute when attribute is unreadable (except root)"
	create_files $basedir
	ini_files=$(ls $initdir/file*)

	i=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $ini_files)
		typeset -i j=0
		while (( j < NUM_ATTR )); do
			# chmod all the attribute files to '000'.
			runat $f chmod 000 attribute.$j

			(( j += 1 ))
		done

		# Apply 'cp -@p' to the file whose attribute files
		# models are '000'.
		cp -@p $f $testdir

		typeset tst_files=$(ls $testdir/file*)
		typeset tf=$(getitem $i $tst_files)
		typeset ls_attr=$(ls -@ $tf | nawk '{print substr($1, 11, 1)}')
		if [[ $ls_attr != "@" ]]; then
			log_fail "Should be able to cp attribute when" \
			    "attribute files is unreadable as root."
		fi

		(( i += 1 ))
	done

	clean_up $basedir

	log_note "Verifies that cp will not include file attribute" \
	    "when the -@ flag is not present."
	create_files $basedir
	ini_files=$(ls $initdir/file*)

	i=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $ini_files)
		cp $f $testdir

		tst_files=$(ls $testdir/file*)
		typeset tf=$(getitem $i $tst_files)
		typeset ls_attr=$(ls -@ $tf | nawk '{print substr($1, 11, 1)}')
		if [[ $ls_attr == "@" ]]; then
			log_fail "cp of attribute successful without" \
			    "-@ or -p option"
		fi

		(( i += 1 ))
	done

	clean_up $basedir
	log_note "($$) Finished cp test."
}

# The test_find function tests the functionality of the find
# utility.  The function tests the following:
#
#   * verifies ability to find files with attribute with -xattr
#     flag and using "-exec runat ls"
#   * verifies -xattr doesn't include files without attribute
#     and using "-exec runat ls"
#   * verifies that using the command "find . -xattr" will only
#     return those files known to have attribute
function test_find
{

	log_assert "($$)Starting find test ..."
	typeset basedir=$1
	typeset initdir=$basedir/$INI_DIR

	log_note "Verifies ability to find files with attribute with" \
	    "-xattr flag and using '-exec runat ls'"
	typeset oldpwd=$PWD
	create_files $basedir
	typeset ini_files=$(ls $initdir/file*)
	typeset ff fa

	cd $initdir
	typeset -i i=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $ini_files)
		ff=$(find $initdir -type f -name ${f##*/} -xattr -print)
		if [[ $ff != $f ]]; then
			log_fail "failed to find file containing attribute"
		fi

		cd $initdir
		typeset j=0
		while (( j < NUM_ATTR )); do
			typeset af=attribute.$j
			fa=$(find . -type f -name ${f##*/} -xattr \
			    -exec runat {} ls $af \;)
			if [[ $fa != $af ]]; then
				log_fail "find file attribute fail"
			fi
			(( j += 1 ))
		done
		(( i += 1 ))
	done

	log_note "verifies -xattr doesn't include files without" \
	    "attribute and using '-exec runat ls'"
	i=0
	while (( i < NUM_FILE )); do
		f=$(getitem $i $ini_files)
		runat $f rm attribute*
		(( i += 1 ))
	done

	i=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $ini_files)
		ff=$(find $initdir -type f -name ${f##*/} -xattr -print)
		if [[ $ff == $f ]]; then
			log_fail "find not containing attribute should fail"
		fi
		typeset j=0
		while (( j < NUM_ATTR )); do
			fa=$(find . -type f -name ${f##*/} -xattr \
			    -exec runat {} ls attribute.$j \;)
			if [[ $fa == attribute.$j ]]; then
				log_note "find file attribute should fail"
			fi
			(( j += 1 ))
		done
		(( i += 1 ))
	done

	clean_up $basedir
	cd $oldpwd
	log_note "($$) Finished find test."
}

# The test_ls function tests the functionality of the ls
# utility.  The function tests the following:
#
#   * verifies that ls displays @ in the file permissions
#     using ls -@ for files with attribute
#   * verifies that ls doesn't display @ in the file
#     permissions using ls -@ for files without attribute
function test_ls
{
	log_assert "($$)Starting ls test ..."
	typeset basedir=$1
	typeset initdir=$basedir/$INI_DIR

	log_note "Verifies that ls displays @ in the file permissions" \
	    "using ls -@ for files with attribute."
	create_files $basedir

	typeset ini_files=$(ls $initdir/file*)
	typeset ls_attr
	typeset -i i=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $ini_files)
		ls_attr=$(ls -@ $f | nawk '{print substr($1, 11, 1)}')
		if [[ $ls_attr != "@" ]]; then
			log_fail "ls with attribute failed"
		fi
		(( i += 1 ))
	done

	log_note "Verifies that ls doesn't display @ in the file" \
	    "permissions using ls -@ for files without attribute."
	i=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $ini_files)
		runat $f rm attribute*
		ls_attr=$(ls -l $f | nawk '{print substr($1, 11, 1)}')
		if [[ $ls_attr == "@" ]]; then
			log_fail "ls with attribute shouldn't succeed."
		fi
		(( i += 1 ))
	done

	clean_up $basedir
	log_note "($$) Finished ls test."
}

# The mv_test function tests the functionality of the mv
# utility.  The function tests the following:
#
#   * verifies that mv will include file attribute
function test_mv
{
	log_assert "($$)Starting mv test ... "

	typeset basedir=$1
	typeset initdir=$basedir/$INI_DIR
	typeset testdir=$basedir/$TST_DIR

	create_files $basedir
	typeset ini_files=$(ls $initdir/file*)

	cksum_file $initdir BEFORE_FCKSUM BEFORE_ACKSUM

	typeset -i i=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $ini_files)
		mv $f $testdir
		(( i += 1 ))
	done

	cksum_file $testdir AFTER_FCKSUM AFTER_ACKSUM

	compare_cksum BEFORE_FCKSUM AFTER_FCKSUM
	compare_cksum BEFORE_ACKSUM AFTER_ACKSUM

	clean_up $basedir
	log_note "($$) Finished mv test."
}

# The pack_test function tests the functionality of the pack
# and unpack utility.  The function tests the following:
#
#   * verifies that pack will keep file attribute intact after
#     the file is packed and unpacked
function test_pack
{
	log_assert "($$)Starting pack/unpack test ... "

	typeset basedir=$1
	typeset initdir=$basedir/$INI_DIR
	typeset testdir=$basedir/$TST_DIR

	create_files $basedir

	cksum_file $initdir BEFORE_FCKSUM BEFORE_ACKSUM
	pack -f $initdir/file* > /dev/null 2>&1
	mv $initdir/* $testdir
	unpack $testdir/file* > /dev/null 2>&1
	cksum_file $testdir AFTER_FCKSUM AFTER_ACKSUM

	compare_cksum BEFORE_FCKSUM AFTER_FCKSUM
	compare_cksum BEFORE_ACKSUM AFTER_ACKSUM

	clean_up $basedir
	log_note "($$) Finished pack/unpack test."
}

# The test_pax function tests the functionality of the pax
# utility.  The function tests the following:
#
#   * include attribute in pax archive and restore with pax
#   * include attribute in tar archive and restore with pax
#   * include attribute in cpio archive and restore with pax
#   * include attribute in tar archive and restore with tar
#   * include attribute in cpio archive and restore with cpio
function test_pax
{
	log_assert "($$)Starting pax test ..."

	typeset basedir=$1
	typeset initdir=$basedir/$INI_DIR
	typeset testdir=$basedir/$TST_DIR
	typeset tmpdir=$basedir/$TMP_DIR
	typeset oldpwd=$PWD

	log_note "Include attribute in pax archive and restore with pax"
	[[ ! -d $initdir ]] && mkdir -m 777 -p $initdir
	mktree -b $initdir -l 6 -d 2 -f 2

	# Enter into initial directory and record all directory information,
	# then pax all the files to $tmpdir/files.pax.
	[[ ! -d $tmpdir ]] && mkdir $tmpdir
	typeset initout=$tmpdir/initout.$$
	cd $initdir
	record_cksum $initout
	typeset paxout=$tmpdir/files.pax
	pax -w -@ -f $paxout * > /dev/null 2>&1

	# Enter into test directory and pax $tmpdir/files.pax to current
	# directory. Record all directory information and compare with initial
	# directory record.
	[[ ! -d $testdir ]] && mkdir -m 777 $testdir
	typeset testout=$tmpdir/testout.$$
	cd $testdir
	pax -r -@ -f $paxout > /dev/null 2>&1
	record_cksum $testout
	diff $initout $testout

	clean_up $basedir

	log_note "Include attribute in tar archive and restore with pax"
	[[ ! -d $initdir ]] && mkdir -m 777 $initdir
	mktree -b $initdir -l 5 -d 2 -f 2
	[[ ! -d $tmpdir ]] && mkdir -m 777 $tmpdir
	cd $initdir
	record_cksum $initout
	paxout=$tmpdir/files.$$.tar
	pax -w -x ustar -@ -f $paxout * > /dev/null 2>&1

	[[ ! -d $testdir ]] && mkdir -m 777 $testdir
	cd $testdir
	tar xpf@ $paxout
	record_cksum $testout

	diff $initout $testout

	clean_up $basedir

	log_note "Include attribute in cpio archive and restore with pax"
	[[ ! -d $initdir ]] && mkdir -m 777 $initdir
	mktree -b $inidir -l 5 -d 2 -f 2

	cd $initdir
	record_cksum $initout
	paxout=$tmpdir/files.cpio
	pax -w -x cpio -@ -f $paxout * > /dev/null 2>&1

	[[ ! -d $testdir ]] && mkdir -m 777 $testdir
	cd $testdir
	cpio -ivd@ < $paxout > /dev/null 2>&1
	record_cksum $testout

	diff $initout $testout

	clean_up $basedir

	log_note "Include attribute in tar archive and restore with tar"
	create_files $basedir
	cksum_file $initdir BEFORE_FCKSUM BEFORE_ACKSUM
	cd $initdir
	paxout=$tmpdir/files.pax
	pax -w -@ -f $paxout file* > /dev/null 2>&1
	cd $testdir
	pax -r -@ -f $paxout > /dev/null 2>&1
	cksum_file $testdir AFTER_FCKSUM AFTER_ACKSUM

	compare_cksum BEFORE_FCKSUM AFTER_FCKSUM
	compare_cksum BEFORE_ACKSUM AFTER_ACKSUM
	clean_up $basedir

	log_note "Include attribute in cpio archive and restore with cpio"
	create_files $basedir
	cd $initdir
	paxout=$tmpdir/files.cpio
	cksum_file $initdir BEFORE_FCKSUM BEFORE_ACKSUM
	pax -w -x cpio -@ -f $paxout file* > /dev/null 2>&1

	cd $testdir
	pax -r -x cpio -@ -f $paxout > /dev/null 2>&1
	cksum_file $testdir AFTER_FCKSUM AFTER_ACKSUM

	compare_cksum BEFORE_FCKSUM AFTER_FCKSUM
	compare_cksum BEFORE_ACKSUM AFTER_ACKSUM

	rm -rf file*
	cpio -iv@ < $paxout > /dev/null 2>&1
	cksum_file $testdir AFTER_FCKSUM AFTER_ACKSUM

	compare_cksum BEFORE_FCKSUM AFTER_FCKSUM
	compare_cksum BEFORE_ACKSUM AFTER_ACKSUM

	clean_up $basedir

	create_files $basedir
	cksum_file $initdir BEFORE_FCKSUM BEFORE_ACKSUM
	paxout=$tmpdir/files.$$.tar
	cd $initdir
	pax -w -x ustar -@ -f $paxout file* > /dev/null 2>&1
	cd $testdir
	pax -r -x ustar -@ -f $paxout > /dev/null 2>&1
	cksum_file $testdir AFTER_FCKSUM AFTER_ACKSUM

	compare_cksum BEFORE_FCKSUM AFTER_FCKSUM
	compare_cksum BEFORE_ACKSUM AFTER_ACKSUM

	rm -rf file*
	tar xf@ $tmpdir/files.$$.tar > /dev/null 2>&1
	cksum_file $testdir AFTER_FCKSUM AFTER_ACKSUM

	compare_cksum BEFORE_FCKSUM AFTER_FCKSUM
	compare_cksum BEFORE_ACKSUM AFTER_ACKSUM

	clean_up $basedir
	cd $oldpwd
	log_note "($$) Finished pax test."
}

# The test_rm function tests the functionality of the rm
# utility.  The function tests the following:
#
#   * removal of file and associated attribute
function test_rm
{
	log_assert "($$)Starting rm test ..."

	typeset basedir=$1
	typeset initdir=$basedir/$INI_DIR
	typeset testdir=$basedir/$TST_DIR

	create_files $basedir
	typeset ini_files=$(ls $initdir/file*)

	typeset -i i=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $ini_files)
		rm $f
		ls $f

		(( i += 1 ))
	done

	clean_up $basedir
	log_note "($$) Finished rm test."
}

# The test_tar function tests the functionality of the tar
# utility.  The function tests the following:
#
#   * verifies that tar will include file attribute when
#     @ flag is present
#   * verifies that tar will not include files attribute
#     when @ flag is not present
function test_tar
{
	log_assert "($$)Starting tar test ..."

	typeset basedir=$1
	typeset initdir=$basedir/$INI_DIR
	typeset testdir=$basedir/$TST_DIR
	typeset tmpdir=$basedir/$TMP_DIR
	typeset oldpwd=$PWD

	[[ ! -d $initdir ]] && mkdir -m 777 $initdir
	[[ ! -d $tmpdir ]] && mkdir -m 777 $tmpdir
	[[ ! -d $testdir ]] && mkdir -m 777 $testdir
	mktree -b $initdir -l 5 -d 2 -f 2

	log_note "Verifies that tar will include file attribute" \
	    "when @ flag is present."
	typeset initout=$tmpdir/initout.$$
	typeset tarout=$tmpdir/files.$$.tar
	cd $initdir
	record_cksum $initout
	tar cpf@ $tarout *

	typeset testout=$tmpdir/testout.$$
	cd $testdir
	tar xpf@ $tarout
	record_cksum $testout

	diff $initout $testout
	clean_up $basedir

	log_note "Verifies that tar will not include files attribute" \
	    "when @ flag is not present."
	create_files $basedir
	cd $initdir
	cksum_file $initdir BEFORE_FCKSUM BEFORE_ACKSUM
	tarout=$tmpdir/files.$$.tar
	tar cpf@ $tarout * > /dev/null 2>&1
	cksum_tara=$(cksum $tarout)
	cp $tarout $testdir

	cd $testdir
	tar xpf@ $tarout > /dev/null 2>&1
	cksum_file $testdir AFTER_FCKSUM AFTER_ACKSUM

	compare_cksum BEFORE_FCKSUM AFTER_FCKSUM
	compare_cksum BEFORE_ACKSUM AFTER_ACKSUM

	ck_tvf=$(tar tvf $tarout | grep attribute | wc -l)
	if (( $ck_tvf != NUM_ATTR * NUM_FILE + NUM_FILE )); then
		log_note "table of contents displayed attribute fail"
	fi

	clean_up $basedir

	create_files $basedir

	cd $initdir
	tar cpf $tarout file* > /dev/null 2>&1
	cksum_tarb=$(cksum $tarout)
	cp $tarout $testdir

	cd $testdir
	tar xpf $tarout > /dev/null 2>&1
	typeset test_files=$(ls $testdir/file*)
	typeset -i i=0
	while (( i < NUM_FILE )); do
		typeset f=$(getitem $i $test_files)
		ls_attr=$(ls -@ $f | nawk '{print substr($1, 11, 1)}')
		if [[ $ls_attr == "@" ]]; then
			log_fail "extraction of attribute successful w/ -@ flag"
		fi

		(( i += 1 ))
	done

	if [[ $cksum_tara == $cksum_tarb ]]; then
		log_fail "inclusion of attribute in tar file without -@ failed"
	fi

	clean_up $basedir
	cd $oldpwd
	log_note "($$) Finished tar test."
}

function test_all #<directory>
{
	typeset dir=$1

	test_compress $dir
	test_cp $dir
	test_find $dir
	test_ls $dir
	test_mv $dir
	test_pack $dir
	test_pax $dir
	test_rm $dir
	test_tar $dir

	exit 0
}

function trap_handle
{
	typeset pid

	for pid in $@; do
		kill -9 $pid
	done
	kill -9 $$
}

typeset dataset=$1
typeset ddirb=${TEST_BASE_DIR%%/}/dir.$$
typeset -i runat=0

(( count = TOTAL_COUNT * NUM_CREATORS ))

while (( runat < count )); do
	typeset -i run_count=0
	typeset tfs=$dataset/fs.$$.$runat
	typeset tdir=$ddirb/$runat

	mkdir -p $tdir
	zfs create $tfs
	zfs set mountpoint=$tdir $tfs
	if ! dataset_set_defaultproperties $tfs; then
		log_fail "dataset_set_defaultproperties failed"
	fi

	typeset runpids=""
	while (( run_count < NUM_CREATORS )); do
		log_note "Starting No.$run_count running..."

		[[ ! -d $tdir/$run_count ]] && mkdir -m 777 $tdir/$run_count

		test_all $tdir/$run_count > /dev/null 2>&1 &
		runpids="$! $runpids"

		(( run_count += 1 ))
	done

	trap 'trap_handle $runpids' USR1

	for pid in $runpids; do
		wait $pid
		typeset status=$?
		if [ $status -ne 0 ]; then
			log_note "($pid)Extend attribute test failed. ($status)"
		fi
	done
	runpids=""

	if datasetexists $tfs; then
		zfs destroy -Rf $tfs
	fi
	if [[ -d $tdir ]]; then
		rm -rf $tdir
	fi

	(( runat += 1 ))
done

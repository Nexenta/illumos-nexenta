#! /usr/bin/ksh -p
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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# compile.ksh compile c programs in a remote host
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

function usage
{
	echo "ERROR: USAGE: $0 setup | cleanup [file] [flags] [CCPATH]"
	echo "\twhere all optional arguments are used in setup only."
	echo "\tsetup | cleanup: desired compilation action to be taken."
	echo "\tfile: contains the info about files to be compiled and how."
	echo "\tflags: are c flags to be used on all files,"
	echo "\t be aware that individual c flags are specified for each c file"
	echo "\t on the setup file. Contradictions may cause problems."
	echo "\tCCPATH: path to cc compiler to use in this machine."
	exit -1
}

[ $# -lt 1 ] && usage
[ $# -eq 1 ] && [ "$1" = "setup" ] && usage
[ "$1" = "setup" ] && [ $# -lt 2 ] && usage
action=$1
[ $# -ge 2 ] && file=$2
[ $# -ge 3 ] && tflags=$3
[ -n "$tflags" ] && flags=${tflags:="-g"}
arch=`uname -p`
if [ $arch = "sparc" ]; then
	arch2="i386"
else
	arch2="sparc"
fi
[ $# -ge 4 ] && tcc=$4
[ -n "$tcc" ] && CC=\
${tcc:=/opt/SUNWspro/bin/cc}

# Check if correct arch is in path (in case default got wrong value)
# Make sure the wrong arch is not in string
res=`echo $CC | grep $arch2`
if [ $? -eq 0 ]; then
	# try to fix by replacing with correct arch
	CC=`echo $CC | sed "s/$arch2/$arch/g"`
fi

RES=0
# setup the remote machine
if [ "$action" = "setup" ]; then
	if [ ! -r "$file" ]; then
		echo "ERROR: $file does not exist or cannot be read"
		exit 1
	fi

	# create cleanup file
	echo "$0\n$file" > ./cleanup.list

	if [ ! -x $CC ]; then
		echo "ERROR: machine `hostname`($arch) failed to run $CC."
		exit -1
	fi
	tmpfile="tmpfile.$$"
	egrep -v "^#|^  *$|^$" $file > $tmpfile

	while read comm filename opts objs other
	do
		case "$comm" in
		c) echo "${filename}*" >> ./cleanup.list
		   if [ ! -r ${filename}.c ]; then
			echo "WARNING: $filename not present"
			RES=1
		   else
			[ "$opt" = "\"\"" ] && opt=""
			$CC $opt $flags -c ${filename}.c -o ${filename}.o
		   fi;;
		l)if [ ! -r ${filename}.o ]; then
			echo "WARNING: ${filename}.o not present"
			RES=2
		   elif [ "$objs" != "\"\"" ] && [ ! -r "$objs" ]; then
			echo "WARNING: $objs not present"
			RES=2
		   else
			[ "$objs" = "\"\"" ] && objs=""
			[ "$opt" = "\"\"" ] && opt=""
			$CC $opt $flags $objs ${filename}.o -o $filename
			chmod 777 $filename
		   fi;;
		s) echo "${filename}*" >> ./cleanup.list
		   if [ ! -r "$filename" ]; then
			echo "WARNING: $filename not present"
			RES=3
		   else
			chmod 777 $filename
		   fi;;
		*) echo "ERROR in $file: $comm $filename $opts $objs $other"
			exit -1;;
		esac
	done < $tmpfile
	rm -f $tmpfile > /dev/null 2>&1
else
# cleanup the remote machine
	tmpfile="./cleanup.list"
	if [ ! -r "$tmpfile" ]; then
		echo "ERROR: $tmpfile does not exist or cannot be read"
		exit 1
	fi
	files=`cat $tmpfile`
	for i in `echo $files`
	do
		[ -r "$i" ] && rm -rf $i
	done
	rm -f $tmpfile > /dev/null 2>&1
fi
exit $RES

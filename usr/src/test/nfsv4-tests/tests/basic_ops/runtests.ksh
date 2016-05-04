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
# Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# control program to run all "basic_ops" tests

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
DIR=`pwd`
ALLTDIRS="access close commit create getattr getfh link lookup lookupp"
ALLTDIRS="$ALLTDIRS open openconfirm nverify openattr"
ALLTDIRS="$ALLTDIRS putfh putpubfh putrootfh read readdir"
ALLTDIRS="$ALLTDIRS readlink remove rename renew restorefh savefh"
ALLTDIRS="$ALLTDIRS secinfo setattr setclientid verify write"
ALLTDIRS="$ALLTDIRS locksid release_lockowner"
TDIRS=${TDIRS:-"$ALLTDIRS"}

# make sure the server's GRACE period will be checked the first time
rm -f $TMPDIR/SERVER_NOT_IN_GRACE

for d in $TDIRS
do
	cd $DIR/$d
	./runtests
done

exit 0

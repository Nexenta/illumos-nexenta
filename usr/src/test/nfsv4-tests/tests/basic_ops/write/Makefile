#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#
#
# Copyright (c) 2012 by Delphix. All rights reserved.
# Copyright 2016 Nexenta Systems, Inc.  All rights reserved.
#
include $(SRC)/Makefile.master

TEST = basic_ops/write
SHRSRC = WRITE.env WRITE.flist
TCS = runtests
TCLSRC = rw_bnd01 rw_bnd02 write_neg01 write_neg02 write_neg03 \
	write_neg04 write_pos01 write_pos02 WRITE_proc

include ../../Makefile.test

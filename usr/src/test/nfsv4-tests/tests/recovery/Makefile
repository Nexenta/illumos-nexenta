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

TEST = recovery
SHRSRC = README RECOV.flist
TCLSRC = ck_unshareall01 io_neg01 io_neg02 io_neg03 RECOV_proc
TCS = isserverup nfs4red recov_cleanup recov_setup recov_srv_setup \
	runtests srv_ckshare S99nfs4red

include ../Makefile.test

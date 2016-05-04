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

TEST = basic_ops/locksid
SHRSRC = LOCKsid.env LOCKsid.flist
TCS = runtests
TCLSRC = locksid_neg01 locksid_neg02 locksid_neg03 locksid_neg04 \
	locksid_neg05 locksid_neg06 locksid_neg07 locksid_pos01 \
	locksid_pos02 locksid_pos03 srv_recov01 srv_recov02 \
	srv_recov03 srv_recov04

include ../../Makefile.test

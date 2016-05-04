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

TEST = other_tests/uidmapping
SHRSRC = README create_mapid_files.c
TCS = runtests uid_proc uidmapping_neg03 uidmapping_neg04 \
	uidmapping_pos03 uidmapping_pos04 uidmapping_pos05 \
	uidmapping_stress01 uidmapping_stress02
TCLSRC = send_setattr_reqs uidmapping_neg01 uidmapping_neg02 \
	uidmapping_pos01

include ../../Makefile.test

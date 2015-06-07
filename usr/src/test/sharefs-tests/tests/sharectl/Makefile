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
# Copyright (c) 2012 by Delphix. All rights reserved.
# Copyright 2014 Nexenta Systems, Inc.  All rights reserved.
#
include $(SRC)/Makefile.master

ROOTOPTPKG = $(ROOT)/opt/sharefs-tests
TESTDIR = $(ROOTOPTPKG)/tests/sharectl

PROGS = tp_sharectl_009 tp_sharectl_019 tp_sharectl_029 \
	tc_sharectl tp_sharectl_010 tp_sharectl_020 tp_sharectl_030 \
	tp_sharectl_001 tp_sharectl_011 tp_sharectl_021 tp_sharectl_031 \
	tp_sharectl_002 tp_sharectl_012 tp_sharectl_022 tp_sharectl_032 \
	tp_sharectl_003 tp_sharectl_013 tp_sharectl_023 tp_sharectl_033 \
	tp_sharectl_004 tp_sharectl_014 tp_sharectl_024 tp_sharectl_034 \
	tp_sharectl_005 tp_sharectl_015 tp_sharectl_025 tp_sharectl_035 \
	tp_sharectl_006 tp_sharectl_016 tp_sharectl_026 tp_sharectl_036 \
	tp_sharectl_007 tp_sharectl_017 tp_sharectl_027 tp_sharectl_037 \
	tp_sharectl_008 tp_sharectl_018 tp_sharectl_028 tp_sharectl_038
	

CMDS = $(PROGS:%=$(TESTDIR)/%)
$(CMDS) := FILEMODE = 0555

all lint clean clobber:

install: $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.ksh
	$(INS.rename)

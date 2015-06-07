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
TESTDIR = $(ROOTOPTPKG)/tests/sharemgr/delete

PROGS = tp_delete_002 tp_delete_005 \
	tc_delete_share tp_delete_003 tp_delete_006 \
	tp_delete_001 tp_delete_004 tp_delete_007


CMDS = $(PROGS:%=$(TESTDIR)/%)
$(CMDS) := FILEMODE = 0555

all lint clean clobber:

install: $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.ksh
	$(INS.rename)

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
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#
include $(SRC)/Makefile.master

ROOTOPTPKG = $(ROOT)/opt/comstar-tests
TESTDIR = $(ROOTOPTPKG)/tests/iscsi/fs

PROGS = tc_iscsi_fs tp_iscsi_fs_001 tp_iscsi_fs_002 tp_iscsi_fs_003 \
	tp_iscsi_fs_004 tp_iscsi_fs_005 tp_iscsi_fs_006 tp_iscsi_fs_007 \
	tp_iscsi_fs_008 tp_iscsi_fs_009
	

CMDS = $(PROGS:%=$(TESTDIR)/%)
$(CMDS) := FILEMODE = 0555

all lint clean clobber:

install: $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.ksh
	$(INS.rename)

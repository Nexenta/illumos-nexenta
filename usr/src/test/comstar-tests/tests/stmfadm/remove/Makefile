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
TESTDIR = $(ROOTOPTPKG)/tests/stmfadm/remove

PROGS = tc_remove_stmfadm tp_remove_stmfadm_001 tp_remove_stmfadm_002 \
	tp_remove_stmfadm_003 tp_remove_stmfadm_004 tp_remove_stmfadm_005 \
	tp_remove_stmfadm_006 tp_remove_stmfadm_007 tp_remove_stmfadm_008 \
	tp_remove_stmfadm_009 tp_remove_stmfadm_010

	

CMDS = $(PROGS:%=$(TESTDIR)/%)
$(CMDS) := FILEMODE = 0555

all lint clean clobber:

install: $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.ksh
	$(INS.rename)

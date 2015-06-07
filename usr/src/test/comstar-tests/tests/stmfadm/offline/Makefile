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
TESTDIR = $(ROOTOPTPKG)/tests/stmfadm/offline

PROGS = tc_offline_stmfadm tp_offline_stmfadm_001 tp_offline_stmfadm_002 \
	tp_offline_stmfadm_003 tp_offline_stmfadm_004 tp_offline_stmfadm_005 \
	tp_offline_stmfadm_006 tp_offline_stmfadm_007 tp_offline_stmfadm_008 \
	tp_offline_stmfadm_009 tp_offline_stmfadm_010 tp_offline_stmfadm_011 \
	tp_offline_stmfadm_012 tp_offline_stmfadm_013 tp_offline_stmfadm_014 \
	tp_offline_stmfadm_015 tp_offline_stmfadm_016 tp_offline_stmfadm_017 \
	tp_offline_stmfadm_018 tp_offline_stmfadm_019 tp_offline_stmfadm_020

	

CMDS = $(PROGS:%=$(TESTDIR)/%)
$(CMDS) := FILEMODE = 0555

all lint clean clobber:

install: $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.ksh
	$(INS.rename)

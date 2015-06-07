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
TESTDIR = $(ROOTOPTPKG)/tests/stmfadm/add

PROGS = tc_add_stmfadm tp_add_stmfadm_001 tp_add_stmfadm_002 tp_add_stmfadm_003 \
	tp_add_stmfadm_004 tp_add_stmfadm_005 tp_add_stmfadm_006 tp_add_stmfadm_008 \
	tp_add_stmfadm_009 tp_add_stmfadm_010 tp_add_stmfadm_011 tp_add_stmfadm_012 \
	tp_add_stmfadm_013 tp_add_stmfadm_014 tp_add_stmfadm_015 tp_add_stmfadm_016 \
	tp_add_stmfadm_017 tp_add_stmfadm_018 tp_add_stmfadm_019 tp_add_stmfadm_020 \
	tp_add_stmfadm_021 tp_add_stmfadm_022 tp_add_stmfadm_023 tp_add_stmfadm_024 \
	tp_add_stmfadm_025 tp_add_stmfadm_026 tp_add_stmfadm_007
	

CMDS = $(PROGS:%=$(TESTDIR)/%)
$(CMDS) := FILEMODE = 0555

all lint clean clobber:

install: $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.ksh
	$(INS.rename)

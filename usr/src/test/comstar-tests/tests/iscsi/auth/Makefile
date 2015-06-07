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
TESTDIR = $(ROOTOPTPKG)/tests/iscsi/auth

PROGS = tc_iscsi_auth tp_iscsi_auth_001 tp_iscsi_auth_002 \
	tp_iscsi_auth_003 tp_iscsi_auth_004 tp_iscsi_auth_005 \
	tp_iscsi_auth_006 tp_iscsi_auth_007 tp_iscsi_auth_008 \
	tp_iscsi_auth_009 tp_iscsi_auth_010 tp_iscsi_auth_011 \
	tp_iscsi_auth_012
	

CMDS = $(PROGS:%=$(TESTDIR)/%)
$(CMDS) := FILEMODE = 0555

all lint clean clobber:

install: $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.ksh
	$(INS.rename)

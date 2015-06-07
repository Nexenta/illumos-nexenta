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
TESTDIR = $(ROOTOPTPKG)/tests/sharemgr/set_security

PROGS = tp_set_security_004 tp_set_security_009 tp_set_security_014 \
	tc_set_security tp_set_security_005 tp_set_security_010 tp_set_security_015 \
	tp_set_security_001 tp_set_security_006 tp_set_security_011 \
	tp_set_security_002 tp_set_security_007 tp_set_security_012 \
	tp_set_security_003 tp_set_security_008 tp_set_security_013

CMDS = $(PROGS:%=$(TESTDIR)/%)
$(CMDS) := FILEMODE = 0555

all lint clean clobber:

install: $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.ksh
	$(INS.rename)

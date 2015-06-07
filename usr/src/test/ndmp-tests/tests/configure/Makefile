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
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#
#
# The top level Makefile for the configuration portion of the test
# suite.
#
include $(SRC)/Makefile.master

ROOTOPTPKG = $(ROOT)/opt/ndmp-tests
TESTDIR = $(ROOTOPTPKG)/tests/configure

PROGS	= tc_configure

CMDS = $(PROGS:%=$(TESTDIR)/%)
$(CMDS) := FILEMODE = 0555

all lint clean clobber:

install : $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.ksh
	$(INS.rename)

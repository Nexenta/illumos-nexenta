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

ROOTOPTPKG = $(ROOT)/opt/nfsv4-tests
ROOTBIN = $(ROOTOPTPKG)/bin
ROOTSHR = $(ROOTBIN)

#
# Top level scripts invoked by stf framework
#
SHRSRC = v4test.cfg
SCRIPTS = fillDisk getTestFSType mk_srvdir setupFS

SHS = $(SCRIPTS:%=$(ROOTBIN)/%)
SHRS = $(SHRSRC:%=$(ROOTSHR)/%)
$(SHS) := FILEMODE = 0555
$(SHRS) := FILEMODE = 0444

all lint clean clobber:

install: $(SHS) $(SHRS)

$(SHS) : $(ROOTBIN)
$(SHRS) : $(ROOTSHR)

$(ROOTBIN):
	$(INS.dir)

$(ROOTBIN)/%: %.ksh
	$(INS.rename)

$(ROOTSHR)/%: %
	$(INS.file)

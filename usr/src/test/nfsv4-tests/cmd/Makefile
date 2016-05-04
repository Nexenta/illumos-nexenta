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
ROOTTCL = $(ROOTBIN)

SHRSRC = libsmf.shlib nfs4test.env tcl.init
TCLSRC = acltools getleasetm lcltools testproc
SCRIPTS = compile get_tunable go_cleanup go_setup operate_dir \
	runit runtests set_nfstunable srv_setup testsh nfsv4test

SHS = $(SCRIPTS:%=$(ROOTBIN)/%)
SHRS = $(SHRSRC:%=$(ROOTSHR)/%)
TCLS = $(TCLSRC:%=$(ROOTTCL)/%)
$(SHS) $(TCLS) := FILEMODE = 0555
$(SHRS) := FILEMODE = 0444

all lint clean clobber:

install: $(SHS) $(SHRS) $(TCLS)

$(SHS) : $(ROOTBIN)
$(SHRS) : $(ROOTSHR)
$(TCLS) : $(ROOTTCL)

$(ROOTBIN):
	$(INS.dir)

$(ROOTBIN)/%: %.ksh
	$(INS.rename)

$(ROOTTCL)/%: %.tcl
	$(INS.rename)

$(ROOTSHR)/%: %
	$(INS.file)

.PARALLEL: $(SUBDIRS)

SUBDIRS = nfsv4sh

include $(SRC)/test/Makefile.com

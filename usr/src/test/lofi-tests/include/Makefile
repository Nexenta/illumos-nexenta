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
# Copyright 2014 Nexenta Systems, Inc.  All rights reserved.
#

include $(SRC)/Makefile.master

ROOTOPTPKG = $(ROOT)/opt/lofi-tests
INCBIN = $(ROOTOPTPKG)/lib

TOOLS = fs_common \
	startup_cleanup_common \
	util_common

INCS = $(TOOLS:%=$(INCBIN)/%)
$(INCS) := FILEMODE = 0555

all lint clean clobber:

install: $(INCS)

$(INCS): $(INCBIN)

$(INCBIN):
	$(INS.dir)

$(INCBIN)/%: %.ksh
	$(INS.rename)

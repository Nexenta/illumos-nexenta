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
# Copyright 2012 Nexenta Systems, Inc. All rights reserved.
#

PROG=		aoe-initiator
SRCSAOEI=	aoe-initiator.c

MANIFEST=	$(PROG:%=%.xml)
SVCMETHOD=	$(PROG)

include		../Makefile.cmd

LDLIBS +=	-laoe -lipadm

ROOTMANIFESTDIR= $(ROOTSVCNETWORK)
$(ROOTSVCNETWORK)/aoe-initiator.xml := FILEMODE = 0444

.KEEP_STATE:

all:		$(PROG)

check:		$(CHKMANIFEST)

clean:

install:	all $(ROOTMANIFEST) $(ROOTSVCMETHOD)

lint:
		$(LINT.c) $(SRCSAOEI) $(LDLIBS)

include		../Makefile.targ

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
# Copyright 2012 Nexenta Systems, Inc.  All rights reserved.
#

PROG=	netgr_get netgr_in

include		../Makefile.cmd

CSTD=		$(CSTD_GNU99)
#CERRWARN +=

all:		$(PROG)

install:	all $(ROOTPROG)

clean:
	$(RM) $(PROG) *.o

lint:
	$(LINT.c) netgr_get.c
	$(LINT.c) netgr_in.c

include		../Makefile.targ

.KEEP_STATE:

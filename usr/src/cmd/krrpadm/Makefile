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

PROG=	krrpadm

CMNDIR=     $(SRC)/common/krrp

OBJS_KRRP_TOOL = krrpadm.o

OBJS= ${OBJS_KRRP_TOOL}
SRCS=   ${OBJS_KRRP_TOOL:.o=.c}

include ../Makefile.cmd
include ../Makefile.ctf

INCS += -I../../common/krrp

CPPFLAGS += -D_REENTRANT
CPPFLAGS += $(INCS)

LDLIBS += -lnvpair -lkrrp -luuid

.KEEP_STATE:

all: $(PROG)

$(PROG): $(OBJS)
	$(LINK.c) -o $(PROG) $(OBJS) $(LDLIBS)
	$(POST_PROCESS)

%.o: $(CMNDIR)/%.c
	$(COMPILE.c) -o $@ $<
	$(POST_PROCESS_O)

install: all $(ROOTUSRSBINPROG)

clean:
	$(RM) $(OBJS)

_msg:

lint:	lint_SRCS

include ../Makefile.targ

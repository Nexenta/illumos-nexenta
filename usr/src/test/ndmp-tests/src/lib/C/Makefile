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

AR= ar

include 	$(SRC)/cmd/Makefile.cmd
include 	$(SRC)/test/Makefile.com

OBJS = ndmp_xdr.o ndmp_conv.o log.o connect_utils.o \
	ndmp_connect.o xdr_utils.o notifications_queue.o

SRCS=	$(OBJS:%.o=%.c)

LIBDIR =	.
LDLIB = 	$(LIBDIR)/libndmpprototest.a

INCPATH=	-I. -I../../include -I$(LIBDIR)

CPPFLAGS = 	$(INCPATH)
C99MODE =	$(C99_ENABLE)

FILEMODE= 	2555


# build rule
#

all:		$(LDLIB)

$(LDLIB): $(OBJS)
	$(AR) rv $@ $?

install:	$(LDLIB)

clobber: clean

clean:
	$(RM) $(PROG) $(OBJS) $(LDLIB)

lint:	

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

include $(SRC)/cmd/Makefile.cmd
include $(SRC)/test/Makefile.com


ROOTOPTPKG = $(ROOT)/opt/ndmp-tests
TESTDIR = $(ROOTOPTPKG)/bin

BLDPROG = ndmp_proto_test.bin
PROG=	ndmp_proto_test
CMDS = $(PROG:%=$(TESTDIR)/%)

$(CMDS) := FILEMODE = 0555

DEFINES =  -DNDMP_PROTOCOL_TEST
#DEFINES =  -DUNIT_TEST_NOTIFY
#DEFINES =  -DUNIT_TEST_MOVER
#DEFINES =  -DUNIT_TEST_DATA
#DEFINES =  -DUNIT_TEST_TAPE
#DEFINES =  -DUNIT_TEST_SCSI
#DEFINES =  -DUNIT_TEST_CONFIG
#DEFINES =  -DUNIT_TEST_CONNECT

OBJS= connect_tester.o config_tester.o data.o fhistory_tester.o \
	log_tester.o mover.o ndmp_comm_lib.o ndmp_lib.o \
	ndmp_proto_test.o notify_tester.o scsi_tester.o tape_tester.o

SRCS=	$(OBJS:%.o=%.c)

LIBTARGET=	../../lib/C/libndmpprototest.a
INCPATH=	-I. -I../../include -I../../lib/C
LIBS = -lsocket -lnsl

CPPFLAGS += -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 $(INCPATH) $(DEFINES)

FILEMODE= 	2555

# build rule
#
all:		$(BLDPROG)

$(BLDPROG):	$(OBJS) $(LIBTARGET)
	$(LINK.c) $(OBJS) $(LIBTARGET) $(LIBS) -o $@
	$(POST_PROCESS)

$(LIBTARGET):
	(cd ../../lib/C;make install)

clean:
	$(RM) $(BLDPROG) $(OBJS)

install: $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.bin
	$(INS.rename)

lint:

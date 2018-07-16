#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#
#
# Copyright (c) 1998, 2010, Oracle and/or its affiliates. All rights reserved.
# Copyright 2018 Nexenta Systems, Inc. All rights reserved.
#

PROG= savecore
SRCS= ../savecore.c ../../../uts/common/os/compress.c
OBJS= savecore.o compress.o

include ../../Makefile.cmd

CSTD = $(CSTD_GNU99)

CFLAGS += $(CCVERBOSE)
CFLAGS64 += $(CCVERBOSE)
CPPFLAGS += -D_LARGEFILE64_SOURCE=1 -I$(SRC)/uts/common

LDLIBS += -luuid -lgen

.KEEP_STATE:

all: $(PROG)

$(PROG): $(OBJS)
	$(LINK.c) -o $(PROG) $(OBJS) $(LDLIBS)
	$(POST_PROCESS)

clean:
	$(RM) $(OBJS)

#
# savecore only uses the decompress() path of compress.c
# suppress complaints about unused compress() path
#
lint := LINTFLAGS += -erroff=E_NAME_DEF_NOT_USED2
lint := LINTFLAGS64 += -erroff=E_NAME_DEF_NOT_USED2

lint:	$(LINTSRCS)
	$(LINT.c) $(SRCS) $(LDLIBS)

include ../../Makefile.targ

%.o: ../%.c
	$(COMPILE.c) -I$(SRC)/common $<
	$(POST_PROCESS_O)

%.o: ../../../uts/common/os/%.c
	$(COMPILE.c) $<
	$(POST_PROCESS_O)

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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# Copyright (c) 2012 by Delphix. All rights reserved.
# Copyright 2016 Nexenta Systems, Inc.  All rights reserved.
#
include $(SRC)/cmd/Makefile.cmd

ROOTOPTPKG = $(ROOT)/opt/nfsv4-tests
TESTBIN = $(ROOTOPTPKG)/bin

PROGS =	nfsh
BINS = $(PROGS:%=$(TESTBIN)/%)
$(BINS) := FILEMODE = 0555

LINTOBJS= nfs_main.o nfs_proc.o nfs_ops.o nfs_attr.o nfs_utils.o \
	nfs_open.o
OBJS=	$(LINTOBJS) nfs4_clnt.o nfs4_xdr.o
NFS4X=	../nfs4_prot.x

CFLAGS = -erroff=%all 	# Ignore all lint msg now
CFLAGS += -I/usr/include
LDLIBS += -lnsl -lsocket -ltcl8.5
LDFLAGS += -zignore

all install: $(BINS)

$(BINS): $(OBJS)
	$(LINK.c) $(CFLAGS) -o $@ $(OBJS) $(LDLIBS)
	$(POST_PROCESS)

nfs4_prot.h nfs4_clnt.c nfs4_xdr.c: $(NFS4X)
	$(CP) $(NFS4X) .
	$(RPCGEN) -C -c nfs4_prot.x > nfs4_xdr.c
	$(RPCGEN) -C -h nfs4_prot.x > nfs4_prot.h
	$(RPCGEN) -C -l nfs4_prot.x > nfs4_clnt.c

nfs_proc.o: nfs4_prot.h
	$(COMPILE.c) $(CPPFLAGS) $(CFLAGS) -c nfs_proc.c
	$(POST_PROCESS)

nfs_main.o: nfs_main.c
	$(COMPILE.c) $(CFLAGS) -c nfs_main.c
	$(POST_PROCESS)

$(OBJS): nfs4_prot.h

clobber clean:
	$(RM) *.o  nfs4*.?
	$(RM) $(PROGS) $(TCLLIB)
	
lint:
	$(LINT.c) $(CFLAGS) $(LINTOBJS:.o=.c)

$(TESTBIN)/%: %
	$(INS.file)

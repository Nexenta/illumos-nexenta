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
include $(SRC)/cmd/Makefile.cmd

TEST = other_tests/domain
SHRSRC = dns.test.nfs.master.tmpl dns.test.nfs.reverse.master.tmpl \
	domain.flist named.conf.tmpl nfs.master.tmpl root.master.tmpl \
	test.nfs.master.tmpl README
TCS = dnscfg dom_env dom_functions libmapid_syscfgd libmapid01 \
	libmapid02 libmapid03 libmapid04 libmapid05 nfsmapid01 \
	nfsmapid02 nfsmapid03 nfsmapid04 runtests
TCLSRC =

include ../../Makefile.test

#
# Build binaries from C sources
#
PROGS= check_domain_dl check_domain_mt check_domain derive_domain_dl \
	get_domain_mt get_domain reeval_callback resolv

SRCS = $(PROGS:%=%.c)
OBJS = $(PROGS:%=%.o)

CFLAGS = -erroff=%all	# Ignore all lint msg now
check_domain_dl derive_domain_dl resolv := LDLIBS += -lresolv
check_domain_mt check_domain get_domain_mt \
get_domain reeval_callback := LDLIBS += -lresolv \
	-L$(ROOT)/usr/lib/nfs -R/usr/lib/nfs -lmapid
LDFLAGS += -zignore

BINS = $(PROGS:%=$(TESTDIR)/%)
$(BINS) := FILEMODE = 0555

all install: $(BINS)

$(PROGS): $(OBJS)
	$(LINK.c) $@.o -o $@ $(LDLIBS)
	$(POST_PROCESS)

lint:
	for src in $(SRCS); \
	do \
	$(LINT.c) $(CFLAGS) $${src} $(LDLIBS); \
	done

clobber clean:
	-$(RM) $(OBJS) $(PROGS)

$(TESTDIR)/%: %
	$(INS.file)

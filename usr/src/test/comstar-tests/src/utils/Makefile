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
# Copyright (c) 2012 by Delphix. All rights reserved.
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#
include $(SRC)/Makefile.master

ROOTOPTPKG = $(ROOT)/opt/comstar-tests
TESTDIR = $(ROOTOPTPKG)/bin

PROGS = port_offline port_online switch_reset link_reset_port \
	br_port_offline br_port_online br_switch_reset \
	ts_port_offline ts_port_online \
	cn_port_offline cn_port_online \
	modify_chap_secret_ksh modify_chap_secret_rsh \
	modify_radius_secret_ksh
SRCS = $(PROGS:%=%.exp)

$(PROGS): $(SRCS)
	$(RM) $@
	echo \#!/bin/sh > $@
	echo \# \\ >> $@
	echo exec \$${EXPECT:-/usr/bin/expect} \"\$$0\" \$${1+\"\$$@\"} \
		>> $@
	$(CAT) $@.exp >> $@
	$(CHMOD) +x $@

EXPS = $(PROGS:%=$(TESTDIR)/%)
$(EXPS) := FILEMODE = 0555

all lint:

install: $(EXPS)

$(EXPS): $(TESTDIR)

clean clobber:
	$(RM) $(PROGS)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %
	$(INS.file)

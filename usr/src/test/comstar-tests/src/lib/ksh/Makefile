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
TESTDIR = $(ROOTOPTPKG)/lib

PROGS = comstar_cmd \
	comstar_common \
	comstar_fault \
	comstar_fcoe \
	comstar_fs \
	comstar_host \
	comstar_init \
	comstar_io \
	comstar_mpxio \
	comstar_smf \
	comstar_syslog \
	comstar_tcc \
	comstar_unix_cmd \
	comstar_utils \
	fc_host_cablepull \
	fc_target_cablepull \
	fcoet_smf \
	iscsi_host_cablepull \
	iscsi_target_cablepull \
	iscsiadm_command \
	iscsiadm_global \
	iscsiadm_info \
	iscsiadm_smf \
	iscsiadm_verify \
	iscsitadm_smf \
	isnsadm_smf \
	itadm_command \
	itadm_info \
	itadm_smf \
	itadm_verify \
	portal_utils \
	sbdadm_command \
	sbdadm_info \
	sbdadm_verify \
	stmfadm_command \
	stmfadm_info \
	stmfadm_verify \
	switch_fault \
	syntax_auto

CMDS = $(PROGS:%=$(TESTDIR)/%)
$(CMDS) := FILEMODE = 0444

all lint clean clobber:

install: $(CMDS)

$(CMDS): $(TESTDIR)

$(TESTDIR):
	$(INS.dir)

$(TESTDIR)/%: %.ksh
	$(INS.rename)

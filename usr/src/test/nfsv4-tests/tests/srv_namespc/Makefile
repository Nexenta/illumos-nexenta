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
include $(SRC)/Makefile.master

TEST = srv_namespc
SHRSRC = README SNSPC.assertions SNSPC.env SNSPC.flist 
TCLSRC = srvnspc_neg01 srvnspc_pos01 srvnspc_pos02 srvnspc_pos03 \
	srvnspc_pos04
TCS = clntspc_mnt01 clntspc_mnt02 clntspc_mnt03 clntspc_mnt04 \
	clntspc_mnt05 clntspc_mnt06 doshare runtests srvnspc_share01

include ../Makefile.test

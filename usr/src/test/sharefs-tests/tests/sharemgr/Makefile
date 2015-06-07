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
# Copyright 2014 Nexenta Systems, Inc.  All rights reserved.
#

.PARALLEL: $(SUBDIRS)

#SUBDIRS = add create delete disable move oneoff remove set_ set_security \
#	set_share show unset_ usage zfs zones

# Skip oneoff test which requires reboot twice
SUBDIRS = add create delete disable move remove set_ set_security \
	set_share show unset_ usage zfs zones

include $(SRC)/test/Makefile.com

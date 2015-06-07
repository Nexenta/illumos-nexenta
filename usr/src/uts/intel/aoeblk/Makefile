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
# Copyright 2012 Nexenta Systems, Inc.  All rights reserved.
#

# This makefile drives the production of the aoeblk driver

# Path to the base of the uts directory tree (usually /usr/src/uts).
UTSBASE	= ../..

# Define the module and object file sets.
MODULE		= aoeblk
OBJECTS		= $(AOEBLK_OBJS:%=$(OBJS_DIR)/%)
LINTS		= $(AOEBLK_OBJS:%.o=$(LINTS_DIR)/%.ln)
ROOTMODULE	= $(ROOT_DRV_DIR)/$(MODULE)
CONF_SRCDIR	= $(UTSBASE)/common/io/aoe

# Include common rules.
include		../Makefile.intel

# Define targets
ALL_TARGET	= $(BINARY) $(SRC_CONFFILE)
LINT_TARGET	= $(MODULE).lint
INSTALL_TARGET	= $(BINARY) $(ROOTMODULE) $(ROOT_CONFFILE)

# Overrides and depends_on
LDFLAGS		+= -r -dy -N drv/aoe -N drv/blkdev

LINTTAGS	+= -erroff=E_BAD_PTR_CAST_ALIGN

.KEEP_STATE:

# Default build targets.
all:		$(ALL_DEPS)

clean.lint:	$(CLEAN_LINT_DEPS)

clean:		$(CLEAN_DEPS)

clobber:	$(CLOBBER_DEPS)

def:		$(DEF_DEPS)

install:	$(INSTALL_DEPS)

lint:		$(LINT_DEPS)

modlintlib:	$(MODLINTLIB_DEPS)

# Include common targets.
include		../Makefile.targ

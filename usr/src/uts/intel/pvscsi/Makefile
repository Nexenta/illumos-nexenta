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
# Copyright 2012 Nexenta Systems, Inc. All rights reserved.
#

UTSBASE=	../..

MODULE=		pvscsi
OBJECTS=	$(PVSCSI_OBJS:%=$(OBJS_DIR)/%)
LINTS=		$(PVSCSI_OBJS:%.o=$(LINTS_DIR)/%.ln)
ROOTMODULE=	$(ROOT_DRV_DIR)/$(MODULE)
CONF_SRCDIR=	$(UTSBASE)/intel/io/scsi/adapters/pvscsi

include		$(UTSBASE)/intel/Makefile.intel

ALL_TARGET=	$(BINARY) $(CONFMOD)
LINT_TARGET=	$(MODULE).lint
INSTALL_TARGET=	$(BINARY) $(ROOTMODULE) $(ROOT_CONFFILE)

CERRWARN +=	-_gcc=-Wno-parentheses

LDFLAGS	+=	-dy -N misc/scsi -N drv/scsi_vhci

LINTTAGS +=	-erroff=E_BAD_PTR_CAST_ALIGN
LINTTAGS +=	-erroff=E_CONSTANT_CONDITION

.KEEP_STATE:

all:		$(ALL_DEPS)

clean.lint:	$(CLEAN_LINT_DEPS)

clean:		$(CLEAN_DEPS)

clobber:	$(CLOBBER_DEPS)

def:		$(DEF_DEPS)

install:	$(INSTALL_DEPS)

lint:		$(LINT_DEPS)

modlintlib:	$(MODLINTLIB_DEPS)

include		$(UTSBASE)/intel/Makefile.targ

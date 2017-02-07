#
# Copyright 2017 Nexenta Systems, Inc. All rights reserved.
#

LIBRARY= libkrrp.a
VERS= .1

OBJS_SHARED=			\
	krrp_params.o		\
	krrp_ioctl_common.o

OBJS_COMMON=			\
	libkrrp_error.o		\
	libkrrp_event.o		\
	libkrrp_ioctl.o		\
	libkrrp_session.o	\
	libkrrp_svc.o		\
	libkrrp_util.o

OBJECTS= $(OBJS_COMMON) $(OBJS_SHARED)

include ../../Makefile.lib

# install this library in the root filesystem
include ../../Makefile.rootfs

LIBS=		$(DYNLIB) $(LINTLIB)
SRCDIR=	../common

INCS +=	-I$(SRCDIR)
INCS +=	-I../../../common/krrp

LINTFLAGS +=	-erroff=E_INVALID_TOKEN_IN_DEFINE_MACRO
LINTFLAGS64 +=	-erroff=E_INVALID_TOKEN_IN_DEFINE_MACRO

LDLIBS +=	-lc -lnvpair -lumem -luuid -lsysevent -lzfs
CPPFLAGS +=	$(INCS) -D_REENTRANT

SRCS=	$(OBJS_COMMON:%.o=$(SRCDIR)/%.c)        \
	$(OBJS_SHARED:%.o=$(SRC)/common/krrp/%.c)
$(LINTLIB) := SRCS=	$(SRCDIR)/$(LINTSRC)

.KEEP_STATE:

all: $(LIBS)

lint: lintcheck

pics/%.o: ../../../common/krrp/%.c
	$(COMPILE.c) -o $@ $<
	$(POST_PROCESS_O)

include ../../Makefile.targ

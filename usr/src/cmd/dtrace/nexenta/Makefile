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
# Copyright 2018 Nexenta Systems, Inc. All rights reserved.
#

include $(SRC)/cmd/Makefile.cmd

FILES = \
	dirtydata-timestamp.d \
	dirtydata.d

BINFILES = \
	capture-flamestacks \
	flamegraph \
	iscsirwlat \
	iscsisvrtop \
	nfsio \
	nfsio30sec \
	nfssvrtop \
	nfsutil \
	nfswizard \
	stackcollapse \
	zfs-prefetch \
	zilstat \
	ziosnoop \
	ziotype


ROOTDTDIR= $(ROOT)/usr/nexenta/dtrace
ROOTFILES= $(FILES:%=$(ROOTDTDIR)/%)
ROOTBINFILES= $(BINFILES:%=$(ROOTDTDIR)/%)
FILEMODE= 555

$(ROOTDTDIR)/%: %
	$(INS.file)

.KEEP_STATE:

all:		$(FILES) $(BINFILES)

install: all $(ROOTDTDIR) $(ROOTBINFILES) $(ROOTFILES)
	@for file in $(BINFILES); do \
	$(RM) $(ROOTBIN)/$$file; $(SYMLINK) ../nexenta/dtrace/$$file $(ROOTBIN)/$$file; \
	done

clean clobber lint:

$(ROOTDTDIR):
	$(INS.dir)

$(ROOTDTDIR) := DIRMODE = 755

$(ROOTDTDIR)/dirtydata.d := FILEMODE = 644
$(ROOTDTDIR)/dirtydata-timestamp.d := FILEMODE = 644


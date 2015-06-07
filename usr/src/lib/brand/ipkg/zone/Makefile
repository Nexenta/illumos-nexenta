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
# Copyright 2010 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# Copyright 2013 Nexenta Systems, Inc.  All rights reserved.
#

PROGS=		attach clone detach fmri_compare image_install p2v \
		pkgcreatezone poststate prestate support uninstall
XMLDOCS=	config.xml platform.xml smf_disable.lst pkgrm.lst common.ksh
USERFILES=	smf_disable.conf pkgrm.conf
TEMPLATES=	SUNWipkg.xml

CLOBBERFILES=	$(ROOTPROGS) $(ROOTXMLDOCS) $(ROOTTEMPLATES) $(ETCUSER)

include $(SRC)/cmd/Makefile.cmd
include ../Makefile.ipkg

.KEEP_STATE:

all:	$(PROGS)

# Our one .py file produces an empty .po file.
# This is the easiest way to deal with it.
GNUXGETFLAGS += --force-po

POFILES =	$(PROGS:%=%.po) common.po
POFILE =	ipkg_zone.po

$(POFILE): $(POFILES)
	$(RM) $@
	$(CAT) $(POFILES) > $@

install: $(PROGS) $(ROOTPROGS) $(ROOTXMLDOCS) $(ROOTTEMPLATES) $(ETCUSER)

lint:

clean:
	-$(RM) $(PROGS) $(POFILES) $(POFILE)

support := LDLIBS += -lzonecfg

support: support.c
	$(LINK.c) -o $@ $@.c $(LDLIBS)
	$(POST_PROCESS)

include $(SRC)/cmd/Makefile.targ

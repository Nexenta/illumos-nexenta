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
# Copyright 2010 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
# Copyright 2014 Nexenta Systems, Inc. All rights reserved.
#

ETCFILES= 	ips2deb.priorities \
		ips2deb.replaces \
		ips2deb.versions

PYFILES= ips2deb

CLEANFILES = $(PYFILES)

include ../Makefile.tools

$(ROOTONBLDETCFILES) := FILEMODE=	644

.KEEP_STATE:

all:	$(PYFILES) $(SHFILES)

install: all .WAIT $(ROOTONBLDETCFILES) $(ROOTONBLDPYFILES)

clean:
	$(RM) $(CLEANFILES)

include ../Makefile.targ


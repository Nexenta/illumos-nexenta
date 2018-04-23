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
# Copyright 2018 Nexenta Systems, Inc.  All rights reserved.
#

MODULE =	LENOVO-D1224J12ESM3P
SRCS =		lenovo.c
SRCDIR =	../common
PLUGINTYPE =	vendor
ALIASES =			\
	Ericsson		\
	HGST-2U24_STOR_ENCL	\
	LENOVO-D1212J12ESM3P	\
	LENOVO-2U24ENCJ12ESM3P	\
	SANDISK-SDIFHS02

include ../../Makefile.lib

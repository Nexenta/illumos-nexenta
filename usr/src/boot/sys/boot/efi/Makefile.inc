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
# Copyright 2015 Toomas Soome <tsoome@me.com>
#

BINDIR=	/boot

# Options used when building app-specific efi components
# See conf/kern.mk for the correct set of these
CFLAGS +=	-fPIC -ffreestanding -Wformat -msoft-float
CFLAGS +=	-mno-mmx -mno-3dnow -mno-sse2 -mno-sse3 -mno-sse
CFLAGS +=	-mno-avx -fshort-wchar -mno-aes
CFLAGS +=	-std=gnu99

CFLAGS +=	-fident -finline -fno-inline-functions -fno-builtin -fno-asm
CFLAGS +=	-fdiagnostics-show-option -nodefaultlibs
CFLAGS +=	-fno-inline-small-functions -fno-inline-functions-called-once
CFLAGS +=	-fno-ipa-cp

# -D__sun -Wall -Wextra -std=gnu99 -Werror -Wno-missing-braces -Wno-sign-compare -Wno-unknown-pragmas -Wno-unused-parameter -Wno-missing-field-initializers -Wno-unused -Wno-empty-body -Wno-parentheses -Wno-uninitialized -Wno-char-subscripts -Wno-unused-variable -Wno-unused-function -Wno-unused-label -Wno-type-limits -Wno-clobbered -Wno-empty-body -Wno-unused-value
# -D_BOOT -D_BOOT_TARGET_amd64 -D_MACHDEP -D_I32LPx

CFLAGS +=	-Wno-pointer-sign -Wno-empty-body

#CFLAGS +=	-Wsystem-headers -Werror -Wall -Wno-format-y2k -W
#CFLAGS +=	-Wno-unused-parameter -Wstrict-prototypes -Wmissing-prototypes
#CFLAGS +=	-Wpointer-arith -Wreturn-type -Wcast-qual -Wwrite-strings
#CFLAGS +=	-Wswitch -Wshadow -Wunused-parameter -Wcast-align -Wno-cast-qual
#CFLAGS +=	-Wchar-subscripts -Winline -Wnested-externs -Wredundant-decls
#CFLAGS +=	-Wold-style-definition

ASFLAGS +=	-fPIC
# include ../Makefile.inc

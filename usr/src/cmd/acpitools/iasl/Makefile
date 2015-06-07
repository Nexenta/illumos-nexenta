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
# Copyright 2013 Nexenta Systems, Inc. All rights reserved.
#

PROG=		iasl
# common
OBJS +=		adfile.o adisasm.o adwalk.o ahpredef.o dmextern.o	\
		dmrestag.o dmtable.o dmtbdump.o	dmtbinfo.o getopt.o
# compiler (generated)
OBJS +=		aslcompilerparse.o aslcompilerlex.o dtparserparse.o	\
		dtparserlex.o prparserparse.o prparserlex.o
# compiler
OBJS +=		aslanalyze.o aslbtypes.o aslcodegen.o aslcompile.o	\
		aslerror.o aslfileio.o aslfiles.o aslfold.o aslhex.o	\
		asllength.o asllisting.o aslload.o asllookup.o		\
		aslmain.o aslmap.o aslmethod.o aslnamesp.o		\
		aslopcodes.o asloperands.o aslopt.o aslpredef.o		\
		aslprepkg.o aslresource.o aslrestype1.o aslrestype1i.o	\
		aslrestype2.o aslrestype2d.o aslrestype2e.o		\
		aslrestype2q.o aslrestype2s.o aslrestype2w.o		\
		aslstartup.o aslstubs.o	asltransform.o asltree.o	\
		aslutils.o asluuid.o aslwalks.o aslxref.o dtcompile.o	\
		dtexpress.o dtfield.o dtio.o dtsubtable.o dttable.o	\
		dttemplate.o dtutils.o prexpress.o prmacros.o prscan.o	\
		prutils.o
# components/debugger
OBJS +=		dbfileio.o
# components/disassembler
OBJS +=		dmbuffer.o dmdeferred.o dmnames.o dmopcode.o dmresrc.o	\
		dmresrcl.o dmresrcl2.o dmresrcs.o dmutils.o dmwalk.o
# components/dispatcher
OBJS +=		dsargs.o dscontrol.o dsfield.o dsobject.o dsopcode.o	\
		dsutils.o dswexec.o dswload.o dswload2.o dswscope.o	\
		dswstate.o
# components/executer
OBJS +=		exconvrt.o excreate.o exdump.o exmisc.o exmutex.o	\
		exnames.o exoparg1.o exoparg2.o exoparg3.o exoparg6.o	\
		exprep.o exresnte.o exresolv.o exresop.o exstore.o	\
		exstoren.o exstorob.o exsystem.o exutils.o
# components/namespace
OBJS +=		nsaccess.o nsalloc.o nsconvert.o nsdump.o nsnames.o	\
		nsobject.o nsparse.o nssearch.o nsutils.o nswalk.o
# components/parser
OBJS +=		psargs.o psloop.o psobject.o psopcode.o psopinfo.o	\
		psparse.o psscope.o pstree.o psutils.o pswalk.o
# components/tables
OBJS +=		tbfadt.o tbinstal.o tbutils.o tbxface.o
# components/utilities
OBJS +=		utaddress.o utalloc.o utcache.o utcopy.o utdebug.o	\
		utdecode.o utdelete.o utexcep.o utglobal.o utinit.o	\
		utlock.o utmath.o utmisc.o utmutex.o utobject.o		\
		utownerid.o utresrc.o utstate.o utstring.o utxface.o	\
		utxferror.o
# os_specific/service_layers
OBJS +=		osunixxf.o

CLEANFILES=	aslcompiler.y.h aslcompilerlex.c aslcompilerparse.c	\
		dtparser.y.h dtparserlex.c dtparserparse.c prparser.y.h	\
		prparserlex.c prparserparse.c

ACPICA=		$(SRC)/uts/intel/io/acpica

include		$(SRC)/cmd/Makefile.cmd

C99MODE=	$(C99_ENABLE)
CPPFLAGS +=	-DACPI_ASL_COMPILER -DACPI_USE_STANDARD_HEADERS		\
		-I$(SRC)/uts/intel/sys/acpi -I$(ACPICA)/compiler -I.

# Flags for flex and bison
LFLAGS=		-i -s
YFLAGS=		-d

.KEEP_STATE:

all:		$(PROG)

clean:
		$(RM) $(CLEANFILES) $(OBJS)

install:	all $(ROOTPROG)

$(PROG):	$(OBJS)
		$(LINK.c) $(OBJS) -o $@ $(LDLIBS)
		$(POST_PROCESS)

aslcompilerlex.c: $(ACPICA)/compiler/aslcompiler.l $(ACPICA)/compiler/aslsupport.l
		$(FLEX) $(LFLAGS) -PAslCompiler -o$@ $(ACPICA)/compiler/aslcompiler.l

aslcompilerparse.c: $(ACPICA)/compiler/aslcompiler.y
		$(BISON) $(YFLAGS) -pAslCompiler -o$@ $(ACPICA)/compiler/aslcompiler.y
		$(RM) aslcompiler.y.h; $(MV) aslcompilerparse.h aslcompiler.y.h

dtparserlex.c:	$(ACPICA)/compiler/dtparser.l
		$(FLEX) $(LFLAGS) -PDtParser -o$@ $(ACPICA)/compiler/dtparser.l

dtparserparse.c: $(ACPICA)/compiler/dtparser.y
		$(BISON) $(YFLAGS) -pDtParser -o$@ $(ACPICA)/compiler/dtparser.y
		$(RM) dtparser.y.h; $(MV) dtparserparse.h dtparser.y.h

prparserlex.c:	$(ACPICA)/compiler/prparser.l
		$(FLEX) $(LFLAGS) -PPrParser -o$@ $(ACPICA)/compiler/prparser.l

prparserparse.c: $(ACPICA)/compiler/prparser.y
		$(BISON) $(YFLAGS) -pPrParser -o$@ $(ACPICA)/compiler/prparser.y
		$(RM) prparser.y.h; $(MV) prparserparse.h prparser.y.h

%.o:		$(ACPICA)/common/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

%.o:		$(ACPICA)/compiler/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

%.o:		$(ACPICA)/components/debugger/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

%.o:		$(ACPICA)/components/disassembler/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

%.o:		$(ACPICA)/components/dispatcher/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

%.o:		$(ACPICA)/components/executer/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

%.o:		$(ACPICA)/components/namespace/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

%.o:		$(ACPICA)/components/parser/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

%.o:		$(ACPICA)/components/tables/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

%.o:		$(ACPICA)/components/utilities/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

%.o:		$(ACPICA)/os_specific/service_layers/%.c
		$(COMPILE.c) -o $@ $<
		$(POST_PROCESS_O)

include		$(SRC)/cmd/Makefile.targ

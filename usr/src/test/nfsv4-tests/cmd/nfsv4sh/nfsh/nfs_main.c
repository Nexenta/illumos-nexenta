/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "tcl.h"
#include "nfstcl4.h"

/* This variable is used to keep the path from argv[0] to find tclprocs. */
static char	*buffer;

/*
 * The following variable is a special hack that is needed in order for
 * Sun shared libraries to be used for Tcl.
 */

extern int main();
extern void nfs_initialize();

int *tclDummyMainPtr = (int *)main;
Tcl_Interp *interp;

/*
 * -----------------------------------------------------------------
 *
 * main --
 *
 *	This is the main program for the application.
 *
 * Results:
 *	None: Tcl_Main never returns here, so this procedure never
 *	returns either.
 *
 * Side effects:
 *	Whatever the application does.
 *
 * -----------------------------------------------------------------
 */

int
main(argc, argv)
	int argc;	/* Number of command-line arguments. */
	char **argv;	/* Values of command-line arguments. */
{
	extern char	*optarg;
	extern int	optind,
	    optopt,
	    opterr;
	char		*tmp_ptr;
	int		c,
	    Vflg = 0,
	    errflg = 0;

	opterr = 0;

#ifdef TCL_TEST
	/*
	 * Pass the build time location of the tcl library
	 * (to find init.tcl)
	 */
	Tcl_Obj *path;
	path = Tcl_NewStringObj(TCL_BUILDTIME_LIBRARY, -1);
	TclSetLibraryPath(Tcl_NewListObj(1, &path));

#endif

#ifdef TCL_XT_TEST
	XtToolkitInitialize();
#endif

	/* search for flags */
	while ((c = getopt(argc, argv, "V")) != EOF)
		switch (c) {
		case 'V':
			Vflg++;
			break;
		case '?':
			errflg++;
			break;
		default:
			break;
		}

	if (errflg) {
		fprintf(stderr, "usage: %s [-V]\n", argv[0]);
		exit(1);
	}

	if (Vflg)
#ifdef NFSH_VERS
		printf("%s version %s\n", argv[0], NFSH_VERS);
#else
	printf("%s version unknown.\n", argv[0]);
#endif

	/* check for path information on argv[0], if so, use it for tclprocs */
#undef DEBUG_BUFFER
#ifdef DEBUG_BUFFER
	printf("argv[0] = <%s>\n", argv[0]);
#endif /* DEBUG_BUFFER */
	if (strchr(argv[0], '/') != NULL) {
		/* store argv[0] path */
		buffer = malloc(strlen(argv[0]) + 255);
		strcpy(buffer, argv[0]);
		tmp_ptr = strrchr(buffer, '/');
		if (tmp_ptr == NULL)
			buffer = NULL;
		else {
			++tmp_ptr;
			*tmp_ptr = '\0';
		}
#ifdef DEBUG_BUFFER
		printf("buffer = <%s>\n", buffer);
#endif /* DEBUG_BUFFER */
	} else
		buffer = NULL;

	Tcl_Main(argc, argv, Tcl_AppInit);
	return (0);	/* Needed only to prevent compiler warning. */
}


/*
 * -----------------------------------------------------------------
 *
 * Tcl_AppInit --
 *
 *	This procedure performs application-specific initialization.
 *	Most applications, especially those that incorporate additional
 *	packages, will have their own version of this procedure.
 *
 * Results:
 *	Returns a standard Tcl completion code, and leaves an error
 *	message in the interp's result if an error occurs.
 *
 * Side effects:
 *	Depends on the startup script.
 *
 * -----------------------------------------------------------------
 */

int
Tcl_AppInit(interp)
	Tcl_Interp *interp;		/* Interpreter for application. */
{
	char	*default_procs = "tclprocs";
	char	nfshvers[10];
	int	i;

	if (Tcl_Init(interp) == TCL_ERROR) {
		return (TCL_ERROR);
	}

#ifdef TCL_TEST
#ifdef TCL_XT_TEST
	if (Tclxttest_Init(interp) == TCL_ERROR) {
		return (TCL_ERROR);
	}
#endif
	if (Tcltest_Init(interp) == TCL_ERROR) {
		return (TCL_ERROR);
	}

	Tcl_StaticPackage(interp, "Tcltest", Tcltest_Init,
	    (Tcl_PackageInitProc *) NULL);

	if (TclObjTest_Init(interp) == TCL_ERROR) {
		return (TCL_ERROR);
	}

#ifdef TCL_THREADS
	if (TclThread_Init(interp) == TCL_ERROR) {
		return (TCL_ERROR);
	}
#endif
	if (Procbodytest_Init(interp) == TCL_ERROR) {
		return (TCL_ERROR);
	}

	Tcl_StaticPackage(interp, "procbodytest", Procbodytest_Init,
	    Procbodytest_SafeInit);

#endif /* TCL_TEST */

	/*
	 * Call the init procedures for included packages.
	 * Each call should look like this:
	 *
	 * if (Mod_Init(interp) == TCL_ERROR) {
	 *	return (TCL_ERROR);
	 * }
	 *
	 * where "Mod" is the name of the module.
	 */

	/*
	 * Call Tcl_CreateCommand for application-specific commands, if
	 * they weren't already created by the init procedures called above.
	 */

	nfs_initialize(interp);

	/*
	 * Specify a user-specific startup file to invoke if the
	 * application is run interactively.  Typically the
	 * startup file is "~/.apprc" where "app" is the name of
	 * the application.  If this line is deleted then no
	 * user-specific startup file will be run under any
	 * conditions.
	 */

	Tcl_SetVar(interp, "tcl_rcFileName", "~/.tclshrc", TCL_GLOBAL_ONLY);

#ifdef NFSH_VERS
	/*
	 * set the variable "nfsh_version" for the version number
	 * of the tool.  It's value is defined by NFSH_VERS at
	 * compile time.  If it is not set, "Unknown"  will be printed.
	 */
	sprintf(nfshvers, "%s", NFSH_VERS);
	Tcl_SetVar(interp, "nfsh_version", nfshvers, TCL_GLOBAL_ONLY);
#else
	Tcl_SetVar(interp, "nfsh_version", "Unknown", TCL_GLOBAL_ONLY);
#endif

	/* check for path information stored in buffer. */
	/* If so, use it for tclprocs. */
	if (buffer == NULL) {
		/* look under PATH */
#ifdef DEBUG_BUFFER
		printf("default_procs = <%s>\n", default_procs);
#endif /* DEBUG_BUFFER */
		if ((default_procs = find_file(default_procs, "PATH", ":"))
		    == NULL) {
			interp->result = "cannot read [tclprocs].";
			return (TCL_ERROR);
		}
	} else { /* use argv[0] path and append default_procs */
		strcat(buffer, default_procs);
		default_procs = buffer;
#ifdef DEBUG_BUFFER
		printf("default_procs = <%s>\n", default_procs);
#endif /* DEBUG_BUFFER */
	}

	if (Tcl_EvalFile(interp, default_procs) == TCL_ERROR) {
		interp->result = "unable to load [tclprocs].";
		return (TCL_ERROR);
	}

	/* clear buffer */
	if (buffer != NULL)
		free(buffer);

	return (TCL_OK);
}

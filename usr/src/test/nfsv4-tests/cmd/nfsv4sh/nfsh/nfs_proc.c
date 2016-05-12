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

#include <netdb.h>
#include <netconfig.h>
#include <netdir.h>
#include <rpc/rpc.h>
#include <rpc/clnt.h>
#include <rpc/clnt_soc.h>
#include <sys/socket.h>
#include <unistd.h>
#include "nfs4_prot.h"
#include "nfstcl4.h"

/* maximal size of argv[] for nfs_connection */
#define	MAX_RECONNECTION_ARGS	7

CLIENT *client;		/* Global client handle */

/* tcl procedure table */
NFSPROC nfs_proc[] = {
	{"connect",	nfs_connect		},
	{"disconnect",	nfs_disconnect		},
	{"nullproc",	nfs_nullproc		},
	{"compound",	nfs_compound		},
	{0,		0	},
};

static int reconnection(ClientData clientData,
    Tcl_Interp *interp, int argc, char *argv[]);

/*
 * Avoid calling clnt_create() here because this
 * client needs to connect to the server on a well-known
 * port - 2049.  This used to be easy with the original
 * RPC API, but since TLI and TI-RPC, it's become extraordinarly
 * difficult - as the following code shows.
 */
int
nfs_connect(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	struct timeval tv;
	char *host;
	struct t_bind *tbind = NULL;
	int fd;
	struct t_info tinfo;
	struct nd_hostserv hs;
	struct nd_addrlist *retaddrs;
	struct netconfig *nconf;
	int c;
	ushort_t port = NFS_PORT;
	char *transport = "tcp";
	int err = 0;
	char *secflav = "sys";
	char mech_krb[] = "kerberos_v5";
	char service_name[128];
	struct hostent *he;
	rpc_gss_service_t service = rpc_gss_svc_none;
	rpc_gss_options_ret_t o;

#ifdef DEBUG_PROC
	{
		int	i;

		(void) fprintf(stderr,
		    "debug nfs_connect:\n"
		    "    &clientData == %p\n",
		    "    interp = %p\n"
		    "    argc == %d\n",
		    &clientData, interp, argc);
		for (i = 0; i < argc; i++) {
			(void) fprintf(stderr, "    argv[%d] == %s\n",
			    i, argv[i]);
		}
		(void) fprintf(stderr,
		    "debug nfs_connect: starting with client == %p\n",
		    client);
	}
#endif	/* DEBUG_PROC */
	/* reset option index to one */
	optind = 1;
	while ((c = getopt(argc, argv, "p:t:s:")) != EOF) {
		switch (c) {
		case 'p':
			port = atoi(optarg);
			break;
		case 't':
			transport = optarg;
			break;
		case 's':
			secflav = optarg;
			break;
		default:
			err++;
			break;
		}
	}

	if (err || (argc - optind != 1)) {
		interp->result =
		    "Usage: connect [-p port] "
		    "[-t tcp|udp] [-s sys|krb5|krb5i|krb5p] <hostname>";
		return (TCL_ERROR);
	}

	if (client != NULL) {
		clnt_destroy(client);
		client = NULL;
	}

	host = argv[optind];

	/* save host */
	if (reconnection(clientData, interp, argc, argv) != 0)
		return (TCL_ERROR);

	nconf = getnetconfigent(transport);
	if (nconf == NULL)
		goto done;

	if ((fd = t_open(nconf->nc_device, O_RDWR, &tinfo)) < 0)
		goto done;

	/* LINTED pointer alignment */
	if ((tbind = (struct t_bind *)t_alloc(fd, T_BIND, T_ADDR))
	    == NULL)
		goto done;

	hs.h_host = host;
	hs.h_serv = NULL;

	if (netdir_getbyname(nconf, &hs, &retaddrs) != ND_OK) {
		goto done;
	}
	(void) memcpy(tbind->addr.buf, retaddrs->n_addrs->buf,
	    retaddrs->n_addrs->len);
	tbind->addr.len = retaddrs->n_addrs->len;
	netdir_free((void *)retaddrs, ND_ADDRLIST);

	if (strcmp(nconf->nc_protofmly, NC_INET) == NULL)
		/* LINTED pointer cast may result in improper alignment */
		((struct sockaddr_in *)
		    tbind->addr.buf)->sin_port =
		    htons(port);
#ifdef INET6
	else if (strcmp(nconf->nc_protofmly, NC_INET6) == NULL)
		((struct sockaddr_in6 *)
		    tbind->addr.buf)->sin6_port =
		    htons((ushort_t)NFS_PORT);
#endif /* INET6 */

	client = clnt_tli_create(fd, nconf, &tbind->addr, NFS4_PROGRAM,
	    4, 0, 0);

	if (client == NULL) {
		if (reconnection(clientData, interp, 0, NULL) == 0)
			return (TCL_OK);
		interp->result =
		    "connect failed - can't create client handle";
		clnt_pcreateerror("clnt_tli_create");
#ifdef DEBUG_PROC
		(void) fprintf(stderr,
		    "debug nfs_connect %s: client == %p, TCL_ERROR\n",
		    interp->result, client);
#endif	/* DEBUG_PROC */
		return (TCL_ERROR);
	}

	tv.tv_sec = 0;
	tv.tv_usec = 700000;
	clnt_control(client, CLSET_RETRY_TIMEOUT, (char *)&tv);

	tv.tv_usec = 0;
	clnt_control(client, CLGET_RETRY_TIMEOUT, (char *)&tv);

	if (strcmp(secflav, "sys") == 0)
		client->cl_auth = authunix_create_default();
#ifdef _RPCGSS
	else {
		if (strcmp(secflav, "krb5") == 0)
			service = rpc_gss_svc_none;
		if (strcmp(secflav, "krb5i") == 0)
			service = rpc_gss_svc_integrity;
		if (strcmp(secflav, "krb5p") == 0)
			service = rpc_gss_svc_privacy;

		strcpy(service_name, "nfs@");
		he = gethostbyname(host);
		strcat(service_name, he->h_name);

		client->cl_auth = rpc_gss_seccreate(client,
		    service_name, mech_krb, service, NULL, NULL, &o);
	}
#endif
	if (client->cl_auth == NULL) {
		interp->result =
		    "connect failed - can't create cl_auth.";
		clnt_pcreateerror("auth creation");
		clnt_destroy(client);
		client = NULL;
#ifdef DEBUG_PROC
		(void) fprintf(stderr,
		    "debug nfs_connect: client == %p, TCL_ERROR\n", client);
#endif	/* DEBUG_PROC */
		return (TCL_ERROR);
	}

#ifdef DEBUG_PROC
	(void) fprintf(stderr, "debug nfs_connect: client == %p, TCL_OK\n",
	    client);
#endif	/* DEBUG_PROC */
	return (TCL_OK);

done:
	if (tbind)
		t_free((char *)tbind, T_BIND);

	if (fd >= 0)
		(void) t_close(fd);

	interp->result = "connect failed - unable to netconfig.";
#ifdef DEBUG_PROC
	(void) fprintf(stderr,
	    "debug nfs_connect %s: client == %p, TCL_ERROR\n",
	    interp->result, client);
#endif	/* DEBUG_PROC */
	return (TCL_ERROR);
}

/*
 * Break the connection to the server and
 * destroy the client handle.
 */
/* ARGSUSED0 */
int
nfs_disconnect(ClientData clientData, Tcl_Interp *interp,
    int argc, char *argv[])
{
#ifdef DEBUG_PROC
	(void) fprintf(stderr, "debug nfs_disconnect: client == %p\n", client);
#endif	/* DEBUG_PROC */
	if (client == NULL) {
		interp->result = "No connection to server";
		return (TCL_ERROR);
	}

	auth_destroy(client->cl_auth);
	clnt_destroy(client);
	client = NULL;

#ifdef DEBUG_PROC
	(void) fprintf(stderr,
	    "debug nfs_disconnect: client == %p, TCL_OK\n", client);
#endif	/* DEBUG_PROC */
	return (TCL_OK);
}

/*
 * Call the null procedure of the server
 */
/* ARGSUSED0 */
int
nfs_nullproc(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	if (client == NULL) {
		interp->result = "No connection to server";
		return (TCL_ERROR);
	}

	nfsproc4_null_4(NULL, client);

	return (TCL_OK);
}


COMPOUND4args compound_args;
COMPOUND4res  compound_res;
int opmax, opcount;
nfs_argop4 *opvals;

/*
 * This function provides a new argop from a sequence
 * of compound ops that is ready to be filled-in by
 * an op* routine.  If the compound op array in opvals
 * is too small, the routine will double its size.
 */
nfs_argop4 *
new_argop()
{
	if (opvals == NULL) {
		opmax = 8;
		opcount = 0;
		opvals = malloc(opmax * sizeof (nfs_argop4));
	}

	if (opcount >= opmax) {
		opmax *= 2;
		opvals = realloc(opvals, opmax * sizeof (nfs_argop4));
	}

	if (opvals == NULL) {
		(void) printf("new_argop: malloc failed");
		exit(1);
	}

	return (&opvals[opcount++]);
}

/*
 * Generate a compound request.
 */
int
nfs_compound(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	int err;
	COMPOUND4res *resp;
	const char *tag;
	struct rpc_err rpc_err;
	int retry_cnt;
	int mvers;		/* minor version */

	if (argc != 2) {
		interp->result = "Usage: compound { ops ... }";
		return (TCL_ERROR);
	}

	if (client == NULL) {
		interp->result = "No connection to server";
		return (TCL_ERROR);
	}

	/*
	 * Allow the script writer to set the "tag"
	 * string and minor version on the compound call.
	 */
	tag = Tcl_GetVar(interp, "minorversion", 0);
	if (tag == NULL)		/* use "tag" temporary */
		mvers = 0;
	else
		mvers = (int)atoi(tag);

	tag = Tcl_GetVar(interp, "tag", 0);
	if (tag == NULL)
		tag = "";

	compound_args.tag = *str2utf8(tag);
	compound_args.minorversion = mvers;
	opcount = 0;
	opvals = NULL;
#ifdef DEBUG_PROC
		(void) fprintf(stderr,
		"debug nfs_compound: compound_args.tag=%s, minorversion=%d\n",
		    tag, mvers);
#endif	/* DEBUG_PROC */

	/*
	 * The body of the compound call (the ops in
	 * the curly braces) is handled by this Eval.
	 */
	err = Tcl_Eval(interp, argv[1]);
	if (err != TCL_OK) {
#ifdef DEBUG_PROC
		(void) fprintf(stderr,
		    "debug nfs_compound: Tcl_Eval(interp, argv[1]) == %s\n",
		    interp->result);
#endif	/* DEBUG_PROC */
		return (err);
	}

	Tcl_UnsetVar(interp, "status", 0);

	/*
	 * Now have a completely encoded compound op.
	 * Just plug it into the RPC args and call
	 * the server ...
	 */
	compound_args.argarray.argarray_len = opcount;
	compound_args.argarray.argarray_val = opvals;

	for (retry_cnt = 0; retry_cnt <= 1; retry_cnt++) {

#ifdef DEBUG_PROC
		(void) fprintf(stderr,
		    "debug nfs_compound: for (retry_cnt = %d...\n",
		    retry_cnt);
		(void) fprintf(stderr, "\tclient == %p\n", client);
		if (client != (CLIENT *)NULL) {
			(void) fprintf(stderr,
			    "\t\tcl_auth == %p\n"
			    "\t\tcl_private == %p\n"
			    "\t\tcl_netid == %p\n"
			    "\t\tcl_tp == %p\n",
			    client->cl_auth, client->cl_private,
			    client->cl_netid, client->cl_tp);
			if (client->cl_netid) {
				(void) fprintf(stderr,
				    "\t\tclient->cl_netid == %s\n",
				    client->cl_netid);
			}
			if (client->cl_tp) {
				(void) fprintf(stderr,
				    "\t\tclient->cl_tp == %s\n",
				    client->cl_tp);
			}
		}
#endif	/* DEBUG_PROC */

		if (client == (CLIENT *)NULL)
			break;
		resp = nfsproc4_compound_4(&compound_args, client);
#ifdef DEBUG_PROC
		(void) fprintf(stderr,
		    "debug nfs_compound: nfsproc4_compound_4() == %p\n",
		    resp);
#endif	/* DEBUG_PROC */
		if (resp == NULL) {
			clnt_geterr(client, &rpc_err);
#ifdef DEBUG_PROC
			(void) fprintf(stderr,
			    "debug nfs_compound:\n"
			    "\tclnt_sperrno(rpc_err.re_status) == %s\n",
			    clnt_sperrno(rpc_err.re_status));
#endif	/* DEBUG_PROC */
			if (rpc_err.re_status == RPC_CANTRECV ||
			    rpc_err.re_status == RPC_TIMEDOUT) {
				/* reconnect and retry */
				if (reconnection(clientData, interp, 0, NULL) !=
				    -1)
					continue; /* retry compound */
			}
#ifdef DEBUG_PROC
			(void) fprintf(stderr,
			    "debug nfs_compound: RPC error\n");
#endif	/* DEBUG_PROC */
			(void) snprintf(interp->result, sizeof (interp->result),
	 		    "RPC error: %s\n", clnt_sperrno(rpc_err.re_status));
			return (TCL_ERROR);
		}
		break;
	}
	if (resp == NULL) {
		(void) snprintf(interp->result, sizeof (interp->result),
		    "RPC error: %s\n", clnt_sperrno(rpc_err.re_status));
		return (TCL_ERROR);
	}

	/*
	 * Evaluate the compound result here.
	 */
	return (compound_result(interp, resp));
}

/*
 * This is called from the generic main() function
 * to register the new Tcl commands.
 */
void
nfs_initialize(Tcl_Interp *interp)
{
	int i;

	client = NULL;

	for (i = 0; nfs_proc[i].name != NULL; i++) {
		Tcl_CreateCommand(interp,
		    nfs_proc[i].name, nfs_proc[i].func,
		    (ClientData) NULL,
		    (Tcl_CmdDeleteProc *) NULL);
	}

	/*
	 * Register the compound ops.
	 */
	op_createcom(interp);
}

/*
 * Reconnection for the case server failed.
 */
static int
reconnection(ClientData clientData, Tcl_Interp *interp,
    int argc, char *argv[])
{
	static int	connect_argc;
	static char	*connect_argv[MAX_RECONNECTION_ARGS];
	static size_t	connect_argv_size[MAX_RECONNECTION_ARGS];
	static int	args_saved = 0;
	static int	recursion = 0;
	size_t		arg_size;
	int		ind;
	int		sleep_cnt;
	int 		reconnect_cnt;
	int		reconnected = 0;

	if (argc != 0) {
		/* save arguments to connection */
		if (connect_argc == 0) {
			/* get argument vector */
			arg_size = 64;
			for (ind = 0; ind < MAX_RECONNECTION_ARGS;
			    ind++) {
				connect_argv[ind] =
				    (char *)malloc(arg_size);
				if (connect_argv[ind] == NULL) {
					perror("malloc(arg_size)");
					return (-1);
				}
				connect_argv_size[ind] = arg_size;
			}
		}
		/* save arguments counter */
		connect_argc = argc;
		/* save arguments vector */
		if (argc > MAX_RECONNECTION_ARGS) {
			(void) fprintf(stderr,
			    "Test ERROR: MAX_RECONNECTION_ARGS "
			    "should be %d!!!\n",
			    argc);
			return (-1);
		}
		for (ind = 0; ind < argc; ind++) {
			arg_size = strlen(argv[ind]) + 1;
			if (strlcpy(connect_argv[ind], argv[ind],
			    connect_argv_size[ind]) >=
			    connect_argv_size[ind]) {
				connect_argv[ind] = realloc(connect_argv[ind],
				    arg_size);
				if (connect_argv[ind] == NULL) {
					perror("realloc(connect_argv[ind], "
					    "arg_size)");
					return (-1);
				}
				connect_argv_size[ind] = arg_size;
				(void) strlcpy(connect_argv[ind], argv[ind],
				    connect_argv_size[ind]);
			}
		}
		args_saved = 1;
		return (0);
	} else {
		/* reconnect */
		if (!args_saved) {
			(void) fprintf(stderr,
			    "ERROR:\nfile %s, line %d:\n"
			    "connect_argv not initialized!!!\n",
			    __FILE__, __LINE__);
			recursion = 0;
			return (-1);
		}
		if (recursion == 0) {
			recursion = 20; /* 20 times of 30 sec == 10 min */
		} else {
			return (-1);
		}
		for (reconnect_cnt = 0; reconnect_cnt < recursion;
		    reconnect_cnt++) {
#ifdef DEBUG_PROC
			(void) fprintf(stderr,
			    "\tdebug reconnection: reconnect_cnt == %d: "
			    "30 sec delay to restart server\n",
			    reconnect_cnt);
#endif	/* DEBUG_PROC */
			sleep_cnt = 30; /* retry each 30 sec */
			while (sleep_cnt > 0) {
				sleep_cnt = sleep(sleep_cnt);
			}
			(void) nfs_disconnect(clientData, interp, 0, NULL);
			if (nfs_connect(clientData, interp,
			    connect_argc, connect_argv) ==
			    TCL_OK) {
				reconnected = 1;
#ifdef DEBUG_PROC
				(void) fprintf(stderr,
				    "debug reconnection: reconnected.\n");
#endif	/* DEBUG_PROC */
				break;
#ifdef DEBUG_PROC
			} else {
				(void) fprintf(stderr,
				    "debug reconnection: "
				    "reconnection try failed.\n");
#endif	/* DEBUG_PROC */
			}
		}	/* reconnection loop */
		recursion = 0;
		return (reconnected ? 0 : -1);
	}
}

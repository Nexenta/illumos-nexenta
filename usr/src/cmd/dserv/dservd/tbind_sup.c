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
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 *
 * Copyright 2011 Nexenta Systems, Inc. All rights reserved.
 */

#include <nfs/nfs.h>
#include <nfs/nfs4.h>
#include <libintl.h>
#include <sys/param.h>
#include <sys/tiuser.h>
#include <rpc/svc.h>
#include "nfs_tbind.h"
#include <nfs/nfssys.h>
#include <libdserv.h>
#include <dservd.h>
#include "libdserv_impl.h"

#define	PNFSCTLMDS	104000
#define	PNFSCTLMDS_V1	1

#ifndef TEXT_DOMAIN
#define	TEXT_DOMAIN	"SUNW_OST_OSCMD"
#endif /* TEXT_DOMAIN */

/*
 * The following are all globals used by routines in nfs_tbind.c.
 */
size_t	end_listen_fds;		/* used by conn_close_oldest() */
size_t	num_fds = 0;		/* used by multiple routines */
int	listen_backlog = 32;	/* used by bind_to_{provider,proto}() */
int	num_servers;		/* used by cots_listen_event() */
int	(*Mysvc)(int, struct netbuf, struct netconfig *) = NULL;
				/* used by cots_listen_event() */
int	max_conns_allowed = -1;	/* used by cots_listen_event() */

#define	MAXHOSTNAMELEN 64

static dserv_handle_t *do_all_handle;

static int
make_sock_nonblock(int sock)
{
	int flags;

	flags = fcntl(sock, F_GETFL, 0);
	if (flags < 0)
		return (-1);

	return (fcntl(sock, F_SETFL, flags | O_NONBLOCK));
}

/*
 * The function gets DS IP address and saves it to ds_sa.
 * DS IP address is detected during the attempt to connect
 * to MDS specified by mds_sa.
 *
 * On success function returns 0 and negative value otherwise.
 */
static int
get_dserv_address(const struct sockaddr *mds_sa,
    socklen_t addrlen, struct sockaddr *ds_sa)
{
	int ret, sock;

	sock = socket(mds_sa->sa_family, SOCK_STREAM, 0);
	if (sock < 0)
		return (-1);

	/*
	 * Make socket nonblocking in order to prevent
	 * dservd from blocking in connect(). We don't need to
	 * make real connect to MDS, we just want to determine
	 * local IP address DS uses to connect to MDS.
	 */
	if ((ret = make_sock_nonblock(sock) < 0))
		goto out;

	if ((ret = connect(sock, mds_sa, addrlen)) < 0)
		if (errno != EINPROGRESS)
			goto out;

	ret = getsockname(sock, ds_sa, &addrlen);

out:
	close(sock);
	return (ret);
}

/*
 * The function gets DS IP address and represents it
 * in a form of uaddr concatenating the address with
 * port given in nb_port netbuf.
 *
 * On success function returns valid uaddr and NULL
 * otherwise.
 */
static char *
get_uaddr(struct sockaddr *mds_sa,
    struct netconfig *nconf, struct netbuf *nb_port)
{
	socklen_t addrlen;
	struct netbuf cli_nb;
	char *uaddr = NULL;
	dsaddr_t ds_addr;

	addrlen = (mds_sa->sa_family == AF_INET) ?
	    sizeof (struct sockaddr_in) : sizeof (struct sockaddr_in6);

	if (get_dserv_address(mds_sa, addrlen, &ds_addr.sa) < 0)
		return (NULL);

	/* Fetch port from nb_port netbuf and save it ds_addr */
	if (mds_sa->sa_family == AF_INET) {
		struct sockaddr_in *sin;

		sin = (struct sockaddr_in *)nb_port->buf;
		ds_addr.sin.sin_port = sin->sin_port;
	} else {
		struct sockaddr_in6 *sin6;

		sin6 = (struct sockaddr_in6 *)nb_port->buf;
		ds_addr.sin6.sin6_port = sin6->sin6_port;
	}

	cli_nb.buf = (char *)&ds_addr.sa;
	cli_nb.len = cli_nb.maxlen = addrlen;
	uaddr = taddr2uaddr(nconf, &cli_nb);

	return (uaddr);
}

static int
do_dserv_krpc_start(struct netconfig *nconf, struct netbuf *addr, int fd)
{
	dserv_svc_args_t svcargs;

	svcargs.fd = fd;
	bcopy(addr->buf, &svcargs.sin, addr->len);
	(void) strlcpy(svcargs.netid,
	    nconf->nc_netid, sizeof (svcargs.netid));

	return (dserv_kmod_svc(do_all_handle, &svcargs));
}

static int
do_dserv_setport(struct netconfig *nconf, struct netbuf *addr)
{
	int result = 0, mds_af;
	dserv_setport_args_t setportargs;
	struct dserv_mdsaddr **p;
	char *uaddr;

	mds_af = ((struct sockaddr_in *)addr->buf)->sin_family;
	(void) strlcpy(setportargs.dsa_proto, nconf->nc_proto,
	    sizeof (setportargs.dsa_proto));
	(void) strlcpy(setportargs.dsa_name, getenv("SMF_FMRI"),
	    sizeof (setportargs.dsa_name));


	/*
	 * dsh_mdsaddr array contains different IP addresses of
	 * one MDS server. Here we try to register all possible
	 * DS addresses that can be used for DS multipathing.
	 */
	for (p = &do_all_handle->dsh_mdsaddr[0]; *p != NULL; p++) {
		struct dserv_mdsaddr *mdsaddr = *p;

		/*
		 * skip address if its address family is not compatible
		 * with family of MDS address.
		 */
		if (mdsaddr->addr.mdsaddr_family != mds_af)
			continue;

		uaddr = get_uaddr(&mdsaddr->addr.sa, nconf, addr);

		if (uaddr == NULL) {
			dserv_log(do_all_handle, LOG_WARNING,
			    gettext("NFS4_SETPORT: get_uaddr failed for "
			    "MDS %s\n"), mdsaddr->name);
			result = 1;
			continue;
		}

		(void) strlcpy(setportargs.dsa_uaddr, uaddr,
		    sizeof (setportargs.dsa_uaddr));

		result = dserv_kmod_setport(do_all_handle,
		    &setportargs);
		free(uaddr);

		if (result != 0) {
			dserv_log(do_all_handle, LOG_ERR,
			    gettext("NFS4_SETPOR: failed for MDS %s\n"),
			    mdsaddr->name);
			break;
		}
	}

	return (result);
}

/*
 * dserv_service is called either with a command of
 * NFS4_KRPC_START or SETPORT. Any other value is
 * invalid.
 */
static int
dserv_service(int fd, struct netbuf *addrmask, struct netconfig *nconf,
    int cmd, struct netbuf *addr)
{
	int result = 0;

	/* ignore non tcp proto */
	if (strncasecmp(nconf->nc_proto, NC_TCP, strlen(NC_TCP)))
		return (0);

	if (cmd & NFS4_KRPC_START)
		result = do_dserv_krpc_start(nconf, addr, fd);

	if ((result == 0) && (cmd & NFS4_SETPORT))
		result = do_dserv_setport(nconf, addr);

	/*
	 * result can be either negative, positive or 0.
	 * Negative error code denotes errors happened
	 * inside libdserv. Positive error code denotes all
	 * other errors.
	 */
	if (result < 0) {
		dserv_log(do_all_handle, LOG_ERR, NULL);
		errno = do_all_handle->dsh_errno_error;
	}

	return (result);
}

void
dserv_daemon(dserv_handle_t *handle)
{
	struct svcpool_args dserv_svcpool;
	struct protob dservproto;

	bzero(&dserv_svcpool, sizeof (dserv_svcpool));

	dserv_svcpool.id = UNIQUE_SVCPOOL_ID;

	if (_nfssys(SVCPOOL_CREATE, &dserv_svcpool)) {
		dserv_log(handle, LOG_ERR,
		    gettext("SVCPOOL_CREATE failed: %m"));
		exit(1);
	}

	dserv_set_pool_id(handle, dserv_svcpool.id);

	if (svcwait(dserv_svcpool.id)) {
		dserv_log(handle, LOG_ERR,
		    gettext("svcwait(DSERV_SVCPOOL_ID) failed: %m"));
		exit(1);
	}

	dservproto.serv = "DSERV";
	dservproto.versmin = PNFSCTLMDS_V1;
	dservproto.versmax = PNFSCTLMDS_V1;
	dservproto.program = PNFSCTLMDS;
	dservproto.flags = PROTOB_NO_REGISTER;
	dservproto.next = NULL;

	/*
	 * We love globals!
	 */
	Mysvc4 = dserv_service;
	do_all_handle = handle;
	if (do_all(&dservproto, NULL) == -1) {
		dserv_log(handle, LOG_ERR,
		    gettext("do_all(): %m"));
		exit(1);
	}
	if (num_fds == 0) {
		dserv_log(handle, LOG_ERR,
		    gettext("Could not start DSERV service for any protocol"));
		exit(1);
	}

	if (dserv_kmod_reportavail(handle)) {
		dserv_log(handle, LOG_ERR, gettext("reportavail"));
		exit(1);
	}

	end_listen_fds = num_fds;
	poll_for_action();

	dserv_log(handle, LOG_INFO,
	    gettext("I am shutting down now"));

	exit(1);
}

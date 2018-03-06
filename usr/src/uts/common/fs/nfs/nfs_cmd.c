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
 * Copyright 2010 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * Copyright 2018 Nexenta Systems, Inc.
 */

#include <sys/param.h>
#include <sys/types.h>
#include <sys/pathname.h>
#include <sys/errno.h>
#include <sys/cmn_err.h>
#include <sys/debug.h>
#include <sys/systm.h>
#include <sys/unistd.h>
#include <sys/door.h>
#include <sys/socket.h>
#include <nfs/export.h>
#include <nfs/nfs_cmd.h>
#include <sys/kmem.h>
#include <sys/sunddi.h>

#define	NFSCMD_DR_TRYCNT	8

#ifdef nextdp
#undef nextdp
#endif
#define	nextdp(dp)	((struct dirent64 *)((char *)(dp) + (dp)->d_reclen))

typedef struct nfscmd_globals {
	kmutex_t	nfscmd_lock;
	door_handle_t   nfscmd_dh;
} nfscmd_globals_t;

static zone_key_t nfscmd_zone_key;

static struct charset_cache *nfscmd_charmap(exportinfo_t *exi,
    struct sockaddr *sp);
static void *nfscmd_zone_init(zoneid_t);
static void nfscmd_zone_fini(zoneid_t, void *);

void
nfscmd_args(uint_t did)
{
	nfscmd_globals_t *ncg = zone_getspecific(nfscmd_zone_key, curzone);

	mutex_enter(&ncg->nfscmd_lock);
	if (ncg->nfscmd_dh != NULL)
		door_ki_rele(ncg->nfscmd_dh);
	ncg->nfscmd_dh = door_ki_lookup(did);
	mutex_exit(&ncg->nfscmd_lock);
}

void
nfscmd_init(void)
{
	zone_key_create(&nfscmd_zone_key, nfscmd_zone_init,
	    NULL, nfscmd_zone_fini);
}

void
nfscmd_fini(void)
{
	(void) zone_key_delete(nfscmd_zone_key);
}

/*ARGSUSED*/
static void *
nfscmd_zone_init(zoneid_t zoneid)
{
	nfscmd_globals_t *ncg;

	ncg = kmem_zalloc(sizeof (*ncg), KM_SLEEP);
	mutex_init(&ncg->nfscmd_lock, NULL, MUTEX_DEFAULT, NULL);

	return (ncg);
}

/*ARGSUSED*/
static void
nfscmd_zone_fini(zoneid_t zoneid, void *data)
{
	nfscmd_globals_t *ncg = data;

	mutex_destroy(&ncg->nfscmd_lock);
	if (ncg->nfscmd_dh)
		door_ki_rele(ncg->nfscmd_dh);
	kmem_free(ncg, sizeof (*ncg));
}

/*
 * nfscmd_send(arg, result)
 *
 * Send a command to the daemon listening on the door. The result is
 * returned in the result pointer if the function return value is
 * NFSCMD_ERR_SUCCESS. Otherwise it is the error value.
 */
int
nfscmd_send(nfscmd_arg_t *arg, nfscmd_res_t *res)
{
	door_handle_t	dh;
	door_arg_t	da;
	door_info_t	di;
	int		ntries = 0;
	int		last = 0;
	nfscmd_globals_t *ncg = zone_getspecific(nfscmd_zone_key, curzone);

retry:
	mutex_enter(&ncg->nfscmd_lock);
	dh = ncg->nfscmd_dh;
	if (dh != NULL)
		door_ki_hold(dh);
	mutex_exit(&ncg->nfscmd_lock);

	if (dh == NULL) {
		/*
		 * The rendezvous point has not been established yet !
		 * This could mean that either mountd(1m) has not yet
		 * been started or that _this_ routine nuked the door
		 * handle after receiving an EINTR for a REVOKED door.
		 *
		 * Returning NFSAUTH_DROP will cause the NFS client
		 * to retransmit the request, so let's try to be more
		 * rescillient and attempt for ntries before we bail.
		 */
		if (++ntries % NFSCMD_DR_TRYCNT) {
			delay(hz);
			goto retry;
		}
		return (NFSCMD_ERR_DROP);
	}

	da.data_ptr = (char *)arg;
	da.data_size = sizeof (nfscmd_arg_t);
	da.desc_ptr = NULL;
	da.desc_num = 0;
	da.rbuf = (char *)res;
	da.rsize = sizeof (nfscmd_res_t);

	switch (door_ki_upcall(dh, &da)) {
	case 0:
		/* Success */
		break;
	case EAGAIN:
		/* Need to retry a couple of times */
		door_ki_rele(dh);
		delay(hz);
		goto retry;
		/* NOTREACHED */
	case EINTR:
		if (!door_ki_info(dh, &di)) {
			if (di.di_attributes & DOOR_REVOKED) {
				/*
				 * The server barfed and revoked
				 * the (existing) door on us; we
				 * want to wait to give smf(5) a
				 * chance to restart mountd(1m)
				 * and establish a new door handle.
				 */
				mutex_enter(&ncg->nfscmd_lock);
				if (dh == ncg->nfscmd_dh)
					ncg->nfscmd_dh = NULL;
				mutex_exit(&ncg->nfscmd_lock);
				door_ki_rele(dh);
				delay(hz);
				goto retry;
			}
			/*
			 * If the door was _not_ revoked on us,
			 * then more than likely we took an INTR,
			 * so we need to fail the operation.
			 */
			door_ki_rele(dh);
		}
		/*
		 * The only failure that can occur from getting
		 * the door info is EINVAL, so we let the code
		 * below handle it.
		 */
		/* FALLTHROUGH */

	case EBADF:
	case EINVAL:
	default:
		/*
		 * If we have a stale door handle, give smf a last
		 * chance to start it by sleeping for a little bit.
		 * If we're still hosed, we'll fail the call.
		 *
		 * Since we're going to reacquire the door handle
		 * upon the retry, we opt to sleep for a bit and
		 * _not_ to clear mountd_dh. If mountd restarted
		 * and was able to set mountd_dh, we should see
		 * the new instance; if not, we won't get caught
		 * up in the retry/DELAY loop.
		 */
		door_ki_rele(dh);
		if (!last) {
			delay(hz);
			last++;
			goto retry;
		}
		res->error = NFSCMD_ERR_FAIL;
		break;
	}
	return (res->error);
}

/*
 * nfscmd_findmap(export, addr)
 *
 * Find a characterset map for the specified client address.
 * First try to find a cached entry. If not successful,
 * ask mountd daemon running in userland.
 *
 * For most of the clients this function is NOOP, since
 * EX_CHARMAP flag won't be set.
 */
struct charset_cache *
nfscmd_findmap(struct exportinfo *exi, struct sockaddr *sp)
{
	struct charset_cache *charset;

	/*
	 * In debug kernel we want to know about strayed nulls.
	 * In non-debug kernel we behave gracefully.
	 */
	ASSERT(exi != NULL);
	ASSERT(sp != NULL);

	if (exi == NULL || sp == NULL)
		return (NULL);

	mutex_enter(&exi->exi_lock);

	if (!(exi->exi_export.ex_flags & EX_CHARMAP)) {
		mutex_exit(&exi->exi_lock);
		return (NULL);
	}

	for (charset = exi->exi_charset;
	    charset != NULL;
	    charset = charset->next) {
		if (bcmp(sp, &charset->client_addr,
		    sizeof (struct sockaddr)) == 0)
			break;
	}
	mutex_exit(&exi->exi_lock);

	/* the slooow way - ask daemon */
	if (charset == NULL)
		charset = nfscmd_charmap(exi, sp);

	return (charset);
}

/*
 * nfscmd_insert_charmap(export, addr, name)
 *
 * Insert a new character set conversion map into the export structure
 * for the share. The entry has the IP address of the client and the
 * character set name.
 */

static struct charset_cache *
nfscmd_insert_charmap(struct exportinfo *exi, struct sockaddr *sp, char *name)
{
	struct charset_cache *charset;

	charset = (struct charset_cache *)
	    kmem_zalloc(sizeof (struct charset_cache), KM_SLEEP);

	if (charset == NULL)
		return (NULL);

	charset->inbound = kiconv_open("UTF-8", name);
	charset->outbound = kiconv_open(name, "UTF-8");

	charset->client_addr = *sp;
	mutex_enter(&exi->exi_lock);
	charset->next = exi->exi_charset;
	exi->exi_charset = charset;
	mutex_exit(&exi->exi_lock);

	return (charset);
}

/*
 * nfscmd_charmap(response, sp, exi)
 *
 * Check to see if this client needs a character set conversion.
 */
static struct charset_cache *
nfscmd_charmap(exportinfo_t *exi, struct sockaddr *sp)
{
	nfscmd_arg_t req;
	int ret;
	char *path;
	nfscmd_res_t res;
	struct charset_cache *charset;

	path = exi->exi_export.ex_path;
	if (path == NULL)
		return (NULL);

	/*
	 * nfscmd_findmap() did not find one in the cache so make
	 * the request to the daemon. We need to add the entry in
	 * either case since we want negative as well as
	 * positive cacheing.
	 */
	req.cmd = NFSCMD_CHARMAP_LOOKUP;
	req.version = NFSCMD_VERSION;
	req.arg.charmap.addr = *sp;
	(void) strncpy(req.arg.charmap.path, path, MAXPATHLEN);
	bzero((caddr_t)&res, sizeof (nfscmd_res_t));
	ret = nfscmd_send(&req, &res);
	if (ret == NFSCMD_ERR_SUCCESS)
		charset = nfscmd_insert_charmap(exi, sp,
		    res.result.charmap.codeset);
	else
		charset = nfscmd_insert_charmap(exi, sp, NULL);

	return (charset);
}

/*
 * nfscmd_convname(addr, export, name, inbound, size)
 *
 * Convert the given "name" string to the appropriate character set.
 * If inbound is true, convert from the client character set to UTF-8.
 * If inbound is false, convert from UTF-8 to the client characters set.
 *
 * In case of NFS v4 this is used for ill behaved clients, since
 * according to the standard all file names should be utf-8 encoded
 * on client-side.
 */

char *
nfscmd_convname(struct sockaddr *ca, struct exportinfo *exi, char *name,
    int inbound, size_t size)
{
	char *newname;
	char *holdname;
	int err;
	int ret;
	size_t nsize;
	size_t osize;
	struct charset_cache *charset = NULL;

	charset = nfscmd_findmap(exi, ca);
	if (charset == NULL ||
	    (charset->inbound == (kiconv_t)-1 && inbound) ||
	    (charset->outbound == (kiconv_t)-1 && !inbound))
		return (name);

	/* make sure we have more than enough space */
	newname = kmem_zalloc(size, KM_SLEEP);
	nsize = strlen(name);
	osize = size;
	holdname = newname;
	if (inbound)
		ret = kiconv(charset->inbound, &name, &nsize,
		    &holdname, &osize, &err);
	else
		ret = kiconv(charset->outbound, &name, &nsize,
		    &holdname, &osize, &err);
	if (ret == (size_t)-1) {
		kmem_free(newname, size);
		newname = NULL;
	}

	return (newname);
}

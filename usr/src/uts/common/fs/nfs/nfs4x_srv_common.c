#include <sys/systm.h>
#include <sys/sdt.h>
#include <rpc/types.h>
#include <nfs/nfs4.h>
#include <sys/cmn_err.h>
#include <sys/modctl.h>

static kmem_cache_t *rfs4x_compound_state_cache = NULL;

static int rfs4x_compound_state_construct(void *, void *, int);
static void rfs4x_compound_state_destroy(void *, void *);


void
rfs4x_srvrinit(void)
{
	rfs4x_compound_state_cache = kmem_cache_create(
	    "rfs4x_compound_state_cache", sizeof (compound_state_t), 0,
	    rfs4x_compound_state_construct, rfs4x_compound_state_destroy, NULL,
	    NULL, NULL, 0);
}

compound_state_t *
rfs4x_compound_state_alloc(nfs_server_instance_t *instp, int minorvers)
{
	compound_state_t *cs;

	cs = kmem_cache_alloc(rfs4x_compound_state_cache, KM_SLEEP);
	cs->instp = instp;
	cs->cont = TRUE;
	cs->fh.nfs_fh4_val = cs->fhbuf;
	cs->access = CS_ACCESS_DENIED;

	switch (minorvers) {
	case NFS4_MINOR_v0:
	case NFS4_MINOR_v1:
		break;
	default:
		VERIFY(0);
	}

	cs->minorversion = minorvers;
	return (cs);
}

void
rfs4x_compound_state_free(compound_state_t *cs)
{
	if (cs->vp) {
		VN_RELE(cs->vp);
		cs->vp = NULL;
	}
	if (cs->saved_vp) {
		VN_RELE(cs->saved_vp);
		cs->saved_vp = NULL;
	}
	if (cs->cr) {
		crfree(cs->cr);
		cs->cr = NULL;
	}
	if (cs->saved_fh.nfs_fh4_val) {
		kmem_free(cs->saved_fh.nfs_fh4_val, NFS4_FHSIZE);
		cs->saved_fh.nfs_fh4_val = NULL;
	}
	if (cs->basecr) {
		crfree(cs->basecr);
		cs->basecr = NULL;
	}
	if (cs->sp) {
		rfs41_session_rele(cs->sp);
		if (cs->cp)
			rfs4_client_rele(cs->cp);

		cs->sp = NULL;
		cs->cp = NULL;
	}

	kmem_cache_free(rfs4x_compound_state_cache, cs);
}

/*ARGSUSED*/
static int
rfs4x_compound_state_construct(void *buf, void *cdrarg, int kmflags)
{
	bzero(buf, sizeof (compound_state_t));
	return (0);
}

/*ARGSUSED*/
static void
rfs4x_compound_state_destroy(void *buf, void *cdrarg)
{
	compound_state_t *cs = (compound_state_t *)buf;

	ASSERT(cs->vp == NULL);
	ASSERT(cs->cr == NULL);
	ASSERT(cs->saved_fh.nfs_fh4_val == NULL);
	ASSERT(cs->basecr == NULL);
	ASSERT(cs->cp == NULL);
	ASSERT(cs->sp == NULL);
}

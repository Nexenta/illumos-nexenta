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

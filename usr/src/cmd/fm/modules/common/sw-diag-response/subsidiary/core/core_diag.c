/*
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 */

/*
 * Copyright 2017 Nexenta Systems, Inc.
 */

#include <assert.h>
#include <strings.h>
#include <string.h>
#include <alloca.h>
#include <zone.h>
#include <libproc.h>
#include <sys/fm/sw/core.h>

#include "../../common/sw.h"

#define	SW_SUNOS_CORE_DEFECT "defect.sunos.system.core"
#define	MAX_STACK_SIZE 4096
#define	MAX_FNAME_LENGTH 512

static id_t myid;
static int stacks_enabled;

/*
 * Our serialization structure type.
 */
#define	SWDE_CORE_CASEDATA_VERS	1

typedef struct swde_core_casedata {
	uint32_t scd_vers;		/* must be first member */
	uint64_t scd_receive_time;	/* when we first knew of this core */
	size_t scd_nvlbufsz;		/* size of following buffer */
					/* packed attr nvlist follows */
} swde_core_casedata_t;

static struct {
	fmd_stat_t swde_core_diagnosed;
	fmd_stat_t swde_core_badpayload;
	fmd_stat_t swde_core_failsrlz;
	fmd_stat_t swde_core_nostack;
} swde_core_stats = {
	{ "swde_core_diagnosed", FMD_TYPE_UINT64,
	    "core defects published" },
	{ "swde_core_badpayload", FMD_TYPE_UINT64,
	    "malformed event - invalid event payload" },
	{ "swde_core_failsrlz", FMD_TYPE_UINT64,
	    "failures to serialize case data" },
	{ "swde_core_nostack", FMD_TYPE_UINT64,
	    "failed to obtain stack from core" },
};

#define	BUMPSTAT(stat)		swde_core_stats.stat.fmds_value.ui64++

typedef struct lwp_context {
	fmd_hdl_t *fmd_hdl;
	struct ps_prochandle *proc;
	nvlist_t *stack;
} lwp_context_t;

typedef struct frame_context {
	struct ps_prochandle *proc;
	char *buf;
	int size;
	int length;
	int first;
} frame_context_t;

/*
 * Attribute members to include in event-specific defect
 * payload.
 */
const char *toadd[] = {
	FM_EREPORT_PAYLOAD_CORE_COMMAND,
	FM_EREPORT_PAYLOAD_CORE_PSARGS,
	FM_EREPORT_PAYLOAD_CORE_SIGNAL,
	FM_EREPORT_PAYLOAD_CORE_PATH
};

static int
print_frame(void *data, prgregset_t gregs, uint_t argc, const long *argv)
{
	frame_context_t *ctx = data;
	uintptr_t pc = gregs[R_PC];
	char fname[MAX_FNAME_LENGTH] = "????????";
	GElf_Sym sym;
	int n;

	if (Plookup_by_addr(ctx->proc, pc, fname, sizeof (fname), &sym) == 0) {
		n = strnlen(fname, MAX_FNAME_LENGTH);
		(void) snprintf(&fname[n], MAX_FNAME_LENGTH - n, "+%lx ()",
		    (long)(pc - sym.st_value));
	} else {
		(void) strlcat(fname, " ()", MAX_FNAME_LENGTH);
	}

	n = snprintf(&ctx->buf[ctx->length], ctx->size - ctx->length, "%s%s",
	    ctx->first ? "" : " | ", fname);

	ctx->first = 0;
	ctx->length += n;

	return ((ctx->length >= ctx->size) ? 1 : 0);
}

static int
lwp_call_stack(void *data, const lwpstatus_t *psp, const lwpsinfo_t *pip)
{
	lwp_context_t *ctx = data;
	char key[20];	/* for holding lwp ID (i.e. "lwp #13") */

	(void) snprintf(key, sizeof (key), "lwp #%ld", pip->pr_lwpid);

	if (psp != NULL) {
		prgregset_t reg;
		frame_context_t fctx;

		fctx.proc = ctx->proc;
		fctx.buf = fmd_hdl_alloc(ctx->fmd_hdl, MAX_STACK_SIZE,
		    FMD_SLEEP);
		fctx.buf[0] = '\0';
		fctx.size = MAX_STACK_SIZE;
		fctx.length = 0;
		fctx.first = 1;

		(void) memcpy(reg, psp->pr_reg, sizeof (reg));
		(void) Pstack_iter(ctx->proc, reg, print_frame, &fctx);
		(void) nvlist_add_string(ctx->stack, key, fctx.buf);
		fmd_hdl_free(ctx->fmd_hdl, fctx.buf, MAX_STACK_SIZE);
	} else {
		(void) nvlist_add_string(ctx->stack, key, "(zombie)");
	}

	return (0);
}

static int
add_stack_info(fmd_hdl_t *hdl, nvlist_t *defect, const char *path)
{
	lwp_context_t ctx;
	struct ps_prochandle *proc;
	const char *lwps;
	int perr;

	proc = proc_arg_xgrab(path, NULL, PR_ARG_CORES, 0, &perr, &lwps);
	if (proc == NULL) {
		fmd_hdl_debug(hdl, "Cannot examine core %s: %s\n",
		    path, Pgrab_error(perr));
		return (1);
	}

	ctx.fmd_hdl = hdl;
	ctx.proc = proc;
	ctx.stack = fmd_nvl_alloc(hdl, FMD_SLEEP);

	(void) Plwp_iter_all(proc, lwp_call_stack, &ctx);

	Prelease(proc, 0);
	(void) nvlist_add_nvlist(defect, "stacks", ctx.stack);
	nvlist_free(ctx.stack);

	return (0);
}

/*
 * Handler for ereport.sw.core.available.
 */

/*ARGSUSED*/
void
swde_core_available(fmd_hdl_t *hdl, fmd_event_t *ep, nvlist_t *nvl,
    const char *class, void *arg)
{
	swde_core_casedata_t *cdp;
	fmd_case_t *cp;
	size_t sz;
	nvpair_t *nvp;
	nvlist_t *defect;
	nvlist_t *detector;
	char *fmribuf;
	char *command;
	char *path;
	char *psargs;
	int i;

	fmd_hdl_debug(hdl, "swde_core_available\n");

	if (nvlist_lookup_nvlist(nvl, FM_EREPORT_DETECTOR, &detector) != 0) {
		BUMPSTAT(swde_core_badpayload);
		return;
	}

	if (nvlist_lookup_string(nvl, FM_EREPORT_PAYLOAD_CORE_PATH,
	    &path) != 0) {
		BUMPSTAT(swde_core_badpayload);
		return;
	}
	if (nvlist_lookup_string(nvl, FM_EREPORT_PAYLOAD_CORE_COMMAND,
	    &command) != 0) {
		BUMPSTAT(swde_core_badpayload);
		return;
	}
	if (nvlist_lookup_string(nvl, FM_EREPORT_PAYLOAD_CORE_PSARGS,
	    &psargs) != 0) {
		BUMPSTAT(swde_core_badpayload);
		return;
	}

	fmd_hdl_debug(hdl, "swde_core_available: "
	    "new core %s of program %s\n", path, command);

	/*
	 * Prepare serialization data to be associated with a new case.
	 * Our serialization data consists of a swde_core_casedata_t
	 * structure followed by a packed nvlist of the attributes of
	 * the initial event.
	 */
	if (nvlist_size(nvl, &sz, NV_ENCODE_NATIVE) != 0) {
		BUMPSTAT(swde_core_failsrlz);
		return;
	}

	cdp = fmd_hdl_zalloc(hdl, sizeof (*cdp) + sz, FMD_SLEEP);
	fmribuf = (char *)cdp + sizeof (*cdp);
	cdp->scd_vers = SWDE_CORE_CASEDATA_VERS;
	cdp->scd_receive_time = time(NULL);
	cdp->scd_nvlbufsz = sz;

	cp = swde_case_open(hdl, myid, NULL, SWDE_CORE_CASEDATA_VERS,
	    cdp, sizeof (*cdp) + sz);

	fmd_case_setprincipal(hdl, cp, ep);
	fmd_case_add_ereport(hdl, cp, ep);
	(void) nvlist_pack(nvl, &fmribuf, &sz, NV_ENCODE_NATIVE, 0);
	swde_case_data_write(hdl, cp);

	defect = fmd_nvl_create_defect(hdl, SW_SUNOS_CORE_DEFECT,
	    100, detector, NULL, detector);
	assert(defect != NULL);

	for (i = 0; i < sizeof (toadd) / sizeof (toadd[0]); i++) {
		if (nvlist_lookup_nvpair(nvl, toadd[i], &nvp) == 0)
			(void) nvlist_add_nvpair(defect, nvp);
	}

	if (stacks_enabled != 0) {
		/* Try to add stack information */
		if (add_stack_info(hdl, defect, path) != 0)
			BUMPSTAT(swde_core_nostack);
	}

	fmd_case_add_suspect(hdl, cp, defect);
	fmd_case_solve(hdl, cp);

	/*
	 * Close the case.  Do no free casedata - framework does that for us
	 * on closure callback.
	 */
	fmd_case_close(hdl, cp);
	BUMPSTAT(swde_core_diagnosed);
}

const struct sw_disp swde_core_disp[] = {
	{ "ereport." CORE_ERROR_CLASS, swde_core_available, NULL },
	/*
	 * Something has to subscribe to every fault or defect diagnosed in fmd.
	 * We do that here, but throw it away.
	 */
	{ SW_SUNOS_CORE_DEFECT, NULL, NULL },
	{ NULL, NULL, NULL }
};

/*ARGSUSED*/
int
swde_core_init(fmd_hdl_t *hdl, id_t id, const struct sw_disp **dpp,
    int *nelemp)
{
	myid = id;

	if (fmd_prop_get_int32(hdl, "core_enable") == 0) {
		fmd_hdl_debug(hdl, "core diag engine is disabled "
		    "in the config file\n");
		return (SW_SUB_INIT_FAIL_VOLUNTARY);
	}
	if (getzoneid() != GLOBAL_ZONEID)
		return (SW_SUB_INIT_FAIL_VOLUNTARY);

	(void) fmd_stat_create(hdl, FMD_STAT_NOALLOC,
	    sizeof (swde_core_stats) / sizeof (fmd_stat_t),
	    (fmd_stat_t *)&swde_core_stats);

	fmd_hdl_subscribe(hdl, "ereport." CORE_ERROR_CLASS);

	stacks_enabled = fmd_prop_get_int32(hdl, "core_stacks_enable");
	if (stacks_enabled == 0) {
		fmd_hdl_debug(hdl, "core stacks are disabled "
		    "in the config file\n");
	}

	*dpp = &swde_core_disp[0];
	*nelemp = sizeof (swde_core_disp) / sizeof (swde_core_disp[0]);
	return (SW_SUB_INIT_SUCCESS);
}

const struct sw_subinfo core_diag_info = {
	"core diagnosis",	/* swsub_name */
	SW_CASE_CORE,		/* swsub_casetype */
	swde_core_init,		/* swsub_init */
	NULL,			/* swsub_fini */
	NULL,			/* swsub_timeout */
	NULL,			/* swsub_case_close */
	NULL,			/* swsub_case_vrfy */
};

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
 * Copyright 2014 Nexenta Systems, Inc.  All rights reserved.
 */

#include <fm/fmd_api.h>
#include <sys/note.h>
#include <fm/libtopo.h>
#include <sys/fm/protocol.h>
#include <strings.h>

typedef struct slow_io_stat {
	fmd_stat_t bad_fmri;
	fmd_stat_t bad_scheme;
} slow_io_stat_t;

slow_io_stat_t slow_io_stats = {
	{ "bad_FMRI", FMD_TYPE_UINT64,
		"event FMRI is missing or invalid" },
	{ "bad_scheme", FMD_TYPE_UINT64,
		"event does not contain a valid detector"},
};

static const fmd_prop_t fmd_props [] = {
	{ "io_N", FMD_TYPE_INT32, "10" },
	{ "io_T", FMD_TYPE_TIME, "10min"},
	{ NULL, 0, NULL }
};

typedef struct topo_node_info {
	const char *device;
	nvlist_t *fru;
	nvlist_t *resource;
} topo_node_info_t;

void
slow_io_close(fmd_hdl_t *hdl, fmd_case_t *c)
{
	char *devid = fmd_case_getspecific(hdl, c);
	if (devid != NULL) {
		fmd_hdl_debug(hdl, "Destroying serd: %s", devid);
		fmd_serd_destroy(hdl, devid);
	}
}

int
topo_walk_cb(topo_hdl_t *thp, tnode_t *tn, void *arg) {

	topo_node_info_t *node = (topo_node_info_t *)arg;
	char *cur_devid;
	nvlist_t *fru;
	nvlist_t *resource;
	int err = 0;
	_NOTE(ARGUNUSED(thp));

	if (strcmp(topo_node_name(tn), "disk") != 0)
		return (TOPO_WALK_NEXT);

	if (topo_prop_get_string(tn, "io", "devid", &cur_devid, &err) != 0)
		return (TOPO_WALK_NEXT);

	if (strcmp(cur_devid, node->device) == 0) {
		(void) topo_node_fru(tn, &fru, NULL, &err);
		(void) topo_node_resource(tn, &resource, &err);

		if (err == 0) {
			if (nvlist_dup(fru, &node->fru, 0) != 0 ||
			    nvlist_dup(resource, &node->resource, 0) != 0)
				return (TOPO_WALK_ERR);
			return (TOPO_WALK_TERMINATE);
		}
	}

	return (TOPO_WALK_NEXT);
}

topo_node_info_t *
topo_node_lookup_by_devid(fmd_hdl_t *hdl, char *device) {

	int err = 0;
	topo_hdl_t *thp;
	topo_walk_t *twp;

	topo_node_info_t *node = (topo_node_info_t *)fmd_hdl_zalloc(hdl,
	    sizeof (topo_node_info_t), FMD_SLEEP);

	thp = fmd_hdl_topo_hold(hdl, TOPO_VERSION);

	node->device = device;

	if ((twp = topo_walk_init(thp, FM_FMRI_SCHEME_HC, topo_walk_cb,
	    node, &err)) == NULL) {
		fmd_hdl_error(hdl, "failed to get topology: %s",
		    topo_strerror(err));
		fmd_hdl_topo_rele(hdl, thp);
		return (NULL);
	}

	(void) topo_walk_step(twp, TOPO_WALK_CHILD);
	if (twp != NULL)
		topo_walk_fini(twp);
	if (thp != NULL)
		fmd_hdl_topo_rele(hdl, thp);

	if (node->fru == NULL || node->resource == NULL) {
		fmd_hdl_debug(hdl, "Could not find device and its FRU");
		fmd_hdl_free(hdl, node, sizeof (topo_node_info_t));
		return (NULL);
	} else {
		fmd_hdl_debug(hdl, "Found FRU for device %s", device);
		return (node);
	}
}

void
slow_io_recv(fmd_hdl_t *hdl, fmd_event_t *event, nvlist_t *nvl,
	const char *class)
{
	nvlist_t *detector = NULL;
	char *devid = NULL;
	nvlist_t *fault;
	topo_node_info_t *node;
	_NOTE(ARGUNUSED(class));

	if (nvlist_lookup_nvlist(nvl, "detector", &detector) != 0) {
		slow_io_stats.bad_scheme.fmds_value.ui64++;
		return;
	}

	if (nvlist_lookup_string(detector, "devid", &devid) != 0) {
		slow_io_stats.bad_fmri.fmds_value.ui64++;
		return;
	}

	if (fmd_serd_exists(hdl, devid) == 0) {
		fmd_serd_create(hdl, devid, fmd_prop_get_int32(hdl, "io_N"),
		    fmd_prop_get_int64(hdl, "io_T"));
		(void) fmd_serd_record(hdl, devid, event);
		return;
	}

	if (fmd_serd_record(hdl, devid, event) == FMD_B_TRUE) {
		fmd_case_t *c = fmd_case_open(hdl, NULL);
		fmd_case_add_serd(hdl, c, devid);
		node = topo_node_lookup_by_devid(hdl, devid);

		/*
		 * If for some reason libtopo does not enumureate the device
		 * we still want to create a fault, we will see a "bad"
		 * FMA message however that lacks the FRU information.
		 */

		if (node == NULL) {
			fault = fmd_nvl_create_fault(hdl,
			    "fault.io.disk.slow-io", 100,
			    detector, NULL, NULL);
		} else {
			fault = fmd_nvl_create_fault(hdl,
			    "fault.io.disk.slow-io", 100,
			    detector, node->fru, node->resource);
			nvlist_free(node->fru);
			nvlist_free(node->resource);
			fmd_hdl_free(hdl, node, sizeof (topo_node_info_t));
		}

		fmd_case_add_suspect(hdl, c, fault);
		fmd_case_setspecific(hdl, c, devid);
		fmd_case_solve(hdl, c);
	}
}

static const fmd_hdl_ops_t fmd_ops = {
	slow_io_recv,
	NULL,
	slow_io_close,
	NULL,
	NULL,
};

static const fmd_hdl_info_t fmd_info = {
	"slow-io-de", "0.2", &fmd_ops, fmd_props
};

void
_fmd_init(fmd_hdl_t *hdl)
{
	if (fmd_hdl_register(hdl, FMD_API_VERSION, &fmd_info) != 0) {
		fmd_hdl_debug(hdl, "Internal error\n");
		return;
	}

	(void) fmd_stat_create(hdl, FMD_STAT_NOALLOC, sizeof (slow_io_stats) /
	    sizeof (fmd_stat_t), (fmd_stat_t *)&slow_io_stats);
}

void
_fmd_fini(fmd_hdl_t *hdl)
{
	_NOTE(ARGUNUSED(hdl));
}

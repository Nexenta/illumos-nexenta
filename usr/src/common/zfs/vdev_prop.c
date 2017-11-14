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
 * Copyright 2015 Nexenta Systems, Inc. All rights reserved.
 */

#include <sys/zio.h>
#include <sys/spa.h>
#include <sys/zfs_ioctl.h>
#include <sys/fs/zfs.h>

#include "zfs_prop.h"

#if defined(_KERNEL)
#include <sys/systm.h>
#else
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#endif

static zprop_desc_t vdev_prop_table[VDEV_NUM_PROPS];

zprop_desc_t *
vdev_prop_get_table(void)
{
	return (vdev_prop_table);
}

void
vdev_prop_init(void)
{
	static zprop_index_t boolean_table[] = {
		{ "off",	0},
		{ "on",		1},
		{ NULL }
	};

	/* index properties */
	zprop_register_index(VDEV_PROP_L2ADDDT, "l2arc_ddt", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "on | off",
	    "<cache DDT on this L2ARC device>", boolean_table);

	/* string properties */
	zprop_register_string(VDEV_PROP_PATH, "path", NULL,
	    PROP_READONLY, ZFS_TYPE_VDEV, "<path>", "PATH");
	zprop_register_string(VDEV_PROP_FRU, "fru", NULL,
	    PROP_READONLY, ZFS_TYPE_VDEV, "<fru>", "FRU");
	zprop_register_string(VDEV_PROP_COS, "cos", NULL,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<class of storage>", "COS");
	zprop_register_string(VDEV_PROP_SPAREGROUP, "sparegroup", NULL,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<spare device group>", "SPRGRP");

	/* default number properties */
	zprop_register_number(VDEV_PROP_GUID, "guid", 0,
	    PROP_READONLY, ZFS_TYPE_VDEV, "<vdev guid>", "GUID");
	zprop_register_number(VDEV_PROP_READ_MINACTIVE, "read_minactive", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<read min active (0..1000)>",
	    "READ_MINACTIVE");
	zprop_register_number(VDEV_PROP_READ_MAXACTIVE, "read_maxactive", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<read max active (0..1000)>",
	    "READ_MAXACTIVE");
	zprop_register_number(VDEV_PROP_AREAD_MINACTIVE, "aread_minactive", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<async read min active (0..1000)>",
	    "AREAD_MINACTIVE");
	zprop_register_number(VDEV_PROP_AREAD_MAXACTIVE, "aread_maxactive", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<async read max active (0..1000)>",
	    "AREAD_MAXACTIVE");
	zprop_register_number(VDEV_PROP_WRITE_MINACTIVE, "write_minactive", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<write min active (0..1000)>",
	    "WRITE_MINACTIVE");
	zprop_register_number(VDEV_PROP_WRITE_MAXACTIVE, "write_maxactive", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<write max active (0..1000)>",
	    "WRITE_MAXACTIVE");
	zprop_register_number(VDEV_PROP_AWRITE_MINACTIVE, "awrite_minactive", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<async write min active (0..1000)>",
	    "AWRITE_MINACTIVE");
	zprop_register_number(VDEV_PROP_AWRITE_MAXACTIVE, "awrite_maxactive", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<async write max active (0..1000)>",
	    "AWRITE_MAXACTIVE");
	zprop_register_number(VDEV_PROP_SCRUB_MINACTIVE, "scrub_minactive", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<scrub min active (0..1000)>",
	    "SCRUB_MINACTIVE");
	zprop_register_number(VDEV_PROP_SCRUB_MAXACTIVE, "scrub_maxactive", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<scrub max active (0..1000)>",
	    "SCRUB_MAXACTIVE");
	zprop_register_number(VDEV_PROP_RESILVER_MINACTIVE,
	    "resilver_minactive", 0, PROP_DEFAULT, ZFS_TYPE_VDEV,
	    "<resilver min active (0..1000)>", "RESILVER_MINACTIVE");
	zprop_register_number(VDEV_PROP_RESILVER_MAXACTIVE,
	    "resilver_maxactive", 0, PROP_DEFAULT, ZFS_TYPE_VDEV,
	    "<resilver max active (0..1000)>", "RESILVER_MAXACTIVE");
	zprop_register_number(VDEV_PROP_PREFERRED_READ, "prefread", 0,
	    PROP_DEFAULT, ZFS_TYPE_VDEV, "<preferred read (0..100)>",
	    "PREFREAD");
}

/*
 * Given a property name and its type, returns the corresponding property ID.
 */
vdev_prop_t
vdev_name_to_prop(const char *propname)
{
	return (zprop_name_to_prop(propname, ZFS_TYPE_VDEV));
}

/*
 * Given a vdev property ID, returns the corresponding name.
 * Assuming the vdev propety ID is valid.
 */
const char *
vdev_prop_to_name(vdev_prop_t prop)
{
	return (vdev_prop_table[prop].pd_name);
}

zprop_type_t
vdev_prop_get_type(vdev_prop_t prop)
{
	return (vdev_prop_table[prop].pd_proptype);
}

boolean_t
vdev_prop_readonly(vdev_prop_t prop)
{
	return (vdev_prop_table[prop].pd_attr == PROP_READONLY);
}

const char *
vdev_prop_default_string(vdev_prop_t prop)
{
	return (vdev_prop_table[prop].pd_strdefault);
}

uint64_t
vdev_prop_default_numeric(vdev_prop_t prop)
{
	return (vdev_prop_table[prop].pd_numdefault);
}

int
vdev_prop_string_to_index(vdev_prop_t prop, const char *string,
    uint64_t *index)
{
	return (zprop_string_to_index(prop, string, index, ZFS_TYPE_VDEV));
}

int
vdev_prop_index_to_string(vdev_prop_t prop, uint64_t index,
    const char **string)
{
	return (zprop_index_to_string(prop, index, string, ZFS_TYPE_VDEV));
}

uint64_t
vdev_prop_random_value(vdev_prop_t prop, uint64_t seed)
{
	return (zprop_random_value(prop, seed, ZFS_TYPE_VDEV));
}

#ifndef _KERNEL

const char *
vdev_prop_values(vdev_prop_t prop)
{
	return (vdev_prop_table[prop].pd_values);
}

const char *
vdev_prop_column_name(vdev_prop_t prop)
{
	return (vdev_prop_table[prop].pd_colname);
}

boolean_t
vdev_prop_align_right(vdev_prop_t prop)
{
	return (vdev_prop_table[prop].pd_rightalign);
}
#endif

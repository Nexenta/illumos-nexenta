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
 * Copyright 2017 Nexenta Systems, Inc.  All rights reserved.
 */

#include <libnvpair.h>
#include <scsi/libses.h>
#include <scsi/libses_plugin.h>
#include <scsi/plugins/ses/framework/ses2_impl.h>

/*
 * This is a plugin, modeled after the DELL-MD3060e plugin, to update
 * libses's description field for SMC's 60 bay JBOD (2 subenclosures
 * with 30 bays).  When we get the description from the JBOD
 * subenclosure, it contains the slot number in the form "Slot#",
 * where # is from 01-30, however, the aes page indicates the device
 * slot numbering is from 0-29.  Therefore, we will replace these
 * Slot01-Slot30 descriptions using the bay number (Slot00-Slot29).
 */

/*ARGSUSED*/
static int
smc60_parse_node(ses_plugin_t *sp, ses_node_t *np)
{
	uint64_t type, bay;
	int nverr;
	nvlist_t *props;
	char buf[SES2_MIN_DIAGPAGE_ALLOC];

	if (ses_node_type(np) != SES_NODE_ELEMENT)
		return (0);

	props = ses_node_props(np);
	VERIFY(nvlist_lookup_uint64(props, SES_PROP_ELEMENT_TYPE, &type) == 0);
	if (type != SES_ET_ARRAY_DEVICE && type != SES_ET_DEVICE)
		return (0);

	/* bay will range 0-29 */
	if (nvlist_lookup_uint64(props, SES_PROP_BAY_NUMBER, &bay) != 0)
		return (0);

	/* modify the descrition to use the bay number */
	buf[SES2_MIN_DIAGPAGE_ALLOC - 1] = '\0';
	if (snprintf(buf, SES2_MIN_DIAGPAGE_ALLOC - 1,
	    "Slot%02" PRIu64, bay) < 0)
		return (0);

	/*
	 * Replace the ses-description field with the string we created above.
	 * Note:  SES_NV_ADD is a nested macro that can return -1 on error.
	 */
	SES_NV_ADD(string, nverr, props, SES_PROP_DESCRIPTION, buf);

	return (0);
}

int
_ses_init(ses_plugin_t *sp)
{
	ses_plugin_config_t config = {
		.spc_node_parse = smc60_parse_node
	};

	return (ses_plugin_register(sp, LIBSES_PLUGIN_VERSION, &config) != 0);
}

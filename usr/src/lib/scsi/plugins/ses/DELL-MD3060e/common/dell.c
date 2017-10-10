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
 * This is a plugin for Dell's MD3060e JBOD.  It updates libses'
 * ses-description field to indicate drawer and slot numbers,
 * and overrides the bay number if the invalid bit is set for the
 * AES descriptor.
 */

/*
 * Override bay number if the invalid bit is set for the AES descriptor.
 * This is modeled after the LENOVO-D1224J12ESM3P plugin.
 */
static int
dell_fix_bay(ses_plugin_t *sp, ses_node_t *np)
{
	ses2_aes_descr_eip_impl_t *dep;
	ses2_aes_descr_sas0_eip_impl_t *s0ep;
	size_t len;
	int nverr;
	nvlist_t *props = ses_node_props(np);

	/*
	 * The spec conveniently defines the bay number as part of the
	 * additional element status descriptor.  However, the AES descriptor
	 * is technically only valid if the device is inserted.
	 * Thankfully, the Dell enclosure defines this value even if
	 * the invalid bit is set, so we override bay value, even for empty
	 * bays.
	 */
	if ((dep = ses_plugin_page_lookup(sp, ses_node_snapshot(np),
	    SES2_DIAGPAGE_ADDL_ELEM_STATUS, np, &len)) == NULL)
		return (0);

	if (dep->sadei_protocol_identifier != SPC4_PROTO_SAS ||
	    !dep->sadei_eip || !dep->sadei_invalid)
		return (0);

	s0ep = (ses2_aes_descr_sas0_eip_impl_t *)dep->sadei_protocol_specific;

	SES_NV_ADD(uint64, nverr, props, SES_PROP_BAY_NUMBER,
	    s0ep->sadsi_bay_number);

	return (0);
}

/*
 * This updates libses ses-description field for Dell's MD3060e JBOD.
 * This JBOD is special because it has a physical label attached to it
 * which splits the slot numbering into 5 drawers, each having slots 0-11.
 * The description and slot numbering we get from the JBOD has slots
 * numbered 1-60. We map these 1-60 description "SLOT # " strings
 * into "Drawer X, Slot Y. ( Global SLOT # )" strings.
 */

/*ARGSUSED*/
static int
dell_parse_node(ses_plugin_t *sp, ses_node_t *np)
{
	uint64_t type, bay;
	int nverr, rc;
	nvlist_t *props;
	char *descr, buf[SES2_MIN_DIAGPAGE_ALLOC];
	int drawer, drawer_slot;

	if (ses_node_type(np) != SES_NODE_ELEMENT)
		return (0);

	props = ses_node_props(np);
	VERIFY(nvlist_lookup_uint64(props, SES_PROP_ELEMENT_TYPE, &type) == 0);
	if (type != SES_ET_ARRAY_DEVICE && type != SES_ET_DEVICE)
		return (0);

	if ((rc = dell_fix_bay(sp, np)) != 0) 
		return (rc);

	/* bay will range 1-60 */
	if (nvlist_lookup_uint64(props, SES_PROP_BAY_NUMBER, &bay) != 0)
		return (0);

	/* description strings will have something like "SLOT ## " */
	if (nvlist_lookup_string(props, SES_PROP_DESCRIPTION, &descr) != 0)
		return (0);

	/*
	 * there are 12 slots per drawer; we want drawer numering to
	 * start with 1 and drawer slot numbering to start at 0
	 */
	drawer = ((bay - 1) / 12) + 1;
	drawer_slot = (bay - (drawer - 1) * 12) - 1;

	/* modify the descrition to include drawer and a slot within drawer */
	buf[SES2_MIN_DIAGPAGE_ALLOC - 1] = '\0';
	if (snprintf(buf, SES2_MIN_DIAGPAGE_ALLOC - 1,
	    "Drawer %d, Slot %d. ( Global %s)", drawer, drawer_slot, descr) < 0)
		return (0);

	/* replace the ses-description field with the string we created above */
	SES_NV_ADD(string, nverr, props, SES_PROP_DESCRIPTION, buf);

	return (0);
}

int
_ses_init(ses_plugin_t *sp)
{
	ses_plugin_config_t config = {
		.spc_node_parse = dell_parse_node
	};

	return (ses_plugin_register(sp, LIBSES_PLUGIN_VERSION, &config) != 0);
}

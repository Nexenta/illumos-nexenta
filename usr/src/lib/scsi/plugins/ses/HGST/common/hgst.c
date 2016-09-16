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
 * Copyright 2016 Nexenta Systems, Inc.  All rights reserved.
 */

#include <stddef.h>
#include <libnvpair.h>
#include <scsi/libses.h>
#include <scsi/libses_plugin.h>
#include <scsi/plugins/ses/framework/ses2_impl.h>

/*
 * FC protocol specific parsing for the given (fp) AES element descriptor.
 * Copy-pasted elem_parse_aes_fc() from ses2_elements.c
 */
static int
hgst_elem_parse_aes_fc(const ses2_aes_descr_fc_eip_impl_t *fp,
    nvlist_t *nvl, size_t len)
{
	int nverr, i;
	nvlist_t **nva;
	int nports;

	if (len < offsetof(ses2_aes_descr_fc_eip_impl_t,
	    sadfi_ports))
		return (0);

	SES_NV_ADD(uint64, nverr, nvl, SES_PROP_BAY_NUMBER,
	    fp->sadfi_bay_number);
	SES_NV_ADD(uint64, nverr, nvl, SES_FC_PROP_NODE_NAME,
	    SCSI_READ64(&fp->sadfi_node_name));

	nports = MIN(fp->sadfi_n_ports,
	    (len - offsetof(ses2_aes_descr_fc_eip_impl_t,
	    sadfi_ports)) / sizeof (ses2_aes_port_descr_impl_t));

	if (nports == 0)
		return (0);

	nva = ses_zalloc(nports * sizeof (nvlist_t *));
	if (nva == NULL)
		return (-1);

	for (i = 0; i < nports; i++) {
		if ((nverr = nvlist_alloc(&nva[i], NV_UNIQUE_NAME, 0)) != 0)
			goto fail;
		if ((nverr = nvlist_add_uint64(nva[i], SES_FC_PROP_LOOP_POS,
		    fp->sadfi_ports[i].sapdi_port_loop_position)) != 0)
			goto fail;
		if ((nverr = nvlist_add_uint64(nva[i], SES_FC_PROP_REQ_HARDADDR,
		    fp->sadfi_ports[i].sapdi_port_requested_hard_address)) != 0)
			goto fail;
		nverr = nvlist_add_uint64(nva[i], SES_FC_PROP_N_PORT_ID,
		    SCSI_READ24(fp->sadfi_ports[i].sapdi_n_port_identifier));
		if (nverr != 0)
			goto fail;
		if ((nverr = nvlist_add_uint64(nva[i], SES_FC_PROP_N_PORT_NAME,
		    SCSI_READ64(&fp->sadfi_ports[i].sapdi_n_port_name))) != 0)
			goto fail;
	}

	if ((nverr = nvlist_add_nvlist_array(nvl, SES_FC_PROP_PORTS,
	    nva, nports)) != 0)
		goto fail;

	for (i = 0; i < nports && nva[i] != NULL; i++)
		nvlist_free(nva[i]);
	ses_free(nva);
	return (0);

fail:
	for (i = 0; i < nports && nva[i] != NULL; i++)
		nvlist_free(nva[i]);
	ses_free(nva);
	return (ses_set_nverrno(nverr, NULL));
}

/*
 * Parse AES descriptor for the given element (dep).
 * Copy-pasted elem_parse_aes_device() from ses2_elements.c
 */
static int
hgst_elem_parse_aes_device(const ses2_aes_descr_eip_impl_t *dep, nvlist_t *nvl,
    size_t len)
{
	ses2_aes_descr_fc_eip_impl_t *fp;
	ses2_aes_descr_sas0_eip_impl_t *s0ep;
	ses2_aes_descr_sas0_impl_t *s0p;
	ses2_aes_descr_impl_t *dip;
	nvlist_t **nva;
	int nverr, i;
	size_t nphy;

	if (dep->sadei_eip) {
		s0ep = (ses2_aes_descr_sas0_eip_impl_t *)
		    dep->sadei_protocol_specific;
		s0p = (ses2_aes_descr_sas0_impl_t *)
		    dep->sadei_protocol_specific;
	} else {
		dip = (ses2_aes_descr_impl_t *)dep;
		s0ep = NULL;
		s0p = (ses2_aes_descr_sas0_impl_t *)
		    dip->sadei_protocol_specific;
	}

	if (dep->sadei_invalid)
		return (0);

	if (dep->sadei_protocol_identifier == SPC4_PROTO_FIBRE_CHANNEL) {
		fp = (ses2_aes_descr_fc_eip_impl_t *)
		    dep->sadei_protocol_specific;

		if (!SES_WITHIN_PAGE_STRUCT(fp, dep, len))
			return (0);

		return (hgst_elem_parse_aes_fc(fp, nvl, len -
		    offsetof(ses2_aes_descr_eip_impl_t,
		    sadei_protocol_specific)));
	} else if (dep->sadei_protocol_identifier != SPC4_PROTO_SAS) {
		return (0);
	}

	if (s0p->sadsi_descriptor_type != SES2_AESD_SAS_DEVICE)
		return (0);

	SES_NV_ADD(boolean_value, nverr, nvl, SES_DEV_PROP_SAS_NOT_ALL_PHYS,
	    s0p->sadsi_not_all_phys);
	if (s0ep != NULL) {
		SES_NV_ADD(uint64, nverr, nvl, SES_PROP_BAY_NUMBER,
		    s0ep->sadsi_bay_number);
		nphy = MIN(s0ep->sadsi_n_phy_descriptors,
		    (len - offsetof(ses2_aes_descr_sas0_eip_impl_t,
		    sadsi_phys)) / sizeof (ses2_aes_phy0_descr_impl_t));
	} else {
		nphy = MIN(s0p->sadsi_n_phy_descriptors,
		    (len - offsetof(ses2_aes_descr_sas0_impl_t,
		    sadsi_phys)) / sizeof (ses2_aes_phy0_descr_impl_t));
	}

	if (nphy == 0)
		return (0);

	nva = ses_zalloc(nphy * sizeof (nvlist_t *));
	if (nva == NULL)
		return (-1);

	for (i = 0; i < nphy; i++) {
		ses2_aes_phy0_descr_impl_t *pp;
		pp = s0ep != NULL ? &s0ep->sadsi_phys[i] : &s0p->sadsi_phys[i];
		if ((nverr = nvlist_alloc(&nva[i], NV_UNIQUE_NAME, 0)) != 0)
			goto fail;
		if ((nverr = nvlist_add_uint64(nva[i], SES_SAS_PROP_DEVICE_TYPE,
		    pp->sapdi_device_type)) != 0)
			goto fail;
		if ((nverr = nvlist_add_boolean_value(nva[i],
		    SES_SAS_PROP_SMPI_PORT, pp->sapdi_smp_initiator_port)) != 0)
			goto fail;
		if ((nverr = nvlist_add_boolean_value(nva[i],
		    SES_SAS_PROP_STPI_PORT, pp->sapdi_stp_initiator_port)) != 0)
			goto fail;
		if ((nverr = nvlist_add_boolean_value(nva[i],
		    SES_SAS_PROP_SSPI_PORT, pp->sapdi_ssp_initiator_port)) != 0)
			goto fail;
		if ((nverr = nvlist_add_boolean_value(nva[i],
		    SES_SAS_PROP_SATA_DEVICE, pp->sapdi_sata_device)) != 0)
			goto fail;
		if ((nverr = nvlist_add_boolean_value(nva[i],
		    SES_SAS_PROP_SMPT_PORT, pp->sapdi_smp_target_port)) != 0)
			goto fail;
		if ((nverr = nvlist_add_boolean_value(nva[i],
		    SES_SAS_PROP_STPT_PORT, pp->sapdi_stp_target_port)) != 0)
			goto fail;
		if ((nverr = nvlist_add_boolean_value(nva[i],
		    SES_SAS_PROP_SSPT_PORT, pp->sapdi_ssp_target_port)) != 0)
			goto fail;
		nverr = nvlist_add_uint64(nva[i], SES_SAS_PROP_ATT_ADDR,
		    SCSI_READ64(&pp->sapdi_attached_sas_address));
		if (nverr != 0)
			goto fail;
		nverr = nvlist_add_uint64(nva[i], SES_SAS_PROP_ADDR,
		    SCSI_READ64(&pp->sapdi_sas_address));
		if (nverr != 0)
			goto fail;
		if ((nverr = nvlist_add_uint64(nva[i], SES_SAS_PROP_PHY_ID,
		    pp->sapdi_phy_identifier)) != 0)
			goto fail;
	}

	if ((nverr = nvlist_add_nvlist_array(nvl, SES_SAS_PROP_PHYS,
	    nva, nphy)) != 0)
		goto fail;

	for (i = 0; i < nphy && nva[i] != NULL; i++)
		nvlist_free(nva[i]);
	ses_free(nva);
	return (0);

fail:
	for (i = 0; i < nphy && nva[i] != NULL; i++)
		nvlist_free(nva[i]);
	ses_free(nva);
	return (ses_set_nverrno(nverr, NULL));
}

/*
 * HGST specific ses node parsing is needed to correct libses assumptions about
 * element index numbering.
 */
static int
hgst_parse_node(ses_plugin_t *sp, ses_node_t *np)
{
	uint64_t i, type;
	int nverr;
	size_t len;
	nvlist_t *props;
	ses2_aes_descr_eip_impl_t *dep;

	if (ses_node_type(np) != SES_NODE_ELEMENT)
		return (0);

	props = ses_node_props(np);
	VERIFY(nvlist_lookup_uint64(props, SES_PROP_ELEMENT_TYPE, &type) == 0);
	if (type != SES_ET_ARRAY_DEVICE && type != SES_ET_DEVICE)
		return (0);

	if (nvlist_lookup_uint64(props, SES_PROP_ELEMENT_ONLY_INDEX, &i) != 0)
		return (0);

	/*
	 * We populated the element-only-index in ses_build_snap_skel().
	 * This index starts at zero and is used internally by libses to match
	 * device element indexes to the indexes obtained from the AES page (see
	 * ses2_aes_index()).
	 * HGST starts their element index at one so we have an off by one error
	 * that we are correcting here
	 */
	SES_NV_ADD(uint64, nverr, props, SES_PROP_ELEMENT_ONLY_INDEX, i + 1);

	/* now that we've fixed the index we need to redo the AES parsing */
	if ((dep = ses_plugin_page_lookup(sp, ses_node_snapshot(np),
	    SES2_DIAGPAGE_ADDL_ELEM_STATUS, np, &len)) == NULL)
		return (0);

	return (hgst_elem_parse_aes_device(dep, props, len));
}

int
_ses_init(ses_plugin_t *sp)
{
	ses_plugin_config_t config = {
		.spc_node_parse = hgst_parse_node
	};

	return (ses_plugin_register(sp, LIBSES_PLUGIN_VERSION, &config) != 0);
}

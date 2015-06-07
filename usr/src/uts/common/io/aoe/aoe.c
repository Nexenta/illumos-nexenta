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
 * Copyright 2012 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * Nexus driver for AoE initiator and COMSTAR target
 *
 * Common AoE interface interacts with MAC, managing AoE ports,
 * doing MAC address discovery/managment, and AoE frame
 * encapsulation/decapsulation
 */

#include <sys/aoe.h>
#include <sys/bootconf.h>
#include <sys/conf.h>
#include <sys/ddi.h>
#include <sys/debug.h>
#include <sys/devops.h>
#include <sys/dls.h>
#include <sys/dls_mgmt.h>
#include <sys/errno.h>
#include <sys/file.h>
#include <sys/kmem.h>
#include <sys/kmem.h>
#include <sys/ksynch.h>
#include <sys/log.h>
#include <sys/mac_client.h>
#include <sys/modctl.h>
#include <sys/modctl.h>
#include <sys/param.h>
#include <sys/pci.h>
#include <sys/stat.h>
#include <sys/stream.h>
#include <sys/stropts.h>
#include <sys/strsubr.h>
#include <sys/strsun.h>
#include <sys/sunndi.h>
#include <sys/sysmacros.h>
#include <sys/types.h>
#include <sys/ethernet.h>

/*
 * There will be only one aoe instance
 */
typedef struct aoe_soft_state {
	dev_info_t	*ss_dip;
	uint32_t	 ss_flags;
	list_t		 ss_mac_list;
	list_t		 ss_port_list;
	uint32_t	 ss_ioctl_flags;
	kmutex_t	 ss_ioctl_mutex;
} aoe_soft_state_t;

/*
 * One for each ethernet interface
 */
struct aoe_port;
typedef struct aoe_mac
{
	list_node_t		am_ss_node;
	datalink_id_t		am_linkid;
	char			am_ifname[MAXNAMELEN];

	struct aoe_port		*am_port;
	aoe_soft_state_t	*am_ss;

	mac_handle_t		am_handle;
	mac_client_handle_t	am_cli_handle;
	mac_promisc_handle_t	am_promisc_handle;
	mac_notify_handle_t	am_notify_handle;
	mac_unicast_handle_t	am_unicst_handle;
	ether_addr_t		am_primary_addr;
	ether_addr_t		am_current_addr;
	uint32_t		am_running:1,
				am_force_promisc:1,
				am_rsvd:22,
				am_link_state:8;
	uint32_t		am_use_cnt;
	uint32_t		am_frm_cnt;
	uint32_t		am_link_speed;
	uint32_t		am_mtu;
	uint64_t		am_rtt_cnt;
	uint64_t		am_rx_frames;
	uint64_t		am_tx_frames;
	kcondvar_t		am_tx_cv;
	kmutex_t		am_mutex;
} aoe_mac_t;

typedef struct aoe_path
{
	aoe_mac_t		*ap_mac;
	ether_addr_t		ap_addr;
	uint16_t		ap_state;
	uint32_t		ap_link_speed; /* in Mbps */
	uint32_t		ap_weight;
	uint32_t		ap_wait_cnt;
} aoe_path_t;

#define	WLB_MAX_RETRY_COUNT	100
#define	WLB_RTT_WEIGHT(x)	(x << 1)

typedef struct aoe_unit
{
	unsigned long		au_unit;
	aoe_path_t		au_path[AOE_MAX_MACOBJ];
	uint32_t		au_path_cnt;
	uint32_t		au_rrp_next;
} aoe_unit_t;

typedef struct aoe_port
{
	list_node_t		p_ss_node;
	aoe_eport_t		p_eport;
	aoe_soft_state_t	*p_ss;
	dev_info_t		*p_client_dev;
	aoe_client_t		p_client;
	kmem_cache_t		*p_frame_cache;
	aoe_cli_policy_t	p_policy;
	aoe_cli_type_t		p_type;
	uint32_t		p_portid;
	uint32_t		p_rsvd:28,
				p_state:4;
	uint32_t		p_flags;
	uint32_t		p_mac_cnt;
	uint32_t		p_unit_cnt;
	aoe_unit_t		p_unit[AOE_MAX_UNIT];
	aoe_mac_t		*p_mac[AOE_MAX_MACOBJ];
} aoe_port_t;

#define	EPORT2PORT(x_eport)	((aoe_port_t *)(x_eport)->eport_aoe_private)
#define	FRM2MAC(x_frm)		((aoe_mac_t *)(x_frm)->af_mac)

#define	AOE_PORT_FLAG_BOUND	0x01
#define	AOE_PORT_FLAG_BUSY	0x02

#define	AOE_STR_LEN		32
#define	MAX_RESERVE_SIZE	(AOE_MAX_MACOBJ * ETHERADDRL)

/*
 * Ethernet functions
 */
static int	aoe_open_mac(aoe_mac_t *, int);
static int	aoe_close_mac(aoe_mac_t *);
static void	aoe_destroy_mac(aoe_mac_t *);
static void	aoe_destroy_port(aoe_port_t *port);
static aoe_mac_t  *aoe_lookup_mac_by_id(datalink_id_t);
static aoe_port_t *aoe_lookup_port_by_id(uint32_t);
static aoe_mac_t  *aoe_create_mac_by_id(uint32_t, datalink_id_t, int *);
static int	aoe_mac_set_address(aoe_mac_t *, uint8_t *, boolean_t);
static void	aoe_port_notify_link_up(void *);
static void	aoe_port_notify_link_down(void *);
static void	aoe_mac_notify(void *, mac_notify_type_t);
static mblk_t	*aoe_get_mblk(aoe_mac_t *, uint32_t);

/*
 * Driver's global variables
 */
static char	aoe_ident[] = "Common AOE library and nexus driver";
static void	*aoe_state = NULL;
aoe_soft_state_t *aoe_global_ss	= NULL;

/*
 * Nexus driver functions
 */
static int	aoe_bus_ctl(dev_info_t *, dev_info_t *, ddi_ctl_enum_t,
    void *, void *result);
static int	aoe_initchild(dev_info_t *, dev_info_t *);
static int	aoe_uninitchild(dev_info_t *, dev_info_t *);
static int	aoe_attach(dev_info_t *, ddi_attach_cmd_t);
static int	aoe_detach(dev_info_t *, ddi_detach_cmd_t);
static int	aoe_open(dev_t *, int, int, cred_t *);
static int	aoe_close(dev_t, int, int, cred_t *);
static int	aoe_ioctl(dev_t, int, intptr_t, int, cred_t *, int *);
static int	aoe_copyin_iocdata(intptr_t, int, aoeio_t **, void **, void **,
    void **);
static int	aoe_copyout_iocdata(intptr_t, int, aoeio_t *, void *);
static int	aoe_iocmd(aoe_soft_state_t *, intptr_t, int);
static int	aoe_create_port(dev_info_t *, aoe_port_t *, aoe_cli_type_t,
    aoe_cli_policy_t, char *);
static int	aoe_delete_port(dev_info_t *, aoeio_t *, uint32_t);
static int	aoe_get_port_list(aoe_port_instance_t *, int);
static int	aoe_i_port_autoconf(uint32_t);
static void	aoe_unit_update(aoe_port_t *, aoe_mac_t *, int, int);

/*
 * Client functions
 */
static void	aoe_deregister_client(aoe_eport_t *);
static void	aoe_rx(void *, mac_resource_handle_t, mblk_t *, boolean_t);
static int	aoe_enable_callback(aoe_mac_t *);
static int	aoe_disable_callback(aoe_mac_t *);
static int	aoe_ctl(aoe_eport_t *, void *, int, void *);
static int	aoe_report_unit(aoe_eport_t *, void *, unsigned long, char *);
static void	aoe_tx_frame(aoe_frame_t *);
static void	aoe_release_frame(aoe_frame_t *);
static void	*aoe_alloc_netb(aoe_frame_t *, uint32_t, caddr_t, int);
static void	aoe_free_netb(void *);
static aoe_frame_t *aoe_allocate_frame(aoe_eport_t *, int, void *, int);
static uint8_t	*aoe_get_mac_addr(void *);
static int	aoe_get_mac_link_state(void *);
static uint32_t aoe_allow_port_detach(aoe_eport_t *);

/*
 * Driver identificaton stuff
 */
static struct cb_ops aoe_cb_ops = {
	aoe_open,
	aoe_close,
	nodev,
	nodev,
	nodev,
	nodev,
	nodev,
	aoe_ioctl,
	nodev,
	nodev,
	nodev,
	nochpoll,
	ddi_prop_op,
	0,
	D_MP | D_NEW | D_HOTPLUG,
	CB_REV,
	nodev,
	nodev
};

static struct bus_ops aoe_busops = {
	BUSO_REV,
	nullbusmap,			/* bus_map */
	NULL,				/* bus_get_intrspec */
	NULL,				/* bus_add_intrspec */
	NULL,				/* bus_remove_intrspec */
	i_ddi_map_fault,		/* bus_map_fault */
	NULL,				/* bus_dma_map (OBSOLETE) */
	ddi_dma_allochdl,		/* bus_dma_allochdl */
	ddi_dma_freehdl,		/* bus_dma_freehdl */
	ddi_dma_bindhdl,		/* bus_dma_bindhdl */
	ddi_dma_unbindhdl,		/* bus_unbindhdl */
	ddi_dma_flush,			/* bus_dma_flush */
	ddi_dma_win,			/* bus_dma_win */
	ddi_dma_mctl,			/* bus_dma_ctl */
	aoe_bus_ctl,			/* bus_ctl */
	ddi_bus_prop_op,		/* bus_prop_op */
	NULL,				/* bus_get_eventcookie */
	NULL,				/* bus_add_eventcall */
	NULL,				/* bus_remove_event */
	NULL,				/* bus_post_event */
	NULL,				/* bus_intr_ctl */
	NULL,				/* bus_config */
	NULL,				/* bus_unconfig */
	NULL,				/* bus_fm_init */
	NULL,				/* bus_fm_fini */
	NULL,				/* bus_fm_access_enter */
	NULL,				/* bus_fm_access_exit */
	NULL,				/* bus_power */
	NULL
};

static struct dev_ops aoe_dev_ops = {
	DEVO_REV,
	0,
	ddi_no_info,
	nulldev,			/* identify */
	nulldev,			/* probe */
	aoe_attach,			/* attach */
	aoe_detach,			/* detach */
	nodev,				/* reset */
	&aoe_cb_ops,			/* cb_ops */
	&aoe_busops,			/* bus_ops */
	NULL,				/* power */
	ddi_quiesce_not_supported	/* quiesce */
};

extern char *aoepath_prop;

/* Standard Module linkage initialization for a Streams driver */
extern struct mod_ops mod_driverops;

static struct modldrv modldrv = {
	&mod_driverops,	    /* Type of module.  This one is a driver */
	aoe_ident,	    /* short description */
	&aoe_dev_ops	    /* driver specific ops */
};

static struct modlinkage modlinkage = {
	MODREV_1,
	{
		(void *)&modldrv,
		NULL,
	},
};

/*
 * Bus control operations for nexus drivers.
 */
static int
aoe_bus_ctl(dev_info_t *aoe_dip, dev_info_t *rip,
    ddi_ctl_enum_t op, void *clientarg, void *result)
{
	int ret;
	switch (op) {
	case DDI_CTLOPS_REPORTDEV:
	case DDI_CTLOPS_IOMIN:
		ret = DDI_SUCCESS;
		break;

	case DDI_CTLOPS_INITCHILD:
		ret = aoe_initchild(aoe_dip, (dev_info_t *)clientarg);
		break;

	case DDI_CTLOPS_UNINITCHILD:
		ret = aoe_uninitchild(aoe_dip, (dev_info_t *)clientarg);
		break;

	default:
		ret = ddi_ctlops(aoe_dip, rip, op, clientarg, result);
		break;
	}

	return (ret);
}

/*
 * We need specify the dev address for client driver's instance, or we
 * can't online client driver's instance.
 */
/* ARGSUSED */
static int
aoe_initchild(dev_info_t *aoe_dip, dev_info_t *client_dip)
{
	char	client_addr[AOE_STR_LEN];
	int	rval;

	rval = ddi_prop_get_int(DDI_DEV_T_ANY, client_dip,
	    DDI_PROP_DONTPASS | DDI_PROP_NOTPROM, "port_id", -1);
	if (rval == -1) {
		dev_err(aoe_dip, CE_WARN, "no port_id property: %p",
		    (void *)client_dip);
		return (DDI_FAILURE);
	}

	bzero(client_addr, AOE_STR_LEN);
	(void) sprintf((char *)client_addr, "%x,0", rval);
	ddi_set_name_addr(client_dip, client_addr);
	return (DDI_SUCCESS);
}

/* ARGSUSED */
static int
aoe_uninitchild(dev_info_t *aoe_dip, dev_info_t *client_dip)
{
	ddi_set_name_addr(client_dip, NULL);
	return (DDI_SUCCESS);
}

static int
aoe_open_mac(aoe_mac_t *mac, int force_promisc)
{
	int		ret;
	char		cli_name[MAXNAMELEN];
	mac_diag_t	diag;
	uint16_t	am_open_flag = 0;

	/*
	 * Open MAC interface
	 */
	ret = mac_open_by_linkid(mac->am_linkid, &mac->am_handle);
	if (ret != 0) {
		if (mac->am_ifname)
			ret = mac_open(mac->am_ifname, &mac->am_handle);
		if (ret != 0) {
			cmn_err(CE_WARN, "mac_open %d failed %x",
			    mac->am_linkid, ret);
			return (DDI_FAILURE);
		}
	}

	(void) sprintf(cli_name, "%s-%d", "aoe", mac->am_linkid);

	ret = mac_client_open(mac->am_handle,
	    &mac->am_cli_handle, cli_name, am_open_flag);
	if (ret != 0) {
		(void) aoe_close_mac(mac);
		return (DDI_FAILURE);
	}

	/*
	 * Cache the pointer of the immutable MAC inforamtion and
	 * the current and primary MAC address
	 */
	mac_unicast_primary_get(mac->am_handle, mac->am_primary_addr);
	ether_copy((void *)mac->am_primary_addr, (void *)mac->am_current_addr);

	ret = mac_unicast_add(mac->am_cli_handle, NULL, MAC_UNICAST_PRIMARY,
	    &mac->am_unicst_handle, 0, &diag);
	if (ret != 0) {
		cmn_err(CE_WARN, "mac_unicast_add failed. ret=%d", ret);
		(void) aoe_close_mac(mac);
		return (DDI_FAILURE);
	}

	if (force_promisc) {
		mac->am_force_promisc = B_TRUE;
	}

	/* Get mtu */
	mac_sdu_get(mac->am_handle, NULL, &mac->am_mtu);

	/* Get link speed */
	mac->am_link_speed =
	    mac_client_stat_get(mac->am_cli_handle, MAC_STAT_IFSPEED);

	cv_init(&mac->am_tx_cv, NULL, CV_DRIVER, NULL);
	mutex_init(&mac->am_mutex, NULL, MUTEX_DRIVER, NULL);
	mac->am_running = B_TRUE;

	return (DDI_SUCCESS);
}

static int
aoe_close_mac(aoe_mac_t *mac)
{
	int ret;

	if (mac->am_handle == NULL) {
		return (DDI_SUCCESS);
	}

	if (mac->am_running) {
		cv_destroy(&mac->am_tx_cv);
		mutex_destroy(&mac->am_mutex);
		mac->am_running = B_FALSE;
	}

	if (mac->am_promisc_handle != NULL) {
		mac_promisc_remove(mac->am_promisc_handle);
		mac->am_promisc_handle = NULL;
	} else {
		mac_rx_clear(mac->am_cli_handle);
	}

	if (mac->am_notify_handle != NULL) {
		ret = mac_notify_remove(mac->am_notify_handle, B_TRUE);
		ASSERT(ret == 0);
		mac->am_notify_handle = NULL;
	}

	if (mac->am_unicst_handle != NULL) {
		(void) mac_unicast_remove(mac->am_cli_handle,
		    mac->am_unicst_handle);
		mac->am_unicst_handle = NULL;
	}

	mac_client_close(mac->am_cli_handle, 0);
	mac->am_cli_handle = NULL;

	(void) mac_close(mac->am_handle);
	mac->am_handle = NULL;
	return (DDI_SUCCESS);
}

/*
 * Return mac instance if it exist, or else return NULL.
 */
static aoe_mac_t *
aoe_lookup_mac_by_id(datalink_id_t linkid)
{
	aoe_mac_t *mac = NULL;

	ASSERT(MUTEX_HELD(&aoe_global_ss->ss_ioctl_mutex));
	for (mac = list_head(&aoe_global_ss->ss_mac_list); mac;
	    mac = list_next(&aoe_global_ss->ss_mac_list, mac)) {
		if (linkid == mac->am_linkid)
			return (mac);
	}
	return (NULL);
}

/*
 * Return port instance if it exist, or else return NULL.
 */
static aoe_port_t *
aoe_lookup_port_by_id(uint32_t portid)
{
	aoe_port_t *port = NULL;

	ASSERT(MUTEX_HELD(&aoe_global_ss->ss_ioctl_mutex));
	for (port = list_head(&aoe_global_ss->ss_port_list); port;
	    port = list_next(&aoe_global_ss->ss_port_list, port)) {
		if (portid == port->p_portid)
			return (port);
	}
	return (NULL);
}

/*
 * Return aoe_mac if it exists, otherwise create a new one
 */
static aoe_mac_t *
aoe_create_mac_by_id(uint32_t portid, datalink_id_t linkid,
    int *is_port_created)
{
	aoe_port_t *port;
	aoe_mac_t *mac;
	int port_created = 0;
	ASSERT(MUTEX_HELD(&aoe_global_ss->ss_ioctl_mutex));

	*is_port_created = 0;
	port = aoe_lookup_port_by_id(portid);
	if (port == NULL) {
		port = kmem_zalloc(sizeof (aoe_port_t), KM_SLEEP);
		if (!port)
			return (NULL);
		port->p_portid = portid;
		port->p_ss = aoe_global_ss;
		port->p_mac_cnt = 0;

		list_insert_tail(&port->p_ss->ss_port_list, port);
		port_created = 1;
	}

	mac = aoe_lookup_mac_by_id(linkid);
	if (mac != NULL) {
		if (port_created)
			aoe_destroy_port(port);
		return (NULL);
	}

	mac = kmem_zalloc(sizeof (aoe_mac_t), KM_SLEEP);
	if (!mac) {
		if (port_created)
			aoe_destroy_port(port);
		return (NULL);
	}
	mac->am_linkid = linkid;
	mac->am_ss = aoe_global_ss;
	mac->am_port = port;
	port->p_mac[port->p_mac_cnt++] = mac;

	list_insert_tail(&mac->am_ss->ss_mac_list, mac);
	*is_port_created = port_created;
	return (mac);
}

static void
aoe_destroy_port(aoe_port_t *port)
{
	ASSERT(port != NULL);
	ASSERT(port->p_mac_cnt == 0);
	list_remove(&port->p_ss->ss_port_list, port);
	kmem_free(port, sizeof (aoe_port_t));
}

static void
aoe_destroy_mac(aoe_mac_t *mac)
{
	aoe_port_t *port;
	ASSERT(mac != NULL);

	port = mac->am_port;
	list_remove(&mac->am_ss->ss_mac_list, mac);
	kmem_free(mac, sizeof (aoe_mac_t));

	port->p_mac_cnt--;
}


/*
 * The following routines will be called through vectors in aoe_eport_t
 */

/*
 * Deregister aoet/aoei modules, client should make sure the port is in
 * offline status already
 */
static void
aoe_deregister_client(aoe_eport_t *eport)
{
	aoe_port_t *port = EPORT2PORT(eport);
	int i, found = 0;

	/*
	 * Wait for all the related frame to be freed, this should be fast
	 * because before deregister aoei/aoet will make sure its port
	 * is already in offline status so no frame will be received or sent
	 * any more
	 */
	for (i = 0; i < port->p_mac_cnt; i++) {
		if (port->p_mac[i]->am_frm_cnt > 0) {
			found = 1;
			break;
		}
	}
	if (found)
		delay(100);

	kmem_cache_destroy(port->p_frame_cache);

	atomic_and_32(&port->p_flags, ~AOE_PORT_FLAG_BOUND);
}

/* ARGSUSED */
static void
aoe_rx(void *arg, mac_resource_handle_t mrh, mblk_t *mp, boolean_t loopback)
{
	aoe_mac_t *mac = (aoe_mac_t *)arg;
	mblk_t *next;
	aoe_frame_t *frm;
	uint16_t frm_type;
	aoe_port_t *port;

	port = mac->am_port;

	while (mp != NULL) {
		next = mp->b_next;
		mp->b_next = NULL;
		frm_type = ntohs(*(uint16_t *)((uintptr_t)mp->b_rptr + 12));

		if (frm_type != ETHERTYPE_AOE ||
		    !(port->p_flags & AOE_PORT_FLAG_BOUND)) {
			/*
			 * This mp is not allocated in AoE, we must free it...
			 *
			 * We are using freemsg because we haven't done the
			 * b_cont check yet. Most of the time it WILL be a
			 * single mblk, but freemsg is more conservative here.
			 */
			freemsg(mp);
			mp = next;
			continue;
		}

		if (mp->b_cont != NULL) {
			mblk_t *nmp = msgpullup(mp, -1);
			if (nmp == NULL) {
				freemsg(mp);
				mp = next;
				continue;
			}
			/* Reset it to new collapsed mp */
			freemsg(mp);
			mp = nmp;
		}

		frm = aoe_allocate_frame(&port->p_eport, -1, mac, KM_NOSLEEP);
		if (frm != NULL) {
			aoe_hdr_t *h = (aoe_hdr_t *)mp->b_rptr;

			ether_copy((void *)h->aoeh_src, (void *)frm->af_addr);
			frm->af_netb = mp;
			frm->af_data = (uint8_t *)mp->b_rptr;
			port->p_client.ect_rx_frame(frm);
			mac->am_rx_frames++;
		} else
			/* Using freeb because we know it is a single mblk */
			freeb(mp);

		mp = next;
	}
}

static int
aoe_enable_callback(aoe_mac_t *mac)
{
	int ret;

	/*
	 * Set message callback
	 */
	if (mac->am_force_promisc) {
		ret = mac_promisc_add(mac->am_cli_handle,
		    MAC_CLIENT_PROMISC_FILTERED, aoe_rx, mac,
		    &mac->am_promisc_handle,
		    MAC_PROMISC_FLAGS_NO_TX_LOOP);
		if (ret != 0) {
			dev_err(mac->am_port->p_client_dev, CE_WARN,
			    "mac_promisc_add on %d failed (%x)",
			    mac->am_linkid, ret);
			return (DDI_FAILURE);
		}
	} else {
		mac_rx_set(mac->am_cli_handle, aoe_rx, mac);
	}

	/* Get the link state, if it's up, we will need to notify client */
	mac->am_link_state =
	    mac_stat_get(mac->am_handle, MAC_STAT_LINK_UP)?
	    AOE_MAC_LINK_STATE_UP:AOE_MAC_LINK_STATE_DOWN;

	/*
	 * Add a notify function so that we get updates from MAC
	 */
	mac->am_notify_handle = mac_notify_add(mac->am_handle,
	    aoe_mac_notify, (void *)mac);
	return (DDI_SUCCESS);
}

static int
aoe_disable_callback(aoe_mac_t *mac)
{
	int ret;

	if (mac->am_promisc_handle) {
		mac_promisc_remove(mac->am_promisc_handle);
		mac->am_promisc_handle = NULL;
	} else {
		mac_rx_clear(mac->am_cli_handle);
	}

	if (mac->am_notify_handle) {
		ret = mac_notify_remove(mac->am_notify_handle, B_TRUE);
		ASSERT(ret == 0);
		mac->am_notify_handle = NULL;
	}

	ret = aoe_mac_set_address(mac, mac->am_primary_addr, B_FALSE);

	return (ret);
}

static void
aoe_update_path_info(aoe_unit_t *u, aoe_path_t *p)
{
	aoe_path_t *xp;
	unsigned int i;
	uint32_t max_speed;

	p->ap_link_speed = p->ap_mac->am_link_speed / 1000000;

	/* find the maximum speed */
	max_speed = 0;
	for (i = 0; i < u->au_path_cnt; i++) {
		xp = &u->au_path[i];
		if (xp->ap_link_speed > max_speed)
			max_speed = xp->ap_link_speed;
	}

	/* update per-path weight */
	for (i = 0; i < u->au_path_cnt; i++) {
		xp = &u->au_path[i];
		if (xp->ap_link_speed)
			xp->ap_weight = max_speed / xp->ap_link_speed;
		else
			xp->ap_weight = 100; /* an arbitrary number */
	}

	/* update per-path wait count */
	for (i = 0; i < u->au_path_cnt; i++) {
		xp = &u->au_path[i];
		xp->ap_wait_cnt = xp->ap_weight;
	}
}

static int
aoe_report_unit(aoe_eport_t *eport, void *mac, unsigned long unit,
    char *dst_addr)
{
	int i, j;
	aoe_unit_t *u = NULL;
	aoe_path_t *p = NULL;
	aoe_port_t *port = EPORT2PORT(eport);

	for (i = 0; i < port->p_unit_cnt; i++) {
		if (port->p_unit[i].au_unit == unit) {
			u = &port->p_unit[i];
			break;
		}
	}

	if (u == NULL) {
		/*
		 * Record new unit
		 */
		u = &port->p_unit[i];
		u->au_unit = unit;
		p = &u->au_path[u->au_path_cnt++];
		p->ap_mac = mac;
		p->ap_state = AOE_CMD_PORT_UNIT_ONLINE;
		if (port->p_policy == AOE_POLICY_LOADBALANCE)
			aoe_update_path_info(u, p);
		ether_copy((void *)dst_addr, (void *)p->ap_addr);
		port->p_unit_cnt++;
		return (i);
	}

	/*
	 * See if it is a new path... and log new path if so
	 */
	for (j = 0; j < u->au_path_cnt; j++) {
		if (u->au_path[j].ap_mac == mac) {
			p = &u->au_path[j];
			break;
		}
	}

	if (p == NULL) {
		p = &u->au_path[u->au_path_cnt++];
		p->ap_mac = mac;
		p->ap_state = AOE_CMD_PORT_UNIT_ONLINE;
		if (port->p_policy == AOE_POLICY_LOADBALANCE)
			aoe_update_path_info(u, p);
	}
	ether_copy((void *)dst_addr, (void *)p->ap_addr);

	return (i);
}

static void
aoe_unit_update(aoe_port_t *port, aoe_mac_t *mac, int cmd, int unit_id)
{
	aoe_unit_t *u;
	aoe_path_t *p = NULL;
	int j;

	/*
	 * Must report unit first
	 */
	ASSERT(unit_id <= port->p_unit_cnt);

	u = &port->p_unit[unit_id];

	/*
	 * Log state to the matching path
	 */
	for (j = 0; j < u->au_path_cnt; j++) {
		if (u->au_path[j].ap_mac == mac) {
			p = &u->au_path[j];
			break;
		}
	}

	if (p) {
		if (cmd == AOE_CMD_PORT_UNIT_RETRANSMIT)
			p->ap_mac->am_rtt_cnt++;
		else
			p->ap_state = (uint16_t)cmd;
	}
}

/* ARGSUSED */
static int
aoe_ctl(aoe_eport_t *eport, void *mac, int cmd, void *arg)
{
	aoe_port_t *port = EPORT2PORT(eport);
	int i;

	switch (cmd) {
		case AOE_CMD_PORT_ONLINE:
			for (i = 0; i < port->p_mac_cnt; i++) {
				if (aoe_enable_callback(port->p_mac[i])
				    == DDI_FAILURE) {
					int j;
					for (j = i - 1; j >= 0; j--)
						(void) aoe_disable_callback(
						    port->p_mac[j]);
					return (DDI_FAILURE);
				}
			}
			port->p_state = AOE_PORT_STATE_ONLINE;
			break;
		case AOE_CMD_PORT_OFFLINE:
			for (i = 0; i < port->p_mac_cnt; i++) {
				if (aoe_disable_callback(port->p_mac[i])
				    == DDI_FAILURE) {
					int j;
					for (j = i - 1; j >= 0; j--)
						(void) aoe_enable_callback(
						    port->p_mac[j]);
					return (DDI_FAILURE);
				}
			}
			port->p_state = AOE_PORT_STATE_OFFLINE;

			/*
			 * in case there are threads waiting
			 */
			for (i = 0; i < port->p_mac_cnt; i++) {
				mutex_enter(&port->p_mac[i]->am_mutex);
				cv_broadcast(&port->p_mac[i]->am_tx_cv);
				mutex_exit(&port->p_mac[i]->am_mutex);
			}
			break;
		case AOE_CMD_PORT_UNIT_ONLINE:
			aoe_unit_update(port, mac, cmd, (unsigned long)arg);
			break;
		case AOE_CMD_PORT_UNIT_OFFLINE:
			aoe_unit_update(port, mac, cmd, (unsigned long)arg);
			break;
		case AOE_CMD_PORT_UNIT_RETRANSMIT:
			aoe_unit_update(port, mac, cmd, (unsigned long)arg);
			break;
		default:
			dev_err(port->p_client_dev, CE_WARN,
			    "aoe_ctl, unsupported cmd %x", cmd);
			break;
	}

	return (DDI_SUCCESS);
}

/*
 * Transmit the specified frame to the link
 */
static void
aoe_tx_frame(aoe_frame_t *af)
{
	mblk_t *ret_mblk = NULL;
	aoe_mac_t *mac = FRM2MAC(af);
	mac_tx_cookie_t	ret_cookie;

tx_frame:
	ret_cookie = mac_tx(mac->am_cli_handle, af->af_netb, 0,
	    MAC_TX_NO_ENQUEUE, &ret_mblk);
	if (ret_cookie != NULL) {
		mutex_enter(&mac->am_mutex);
		(void) cv_reltimedwait(&mac->am_tx_cv, &mac->am_mutex,
		    drv_usectohz(100000), TR_CLOCK_TICK);
		mutex_exit(&mac->am_mutex);

		if (mac->am_port->p_state == AOE_PORT_STATE_OFFLINE) {
			/*
			 * we are doing offline, so just tell the upper that
			 * this is finished, the cmd will be aborted soon.
			 */
			aoe_free_netb(ret_mblk);
		} else {
			goto tx_frame;
		}
	}

	/*
	 * MAC driver will release the mblk of the frame
	 */

	mac->am_tx_frames++;
}

/*
 * raw frame layout:
 * AoE header + AoE command + AoE payload
 */
/* ARGSUSED */
static mblk_t *
aoe_get_mblk(aoe_mac_t *mac, uint32_t raw_frame_size)
{
	mblk_t	*mp;
	int	 err;

	while ((mp = allocb((size_t)raw_frame_size, 0)) == NULL) {
		if ((err = strwaitbuf((size_t)raw_frame_size, BPRI_LO)) != 0) {
			dev_err(mac->am_port->p_client_dev, CE_WARN,
			    "strwaitbuf return %d", err);
			return (NULL);
		}
	}
	mp->b_wptr = mp->b_rptr + raw_frame_size;

	return (mp);
}

static void *
aoe_alloc_netb(aoe_frame_t *af, uint32_t buf_size, caddr_t buf, int kmflag)
{
	mblk_t *mp;
	aoe_mac_t *mac = FRM2MAC(af);

	if (buf)
		mp = kmflag == KM_NOSLEEP ?
		    esballoc((unsigned char *)buf, buf_size, 0, &frnop) :
		    esballoc_wait((unsigned char *)buf, buf_size, 0, &frnop);
	else
		mp = aoe_get_mblk(mac, buf_size);

	if (mp) {
		if (af->af_netb == NULL) {
			aoe_hdr_t *h = (aoe_hdr_t *)mp->b_rptr;

			af->af_netb = mp;
			af->af_data = (uint8_t *)mp->b_rptr;
			ether_copy((void *)mac->am_current_addr,
			    (void *)h->aoeh_src);
			ether_copy((void *)af->af_addr,
			    (void *)h->aoeh_dst);
		} else
			((mblk_t *)af->af_netb)->b_cont = mp;
		mp->b_wptr = mp->b_rptr + buf_size;
	}

	return (mp);
}

static void
aoe_free_netb(void *netb)
{
	freeb((mblk_t *)netb);
}

static void
aoe_release_frame(aoe_frame_t *af)
{
	aoe_port_t *port = EPORT2PORT(af->af_eport);
	aoe_mac_t *mac = FRM2MAC(af);
	aoe_hdr_t *h = (aoe_hdr_t *)af->af_data;

	if (h->aoeh_cmd == AOECMD_ATA && mac->am_rtt_cnt)
		mac->am_rtt_cnt--;
	kmem_cache_free(port->p_frame_cache, af);
	mac->am_frm_cnt--;
}

static aoe_path_t *
load_balancing(aoe_unit_t *u)
{
	aoe_mac_t	*mac;
	aoe_path_t	*p = NULL;
	aoe_path_t	*xp = NULL;
	int		i;
	int		j = 0;
	int		mst;
	int		pst;
	int		retry = 0;

	for (;;) {
		if (u->au_rrp_next >= u->au_path_cnt)
			i = u->au_rrp_next = 0;
		else
			i = u->au_rrp_next++;
		if (j > u->au_path_cnt) {
			/*
			 * We have already scanned all the paths,
			 * if there is one online, use it!
			 */
			if (xp) {
				p = xp;
				break;
			} else {
				retry++;
				if (retry > WLB_MAX_RETRY_COUNT) {
					p = NULL;
					break;
				}
				j = 0;
				delay(30);
				continue;
			}
		}
		j++;	/* number of paths scanned so far */
		p = &u->au_path[i];
		mac = p->ap_mac;
		if (mac == NULL)
			continue;
		mst = mac->am_link_state;
		pst = p->ap_state;
		if (mst == AOE_MAC_LINK_STATE_UP &&
		    pst == AOE_CMD_PORT_UNIT_ONLINE) {
			/* found an online path */
			if (--p->ap_wait_cnt) {
				/* weight has not fully dropped yet */
				xp = p;
				continue;
			} else {
				/* reset weight & return the path */
				p->ap_wait_cnt = p->ap_weight +
				    WLB_RTT_WEIGHT(mac->am_rtt_cnt);
				break;
			}
		}
	}
	return (p);
}

static aoe_frame_t *
aoe_allocate_frame(aoe_eport_t *eport, int unit_id, void *xmac, int kmflag)
{
	aoe_port_t *port = EPORT2PORT(eport);
	aoe_frame_t *af;
	aoe_mac_t *mac = xmac;
	int i;

	/*
	 * aoe_frame_t initialization
	 */
	af = (aoe_frame_t *)kmem_cache_alloc(port->p_frame_cache, kmflag);
	if (af == NULL)
		return (NULL);
	bzero(af, sizeof (*af) + port->p_client.ect_private_frame_struct_size);

	if (mac == NULL) {
		aoe_path_t *p = NULL;

		ASSERT(unit_id <= port->p_unit_cnt);
		ASSERT(port->p_unit_cnt);

		/*
		 * Apply selected port policy
		 */
		if (port->p_policy == AOE_POLICY_NONE) {
			p = &port->p_unit[unit_id].au_path[0];
		} else if (port->p_policy == AOE_POLICY_FAILOVER) {
			aoe_unit_t *u = &port->p_unit[unit_id];

			/*
			 * Select first ONLINE path
			 */
			for (i = 0; i < u->au_path_cnt; i++) {
				int mst = u->au_path[i].ap_mac->am_link_state;
				int pst = u->au_path[i].ap_state;

				if (mst == AOE_MAC_LINK_STATE_UP &&
				    pst == AOE_CMD_PORT_UNIT_ONLINE) {
					p = &u->au_path[i];
					break;
				}
			}
		} else if (port->p_policy == AOE_POLICY_ROUNDROBIN) {
			aoe_unit_t *u = &port->p_unit[unit_id];
			int j = 0;

			/*
			 * Just round-robin through ONLINE paths
			 */
round2:
			for (i = u->au_rrp_next++; i < u->au_path_cnt; i++) {
				int mst = u->au_path[i].ap_mac->am_link_state;
				int pst = u->au_path[i].ap_state;

				if (mst == AOE_MAC_LINK_STATE_UP &&
				    pst == AOE_CMD_PORT_UNIT_ONLINE) {
					p = &u->au_path[i];
					break;
				}
				j++;
			}
			if (p == NULL && j < u->au_path_cnt) {
				u->au_rrp_next = 0;
				goto round2;
			}
			if (p == NULL || u->au_rrp_next == u->au_path_cnt)
				u->au_rrp_next = 0;
		} else if (port->p_policy == AOE_POLICY_LOADBALANCE) {
			/*
			 * Weighted balancing
			 */
			p = load_balancing(&port->p_unit[unit_id]);
		} else {
			ASSERT(0);
		}

		if (p == NULL) {
			kmem_cache_free(port->p_frame_cache, af);
			return (NULL);
		}

		mac = p->ap_mac;
		ether_copy((void *)p->ap_addr, (void *)af->af_addr);
	} else if (unit_id >= 0) {
		aoe_unit_t *u = &port->p_unit[unit_id];

		/*
		 * If unit_id and xmac specified, we should select the right
		 * target address
		 */
		for (i = 0; i < u->au_path_cnt; i++) {
			if (u->au_path[i].ap_mac == mac) {
				aoe_path_t *p = &u->au_path[i];
				ether_copy((void *)p->ap_addr,
				    (void *)af->af_addr);
				break;
			}
		}
	}

	af->af_eport = eport;
	af->af_mac = mac;

	mac->am_frm_cnt++;

	return (af);
}

static int
aoe_get_mac_link_state(void *xmac)
{
	aoe_mac_t *mac = xmac;

	return (mac->am_link_state);
}

static uint8_t *
aoe_get_mac_addr(void *xmac)
{
	aoe_mac_t	*mac = xmac;

	return (mac->am_current_addr);
}

/*
 * Only this function will be called explicitly by clients
 * Register the specified client port (initiator/target)
 */
aoe_eport_t *
aoe_register_client(aoe_client_t *client)
{
	aoe_eport_t	*eport;
	char		cache_string[32];
	aoe_port_t	*port;
	uint32_t	alloc_size;
	uint32_t	i;
	uint32_t	min_mtu = 0;

	/*
	 * We will not come here, when someone is changing ss_port_list,
	 * so it's safe to go through ss_port_list.
	 */
	for (port = list_head(&aoe_global_ss->ss_port_list); port;
	    port = list_next(&aoe_global_ss->ss_port_list, port)) {
		if (client->ect_channelid == port->p_portid)
			break;
	}

	if (port == NULL) {
		cmn_err(CE_WARN, "can't find the port to bind");
		return (NULL);
	}

	if (port->p_flags & AOE_PORT_FLAG_BOUND) {
		dev_err(port->p_client_dev, CE_WARN,
		    "the port you want to bind is bound already");
		return (NULL);
	}

	atomic_or_32(&port->p_flags, AOE_PORT_FLAG_BOUND);
	bcopy(client, &port->p_client, sizeof (aoe_client_t));

	alloc_size = sizeof (aoe_frame_t) +
	    port->p_client.ect_private_frame_struct_size + MAX_RESERVE_SIZE;

	(void) sprintf(cache_string, "port_frame_cache_%d", port->p_portid);
	port->p_frame_cache = kmem_cache_create(cache_string,
	    alloc_size, 0, NULL, NULL, NULL, port, NULL, KM_SLEEP);
	if (!port->p_frame_cache) {
		return (NULL);
	}
	atomic_or_32(&port->p_flags, AOE_PORT_FLAG_BUSY);

	/*
	 * aoe_eport_t initialization
	 */
	eport = &port->p_eport;
	eport->eport_aoe_private = port;
	eport->eport_client_private = client->ect_client_port_struct;
	eport->eport_mac = (void **)port->p_mac;
	eport->eport_mac_cnt = port->p_mac_cnt;

	for (i = 0; i < port->p_mac_cnt; i++) {
		aoe_mac_t *mac = port->p_mac[i];

		if (min_mtu == 0 || mac->am_mtu < min_mtu)
			min_mtu = mac->am_mtu;
	}

	eport->cache_unit_size = alloc_size;
	eport->eport_maxxfer = (min_mtu - AOEHDRSZ) & ~(DEV_BSIZE - 1);
	eport->eport_tx_frame = aoe_tx_frame;
	eport->eport_alloc_frame = aoe_allocate_frame;
	eport->eport_release_frame = aoe_release_frame;
	eport->eport_alloc_netb = aoe_alloc_netb;
	eport->eport_free_netb = aoe_free_netb;
	eport->eport_deregister_client = aoe_deregister_client;
	eport->eport_get_mac_addr = aoe_get_mac_addr;
	eport->eport_get_mac_link_state = aoe_get_mac_link_state;
	eport->eport_ctl = aoe_ctl;
	eport->eport_report_unit = aoe_report_unit;
	eport->eport_allow_port_detach = aoe_allow_port_detach;

	return (eport);
}

static int
aoe_mac_set_address(aoe_mac_t *mac, uint8_t *addr, boolean_t assigned)
{
	int ret;

	if (ether_cmp((void *)addr, (void *)mac->am_current_addr) == 0) {
		return (DDI_SUCCESS);
	}

	mutex_enter(&mac->am_mutex);
	if (mac->am_promisc_handle == NULL) {
		ret = mac_unicast_primary_set(mac->am_handle, addr);
		if (ret != 0) {
			mutex_exit(&mac->am_mutex);
			dev_err(mac->am_port->p_client_dev, CE_WARN,
			    "mac_unicast_primary_set on %d "
			    "failed %x", mac->am_linkid, ret);
			return (DDI_FAILURE);
		}
	}
	if (assigned) {
		ether_copy((void *)addr,
		    (void *)mac->am_current_addr);
	} else {
		ether_copy((void *)mac->am_primary_addr,
		    (void *)mac->am_current_addr);
	}
	mutex_exit(&mac->am_mutex);
	return (DDI_SUCCESS);
}

static void
aoe_port_notify_link_up(void *arg)
{
	aoe_port_t *port = (aoe_port_t *)arg;

	ASSERT(port->p_flags & AOE_PORT_FLAG_BOUND);

	port->p_client.ect_port_event(&port->p_eport,
	    AOE_NOTIFY_EPORT_LINK_UP);
}

static void
aoe_port_notify_link_down(void *arg)
{
	aoe_port_t *port = (aoe_port_t *)arg;

	if (port->p_flags & AOE_PORT_FLAG_BOUND) {
		port->p_client.ect_port_event(&port->p_eport,
		    AOE_NOTIFY_EPORT_LINK_DOWN);
	}
}

static void
aoe_mac_notify(void *arg, mac_notify_type_t type)
{
	aoe_mac_t *mac = (aoe_mac_t *)arg;
	int link_cnt = 0, i;
	aoe_port_t *port;

	port = mac->am_port;

	/*
	 * We assume that the calls to this notification callback are serialized
	 * by MAC layer.
	 *
	 * Notes for GLDv3: There is one notification thread per mac_handle_t
	 * (mac_impl_t), so if a given callback was only added once on a single
	 * mac_handle_t, then it will not be called concurrently.
	 *
	 * This is based on the current implementation of mac_handle_t.  If that
	 * implementation changes, so should we.
	 */

	switch (type) {
	case MAC_NOTE_LINK:
		/*
		 * This notification is sent every time the MAC driver
		 * updates the link state.
		 */
		if (mac_stat_get(mac->am_handle, MAC_STAT_LINK_UP) != 0) {
			if (mac->am_link_state == AOE_MAC_LINK_STATE_UP) {
				break;
			}

			(void) aoe_mac_set_address(mac,
			    mac->am_primary_addr, B_FALSE);

			mac->am_link_state = AOE_MAC_LINK_STATE_UP;

			for (i = 0; i < port->p_mac_cnt; i++) {
				if (port->p_mac[i]->am_link_state ==
				    AOE_MAC_LINK_STATE_UP)
					link_cnt++;
			}

			/*
			 * Signal only once... we can have 2+ MACs with
			 * different states, but if at least one is green
			 * we are in "good" shape
			 */
			if (link_cnt == 1) {
				dev_err(port->p_client_dev, CE_WARN,
				    "aoe_mac_notify: link/%d arg/%p LINK up",
				    mac->am_linkid, arg);
				aoe_port_notify_link_up(port);
			}
		} else {
			if (mac->am_link_state == AOE_MAC_LINK_STATE_DOWN) {
				break;
			}

			mac->am_link_state = AOE_MAC_LINK_STATE_DOWN;

			for (i = 0; i < port->p_mac_cnt; i++) {
				if (port->p_mac[i]->am_link_state ==
				    AOE_MAC_LINK_STATE_UP)
					link_cnt++;
			}

			/*
			 * Signal only once
			 */
			if (link_cnt == 0) {
				dev_err(port->p_client_dev, CE_WARN,
				    "aoe_mac_notify: link/%d arg/%p LINK down",
				    mac->am_linkid, arg);
				aoe_port_notify_link_down(port);
			}
		}
		break;

	case MAC_NOTE_TX:
		/*
		 * MAC is not so busy now, then wake up aoe_tx_frame to try
		 */
		mutex_enter(&mac->am_mutex);
		cv_broadcast(&mac->am_tx_cv);
		mutex_exit(&mac->am_mutex);
		break;

	case MAC_NOTE_CAPAB_CHG:
		/*
		 * This notification is sent whenever the MAC resources
		 * change or capabilities change. We need to renegotiate
		 * the capabilities. This driver does not support this feature.
		 */
		break;

	case MAC_NOTE_LOWLINK:
		/*
		 * LOWLINK refers to the actual link status. For links that
		 * are not part of a bridge instance LOWLINK and LINK state
		 * are the same (this is handled above). This driver only
		 * support this case.
		 */
		break;

	default:
		dev_err(port->p_client_dev, CE_WARN,
		    "aoe_mac_notify: not supported arg/%p, type/%d",
		    arg, type);
		break;
	}
}

/*
 * Device access entry points
 */
static int
aoe_open(dev_t *devp, int flag, int otype, cred_t *credp)
{
	int instance;
	aoe_soft_state_t *ss;

	if (otype != OTYP_CHR) {
		return (EINVAL);
	}

	/*
	 * Only allow root to issue ioctl
	 */
	if (drv_priv(credp) != 0) {
		return (EPERM);
	}

	instance = (int)getminor(*devp);
	ss = ddi_get_soft_state(aoe_state, instance);
	if (ss == NULL) {
		return (ENXIO);
	}

	mutex_enter(&ss->ss_ioctl_mutex);
	if (ss->ss_ioctl_flags & AOE_IOCTL_FLAG_EXCL) {
		/*
		 * It is already open for exclusive access.
		 * So shut the door on this caller.
		 */
		mutex_exit(&ss->ss_ioctl_mutex);
		return (EBUSY);
	}

	if (flag & FEXCL) {
		if (ss->ss_ioctl_flags & AOE_IOCTL_FLAG_OPEN) {
			/*
			 * Exclusive operation not possible
			 * as it is already opened
			 */
			mutex_exit(&ss->ss_ioctl_mutex);
			return (EBUSY);
		}
		ss->ss_ioctl_flags |= AOE_IOCTL_FLAG_EXCL;
	}

	ss->ss_ioctl_flags |= AOE_IOCTL_FLAG_OPEN;
	mutex_exit(&ss->ss_ioctl_mutex);

	return (0);
}

/* ARGSUSED */
static int
aoe_close(dev_t dev, int flag, int otype, cred_t *credp)
{
	int instance;
	aoe_soft_state_t *ss;

	if (otype != OTYP_CHR) {
		return (EINVAL);
	}

	instance = (int)getminor(dev);
	ss = ddi_get_soft_state(aoe_state, instance);
	if (ss == NULL) {
		return (ENXIO);
	}

	mutex_enter(&ss->ss_ioctl_mutex);
	if ((ss->ss_ioctl_flags & AOE_IOCTL_FLAG_OPEN) == 0) {
		mutex_exit(&ss->ss_ioctl_mutex);
		return (ENODEV);
	}

	ss->ss_ioctl_flags &= ~AOE_IOCTL_FLAG_MASK;
	mutex_exit(&ss->ss_ioctl_mutex);

	return (0);
}

static int
aoe_create_port(dev_info_t *parent, aoe_port_t *port,
    aoe_cli_type_t type, aoe_cli_policy_t policy, char *module)
{
	int rval = 0, i;
	dev_info_t *child = NULL;
	char *devname;

	if (module != NULL)
		devname = module;
	else
		devname = type ? AOET_DRIVER_NAME : AOEI_DRIVER_NAME;

	ndi_devi_alloc_sleep(parent, devname, DEVI_PSEUDO_NODEID, &child);
	if (child == NULL) {
		dev_err(parent, CE_WARN, "fail to create new devinfo '%s'",
		    devname);
		return (NDI_FAILURE);
	}

	if (ddi_prop_update_int(DDI_DEV_T_NONE, child,
	    "port_id", port->p_portid) != DDI_PROP_SUCCESS) {
		dev_err(parent, CE_WARN,
		    "prop_update port_id failed for port %d", port->p_portid);
		(void) ndi_devi_free(child);
		return (NDI_FAILURE);
	}

	rval = ndi_devi_online(child, NDI_ONLINE_ATTACH);
	if (rval != NDI_SUCCESS) {
		dev_err(parent, CE_WARN,
		    "online_driver failed for port %d (%s)", port->p_portid,
		    devname);
		return (NDI_FAILURE);
	}

	port->p_client_dev = child;
	port->p_policy = policy;
	port->p_type = type;

	for (i = 0; i < port->p_mac_cnt; i++)
		port->p_mac[i]->am_use_cnt++;

	return (DDI_SUCCESS);
}

static int
aoe_delete_port(dev_info_t *parent, aoeio_t *aoeio, uint32_t portid)
{
	int rval, i, mac_cnt;
	aoe_port_t *port;
	int mac_in_use = 0;

	port = aoe_lookup_port_by_id(portid);
	if (port == NULL) {
		aoeio->aoeio_status = AOEIOE_INVAL_ARG;
		return (EINVAL);
	}

	for (i = 0; i < port->p_mac_cnt; i++) {
		aoe_mac_t *mac = port->p_mac[i];

		mac = aoe_lookup_mac_by_id(mac->am_linkid);
		if (mac == NULL) {
			aoeio->aoeio_status = AOEIOE_MAC_NOT_FOUND;
			return (EINVAL);
		}
	}

	if (port->p_flags & AOE_PORT_FLAG_BOUND) {
		/*
		 * Offline it first
		 */
		atomic_and_32(&port->p_flags, ~AOE_PORT_FLAG_BUSY);
		rval = ndi_devi_offline(port->p_client_dev, NDI_DEVI_REMOVE);
		if (rval != NDI_SUCCESS) {
			atomic_or_32(&port->p_flags, AOE_PORT_FLAG_BUSY);
			aoeio->aoeio_status = AOEIOE_OFFLINE_FAILURE;
			dev_err(parent, CE_WARN, "offline_driver %s failed",
			    ddi_get_name(port->p_client_dev));
			return (EBUSY);
		}
		atomic_and_32(&port->p_flags, ~AOE_PORT_FLAG_BOUND);
	}

	/*
	 * If AOE_PORT_FLAG_BOUND flag is clear, it means that deferred
	 * detach has finished of last delete operation
	 */

	/*
	 * aoe_destroy_mac() will decrement it.. so we need to
	 * loop using stack variable...
	 */
	mac_cnt = port->p_mac_cnt;
	for (i = mac_cnt - 1; i >= 0; i--) {
		aoe_mac_t *mac = port->p_mac[i];
		if (mac->am_use_cnt <= 1) {
			(void) aoe_close_mac(mac);
			aoe_destroy_mac(mac);
		} else {
			mac_in_use = 1;
			break;
		}
	}
	if (!port->p_mac_cnt && !mac_in_use)
		aoe_destroy_port(port);
	else {
		cmn_err(CE_WARN, "Can't delete port due to mac in use\n");
		return (EINVAL);
	}

	return (0);
}

static int
aoe_get_port_list(aoe_port_instance_t *ports, int count)
{
	int i = 0;
	int j;
	aoe_port_t *port;

	ASSERT(ports != NULL);
	ASSERT(MUTEX_HELD(&aoe_global_ss->ss_ioctl_mutex));

	for (port = list_head(&aoe_global_ss->ss_port_list); port;
	    port = list_next(&aoe_global_ss->ss_port_list, port)) {
		if (i >= count)
			break;
		ports[i].api_mac_cnt = port->p_mac_cnt;
		ports[i].api_maxxfer = port->p_eport.eport_maxxfer;
		ports[i].api_port_id = port->p_portid;
		ports[i].api_port_policy = port->p_policy;
		ports[i].api_port_state = port->p_state;
		ports[i].api_port_type = port->p_type;
		for (j = 0; j < port->p_mac_cnt; j++) {
			aoe_mac_t *mac = port->p_mac[j];

			ports[i].api_mac[j].ami_mac_rx_frames =
			    mac->am_rx_frames;

			ports[i].api_mac[j].ami_mac_tx_frames =
			    mac->am_tx_frames;

			ports[i].api_mac[j].ami_mac_link_state =
			    mac->am_link_state;

			ports[i].api_mac[j].ami_mac_linkid = mac->am_linkid;

			ether_copy((void *)mac->am_current_addr,
			    (void *)ports[i].api_mac[j].ami_mac_current_addr);

			ether_copy((void *)mac->am_primary_addr,
			    (void *)ports[i].api_mac[j].ami_mac_factory_addr);

			ports[i].api_mac[j].ami_mtu_size = mac->am_mtu;

			ports[i].api_mac[j].ami_mac_promisc =
			    mac->am_promisc_handle != NULL ? 1 : 0;
		}
		i++;
	}
	return (i);
}

/* ARGSUSED */
static int
aoe_ioctl(dev_t dev, int cmd, intptr_t data, int mode,
    cred_t *credp, int *rval)
{
	aoe_soft_state_t	*ss;
	int			ret = 0;

	if (drv_priv(credp) != 0) {
		return (EPERM);
	}

	ss = ddi_get_soft_state(aoe_state, (int32_t)getminor(dev));
	if (ss == NULL) {
		return (ENXIO);
	}

	mutex_enter(&ss->ss_ioctl_mutex);
	if ((ss->ss_ioctl_flags & AOE_IOCTL_FLAG_OPEN) == 0) {
		mutex_exit(&ss->ss_ioctl_mutex);
		return (ENXIO);
	}
	mutex_exit(&ss->ss_ioctl_mutex);

	switch (cmd) {
	case AOEIO_CMD:
		ret = aoe_iocmd(ss, data, mode);
		break;
	default:
		ret = ENOTTY;
		break;
	}

	return (ret);
}

static int
aoe_copyin_iocdata(intptr_t data, int mode, aoeio_t **aoeio,
    void **ibuf, void **abuf, void **obuf)
{
	int	ret = 0;

	*ibuf = NULL;
	*abuf = NULL;
	*obuf = NULL;
	*aoeio = kmem_zalloc(sizeof (aoeio_t), KM_SLEEP);
	if (ddi_copyin((void *)data, *aoeio, sizeof (aoeio_t), mode) != 0) {
		ret = EFAULT;
		goto copyin_iocdata_fail;
	}

	if ((*aoeio)->aoeio_ilen > AOEIO_MAX_BUF_LEN ||
	    (*aoeio)->aoeio_alen > AOEIO_MAX_BUF_LEN ||
	    (*aoeio)->aoeio_olen > AOEIO_MAX_BUF_LEN) {
		ret = EFAULT;
		goto copyin_iocdata_fail;
	}

	if ((*aoeio)->aoeio_ilen) {
		*ibuf = kmem_zalloc((*aoeio)->aoeio_ilen, KM_SLEEP);
		if (ddi_copyin((void *)(unsigned long)(*aoeio)->aoeio_ibuf,
		    *ibuf, (*aoeio)->aoeio_ilen, mode) != 0) {
			ret = EFAULT;
			goto copyin_iocdata_fail;
		}
	}

	if ((*aoeio)->aoeio_alen) {
		*abuf = kmem_zalloc((*aoeio)->aoeio_alen, KM_SLEEP);
		if (ddi_copyin((void *)(unsigned long)(*aoeio)->aoeio_abuf,
		    *abuf, (*aoeio)->aoeio_alen, mode) != 0) {
			ret = EFAULT;
			goto copyin_iocdata_fail;
		}
	}

	if ((*aoeio)->aoeio_olen) {
		*obuf = kmem_zalloc((*aoeio)->aoeio_olen, KM_SLEEP);
	}
	return (ret);

copyin_iocdata_fail:
	if (*abuf) {
		kmem_free(*abuf, (*aoeio)->aoeio_alen);
		*abuf = NULL;
	}

	if (*ibuf) {
		kmem_free(*ibuf, (*aoeio)->aoeio_ilen);
		*ibuf = NULL;
	}

	kmem_free(*aoeio, sizeof (aoeio_t));
	return (ret);
}

static int
aoe_copyout_iocdata(intptr_t data, int mode, aoeio_t *aoeio, void *obuf)
{

	if (aoeio->aoeio_olen) {
		if (ddi_copyout(obuf,
		    (void *)(unsigned long)aoeio->aoeio_obuf,
		    aoeio->aoeio_olen, mode) != 0) {
			return (EFAULT);
		}
	}

	if (ddi_copyout(aoeio, (void *)data, sizeof (aoeio_t), mode) != 0) {
		return (EFAULT);
	}
	return (0);
}

static int
aoe_iocmd(aoe_soft_state_t *ss, intptr_t data, int mode)
{
	aoe_mac_t	*aoe_mac[AOE_MAX_MACOBJ];
	aoeio_t		*aoeio;
	int		i;
	int		j;
	int		ret = 0;
	void		*abuf = NULL;
	void		*ibuf = NULL;
	void		*obuf = NULL;

	ret = aoe_copyin_iocdata(data, mode, &aoeio, &ibuf, &abuf, &obuf);
	if (ret != 0)
		goto aoeiocmd_release_buf;

	/*
	 * If an exclusive open was demanded during open, ensure that
	 * only one thread can execute an ioctl at a time
	 */
	mutex_enter(&ss->ss_ioctl_mutex);
	if (ss->ss_ioctl_flags & AOE_IOCTL_FLAG_EXCL) {
		if (ss->ss_ioctl_flags & AOE_IOCTL_FLAG_EXCL_BUSY) {
			mutex_exit(&ss->ss_ioctl_mutex);
			aoeio->aoeio_status = AOEIOE_BUSY;
			ret = EBUSY;
			goto aoeiocmd_release_buf;
		}
		ss->ss_ioctl_flags |= AOE_IOCTL_FLAG_EXCL_BUSY;
	}
	mutex_exit(&ss->ss_ioctl_mutex);

	aoeio->aoeio_status = 0;

	switch (aoeio->aoeio_cmd) {
	case AOEIO_CREATE_PORT: {
		aoe_port_t *created_port = NULL;
		aoe_mac_t *created_mac[AOE_MAX_MACOBJ];
		aoe_mac_t *opened_mac[AOE_MAX_MACOBJ];
		int mac_used = 0, m = 0, n = 0;
		int is_port_created = 0;
		aoeio_create_port_param_t *param =
		    (aoeio_create_port_param_t *)ibuf;
		int portid = param->acp_port_id;

		if (aoeio->aoeio_ilen != sizeof (aoeio_create_port_param_t) ||
		    aoeio->aoeio_xfer != AOEIO_XFER_WRITE) {
			aoeio->aoeio_status = AOEIOE_INVAL_ARG;
			ret = EINVAL;
			break;
		}

		mutex_enter(&ss->ss_ioctl_mutex);

		if (aoe_lookup_port_by_id(portid) != NULL) {
			aoeio->aoeio_status = AOEIOE_ALREADY;
			ret = EINVAL;
			mutex_exit(&ss->ss_ioctl_mutex);
			break;
		}

		/*
		 * In case of error, we should destroy all the
		 * created macs and the created port.
		 */
		for (i = 0; i < AOE_MAX_MACOBJ; i++) {
			int linkid = param->acp_mac_linkid[i];
			aoe_mac_t *mac;

			/* last one */
			if (linkid == 0)
				break;

			aoe_mac[i] = NULL;
			mac = aoe_create_mac_by_id(portid, linkid,
			    &is_port_created);
			if (mac == NULL) {
				aoeio->aoeio_status = AOEIOE_CREATE_MAC;
				ret = EIO;
				goto error_1;
			}
			if (mac->am_port->p_mac_cnt == 1)
				created_port = mac->am_port;
			created_mac[m++] = mac;
			if (mac->am_use_cnt) {
				aoe_mac[i] = mac;
				continue;
			}
			for (j = i - 1; j >= 0; j--) {
				if (aoe_mac[j] == mac) {
					aoeio->aoeio_status = AOEIOE_ALREADY;
					ret = EINVAL;
					goto error_1;
				}
			}
			ret = aoe_open_mac(mac, param->acp_force_promisc);
			if (ret != 0) {
				ret = EIO;
				if (aoeio->aoeio_status == 0)
					aoeio->aoeio_status = AOEIOE_OPEN_MAC;
				goto error_1;
			}
			opened_mac[n++] = mac;
			aoe_mac[i] = mac;
		}

		ret = aoe_create_port(ss->ss_dip, aoe_mac[0]->am_port,
		    param->acp_port_type, param->acp_port_policy,
		    (*param->acp_module) ? param->acp_module : NULL);
		if (!ret)
			goto exit_1;
		aoeio->aoeio_status = AOEIOE_CREATE_PORT;
		ret = EIO;

error_1:
		for (i = 0; i < n; i++) {
			if (!opened_mac[i]->am_use_cnt)
				(void) aoe_close_mac(opened_mac[i]);
			else
				mac_used = 1;
		}
		for (i = 0; i < m; i++) {
			if (!created_mac[i]->am_use_cnt)
				aoe_destroy_mac(created_mac[i]);
			else
				mac_used = 1;
		}
		if (is_port_created) {
			if (!mac_used) {
				created_port = aoe_lookup_port_by_id(portid);
				aoe_destroy_port(created_port);
			} else {
				cmn_err(CE_WARN, "Cannot delete port after "
				    "failed port creation due to "
				    "a mac is in use!\n");
			}
		}
exit_1:
		mutex_exit(&ss->ss_ioctl_mutex);
		break;
	}

	case AOEIO_DELETE_PORT: {
		aoeio_delete_port_param_t *del_port_param =
		    (aoeio_delete_port_param_t *)ibuf;

		if (aoeio->aoeio_ilen < sizeof (aoeio_delete_port_param_t) ||
		    aoeio->aoeio_xfer != AOEIO_XFER_READ) {
			aoeio->aoeio_status = AOEIOE_INVAL_ARG;
			ret = EINVAL;
			break;
		}

		mutex_enter(&ss->ss_ioctl_mutex);
		ret = aoe_delete_port(ss->ss_dip, aoeio,
		    del_port_param->adp_port_id);
		mutex_exit(&ss->ss_ioctl_mutex);
		break;
	}

	case AOEIO_GET_PORT_LIST: {
		aoe_port_list_t *list = (aoe_port_list_t *)obuf;
		int count;

		if (aoeio->aoeio_xfer != AOEIO_XFER_READ ||
		    aoeio->aoeio_olen < sizeof (aoe_port_list_t)) {
			aoeio->aoeio_status = AOEIOE_INVAL_ARG;
			ret = EINVAL;
			break;
		}
		mutex_enter(&ss->ss_ioctl_mutex);

		list->num_ports = 1 + (aoeio->aoeio_olen -
		    sizeof (aoe_port_list_t))/sizeof (aoe_port_instance_t);

		count = aoe_get_port_list(list->ports, list->num_ports);

		if (count > list->num_ports) {
			aoeio->aoeio_status = AOEIOE_MORE_DATA;
			ret = ENOSPC;
		}
		list->num_ports = count;
		mutex_exit(&ss->ss_ioctl_mutex);

		break;

	}

	default:
		return (ENOTTY);
	}

aoeiocmd_release_buf:
	if (ret == 0) {
		ret = aoe_copyout_iocdata(data, mode, aoeio, obuf);
	} else if (aoeio->aoeio_status) {
		(void) aoe_copyout_iocdata(data, mode, aoeio, obuf);
	}

	if (obuf != NULL) {
		kmem_free(obuf, aoeio->aoeio_olen);
		obuf = NULL;
	}
	if (abuf != NULL) {
		kmem_free(abuf, aoeio->aoeio_alen);
		abuf = NULL;
	}

	if (ibuf != NULL) {
		kmem_free(ibuf, aoeio->aoeio_ilen);
		ibuf = NULL;
	}
	kmem_free(aoeio, sizeof (aoeio_t));

	return (ret);
}

static int
aoe_i_port_autoconf(uint32_t portid)
{
	aoeio_t iost;
	int ret, i;
	aoe_soft_state_t *ss = aoe_global_ss;
	aoe_mac_t *mac;
	uint32_t linkid = rootfs.bo_ppa;
	aoe_port_t *created_port = NULL;
	int is_port_created = 0;

	/*
	 * Automatically discover MAC interfaces with AoE targets on it
	 * One MAC per port will be created. Means that if you have
	 * multi-pathed AoE target setup, system will see two disks
	 */
	mutex_enter(&ss->ss_ioctl_mutex);
	mac = aoe_create_mac_by_id(portid, linkid, &is_port_created);
	if (mac == NULL) {
		cmn_err(CE_WARN, "Error while creating mac linkid=%d", linkid);
		if (is_port_created) {
			created_port = aoe_lookup_port_by_id(portid);
			aoe_destroy_port(created_port);
		}
		mutex_exit(&ss->ss_ioctl_mutex);
		return (0);
	}

	(void) strlcpy(mac->am_ifname, rootfs.bo_ifname,
	    sizeof (mac->am_ifname));

	ret = aoe_open_mac(mac, B_FALSE);
	if (ret != 0) {
		cmn_err(CE_WARN, "Error while opening mac linkid=%d", linkid);
		aoe_destroy_mac(mac);
		if (is_port_created) {
			created_port = aoe_lookup_port_by_id(portid);
			aoe_destroy_port(created_port);
		}
		mutex_exit(&ss->ss_ioctl_mutex);
		return (0);
	}

	ret = aoe_create_port(ss->ss_dip, mac->am_port,
	    AOE_CLIENT_INITIATOR, AOE_POLICY_FAILOVER, NULL);
	if (ret != 0) {
		cmn_err(CE_WARN, "Error while creating port linkid=%d", linkid);
		(void) aoe_close_mac(mac);
		aoe_destroy_mac(mac);
		if (is_port_created) {
			created_port = aoe_lookup_port_by_id(portid);
			aoe_destroy_port(created_port);
		}
		mutex_exit(&ss->ss_ioctl_mutex);
		return (0);
	}
	mutex_exit(&ss->ss_ioctl_mutex);

	/*
	 * We got that far means port in a good shape,
	 * lets poll for state change...
	 *
	 * Timeout is 30 seconds so that at least two attempts of periodic
	 * disk discovery would fit while brining up boot device...
	 */
	for (i = 0; i < 30; i++) {
		delay(100);
		if (mac->am_port->p_unit_cnt > 0) {
			cmn_err(CE_NOTE, "AoE autoconf: %d disks detected",
			    mac->am_port->p_unit_cnt);
			/*
			 * TODO: If boot-aoepath is set to "auto",
			 * configure first found AoE device. This is
			 * to be done in the future.
			 */
			if (aoepath_prop != NULL &&
			    strcmp(aoepath_prop, "auto") == 0)
				cmn_err(CE_PANIC, "FIXME autoconf bootpath");

			/* keep port open */
			return (1);
		}
	}

	mutex_enter(&ss->ss_ioctl_mutex);
	ret = aoe_delete_port(ss->ss_dip, &iost, portid);
	mutex_exit(&ss->ss_ioctl_mutex);

	return (0);
}

static int
aoe_attach(dev_info_t *dip, ddi_attach_cmd_t cmd)
{
	int ret;
	int instance;
	aoe_soft_state_t *ss;

	instance = ddi_get_instance(dip);
	switch (cmd) {
	case DDI_ATTACH:
		break;

	case DDI_RESUME:
	case DDI_PM_RESUME:
		dev_err(dip, CE_WARN, "resume not supported yet");
		ret = DDI_FAILURE;
		goto exit;

	default:
		dev_err(dip, CE_WARN, "cmd 0x%x not recognized", cmd);
		ret = DDI_FAILURE;
		goto exit;
	}

	ret = ddi_soft_state_zalloc(aoe_state, instance);
	if (ret != DDI_SUCCESS) {
		dev_err(dip, CE_WARN, "soft_state_zalloc-%x/%x", ret,
		    instance);
		goto exit;
	}

	ss = ddi_get_soft_state(aoe_state, instance);
	ss->ss_dip = dip;
	ss->ss_ioctl_flags = 0;
	mutex_init(&ss->ss_ioctl_mutex, NULL, MUTEX_DRIVER, NULL);
	list_create(&ss->ss_mac_list, sizeof (aoe_mac_t),
	    offsetof(aoe_mac_t, am_ss_node));
	list_create(&ss->ss_port_list, sizeof (aoe_port_t),
	    offsetof(aoe_port_t, p_ss_node));

	ret = ddi_create_minor_node(dip, "admin", S_IFCHR,
	    ddi_get_instance(dip), DDI_PSEUDO, 0);
	if (ret != DDI_SUCCESS) {
		dev_err(dip, CE_WARN, "ddi_create_minor_node failed");
		goto exit;
	}

	ASSERT(aoe_global_ss == NULL);
	aoe_global_ss = ss;

	if (ddi_prop_exists(DDI_DEV_T_ANY, ddi_root_node(),
	    DDI_PROP_DONTPASS, "boot-mac"))
		(void) aoe_i_port_autoconf(0);

	ddi_report_dev(dip);
	return (DDI_SUCCESS);

exit:
	return (ret);
}

static int
aoe_detach(dev_info_t *dip, ddi_detach_cmd_t cmd)
{
	aoe_soft_state_t	*ss;
	int			instance;

	instance = ddi_get_instance(dip);
	ss = ddi_get_soft_state(aoe_state, instance);
	if (ss == NULL)
		return (DDI_FAILURE);

	ASSERT(aoe_global_ss != NULL);
	ASSERT(dip == aoe_global_ss->ss_dip);

	switch (cmd) {
	case DDI_DETACH:
		break;
	case DDI_PM_SUSPEND:
		dev_err(dip, CE_WARN, "suspend not supported yet");
		return (DDI_FAILURE);
	default:
		dev_err(dip, CE_WARN, "cmd 0x%x unrecognized", cmd);
		return (DDI_FAILURE);
	}

	if (!list_is_empty(&ss->ss_mac_list)) {
		dev_err(dip, CE_WARN, "ss_mac_list is not empty when detach");
		return (DDI_FAILURE);
	}

	ddi_remove_minor_node(ss->ss_dip, NULL);
	mutex_destroy(&ss->ss_ioctl_mutex);
	list_destroy(&ss->ss_mac_list);
	list_destroy(&ss->ss_port_list);

	return (DDI_SUCCESS);
}

/*
 * Check if AoE port can be detached
 */
static uint32_t
aoe_allow_port_detach(aoe_eport_t *eport)
{
	aoe_port_t *port = EPORT2PORT(eport);

	return (port->p_flags & AOE_PORT_FLAG_BUSY);
}

int
_init(void)
{
	int	rv;

	rv = ddi_soft_state_init(&aoe_state, sizeof (aoe_soft_state_t), 0);
	if (rv != 0)
		return (rv);

	if ((rv = mod_install(&modlinkage)) != 0)
		ddi_soft_state_fini(&aoe_state);

	return (rv);
}

int
_fini(void)
{
	int	rv;

	if ((rv = mod_remove(&modlinkage)) == 0)
		ddi_soft_state_fini(&aoe_state);

	return (rv);
}

int
_info(struct modinfo *modinfop)
{

	return (mod_info(&modlinkage, modinfop));
}

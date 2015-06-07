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

#ifndef	_AOE_H_
#define	_AOE_H_

#include <sys/param.h>
#include <sys/types.h>
#include <sys/ethernet.h>

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * IOCTL supporting stuff
 */
#define	AOE_IOCTL_FLAG_MASK		0xFF
#define	AOE_IOCTL_FLAG_IDLE		0x00
#define	AOE_IOCTL_FLAG_OPEN		0x01
#define	AOE_IOCTL_FLAG_EXCL		0x02
#define	AOE_IOCTL_FLAG_EXCL_BUSY	0x04

/*
 * IOCTL cmd definitions
 */
#define	AOEIO_CMD			('G'<< 8 | 2009)
#define	AOEIO_SUB_CMD			('X' << 8)

/*
 * IOCTL sub-command
 */
#define	AOEIO_CREATE_PORT		(AOEIO_SUB_CMD + 0x01)
#define	AOEIO_DELETE_PORT		(AOEIO_SUB_CMD + 0x02)
#define	AOEIO_GET_PORT_LIST		(AOEIO_SUB_CMD + 0x03)

/*
 * aoeio_xfer definitions
 */
#define	AOEIO_XFER_NONE		0x00
#define	AOEIO_XFER_READ		0x01
#define	AOEIO_XFER_WRITE	0x02
#define	AOEIO_XFER_RW		(AOEIO_XFER_READ | AOEIO_XFER_WRITE)

/*
 * aoeio_errno definitions
 */
typedef enum {
	AOEIOE_INVAL_ARG = 5,
	AOEIOE_BUSY,
	AOEIOE_ALREADY,
	AOEIOE_CREATE_MAC,
	AOEIOE_OPEN_MAC,
	AOEIOE_CREATE_PORT,
	AOEIOE_MAC_NOT_FOUND,
	AOEIOE_OFFLINE_FAILURE,
	AOEIOE_MORE_DATA
} aoeio_stat_t;

/* Biggest buffer length, can hold up to 1024 port instances */
#define	AOEIO_MAX_BUF_LEN	0x10000
#define	AOE_MAX_MACOBJ		16  /* MAX # of ethernet interfaces per port */
#define	AOE_MAX_UNIT		256 /* MAX # of LU per target/port */

typedef struct aoeio {
	uint16_t	aoeio_xfer;		/* direction */
	uint16_t	aoeio_cmd;		/* sub command */
	uint16_t	aoeio_flags;		/* flags */
	uint16_t	aoeio_cmd_flags;	/* command specific flags */
	uint32_t	aoeio_ilen;		/* Input buffer length */
	uint32_t	aoeio_olen;		/* Output buffer length */
	uint32_t	aoeio_alen;		/* Auxillary buffer length */
	aoeio_stat_t	aoeio_status;		/* AoE internal error status */
	uint64_t	aoeio_ibuf;		/* Input buffer */
	uint64_t	aoeio_obuf;		/* Output buffer */
	uint64_t	aoeio_abuf;		/* Auxillary buffer */
} aoeio_t;

/*
 * Client port type
 */
typedef enum {
	AOE_CLIENT_INITIATOR = 0,
	AOE_CLIENT_TARGET
} aoe_cli_type_t;

/*
 * Client port policy
 */
typedef enum {
	AOE_POLICY_NONE = 0,
	AOE_POLICY_FAILOVER,
	AOE_POLICY_ROUNDROBIN,
	AOE_POLICY_LOADBALANCE
} aoe_cli_policy_t;

#define	AOE_ACP_MODLEN	MAXNAMELEN

/*
 * AOE port commands
 */
typedef struct aoeio_create_port_param {
	uint32_t		acp_port_id;
	uint32_t		acp_force_promisc;
	aoe_cli_type_t		acp_port_type;
	aoe_cli_policy_t	acp_port_policy;
	datalink_id_t		acp_mac_linkid[AOE_MAX_MACOBJ];
	uint32_t		acp_rsvd0;
	char			acp_module[AOE_ACP_MODLEN];
} aoeio_create_port_param_t;

typedef struct aoeio_delete_port_param {
	uint32_t	adp_port_id;
	uint32_t	adp_rsvd0;
} aoeio_delete_port_param_t;

/*
 * AOE MAC instance
 */
typedef struct aoe_mac_instance {
	datalink_id_t		ami_mac_linkid;
	uint32_t		ami_rsvd0;
	ether_addr_t		ami_mac_factory_addr;
	uint16_t		ami_mac_promisc;
	ether_addr_t		ami_mac_current_addr;
	uint16_t		ami_rsvd1;
	uint32_t		ami_mtu_size;
	uint32_t		ami_mac_link_state;
	uint64_t		ami_mac_rx_frames;
	uint64_t		ami_mac_tx_frames;
} aoe_mac_instance_t;

/*
 * AOE port instance
 */
typedef struct aoe_port_instance {
	uint32_t		api_port_id;
	uint32_t		api_mac_cnt;
	uint32_t		api_port_state;
	uint32_t		api_maxxfer;
	aoe_cli_type_t		api_port_type;
	aoe_cli_policy_t	api_port_policy;
	aoe_mac_instance_t	api_mac[AOE_MAX_MACOBJ];
} aoe_port_instance_t;

/*
 * AOE port instance list
 */
typedef struct aoe_port_list {
	uint64_t		num_ports;
	aoe_port_instance_t	ports[1];
} aoe_port_list_t;

#define	AOE_PORT_STATE_OFFLINE		0x00
#define	AOE_PORT_STATE_ONLINE		0x01

#define	AOE_MAC_LINK_STATE_DOWN		0x00
#define	AOE_MAC_LINK_STATE_UP		0x01

#ifdef	_KERNEL

#define	AOET_DRIVER_NAME	"aoet"
#define	AOEI_DRIVER_NAME	"aoeblk"

#define	AOECMD_ATA	0	/* Issue ATA Command */
#define	AOECMD_CFG	1	/* Query Config Information */
#define	AOECMD_MML	2	/* Mac Mask List */
#define	AOECMD_RSV	3	/* Reserve / Release */

#define	AOEFL_RSP		(1<<3)
#define	AOEFL_ERR		(1<<2)

#define	AOEAFL_EXT		(1<<6)
#define	AOEAFL_DEV		(1<<4)
#define	AOEAFL_ASYNC		(1<<1)
#define	AOEAFL_WRITE		(1<<0)

#define	AOE_HVER		0x10

#define	ETHERTYPE_AOE		0x88A2  /* ATA over Ethernet */

#define	MINPERMAJ		10
#define	AOEMAJOR(unit)		((unit) / MINPERMAJ)
#define	AOEMINOR(unit)		((unit) % MINPERMAJ)
#define	AOEUNIT(maj, min)	((maj) * MINPERMAJ + (min))

typedef struct aoe_hdr {
	ether_addr_t	aoeh_dst;
	ether_addr_t	aoeh_src;
	uint16_t	aoeh_type;
	uint8_t		aoeh_verfl;
	uint8_t		aoeh_err;
	uint16_t	aoeh_major;
	uint8_t		aoeh_minor;
	uint8_t		aoeh_cmd;
	uint32_t	aoeh_tag;
} aoe_hdr_t;

typedef struct aoe_atahdr {
	uint8_t	aa_aflags;
	uint8_t	aa_errfeat;
	uint8_t	aa_scnt;
	uint8_t	aa_cmdstat;
	uint8_t	aa_lba0;
	uint8_t	aa_lba1;
	uint8_t	aa_lba2;
	uint8_t	aa_lba3;
	uint8_t	aa_lba4;
	uint8_t	aa_lba5;
	uint8_t	aa_res[2];
} aoe_atahdr_t;

/* ATA commands */
#define	ATA_READ		0x20	/* read */
#define	ATA_READ48		0x24	/* read 48bit LBA */
#define	ATA_WRITE		0x30	/* write */
#define	ATA_WRITE48		0x34	/* write 48bit LBA */
#define	ATA_FLUSHCACHE		0xe7	/* flush cache to disk */
#define	ATA_FLUSHCACHE48	0xea	/* flush cache to disk */
#define	ATA_SETFEATURES		0xef	/* features command */
#define	ATA_SF_ENAB_WCACHE	0x02	/* enable write cache */
#define	ATA_SF_DIS_WCACHE	0x82	/* disable write cache */
#define	ATA_ATA_IDENTIFY	0xec	/* get ATA params */
#define	ATA_CHECK_POWER_MODE	0xe5	/* Check power mode */

typedef struct aoe_cfghdr {
	uint16_t	ac_bufcnt;	/* Buffer Count */
	uint16_t	ac_fwver;	/* Firmware Version */
	uint8_t		ac_scnt;	/* Sector Count */
	uint8_t		ac_aoeccmd;	/* AoE Ver + CCmd */
	uint8_t		ac_cslen[2];	/* Config String Length */
} aoe_cfghdr_t;

#define	AOEHDRSZ	(sizeof (aoe_hdr_t) + sizeof (aoe_atahdr_t))
#define	FREETAG		-1	/* tag magic; denotes free frame */
#define	INPROCTAG	-2	/* tag magic; denotes frame in processing */

/* Definitions of CCmd of Query Config Information */
#define	AOE_CFGCMD_READ		0
#define	AOE_CFGCMD_TEST_EXACT	1
#define	AOE_CFGCMD_TEST_PREFIX	2
#define	AOE_CFGCMD_SET		3
#define	AOE_CFGCMD_FORCE_SET	4

typedef struct aoe_rsvhdr {
	uint8_t		al_rcmd;
	uint8_t		al_nmacs;
	ether_addr_t	al_addr[];
} aoe_rsvhdr_t;

#define	AOE_RCMD_READ_LIST		0
#define	AOE_RCMD_SET_LIST		1
#define	AOE_RCMD_FORCE_SET_LIST		2

/*
 * aoe_frame_t - structure which encapsulates one or more mblk_t. To add
 *               mblk HBA driver could use eport_alloc_netb() or manually
 *               via f->frm_netb field
 */
struct aoe_eport;
typedef struct aoe_frame {
	void		 *af_netb;	/* Pointer to the mblk_t */
	struct aoe_eport *af_eport;	/* Port object */
	void		 *af_mac;	/* Library's private MAC object */
	uint8_t		 *af_data;	/* Typically netb->b_rptr */
	ether_addr_t	 af_addr;	/* Destination address */
	uint16_t	 af_rsvd0;
} aoe_frame_t;

#define	FRM2MBLK(x_frm)		((mblk_t *)(x_frm)->af_netb)
#define	FRM2PRIV(x_frm)		((void *)(((aoe_frame_t *)(x_frm))+1))
#define	PRIV2FRM(x_frm)		((void *)(((aoe_frame_t *)(x_frm))-1))

/*
 * aoe_eport_t - main interface for HBA driver
 *
 * eport_maxxfer: calculated based on MTU sizes as a minimal size in group
 * eport_mac: array of MAC objects of all MAC interfaces in the group
 * eport_mac_cnt: number of active MAC interfaces in the group
 *
 * eport_tx_fram():          Tansmit frame to the wire
 * eport_alloc_frame():      Allocate new frame out of Library kmem cache.
 *                           Typically mac and netb can be set to NULL
 * eport_release_frame():    release used frame (both solicited and unsolicited)
 * eport_alloc_netb():       Allocate extra buffer and link with frame
 * eport_free_netb():        Free f->frm_netb
 * eport_deregister_client() Unregister HBA driver
 * eport_ctl():		     Used to send notifications on port ONLINE/OFFLINE
 * eport_report_unit():	     Used to report new unit
 * eport_get_mac_addr():     Used to get MAC object etherent address
 * eport_get_mac_link_state(): Used to get MAC object link state
 * eport_allow_port_detach():Returns nonzero if detaching port is not allowed
 */
typedef struct aoe_eport {
	void		*eport_aoe_private;	/* Library internal */
	void		*eport_client_private;	/* HBA internal */
	uint32_t	eport_maxxfer;		/* Calculate max xfer size */
	void		**eport_mac;		/* Array of MAC objects */
	uint32_t	eport_mac_cnt;		/* Number of MAC objects */
	uint32_t	cache_unit_size;

	void		(*eport_tx_frame)(aoe_frame_t *frame);
	aoe_frame_t	*(*eport_alloc_frame)(struct aoe_eport *eport,
				int unit_id, void *mac, int kmflag);
	void		(*eport_release_frame)(aoe_frame_t *frame);
	void		*(*eport_alloc_netb)(aoe_frame_t *frame,
				uint32_t buf_size, caddr_t buf, int kmflag);
	void		(*eport_free_netb)(void *netb);
	void		(*eport_deregister_client)(struct aoe_eport *eport);
	int		(*eport_ctl)(struct aoe_eport *eport, void *mac,
				int cmd, void *arg);
	int		(*eport_report_unit)(struct aoe_eport *eport, void *mac,
				unsigned long unit, char *);
	uint8_t		*(*eport_get_mac_addr)(void *mac);
	int		(*eport_get_mac_link_state)(void *mac);
	uint32_t	(*eport_allow_port_detach)(struct aoe_eport *eport);
} aoe_eport_t;

/*
 * aoe_client_t - passed to Library via aoe_register_client()
 *
 * ect_eport_flags: EPORT_FLAG_TGT_MODE | EPORT_FLAG_INI_MODE
 * ect_private_frame_struct_size: private HBA driver per-frame
 * ect_channelid: set to port_id via NDI property to distinguish HBA ports
 * ect_client_port_struct: pointer to HBA private
 *
 * ect_rx_frame():	Callback on MAC receive event. Frame will be allocated
 *                      and ready to be released by HBA. HBA needs to call
 *                      eport_release_frame(). To get ETHERNET source HBA
 *                      needs to copy it from frm_hdr like this
 *                      bcopy(h->ah_src, d->ad_addr, sizeof (ether_addr_t)
 *                      where h is a pointer to frm_hdr casted to aoe_hdr
 *
 * ect_port_event():    Callback for Library events such as
 *                      AOE_NOTIFY_EPORT_LINK_UP | AOE_NOTIFY_EPORT_LINK_DOWN
 */
typedef struct aoe_client {
	uint32_t	 ect_eport_flags;
	uint32_t	 ect_private_frame_struct_size;
	uint32_t	 ect_channelid;
	void		*ect_client_port_struct;
	void		 (*ect_rx_frame)(aoe_frame_t *frame);
	void		 (*ect_port_event)(aoe_eport_t *eport, uint32_t event);
} aoe_client_t;

#define	EPORT_FLAG_TGT_MODE		0x01
#define	EPORT_FLAG_INI_MODE		0x02
#define	EPORT_FLAG_MAC_IN_USE		0x04

#define	AOE_NOTIFY_EPORT_LINK_UP	0x01
#define	AOE_NOTIFY_EPORT_LINK_DOWN	0x02
#define	AOE_NOTIFY_EPORT_ADDR_CHG	0x03

#define	AOE_PORT_CTL_CMDS		0x3000
#define	AOE_CMD_PORT_ONLINE		(AOE_PORT_CTL_CMDS | 0x01)
#define	AOE_CMD_PORT_OFFLINE		(AOE_PORT_CTL_CMDS | 0x02)
#define	AOE_CMD_PORT_UNIT_ONLINE	(AOE_PORT_CTL_CMDS | 0x04)
#define	AOE_CMD_PORT_UNIT_OFFLINE	(AOE_PORT_CTL_CMDS | 0x08)
#define	AOE_CMD_PORT_UNIT_RETRANSMIT	(AOE_PORT_CTL_CMDS | 0x10)

/*
 * AOE Target/Initiator will only call this aoe function explicitly, all others
 * should be called through vectors in struct aoe_eport.
 * AOE client call this to register one port to AOE, AOE need initialize
 * and return the corresponding aoe_port.
 */
extern aoe_eport_t *aoe_register_client(aoe_client_t *client);

#endif	/* _KERNEL */

#ifdef	__cplusplus
}
#endif

#endif	/* _AOE_H_ */

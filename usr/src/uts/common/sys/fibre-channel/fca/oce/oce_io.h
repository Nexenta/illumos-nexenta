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
 * Copyright (c) 2009-2012 Emulex. All rights reserved.
 * Use is subject to license terms.
 */



/*
 * Header file defining the HW IO elements
 */

#ifndef _OCE_IO_H_
#define	_OCE_IO_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/types.h>
#include <sys/dditypes.h>
#include <sys/mutex.h>
#include <sys/stream.h>
#include <sys/debug.h>
#include <sys/byteorder.h>
#include <oce_hw.h>
#include <oce_buf.h>

#define	DEFAULT_MQ_MBOX_TIMEOUT	(5 * 1000 * 1000) /* 5 sec (in usec) */
#define	MBX_READY_TIMEOUT	(1 * 1000 * 1000) /* 1 sec (in usec) */
#define	DEFAULT_DRAIN_TIME 	200	/* Default Drain Time */
#define	MBX_TIMEOUT_SEC		5
#define	STAT_TIMEOUT		2000000 /* update stats every 2 sec */
#define	OCE_HDR_LEN		64

struct oce_dev;

enum eq_len {
	EQ_LEN_256 = 256,
	EQ_LEN_512 = 512,
	EQ_LEN_1024 = 1024,
	EQ_LEN_2048 = 2048,
	EQ_LEN_4096 = 4096
};

enum eqe_size {
	EQE_SIZE_4 = 4,
	EQE_SIZE_16 = 16
};

enum qtype {
	QTYPE_EQ,
	QTYPE_MQ,
	QTYPE_WQ,
	QTYPE_RQ,
	QTYPE_CQ,
	QTYPE_RSS
};

typedef enum qstate_e {
	QDELETED = 0x0,
	QCREATED,
	QSTARTED,
	QSTOPPED,
	QFINI,
	QFINI_PENDING
}qstate_t;

enum mb_mode_e {
	MBX_BOOTSTRAP = 0x00,	/* issue a command on the bootstrap mbox */
	MBX_ASYNC_MQ  = 0x01	/* issue command thru MCC */
};

/* Driver special codes */

#define	MBX_SUCCESS				0x00
#define	MBX_FAILURE				0x01
#define	MBX_COMPLETED				0x02
#define	MBX_QUEUE_FULL				0xF8
#define	MBX_BUSY				0xFD
#define	MBX_TIMEOUT				0xFE

struct oce_eq {
	/* id assigned by the hw to this eq */
	uint32_t eq_id;
	/* handle to the creating parent dev */
	void *parent;
	/* ring buffer for this eq */
	oce_ring_buffer_t *ring;
	/* reference count of this structure */
	uint32_t ref_count;
	/* vector index */
	uint32_t idx;
	uint32_t qstate;
	kmutex_t lock;
};

enum cq_len {
	CQ_LEN_256 = 256,
	CQ_LEN_512 = 512,
	CQ_LEN_1024 = 1024,
	CQ_LEN_2048 = 2048
};

struct cq_config {
	/* length of queue */
	enum cq_len q_len;
};

typedef void * (*cq_handler_t)(void *arg1, int arg2, int arg3);

struct oce_cq {
	/* id given by the hardware */
	uint32_t    cq_id;
	/* parent device to which this cq belongs */
	void *parent;
	/* event queue associated with this cq */
	struct oce_eq *eq;
	cq_handler_t cq_handler;
	/* placeholder for callback context */
	void *cb_arg;
	/* ring buffer for this cq */
	oce_ring_buffer_t *ring;
	/* Queue state */
	qstate_t qstate;
	/* configuration of this cq */
	struct cq_config cq_cfg;
	/* reference count of this structure */
	uint32_t ref_count;
};

struct mq_config {
	uint32_t eqd;
	uint8_t q_len;
	uint8_t pad[3];

};

struct oce_mq {
	/* lock for the mq */
	kmutex_t lock;
	/* handle to the parent device */
	void *parent;
	/* send queue */
	oce_ring_buffer_t *ring;
	/* idnetifier for the mq */
	uint32_t mq_id;
	struct oce_cq *cq;
	struct oce_cq *async_cq;
	/* free entries in Queue */
	uint32_t mq_free;
	/* Queue state */
	qstate_t qstate;

	/* configuration of this mq */
	struct mq_config cfg;
};


/*
 * utility structure that handles context of mbx
 */
struct oce_mbx_ctx {
	/* pointer to mbx */
	struct oce_mbx *mbx;
	kmutex_t cv_lock;
	kcondvar_t cond_var;
	/* call back functioin [optional] */
	void (*cb)(void *ctx);
	/* call back context [optional] */
	void *cb_ctx;
	uint32_t mbx_status;
	struct oce_mbx *mqe; /* pointer to mq entry */
	uint32_t compl_status; /* mgmt status | addl status */
};

#define	OCE_MODE_POLL B_FALSE
#define	OCE_MODE_INTR B_TRUE

struct wq_config {
	/* qtype */
	uint8_t wq_type;
	uint16_t buf_size;
	uint8_t pad[1];
	uint32_t q_len; /* number of wqes */
	uint16_t pd_id; /* protection domain id */
	uint16_t pci_fn_num; /* pci function number */
	uint32_t eqd;	/* interrupt delay */
	uint32_t nbufs; /* copy buffers */
	uint32_t nhdl; /* preallocated memory handles */
};

struct oce_wq {
	kmutex_t tx_lock; /* lock for the WQ */
	kmutex_t txc_lock; /* tx compl lock */
	void *parent; /* parent of this wq */
	mac_ring_handle_t handle; /* ring handle used by crossbow framework */

	oce_ring_buffer_t *ring; /* ring buffer managing the wqes */
	struct oce_cq *cq; 	/* cq associated with this wq */
	kmem_cache_t *wqed_cache; /* packet desc cache */
	oce_wq_bdesc_t *wq_bdesc_array; /* buffer desc array */
	uint32_t wqb_free; /* Wqb free */
	uint32_t wqbd_next_free; /* Next availble wqbd index */
	uint32_t wqbd_rc_head; /* wqbd recycle head */
	kmutex_t wqb_alloc_lock; /* wqbd lock in allocation path */
	kmutex_t wqb_free_lock; /* wqbd lock in recycle path */
	oce_wq_bdesc_t **wqb_freelist; /* Free wqbds */
	list_t wqe_desc_list; /* packet descriptor list */
	kmutex_t wqed_list_lock; /* wqed list lock */
	uint32_t wqe_pending; /* Wqe pending */
	oce_wq_mdesc_t *wq_mdesc_array; /* preallocated memory handles */
	uint32_t wqm_free; /* Wqm free */
	uint32_t wqmd_next_free; /* Next free wqmd slot */
	uint32_t wqmd_rc_head; /* wqmd recycle head */
	kmutex_t wqm_alloc_lock; /* Lock for wqm alloc path */
	kmutex_t wqm_free_lock; /* Lock for wqm free path */
	oce_wq_mdesc_t **wqm_freelist; /* Free wqmds */
	uint32_t wqm_used; /* memory handles uses */
	oce_dma_buf_t wqb; /* Tx Copy buffer dma memory */
	boolean_t resched; /* used for mac_tx_update */
	uint32_t wq_free; /* Wqe free */

	uint32_t tx_deferd; /* Wqe free */
	uint32_t pkt_drops; /* drops */

	int64_t last_compl;
	int64_t last_armed;
	int64_t last_intr;
	int64_t last_defered;

	uint64_t stat_bytes;
	uint64_t stat_pkts;

	/* Queue state */
	qstate_t qstate;
	uint_t qmode; /* poll or interrupt mode */
	uint16_t wq_id; /* wq ID */
    struct wq_config cfg; /* q config */
};

struct rq_config {
	uint32_t q_len; /* q length */
	uint32_t frag_size; /* fragment size. Send log2(size) in commmand */
	uint32_t mtu; /* max frame size for this RQ */
	uint32_t if_id; /* interface ID to associate this RQ with */
	uint32_t is_rss_queue; /* is this RQ an RSS queue? */
	uint32_t eqd;  /* interrupt delay */
	uint32_t nbufs; /* Total data buffers */
};

struct rq_shadow_entry {
	oce_rq_bdesc_t *rqbd;
};

struct oce_rq {

	kmutex_t rx_lock;
	kmutex_t rq_fini_lock;
	mac_ring_handle_t handle; /* ring handle used by framework */
	uint64_t gen_number; /* used by framework */
	boolean_t qmode;
	uint64_t stat_bytes;
	uint64_t stat_pkts;

	/* RQ config */
	struct rq_config cfg;

	/* ring buffer managing the RQEs */
	oce_ring_buffer_t *ring;
	/* cq associated with this queue */
	struct oce_cq *cq;
	oce_rq_bdesc_t  *rq_bdesc_array;
	/* shadow list of mblk for rq ring */
	oce_rq_bdesc_t **shadow_ring;
	oce_rq_bdesc_t  **rqb_freelist;
	oce_dma_buf_t rqb; /* data buffer for the rq's */
	uint32_t rqb_free;
	uint32_t rqb_next_free; /* next free slot */
	uint32_t rqb_rc_head; /* recycling  head */
	uint32_t buf_avail; /* buffer avaialable with hw */
	uint32_t pending; /* Buffers sent up */
	/* rq lock */
	kmutex_t rc_lock;

	/* parent of this rq */
	void *parent;
	/* RQ id */
	uint32_t rq_id;
	/* CPU ID assigend to this RQ if it is an RSS queue */
	uint32_t rss_cpuid;
	/* Queue state */
	uint32_t qstate;
	void *grp;		/* group it belongs to */
};

struct link_status {
	/* dw 0 */
	uint8_t physical_port;
	uint8_t mac_duplex;
	uint8_t mac_speed;
	uint8_t mac_fault;
	/* dw 1 */
	uint8_t mgmt_mac_duplex;
	uint8_t mgmt_mac_speed;
	uint16_t qos_link_speed;
	/* dw2 */
	uint32_t logical_link_status;
};

int oce_alloc_dma_buffer(struct oce_dev *dev, oce_dma_buf_t *dbuf,
    uint32_t size, ddi_dma_attr_t *dma_attr, uint32_t flags);
void oce_free_dma_buffer(struct oce_dev *dev, oce_dma_buf_t *dbuf);

oce_ring_buffer_t *oce_create_ring_buffer(struct oce_dev *dev,
    uint32_t num_items, uint32_t item_size,
    uint32_t flags);
void destroy_ring_buffer(struct oce_dev *dev, oce_ring_buffer_t *ring);

/* Queues */
int oce_set_eq_delay(struct oce_dev *dev, uint32_t *eq_arr,
    uint32_t eq_cnt, uint32_t eq_delay, uint32_t mode);
void oce_arm_eq(struct oce_dev *dev, int16_t qid, int npopped,
    boolean_t rearm, boolean_t clearint);
void oce_arm_cq(struct oce_dev *dev, int16_t qid, int npopped,
    boolean_t rearm);
void oce_drain_eq(struct oce_eq *eq);


/* Bootstrap */
int oce_mbox_init(struct oce_dev *dev);
int oce_mbox_fini(struct oce_dev *dev);
int oce_mbox_dispatch(struct  oce_dev *dev, uint32_t tmo_sec);
int oce_mbox_wait(struct  oce_dev *dev, uint32_t tmo_sec);
int oce_issue_mbox_passthru(struct oce_dev *dev, queue_t *wq, mblk_t *mp,
    uint32_t *rsp_len);
int oce_issue_mbox_cmd(struct oce_dev *dev, struct oce_mbx *mbx,
    uint32_t tmo_sec, uint32_t flag);

/* Hardware */
boolean_t oce_is_reset_pci(struct oce_dev *dev);
int oce_pci_soft_reset(struct oce_dev *dev);
int oce_POST(struct oce_dev *dev);
int oce_pci_init(struct oce_dev *dev);
void oce_pci_fini(struct oce_dev *dev);
int oce_init_tx(struct oce_dev *dev);
void oce_fini_tx(struct oce_dev *dev);
int oce_create_queues(struct oce_dev *dev);
int oce_create_mcc_queue(struct oce_dev *dev);
void oce_delete_queues(struct oce_dev *dev);
void oce_delete_mcc_queue(struct oce_dev *dev);
int oce_reset_fun(struct oce_dev *dev);

/* Transmit */
void *oce_drain_wq_cq(void *arg, int arg2, int arg3);
mblk_t *oce_send_packet(struct oce_wq *wq, mblk_t *mp);
int oce_start_wq(struct oce_wq *wq);
void oce_clean_wq(struct oce_wq *wq);

/* Recieve */
void * oce_drain_rq_cq(void *arg, int arg2, int arg3);
int oce_start_rq(struct oce_rq *rq);
void oce_clean_rq(struct oce_rq *rq);
void oce_rq_discharge(struct oce_rq *rq);
int oce_rx_pending(struct oce_dev *dev, struct oce_rq *rq, int32_t timeout);
void oce_rq_fini(struct oce_dev *dev, struct oce_rq *rq);

/* Mailbox */
void * oce_drain_mq_cq(void *arg, int arg2, int arg3);
int oce_issue_mq_mbox(struct  oce_dev *dev, struct  oce_mbx *mbx);
struct oce_mbx *oce_mq_get_mbx(struct oce_dev *dev);
void oce_clean_mq(struct oce_mq *mq);
int oce_start_mq(struct oce_mq *mq);

/* mbx helper functions */
void mbx_common_req_hdr_init(struct mbx_hdr *hdr, uint8_t dom,
    uint8_t port, uint8_t subsys, uint8_t opcode,
    uint32_t timeout, uint32_t pyld_len, uint8_t version);
void mbx_nic_req_hdr_init(struct mbx_hdr *hdr, uint8_t dom, uint8_t port,
    uint8_t opcode, uint32_t timeout, uint32_t pyld_len);
int oce_get_fw_version(struct oce_dev *dev, uint32_t mode);
int oce_read_mac_addr(struct oce_dev *dev, uint32_t if_id, uint8_t perm,
    uint8_t type, struct mac_address_format *mac, uint32_t mode);
int oce_if_create(struct oce_dev *dev, uint32_t cap_flags, uint32_t en_flags,
    uint16_t vlan_tag, uint8_t *mac_addr, uint32_t *if_id, uint32_t mode);
int oce_if_del(struct oce_dev *dev, uint32_t if_id, uint32_t mode);

int oce_get_link_status(struct oce_dev *dev, link_state_t *link_status,
    int32_t *link_speed, uint8_t *link_duplex, uint8_t cmd_ver, uint32_t mode);
int oce_set_rx_filter(struct oce_dev *dev,
    struct mbx_set_common_ntwk_rx_filter *filter, uint32_t mode);
int oce_set_multicast_table(struct oce_dev *dev, uint32_t if_id,
    struct ether_addr *mca_table, uint16_t mca_cnt, boolean_t promisc,
    uint32_t mode);
int oce_get_fw_config(struct oce_dev *dev, uint32_t mode);
int oce_get_hw_stats(struct oce_dev *dev, uint32_t mode);
int oce_get_pport_stats(struct oce_dev *dev, uint32_t mode);
int oce_set_flow_control(struct oce_dev *dev, uint32_t flow_control,
    uint32_t mode);
int oce_get_flow_control(struct oce_dev *dev, uint32_t *flow_control,
    uint32_t mode);
int oce_set_promiscuous(struct oce_dev *dev, boolean_t enable, uint32_t mode);
int oce_add_mac(struct oce_dev *dev, uint32_t if_id,
			const uint8_t *mac, uint32_t *pmac_id, uint32_t mode);
int oce_del_mac(struct oce_dev *dev, uint32_t if_id, uint32_t *pmac_id,
    uint32_t mode);
int oce_config_vlan(struct oce_dev *dev, uint32_t if_id,
    struct normal_vlan *vtag_arr,
    uint8_t vtag_cnt,  boolean_t untagged,
    boolean_t enable_promisc, uint32_t mode);
int oce_config_link(struct oce_dev *dev, boolean_t enable, uint32_t mode);
int oce_config_rss(struct oce_dev *dev, uint16_t if_id, char *hkey, char *itbl,
    int  tbl_sz, uint16_t rss_type, uint8_t flush, uint32_t mode);
int oce_issue_mbox(struct oce_dev *dev, queue_t *wq, mblk_t *mp,
    uint32_t *payload_length);
#ifdef __cplusplus
}
#endif

#endif /* _OCE_IO_H_ */

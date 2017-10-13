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
 * Copyright 2017 Nexenta Systems, Inc. All rights reserved.
 */

#ifndef	_LIBKRRP_H_
#define	_LIBKRRP_H_

#include <sys/types.h>
#include <sys/nvpair.h>
#include <uuid/uuid.h>
#include <sys/krrp.h>
#include <netdb.h>
#include <errno.h>

#ifdef	__cplusplus
extern "C" {
#endif

typedef char libkrrp_error_descr_t[1024];

typedef struct {
	char address[MAXHOSTNAMELEN];
	uint16_t port;
} libkrrp_srv_config_t;

typedef struct {
	boolean_t enabled;
	boolean_t running;
} libkrrp_svc_state_t;

typedef unsigned long krrp_sess_stream_flags_t;

#define	KRRP_STREAM_ZFS_EMBEDDED	0x0001
#define	KRRP_STREAM_ZFS_CHKSUM		0x0002
#define	KRRP_STREAM_INCLUDE_ALL_SNAPS	0x0004
#define	KRRP_STREAM_SEND_RECURSIVE	0x0008
#define	KRRP_STREAM_SEND_PROPERTIES	0x0010
#define	KRRP_STREAM_FORCE_RECEIVE	0x0020
#define	KRRP_STREAM_DISCARD_HEAD	0x0040
#define	KRRP_STREAM_LEAVE_TAIL		0x0080
#define	KRRP_STREAM_ZFS_COMPRESSED	0x0100
#define	KRRP_STREAM_ZFS_LARGE_BLOCKS	0x0200

typedef struct libkrrp_handle_s libkrrp_handle_t;
typedef struct libkrrp_evc_handle_s libkrrp_evc_handle_t;
typedef struct libkrrp_event_s libkrrp_event_t;

#define	LIBKRRP_ERRF_REMOTE 0x1
#define	LIBKRRP_ERRF_KERNEL 0x80000000

#define	KRNKRRP_ERRNO_MAP(X)     \
	X(INTR)                  \
	X(INVAL)                 \
	X(BUSY)                  \
	X(NOMEM)                 \
	X(SESS)                  \
	X(CONN)                  \
	X(PDUENGINE)             \
	X(STREAM)                \
	X(SESSID)                \
	X(KSTATID)               \
	X(ADDR)                  \
	X(PORT)                  \
	X(DBLKSZ)                \
	X(MAXMEMSZ)              \
	X(FAKEDSZ)               \
	X(SRCDS)                 \
	X(DSTDS)                 \
	X(CMNSNAP)               \
	X(SRCSNAP)               \
	X(BADRESP)               \
	X(BIGPAYLOAD)            \
	X(UNEXPCLOSE)            \
	X(UNEXPEND)              \
	X(ZFSGCTXFAIL)           \
	X(CREATEFAIL)            \
	X(BINDFAIL)              \
	X(LISTENFAIL)            \
	X(CONNFAIL)              \
	X(ACCEPTFAIL)            \
	X(SENDFAIL)              \
	X(SENDMBLKFAIL)          \
	X(RECVFAIL)              \
	X(READFAIL)              \
	X(WRITEFAIL)             \
	X(FLCTRLVIOL)            \
	X(PINGTIMEOUT)           \
	X(SETSOCKOPTFAIL)        \
	X(PROTO)                 \
	X(AUTH)                  \
	X(CFGTYPE)               \
	X(SNAPFAIL)              \
	X(CONNTIMEOUT)           \
	X(THROTTLE)              \
	X(AUTOSNAP)              \
	X(RESUMETOKEN)           \
	X(KEEPSNAPS)             \
	X(SKIP_SNAPS_MASK)       \

#define	LIBKRRP_ERRNO_MAP(X)     \
	X(IOCTLFAIL)             \
	X(NOTSUP)                \
	X(IOCTLDATAFAIL)         \
	X(SVCACTIVE)             \
	X(SVCNOTACTIVE)          \
	X(EVBINDFAIL)            \
	X(EVSUBSRIBEFAIL)        \
	X(EVREADFAIL)            \
	X(SESSERR)               \
	X(PROPS)                 \

#define	LIBKRRP_ERRNO_EXPAND(enum_name) LIBKRRP_ERRNO_##enum_name,
typedef enum {
	LIBKRRP_ERRNO_OK = 0,
	LIBKRRP_ERRNO_UNKNOWN = 1000,
	KRNKRRP_ERRNO_MAP(LIBKRRP_ERRNO_EXPAND)
	LIBKRRP_ERRNO_RESERVED = 2000,
	LIBKRRP_ERRNO_MAP(LIBKRRP_ERRNO_EXPAND)
	LIBKRRP_ERRNO_LAST
} libkrrp_errno_t;
#undef	LIBKRRP_ERRNO_EXPAND

typedef enum {
	LIBKRRP_SESS_TYPE_SENDER,
	LIBKRRP_SESS_TYPE_RECEIVER,
	LIBKRRP_SESS_TYPE_COMPOUND
} libkrrp_sess_type_t;

typedef struct libkrrp_error_s {
	libkrrp_errno_t libkrrp_errno;
	int unix_errno;
	uint32_t flags;
} libkrrp_error_t;

typedef struct libkrrp_sess_list_s {
	uuid_t sess_id;
	char *sess_kstat_id;
	boolean_t sess_started;
	boolean_t sess_running;
	struct libkrrp_sess_list_s *sl_next;
} libkrrp_sess_list_t;

#define	LIBKRRP_EV_TYPE_MAP(X)    \
	X(SESS_SEND_DONE)         \
	X(SESS_ERROR)             \
	X(SERVER_ERROR)           \

#define	LIBKRRP_EV_TYPE_EXPAND(enum_name) LIBKRRP_EV_TYPE_##enum_name,
typedef enum {
	LIBKRRP_EV_TYPE_UNKNOWN,
	LIBKRRP_EV_TYPE_MAP(LIBKRRP_EV_TYPE_EXPAND)
	LIBKRRP_EV_TYPE_LAST
} libkrrp_ev_type_t;
#undef	LIBKRRP_EV_TYPE_EXPAND

typedef struct libkrrp_ev_sess_send_done_data_s {
	uuid_t sess_id;
} libkrrp_ev_sess_send_done_data_t;

typedef struct libkrrp_ev_sess_error_data_s {
	uuid_t sess_id;
	libkrrp_error_t libkrrp_error;
} libkrrp_ev_sess_error_data_t;

typedef union {
	libkrrp_ev_sess_send_done_data_t sess_send_done;
	libkrrp_ev_sess_error_data_t sess_error;
	libkrrp_error_t server_error;
} libkrrp_ev_data_t;

typedef struct libkrrp_sess_status_s {
	uuid_t sess_id;
	libkrrp_sess_type_t sess_type;
	boolean_t sess_running;
	boolean_t sess_started;
	char sess_kstat_id[KRRP_KSTAT_ID_STRING_LENGTH];
	libkrrp_error_t libkrrp_error;
} libkrrp_sess_status_t;

typedef struct libkrrp_sess_conn_info_s {
	uint32_t blk_sz;
} libkrrp_sess_conn_info_t;

boolean_t is_krrp_supported(void);

libkrrp_handle_t *libkrrp_init(void);
void libkrrp_fini(libkrrp_handle_t *);

int krrp_set_srv_config(libkrrp_handle_t *, const char *, const uint16_t);
int krrp_get_srv_config(libkrrp_handle_t *, libkrrp_srv_config_t *);

int krrp_sess_create_sender(libkrrp_handle_t *, uuid_t, const char *,
    const char *, boolean_t);
int krrp_sess_create_receiver(libkrrp_handle_t *, uuid_t, const char *,
    const char *, boolean_t);
int krrp_sess_create_compound(libkrrp_handle_t *, uuid_t, const char *,
    boolean_t);

int krrp_sess_destroy(libkrrp_handle_t *, uuid_t);

int krrp_sess_set_private_data(libkrrp_handle_t *hdl, uuid_t sess_id,
    nvlist_t *private_data);
int krrp_sess_get_private_data(libkrrp_handle_t *hdl, uuid_t sess_id,
    nvlist_t **private_data);

int krrp_sess_create_conn(libkrrp_handle_t *, uuid_t, const char *,
    const uint16_t, const uint32_t);
int krrp_sess_conn_throttle(libkrrp_handle_t *, uuid_t, const uint32_t);
int krrp_sess_create_pdu_engine(libkrrp_handle_t *, uuid_t, const int,
    const int, boolean_t);

int krrp_sess_create_read_stream(libkrrp_handle_t *, uuid_t, const char *,
    const char *, const char *, uint64_t, krrp_sess_stream_flags_t,
    const char *, uint32_t, const char *);
int krrp_sess_create_write_stream(libkrrp_handle_t *, uuid_t, const char *,
    const char *, krrp_sess_stream_flags_t, nvlist_t *ignore_props,
    nvlist_t *replace_props, const char *, uint32_t);

int krrp_sess_run(libkrrp_handle_t *, uuid_t, boolean_t);
int krrp_sess_send_stop(libkrrp_handle_t *, uuid_t);

int krrp_sess_list(libkrrp_handle_t *, libkrrp_sess_list_t **);
void krrp_sess_list_free(libkrrp_sess_list_t *);

int krrp_sess_get_conn_info(libkrrp_handle_t *hdl, uuid_t sess_id,
    libkrrp_sess_conn_info_t *sess_conn_info);

int krrp_sess_status(libkrrp_handle_t *, uuid_t, libkrrp_sess_status_t *);
void libkrrp_sess_error_description(libkrrp_error_t *, libkrrp_error_descr_t);

int krrp_svc_enable(libkrrp_handle_t *);
int krrp_svc_disable(libkrrp_handle_t *);
int krrp_svc_state(libkrrp_handle_t *, libkrrp_svc_state_t *);

const libkrrp_error_t *libkrrp_error(libkrrp_handle_t *);
const char *libkrrp_error_description(libkrrp_handle_t *);

int libkrrp_evc_subscribe(libkrrp_evc_handle_t **,
    int(*)(libkrrp_event_t *, void *), void *);
void libkrrp_evc_unsubscribe(libkrrp_evc_handle_t *);
libkrrp_error_t *libkrrp_evc_error(libkrrp_evc_handle_t *);
const char *libkrrp_evc_error_description(libkrrp_evc_handle_t *);

libkrrp_event_t *libkrrp_ev_dup(libkrrp_event_t *);
libkrrp_ev_type_t libkrrp_ev_type(libkrrp_event_t *);
libkrrp_ev_data_t *libkrrp_ev_data(libkrrp_event_t *);
libkrrp_error_t *libkrrp_ev_error(libkrrp_event_t *);
const char *libkrrp_ev_error_description(libkrrp_event_t *);
void libkrrp_ev_data_error_description(libkrrp_ev_type_t, libkrrp_error_t *,
    libkrrp_error_descr_t);
void libkrrp_ev_free(libkrrp_event_t *);

#ifdef	__cplusplus
}
#endif

#endif	/* _LIBKRRP_H_ */

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

#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>
#include <stropts.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/debug.h>
#include <inttypes.h>
#include <ctype.h>
#include <umem.h>
#include <libnvpair.h>
#include <uuid/uuid.h>

#include <libsysevent.h>
#include <sys/sysevent/krrp.h>

#include <assert.h>

#include <sys/krrp.h>
#include <libkrrp.h>


#define	KRRP_CMD_MAP(X) \
	X(read-event, krrp_do_read_event, \
	    krrp_usage_event, READ_EVENT) \
	X(sess-list, krrp_do_sess_list, \
	    krrp_usage_sess, SESS_LIST) \
	X(sess-create, krrp_do_sess_create, \
	    krrp_usage_sess, SESS_CREATE) \
	X(sess-destroy, krrp_do_sess_action, \
	    krrp_usage_sess, SESS_DESTROY) \
	X(sess-run, krrp_do_sess_action, \
	    krrp_usage_sess, SESS_RUN) \
	X(sess-send-stop, krrp_do_sess_action, \
	    krrp_usage_sess, SESS_SEND_STOP) \
	X(sess-status, krrp_do_sess_status, \
	    krrp_usage_sess, SESS_STATUS) \
	X(sess-create-conn, krrp_do_sess_create_conn, \
	    krrp_usage_sess, SESS_CREATE_CONN) \
	X(sess-create-read-stream, krrp_do_sess_create_read_stream, \
	    krrp_usage_sess, SESS_CREATE_READ_STREAM) \
	X(sess-create-write-stream, krrp_do_sess_create_write_stream, \
	    krrp_usage_sess, SESS_CREATE_WRITE_STREAM) \
	X(sess-create-pdu-engine, krrp_do_sess_create_pdu_engine, \
	    krrp_usage_sess, SESS_CREATE_PDU_ENGINE) \
	X(sess-conn-throttle, krrp_do_sess_action, \
	    krrp_usage_sess, SESS_CONN_THROTTLE) \
	X(sess-get-conn-info, krrp_do_sess_get_conn_info, \
	    krrp_usage_sess, SESS_GET_CONN_INFO) \
	X(ksvc-enable, krrp_do_ksvc_action, \
	    krrp_usage_ksvc, KSVC_ENABLE) \
	X(ksvc-disable, krrp_do_ksvc_action, \
	    krrp_usage_ksvc, KSVC_DISABLE) \
	X(ksvc-state, krrp_do_svc_get_state, \
	    krrp_usage_ksvc, KSVC_STATE) \
	X(ksvc-configure, krrp_do_ksvc_configure, \
	    krrp_usage_ksvc, KSVC_CONFIGURE) \

typedef enum {
#define	KRRP_CMD_EXPAND(cmd_name, action_func, usage_func, enum_name) \
    KRRP_CMD_##enum_name,
	KRRP_CMD_MAP(KRRP_CMD_EXPAND)
#undef KRRP_CMD_EXPAND
	KRRP_CMD_LAST
} krrp_cmd_item_t;

typedef struct krrp_cmd_s krrp_cmd_t;

typedef void (krrp_usage_func)(int, krrp_cmd_t *, boolean_t);
typedef int (krrp_handler_func)(int argc, char **argv, krrp_cmd_t *);

struct krrp_cmd_s {
	const char			*name;
	krrp_handler_func	*handler_func;
	krrp_usage_func		*usage_func;
	krrp_cmd_item_t		item;
};

static void common_usage(int);
static int krrp_lookup_cmd(const char *, krrp_cmd_t **);

static krrp_usage_func krrp_usage_ksvc, krrp_usage_sess, krrp_usage_event;

static krrp_handler_func krrp_do_ksvc_action, krrp_do_ksvc_configure,
    krrp_do_sess_list, krrp_do_sess_action, krrp_do_sess_create_conn,
    krrp_do_sess_create_read_stream, krrp_do_sess_create_write_stream,
    krrp_do_sess_create_pdu_engine, krrp_do_sess_status, krrp_do_read_event,
    krrp_do_svc_get_state, krrp_do_sess_create, krrp_do_sess_get_conn_info;

static int krrp_parse_and_check_sess_id(char *sess_id_str,
    uuid_t sess_id);

static int krrp_sysevent_cb(libkrrp_event_t *ev, void *cookie);
static void krrp_print_err_already_defined(const char *param);
static void krrp_print_err_unknown_param(const char *param);
static void krrp_print_err_no_sess_id(void);
static void krrp_print_libkrrp_error(void);

static void fprintf_err(const char *fmt, ...);
static void fprintf_msg(const char *fmt, ...);

static krrp_cmd_t cmds[] = {
#define	KRRP_CMD_EXPAND(cmd_name, action_func, usage_func, enum_name) \
	{#cmd_name, action_func, usage_func, KRRP_CMD_##enum_name},
	KRRP_CMD_MAP(KRRP_CMD_EXPAND)
#undef KRRP_CMD_EXPAND
};
static size_t cmds_sz = sizeof (cmds) / sizeof (cmds[0]);

const char *tool_name;
libkrrp_handle_t *libkrrp_hdl = NULL;

int
main(int argc, char **argv)
{
	int rc = 0;
	krrp_cmd_t *cmd;

	opterr = 0;

	tool_name = argv[0];

	if (argc < 2) {
		fprintf_err("missing command\n\n\n");
		common_usage(1);
	}

	rc = krrp_lookup_cmd(argv[1], &cmd);
	if (rc != 0) {
		fprintf_err("unknown command\n");
		common_usage(1);
	}

	libkrrp_hdl = libkrrp_init();
	if (libkrrp_hdl == NULL) {
		fprintf_err("Failed to init libkrrp\n");
		exit(1);
	}

	rc = cmd->handler_func(argc - 1, argv + 1, cmd);

	return (rc);
}

static void
common_usage(int rc)
{
	size_t i;

	for (i = 0; i < cmds_sz; i++)
		cmds[i].usage_func(0, &cmds[i], B_TRUE);

	exit(rc);
}

static void
krrp_usage_event(int rc, krrp_cmd_t *cmd, boolean_t use_return)
{
	assert(cmd->item == KRRP_CMD_READ_EVENT);

	fprintf_msg("Usage: %s read-event\n\n\n", tool_name);

	if (use_return)
		return;

	exit(rc);
}

static void
krrp_usage_ksvc(int rc, krrp_cmd_t *cmd, boolean_t use_return)
{
	switch (cmd->item) {
	case KRRP_CMD_KSVC_ENABLE:
		fprintf_msg("Usage: %s ksvc-enable\n", tool_name);
		break;
	case KRRP_CMD_KSVC_DISABLE:
		fprintf_msg("Usage: %s ksvc-disable\n", tool_name);
		break;
	case KRRP_CMD_KSVC_STATE:
		fprintf_msg("Usage: %s ksvc-state\n", tool_name);
		break;
	case KRRP_CMD_KSVC_CONFIGURE:
		fprintf_msg("Usage: %s ksvc-configure "
		    "<-p listning port>\n", tool_name);
		break;
	default:
		assert(0);
	}

	fprintf_msg("\n\n");

	if (use_return)
		return;

	exit(rc);
}

static void
krrp_usage_sess(int rc, krrp_cmd_t *cmd, boolean_t use_return)
{
	switch (cmd->item) {
	case KRRP_CMD_SESS_LIST:
		fprintf_msg("Usage: %s sess-list\n", tool_name);
		break;
	case KRRP_CMD_SESS_CREATE:
		fprintf_msg("Usage: %s sess-create -s <sess_id> "
		    "<-k kstat_id (16 symbols)> "
		    "[-a <auth digest (max 255 symbols)>] "
		    "[-z] [-f] [-c]\n", tool_name);
		break;
	case KRRP_CMD_SESS_DESTROY:
		fprintf_msg("Usage: %s sess-destroy "
		    "-s <sess_id>\n", tool_name);
		break;
	case KRRP_CMD_SESS_STATUS:
		fprintf_msg("Usage: %s sess-status "
		    "-s <sess_id>\n", tool_name);
		break;
	case KRRP_CMD_SESS_RUN:
		fprintf_msg("Usage: %s sess-run "
		    "-s <sess_id>\n", tool_name);
		break;
	case KRRP_CMD_SESS_SEND_STOP:
		fprintf_msg("Usage: %s sess-send-stop "
		    "-s <sess_id>\n", tool_name);
		break;
	case KRRP_CMD_SESS_CREATE_CONN:
		fprintf_msg("Usage: %s sess-create-conn "
		    "-s <sess_id> -a <remote IP> -p <remote port> "
		    "-t <timeout>\n", tool_name);
		break;
	case KRRP_CMD_SESS_CONN_THROTTLE:
		fprintf_msg("Usage: %s sess-conn-throttle "
		    "-s <sess_id> -l <limit>\n",
		    tool_name);
		break;
	case KRRP_CMD_SESS_GET_CONN_INFO:
		fprintf_msg("Usage: %s sess-get-conn-info "
		    "-s <sess_id>\n", tool_name);
		break;
	case KRRP_CMD_SESS_CREATE_READ_STREAM:
		fprintf_msg("Usage: %s sess-create-read-stream "
		    "-s <sess_id> -d <src dataset> [-z <src snapshot>] "
		    "[-c <common snapshot>] [-I] [-r] [-p] [-e] [-k] "
		    "[-j] [-b] [-f <fake_data_sz>] [-t <resume_token>] "
		    "[-n <keep snaps>] [-m <user_prop_name>=<val>]\n",
		    tool_name);
		break;
	case KRRP_CMD_SESS_CREATE_WRITE_STREAM:
		fprintf_msg("Usage: %s sess-create-write-stream "
		    "-s <sess_id> -d <dst dataset> [-c <common snapshot>] "
		    "[-F] [-k] [-l | -x] [-i <prop_name>] "
		    "[-o <prop_name=value>] [-t <resume_token>] "
		    "[-n <keep snaps>]\n", tool_name);
		break;
	case KRRP_CMD_SESS_CREATE_PDU_ENGINE:
		fprintf_msg("Usage: %s sess-create-pdu-engine "
		    "-s <sess_id> -b <data block size> [-a] "
		    "-m <max memory in MB>\n", tool_name);
		break;
	default:
		assert(0);
	}

	fprintf_msg("\n\n");

	if (use_return)
		return;

	exit(rc);
}

static int
krrp_lookup_cmd(const char *cmd_name, krrp_cmd_t **cmd)
{
	size_t i;
	int rc = -1;

	for (i = 0; i < cmds_sz; i++) {
		if (strcmp(cmds[i].name, cmd_name) == 0) {
			*cmd = &cmds[i];
			rc = 0;
			break;
		}
	}

	return (rc);
}

/* ARGSUSED */
static int
krrp_do_read_event(int argc, char **argv, krrp_cmd_t *cmd)
{
	int rc;
	libkrrp_evc_handle_t *libkrrp_evc_hdl = NULL;


	rc = libkrrp_evc_subscribe(&libkrrp_evc_hdl, krrp_sysevent_cb, NULL);
	if (rc != 0) {
		fprintf_err("Failed to subscribe to KRRP events\n");
		exit(1);
	}

	for (;;)
		(void) sleep(1);

	/* NOTREACHED */
	return (0);
}

/* ARGSUSED */
static int
krrp_sysevent_cb(libkrrp_event_t *ev, void *cookie)
{
	libkrrp_ev_type_t ev_type;
	libkrrp_ev_data_t *ev_data;
	char sess_id_str[UUID_PRINTABLE_STRING_LENGTH];
	libkrrp_error_descr_t err_desc;

	ev_type = libkrrp_ev_type(ev);
	ev_data = libkrrp_ev_data(ev);

	switch (ev_type) {
	case LIBKRRP_EV_TYPE_SESS_SEND_DONE:
		uuid_unparse(ev_data->sess_send_done.sess_id, sess_id_str);
		fprintf_msg("Session '%s' has done send\n", sess_id_str);
		break;
	case LIBKRRP_EV_TYPE_SESS_ERROR:
		uuid_unparse(ev_data->sess_error.sess_id, sess_id_str);
		libkrrp_ev_data_error_description(ev_type,
		    &ev_data->sess_error.libkrrp_error, err_desc);
		fprintf_msg("Session '%s' has interrupted by error:\n"
		    "    %s\n", sess_id_str, err_desc);
		break;
	case LIBKRRP_EV_TYPE_SERVER_ERROR:
		libkrrp_ev_data_error_description(ev_type,
		    &ev_data->sess_error.libkrrp_error, err_desc);
		fprintf_msg("An error occured in kernel-server:\n"
		    "    %s\n", err_desc);
		break;
	default:
		fprintf_err("Unknow event type\n");
		assert(0);
	}

	return (0);
}

static int
krrp_do_sess_create(int argc, char **argv, krrp_cmd_t *cmd)
{
	int c, rc = 0;
	uuid_t sess_id;
	boolean_t sender = B_FALSE, compound = B_FALSE,
	    fake_mode = B_FALSE;
	char *auth_digest = NULL, *kstat_id = NULL;

	assert(cmd->item == KRRP_CMD_SESS_CREATE);

	uuid_clear(sess_id);

	while ((c = getopt(argc, argv, "hs:zfck:a:")) != -1) {
		switch (c) {
		case 's':
			if (krrp_parse_and_check_sess_id(optarg, sess_id) != 0)
				exit(1);

			break;
		case 'a':
			if (auth_digest != NULL) {
				krrp_print_err_already_defined("a");
				exit(1);
			}

			auth_digest = optarg;
			break;
		case 'k':
			if (kstat_id != NULL) {
				krrp_print_err_already_defined("k");
				exit(1);
			}

			kstat_id = optarg;
			break;
		case 'z':
			if (sender) {
				krrp_print_err_already_defined("z");
				exit(1);
			}

			sender = B_TRUE;
			break;
		case 'f':
			if (fake_mode) {
				krrp_print_err_already_defined("f");
				exit(1);
			}

			fake_mode = B_TRUE;
			break;
		case 'c':
			if (compound) {
				krrp_print_err_already_defined("c");
				exit(1);
			}

			compound = B_TRUE;
			break;
		case '?':
			krrp_print_err_unknown_param(argv[optind - 1]);
			cmd->usage_func(1, cmd, B_FALSE);
			break;
		case 'h':
			cmd->usage_func(0, cmd, B_FALSE);
			break;
		}
	}

	if (uuid_is_null(sess_id) == 1) {
		krrp_print_err_no_sess_id();
		cmd->usage_func(1, cmd, B_FALSE);
	}

	if (kstat_id == NULL) {
		fprintf_err("Session Kstat ID is not defined\n");
		cmd->usage_func(1, cmd, B_FALSE);
	}

	if (sender && compound) {
		fprintf_err("'c' and 'z' parameters cannot "
		    "be used together\n");
		exit(1);
	}

	if (compound) {
		rc = krrp_sess_create_compound(libkrrp_hdl, sess_id,
		    kstat_id, fake_mode);
	} else if (sender) {
		rc = krrp_sess_create_sender(libkrrp_hdl, sess_id,
		    kstat_id, auth_digest, fake_mode);
	} else {
		rc = krrp_sess_create_receiver(libkrrp_hdl, sess_id,
		    kstat_id, auth_digest, fake_mode);
	}

	if (rc != 0) {
		fprintf_err("Failed to create session\n");
		krrp_print_libkrrp_error();
		exit(1);
	}

	return (0);
}

static int
krrp_do_sess_action(int argc, char **argv, krrp_cmd_t *cmd)
{
	int c, rc = 0;
	uuid_t sess_id;
	uint32_t limit = UINT32_MAX;
	boolean_t run_once = B_FALSE;
	const char *opts = "hs:";

	uuid_clear(sess_id);

	switch (cmd->item) {
	case KRRP_CMD_SESS_RUN:
		opts = "hs:o";
		break;
	case KRRP_CMD_SESS_CONN_THROTTLE:
		opts = "hs:l:";
		break;
	case KRRP_CMD_SESS_SEND_STOP:
		break;
	case KRRP_CMD_SESS_DESTROY:
		break;
	default:
		fprintf_err("Unknown cmd_item: [%d]\n", cmd->item);
		assert(0);
	}

	while ((c = getopt(argc, argv, opts)) != -1) {
		switch (c) {
		case 's':
			if (krrp_parse_and_check_sess_id(optarg, sess_id) != 0)
				exit(1);

			break;
		case 'l':
			if (limit != UINT32_MAX) {
				krrp_print_err_already_defined("l");
				exit(1);
			}

			limit = strtoul(optarg, NULL, 0);
			if (limit < KRRP_MIN_CONN_THROTTLE && limit != 0) {
				fprintf_err("Limit must be 0 or > %d\n",
				    KRRP_MIN_CONN_THROTTLE);
				exit(1);
			}

			break;
		case 'o':
			if (run_once) {
				krrp_print_err_already_defined("o");
				exit(1);
			}

			run_once = B_TRUE;
			break;
		case '?':
			krrp_print_err_unknown_param(argv[optind - 1]);
			cmd->usage_func(1, cmd, B_FALSE);
			break;
		case 'h':
			cmd->usage_func(0, cmd, B_FALSE);
			break;
		}
	}

	if (uuid_is_null(sess_id) == 1) {
		krrp_print_err_no_sess_id();
		cmd->usage_func(1, cmd, B_FALSE);
	}

	switch (cmd->item) {
	case KRRP_CMD_SESS_RUN:
		rc = krrp_sess_run(libkrrp_hdl, sess_id, run_once);
		if (rc != 0)
			fprintf_err("Failed to run session\n");

		break;
	case KRRP_CMD_SESS_CONN_THROTTLE:
		if (limit == UINT32_MAX) {
			fprintf_err("The throughput limit is not defined\n");
			cmd->usage_func(1, cmd, B_FALSE);
		}

		rc = krrp_sess_conn_throttle(libkrrp_hdl, sess_id, limit);
		if (rc != 0) {
			fprintf_err("Failed to throttle "
			    "session's connection\n");
		}

		break;
	case KRRP_CMD_SESS_SEND_STOP:
		rc = krrp_sess_send_stop(libkrrp_hdl, sess_id);
		if (rc != 0)
			fprintf_err("Failed to stop sending\n");

		break;
	case KRRP_CMD_SESS_DESTROY:
		rc = krrp_sess_destroy(libkrrp_hdl, sess_id);
		if (rc != 0)
			fprintf_err("Failed to destroy session\n");

		break;
	default:
		break;
	}

	if (rc != 0) {
		krrp_print_libkrrp_error();
		exit(1);
	}

	return (0);
}

static int
krrp_do_sess_get_conn_info(int argc, char **argv, krrp_cmd_t *cmd)
{
	int c, rc = 0;
	uuid_t sess_id;
	libkrrp_sess_conn_info_t sess_conn_info;
	char *sess_id_str = NULL;

	assert(cmd->item == KRRP_CMD_SESS_GET_CONN_INFO);

	uuid_clear(sess_id);

	while ((c = getopt(argc, argv, "hs:")) != -1) {
		switch (c) {
		case 's':
			if (krrp_parse_and_check_sess_id(optarg, sess_id) != 0)
				exit(1);

			sess_id_str = optarg;
			break;
		case '?':
			krrp_print_err_unknown_param(argv[optind - 1]);
			cmd->usage_func(1, cmd, B_FALSE);
			break;
		case 'h':
			cmd->usage_func(0, cmd, B_FALSE);
			break;
		}
	}

	if (uuid_is_null(sess_id) == 1) {
		krrp_print_err_no_sess_id();
		cmd->usage_func(1, cmd, B_FALSE);
	}

	rc = krrp_sess_get_conn_info(libkrrp_hdl, sess_id, &sess_conn_info);
	if (rc != 0) {
		fprintf_err("Failed to get information about connection\n");
		krrp_print_libkrrp_error();
		exit(1);
	}

	fprintf_msg("Session: [%s]\n"
	    "    block size: %u\n",
	    sess_id_str,
	    sess_conn_info.blk_sz);

	fprintf_msg("\n");

	return (0);
}

static int
krrp_do_sess_status(int argc, char **argv, krrp_cmd_t *cmd)
{
	int c, rc = 0;
	uuid_t sess_id;
	libkrrp_sess_status_t sess_status;
	libkrrp_error_descr_t err_desc;
	char *sess_id_str = NULL;

	assert(cmd->item == KRRP_CMD_SESS_STATUS);

	uuid_clear(sess_id);

	while ((c = getopt(argc, argv, "hs:")) != -1) {
		switch (c) {
		case 's':
			if (krrp_parse_and_check_sess_id(optarg, sess_id) != 0)
				exit(1);

			sess_id_str = optarg;
			break;
		case '?':
			krrp_print_err_unknown_param(argv[optind - 1]);
			cmd->usage_func(1, cmd, B_FALSE);
			break;
		case 'h':
			cmd->usage_func(0, cmd, B_FALSE);
			break;
		}
	}

	if (uuid_is_null(sess_id) == 1) {
		krrp_print_err_no_sess_id();
		cmd->usage_func(1, cmd, B_FALSE);
	}

	rc = krrp_sess_status(libkrrp_hdl, sess_id, &sess_status);
	if (rc != 0) {
		fprintf_err("Failed to get session status\n");
		krrp_print_libkrrp_error();
		exit(1);
	}

	fprintf_msg("Session: [%s]\n"
	    "    kstat ID: %s\n"
	    "    type: %s\n"
	    "    started: %s\n"
	    "    running: %s\n",
	    sess_id_str,
	    sess_status.sess_kstat_id,
	    sess_status.sess_type == LIBKRRP_SESS_TYPE_SENDER ? "sender" :
	    sess_status.sess_type == LIBKRRP_SESS_TYPE_RECEIVER ? "receiver" :
	    "compound",
	    sess_status.sess_started ? "YES" : "NO",
	    sess_status.sess_running ? "YES" : "NO",
	    err_desc);

	if (sess_status.libkrrp_error.libkrrp_errno != LIBKRRP_ERRNO_OK) {
		libkrrp_sess_error_description(&sess_status.libkrrp_error,
		    err_desc);

		fprintf_msg("    error: %s\n", err_desc);
	}

	fprintf_msg("\n");

	return (0);
}

static int
krrp_do_sess_list(int argc, char **argv, krrp_cmd_t *cmd)
{
	int c, rc = 0;
	libkrrp_sess_list_t *sess_list = NULL, *sess_list_head = NULL;

	while ((c = getopt(argc, argv, "h")) != -1) {
		switch (c) {
		case '?':
			krrp_print_err_unknown_param(argv[optind - 1]);
			cmd->usage_func(1, cmd, B_FALSE);
			break;
		case 'h':
			cmd->usage_func(0, cmd, B_FALSE);
			break;
		}
	}

	rc = krrp_sess_list(libkrrp_hdl, &sess_list_head);
	if (rc != 0) {
		fprintf_err("Failed to get list of sessions\n");
		krrp_print_libkrrp_error();
		exit(1);
	}

	sess_list = sess_list_head;
	while (sess_list != NULL) {
		char sess_id_str[UUID_PRINTABLE_STRING_LENGTH];

		uuid_unparse(sess_list->sess_id, sess_id_str);

		fprintf_msg("Session: [%s]\n"
		    "    kstat ID: %s\n"
		    "    started: %s\n"
		    "    running: %s\n\n",
		    sess_id_str,
		    sess_list->sess_kstat_id,
		    sess_list->sess_started ? "YES" : "NO",
		    sess_list->sess_running ? "YES" : "NO");

		sess_list = sess_list->sl_next;
	}

	krrp_sess_list_free(sess_list_head);
	return (0);
}

static int
krrp_do_sess_create_conn(int argc, char **argv, krrp_cmd_t *cmd)
{
	int c, i, rc = 0;
	uuid_t sess_id;
	const char *remote_addr = NULL;
	uint16_t remote_port = 0;
	uint32_t timeout = 0;

	uuid_clear(sess_id);

	while ((c = getopt(argc, argv, "hs:a:p:t:")) != -1) {
		switch (c) {
		case 's':
			if (krrp_parse_and_check_sess_id(optarg, sess_id) != 0)
				exit(1);

			break;
		case 'a':
			if (remote_addr != NULL) {
				krrp_print_err_already_defined("a");
				exit(1);
			}

			remote_addr = optarg;
			break;
		case 'p':
			if (remote_port != 0) {
				krrp_print_err_already_defined("p");
				exit(1);
			}

			i = strtol(optarg, NULL, 0);
			if (i < KRRP_MIN_PORT || i > KRRP_MAX_PORT) {
				fprintf_err("Port number must be an "
				    "integer in range from %d to %d\n",
				    KRRP_MIN_PORT, KRRP_MAX_PORT);
				exit(1);
			}

			remote_port = i;
			break;
		case 't':
			if (timeout != 0) {
				krrp_print_err_already_defined("t");
				exit(1);
			}

			i = strtol(optarg, NULL, 0);
			if (i < KRRP_MIN_CONN_TIMEOUT ||
			    i > KRRP_MAX_CONN_TIMEOUT) {
				fprintf_err("Connection timeout "
				    "must be an integer in range from "
				    "%d to %d\n", KRRP_MIN_CONN_TIMEOUT,
				    KRRP_MAX_CONN_TIMEOUT);
				exit(1);
			}

			timeout = i;
			break;
		case '?':
			krrp_print_err_unknown_param(argv[optind - 1]);
			cmd->usage_func(1, cmd, B_FALSE);
			break;
		case 'h':
			cmd->usage_func(0, cmd, B_FALSE);
			break;
		}
	}

	if (uuid_is_null(sess_id) == 1) {
		krrp_print_err_no_sess_id();
		cmd->usage_func(1, cmd, B_FALSE);
	}

	if (remote_addr == NULL) {
		fprintf_err("Remote host is not defined\n");
		cmd->usage_func(1, cmd, B_FALSE);
	}

	if (remote_port == 0) {
		fprintf_err("Remote port is not defined\n");
		cmd->usage_func(1, cmd, B_FALSE);
	}

	rc = krrp_sess_create_conn(libkrrp_hdl, sess_id,
	    remote_addr, remote_port, timeout);
	if (rc != 0) {
		fprintf_err("Failed to create connection\n");
		krrp_print_libkrrp_error();
		exit(1);
	}

	return (0);
}

static int
krrp_do_sess_create_read_stream(int argc, char **argv, krrp_cmd_t *cmd)
{
	int c, i, rc = 0;
	uuid_t sess_id;
	uint64_t fake_data_sz = 0;
	char *dataset = NULL, *common_snap = NULL, *src_snap = NULL,
	    *resume_token = NULL, *skip_snaps_mask = NULL;
	krrp_sess_stream_flags_t flags = 0;
	uint32_t keep_snaps = 0;

	uuid_clear(sess_id);

	while ((c = getopt(argc, argv, "hs:d:c:z:Irpejbkf:t:n:m:")) != -1) {
		switch (c) {
		case 's':
			if (krrp_parse_and_check_sess_id(optarg, sess_id) != 0)
				exit(1);

			break;
		case 'd':
			if (dataset != NULL) {
				krrp_print_err_already_defined("d");
				exit(1);
			}

			dataset = optarg;
			break;
		case 'z':
			if (src_snap != NULL) {
				krrp_print_err_already_defined("z");
				exit(1);
			}

			src_snap = optarg;
			break;
		case 'c':
			if (common_snap != NULL) {
				krrp_print_err_already_defined("c");
				exit(1);
			}

			common_snap = optarg;
			break;
		case 'I':
			if ((flags & KRRP_STREAM_INCLUDE_ALL_SNAPS) != 0) {
				krrp_print_err_already_defined("I");
				exit(1);
			}

			flags |= KRRP_STREAM_INCLUDE_ALL_SNAPS;
			break;
		case 'r':
			if ((flags & KRRP_STREAM_SEND_RECURSIVE) != 0) {
				krrp_print_err_already_defined("r");
				exit(1);
			}

			flags |= KRRP_STREAM_SEND_RECURSIVE;
			break;
		case 'p':
			if ((flags & KRRP_STREAM_SEND_PROPERTIES) != 0) {
				krrp_print_err_already_defined("p");
				exit(1);
			}

			flags |= KRRP_STREAM_SEND_PROPERTIES;
			break;
		case 'e':
			if ((flags & KRRP_STREAM_ZFS_EMBEDDED) != 0) {
				krrp_print_err_already_defined("e");
				exit(1);
			}

			flags |= KRRP_STREAM_ZFS_EMBEDDED;
			break;
		case 'j':
			if ((flags & KRRP_STREAM_ZFS_COMPRESSED) != 0) {
				krrp_print_err_already_defined("j");
				exit(1);
			}

			flags |= KRRP_STREAM_ZFS_COMPRESSED;
			break;
		case 'b':
			if ((flags & KRRP_STREAM_ZFS_LARGE_BLOCKS) != 0) {
				krrp_print_err_already_defined("b");
				exit(1);
			}

			flags |= KRRP_STREAM_ZFS_LARGE_BLOCKS;
			break;
		case 'k':
			if ((flags & KRRP_STREAM_ZFS_CHKSUM) != 0) {
				krrp_print_err_already_defined("k");
				exit(1);
			}

			flags |= KRRP_STREAM_ZFS_CHKSUM;
			break;
		case 'f':
			if (fake_data_sz != 0) {
				krrp_print_err_already_defined("f");
				exit(1);
			}

			fake_data_sz = strtoull(optarg, NULL, 0);
			if (fake_data_sz == 0) {
				fprintf_err("Fake data size must >0\n");
				exit(1);
			}

			break;
		case 't':
			if (resume_token != NULL) {
				krrp_print_err_already_defined("t");
				exit(1);
			}

			resume_token = optarg;
			break;
		case 'n':
			if (keep_snaps != 0) {
				krrp_print_err_already_defined("n");
				exit(1);
			}

			i = strtol(optarg, NULL, 0);
			if (i < KRRP_MIN_KEEP_SNAPS ||
			    i > KRRP_MAX_KEEP_SNAPS) {
				fprintf_err("Maximum number of snapshots that "
				    "will be kept must be an integer in range "
				    "from %d to %d\n", KRRP_MIN_KEEP_SNAPS,
				    KRRP_MAX_KEEP_SNAPS);
				exit(1);
			}

			keep_snaps = i;
			break;
		case 'm':
			if (skip_snaps_mask != NULL) {
				krrp_print_err_already_defined("m");
				exit(1);
			}

			skip_snaps_mask = optarg;
			break;
		case '?':
			krrp_print_err_unknown_param(argv[optind - 1]);
			cmd->usage_func(1, cmd, B_FALSE);
			break;
		case 'h':
			cmd->usage_func(0, cmd, B_FALSE);
			break;
		}
	}

	if (uuid_is_null(sess_id) == 1) {
		krrp_print_err_no_sess_id();
		cmd->usage_func(1, cmd, B_FALSE);
	}

	if (dataset == NULL) {
		fprintf_err("Source dataset must be specified\n");
		cmd->usage_func(1, cmd, B_FALSE);
	}

	if (keep_snaps == 0)
		keep_snaps = UINT32_MAX;

	rc = krrp_sess_create_read_stream(libkrrp_hdl, sess_id,
	    dataset, common_snap, src_snap, fake_data_sz, flags,
	    resume_token, keep_snaps, skip_snaps_mask);
	if (rc != 0) {
		fprintf_err("Failed to create read-stream\n");
		krrp_print_libkrrp_error();
		exit(1);
	}

	return (0);
}

static int
krrp_do_sess_create_write_stream(int argc, char **argv, krrp_cmd_t *cmd)
{
	int c, i, rc = 0;
	uuid_t sess_id;
	nvlist_t *ignore_props_list, *replace_props_list;
	char *dataset = NULL, *common_snap = NULL, *resume_token = NULL;
	krrp_sess_stream_flags_t flags = 0;
	uint32_t keep_snaps = 0;

	ignore_props_list = fnvlist_alloc();
	replace_props_list = fnvlist_alloc();

	uuid_clear(sess_id);

	while ((c = getopt(argc, argv, "hs:d:c:Fki:o:t:n:lx")) != -1) {
		switch (c) {
		case 's':
			if (krrp_parse_and_check_sess_id(optarg, sess_id) != 0)
				exit(1);

			break;
		case 'd':
			if (dataset != NULL) {
				krrp_print_err_already_defined("d");
				exit(1);
			}

			dataset = optarg;
			break;
		case 'c':
			if (common_snap != NULL) {
				krrp_print_err_already_defined("c");
				exit(1);
			}

			common_snap = optarg;
			break;
		case 'i':
			if (nvlist_exists(ignore_props_list, optarg)) {
				(void) fprintf(stderr, "The property '%s' "
				    "already defined\n", optarg);
				exit(1);
			}

			fnvlist_add_boolean_value(ignore_props_list,
			    optarg, B_TRUE);
			break;
		case 'o':
			{
				char *p;

				p = strchr(optarg, '=');
				if (p == NULL || *(p + 1) == '\0') {
					(void) fprintf(stderr, "Incorrect "
					    "argument of '-o' parameter\n");
					exit(1);
				}

				*p = '\0'; p++;

				if (nvlist_exists(replace_props_list, optarg)) {
					(void) fprintf(stderr, "The property "
					    "'%s' already defined\n", optarg);
					exit(1);
				}

				fnvlist_add_string(replace_props_list,
				    optarg, p);
				p--; *p = '=';
			}
			break;
		case 'F':
			if ((flags & KRRP_STREAM_FORCE_RECEIVE) != 0) {
				krrp_print_err_already_defined("F");
				exit(1);
			}

			flags |= KRRP_STREAM_FORCE_RECEIVE;
			break;
		case 'k':
			if ((flags & KRRP_STREAM_ZFS_CHKSUM) != 0) {
				krrp_print_err_already_defined("k");
				exit(1);
			}

			flags |= KRRP_STREAM_ZFS_CHKSUM;
			break;
		case 't':
			if (resume_token != NULL) {
				krrp_print_err_already_defined("t");
				exit(1);
			}

			resume_token = optarg;
			break;
		case 'n':
			if (keep_snaps != 0) {
				krrp_print_err_already_defined("n");
				exit(1);
			}

			i = strtol(optarg, NULL, 0);
			if (i < KRRP_MIN_KEEP_SNAPS ||
			    i > KRRP_MAX_KEEP_SNAPS) {
				fprintf_err("Maximum number of snapshots that "
				    "will be kept must be an integer in range "
				    "from %d to %d\n", KRRP_MIN_KEEP_SNAPS,
				    KRRP_MAX_KEEP_SNAPS);
				exit(1);
			}

			keep_snaps = i;
			break;
		case 'l':
			if ((flags & KRRP_STREAM_LEAVE_TAIL) != 0) {
				krrp_print_err_already_defined("l");
				exit(1);
			}

			flags |= KRRP_STREAM_LEAVE_TAIL;
			break;
		case 'x':
			if ((flags & KRRP_STREAM_DISCARD_HEAD) != 0) {
				krrp_print_err_already_defined("x");
				exit(1);
			}

			flags |= KRRP_STREAM_DISCARD_HEAD;
			break;
		case '?':
			krrp_print_err_unknown_param(argv[optind - 1]);
			cmd->usage_func(1, cmd, B_FALSE);
			break;
		case 'h':
			cmd->usage_func(0, cmd, B_FALSE);
			break;
		}
	}

	if (((flags & KRRP_STREAM_DISCARD_HEAD) != 0) &&
	    ((flags & KRRP_STREAM_LEAVE_TAIL) != 0)) {
		fprintf_err("Parameters 'x' and 'l' cannot "
		    "be used together\n");
		exit(1);
	}


	if (uuid_is_null(sess_id) == 1) {
		krrp_print_err_no_sess_id();
		cmd->usage_func(1, cmd, B_FALSE);
	}

	if (dataset == NULL) {
		fprintf_err("Destination dataset must be specified\n");
		cmd->usage_func(1, cmd, B_FALSE);
	}

	if (nvlist_empty(ignore_props_list)) {
		fnvlist_free(ignore_props_list);
		ignore_props_list = NULL;
	}

	if (nvlist_empty(replace_props_list)) {
		fnvlist_free(replace_props_list);
		replace_props_list = NULL;
	}

	if (keep_snaps == 0)
		keep_snaps = UINT32_MAX;

	rc = krrp_sess_create_write_stream(libkrrp_hdl, sess_id,
	    dataset, common_snap, flags, ignore_props_list,
	    replace_props_list, resume_token, keep_snaps);
	if (rc != 0) {
		fprintf_err("Failed to create write stream\n");
		krrp_print_libkrrp_error();
		exit(1);
	}

	return (0);
}

static int
krrp_do_sess_create_pdu_engine(int argc, char **argv, krrp_cmd_t *cmd)
{
	int c, i, rc = 0;
	uuid_t sess_id;
	int mem_limit = 0, dblk_sz = 0;
	boolean_t use_prealloc = B_FALSE;

	uuid_clear(sess_id);

	while ((c = getopt(argc, argv, "hs:m:b:a")) != -1) {
		switch (c) {
		case 's':
			if (krrp_parse_and_check_sess_id(optarg, sess_id) != 0)
				exit(1);

			break;
		case 'm':
			if (mem_limit != 0) {
				krrp_print_err_already_defined("m");
				exit(1);
			}

			i = strtol(optarg, NULL, 0);
			if (i < KRRP_MIN_MAXMEM || i > 16384) {
				fprintf_err("Maximum memory size "
				    "must be an integer in range from "
				    "%d to 16384\n", KRRP_MIN_MAXMEM);
				exit(1);
			}

			mem_limit = i;
			break;
		case 'b':
			if (dblk_sz != 0) {
				krrp_print_err_already_defined("b");
				exit(1);
			}

			i = strtol(optarg, NULL, 0);
			if (i < KRRP_MIN_SESS_PDU_DBLK_DATA_SZ ||
			    i > KRRP_MAX_SESS_PDU_DBLK_DATA_SZ) {
				fprintf_err("DBLK data size must "
				    "be an integer in range from "
				    "%d to %d\n",
				    KRRP_MIN_SESS_PDU_DBLK_DATA_SZ,
				    KRRP_MAX_SESS_PDU_DBLK_DATA_SZ);
				exit(1);
			}

			dblk_sz = i;
			break;
		case 'a':
			if (use_prealloc) {
				krrp_print_err_already_defined("a");
				exit(1);
			}

			use_prealloc = B_TRUE;
			break;
		case '?':
			krrp_print_err_unknown_param(argv[optind - 1]);
			cmd->usage_func(1, cmd, B_FALSE);
			break;
		case 'h':
			cmd->usage_func(0, cmd, B_FALSE);
			break;
		}
	}

	if (uuid_is_null(sess_id) == 1) {
		krrp_print_err_no_sess_id();
		cmd->usage_func(1, cmd, B_FALSE);
	}

	if (dblk_sz == 0) {
		fprintf_err("DBLK Data size is not defined\n");
		cmd->usage_func(1, cmd, B_FALSE);
	}

	if (mem_limit == 0) {
		fprintf_err("Maximum memory is not defined\n");
		cmd->usage_func(1, cmd, B_FALSE);
	}

	rc = krrp_sess_create_pdu_engine(libkrrp_hdl, sess_id,
	    mem_limit, dblk_sz, use_prealloc);
	if (rc != 0) {
		fprintf_err("Failed to create pdu engine\n");
		krrp_print_libkrrp_error();
		exit(1);
	}

	return (0);
}

static int
krrp_do_ksvc_action(int argc, char **argv, krrp_cmd_t *cmd)
{
	int rc = 0;
	const char *action;

	assert(cmd->item == KRRP_CMD_KSVC_ENABLE ||
	    cmd->item == KRRP_CMD_KSVC_DISABLE);

	if (argc > 1) {
		if (strcmp(argv[1], "-h") == 0) {
			cmd->usage_func(0, cmd, B_FALSE);
		} else {
			fprintf_err("Unknown params\n");
			cmd->usage_func(1, cmd, B_FALSE);
		}
	}

	if (cmd->item == KRRP_CMD_KSVC_ENABLE) {
		rc = krrp_svc_enable(libkrrp_hdl);
		action = "enable";
	} else {
		rc = krrp_svc_disable(libkrrp_hdl);
		action = "disable";
	}

	if (rc != 0) {
		fprintf_err("Failed to %s in kernel service\n", action);
		krrp_print_libkrrp_error();
		exit(1);
	}

	return (0);
}

/* ARGSUSED */
static int
krrp_do_svc_get_state(int argc, char **argv, krrp_cmd_t *cmd)
{
	int rc;
	libkrrp_svc_state_t svc_state;

	assert(cmd->item == KRRP_CMD_KSVC_STATE);

	rc = krrp_svc_state(libkrrp_hdl, &svc_state);
	if (rc != 0) {
		fprintf_err("Failed to get state of in-kernel service\n");
		krrp_print_libkrrp_error();
		exit(1);
	}

	fprintf_msg("KSVC-ENABLED: %s, KSRV-RUNNING: %s\n",
	    (svc_state.enabled ? "YES" : "NO"),
	    (svc_state.running ? "YES" : "NO"));

	return (0);
}

static int
krrp_do_ksvc_configure(int argc, char **argv, krrp_cmd_t *cmd)
{
	int c, rc, port = -1;
	const char *addr = NULL;

	assert(cmd->item == KRRP_CMD_KSVC_CONFIGURE);

	while ((c = getopt(argc, argv, "hp:a:")) != -1) {
		switch (c) {
		case 'p':
			if (port != -1) {
				krrp_print_err_already_defined("p");
				exit(1);
			}

			port = strtol(optarg, NULL, 0);
			if (port < KRRP_MIN_PORT || port > KRRP_MAX_PORT) {
				fprintf_err("Port number must be "
				    "an integer in range from %d to %d\n",
				    KRRP_MIN_PORT, KRRP_MAX_PORT);
				exit(1);
			}

			break;
		case 'a':
			if (addr != NULL) {
				krrp_print_err_already_defined("a");
				exit(1);
			}

			addr = optarg;
			break;
		case '?':
			krrp_print_err_unknown_param(argv[optind - 1]);
			cmd->usage_func(1, cmd, B_FALSE);
			break;
		case 'h':
			cmd->usage_func(0, cmd, B_FALSE);
			break;
		}
	}

	if (port == -1) {
		fprintf_err("Listening port number is not defined\n");
		exit(1);
	}

	rc = krrp_set_srv_config(libkrrp_hdl, addr, port);
	if (rc != 0) {
		fprintf_err("Failed to configure in-kernel service\n");
		krrp_print_libkrrp_error();
		exit(1);
	}

	return (0);
}

static int
krrp_parse_and_check_sess_id(char *sess_id_str, uuid_t sess_id)
{
	if (uuid_is_null(sess_id) != 1) {
		fprintf_err("Session ID already defined\n");
		return (-1);
	}

	if (uuid_parse(sess_id_str, sess_id) != 0) {
		fprintf_err("Failed to parse Session ID\n");
		return (-1);
	}

	return (0);
}

static void
krrp_print_err_already_defined(const char *param)
{
	fprintf_err("The parameter '%s' already defined\n", param);
}

static void
krrp_print_err_unknown_param(const char *param)
{
	fprintf_err("Unknown parameter '%s'\n", param);
}

static void
krrp_print_err_no_sess_id(void)
{
	fprintf_err("Session ID is not defined\n");
}

static void
krrp_print_libkrrp_error(void)
{
	fprintf_err("%s\n", libkrrp_error_description(libkrrp_hdl));
}

static void
fprintf_err(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	(void) vfprintf(stderr, fmt, ap);
	va_end(ap);
}

static void
fprintf_msg(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	(void) vfprintf(stdout, fmt, ap);
	va_end(ap);
}

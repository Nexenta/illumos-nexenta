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
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#include <sys/types.h>
#include <sys/conf.h>
#include <sys/sysmacros.h>
#include <sys/cmn_err.h>
#include <sys/stat.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/proc.h>
#include <sys/class.h>
#include <sys/sdt.h>

#include <krrp_params.h>
#include <sys/krrp.h>

#include "krrp_server.h"

static void krrp_server_enable(krrp_server_t *server);
static void krrp_server_worker(void *void_server);
static int krrp_server_accept(krrp_server_t *server, ksocket_t *result_ks);
static int krrp_server_create_socket(krrp_server_t *server);
static void krrp_server_cleanup_socket(krrp_server_t *server);

void
krrp_server_create(krrp_server_t **result_server,
    krrp_new_ks_cb_t *new_ks_cb, krrp_svr_error_cb_t *on_error_cb)
{
	krrp_server_t *server;

	VERIFY(result_server != NULL && *result_server == NULL);
	VERIFY(new_ks_cb != NULL);
	VERIFY(on_error_cb != NULL);

	server = kmem_zalloc(sizeof (krrp_server_t), KM_SLEEP);

	mutex_init(&server->mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&server->cv, NULL, CV_DEFAULT, NULL);

	server->new_ks_cb = new_ks_cb;
	server->on_error_cb = on_error_cb;

	*result_server = server;
}

void
krrp_server_destroy(krrp_server_t *server)
{
	mutex_enter(&server->mtx);

	server->running = B_FALSE;
	cv_signal(&server->cv);
	krrp_server_cleanup_socket(server);
	mutex_exit(&server->mtx);

	if (server->t_did != 0)
		thread_join(server->t_did);

	cv_destroy(&server->cv);
	mutex_destroy(&server->mtx);

	kmem_free(server, sizeof (krrp_server_t));
}

boolean_t
krrp_server_is_running(krrp_server_t *server)
{
	boolean_t result = B_TRUE;

	mutex_enter(&server->mtx);

	if (!server->running || server->state != KRRP_SRVS_ACTIVE)
		result = B_FALSE;

	mutex_exit(&server->mtx);

	return (result);
}

int
krrp_server_set_config(krrp_server_t *server, nvlist_t *params,
    krrp_error_t *error)
{
	int rc = 0;
	const char *listening_addr = NULL;
	int listening_port = 0;
	krrp_server_state_t saved_srv_state;

	mutex_enter(&server->mtx);

	if (server->state == KRRP_SRVS_RECONFIGURE) {
		krrp_error_set(error, KRRP_ERRNO_BUSY, 0);
		mutex_exit(&server->mtx);
		return (-1);
	}

	saved_srv_state = server->state;
	server->state = KRRP_SRVS_RECONFIGURE;
	mutex_exit(&server->mtx);

	(void) krrp_param_get(KRRP_PARAM_LISTENING_ADDRESS,
	    params, (void *)&listening_addr);

	if (listening_addr != NULL && (listening_addr[0] == '\0' ||
	    (strlen(listening_addr) >= sizeof (server->listening_addr)))) {
		krrp_error_set(error, KRRP_ERRNO_ADDR, EINVAL);
		rc = -1;
		goto out;
	}

	rc = krrp_param_get(KRRP_PARAM_PORT,
	    params, &listening_port);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_PORT, ENOENT);
		goto out;
	}

	if (listening_port < KRRP_MIN_PORT ||
	    listening_port > KRRP_MAX_PORT) {
		krrp_error_set(error, KRRP_ERRNO_PORT, EINVAL);
		rc = -1;
		goto out;
	}

	mutex_enter(&server->mtx);

	(void) memset(server->listening_addr, 0,
	    sizeof (server->listening_addr));
	if (listening_addr != NULL)
		(void) strncpy(server->listening_addr, listening_addr,
		    sizeof (server->listening_addr));

	server->listening_port = listening_port;

	if (!server->running) {
		/* The server is not started yet, so need to enable it */
		krrp_server_enable(server);
	} else {
		/*
		 * The server is started, so need to close the current socket,
		 * to recreate it with new parameters
		 */
		krrp_server_cleanup_socket(server);
	}

	/*
	 * To exclude double-error in userspace
	 */
	server->without_event = B_TRUE;

	/*
	 * The worker thread may waits on cv right after start and
	 * if an error occured so need to wake up it.
	 */
	cv_signal(&server->cv);

	/*
	 * We have woken up the worker thread so wait the result of
	 * socket-create operation
	 */
	while (server->state == KRRP_SRVS_RECONFIGURE)
		cv_wait(&server->cv, &server->mtx);

	if (server->state != KRRP_SRVS_ACTIVE) {
		krrp_error_set(error, server->error.krrp_errno,
		    server->error.unix_errno);
		rc = -1;
	}

	server->without_event = B_FALSE;
	mutex_exit(&server->mtx);

	return (rc);

out:
	mutex_enter(&server->mtx);
	server->state = saved_srv_state;
	mutex_exit(&server->mtx);
	return (-1);
}

int
krrp_server_get_config(krrp_server_t *server, nvlist_t *result,
    krrp_error_t *error)
{
	int rc = -1;

	VERIFY(result != NULL);

	mutex_enter(&server->mtx);

	if (!server->running) {
		krrp_error_set(error, KRRP_ERRNO_INVAL, 0);
		goto out;
	}

	(void) krrp_param_put(KRRP_PARAM_PORT, result,
	    &server->listening_port);

	if (server->listening_addr[0] != '\0')
		(void) krrp_param_put(KRRP_PARAM_LISTENING_ADDRESS,
		    result, server->listening_addr);

	rc = 0;

out:
	mutex_exit(&server->mtx);

	return (rc);
}

static void
krrp_server_enable(krrp_server_t *server)
{
	VERIFY(MUTEX_HELD(&server->mtx));

	/* thread_create never fails */
	(void) thread_create(NULL, 0, &krrp_server_worker,
	    server, 0, &p0, TS_RUN, minclsyspri);

	while (server->t_did == 0)
		cv_wait(&server->cv, &server->mtx);
}

static void
krrp_server_worker(void *void_server)
{
	krrp_server_t *server = void_server;
	ksocket_t ks = NULL;

	mutex_enter(&server->mtx);
	server->running = B_TRUE;
	server->t_did = curthread->t_did;
	cv_signal(&server->cv);
	cv_wait(&server->cv, &server->mtx);

	while (server->running) {
		if (krrp_server_create_socket(server) != 0) {
			if (!server->without_event)
				server->on_error_cb(&server->error);

			server->state = KRRP_SRVS_IN_ERROR;
			cv_signal(&server->cv);
			cv_wait(&server->cv, &server->mtx);
			continue;
		}

		server->state = KRRP_SRVS_ACTIVE;
		cv_signal(&server->cv);
		mutex_exit(&server->mtx);

		/*
		 * To be able to unblock ksocket_accept from another
		 * thread by closing the ksocket
		 */
		ksocket_hold(server->listening_ks);

		while (krrp_server_accept(server, &ks) == 0)
			server->new_ks_cb(ks);

		ksocket_rele(server->listening_ks);

		mutex_enter(&server->mtx);
	}

	mutex_exit(&server->mtx);
}

static int
krrp_server_accept(krrp_server_t *server, ksocket_t *result_ks)
{
	int rc = 0;

repeat:
	rc = ksocket_accept(server->listening_ks, NULL, NULL,
	    result_ks, CRED());
	if (rc == ECONNABORTED || rc == EINTR)
		goto repeat;

	/*
	 * ENOTSOCK means someone call ksocket_close()
	 * for the listening socket
	 */
	if (rc != 0 && rc != ENOTSOCK) {
		cmn_err(CE_WARN, "Failed to accept new socket "
		    "[errno: %d]", rc);
	}

	return (rc);
}

static int
krrp_server_create_socket(krrp_server_t *server)
{
	int rc;
	uint32_t on = 1;
	struct sockaddr_in servaddr;

	krrp_error_init(&server->error);

	krrp_server_cleanup_socket(server);

	rc = ksocket_socket(&server->listening_ks, AF_INET, SOCK_STREAM,
	    0, KSOCKET_SLEEP, CRED());
	if (rc != 0) {
		krrp_error_set(&server->error, KRRP_ERRNO_CREATEFAIL, rc);
		goto out;
	}

	(void) ksocket_setsockopt(server->listening_ks, SOL_SOCKET,
	    SO_REUSEADDR, &on, sizeof (on), CRED());

	servaddr.sin_family = AF_INET;
	servaddr.sin_port = htons(server->listening_port);

	if (server->listening_addr[0] != '\0') {
		if (inet_pton(AF_INET, (char *)server->listening_addr,
		    &servaddr.sin_addr) != 1) {
			krrp_error_set(&server->error, KRRP_ERRNO_ADDR, EINVAL);
			rc = -1;
			goto fini;
		}
	} else
		servaddr.sin_addr.s_addr = htonl(INADDR_ANY);

	rc = ksocket_bind(server->listening_ks, (struct sockaddr *)&servaddr,
	    sizeof (servaddr), CRED());
	if (rc != 0) {
		krrp_error_set(&server->error, KRRP_ERRNO_BINDFAIL, rc);
		goto fini;
	}

	rc = ksocket_listen(server->listening_ks, 5, CRED());
	if (rc < 0)
		krrp_error_set(&server->error, KRRP_ERRNO_LISTENFAIL, rc);

fini:
	if (rc != 0)
		krrp_server_cleanup_socket(server);

out:
	return (rc);
}

static void
krrp_server_cleanup_socket(krrp_server_t *server)
{
	if (server->listening_ks != NULL) {
		(void) ksocket_close(server->listening_ks, CRED());
		server->listening_ks = NULL;
	}
}

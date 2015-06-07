/*
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * BSD 3 Clause License
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *      - Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *      - Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *      - Neither the name of Sun Microsystems, Inc. nor the
 *      names of its contributors may be used to endorse or promote products
 *      derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY SUN MICROSYSTEMS, INC. ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL SUN MICROSYSTEMS, INC. BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright 2015 Nexenta Systems, Inc. All rights reserved.
 */

#ifndef _NDMP_CONNECT_H
#define	_NDMP_CONNECT_H

#ifdef	__cplusplus
extern "C" {
#endif

#include <rpc/rpc.h>
#include <ndmp_comm_lib.h>
#include <ndmp.h>

#define	SERVER_PORT		10000
#define	SUCCESS			0
#define	ERROR			1
#define	E_HOST_UNKNOWN		2
#define	E_SOCKET_OPEN		3
#define	E_SOCKET_CONNECT	4
#define	E_XDRREC_CREATE		5
#define	E_XDR_ENCODE		6
#define	E_XDR_DECODE		7
#define	E_AUTH_FAIL		8
#define	E_CONN_NOTFOUND		9
#define	E_NOTIFY_NOT_FOUND	10
#define	E_MALFORMED_PACKET	11
#define	REPLY			12
#define	REQUEST			13
#define	E_XDR_REQ_NOT_FOUND	14

struct host_info {
	char *ipAddr;
	char *userName;
	char *password;
	int protocol_version;
	char server_challenge[64];
	char client_digest[64];
	ndmp_auth_type auth_type;
};
typedef struct host_info host_info;

struct sock_handle {
	int sd;
};
typedef struct sock_handle sock_handle;

struct conn_handle {
	int connhandle;
};
typedef struct conn_handle conn_handle;

struct xdr_info {
	int sd;
	XDR *xdrs;
};
typedef struct xdr_info xdr_info;

struct conn_table {
	conn_handle *conn;
	xdr_info *xdrinfo;
	struct conn_table *next;
};
typedef struct conn_table conn_table;

struct handletable {
	ndmp_message messagecode;
	int replysize;
};
typedef struct handletable handletable;

struct notify_qrec {
	ndmp_message messagecode;
	void *notify;
	struct notify_qrec *next;
};
typedef struct notify_qrec notify_qrec;



int open_connection(host_info *, conn_handle *, FILE *);

int process_request(void *, ndmp_message, conn_handle *, void **,
	FILE *);

int process_notification(conn_handle *, ndmp_message, notify_qrec **,
	FILE *);

int close_connection(conn_handle *, FILE *);

int delete_element(notify_qrec **, ndmp_message, FILE *);
int delete_queue(notify_qrec **, FILE *);
notify_qrec * search_element(notify_qrec *, ndmp_message, FILE *);
int client_connect_close(conn_handle *, FILE *);
int client_connect_authorize(host_info *, conn_handle *,
    ndmp_connect_client_auth_reply **, FILE *);
int client_connect_open(host_info *, conn_handle *,
    ndmp_connect_open_reply **, FILE *);
int server_connect_auth(host_info *, conn_handle *,
    ndmp_connect_server_auth_reply **, FILE *);

#ifdef	__cplusplus
}
#endif

#endif	/* _NDMP_CONNECT_H */

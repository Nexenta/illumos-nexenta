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
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#include <rpc/rpc.h>
#include <rpc/xdr.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <netdb.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <ndmp.h>
#include <ndmp_connect.h>
#include <log.h>

int readit(void *, char *, int);
int writeit(void *, char *, int);
int open_socket(host_info *, sock_handle *, FILE *);
int xdr_initialize(xdr_info *, FILE *);
int send_request(handletable *, XDR *, void *, ndmp_message, FILE *);
int recieve_reply(handletable *, XDR *, void **, ndmp_message, notify_qrec **,
    FILE *);
notify_qrec * recieve_notification(handletable *, XDR *, notify_qrec *,
    ndmp_message, FILE *log);
int authenticate_connection(handletable *, host_info *, conn_table *,
    conn_handle *, ndmp_connect_client_auth_reply **, notify_qrec *, FILE *);
handletable * getmessage_handle(handletable *, ndmp_message, FILE *);
conn_table * get_connection(conn_table *, conn_handle *, FILE *);
notify_qrec *queue_element(notify_qrec *, void *, ndmp_message, FILE *);
void print_queue(notify_qrec *);
bool_t invoke_xdr_routine(XDR *, void *, ndmp_message, int, FILE *);

bool_t conn_eof = FALSE;


/*
 * open_socket() method opens the socket and fills the sock_handle structure
 * Args are     :
 * host_info    : strucuture containing host information :IP,Username and Passwd
 * sock_handle  : strucuture which will be filled by this method with sd
 * log          : handle to write the log messages
 * Return Value : 1 :- success , 0 :- Failure
 */

int
open_socket(host_info *hostinfo, sock_handle *shandle, FILE *log)
{

	/* Define socket structures and XDR pointer allocate memory */

	if (log == NULL) {
		ndmp_fprintf(log, "LOG is NULL \n");
		return (ERROR);
	}

	struct sockaddr_in servAddr;

	struct hostent *h;
	int on = 1;
	h = gethostbyname(hostinfo->ipAddr);

	/* Error Condition checking if host does not exist */


	if (h == NULL) {
		ndmp_fprintf(log, "open_socket failed : unknown host '%s'\n",
		    hostinfo->ipAddr);
		return (E_HOST_UNKNOWN);
	}
	/* Initialize the server socket structure */

	servAddr.sin_family = h->h_addrtype;
	memcpy((char *)&servAddr.sin_addr.s_addr, h->h_addr_list[0],
	    h->h_length);
	servAddr.sin_port = htons(SERVER_PORT);

	/* create socket */

	shandle->sd = socket(AF_INET, SOCK_STREAM, 0);
	setsockopt(shandle->sd, 0, TCP_NODELAY,
	    (const char *) &on, sizeof (int));
	ndmp_dprintf(log, "open_socket SOCKET HANDLE is %d \n",
	    shandle->sd);
	if (shandle->sd < 0) {
		ndmp_fprintf(log, "open_socket failed : cannot open socket \n");
		return (E_SOCKET_OPEN);
	}
	ndmp_dprintf(log, "open_socket () : Socket created \n");
	/* connect to server */
	int rc;
	rc = connect(shandle->sd, (struct sockaddr *)&servAddr,
	    sizeof (servAddr));
	if (rc < 0) {
		ndmp_fprintf(log, "connect socket failed :cannot connect \n");
		return (E_SOCKET_CONNECT);
	}
	ndmp_dprintf(log, "open_socket () :Connect success \n");


	return (SUCCESS);
}

/*
 * xdr_initialize () method initialiazes xdr pointer to socket stream
 * Args are     :
 * xdr_info     : strucuture to be filled with the xdr pointer initialized
 * log          : handle to write log messages
 * Return Value : 1 :- success , 0 :- Failure
 */

int
xdr_initialize(xdr_info *xinfo, FILE *log)
{
	int (*readfunc)(void *, char *, int) = readit;
	int (*writefunc)(void *, char *, int) = writeit;
	ndmp_dprintf(log, "xdr_initialize ():Inside xdr_intialize \n");
	xdrrec_create(xinfo->xdrs, 0, 0, (caddr_t)&(xinfo->sd), readfunc, writefunc);
	if (xinfo->xdrs == NULL) {
		ndmp_fprintf(log, "xdr_intialize () :xdrrec_create Failed \n");
		return (E_XDRREC_CREATE);
	}

	ndmp_dprintf(log, "xdr_intialize() : xdrrec_create successful \n");

	return (SUCCESS);
}

/*
 * send_request() method does request encoding and does the following tasks
 *      forms the ndmp header with the messagecode and sends over the wire
 *      sends the request object over wire with approprite xdr method
 * Args are     :
 * handletable  : which contains the xdr function pointer
 * xdrs         : xdr pointer
 * request      : request object
 * messagecode  : ndmp messagecode
 * log          : handle to write any log messages
 * Return Value : 1 :- success , 0 :- Failure
 */

int
send_request(handletable *handletbl, XDR *xdrs, void *request,
    ndmp_message messagecode, FILE *log)
{
	/* Define and Initialize ndmp_header */
	struct timeval time;
	ndmp_header *hdr = (ndmp_header *) malloc(sizeof (ndmp_header));
	hdr->sequence = 1;
	gettimeofday(&time, 0);
	hdr->time_stamp = time.tv_sec;
	hdr->message_type = NDMP_MESSAGE_REQUEST;
	hdr->message_code = messagecode;
	hdr->reply_sequence = 0;
	hdr->error_code = NDMP_NO_ERR;

	/* SET THE XDR Operation to ENCODE */

	if (request == NULL)
		ndmp_dprintf(log, "send_request:messagecode %d\n", messagecode);
	xdrs->x_op = XDR_ENCODE;

	ndmp_dprintf(log, "send_request () : Afterxdrs->x_op = XDR_ENCODE \n");

	/* call xdr encode method for header */

	if (xdr_ndmp_header(xdrs, hdr)) {
		ndmp_dprintf(log, "send_request(): xdr_ndmp_header success \n");
	} else {
		ndmp_dprintf(log, "send_request(): xdr_ndmp_header failed \n");
		return (E_XDR_ENCODE);
	}

	/* Call the xdr encoding method for the request */


	if (request != NULL && (invoke_xdr_routine(xdrs, request,
	    messagecode, REQUEST, log) == SUCCESS)) {
		ndmp_dprintf(log, "send_request () :Encoding success \n");
	} else {
		ndmp_dprintf(log, "send_request () : Encoding failure or "
		    "request object is NULL \n");
	}
	/* Send XDR data over the wire */

	if (xdrrec_endofrecord(xdrs, 1)) {
		ndmp_dprintf(log, "send_request () :xdrrec_endofrecord returned"
		    "TRUE\n");
	} else {
		ndmp_dprintf(log, "send_request () :xdrrec_endofrecord returned"
		    "FALSE \n");
		return (E_XDR_ENCODE);
	}

	free(hdr);
	return (SUCCESS);
}

/*
 * authenticate_connection () method authenticates the ndmp connection
 * Args are     :
 * handletable  : to get xdr_encode and xdr_decode methods
 * host_info    : strucutre with host information like usename and password
 * conn_table   : to get the connection object to authenticate
 * conn_handle  : connnection handle
 * log          : log handle to log the messages
 * Return Value : 1 :- success , 0 :- Failure
 */

int
authenticate_connection(handletable *handletbl, host_info *hinfo,
    conn_table *conntbl, conn_handle *conn,
    ndmp_connect_client_auth_reply **reply, notify_qrec *qlist, FILE *log)
{
	conn_table *tbl = (conn_table *) get_connection(conntbl, conn, log);
	ndmp_connect_client_auth_request *request =
	    (ndmp_connect_client_auth_request *) malloc
	    (sizeof (ndmp_connect_client_auth_request));

	ndmp_message messagecode = NDMP_CONNECT_CLIENT_AUTH;
	if (hinfo->auth_type == NDMP_AUTH_TEXT) {
		request->auth_data.auth_type = hinfo->auth_type;
		request->auth_data.ndmp_auth_data_u.auth_text.auth_id =
		    hinfo->userName;
		request->auth_data.ndmp_auth_data_u.auth_text.auth_password
		    = hinfo->password;
		ndmp_dprintf(log, "authenticate_connection ():auth type %d \n",
		    request->auth_data.auth_type);
		ndmp_dprintf(log, "authenticate_connection () :auth id %s \n",
		    request->auth_data.ndmp_auth_data_u.auth_text.auth_id);
		ndmp_dprintf(log, "authenticate_connection () :auth pass %s \n",
		    request->auth_data.ndmp_auth_data_u.auth_text.
		    auth_password);
	} else if (hinfo->auth_type == NDMP_AUTH_NONE) {
		request->auth_data.auth_type = NDMP_AUTH_NONE;
	} else {
		request->auth_data.auth_type = hinfo->auth_type;
	}

	if (send_request(handletbl, tbl->xdrinfo->xdrs, request, messagecode,
	    log) == 0) {
		ndmp_dprintf(log, "authenticate_connection () :"
		    "AUTH REQUEST SENT SUCCESSFULLY \n");
	} else {
		ndmp_dprintf(log, "authenticate_connection () :"
		    "AUTH REQUEST FAILED \n");
		return (E_AUTH_FAIL);
	}

	/* Recieve the reply object and decode */

	if (recieve_reply(handletbl, tbl->xdrinfo->xdrs, (void *)reply,
	    messagecode, &qlist, log) == 0) {
		ndmp_dprintf(log, "authenticate_connection () :"
		    "Reply recieved successfully \n");

	} else {
		ndmp_dprintf(log, "authenticate_connection () :"
		    "Error in recieve reply \n");
		return (E_AUTH_FAIL);
	}


	return (SUCCESS);

}

/*
 * recieve_reply () method decodes the reply and fills the reply structure
 * Args are     :
 * handletable  : to get xdr_encode and xdr_decode methods
 * xdrs         : xdr pointer
 * reply        : reply structure
 * messagecode  : ndmp messagecode
 * log          : log handle
 * Return Value : 1 :- success , 0 :- Failure
 */

int
recieve_reply(handletable *handletbl, XDR *xdrs, void **reply,
    ndmp_message messagecode, notify_qrec **qlist, FILE *log)
{
	/* Define and Initialize ndmp_header */
	ndmp_dprintf(log, "recieve_reply () :Inside recieve reply \n");

	ndmp_header *hdr = (ndmp_header *) malloc(sizeof (ndmp_header));

	/* Get the message handle for ndmp reuest method */

	handletable *tbl = (handletable *) getmessage_handle(handletbl,
	    messagecode, log);

	xdrs->x_op = XDR_DECODE;

	/* Allocate memory for the reply structure */

	void *temp = (void *) malloc(tbl->replysize);
	*reply = temp;
	memset(temp, 0, tbl->replysize);
	int count = 0;

	while (conn_eof == FALSE && count < 10) {
		if (xdr_ndmp_header(xdrs, hdr)) {
			/* Check if the message type reply & decode the reply */
			if (hdr->message_type == NDMP_MESSAGE_REPLY) {
				/* Call the xdr decode method for the reply */
				if (hdr->error_code ==
				    NDMP_NOT_AUTHORIZED_ERR) {
					free(temp);
					free(hdr);
					*reply = NULL;
					return (E_MALFORMED_PACKET);
				}
				if (hdr->error_code == NDMP_XDR_DECODE_ERR) {
					free(temp);
					free(hdr);
					*reply = NULL;
					return (E_XDR_DECODE);
				}

				if (invoke_xdr_routine(xdrs, temp,
				    hdr->message_code, REPLY, log) == SUCCESS) {
					free(hdr);
					return (SUCCESS);
				}

			} else if (hdr->message_type == NDMP_MESSAGE_REQUEST) {
				/* Check if message is a notification */
				ndmp_dprintf(log, "recieve_reply ():"
				    "Message code is %x \n", hdr->message_code);

				if (hdr->message_code > 0x500 &&
				    hdr->message_code < 0x506) {
					handletable *tbl2 = (handletable *)
					    getmessage_handle(handletbl,
					    hdr->message_code, log);
					void *temp = (void *)
					    malloc(tbl2->replysize);
					memset(temp, 0, tbl2->replysize);
					/* xdr decode method for notification */
					if (invoke_xdr_routine(xdrs, temp,
					    hdr->message_code, REPLY, log) ==
					    SUCCESS) {
						ndmp_dprintf(log,
						    "recieve_reply () :"
						    "notification success \n");
						*qlist = queue_element(*qlist,
						    temp, hdr->message_code,
						    log);

					} /* End of if (tbl2->reply_fptr) */
				} /* End of if (hdr->message_code > 0x500 */

			} /* End -if(hdr->message_type==NDMP_MESSAGE_REQUEST) */
		}
		xdrrec_skiprecord(xdrs);
		usleep(500000);
		count++;
	}
	free(hdr);
	return (E_XDR_DECODE);
}
/*
 * recieve_notification() method decodes the notifications
 * Args are     :
 * handletable  : to get xdr_encode and xdr_decode methods
 * xdrs         : xdr pointer
 * log          : log handle
 * return value : Returns the queue of notifications
 */

notify_qrec *
recieve_notification(handletable *handletbl, XDR *xdrs,
    notify_qrec *qlist, ndmp_message messagecode, FILE *log)
{
	xdrs->x_op = XDR_DECODE;
	/* Loop on stream to get the objects for (0.5 x count) seconds */
	int count = 0;
	while (count < 30) {
		while (conn_eof == FALSE) {
			ndmp_header hdr;
			if (xdr_ndmp_header(xdrs, &hdr)) {
				if (hdr.message_type == NDMP_MESSAGE_REQUEST) {
					handletable *tbl = (handletable *)
					    getmessage_handle(handletbl,
					    hdr.message_code, log);
					/* Allocate memory for the replysize */
					void *temp = (void *)
					    malloc(tbl->replysize);
					memset(temp, 0, tbl->replysize);
					if (invoke_xdr_routine(xdrs, temp,
					    hdr.message_code, REPLY, log) ==
					    SUCCESS) {
						qlist = queue_element(qlist,
						    temp, hdr.message_code,
						    log);
					}
				}
				if (hdr.message_code == messagecode) {
					ndmp_dprintf(log, "Returning and the "
					    "messagecode = %x \n", messagecode);
					return (qlist);
				}
			}
			xdrrec_skiprecord(xdrs);
		}
		usleep(500000);
		count++;
	}
	return (qlist);
}

bool_t
invoke_xdr_routine(XDR *xdrs, void *objp, ndmp_message messagecode,
    int req_reply_flag, FILE *log)
{

	switch (messagecode) {
		case NDMP_CONNECT_OPEN:
			if (req_reply_flag == REPLY) {
				xdr_ndmp_connect_open_reply(xdrs,
				    (ndmp_connect_open_reply *)objp);
			}
			else
				xdr_ndmp_connect_open_request(xdrs,
				    (ndmp_connect_open_request *)objp);
			break;
		case NDMP_CONFIG_GET_SERVER_INFO:
			if (req_reply_flag == REPLY)
				xdr_ndmp_config_get_server_info_reply(xdrs,
				    (ndmp_config_get_server_info_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_NOTIFY_CONNECTION_STATUS:
			if (req_reply_flag == REPLY)
				xdr_ndmp_notify_connection_status_post(xdrs,
				    (ndmp_notify_connection_status_post *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_CONNECT_CLIENT_AUTH:
			if (req_reply_flag == REPLY)
				xdr_ndmp_connect_client_auth_reply(xdrs,
				    (ndmp_connect_client_auth_reply *)objp);
			else
				xdr_ndmp_connect_client_auth_request(xdrs,
				    (ndmp_connect_client_auth_request *)objp);
			break;
		case NDMP_CONNECT_CLOSE:
			ndmp_dprintf(log, "Invalid  req_reply_flag"
			    "xdr request structure is NULL\n");
			return (E_XDR_REQ_NOT_FOUND);
		case NDMP_CONFIG_GET_HOST_INFO:
			if (req_reply_flag == REPLY)
				xdr_ndmp_config_get_host_info_reply(xdrs,
				    (ndmp_config_get_host_info_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_CONFIG_GET_CONNECTION_TYPE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_config_get_connection_type_reply(xdrs,
				    (ndmp_config_get_connection_type_reply *)
				    objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_CONFIG_GET_AUTH_ATTR:
			if (req_reply_flag == REPLY)
				xdr_ndmp_config_get_auth_attr_reply(xdrs,
				    (ndmp_config_get_auth_attr_reply *)objp);
			else
				xdr_ndmp_config_get_auth_attr_request(xdrs,
				    (ndmp_config_get_auth_attr_request *)objp);
			break;
		case NDMP_CONFIG_GET_BUTYPE_INFO:
			if (req_reply_flag == REPLY)
				xdr_ndmp_config_get_butype_attr_reply(xdrs,
				    (ndmp_config_get_butype_attr_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_CONFIG_GET_FS_INFO:
			if (req_reply_flag == REPLY)
				xdr_ndmp_config_get_fs_info_reply(xdrs,
				    (ndmp_config_get_fs_info_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_CONFIG_GET_TAPE_INFO:
			if (req_reply_flag == REPLY)
				xdr_ndmp_config_get_tape_info_reply(xdrs,
				    (ndmp_config_get_tape_info_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_CONFIG_GET_SCSI_INFO:
			if (req_reply_flag == REPLY)
				xdr_ndmp_config_get_scsi_info_reply(xdrs,
				    (ndmp_config_get_scsi_info_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_CONFIG_GET_EXT_LIST:
			if (req_reply_flag == REPLY)
				xdr_ndmp_config_get_ext_list_reply(xdrs,
				    (ndmp_config_get_ext_list_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_SCSI_OPEN:
			if (req_reply_flag == REPLY)
				xdr_ndmp_scsi_open_reply(xdrs,
				    (ndmp_scsi_open_reply *)objp);
			else
				xdr_ndmp_scsi_open_request(xdrs,
				    (ndmp_scsi_open_request *)objp);
			break;
		case NDMP_SCSI_CLOSE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_scsi_close_reply(xdrs,
				    (ndmp_scsi_close_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_SCSI_GET_STATE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_scsi_get_state_reply(xdrs,
				    (ndmp_scsi_get_state_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_SCSI_RESET_DEVICE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_scsi_reset_device_reply(xdrs,
				    (ndmp_scsi_reset_device_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_SCSI_EXECUTE_CDB:
			if (req_reply_flag == REPLY)
				xdr_ndmp_execute_cdb_reply(xdrs,
				    (ndmp_execute_cdb_reply *)objp);
			else
				xdr_ndmp_execute_cdb_request(xdrs,
				    (ndmp_execute_cdb_request *)objp);
			break;
		case NDMP_TAPE_OPEN:
			if (req_reply_flag == REPLY)
				xdr_ndmp_tape_open_reply(xdrs,
				    (ndmp_tape_open_reply *)objp);
			else
				xdr_ndmp_tape_open_request(xdrs,
				    (ndmp_tape_open_request *)objp);
			break;
		case NDMP_TAPE_CLOSE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_tape_close_reply(xdrs,
				    (ndmp_tape_close_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_TAPE_GET_STATE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_tape_get_state_reply(xdrs,
				    (ndmp_tape_get_state_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_TAPE_MTIO:
			if (req_reply_flag == REPLY)
				xdr_ndmp_tape_mtio_reply(xdrs,
				    (ndmp_tape_mtio_reply *)objp);
			else
				xdr_ndmp_tape_mtio_request(xdrs,
				    (ndmp_tape_mtio_request *)objp);
			break;
		case NDMP_TAPE_WRITE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_tape_write_reply(xdrs,
				    (ndmp_tape_write_reply *)objp);
			else
				xdr_ndmp_tape_write_request(xdrs,
				    (ndmp_tape_write_request *)objp);
			break;
		case NDMP_TAPE_READ:
			if (req_reply_flag == REPLY)
				xdr_ndmp_tape_read_reply(xdrs,
				    (ndmp_tape_read_reply *)objp);
			else
				xdr_ndmp_tape_read_request(xdrs,
				    (ndmp_tape_read_request *)objp);
			break;
		case NDMP_TAPE_EXECUTE_CDB:
			if (req_reply_flag == REPLY)
				xdr_ndmp_tape_execute_cdb_reply(xdrs,
				    (ndmp_tape_execute_cdb_reply *)objp);
			else
				xdr_ndmp_tape_execute_cdb_request(xdrs,
				    (ndmp_tape_execute_cdb_request *)objp);
			break;
		case NDMP_DATA_GET_STATE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_data_get_state_reply(xdrs,
				    (ndmp_data_get_state_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_DATA_START_BACKUP:
			if (req_reply_flag == REPLY)
				xdr_ndmp_data_start_backup_reply(xdrs,
				    (ndmp_data_start_backup_reply *)objp);
			else
				xdr_ndmp_data_start_backup_request(xdrs,
				    (ndmp_data_start_backup_request *)objp);
			break;
		case NDMP_DATA_START_RECOVER:
			if (req_reply_flag == REPLY)
				xdr_ndmp_data_start_recover_reply(xdrs,
				    (ndmp_data_start_recover_reply *)objp);
			else
				xdr_ndmp_data_start_recover_request(xdrs,
				    (ndmp_data_start_recover_request *)objp);
			break;
		case NDMP_DATA_GET_ENV:
			if (req_reply_flag == REPLY)
				xdr_ndmp_data_get_env_reply(xdrs,
				    (ndmp_data_get_env_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_DATA_STOP:
			if (req_reply_flag == REPLY)
				xdr_ndmp_data_stop_reply(xdrs,
				    (ndmp_data_stop_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_DATA_LISTEN:
			if (req_reply_flag == REPLY)
				xdr_ndmp_data_listen_reply(xdrs,
				    (ndmp_data_listen_reply *)objp);
			else
				xdr_ndmp_data_listen_request(xdrs,
				    (ndmp_data_listen_request *)objp);
			break;
		case NDMP_DATA_CONNECT:
			if (req_reply_flag == REPLY)
				xdr_ndmp_data_connect_reply(xdrs,
				    (ndmp_data_connect_reply *)objp);
			else
				xdr_ndmp_data_connect_request(xdrs,
				    (ndmp_data_connect_request *)objp);
			break;
		case NDMP_DATA_START_RECOVER_FILEHIST:
			if (req_reply_flag == REPLY)
				xdr_ndmp_data_start_recover_reply(xdrs,
				    (ndmp_data_start_recover_reply *)objp);
			else
				xdr_ndmp_data_start_recover_request(xdrs,
				    (ndmp_data_start_recover_request *)objp);
			break;
		case NDMP_NOTIFY_DATA_HALTED:
			if (req_reply_flag == REPLY)
				xdr_ndmp_notify_data_halted_post(xdrs,
				    (ndmp_notify_data_halted_post *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_NOTIFY_MOVER_HALTED:
			if (req_reply_flag == REPLY)
				xdr_ndmp_notify_mover_halted_post(xdrs,
				    (ndmp_notify_mover_halted_post *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_NOTIFY_MOVER_PAUSED:
			if (req_reply_flag == REPLY)
				xdr_ndmp_notify_mover_paused_post(xdrs,
				    (ndmp_notify_mover_paused_post *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_NOTIFY_DATA_READ:
			if (req_reply_flag == REPLY)
				xdr_ndmp_notify_data_read_post(xdrs,
				    (ndmp_notify_data_read_post *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_LOG_FILE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_log_file_post(xdrs,
				    (ndmp_log_file_post *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_LOG_MESSAGE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_log_message_post(xdrs,
				    (ndmp_log_message_post *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_FH_ADD_FILE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_fh_add_file_post(xdrs,
				    (ndmp_fh_add_file_post *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_FH_ADD_DIR:
			if (req_reply_flag == REPLY)
				xdr_ndmp_fh_add_dir_post(xdrs,
				    (ndmp_fh_add_dir_post *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_FH_ADD_NODE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_fh_add_node_post(xdrs,
				    (ndmp_fh_add_node_post *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_MOVER_GET_STATE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_mover_get_state_reply(xdrs,
				    (ndmp_mover_get_state_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_MOVER_LISTEN:
			if (req_reply_flag == REPLY)
				xdr_ndmp_mover_listen_reply(xdrs,
				    (ndmp_mover_listen_reply *)objp);
			else
				xdr_ndmp_mover_listen_request(xdrs,
				    (ndmp_mover_listen_request *)objp);
			break;
		case NDMP_MOVER_CONTINUE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_mover_continue_reply(xdrs,
				    (ndmp_mover_continue_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_MOVER_ABORT:
			if (req_reply_flag == REPLY)
				xdr_ndmp_mover_abort_reply(xdrs,
				    (ndmp_mover_abort_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_MOVER_STOP:
			if (req_reply_flag == REPLY)
				xdr_ndmp_mover_stop_reply(xdrs,
				    (ndmp_mover_stop_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_MOVER_SET_WINDOW:
			if (req_reply_flag == REPLY)
				xdr_ndmp_mover_set_window_reply(xdrs,
				    (ndmp_mover_set_window_reply *)objp);
			else
				xdr_ndmp_mover_set_window_request(xdrs,
				    (ndmp_mover_set_window_request *)objp);
			break;
		case NDMP_MOVER_READ:
			if (req_reply_flag == REPLY)
				xdr_ndmp_mover_read_reply(xdrs,
				    (ndmp_mover_read_reply *)objp);
			else
				xdr_ndmp_mover_read_request(xdrs,
				    (ndmp_mover_read_request *)objp);
			break;
		case NDMP_MOVER_CLOSE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_mover_close_reply(xdrs,
				    (ndmp_mover_close_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_MOVER_SET_RECORD_SIZE:
			if (req_reply_flag == REPLY)
				xdr_ndmp_mover_set_record_size_reply(xdrs,
				    (ndmp_mover_set_record_size_reply *)objp);
			else
				xdr_ndmp_mover_set_record_size_request(xdrs,
				    (ndmp_mover_set_record_size_request *)objp);
			break;
		case NDMP_MOVER_CONNECT:
			if (req_reply_flag == REPLY)
				xdr_ndmp_mover_connect_reply(xdrs,
				    (ndmp_mover_connect_reply *)objp);
			else
				xdr_ndmp_mover_connect_request(xdrs,
				    (ndmp_mover_connect_request *)objp);
			break;
		case NDMP_DATA_ABORT:
			if (req_reply_flag == REPLY)
				xdr_ndmp_data_abort_reply(xdrs,
				    (ndmp_data_abort_reply *)objp);
			else {
				ndmp_dprintf(log, "Invalid  req_reply_flag"
				    "xdr request structure is NULL\n");
				return (E_XDR_REQ_NOT_FOUND);
			}
			break;
		case NDMP_CONFIG_SET_EXT_LIST:
			if (req_reply_flag == REPLY)
				xdr_ndmp_config_set_ext_list_reply(xdrs,
				    (ndmp_config_set_ext_list_reply *)objp);
			else
				xdr_ndmp_config_set_ext_list_request(xdrs,
				    (ndmp_config_set_ext_list_request *)objp);
			break;
		case NDMP_CONNECT_SERVER_AUTH:
			if (req_reply_flag == REPLY)
				xdr_ndmp_connect_server_auth_reply(xdrs,
				    (ndmp_connect_server_auth_reply *)objp);
			else
				xdr_ndmp_connect_server_auth_request(xdrs,
				    (ndmp_connect_server_auth_request *)objp);
			break;
		default:
			ndmp_dprintf(log, "Invalid Messagecode \n");
	}
	return (SUCCESS);
}

/*
 * readit() method is used by xdrrec_create() to read from stream
 * Args are     :
 * sd           : Socket descriptor
 * buf          : Buffer
 * len          : Len of bytes to be read from stream
 * Return Value : Returns of no.of bytes read
 */

int
readit(void *psd, char *buf, int len)
{
	int *sd = (int *)psd;
	len = read(*sd, buf, len);
	if (len <= 0) {
		conn_eof = TRUE;
		return (-1);
	}
	return (len);
}

/*
 * writeit() method is used by xdrrec_create() to write to stream
 * Args are     :
 * sd           : Socket descriptor
 * buf          : Buffer
 * len          : Len of bytes to be written on stream
 * Return Value : Returns of no.of bytes written
 */

int
writeit(void *psd, char *buf, int len)
{

	int *sd = (int *)psd;
	len = write(*sd, buf, len);
	if (len < 0) {
		conn_eof = TRUE;
		return (-1);
	}
	return (len);

}

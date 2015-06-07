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

#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <ndmp.h>
#include <ndmp_connect.h>
#include <log.h>

int initialize_handletable(handletable *);
int open_socket(host_info *, sock_handle *, FILE *);
int xdr_initialize(xdr_info *, FILE *);
int send_request(handletable *, XDR *, void *, ndmp_message, FILE *);
int recieve_reply(handletable *, XDR *, void **, ndmp_message, notify_qrec **,
    FILE *);
void * recieve_notification(handletable *, XDR *, notify_qrec *, ndmp_message,
    FILE *log);
conn_table * get_connection(conn_table *, conn_handle *, FILE *);
int create_conntable(conn_table *, xdr_info *, conn_handle *, FILE *);
int insert_connection(conn_table *, xdr_info *, conn_handle *, FILE *);
conn_table * delete_connection(conn_table *, conn_handle *, FILE *);
int authenticate_connection(handletable *, host_info *, conn_table *,
    conn_handle *, ndmp_connect_client_auth_reply **, notify_qrec *, FILE *);
handletable * getmessage_handle(handletable *, ndmp_message, FILE *);
int client_connect_open(host_info *, conn_handle *,
    ndmp_connect_open_reply **, FILE *);
int client_connect_authorize(host_info *, conn_handle *,
    ndmp_connect_client_auth_reply **, FILE *);
int client_connect_close(conn_handle *, FILE *);

/*
 * Global variables
 * conn_table   : connection table containing the current open connections
 * handletable  : Handle table containing the xdr method function pointers
 */
conn_table *conntbl = NULL;

handletable handletbl[120];
notify_qrec *qlist = NULL;

int
client_connect_open(host_info *hostinfo, conn_handle *conn,
    ndmp_connect_open_reply **reply, FILE *loghandle)
{
	if (conntbl == NULL) {
		conntbl = (conn_table *) malloc(sizeof (conn_table));
		conntbl->conn = (conn_handle *) malloc(sizeof (conn_handle));
		conntbl->xdrinfo = (xdr_info *) malloc(sizeof (xdr_info));
		conntbl->xdrinfo->xdrs = (XDR *) malloc(sizeof (XDR));
		conntbl->next = conntbl;
	}
	ndmp_message messagecode = NDMP_CONNECT_OPEN;

	initialize_handletable(handletbl);
	conn_table *tbl = NULL;

	/* Get the connection object from the conenction table */
	if (conntbl->next != conntbl) {
		tbl = get_connection(conntbl, conn,
		    loghandle);
	}


	/* Check if the connection found in connection table or not */

	if (tbl != NULL) {
		ndmp_connect_open_request *ndmp_con =
		    (ndmp_connect_open_request *)
		    malloc(sizeof (ndmp_connect_open_request));

		ndmp_con->protocol_version = hostinfo->protocol_version;

		/* Call the process request method to process the request */

		if (process_request(ndmp_con, messagecode, tbl->conn,
								(void **)reply,
		    loghandle) == SUCCESS) {
			ndmp_dprintf(loghandle, "open_connection():"
			    "Process Request success \n");
		} else {
			ndmp_dprintf(loghandle, "open_connection(): "
			    "Process request failed \n");
			return (ERROR);
		}
		return (SUCCESS);
	}

	/* Define sock_handle structure and open the socket */

	sock_handle *shandle = (sock_handle *) malloc(sizeof (sock_handle));

	int ret = open_socket(hostinfo, shandle, loghandle);

	if (ret != SUCCESS) {
		ndmp_fprintf(loghandle, "open_socket Failed with "
		    "ERROR : %d \n", ret);

		return (ERROR);
	}

	/* Assign the sd to conntbl->sd */

	xdr_info *xinfo = (xdr_info *) malloc(sizeof (xdr_info));
	xinfo->xdrs = (XDR *) malloc(sizeof (XDR));
	xinfo->sd = shandle->sd;

	/* Call xdr_initialize method to do the initialization of XDR pointer */

	xdr_initialize(xinfo, loghandle);

	if (conntbl->next == conntbl) {
		create_conntable(conntbl, xinfo, conn, loghandle);
		ndmp_dprintf(loghandle, "open_connection ():"
		    "Create connection table success \n");
	} else if (insert_connection(conntbl, xinfo, conn, loghandle)
	    == SUCCESS) {
		ndmp_dprintf(loghandle, "open_connection ():"
		    "Insert table success \n");
	}
	/* Define the request structure and allocate memory */

	ndmp_connect_open_request *ndmp_con = (ndmp_connect_open_request *)
	    malloc(sizeof (ndmp_connect_open_request));


	ndmp_con->protocol_version = hostinfo->protocol_version;

	/* Call the process request method to process the request */

	if (process_request(ndmp_con, messagecode, conn, (void **)reply,
	    loghandle) == SUCCESS) {
		ndmp_dprintf(loghandle, "open_connection():"
		    "Process Request success \n");
	} else {
		ndmp_dprintf(loghandle, "open_connection(): "
		    "Process request failed \n");
		return (ERROR);
	}
	return (SUCCESS);
}

int
client_connect_authorize(host_info *hostinfo, conn_handle *conn,
    ndmp_connect_client_auth_reply **reply, FILE *loghandle)
{

	int ret = authenticate_connection(handletbl, hostinfo, conntbl,
	    conn, reply, qlist, loghandle);

	if (ret == SUCCESS) {
		ndmp_dprintf(loghandle, "open_connection(): Connection "
		    "authentication Successful \n");
	} else {
		ndmp_dprintf(loghandle, "open_connection () :Connection "
		    "authentication Failed and error is %d \n", ret);
		return (ERROR);
	}

	return (SUCCESS);
}

int
client_connect_close(conn_handle *conn, FILE *log)
{
	/* Define and send the NDMP_CONNECT_CLOSE request to server */

	ndmp_message messagecode = NDMP_CONNECT_CLOSE;

	void *req_close = NULL;
	void *reply_close = NULL;
	/* Call the process request method to process the request */

	if (process_request(req_close, messagecode, conn, &reply_close, log)
	    == SUCCESS) {
		ndmp_dprintf(log,
		    "close_connection():Process Request success\n");
	} else {
		ndmp_dprintf(log,
		    "close_connection(): Process request failed\n");
		return (ERROR);
	}

	/* Wait for NOTIFY_CONNECT_CLOSE notification */

	messagecode = NDMP_NOTIFY_CONNECTION_STATUS;
	notify_qrec *temp = NULL;
	if (process_notification(conn, messagecode, &temp, log) == SUCCESS) {
		ndmp_dprintf(log,
		    "close_connection():Got NOTIFY_CONNECT_CLOSE\n");
	} else {
		ndmp_dprintf(log,
		    "close_connection(): Notification not found \n");
		return (E_NOTIFY_NOT_FOUND);
	}

	/* Delete the connection once recieving above notification */
	conntbl = (conn_table *) delete_connection(conntbl, conn, log);
	/* Delete the notification queue */

	if (delete_queue(&qlist, log) == SUCCESS) {
		ndmp_dprintf(log,
		    "close_connection():Delete notificaiton queue success\n");
	} else {
		ndmp_dprintf(log,
		    "close_connection(): Delete notificaiton queue failed\n");
	}
	return (SUCCESS);
}

int
server_connect_auth(host_info *hostinfo, conn_handle *conn,
    ndmp_connect_server_auth_reply **reply, FILE *log)
{
	ndmp_message messagecode = NDMP_CONNECT_SERVER_AUTH;

	ndmp_connect_server_auth_request *req =
	    (ndmp_connect_server_auth_request *) malloc
	    (sizeof (ndmp_connect_server_auth_request));
	memset(req, 0, sizeof (ndmp_connect_server_auth_request));

	req->client_attr.auth_type = hostinfo->auth_type;

	strcpy(req->client_attr.ndmp_auth_attr_u.challenge,
	    hostinfo->server_challenge);
	if (process_request(req, messagecode, conn, (void **)reply,
	    log) == SUCCESS) {
		ndmp_dprintf(log, "open_connection():"
		    "Process Request success \n");
	} else {
		ndmp_dprintf(log, "open_connection(): "
		    "Process request failed \n");
		return (ERROR);
	}
	return (SUCCESS);
}

/*
 * open_connection () method opens connection to the NDMP server
 * Args are     :
 * hostinfo     : host information like IP, UserName and Password
 * conn         : connection handle
 * loghandle    : Log handle
 * Return Value : returns SUCCESS(0): Success ERROR(1):Failure
 */

int
open_connection(host_info *hostinfo, conn_handle *conn, FILE *loghandle)
{

	/* Initialize the conntable and allocate memory for first time */

	void *reply = NULL;


	int ret_connect = client_connect_open(hostinfo, conn,
				(ndmp_connect_open_reply **)&reply,
	    loghandle);
	if (ret_connect == SUCCESS) {
		ndmp_dprintf(loghandle, "Connection established \n");
	} else {
		ndmp_dprintf(loghandle, "Connecction failed \n");
		return (ERROR);
	}
	/* Authenticate the connection and check results */

	ndmp_dprintf(loghandle, "open_connection () : End of send request \n");

	void *reply_auth = NULL;
	int ret = authenticate_connection(handletbl, hostinfo, conntbl,
	    conn, (ndmp_connect_client_auth_reply **)&reply_auth, qlist,
								loghandle);
	if (ret == SUCCESS) {
		ndmp_dprintf(loghandle, "open_connection():"
		    "Connection authenticatio Successful \n");
	} else {
		ndmp_dprintf(loghandle, "open_connection () :"
		    "Connection authentication Failed and error is %d \n", ret);
		return (ERROR);
	}

	return (SUCCESS);
}

/*
 * close_connection() method closes the connection to the server and deletes
 * connection object from the connection table and also frees up the allocated
 * memory.
 * Args are     :
 * conn         : Connection object to be deleted
 * log          : Log file handle
 * Return Value : returns pointer to the connection table after deletion
 */

int
close_connection(conn_handle *conn, FILE *log)
{

	/* Define and send the NDMP_CONNECT_CLOSE request to server */

	int ret = client_connect_close(conn, log);
	return (ret);

}

/*
 * process_request() method process, send the requests and process reply
 * Args are     :
 * request      : Request structure
 * messagecode  : Message code to be processed
 * conn         : Connection handle
 * reply        : Reply structure
 * log          : Log handle
 * Return Value : returns SUCCESS(0): Success ERROR(1):Failure
 */

int
process_request(void *request, ndmp_message messagecode, conn_handle *conn,
    void **reply, FILE *log)
{

	/* Get the connection object from the conenction table */

	conn_table *tbl = (conn_table *) get_connection(conntbl, conn, log);

	/* Check if the connection found in connection table or not */

	if (tbl == NULL) {
		return (E_CONN_NOTFOUND);
	}
	if (tbl->xdrinfo->xdrs == NULL) {
		ndmp_dprintf(log, "process_request (): connection not found or "
		    "connection table is null \n");
		return (E_CONN_NOTFOUND);
	}

	/* Call send_request method and check the result */

	int ret = send_request(handletbl, tbl->xdrinfo->xdrs, request,
	    messagecode, log);

	if (ret == SUCCESS) {
		ndmp_dprintf(log,
		    "process_request ():Send request Successful\n");

	} else {
		ndmp_dprintf(log, "process_request ():"
		    "Send request Failed and error is %d\n", ret);
		return (ERROR);
	}

	if (ret == SUCCESS && messagecode == NDMP_CONNECT_CLOSE) {
		return (SUCCESS);
	}

	/* Call recieve reply method and check the result */
	ret = recieve_reply(handletbl, tbl->xdrinfo->xdrs, reply, messagecode,
	    &qlist, log);
	if (ret == SUCCESS && (*reply) != NULL) {
		ndmp_dprintf(log,
		    "process_request : reply success or AUTH_FAILURE\n");
	} else {
		ndmp_dprintf(log,
		    "process_request : receive reply failed and error is "
		    "%d\n", ret);
		return (ret);
	}

	return (SUCCESS);
}

/*
 * process_notification() method process the notifications
 * Args are     :
 * conn         : Connection handle
 * log          : Log handle
 * Return Value : returns SUCCESS(0): Success ERROR(1):Failure
 */

int
process_notification(conn_handle *conn, ndmp_message messagecode,
    notify_qrec **ret_qlist, FILE *log)
{
	/* Get the connection object from the conenction table */
	conn_table *tbl = (conn_table *) get_connection(conntbl, conn, log);

	ndmp_dprintf(log, "Before calling recieve_notification \n");

	/* Search the notification queue if it allready exisits */

	notify_qrec *pre_notify = search_element(qlist, messagecode, log);
	if (pre_notify == NULL) {
		/*
		 * Call the recieve_notification method to get notification
		 * queue
		 */
		qlist = (void *) recieve_notification(handletbl,
		    tbl->xdrinfo->xdrs, qlist, messagecode, log);
		pre_notify = search_element(qlist, messagecode, log);
	}
	/* Assign the return queue pointer to the qlist pointer */

	*ret_qlist = qlist;

	if (pre_notify == NULL) {
		return (E_NOTIFY_NOT_FOUND);
	} else {
		return (SUCCESS);
	}

}
#ifdef UNIT_TEST_NDMP_CONNECT

int
main(int argc, char ** argv)
{
	unit_test_ndmp_connect();
	unit_test_authenticate();
	unit_test_connect_interface();
	return (SUCCESS);
}

int
unit_test_ndmp_connect()
{

	log_level = 2;
	printf("Am in main \n");

	host_info *hostinfo = (host_info *) malloc(sizeof (host_info));


	hostinfo->ipAddr = "10.12.178.122";
	hostinfo->userName = "admin";
	hostinfo->password = "admin";
	hostinfo->auth_type = NDMP_AUTH_TEXT;

	/* Define and initialize conn_handle table */

	conn_handle *conn = (conn_handle *) malloc(sizeof (conn_handle));

	conn->connhandle = 100;

	/* Define the log file handle */
	FILE *log;
	log = fopen("log.out", "w+");

	if (log == NULL) {
		printf("Log file does not exist \n");
		exit(0);
	}
	open_connection(hostinfo, conn, log);

	printf("Vilas : After open_connection The connection handle is %d \n",
	    conn->connhandle);

	void *reply = NULL;

	ndmp_message messagecode = NDMP_DATA_GET_STATE;

	void *ndmp_con = NULL;

	printf("BEFORE SENDING NDMP_DATA_GET_STATE \n");

	process_request(ndmp_con, messagecode, conn, &reply, log);

	ndmp_data_get_state_reply *temp = (ndmp_data_get_state_reply *) reply;

	fclose(log);

	printf("The reply structre is ----- > \n");
	printf("The reply error is %d          \n", temp->error);

	/* NDMP_TAPE_OPEN */
	messagecode = NDMP_TAPE_OPEN;
	ndmp_tape_open_request *req_tape = (ndmp_tape_open_request *) malloc
	    (sizeof (ndmp_tape_open_request));
	req_tape->device = (char *)malloc(sizeof ("/dev/rmt/3n"));
	strcpy(req_tape->device, "/dev/rmt/3n");
	req_tape->mode = 1;
	void *reply_tape = NULL;
	process_request(req_tape, messagecode, conn, &reply_tape, log);
	ndmp_tape_open_reply *rep_tape = (ndmp_tape_open_reply *) reply_tape;
	printf("The tape_open reply error is %d \n", rep_tape->error);

	/* NDMP_DATA_LISTEN */

	messagecode = NDMP_DATA_LISTEN;
	ndmp_data_listen_request *req_data = (ndmp_data_listen_request *) malloc
	    (sizeof (ndmp_data_listen_request));
	req_data->addr_type = 0;
	void *reply_data = NULL;
	process_request(req_data, messagecode, conn, &reply_data, log);
	ndmp_data_listen_reply *rep_data = (ndmp_data_listen_reply *)
	    reply_data;
	printf("The data_listen reply error is %d \n", rep_data->error);
	/* NDMP_MOVER_CONNECT */

	messagecode = NDMP_MOVER_CONNECT;
	void *reply_mover = NULL;
	ndmp_mover_connect_request *req = (ndmp_mover_connect_request *) malloc
	    (sizeof (ndmp_mover_connect_request));
	req->mode = 0;
	req->addr.addr_type = 0;
	printf("Before sending mover_connect \n");
	process_request(req, messagecode, conn, &reply_mover, log);
	printf("Reply of mover_connect is \n");
	ndmp_mover_connect_reply *shen = (ndmp_mover_connect_reply *)
	    reply_mover;
	printf("Reply error is %d \n", shen->error);

	/* CLOSE THE CONNECTION */

	printf("Before sending the close_connection request \n");
	close_connection(conn, log);
	printf("After sending the close_connection request \n");


	/* Call again open connection with diff conn handle */
	conn_handle *conn2 = (conn_handle *) malloc(sizeof (conn_handle));

	conn2->connhandle = 200;

	open_connection(hostinfo, conn2, log);

	print_conntable(conntbl);

	/* call again opne connection with diff connection handle */
	conn_handle *conn3 = (conn_handle *) malloc(sizeof (conn_handle));

	conn3->connhandle = 300;

	open_connection(hostinfo, conn3, log);

	print_conntable(conntbl);

	conn3->connhandle = 27;

	close_connection(conn3, log);

	print_conntable(conntbl);

	open_connection(hostinfo, conn3, log);

	print_conntable(conntbl);
	return (SUCCESS);
}

int
unit_test_authenticate()
{
	log_level = 2;
	printf("Am in main \n");

	host_info *hostinfo = (host_info *) malloc(sizeof (host_info));


	hostinfo->ipAddr = "10.12.178.122";
	hostinfo->userName = "admin";
	hostinfo->password = "admin";
	hostinfo->auth_type = NDMP_AUTH_TEXT;

	/* Define and initialize conn_handle table */

	conn_handle conn;

	conn.connhandle = 100;

	/* Define the log file handle */
	FILE *log;
	log = fopen("log.out", "w+");

	if (log == NULL) {
		printf("Log file does not exist \n");
		exit(0);
	}
	open_connection(hostinfo, &conn, log);

	printf("Vilas : 1st open_connection The connection handle is %d \n",
	    conn.connhandle);
	print_conntable(conntbl);
	void *reply = NULL;
	void *req_ext = NULL;
	ndmp_message messagecode = NDMP_CONFIG_GET_EXT_LIST;
	process_request(req_ext, messagecode, &conn, &reply, log);
	printf("After process_request \n");
	if (reply == NULL)
		printf("Reply is NULL \n");

	ndmp_config_get_ext_list_reply *shen =
	    (ndmp_config_get_ext_list_reply *) reply;
	printf("Reply error is 0x%x \n", shen->error);

	messagecode = NDMP_CONFIG_SET_EXT_LIST;


	ndmp_config_set_ext_list_request *ndmp_con =
	    (ndmp_config_set_ext_list_request *) malloc
	    (sizeof (ndmp_config_set_ext_list_request));
	ndmp_con->ndmp_selected_ext.ndmp_selected_ext_val =
	    (ndmp_class_version *) malloc(sizeof (ndmp_class_version));
	ndmp_con->ndmp_selected_ext.ndmp_selected_ext_val->ext_version =
	    6;
	ndmp_con->ndmp_selected_ext.ndmp_selected_ext_val->ext_class_id =
	    0;
	ndmp_con->ndmp_selected_ext.ndmp_selected_ext_len =
	    sizeof (ndmp_class_version);
	reply = NULL;

	process_request(ndmp_con, messagecode, &conn, &reply, log);
	printf("After process_request \n");
	ndmp_config_set_ext_list_reply *vils =
	    (ndmp_config_set_ext_list_reply *) reply;
	printf("Reply after ext_list is %d \n", vils->error);
	close_connection(&conn, log);
	ndmp_data_get_state_reply *temp = (ndmp_data_get_state_reply *) reply;
	printf("Before sending open connection \n");
	open_connection(hostinfo, &conn, log);
	printf("After sending open connection\n");
	printf("Vilas : 2nd open_connection The connection handle is %d \n",
	    conn.connhandle);
	print_conntable(conntbl);
	printf("Before sending NDMP_MOVER_CONTINUE \n");
	void *data_req = NULL;
	messagecode = NDMP_MOVER_CONTINUE;
	void *reply_data = NULL;
	process_request(ndmp_con, messagecode, &conn, &reply, log);
	printf("After sending  NDMP_MOVER_CONTINUE\n");
	close_connection(&conn, log);
	open_connection(hostinfo, &conn, log);
	print_conntable(conntbl);
	close_connection(&conn, log);
	print_conntable(conntbl);
	close_connection(&conn, log);
	print_conntable(conntbl);
	print_conntable(conntbl);
	return (SUCCESS);
}

int
unit_test_connect_interface()
{

	log_level = 2;
	printf("Am in main \n");

	host_info *hostinfo = (host_info *) malloc(sizeof (host_info));
	memset(hostinfo, 0, sizeof (host_info));

	hostinfo->ipAddr = "10.12.178.122";
	hostinfo->userName = "admin";
	hostinfo->password = "admin";
	hostinfo->auth_type = NDMP_AUTH_TEXT;
	hostinfo->protocol_version = 4;
	strcpy(hostinfo->server_challenge, "0");

	/* Define and initialize conn_handle table */

	conn_handle *conn = (conn_handle *) malloc(sizeof (conn_handle));

	conn->connhandle = 0;

	/* Define the log file handle */
	FILE *log;
	log = fopen("log.out", "w+");

	if (log == NULL) {
		printf("Log file does not exist \n");
		exit(0);
	}
	printf("Before the client connect interfaces \n");
	void *reply = NULL;
	int ret = client_connect_open(hostinfo, conn, &reply, log);
	printf("Return value is %d \n", ret);
	notify_qrec *ret_qlist = NULL;
	ndmp_message messagecode = NDMP_NOTIFY_CONNECTION_STATUS;
	ret = process_notification(conn, messagecode, &ret_qlist, log);
	printf("process_notification ret val = %d \n", ret);
	notify_qrec *objp = search_element(ret_qlist, messagecode, log);
	ndmp_notify_connection_status_post *post =
	    (ndmp_notify_connection_status_post *)(objp->notify);
	printf("The reason is %d \n", post->reason);
	/* NDMP_SHUTDOWN */
	ret = client_connect_close(conn, log);
	printf("The return value is %d \n", ret);

	ndmp_connect_client_auth_reply *reply_auth = NULL;
	client_connect_authorize(hostinfo, conn, &reply_auth, log);
	printf("Reply client_connect_authorize is %d\n", reply_auth->error);
	ndmp_connect_server_auth_reply *reply_server = NULL;
	ret = server_connect_auth(hostinfo, conn, &reply_server, log);
	client_connect_close(conn, log);
	void *reply_get = NULL;

	messagecode = NDMP_DATA_GET_STATE;

	void *ndmp_con = NULL;

	printf("BEFORE SENDING NDMP_DATA_GET_STATE \n");

	process_request(ndmp_con, messagecode, conn, &reply_get, log);

	void *reply2 = NULL;

	hostinfo->protocol_version = 4;
	client_connect_open(hostinfo, conn, &reply2, log);
	printf("conhandle : 2nd time is %d \n", conn->connhandle);
	ndmp_connect_open_reply *rep2 = (ndmp_connect_open_reply *) reply2;
	printf("Reply error is %d \n", rep2->error);

}
#endif

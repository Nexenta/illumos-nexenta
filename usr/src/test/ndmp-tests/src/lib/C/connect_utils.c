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

#include <ndmp.h>
#include <ndmp_connect.h>
#include <log.h>
#include <stdlib.h>

handletable * getmessage_handle(handletable *, ndmp_message, FILE *);
int initialize_handletable(handletable *);
conn_table * get_connection(conn_table *, conn_handle *, FILE *);
int create_conntable(conn_table *, xdr_info *, conn_handle *, FILE *);
int getrandom_num();
int insert_connection(conn_table *, xdr_info *, conn_handle *, FILE *);
void print_conntable(conn_table *);
conn_table * delete_connection(conn_table *, conn_handle *, FILE *);

/*
 * getmessage_handle() method gets the handletable entry for the messagecode
 * Args are     :
 * tbl          : Handle table
 * messagecode  : NDMP messagecode to be searched
 * loghandle    : Log handle
 * Return Value : returns the pointer to the handletable structure
 */

handletable * getmessage_handle(handletable *tbl, ndmp_message messagecode,
    FILE *log)
{

	while (tbl) {

		if (tbl->messagecode == messagecode) {
			ndmp_dprintf(log,
			    "Message code %x found & returning struct\n",
			    tbl->messagecode);
			return (tbl);
		}
		tbl++;
	}
	return (NULL);
}

/*
 * initialize_handletable() method initializes the handletable entries with the
 * messagecode, reply structure size and xdr encode/decode function pointers.
 * This table is populated here and will remain constant.
 * Args are     :
 * tbl          : Handle table
 * Return Value : returns SUCCESS(0): Success ERROR(1):Failure
 */

int
initialize_handletable(handletable *tbl)
{
	/* Initialize the handletable with all the ndmp interface xdr methods */

	tbl[0].messagecode = NDMP_CONNECT_OPEN;
	tbl[0].replysize = sizeof (ndmp_connect_open_reply);

	tbl[1].messagecode = NDMP_CONFIG_GET_SERVER_INFO;
	tbl[1].replysize = sizeof (ndmp_config_get_server_info_reply);

	tbl[2].messagecode = NDMP_NOTIFY_CONNECTION_STATUS;
	tbl[2].replysize = sizeof (ndmp_notify_connection_status_post);

	tbl[3].messagecode = NDMP_CONFIG_GET_SERVER_INFO;
	tbl[3].replysize = sizeof (ndmp_config_get_server_info_reply);

	tbl[4].messagecode = NDMP_CONNECT_CLIENT_AUTH;
	tbl[4].replysize = sizeof (ndmp_connect_client_auth_reply);

	tbl[5].messagecode = NDMP_CONNECT_CLOSE;
	tbl[5].replysize = 0;

	tbl[6].messagecode = NDMP_CONFIG_GET_HOST_INFO;
	tbl[6].replysize = sizeof (ndmp_config_get_host_info_reply);

	tbl[7].messagecode = NDMP_CONFIG_GET_CONNECTION_TYPE;
	tbl[7].replysize = sizeof (ndmp_config_get_connection_type_reply);

	tbl[8].messagecode = NDMP_CONFIG_GET_AUTH_ATTR;
	tbl[8].replysize = sizeof (ndmp_config_get_auth_attr_reply);

	tbl[9].messagecode = NDMP_CONFIG_GET_BUTYPE_INFO;
	tbl[9].replysize = sizeof (ndmp_config_get_butype_attr_reply);

	tbl[10].messagecode = NDMP_CONFIG_GET_FS_INFO;
	tbl[10].replysize = sizeof (ndmp_config_get_fs_info_reply);

	tbl[11].messagecode = NDMP_CONFIG_GET_TAPE_INFO;
	tbl[11].replysize = sizeof (ndmp_config_get_tape_info_reply);

	tbl[12].messagecode = NDMP_CONFIG_GET_SCSI_INFO;
	tbl[12].replysize = sizeof (ndmp_config_get_scsi_info_reply);

	tbl[13].messagecode = NDMP_CONFIG_GET_EXT_LIST;
	tbl[13].replysize = sizeof (ndmp_config_get_ext_list_reply);

	tbl[14].messagecode = NDMP_SCSI_OPEN;
	tbl[14].replysize = sizeof (ndmp_scsi_open_reply);

	tbl[15].messagecode = NDMP_SCSI_CLOSE;
	tbl[15].replysize = sizeof (ndmp_scsi_close_reply);

	tbl[16].messagecode = NDMP_SCSI_GET_STATE;
	tbl[16].replysize = sizeof (ndmp_scsi_get_state_reply);

	tbl[17].messagecode = NDMP_SCSI_RESET_DEVICE;
	tbl[17].replysize = sizeof (ndmp_scsi_reset_device_reply);

	tbl[18].messagecode = NDMP_SCSI_EXECUTE_CDB;
	tbl[18].replysize = sizeof (ndmp_execute_cdb_reply);

	tbl[19].messagecode = NDMP_TAPE_OPEN;
	tbl[19].replysize = sizeof (ndmp_tape_open_reply);

	tbl[20].messagecode = NDMP_TAPE_CLOSE;
	tbl[20].replysize = sizeof (ndmp_tape_close_reply);

	tbl[21].messagecode = NDMP_TAPE_GET_STATE;
	tbl[21].replysize = sizeof (ndmp_tape_get_state_reply);

	tbl[22].messagecode = NDMP_TAPE_MTIO;
	tbl[22].replysize = sizeof (ndmp_tape_mtio_reply);

	tbl[23].messagecode = NDMP_TAPE_WRITE;
	tbl[23].replysize = sizeof (ndmp_tape_write_reply);

	tbl[24].messagecode = NDMP_TAPE_READ;
	tbl[24].replysize = sizeof (ndmp_tape_read_reply);

	tbl[25].messagecode = NDMP_TAPE_EXECUTE_CDB;
	tbl[25].replysize = sizeof (ndmp_tape_execute_cdb_reply);

	tbl[26].messagecode = NDMP_DATA_GET_STATE;
	tbl[26].replysize = sizeof (ndmp_data_get_state_reply);

	tbl[27].messagecode = NDMP_DATA_START_BACKUP;
	tbl[27].replysize = sizeof (ndmp_data_start_backup_reply);

	tbl[28].messagecode = NDMP_DATA_START_RECOVER;
	tbl[28].replysize = sizeof (ndmp_data_start_recover_reply);

	tbl[29].messagecode = NDMP_DATA_GET_ENV;
	tbl[29].replysize = sizeof (ndmp_data_get_env_reply);

	tbl[30].messagecode = NDMP_DATA_STOP;
	tbl[30].replysize = sizeof (ndmp_data_stop_reply);

	tbl[31].messagecode = NDMP_DATA_LISTEN;
	tbl[31].replysize = sizeof (ndmp_data_listen_reply);

	tbl[32].messagecode = NDMP_DATA_CONNECT;
	tbl[32].replysize = sizeof (ndmp_data_connect_reply);

	tbl[33].messagecode = NDMP_DATA_START_RECOVER_FILEHIST;
	tbl[33].replysize = sizeof (ndmp_data_start_recover_reply);

	tbl[34].messagecode = NDMP_NOTIFY_DATA_HALTED;
	tbl[34].replysize = sizeof (ndmp_notify_data_halted_post);

	tbl[35].messagecode = NDMP_NOTIFY_MOVER_HALTED;
	tbl[35].replysize = sizeof (ndmp_notify_mover_halted_post);

	tbl[36].messagecode = NDMP_NOTIFY_MOVER_PAUSED;
	tbl[36].replysize = sizeof (ndmp_notify_mover_paused_post);

	tbl[37].messagecode = NDMP_NOTIFY_DATA_READ;
	tbl[37].replysize = sizeof (ndmp_notify_data_read_post);

	tbl[38].messagecode = NDMP_LOG_FILE;
	tbl[38].replysize = sizeof (ndmp_log_file_post);

	tbl[39].messagecode = NDMP_LOG_MESSAGE;
	tbl[39].replysize = sizeof (ndmp_log_message_post);

	tbl[40].messagecode = NDMP_FH_ADD_FILE;
	tbl[40].replysize = sizeof (ndmp_fh_add_file_post);

	tbl[41].messagecode = NDMP_FH_ADD_DIR;
	tbl[41].replysize = sizeof (ndmp_fh_add_dir_post);

	tbl[42].messagecode = NDMP_FH_ADD_NODE;
	tbl[42].replysize = sizeof (ndmp_fh_add_node_post);

	tbl[43].messagecode = NDMP_MOVER_GET_STATE;
	tbl[43].replysize = sizeof (ndmp_mover_get_state_reply);

	tbl[44].messagecode = NDMP_MOVER_LISTEN;
	tbl[44].replysize = sizeof (ndmp_mover_listen_reply);

	tbl[45].messagecode = NDMP_MOVER_CONTINUE;
	tbl[45].replysize = sizeof (ndmp_mover_continue_reply);

	tbl[46].messagecode = NDMP_MOVER_ABORT;
	tbl[46].replysize = sizeof (ndmp_mover_abort_reply);

	tbl[47].messagecode = NDMP_MOVER_STOP;
	tbl[47].replysize = sizeof (ndmp_mover_stop_reply);

	tbl[48].messagecode = NDMP_MOVER_SET_WINDOW;
	tbl[48].replysize = sizeof (ndmp_mover_set_window_reply);

	tbl[49].messagecode = NDMP_MOVER_READ;
	tbl[49].replysize = sizeof (ndmp_mover_read_reply);

	tbl[50].messagecode = NDMP_MOVER_CLOSE;
	tbl[50].replysize = sizeof (ndmp_mover_close_reply);

	tbl[51].messagecode = NDMP_MOVER_SET_RECORD_SIZE;
	tbl[51].replysize = sizeof (ndmp_mover_set_record_size_reply);

	tbl[52].messagecode = NDMP_MOVER_CONNECT;
	tbl[52].replysize = sizeof (ndmp_mover_connect_reply);

	tbl[53].messagecode = NDMP_DATA_ABORT;
	tbl[53].replysize = sizeof (ndmp_data_abort_reply);

	tbl[54].messagecode = NDMP_CONFIG_SET_EXT_LIST;
	tbl[54].replysize = sizeof (ndmp_config_set_ext_list_reply);

	tbl[55].messagecode = NDMP_CONNECT_SERVER_AUTH;
	tbl[55].replysize = sizeof (ndmp_connect_server_auth_reply);

	return (SUCCESS);
}

/*
 * get_connection() method gets a pointer to the connection object from the
 * connection table
 * Args are     :
 * tbl          : Connection table
 * conn         : Connection handle to be searched
 * log          : Log file handle
 * Return Value : returns pointer to the connection table entry found
 */

conn_table *
    get_connection(conn_table *tbl, conn_handle *conn, FILE *log)
{

	ndmp_dprintf(log, "In getconnection method \n");

	if (tbl == NULL) {
		ndmp_dprintf(log, "getconnection(): connection tbl is null \n");
		return (NULL);
	}

	while (tbl) {
		if (tbl->conn->connhandle == conn->connhandle) {
			ndmp_dprintf(log, "getconnection(): "
			    "connection found \n");
			return (tbl);
		}
		tbl = tbl->next;
	}
	ndmp_dprintf(log, "getconnection (): connection not found in table \n");
	return (NULL);
}

/*
 * create_conntable() method creates the connection table to hold the connection
 * objects and inserts the first element in the connection table
 * Args are     :
 * conntbl2     : Connection table
 * xinfo        : Pointer to the xdr_info containing sd and xdr pointer
 * conn         : Connection object to be inserted in connection table
 * log          : Log file handle
 * Return Value : returns SUCCESS(0): Success ERROR(1):Failure
 */


int create_conntable(conn_table *conntbl2, xdr_info *xinfo, conn_handle *conn,
    FILE *log)
{
	/* Get the random number for the connection handle */

	conn->connhandle = getrandom_num();

	ndmp_dprintf(log, "Inside create_conntable connection handle is %d\n",
	    conn->connhandle);


	ndmp_dprintf(log, "conntable is null and creating conn_table \n");


	conntbl2->conn->connhandle = conn->connhandle;
	ndmp_dprintf(log, "connection handle is %d and conn id %d \n",
	    conntbl2->conn->connhandle, conn->connhandle);

	conntbl2->xdrinfo->xdrs = xinfo->xdrs;

	conntbl2->xdrinfo->sd = xinfo->sd;

	ndmp_dprintf(log, "socket desc is %d and xdr sock id  %d \n",
	    conntbl2->xdrinfo->sd, xinfo->sd);

	conntbl2->next = NULL;

	return (SUCCESS);

}

/*
 * getrandom_num() method generates random number each time when its called
 * This method is used to generate unique connection handle.
 * Return Value : returns random number generated
 */

int
getrandom_num()
{
	const int HIGH = 100;
	srand(time(NULL));
	return (random() % HIGH);
}

/*
 * insert_connection() method inserts connetion object into an exisiting
 * connection table
 * Args are     :
 * conntbl2     : Connection table
 * xinfo        : Pointer to the xdr_info containing sd and xdr pointer
 * conn         : Connection object to be inserted in connection table
 * log          : Log file handle
 * Return Value : returns SUCCESS(0): Success ERROR(1):Failure
 */

int
insert_connection(conn_table *conntbl, xdr_info *xinfo, conn_handle *conn,
    FILE *log)
{
	conn_table *temp = conntbl;

	conn->connhandle = getrandom_num();

	ndmp_dprintf(log, "Inside insert_connection : conn handle %d \n",
	    conn->connhandle);

	while (temp) {
		if (temp->next == NULL) {
			conn_table *new = (conn_table *)
			    malloc(sizeof (conn_table));

			new->conn = (conn_handle *)
			    malloc(sizeof (conn_handle));

			new->xdrinfo = (xdr_info *) malloc(sizeof (xdr_info));

			new->xdrinfo->xdrs = (XDR *) malloc(sizeof (XDR));

			new->conn->connhandle = conn->connhandle;

			new->xdrinfo->xdrs = xinfo->xdrs;

			new->xdrinfo->sd = xinfo->sd;

			new->next = NULL;

			temp->next = new;
			return (SUCCESS);

		}
		temp = temp->next;
	}

	return (ERROR);
}

/*
 * print_conntable() method prints the connection table entries
 * This method is used for debugging pursposes
 * Args are     :
 * conntbl      : Connection table
 * Return Value : returns void
 */

void
print_conntable(conn_table *conntbl)
{
	printf("Table contents are \n");

	while (conntbl) {

		printf("Connection handle is %d \n", conntbl->conn->connhandle);
		printf("Socket id is         %d \n", conntbl->xdrinfo->sd);
		conntbl = conntbl->next;
	}
}

/*
 * delete_connection() method frees up memory allocated for conn_table entries
 * and deletes the connection object from connection table
 * Args are     :
 * tbl          : Connection table
 * conn         : Connection object to be deleted
 * log          : Log file handle
 * Return Value : returns pointer to the connection table after deletion
 */

conn_table *
    delete_connection(conn_table *tbl, conn_handle *conn, FILE *log)
{
	conn_table *temp = tbl;
	conn_table *temp1 = temp;

	if (temp->next == NULL) {
		tbl = temp->next;

		/* close the socket */
		shutdown(temp->xdrinfo->sd, 2);
		free(temp->xdrinfo->xdrs);
		free(temp->xdrinfo);
		free(temp);
		ndmp_dprintf(log, "delete_connection():Deletion successful \n");
		return (tbl);
	}

	while (temp) {
		if ((temp->conn->connhandle == conn->connhandle)) {
			temp1->next = temp->next;
			/* Close the socket */
			shutdown(temp->xdrinfo->sd, 2);
			free(temp->xdrinfo->xdrs);
			free(temp->xdrinfo);
			free(temp);

			return (tbl);
		}
		temp1 = temp;
		temp = temp->next;
	}

	return (tbl);
}

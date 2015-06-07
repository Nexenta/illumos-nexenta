/*
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved. Use is subject
 * to license terms.
 */

/*
 * BSD 3 Clause License
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met: - Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * - Neither the name of Sun Microsystems, Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from this
 * software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY SUN MICROSYSTEMS, INC. ''AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL SUN MICROSYSTEMS, INC. BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * Copyright 2015 Nexenta Systems, Inc. All rights reserved.
 */

/*
 * Config Interface allows the DMA to discover the configuration of the NDMP
 * Server. This files implements all the config interfaces.
 */

#include<stdio.h>
#include<string.h>

#include <ndmp.h>
#include <ndmp_lib.h>
#include <ndmp_comm_lib.h>
#include <log.h>
#include <ndmp_connect.h>
#include <ndmp_conv.h>


/*
 * ndmp_config_get_host_info_reply_print() :
 * Prints the reply object structure. This object gets
 * printed twice in the program, once when it comes
 * from the ndmp server and second time, the expected
 * reply
 *
 * Arguments :
 * 		FILE * - Log file handle.
 * 		void *ndmpMsg - Ndmp message object got from
 * 		the ndmp server response.
 *
 */
void
ndmp_config_get_host_info_reply_print(FILE *out, void *ndmpMsg)
{
	ndmp_config_get_host_info_reply *msg;

	msg = (ndmp_config_get_host_info_reply*)ndmpMsg;
	(void) fprintf(out, "error = %s\n", ndmpErrorCodeToStr(msg->error));
	(void) fprintf(out, "hostname = %s\n", msg->hostname);
	(void) fprintf(out, "os_type = %s\n", msg->os_type);
	(void) fprintf(out, "os_vers = %s\n",
	    msg->os_vers ? msg->os_vers : "msg->os_vers is null");
	(void) fprintf(out, "hostid = %s\n",
	    msg->hostid ? msg->hostid : "msg->hostid is null");
}

/*
 * ndmp_config_get_server_info_reply_print() :
 * Prints the reply object structure. This object gets
 * printed twice in the program, once when it comes
 * from the ndmp server and second time, the expected
 * reply
 *
 * Arguments :
 * 		FILE * - Log file handle.
 * 		void *ndmpMsg - Ndmp message object got from
 * 		the ndmp server response.
 *
 */
void
ndmp_config_get_server_info_reply_print(FILE *out, void *ndmpMsg)
{
	ndmp_config_get_server_info_reply *msg;

	msg = (ndmp_config_get_server_info_reply*)ndmpMsg;
	(void) fprintf(out, "error = %s\n", ndmpErrorCodeToStr(msg->error));
	(void) fprintf(out, "vendor_name = %s\n", msg->vendor_name);
	(void) fprintf(out, "product_name = %s\n", msg->product_name);
	(void) fprintf(out, "revision_number = %s\n",
	    msg->revision_number ? msg->revision_number :
	    "msg->revision_number is null");
	(void) fprintf(out, "auth_type.auth_type_len = %d\n",
	    msg->auth_type.auth_type_len);
}

/*
 * ndmp_config_get_connection_type_reply_print() :
 * Prints the reply object structure. This object gets
 * printed twice in the program, once when it comes
 * from the ndmp server and second time, the expected
 * reply
 *
 * Arguments :
 * 		FILE * - Log file handle.
 * 		void *ndmpMsg - Ndmp message object got from
 * 		the ndmp server response.
 *
 */
void
ndmp_config_get_connection_type_reply_print(FILE *out, void *ndmpMsg)
{
	ndmp_config_get_connection_type_reply	*reply;

	reply = (ndmp_config_get_connection_type_reply*)ndmpMsg;

	if (reply != 0) {

	(void) fprintf(out, "error %s \n", ndmpErrorCodeToStr(reply->error));
	print_addr_types(out, (addr_types *)&(reply->addr_types));

	}
}

/*
 * ndmp_config_get_auth_attr_reply_print() :
 * Prints the reply object structure. This object gets
 * printed twice in the program, once when it comes
 * from the ndmp server and second time, the expected
 * reply
 *
 * Arguments :
 * 		FILE * - Log file handle.
 * 		void *ndmpMsg - Ndmp message object got from
 * 		the ndmp server response.
 *
 */
void
ndmp_config_get_auth_attr_reply_print(FILE *out, void *ndmpMsg)
{
	ndmp_config_get_auth_attr_reply	*reply;

	reply = (ndmp_config_get_auth_attr_reply*)ndmpMsg;

	if (reply != 0) {
	(void) fprintf(out, "error %s \n", ndmpErrorCodeToStr(reply->error));
	print_ndmp_auth_attr(out, &(reply->server_attr));
	}
}

/*
 * ndmp_config_get_butype_info_reply_print() :
 * Prints the reply object structure. This object gets
 * printed twice in the program, once when it comes
 * from the ndmp server and second time, the expected
 * reply
 *
 * Arguments :
 * 		FILE * - Log file handle.
 * 		void *ndmpMsg - Ndmp message object got from
 * 		the ndmp server response.
 *
 */
void
ndmp_config_get_butype_info_reply_print(FILE *out, void *ndmpMsg)
{
	ndmp_config_get_butype_attr_reply	*reply;
	reply = (ndmp_config_get_butype_attr_reply*)ndmpMsg;

	if (reply != 0) {
	(void) fprintf(out, "error %s\n", ndmpErrorCodeToStr(reply->error));
	print_butype_info(out, (butype_info *)&(reply->butype_info));
	} else
	(void) fprintf(out,
	    "ndmp_config_get_butype_info_reply_print: obj is null\n");
}

/*
 * ndmp_config_get_fs_info_reply_print() :
 * Prints the reply object structure. This object gets
 * printed twice in the program, once when it comes
 * from the ndmp server and second time, the expected
 * reply
 *
 * Arguments :
 * 		FILE * - Log file handle.
 * 		void *ndmpMsg - Ndmp message object got from
 * 		the ndmp server response.
 *
 */
void
ndmp_config_get_fs_info_reply_print(FILE *out, void *ndmpMsg)
{
	ndmp_config_get_fs_info_reply	*reply;

	reply = (ndmp_config_get_fs_info_reply*)ndmpMsg;

	if (reply != 0) {

	(void) fprintf(out, "error %s \n", ndmpErrorCodeToStr(reply->error));

	print_fs_info(out, (fs_info *)&(reply->fs_info));

	}
}

/*
 * ndmp_config_get_tape_info_reply_print() :
 * Prints the reply object structure. This object gets
 * printed twice in the program, once when it comes
 * from the ndmp server and second time, the expected
 * reply
 *
 * Arguments :
 * 		FILE * - Log file handle.
 * 		void *ndmpMsg - Ndmp message object got from
 * 		the ndmp server response.
 *
 */
void
ndmp_config_get_tape_info_reply_print(FILE *out, void *ndmpMsg)
{
	ndmp_config_get_tape_info_reply	*reply;

	reply = (ndmp_config_get_tape_info_reply*)ndmpMsg;

	if (reply != 0) {

	(void) fprintf(out, "error %s \n", ndmpErrorCodeToStr(reply->error));

	print_tape_info(out, (tape_info *)&(reply->tape_info));

	}

}

/*
 * ndmp_config_get_scsi_info_reply_print() :
 * Prints the reply object structure. This object gets
 * printed twice in the program, once when it comes
 * from the ndmp server and second time, the expected
 * reply
 *
 * Arguments :
 * 		FILE * - Log file handle.
 * 		void *ndmpMsg - Ndmp message object got from
 * 		the ndmp server response.
 *
 */
void
ndmp_config_get_scsi_info_reply_print(FILE *out, void *ndmpMsg)
{
	ndmp_config_get_scsi_info_reply	*reply;

	reply = (ndmp_config_get_scsi_info_reply*)ndmpMsg;

	if (reply != NULL) {

	(void) fprintf(out, "error %s \n", ndmpErrorCodeToStr(reply->error));
	print_scsi_info(out, (scsi_info *)&(reply->scsi_info));

	} else
	(void) fprintf(out, "ndmp_config_get_scsi_info_reply_print: ");
	(void) fprintf(out, "obj is null\n");

}

/*
 * ndmp_config_get_ext_list_reply_print() :
 * Prints the reply object structure. This object gets
 * printed twice in the program, once when it comes
 * from the ndmp server and second time, the expected
 * reply
 *
 * Arguments :
 * 		FILE * - Log file handle.
 * 		void *ndmpMsg - Ndmp message object got from
 * 		the ndmp server response.
 *
 */
void
ndmp_config_get_ext_list_reply_print(FILE *out, void *ndmpMsg)
{
	ndmp_config_get_ext_list_reply	*reply;

	reply = (ndmp_config_get_ext_list_reply*)ndmpMsg;

	if (reply != 0) {

	(void) fprintf(out, "error %s \n", ndmpErrorCodeToStr(reply->error));

	print_class_list(out, (class_list *)&(reply->class_list));

	}
}

/*
 * ndmp_config_set_ext_list_reply_print() :
 * Prints the reply object structure. This object gets
 * printed twice in the program, once when it comes
 * from the ndmp server and second time, the expected
 * reply
 *
 * Arguments :
 * 		FILE * - Log file handle.
 * 		void *ndmpMsg - Ndmp message object got from
 * 		the ndmp server response.
 *
 */
void
ndmp_config_set_ext_list_reply_print(FILE *out, void *ndmpMsg)
{
	ndmp_config_set_ext_list_reply	*reply;

	reply = (ndmp_config_set_ext_list_reply*)ndmpMsg;

	if (reply != 0) {
	(void) fprintf(out, "error %s \n", ndmpErrorCodeToStr(reply->error));
	}
}

/*
 * Enhancement code start
 */

/*
 * get_config_error()
 * Based on the ndmp message passed to the method return the error message.
 * Return :
 *  message - ndmp message.
 */
ndmp_error
get_config_err(void *reply, ndmp_message msg)
{
	switch (msg) {
		case NDMP_CONFIG_GET_HOST_INFO :
			ndmp_config_get_host_info_reply_print(stdout,
								(void *)msg);
			return ((ndmp_config_get_host_info_reply *)
			    reply)->error;
		case NDMP_CONFIG_GET_SERVER_INFO:
			ndmp_config_get_server_info_reply_print(stdout,
								(void *)msg);
			return ((ndmp_config_get_server_info_reply *)
			    reply)->error;
		case NDMP_CONFIG_GET_CONNECTION_TYPE:
			ndmp_config_get_connection_type_reply_print(stdout,
								(void *)msg);
			return ((ndmp_config_get_connection_type_reply *)
			    reply)->error;
		case NDMP_CONFIG_GET_AUTH_ATTR:
			ndmp_config_get_auth_attr_reply_print(stdout,
								(void *)msg);
			return ((ndmp_config_get_auth_attr_reply *)
			    reply)->error;
		case NDMP_CONFIG_GET_BUTYPE_INFO:
			ndmp_config_get_butype_info_reply_print(stdout,
								(void *)msg);
			return ((ndmp_config_get_butype_attr_reply *)
			    reply)->error;
		case NDMP_CONFIG_GET_FS_INFO:
			ndmp_config_get_fs_info_reply_print(stdout,
								(void *)msg);
			return ((ndmp_config_get_fs_info_reply *)
			    reply)->error;
		case NDMP_CONFIG_GET_TAPE_INFO:
			ndmp_config_get_tape_info_reply_print(stdout,
								(void *)msg);
			return ((ndmp_config_get_tape_info_reply *)
			    reply)->error;
		case NDMP_CONFIG_GET_SCSI_INFO:
			ndmp_config_get_scsi_info_reply_print(stdout,
								(void *)msg);
			return ((ndmp_config_get_scsi_info_reply *)
			    reply)->error;
		case NDMP_CONFIG_GET_EXT_LIST:
			ndmp_config_get_ext_list_reply_print(stdout,
								(void *)msg);
			return ((ndmp_config_get_ext_list_reply *)
			    reply)->error;
		case NDMP_CONFIG_SET_EXT_LIST:
			ndmp_config_set_ext_list_reply_print(stdout,
								(void *)msg);
			return ((ndmp_config_set_ext_list_reply *)
			    reply)->error;
		default:
			return (-1);
	}
}

/*
 * scsi_get_state_core() Basic method to send scsi get state request to the
 * ndmp server
 */
int
config_core(ndmp_error error, ndmp_message message,
	    FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL, *req = NULL;
	ndmp_class_version class;
	/* Create and print the object end */
	ndmp_lprintf(outfile, "REQUEST : %d\n", message);
	/* send the request start */
	if (message == NDMP_CONFIG_GET_AUTH_ATTR) {
		req = (ndmp_config_get_auth_attr_request *)
			malloc(sizeof (ndmp_config_get_auth_attr_request));
		((ndmp_config_get_auth_attr_request *) req)->auth_type =
			NDMP_AUTH_TEXT;
	} else if (message == NDMP_CONFIG_SET_EXT_LIST) {
		req = (ndmp_config_set_ext_list_request *)
			malloc(sizeof (ndmp_config_set_ext_list_request));
		class.ext_class_id = 1;
		class.ext_version = 2;
		((ndmp_config_set_ext_list_request *) req)->
			ndmp_selected_ext.ndmp_selected_ext_len = 1;
		((ndmp_config_set_ext_list_request *) req)->
			ndmp_selected_ext.ndmp_selected_ext_val = &class;
	}
	if (!process_request((void *) req,
		message, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL && error != 0)
			return (SUCCESS);
	} else {
		return (ERROR);
	}
	return (SUCCESS);
}

/*
 * inf_config() : The flow of the test case is decided by this method.
 */
int
inf_config(ndmp_error error, char *ndmp_msg,
		FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	ndmp_message message = strToNdmpMessageCode(ndmp_msg);
	(void) ndmp_fprintf(outfile,
		"Test case name : %s\n", ndmp_msg);
	(void) ndmp_fprintf(outfile,
		"Error Condition : %s\n", ndmpErrorCodeToStr(error));

	/* Send the request */
	ret = config_core(error, message, outfile, conn);
	print_test_result(ret, outfile);

	return (ret);
}

/*
 * NDMP_CONFIG
 */
int
unit_test_config(host_info * host, FILE * logfile)
{
	conn_handle conn;
	int count;
	char ndmp_msg[10][50] = {
		"NDMP_CONFIG_GET_FS_INFO",
		"NDMP_CONFIG_GET_SERVER_INFO",
		"NDMP_CONFIG_GET_CONNECTION_TYPE",
		"NDMP_CONFIG_GET_AUTH_ATTR",
		"NDMP_CONFIG_GET_BUTYPE_INFO",
		"NDMP_CONFIG_GET_FS_INFO",
		"NDMP_CONFIG_GET_TAPE_INFO",
		"NDMP_CONFIG_GET_SCSI_INFO",
		"NDMP_CONFIG_GET_EXT_LIST",
		"NDMP_CONFIG_SET_EXT_LIST"
	};

	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	for (count = 0; count < 10; count++) {
		(void) ndmp_dprintf(logfile, "unit_test_config: "
			"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
		(void) inf_config(NDMP_NOT_AUTHORIZED_ERR, ndmp_msg[count],
			logfile, &conn);
		(void) ndmp_dprintf(logfile, "unit_test_config: "
			"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");
	}
	close_connection(&conn, logfile);

	strcpy(host->password, "admin");
	(void) open_connection(host, &conn, logfile);
	for (count = 0; count < 10; count++) {
		(void) ndmp_dprintf(logfile, "unit_test_config: "
			"Test 2: NDMP_NO_ERR start\n");
		(void) inf_config(NDMP_NO_ERR, ndmp_msg[count], logfile, &conn);
		(void) ndmp_dprintf(logfile, "unit_test_config: "
			"Test 2: NDMP_NO_ERR end\n");
	}
	close_connection(&conn, logfile);

	return (1);
}

#ifdef UNIT_TEST_CONFIG
/* ARGSUSED */
int
main(int argc, char *argv[])
{
	FILE *logfile = NULL;
	host_info host;
	host.ipAddr = strdup("10.12.178.122");
	host.userName = strdup("admin");
	host.password = strdup("admin");
	host.auth_type = NDMP_AUTH_TEXT;

	/* Open Log file */
	logfile = fopen("unit_test_config.log", "w");
	(void) ndmp_dprintf(logfile, "main: start\n");

	/* unit test config */
	unit_test_config(&host, logfile);

	(void) ndmp_dprintf(stdout, "main: end\n");
	free(host.ipAddr);
	free(host.userName);
	free(host.password);
	fclose(logfile);
	return (1);
}
#endif

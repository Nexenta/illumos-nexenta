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
 * The Data Interface manages the transfer of backup and recovery stream data
 * between a Tape Server or peer Data Server and the file system represented
 * by the local Data Server. This files implements all the data interfaces.
 * There are four type of methods for each interface. These methods types are
 * extract request, extract reply, print reply and compare reply.
 */

#include <stdio.h>
#include <strings.h>
#include <unistd.h>

#include <ndmp_conv.h>
#include <ndmp_connect.h>
#include <ndmp.h>
#include <ndmp_comm_lib.h>
#include <tape_tester.h>
#include <mover.h>
#include <data.h>

int stop_mover(FILE *, conn_handle *);
int stop_data(FILE *, conn_handle *);
int print_recover_object(ndmp_data_start_recover_request *, FILE *);

/*
 * ndmp_data_get_state_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *reply - Reply object to be
 * printed in the log file.
 */
void
ndmp_data_get_state_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_data_get_state_reply *msg;
	char reason[30];
	memset(reason, '\0', 30);
	msg = (ndmp_data_get_state_reply *) ndmpMsg;
	fprintf(out, "unsupported = %lu\n", msg->unsupported);
	fprintf(out, "error = %s\n", ndmpErrorCodeToStr(msg->error));
	fprintf(out, "operation = %s\n",
		ndmpDataOperationToStr(msg->operation, reason));
	memset(reason, '\0', 30);
	fprintf(out, "state = %s\n", ndmpDataStateToStr(msg->state, reason));
	memset(reason, '\0', 30);
	fprintf(out, "halt_reason = %s\n",
		ndmpDataHaltReasonToStr(msg->halt_reason, reason));
	print_ndmp_u_quad(out, msg->bytes_processed);
	print_ndmp_u_quad(out, msg->est_bytes_remain);
	fprintf(out, "est_time_remain = %lu\n", msg->est_time_remain);
	print_ndmp_addr(out, &(msg->data_connection_addr));
	print_ndmp_u_quad(out, msg->read_offset);
	print_ndmp_u_quad(out, msg->read_length);
}

/*
 * ndmp_data_start_backup_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *reply - Reply object to be
 * printed in the log file.
 */
void
ndmp_data_start_backup_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_data_start_backup_reply *msg;
	msg = (ndmp_data_start_backup_reply *) ndmpMsg;
	fprintf(out, "error = %s\n", ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_data_start_recover_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *reply - Reply object to be
 * printed in the log file.
 */
void
ndmp_data_start_recover_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_data_start_recover_reply *msg;
	msg = (ndmp_data_start_recover_reply *) ndmpMsg;
	fprintf(out, "error = %s\n", ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_data_abort_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *reply - Reply object to be
 * printed in the log file.
 */
void
ndmp_data_abort_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_data_abort_reply *msg;
	msg = (ndmp_data_abort_reply *) ndmpMsg;
	fprintf(out, "error = %s\n", ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_data_get_env_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *reply - Reply object to be
 * printed in the log file.
 */
void
ndmp_data_get_env_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_data_get_env_reply *msg;
	int i = 0;

	msg = (ndmp_data_get_env_reply *) ndmpMsg;
	fprintf(out, "error = %s\n", ndmpErrorCodeToStr(msg->error));
	fprintf(out, "env.env_len = %d\n", msg->env.env_len);
	for (i = 0; i < msg->env.env_len; i++) {
		print_ndmp_pval(out, msg->env.env_val);
		if (i < (msg->env.env_len - 1))
			(msg->env.env_val)++;
	}
}

/*
 * ndmp_data_stop_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *reply - Reply object to be
 * printed in the log file.
 */
void
ndmp_data_stop_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_data_stop_reply *msg;
	msg = (ndmp_data_stop_reply *) ndmpMsg;
	fprintf(out, "error = %s\n", ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_data_listen_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *reply - Reply object to be
 * printed in the log file.
 */
void
ndmp_data_listen_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_data_listen_reply *msg;
	msg = (ndmp_data_listen_reply *) ndmpMsg;
	fprintf(out, "error = %s\n", ndmpErrorCodeToStr(msg->error));
	print_ndmp_addr(out, &(msg->connect_addr));
}

/*
 * ndmp_data_connect_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *reply - Reply object to be
 * printed in the log file.
 */
void
ndmp_data_connect_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_data_connect_reply *msg;
	msg = (ndmp_data_connect_reply *) ndmpMsg;
	if (msg != 0)
		fprintf(out, "error = %s\n", ndmpErrorCodeToStr(msg->error));
}

/*
 * Code for version 2.0 starts here
 */
int
create_recover_object(ndmp_data_start_recover_request *request,
	char *fileSys, char *bu_type)
{
	ndmp_pval *p_ndmp_pval = 0;
	ndmp_name *nlist_val = NULL;

	request->env.env_len = 9;
	/*
	 * Allocating memory for the ndmp_pval structure based on the number
	 * of variable's
	 */
	p_ndmp_pval =
		(ndmp_pval *) malloc(sizeof (ndmp_pval) * request->env.env_len);
	memset(p_ndmp_pval, '0', (sizeof (ndmp_pval) * request->env.env_len));
	request->env.env_val = p_ndmp_pval;

	/*
	 * Allocation memory for members of ndmp_pval structure and allocatin
	 * the value
	 */
	p_ndmp_pval->name = strdup("FILESYSTEM");
	p_ndmp_pval->value = strdup(fileSys);

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("LEVEL");
	p_ndmp_pval->value = strdup("1");

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("UPDATE");
	p_ndmp_pval->value = strdup("Y");

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("HIST");
	p_ndmp_pval->value = strdup("Y");

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("TYPE");
	p_ndmp_pval->value = strdup("dump");

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("EXTRACT");
	p_ndmp_pval->value = strdup("Y");

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("EXTRACT_ACL");
	p_ndmp_pval->value = strdup("Y");

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("RECURSIVE");
	p_ndmp_pval->value = strdup("Y");

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("DIRECT");
	p_ndmp_pval->value = strdup("N");

	/* Length of nlist */
	request->nlist.nlist_len = 1;
	nlist_val = (ndmp_name *) malloc(sizeof (ndmp_name));
	memset(nlist_val, '0', (sizeof (ndmp_name)));
	request->nlist.nlist_val = nlist_val;
	request->nlist.nlist_val->original_path = NULL;
	request->nlist.nlist_val->destination_dir = strdup(fileSys);
	request->nlist.nlist_val->name = NULL;
	request->nlist.nlist_val->other_name = NULL;

	request->nlist.nlist_val->node.high = 0;
	request->nlist.nlist_val->node.low = 2;

	request->nlist.nlist_val->fh_info.high = 0;
	request->nlist.nlist_val->fh_info.low = 512;

	if (bu_type != NULL)
		request->butype_name = bu_type;
	else
		request->butype_name = strdup("dump");

	return (1);
}

/*
 * Core methods starts here
 */

int
data_start_recover_filehist_core(ndmp_error error, char *fileSys,
	FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_data_start_recover_request *request =
		(ndmp_data_start_recover_request *)
	malloc(sizeof (ndmp_data_start_recover_request));
	if (!create_recover_object(request, fileSys, "dump"))
		return (0);
	ndmp_lprintf(outfile, "REQUEST : NDMP_DATA_START_RECOVER_FILEHIST\n");
	(void) print_recover_object(request, outfile);
	if (!process_request((void *) request,
		NDMP_DATA_START_RECOVER_FILEHIST, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
		error == ((ndmp_data_start_recover_reply *) reply_mem)->error) {
			ndmp_data_start_recover_reply_print(outfile,
				((ndmp_data_start_recover_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

int
print_recover_object(ndmp_data_start_recover_request * request, FILE * logfile)
{
	int i = 0;
	ndmp_pval *pval = NULL;
	ndmp_fprintf(logfile, "Arguments are :\n");
	ndmp_fprintf(logfile, "Request object is { : \n");
	ndmp_fprintf(logfile, "env_len	: %d \n", request->env.env_len);
	ndmp_fprintf(logfile, "Name and Value pair :\n");
	pval = request->env.env_val;
	for (i = 0; i < request->env.env_len; i++) {
		ndmp_fprintf(logfile, "%s	%s\n",
			pval->name, pval->value);
		pval++;
	}
	ndmp_fprintf(logfile, "nlist_len: %d	 \n ",
		request->nlist.nlist_len);
	ndmp_fprintf(logfile, "original_path : NULL	 \n");
	ndmp_fprintf(logfile, "destination_dir	 : %s	 \n",
		request->nlist.nlist_val->destination_dir);
	ndmp_fprintf(logfile, "butype_name		 : %s	 \n",
		request->butype_name);

	return (1);
}

int
data_start_recover_core(ndmp_error error, ndmp_message msg, char *fileSys,
			char *bu_type, FILE * outfile, conn_handle * conn)
{
	char dump[10];
	ndmp_pval pval[9];
	char name[9][50];
	char value[9][50];
	ndmp_name val;
	int i;

	void *reply_mem = NULL;
	ndmp_data_start_recover_request request;
	memset(&request, 0, sizeof (ndmp_data_start_recover_request));
	memset(dump, '\0', (sizeof (char) * 5));

	if (bu_type == NULL)
		strcpy(dump, "dump");
	else
		strcpy(dump, bu_type);

	request.butype_name = dump;
	memset(pval, '0', (sizeof (ndmp_pval) * 9));
	memset(name, '\0', (9 * 50));
	memset(value, '\0', (9 * 50));
	strcpy(name[0], "FILESYSTEM");
	strcpy(value[0], fileSys);
	strcpy(name[1], "LEVEL");
	strcpy(value[1], "0");
	strcpy(name[2], "UPDATE");
	strcpy(value[2], "Y");
	strcpy(name[3], "HIST");
	strcpy(value[3], "Y");
	strcpy(name[4], "TYPE");
	strcpy(value[4], "dump");
	strcpy(name[5], "EXTRACT");
	strcpy(value[5], "Y");
	strcpy(name[6], "EXTRACT_ACL");
	strcpy(value[6], "Y");
	strcpy(name[7], "RECURSIVE");
	strcpy(value[7], "Y");
	strcpy(name[8], "DIRECT");
	strcpy(value[8], "Y");
	for (i = 0; i < 9; i++) {
		pval[i].name = name[i];
		pval[i].value = value[i];
	}
	request.env.env_len = 9;
	request.env.env_val = pval;

	val.original_path = NULL;
	val.destination_dir = fileSys;
	val.name = NULL;
	val.other_name = NULL;
	val.node.high = 0;
	val.node.low = 2;
	val.fh_info.high = 0;
	val.fh_info.low = 512;
	request.nlist.nlist_len = 1;
	request.nlist.nlist_val = &val;

	ndmp_lprintf(outfile, "REQUEST : NDMP_DATA_START_RECOVER\n");
	(void) print_recover_object(&request, outfile);
	if (!process_request((void *) &request,
				msg, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
		error == ((ndmp_data_start_recover_reply *) reply_mem)->error) {
			ndmp_data_start_recover_reply_print(outfile,
				((ndmp_data_start_recover_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * data_start_backup_core(): This method is used to send the
 * data_start_backup request and check if the response was as expected.
 */
int
data_start_backup_core(ndmp_error error, char *fileSys,
	char *backup_type, FILE * outfile, conn_handle * conn)
{
	ndmp_pval *p_ndmp_pval = 0;
	void *reply_mem = NULL;
	int bu_type;
	ndmp_data_start_backup_request *request =
	(ndmp_data_start_backup_request *)
	malloc(sizeof (ndmp_data_start_backup_request));
	if (backup_type != NULL) {
		ndmp_dprintf(outfile, "data_start_backup_core: "
			"backup_type is %s\n", backup_type);
		bu_type = convert_butype(backup_type);
	} else
		bu_type = STD_BACKUP_TYPE_DUMP;
	request->butype_name = (char *) malloc(sizeof (char) * 10);
	switch (bu_type) {
	case STD_BACKUP_TYPE_DUMP:
		(void) strcpy(request->butype_name, "dump");
		break;
	case STD_BACKUP_TYPE_TAR:
		(void) strcpy(request->butype_name, "tar");
		break;
	default:
		if (backup_type == NULL)
			strcpy(request->butype_name, "dump");
		else
			strcpy(request->butype_name, backup_type);
	}
	request->env.env_len = DATA_NVAL_LEN;
	/*
	 * Allocating memory for the ndmp_pval structure based on the number
	 * of variable's
	 */
	p_ndmp_pval =
		(ndmp_pval *) malloc(sizeof (ndmp_pval) * request->env.env_len);
	request->env.env_val = p_ndmp_pval;

	/*
	 * Allocation memory for members of ndmp_pval structure and allocatin
	 * the value
	 */
	p_ndmp_pval->name = strdup("FILESYSTEM");
	p_ndmp_pval->value = strdup(fileSys);

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("LEVEL");
	p_ndmp_pval->value = strdup("0");

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("HIST");
	p_ndmp_pval->value = strdup("Y");

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("ndmp.dump.pathnode");
	p_ndmp_pval->value = strdup("Y");

	p_ndmp_pval++;
	p_ndmp_pval->name = strdup("DIRECT");
	p_ndmp_pval->value = strdup("Y");
	ndmp_lprintf(outfile, "REQUEST : NDMP_DATA_START_BACKUP\n");

	if (!process_request((void *) request,
		NDMP_DATA_START_BACKUP, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
		error == ((ndmp_data_start_backup_reply *) reply_mem)->error) {
			ndmp_data_start_backup_reply_print(outfile,
				((ndmp_data_start_backup_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}


/*
 * data_connect_core(): This method is used to send the connect request and
 * check if the response was as expected.
 */
int
data_connect_core(ndmp_error error, ndmp_addr_type addr_type,
	void *addrObj, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_data_connect_request *request =
		(ndmp_data_connect_request *)
			malloc(sizeof (ndmp_data_connect_request));
	ndmp_addr *addr;
	/*
	 * Create and print the object start
	 */
	if (addrObj != NULL) {
		addr = (ndmp_addr *) addrObj;
		request->addr.addr_type = addr->addr_type;
		request->addr.ndmp_addr_u.tcp_addr.tcp_addr_len =
			addr->ndmp_addr_u.tcp_addr.tcp_addr_len;
		request->addr.ndmp_addr_u.tcp_addr.tcp_addr_val =
			addr->ndmp_addr_u.tcp_addr.tcp_addr_val;
	} else
		request->addr.addr_type = addr_type;

	ndmp_lprintf(outfile, "REQUEST : NDMP_DATA_CONNECT\n");
	/*
	 * send the request start
	 */
	if (!process_request((void *) request,
		NDMP_DATA_CONNECT, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
		error == ((ndmp_data_connect_reply *) reply_mem)->error) {
			ndmp_data_connect_reply_print(outfile,
				((ndmp_data_connect_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * data_listen_core(): This method is used to send the data_listen request
 * and check if the response was as expected.
 */
int
data_listen_core(ndmp_error error, ndmp_addr_type addr_type,
		ndmp_addr ** p_tcp_obj, FILE * outfile, conn_handle * conn)
{
	ndmp_data_listen_reply *reply_mem = NULL;
	ndmp_addr *obj = NULL;
	ndmp_data_listen_request *request = (ndmp_data_listen_request *)
	malloc(sizeof (ndmp_data_listen_request));
	request->addr_type = addr_type;
	ndmp_lprintf(outfile, "REQUEST : NDMP_DATA_LISTEN\n");
	/*
	 * send the request start
	 */
	if (!process_request((void *) request, NDMP_DATA_LISTEN, conn,
		(void *) &reply_mem, outfile)) {
		if (reply_mem != NULL &&
		error == ((ndmp_data_listen_reply *) reply_mem)->error) {
			ndmp_data_listen_reply_print(outfile,
				((ndmp_data_listen_reply *) reply_mem));
			if (addr_type == NDMP_ADDR_TCP) {
				obj = &(reply_mem->connect_addr);
				ndmp_dprintf(outfile,
				"data_listen_core: tcp obj 0x%x\n", obj);
				if (p_tcp_obj != NULL)
					*p_tcp_obj = obj;
			} else {
				ndmp_dprintf(outfile,
				"data_listen_core: NDMP_ADDR_LOCAL\n");
			}
		}
		return (SUCCESS);
	}
	return (ERROR);
}

/*
 * data_stop_core(): This method is used to send the data_stop request and
 * check if the response was as expected.
 */
int
data_stop_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_lprintf(outfile, "REQUEST : NDMP_DATA_STOP\n");
	/*
	 * send the request start
	 */
	if (!process_request(NULL, NDMP_DATA_STOP,
		conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
		error == ((ndmp_data_stop_reply *) reply_mem)->error) {
			ndmp_data_stop_reply_print(outfile,
				((ndmp_data_stop_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * get_data_state - sends the NDMP_DATA_GET_STATE request and returns the
 * state of the data machine Arguments : outfile : Log file handle conn	   :
 * Pointer to the connection handle Returns : ndmp_data_state
 */
ndmp_data_state
get_data_state(FILE * logfile, conn_handle * conn)
{
	ndmp_message ndmpMessage = NDMP_DATA_GET_STATE;
	void *reply_mem = NULL;
	int ret;
	/* Send the request start */
	ret = process_request(NULL, ndmpMessage, conn, &reply_mem, logfile);
	/* This code is for the server NDMP_NOT_AUTHORIZED_ERR bug. */
	if (ret == E_MALFORMED_PACKET)
		return (ret);
	/*
	 * Extract ndmp_data_state from reply and return
	 */
	if (reply_mem == NULL) {
		return (ERROR);
	} else {
		ndmp_data_get_state_reply *resultMsg;
		resultMsg = (ndmp_data_get_state_reply *) reply_mem;
		ndmp_lprintf(logfile, "NDMP REPLY MESSAGE :\n");
		ndmp_lprintf(logfile, "State is %d \n", resultMsg->state);
		return (resultMsg->state);
	}
}

/*
 * data_get_state_core(): This method is used to send the data_get_state
 * request and check if the response was as expected.
 */
int
data_get_state_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_lprintf(outfile, "REQUEST : NDMP_DATA_GET_STATE\n");
	/*
	 * Send the request start
	 */
	if (!process_request(NULL, NDMP_DATA_GET_STATE,
		conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
		error == ((ndmp_data_get_state_reply *) reply_mem)->error) {
			ndmp_data_get_state_reply_print(outfile,
				((ndmp_data_get_state_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * data_abort_core(): This method is used to send the request and check if
 * the response was as expected.
 */
int
data_abort_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_lprintf(outfile, "REQUEST : NDMP_DATA_ABORT\n");
	/*
	 * send the request start
	 */
	if (!process_request(NULL, NDMP_DATA_ABORT,
		conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_data_abort_reply *) reply_mem)->error) {
			ndmp_data_abort_reply_print(outfile,
				((ndmp_data_abort_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * data_get_env_core(): This method is used to send the data_get_env request
 * and check if the response was as expected.
 */
int
data_get_env_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_lprintf(outfile, "REQUEST : NDMP_DATA_GET_ENV\n");
	/*
	 * send the request start
	 */
	if (!process_request(NULL, NDMP_DATA_GET_ENV,
		conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
		error == ((ndmp_data_get_env_reply *) reply_mem)->error) {
			ndmp_data_get_env_reply_print(outfile,
				((ndmp_data_get_env_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * Core methods ends here
 */

/*
 * Interface and helper methods starts here
 */
static int
data_connect_intl(ndmp_error error, char *tape_dev,
	ndmp_mover_mode mode, ndmp_addr_type addr_type,
		ndmp_addr ** tcp_obj, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	ndmp_u_quad ndmpUQuadObj;

	ndmp_dprintf(outfile,
		"data_connect_intl: start, line -> %d\n", __LINE__);
	ret = tape_open_core(NDMP_NO_ERR, tape_dev,
		"NDMP_TAPE_RDWR_MODE", outfile, conn);
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
					STD_REC_SIZE, outfile, conn);

	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = STD_WIN_SIZE;
	ret += mover_set_window_core(NDMP_NO_ERR,
					NULL, &ndmpUQuadObj, outfile, conn);
	ndmp_dprintf(outfile,
		"data_connect_intl: line -> %d, ret -> %d\n", __LINE__, ret);
	if (error == NDMP_ILLEGAL_STATE_ERR) {
		(void) ndmp_dprintf(stdout, "data_connect_intl: "
			"NDMP_ILLEGAL_STATE_ERR 0x%x\n", error);
		return (ret);
	}
	if (addr_type != NDMP_ADDR_TCP) {
		ndmp_dprintf(outfile, "data_connect_intl: "
			"NDMP_ADDR_LOCAL 0x%x\n", addr_type);
		ret += mover_listen_core(NDMP_NO_ERR, mode,
					NDMP_ADDR_LOCAL, NULL, outfile, conn);
	} else {
		ret += mover_listen_core(NDMP_NO_ERR, mode,
				NDMP_ADDR_TCP, (void **)tcp_obj, outfile, conn);
		ndmp_dprintf(outfile, "data_connect_intl: "
			"NDMP_ADDR_TCP tcp obj 0x%x\n", *tcp_obj);
	}
	return (ret);
}

/*
 * Cleanup method for data connect interface.
 */
static int
data_connect_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (0);
	ret = stop_data(outfile, conn);
	ret += stop_mover(outfile, conn);
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * Intialization method for data_listen interface.
 */
static int
data_listen_intl(ndmp_error error, char *tape_dev,
	ndmp_addr_type * addr, FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	if (error == NDMP_ILLEGAL_ARGS_ERR) {
		*addr = 7;
	}
	ret += tape_open_core(NDMP_NO_ERR, tape_dev,
		"NDMP_TAPE_RDWR_MODE", outfile, conn);
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);

	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low += STD_WIN_SIZE;
	ret += mover_set_window_core(NDMP_NO_ERR, NULL,
		&ndmpUQuadObj, outfile, conn);
	if (error == NDMP_ILLEGAL_STATE_ERR) {
		data_listen_core(NDMP_NO_ERR,
			NDMP_ADDR_LOCAL, NULL, outfile, conn);
	}
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (0);
	return (ret);
}

/*
 * Cleanup method for data listen interface.
 */
static int
data_listen_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (0);
	ret = stop_data(outfile, conn);
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * Intialization method for data_start_backup interface.
 */
int
data_start_backup_intl(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	ret += tape_open_core(NDMP_NO_ERR,
		tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);
	tape_mtio_core(NDMP_NO_ERR, "NDMP_MTIO_REW", outfile, conn);
	sleep(1);
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (SUCCESS);
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);
	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = STD_WIN_SIZE;
	ret += mover_set_window_core(NDMP_NO_ERR,
		NULL, &ndmpUQuadObj, outfile, conn);

	ret += mover_listen_core(NDMP_NO_ERR, NDMP_MOVER_MODE_READ,
		NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_connect_core(NDMP_NO_ERR, NDMP_ADDR_LOCAL, NULL,
		outfile, conn);
	return (ret);
}

/*
 * Cleanup method for data start back up interface.
 */
int
data_start_backup_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	/* Call data_abort if DATA is not in Halted state */
	if (get_data_state(outfile, conn) != NDMP_DATA_STATE_HALTED) {
		(void) data_abort_core(NDMP_NO_ERR, outfile, conn);
		/* Call data_stop if data is in Halted state */
		if (get_data_state(outfile, conn) == NDMP_DATA_STATE_HALTED) {
			ret += data_stop_core(NDMP_NO_ERR, outfile, conn);
		}
	} else
		ret += data_stop_core(NDMP_NO_ERR, outfile, conn);

	/* Call mover_abort if MOVER is not in halted state */
	if (get_mover_state(outfile, conn) != NDMP_MOVER_STATE_HALTED) {
		(void) mover_abort_core(NDMP_NO_ERR, outfile, conn);
		/* Call mover_stop if MOVER is in halted state */
		if (get_mover_state(outfile, conn) ==
		    NDMP_MOVER_STATE_HALTED) {
			ret += mover_stop_core(NDMP_NO_ERR, outfile, conn);
		}
	} else
		ret += mover_stop_core(NDMP_NO_ERR, outfile, conn);
	ret += tape_mtio_core(NDMP_NO_ERR, "NDMP_MTIO_EOF", outfile, conn);
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);
	return (ret);
}

/*
 * intialization method for data_start_recover interface.
 */
int
data_start_recover_intl(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	ret += tape_open_core(NDMP_NO_ERR,
		tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);
	if (error != NDMP_NOT_AUTHORIZED_ERR) {
		ret += tape_mtio_core(NDMP_NO_ERR,
			"NDMP_MTIO_REW", outfile, conn);
		sleep(60);
	}
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);

	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = STD_WIN_SIZE;
	ret += mover_set_window_core(NDMP_NO_ERR,
		NULL, &ndmpUQuadObj, outfile, conn);

	ret += mover_listen_core(NDMP_NO_ERR, NDMP_MOVER_MODE_WRITE,
		NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_connect_core(NDMP_NO_ERR, NDMP_ADDR_LOCAL, NULL,
		outfile, conn);
	return (ret);
}

/*
 * Cleanup method for data start recover interface.
 */
int
data_start_recover_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	ret = stop_data(outfile, conn);
	ret += stop_mover(outfile, conn);
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * intialization method for data_get_env interface.
 */
static int
data_get_env_intl(ndmp_error error, char *tape_dev,
	char *absBckDirPath, FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	ret += tape_open_core(NDMP_NO_ERR,
		tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);

	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = STD_WIN_SIZE;
	ret += mover_set_window_core(NDMP_NO_ERR,
		NULL, &ndmpUQuadObj, outfile, conn);

	ret += mover_listen_core(NDMP_NO_ERR,
		NDMP_MOVER_MODE_WRITE, NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_connect_core(NDMP_NO_ERR,
		NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_start_backup_core(NDMP_NO_ERR,
		absBckDirPath, NULL, outfile, conn);
	return (ret);
}

/*
 * Cleanup method for data get anv interface.
 */
static int
data_get_env_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	ret = stop_data(outfile, conn);
	ret += stop_mover(outfile, conn);
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);
	return (ret);
}

/*
 * intialization method for data_abort interface.
 */
static int
data_abort_intl(ndmp_error error, char *tape_dev,
	char *absBckDirPath, FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	ret += tape_open_core(NDMP_NO_ERR,
		tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);

	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = STD_WIN_SIZE;
	ret += mover_set_window_core(NDMP_NO_ERR,
		NULL, &ndmpUQuadObj, outfile, conn);

	ret += mover_listen_core(NDMP_NO_ERR,
		NDMP_MOVER_MODE_WRITE, NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_connect_core(NDMP_NO_ERR,
		NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_start_backup_core(NDMP_NO_ERR,
		absBckDirPath, NULL, outfile, conn);
	return (ret);
}

/*
 * Cleanup method for data abort interface.
 */
static int
data_abort_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	ret = stop_mover(outfile, conn);
	ret += stop_data(outfile, conn);
	return (ret);
}

/*
 * Intialization method for data_stop interface.
 */
static int
data_stop_intl(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	ret += tape_open_core(NDMP_NO_ERR,
		tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);

	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = STD_WIN_SIZE;
	ret += mover_set_window_core(NDMP_NO_ERR,
		NULL, &ndmpUQuadObj, outfile, conn);

	ret += mover_listen_core(NDMP_NO_ERR,
		NDMP_MOVER_MODE_WRITE, NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_connect_core(NDMP_NO_ERR,
		NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_abort_core(NDMP_NO_ERR, outfile, conn);
	return (ret);
}

/*
 * Cleanup method for data stop interface.
 */
int
data_stop_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	ret += stop_mover(outfile, conn);
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * inf_data_get_state(): This method is used to test the inf data get state
 * interface. This request is used by the DMA to obtain information about the
 * Data Server's operational state as represented by the Data Server variable
 * set. Executes all the steps in the test case.
 *
 * Arguments : ndmp_error - Error condition to test. FILE * - Log file handle.
 * conn_handle *- Connection object handle. Return : int - 0 for success and
 * 1 for failure.
 */
int
inf_data_get_state(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_data_get_state\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	switch (error) {
	case NDMP_NO_ERR:
		ret = data_get_state_core(NDMP_NO_ERR, outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		ret = data_get_state_core(NDMP_NOT_AUTHORIZED_ERR,
			outfile, conn);
		break;
	default:
		break;
	}

	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"Test case result : Fail\n");
		return (1);
	} else {
		(void) ndmp_fprintf(outfile,
			"Test case result : Pass\n");
		return (0);
	}
}

/*
 * inf_data_connect(): This method is used to test the data connect
 * interface. This request is used by the DMA to instruct the Data Server to
 * establish a data connection to a Tape Server or peer Data Server. A
 * connect request is only valid when the Data Server is in the IDLE state.
 *
 * Executes all the steps in the test case.
 *
 * Arguments : ndmp_error - Error condition to test. FILE * - Log file handle.
 * conn_handle *- Connection object handle. tape_dev - Tape Device.
 * absBckDirPath - Backup directory path. addr_type - Address type Return :
 * int - 0 for success and 1 for failure.
 */
int
inf_data_connect(ndmp_error error, char *tape_dev, char *mover_mode,
	char *addr_type, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	ndmp_mover_mode mode;
	ndmp_addr_type addr;
	ndmp_addr *tcp_obj = NULL;
	char *addr_t = NULL;

	ndmp_dprintf(outfile,
		"inf_data_connect: start, line -> \n", __LINE__);
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_data_connect\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	if (mover_mode != NULL) {
		mode = convert_mover_mode(mover_mode);
		(void) ndmp_dprintf(outfile,
			"inf_mover_connect: mode is 0x%x\n", mode);
	} else {
		mode = NDMP_MOVER_MODE_READ;
		(void) ndmp_dprintf(outfile,
			"inf_mover_connect: mode is NDMP_MOVER_MODE_READ\n");
	}
	if (addr_type != NULL) {
		addr_t = addr_type;
		addr = convert_addr_type(addr_t);
	} else {
		(void) ndmp_dprintf(outfile,
			"inf_data_connect: addr_type NDMP_ADDR_LOCAL\n");
		addr = NDMP_ADDR_LOCAL;
	}
	ret = data_connect_intl(error, tape_dev, mode,
		addr, &tcp_obj, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"Initialization failed. Test case can't be executed\n");
		print_test_result(1, outfile);
		return (ERROR);
	}
	ndmp_dprintf(outfile, "KK: addr is %d\n", addr);
	ret = data_connect_core(error, addr, tcp_obj, outfile, conn);
	print_test_result(ret, outfile);
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = data_connect_cleanup(error, outfile, conn);
		if (ret != 0) {
			(void) ndmp_fprintf(outfile,
				"data_get_env cleanup failed\n");
			return (1);
		}
	}
	return (0);
}

/*
 * inf_data_start_recover_filehist(): This method is used to test the data
 * start recover filehist interface. This optional request is used by the DMA
 * to instruct the Data Server to initiate a file history recovery operation
 * and process the recovery stream received from a Tape Server or peer Data
 * Server over the previously established data connection to generate
 * filehistory as during backup operations. No changes are made to the local
 * file system. Executes all the steps in the test case.
 *
 * Arguments : ndmp_error - Error condition to test. FILE * - Log file handle.
 * conn_handle *- Connection object handle. tape_dev - Tape Device. addr_type
 * - Address type Return : int - 0 for success and 1 for failure.
 */
int
inf_data_start_recover_filehist(ndmp_error error, char *tape_dev,
	char *fileSys, char *bu_type, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_data_start_recover_filehist\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = data_start_recover_intl(error, tape_dev, outfile, conn);
		if (ret != 0) {
			(void) ndmp_fprintf(outfile,
			"Initialization failed. Test case can't be executed\n");
		}
	}
	ret = data_start_recover_core(NDMP_NOT_SUPPORTED_ERR,
	NDMP_DATA_START_RECOVER_FILEHIST, fileSys, bu_type, outfile, conn);
	if (ret != 0)
		(void) ndmp_fprintf(outfile,
			"Test case result : Fail\n");
	else
		(void) ndmp_fprintf(outfile,
			"Test case result : Pass\n");

	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = data_start_recover_cleanup(error, outfile, conn);
		if (ret != 0) {
			(void) ndmp_fprintf(outfile,
				"data_get_env cleanup failed\n");
			return (1);
		}
	}
	return (0);
}

/*
 * inf_data_start_recover(): This method is used to test the data start
 * recover interface. This request is used by the DMA to instruct the Data
 * Server to initiate a recovery operation and transfer the recovery stream
 * received from a Tape Server or peer Data Server over the previously
 * established data connection to the specified local file system location.
 * Executes all the steps in the test case.
 *
 * Arguments : ndmp_error - Error condition to test. FILE * - Log file handle.
 * conn_handle *- Connection object handle. tape_dev - Tape Device. addr_type
 * - Address type Return : int - 0 for success and 1 for failure.
 */
int
inf_data_start_recover(ndmp_error error, char *tape_dev, char *fileSys,
	char *bu_type, FILE * outfile, conn_handle * conn)
{
	notify_qrec *obj;
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_data_start_recover\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	if (error != NDMP_ILLEGAL_STATE_ERR &&
	    error != NDMP_NOT_AUTHORIZED_ERR) {
		ret = data_start_recover_intl(error, tape_dev, outfile, conn);
		if (ret != 0) {
			(void) ndmp_fprintf(outfile,
			"Initialization failed. Test case can't be executed\n");
		}
	}
	ret = data_start_recover_core(error,
		NDMP_DATA_START_RECOVER, fileSys, bu_type, outfile, conn);
	if (ret != 0)
		(void) ndmp_fprintf(outfile,
			"Test case result : Fail\n");
	else
		(void) ndmp_fprintf(outfile,
			"Test case result : Pass\n");

	if (error != NDMP_ILLEGAL_STATE_ERR &&
	    error != NDMP_NOT_AUTHORIZED_ERR) {
		notify_qrec *list = NULL;
		ret = process_notification(conn,
			NDMP_NOTIFY_DATA_HALTED, &list, outfile);
		obj = search_element(list,
			NDMP_NOTIFY_MOVER_HALTED, outfile);
		if (obj != NULL) {

			ndmp_notify_mover_halted_post *post_m =
				(ndmp_notify_mover_halted_post *) obj->notify;
			ndmp_fprintf(outfile, "inf_data_start_recover: "
				"reason NDMP_NOTIFY_MOVER_HALTED - %d\n",
					post_m->reason);
		}
		obj = search_element(list, NDMP_NOTIFY_DATA_HALTED, outfile);
		if (obj != NULL) {
			ndmp_notify_data_halted_post *post =
				(ndmp_notify_data_halted_post *) obj->notify;
			ndmp_fprintf(outfile, "inf_data_start_recover: reason "
				"NDMP_NOTIFY_DATA_HALTED - %d\n", post->reason);
		}
		obj = search_element(list, NDMP_LOG_FILE, outfile);
		if (obj != NULL) {
			ndmp_log_file_post *post_l =
				(ndmp_log_file_post *) obj->notify;
			ndmp_fprintf(outfile, "inf_data_start_recover:"
			" recovery_status %d\n", post_l->recovery_status);
		}
		ret += data_start_recover_cleanup(error, outfile, conn);
		if (ret != 0) {
			(void) ndmp_fprintf(outfile,
				"data_get_env cleanup failed\n");
			return (1);
		}
	}
	return (0);
}

/*
 * inf_data_start_backup(): This method is used to test the data start backup
 * interface. This request is used by the DMA to instruct the Data Server to
 * initiate a backup operation and begin transferring backup data from the
 * file system represented by this Data Server to a Tape Server or peer Data
 * Server over the previously established dataconnection. Executes all the
 * steps in the test case.
 *
 * Arguments : ndmp_error - Error condition to test. FILE * - Log file handle.
 * conn_handle *- Connection object handle. tape_dev - Tape Device.
 * absBckDirPath - Backup directory path. Return : int - 0 for success and 1
 * for failure.
 */
int
inf_data_start_backup(ndmp_error error, char *tape_dev,
	char *abcBckDirPath, char *backup_type,
		FILE * outfile, conn_handle * conn)
{
	notify_qrec *list = NULL, *obj = NULL;
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_data_start_backup\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	if (error != NDMP_ILLEGAL_STATE_ERR &&
		error != NDMP_NOT_AUTHORIZED_ERR) {
		ret = data_start_backup_intl(error, tape_dev, outfile, conn);
		if (ret != 0) {
			(void) ndmp_fprintf(outfile, "Initialization failed. "
				"Test case can't be executed\n");
			print_test_result(ret, outfile);
			return (ERROR);
		}
	}
	ret = data_start_backup_core(error, abcBckDirPath,
		backup_type, outfile, conn);
	print_test_result(ret, outfile);
	if (error == NDMP_ILLEGAL_STATE_ERR || error == NDMP_NOT_AUTHORIZED_ERR)
		return (SUCCESS);
	if (error != NDMP_ILLEGAL_ARGS_ERR) {
		ret = process_notification(conn,
			NDMP_NOTIFY_MOVER_HALTED, &list, outfile);
		obj = search_element(list,
			NDMP_NOTIFY_MOVER_HALTED, outfile);
	}
	if (obj != NULL) {

		ndmp_notify_mover_halted_post *post_m =
			(ndmp_notify_mover_halted_post *) obj->notify;
		ndmp_fprintf(outfile, "inf_data_start_backup: reason "
			"NDMP_NOTIFY_MOVER_HALTED - %d\n", post_m->reason);
	}
	obj = search_element(list,
		NDMP_NOTIFY_DATA_HALTED, outfile);
	if (obj != NULL) {
		ndmp_notify_data_halted_post *post =
			(ndmp_notify_data_halted_post *) obj->notify;
		ndmp_fprintf(outfile, "inf_data_start_backup: reason "
			"NDMP_NOTIFY_DATA_HALTED - %d\n", post->reason);
	}
	ret = data_start_backup_cleanup(error, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"data_get_env cleanup failed\n");
		return (1);
	}
	return (0);
}

/*
 * inf_data_listen(): This method is used to test the data listen interface.
 * This request is used by the DMA to instruct the Data Server create a
 * connection end point and listen for a subsequent data connection from a
 * Tape Server (mover) or peer Data Server. This request is also used by the
 * DMA to obtain the address of connection end point the Data Server is
 * listening at. A listen request is only valid when the Data Server is in
 * the IDLE state. Executes all the steps in the test case.
 *
 * Arguments : ndmp_error - Error condition to test. FILE * - Log file handle.
 * conn_handle *- Connection object handle. tape_dev - Tape Device. addr_type
 * - Address type Return : int - 0 for success and 1 for failure.
 */
int
inf_data_listen(ndmp_error error, char *tape_dev, char *addr_type,
		FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	ndmp_addr_type  addr;
	if (addr_type != NULL)
		addr = convert_addr_type(addr_type);
	else
		addr = NDMP_ADDR_LOCAL;

	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_data_listen\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	ret = data_listen_intl(error, tape_dev, &addr, outfile, conn);
	print_intl_result(ret, outfile);
	ret = data_listen_core(error, addr, NULL, outfile, conn);
	print_test_result(ret, outfile);

	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = data_listen_cleanup(error, outfile, conn);
		print_cleanup_result(ret, outfile);
	}
	return (0);
}

/*
 * inf_data_get_env(): This method is used to test the inf data get env
 * interface. This request is used by the DMA to obtain the backup
 * environment variable set associated with the current data operation. The
 * NDMP_DATA_GET_ENV request is typically issued following a successful
 * backup operation but MAY be issued during or after a recovery operation as
 * well. This request is only valid when the Data Server is in the ACTIVE or
 * HALTED states. Executes all the steps in the test case.
 *
 * Arguments : ndmp_error - Error condition to test. FILE * - Log file handle.
 * conn_handle *- Connection object handle. tape_dev - Tape Device.
 * absBckDirPath - Backup directory path. Return : int - 0 for success and 1
 * for failure.
 */
int
inf_data_get_env(ndmp_error error, char *tape_dev,
	char *absBckDirPath, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_data_get_env\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = data_get_env_intl(error, tape_dev,
			absBckDirPath, outfile, conn);
	}
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
		"Initialization failed. Test case can't be executed\n");
	}
	switch (error) {
	case NDMP_NO_ERR:
		ret = data_get_env_core(NDMP_NO_ERR, outfile, conn);
		break;
	case NDMP_ILLEGAL_STATE_ERR:
		ret = data_get_env_core(NDMP_ILLEGAL_STATE_ERR,
			outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		ret = data_get_env_core(NDMP_NOT_AUTHORIZED_ERR,
			outfile, conn);
		break;
	default:
		break;
	}
	if (ret != 0)
		(void) ndmp_fprintf(outfile,
			"Test case result : Fail\n");
	else
		(void) ndmp_fprintf(outfile,
			"Test case result : Pass\n");

	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = data_get_env_cleanup(error, outfile, conn);
		if (ret != 0) {
			(void) ndmp_fprintf(outfile,
				"data_get_env cleanup failed\n");
			return (1);
		}
	}
	return (0);
}

/*
 * inf_data_stop(): This method is used to test the data stop interface. This
 * request is used by the DMA to instruct the Data Server to release all
 * resources, reset all Data Server state variables, reset all backup
 * environment variables and transition the Data Server to the IDLE state.
 *
 * Executes all the steps in the test case.
 *
 * Arguments : ndmp_error - Error condition to test. FILE * - Log file handle.
 * conn_handle *- Connection object handle. Return : int - 0 for success and
 * 1 for failure.
 */
int
inf_data_stop(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_data_stop\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = data_stop_intl(error, tape_dev, outfile, conn);
	}
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
		"Initialization failed. Test case can't be executed\n");
	}
	switch (error) {
	case NDMP_NO_ERR:
		ret = data_stop_core(NDMP_NO_ERR, outfile, conn);
		break;
	case NDMP_ILLEGAL_STATE_ERR:
		ret = data_stop_core(NDMP_ILLEGAL_STATE_ERR, outfile, conn);
		break;
	case NDMP_ILLEGAL_ARGS_ERR:
		ret = data_stop_core(NDMP_ILLEGAL_STATE_ERR, outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		ret = data_stop_core(NDMP_NOT_AUTHORIZED_ERR, outfile, conn);
		break;
	default:
		break;
	}
	if (ret != 0)
		(void) ndmp_fprintf(outfile,
				    "Test case result : Fail\n");
	else
		(void) ndmp_fprintf(outfile,
				    "Test case result : Pass\n");

	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = data_stop_cleanup(error, outfile,
					conn);
		if (ret != 0) {
			(void) ndmp_fprintf(outfile,
					    "data_stop cleanup failed\n");
			return (1);
		}
	}
	return (0);
}

/*
 * inf_data_abort(): This method is used to test the data abort interface.
 * Data Abort request is used by the DMA to instruct the Data Server to
 * terminate any in progress data operation, close the data connection if
 * present, and transition the Data Server to the HALTED state. An abort
 * request is valid when the Data Server is in any state except IDLE. If the
 * data abort is received in the ACTIVE state the Data Server SHOULD
 * terminate the backup or recovery operation as soon as practical.
 *
 * Executes all the steps in the test case.
 *
 * Arguments : ndmp_error - Error condition to test. FILE * - Log file handle.
 * conn_handle *- Connection object handle. tape_dev - Tape Device.
 * absBckDirPath - Backup directory path. Return : int - 0 for success and 1
 * for failure.
 */
int
inf_data_abort(ndmp_error error, char *tape_dev,
	char *absBckDirPath, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_data_abort\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = data_abort_intl(error, tape_dev,
			absBckDirPath, outfile, conn);
	}
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
		"Initialization failed. Test case can't be executed\n");
		print_test_result(ERROR, outfile);
		return (ERROR);
	}
	switch (error) {
	case NDMP_NO_ERR:
		ret = data_abort_core(NDMP_NO_ERR, outfile, conn);
		break;
	case NDMP_ILLEGAL_STATE_ERR:
		ret = data_abort_core(NDMP_ILLEGAL_STATE_ERR, outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		ret = data_abort_core(NDMP_NOT_AUTHORIZED_ERR, outfile, conn);
		break;
	default:
		break;
	}
	if (ret != 0)
		(void) ndmp_fprintf(outfile, "Test case result : Fail\n");
	else
		(void) ndmp_fprintf(outfile, "Test case result : Pass\n");

	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = data_abort_cleanup(error, outfile, conn);
		if (ret != 0) {
			(void) ndmp_fprintf(outfile,
				"data_abort cleanup failed\n");
			return (1);
		}
	}
	return (0);
}

/* Unit testing code start */

/*
 * NDMP_DATA_LISTEN
 */
int
unit_test_data_listen(host_info * auth, char *tape, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_data_listen: Test 1: NDMP_NO_ERR start\n");
	(void) open_connection(auth, &conn, logfile);
	inf_data_listen(NDMP_NO_ERR, tape, NULL, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_data_listen: Test 1: NDMP_NO_ERR end\n");

	/* Test 2: NDMP_ILLEGAL_ARGS_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_data_listen: Test 2: NDMP_ILLEGAL_ARGS_ERR start\n");
	inf_data_listen(NDMP_ILLEGAL_ARGS_ERR, tape, NULL, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_data_listen: Test 2: NDMP_ILLEGAL_ARGS_ERR end\n");

	/* Test 3: NDMP_ILLEGAL_STATE_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_data_listen: Test 3: "
			"NDMP_ILLEGAL_STATE_ERR start\n");
	inf_data_listen(NDMP_ILLEGAL_STATE_ERR, tape, NULL, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_data_listen: Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	/* Test 4: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_data_listen: Test 4: "
			"NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_data_listen(NDMP_NOT_AUTHORIZED_ERR, tape, NULL, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_data_listen: Test 4: NDMP_NOT_AUTHORIZED_ERR end\n");

	return (1);
}

/*
 * NDMP_DATA_START_RECOVER
 */
int
unit_test_data_start_recover(host_info * auth,
	char *tape, char *absResDirpath, FILE * logfile)
{
	conn_handle conn;
	char *butype = "tar";

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_data_start_recover: Test 1: NDMP_NO_ERR start\n");
	(void) open_connection(auth, &conn, logfile);
	inf_data_start_recover(NDMP_NO_ERR, tape,
		absResDirpath, butype, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_data_start_recover: Test 1: NDMP_NO_ERR end\n");

	/* Test 2: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_data_start_recover: "
			"Test 2: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_data_start_recover(NDMP_NOT_AUTHORIZED_ERR, tape,
		absResDirpath, butype, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile, "unit_test_data_start_recover: Test 2: "
		"NDMP_NOT_AUTHORIZED_ERR end\n");
	return (1);
}

/*
 * NDMP_DATA_START_BACKUP
 */
int
unit_test_data_start_backup(host_info * auth,
	char *tape, char *absBckDirpath, FILE * logfile)
{
	conn_handle conn;
	char *butype = "tar";

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_data_start_backup: Test 1: NDMP_NO_ERR start\n");
	(void) open_connection(auth, &conn, logfile);
	inf_data_start_backup(NDMP_NO_ERR, tape,
		absBckDirpath, butype, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile, "unit_test_data_start_backup: "
		"Test 1: NDMP_NO_ERR end\n");

	/* Test 2: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_data_start_backup: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_data_start_backup(NDMP_NOT_AUTHORIZED_ERR, tape,
		absBckDirpath, butype, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile, "unit_test_data_start_backup: "
		"Test 2:" "NDMP_NOT_AUTHORIZED_ERR end\n");
	return (1);
}

/*
 * NDMP_DATA_CONNECT
 */
int
unit_test_data_connect(host_info * auth, char *tape, FILE * logfile)
{
	conn_handle conn;
	char *addr_type = "NDMP_ADDR_TCP";
	char *mover_mode = "NDMP_MOVER_MODE_READ";

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_data_connect: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_data_connect(NDMP_NOT_AUTHORIZED_ERR, tape,
		mover_mode, addr_type, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile, "unit_test_data_connect: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_data_connect: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_data_connect(NDMP_NO_ERR, tape,
		mover_mode, addr_type, logfile, &conn);
	(void) ndmp_dprintf(logfile, "unit_test_data_connect: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_ILLEGAL_STATE_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_data_connect: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR start\n");
	inf_data_connect(NDMP_ILLEGAL_STATE_ERR, tape, mover_mode, addr_type,
		logfile, &conn);
	(void) ndmp_dprintf(logfile, "unit_test_data_connect: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	/* Test 4: NDMP_ILLEGAL_ARGS_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_data_connect: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR start\n");
	inf_data_connect(NDMP_ILLEGAL_ARGS_ERR,
		tape, mover_mode, addr_type, logfile, &conn);
	(void) ndmp_dprintf(logfile, "unit_test_data_connect: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR end\n");

	/* Test 5: NDMP_CONNECT_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_data_connect: "
		"Test 5: NDMP_CONNECT_ERR start\n");
	inf_data_connect(NDMP_CONNECT_ERR, tape, mover_mode, addr_type,
		logfile, &conn);
	(void) ndmp_dprintf(logfile, "unit_test_data_connect: "
		"Test 5: NDMP_CONNECT_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

/*
 * NDMP_DATA_GET_STATE
 */
int
unit_test_data_get_state(host_info * auth, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_data_get_state: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) open_connection(auth, &conn, logfile);
	inf_data_get_state(NDMP_NO_ERR, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile, "unit_test_data_get_state: "
		"Test 1: NDMP_NO_ERR end\n");

	/* Test 2: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_data_get_state: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_data_get_state(NDMP_NOT_AUTHORIZED_ERR, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile, "unit_test_data_get_state: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	return (1);
}

#ifdef UNIT_TEST_DATA

int
main(int argc, char *argv[])
{
	FILE *logfile = NULL;
	char *tape_dev = "/dev/rmt/2n";
	char *absBckDirPath = "/etc/cron.d/";
	char *absResDirPath = "/space/dst";
	host_info auth;
	auth.ipAddr = strdup("10.12.178.122");
	auth.userName = strdup("admin");
	auth.password = strdup("admin");
	auth.auth_type = NDMP_AUTH_TEXT;

	/* Open Log file */
	logfile = fopen("unit_test_data.log", "w");
	(void) ndmp_dprintf(logfile, "main: start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);

	/* unit test data get state */
	unit_test_data_get_state(&auth, logfile);
	/*
	 * unit test data connect
	 */
	unit_test_data_connect(&auth, tape_dev, logfile);

	/*
	 * unit test data start recover
	 */
	unit_test_data_start_backup(&auth, tape_dev, absResDirPath, logfile);

	/*
	 * unit test data start backup
	 */
	unit_test_data_start_recover(&auth, tape_dev, absBckDirPath, logfile);

	/*
	 * unit test data listen
	 */
	unit_test_data_listen(&auth, tape_dev, logfile);

	(void) ndmp_dprintf(stdout, "main: end\n");
	free(auth.ipAddr);
	free(auth.userName);
	free(auth.password);
	fclose(logfile);
	return (1);
}
#endif

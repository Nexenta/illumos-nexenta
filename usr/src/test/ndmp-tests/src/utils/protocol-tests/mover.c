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
 * The Mover Interface manages the transfer of backup stream data between a
 * data or Tape Server and the local tape subsystem. This files implements
 * all the mover interfaces. There are four type of methods for each
 * interface. These methods types are extract request, extract reply, print
 * reply and compare reply.
 */

#include<stdio.h>
#include<string.h>
#include<stdlib.h>

#include <ndmp.h>
#include <ndmp_comm_lib.h>
#include <process_hdlr_table.h>
#include <mover.h>
#include <ndmp_connect.h>
#include <ndmp_conv.h>
#include <tape_tester.h>
#include <data.h>

int stop_mover(FILE *, conn_handle *);
int stop_data(FILE *, conn_handle *);

/*
 * ndmp_mover_listen_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_mover_listen_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_mover_listen_reply *msg;
	msg = (ndmp_mover_listen_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "error = %s\n",
			ndmpErrorCodeToStr(msg->error));
	(void) ndmp_lprintf(out, "Connection Type : ");
	print_ndmp_addr(out, &(msg->connect_addr));
}

/*
 * ndmp_mover_stop_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_mover_stop_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_mover_listen_reply *msg;
	msg = (ndmp_mover_listen_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "error = %s\n",
			ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_mover_set_record_size_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_mover_set_record_size_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_mover_set_record_size_reply *msg;
	msg = (ndmp_mover_set_record_size_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "error = %s\n",
			ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_mover_set_window_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_mover_set_window_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_mover_set_window_reply *msg;
	msg = (ndmp_mover_set_window_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "error = %s\n",
			ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_mover_connect_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_mover_connect_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_mover_connect_reply *msg;
	msg = (ndmp_mover_connect_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "error = %s\n",
			ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_mover_read_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_mover_read_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_mover_read_reply *msg;
	msg = (ndmp_mover_read_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "error = %s\n",
			ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_mover_get_state_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg- Reply object to be
 * printed in the log file.
 */
void
ndmp_mover_get_state_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_mover_get_state_reply *msg;
	char reason[30];
	char str_ndmp_mover_state[30];

	memset(reason, '\0', 30);
	memset(str_ndmp_mover_state, '\0', 30);
	msg = (ndmp_mover_get_state_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "error = %s\n",
			ndmpErrorCodeToStr(msg->error));
	(void) ndmp_lprintf(out, "mode = %d\n", msg->mode);
	(void) ndmp_lprintf(out, "state = %s\n",
		ndmpMoverStateToStr(msg->state, str_ndmp_mover_state));
	(void) ndmp_lprintf(out, "pause_reason = %s\n",
		ndmpMoverPauseReasonToStr(msg->pause_reason, reason));
	memset(reason, '\0', 30);
	(void) ndmp_lprintf(out, "halt_reason = %s\n",
		ndmpMoverHaltReasonToStr(msg->halt_reason, reason));
	(void) ndmp_lprintf(out, "record_size = %d\n", (int) msg->record_size);
	(void) ndmp_lprintf(out, "record_num = %d\n", (int) msg->record_num);
	print_ndmp_u_quad(out, msg->bytes_moved);
	print_ndmp_u_quad(out, msg->seek_position);
	print_ndmp_u_quad(out, msg->bytes_left_to_read);
	print_ndmp_u_quad(out, msg->window_offset);
	print_ndmp_u_quad(out, msg->window_length);
	print_ndmp_addr(out, &(msg->data_connection_addr));
}

/*
 * ndmp_mover_continue_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg- Reply object to be
 * printed in the log file.
 */
void
ndmp_mover_continue_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_mover_continue_reply *msg;
	msg = (ndmp_mover_continue_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "error = %s\n",
			    ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_mover_close_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg- Reply object to be
 * printed in the log file.
 */
void
ndmp_mover_close_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_mover_close_reply *msg;
	msg = (ndmp_mover_close_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "error = %s\n",
			    ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_mover_abort_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg- Reply object to be
 * printed in the log file.
 */
void
ndmp_mover_abort_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_mover_abort_reply *msg;
	msg = (ndmp_mover_abort_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "error = %s\n",
			    ndmpErrorCodeToStr(msg->error));
}

/*
 * Code for version 2.0 starts here
 */
int
mover_set_window_core(ndmp_error error,
	ndmp_u_quad * offset, ndmp_u_quad * length,
			FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_mover_set_window_request *request =
	(ndmp_mover_set_window_request *) malloc
	(sizeof (ndmp_mover_set_window_request));
	if (offset != NULL) {
		request->offset.high = offset->high;
		request->offset.low = offset->low;
	} else {
		request->offset.high = 0;
		request->offset.low = 0;
	}
	if (length != NULL) {
		request->length.high = length->high;
		request->length.low = length->low;
	} else {
		request->length.high = 0;
		request->length.low = 0;
	}
	ndmp_lprintf(outfile, "REQUEST : NDMP_MOVER_SET_WINDOW\n");
	if (!process_request((void *) request,
		NDMP_MOVER_SET_WINDOW, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL && error ==
		    ((ndmp_mover_set_window_reply *) reply_mem)->error) {
			ndmp_mover_set_window_reply_print(outfile,
				((ndmp_mover_set_window_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

int
mover_set_rec_size_core(ndmp_error error, ulong_t size,
	FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_mover_set_record_size_request *request =
	(ndmp_mover_set_record_size_request *)
		malloc(sizeof (ndmp_mover_set_record_size_request));

	request->len = size;
	ndmp_lprintf(outfile, "REQUEST : NDMP_MOVER_SET_RECORD_SIZE\n");
	if (!process_request((void *) request,
		NDMP_MOVER_SET_RECORD_SIZE, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL && error != 0)
			ndmp_mover_set_record_size_reply_print(outfile,
			((ndmp_mover_set_record_size_reply *) reply_mem));
		return (SUCCESS);
	}
	return (ERROR);
}

int
mover_abort_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_lprintf(outfile, "REQUEST : NDMP_MOVER_ABORT\n");
	if (!process_request(NULL,
		NDMP_MOVER_ABORT, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_mover_abort_reply *)
						reply_mem)->error) {
			ndmp_mover_abort_reply_print(outfile,
				((ndmp_mover_abort_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

int
mover_stop_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem;
	ndmp_lprintf(outfile, "REQUEST : NDMP_MOVER_STOP\n");
	if (!process_request(NULL,
			NDMP_MOVER_STOP, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_mover_stop_reply *) reply_mem)->error) {
			ndmp_mover_stop_reply_print(outfile,
				((ndmp_mover_stop_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

int
mover_listen_core(ndmp_error error,
	ndmp_mover_mode mode, ndmp_addr_type addr_type,
		void **tcpObj, FILE * outfile, conn_handle * conn)
{
	void *obj = NULL;
	ndmp_mover_listen_reply *reply_mem = NULL;
	ndmp_mover_listen_request *request = NULL;
	/*
	 * Create and print the object start
	 */
	request = (ndmp_mover_listen_request *)
		malloc(sizeof (ndmp_mover_listen_request));
	request->mode = mode;
	request->addr_type = addr_type;

	switch (request->mode) {
	case NDMP_MOVER_MODE_READ:
		ndmp_lprintf(outfile, "Mode : NDMP_MOVER_MODE_READ\n");
		break;
	case NDMP_MOVER_MODE_WRITE:
		ndmp_lprintf(outfile, "Mode : NDMP_MOVER_MODE_WRITE\n");
		break;
	case NDMP_MOVER_MODE_NOACTION:
		ndmp_lprintf(outfile, "Mode : NDMP_MOVER_MODE_NOACTION\n");
		break;
	default:
		ndmp_lprintf(outfile, "Unknown mode\n");
		if (error != NDMP_ILLEGAL_ARGS_ERR)
			return (1);

	}
	switch (request->addr_type) {
	case NDMP_ADDR_LOCAL:
		ndmp_lprintf(outfile, "Connection type : NDMP_ADDR_LOCAL\n");
		break;
	case NDMP_ADDR_TCP:
		ndmp_lprintf(outfile, "Connection type : NDMP_ADDR_TCP\n");
		break;
	case NDMP_ADDR_IPC:
		ndmp_lprintf(outfile, "Connection type : NDMP_ADDR_IPC\n");
		break;
	default:
		ndmp_lprintf(outfile, "Connection type : Unknown \n");
		if (error != NDMP_ILLEGAL_ARGS_ERR)
			return (1);
	}
	ndmp_lprintf(outfile, "REQUEST : NDMP_MOVER_LISTEN\n");
	if (!process_request((void *) request, NDMP_MOVER_LISTEN,
				conn, (void *) &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_mover_listen_reply *)
						reply_mem)->error) {
			ndmp_mover_listen_reply_print(outfile,
				((ndmp_mover_listen_reply *) reply_mem));
			if (addr_type == NDMP_ADDR_TCP) {
				obj = &(reply_mem->connect_addr);
				tcpObj = &obj;
			}
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * mover_continue_core() : This request is used by the DMA to instruct the
 * mover to transition from the PAUSED state to the ACTIVE state and to
 * resume the transfer of data stream between the data connection and the
 * tape subsystem.
 *
 * Arguments : ndmp_error - Error message. FILE * - handle to log file.
 * Connection * -  Connection handle. Returns : int - 0 for success and 1 for
 * failure.
 */
int
mover_continue_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_lprintf(outfile, "REQUEST : NDMP_MOVER_CONTINUE\n");
	if (!process_request(NULL, NDMP_MOVER_CONTINUE,
				conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_mover_continue_reply *)
						reply_mem)->error) {
			ndmp_mover_continue_reply_print(outfile,
				((ndmp_mover_continue_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * mover_close_core() : This request is used by the DMA to instruct the mover
 * to gracefully close the current data connection and transition to the
 * HALTED state.
 *
 * Arguments : ndmp_error - Error message. FILE * - handle to log file.
 * Connection * -  Connection handle. Returns : int - 0 for success and 1 for
 * failure.
 */
int
mover_close_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_lprintf(outfile, "REQUEST : NDMP_MOVER_CLOSE\n");
	if (!process_request(NULL, NDMP_MOVER_CLOSE,
				conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_mover_close_reply *)
						reply_mem)->error) {
			ndmp_mover_close_reply_print(outfile,
				((ndmp_mover_close_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * mover_connect_core() : This request is used by the DMA to instruct the
 * mover to establish a data connection to a Data Server or peer mover. A
 * connect request is only valid when the mover is in the IDLE state and
 * requires the tape drive to be opened. A successful connect request causes
 * the mover to transition to the ACTIVE state.
 *
 * Arguments : ndmp_error - Error message. FILE * - handle to log file.
 * Connection * -  Connection handle. Returns : int - 0 for success and 1 for
 * failure.
 */
int
mover_connect_core(ndmp_error error, ndmp_mover_mode mode,
	ndmp_addr_type addr_type, ndmp_addr * addr,
			FILE * outfile, conn_handle * conn)
{
	void *reply_mem;
	ndmp_mover_connect_request *request = NULL;
	request = (ndmp_mover_connect_request *)
		malloc(sizeof (ndmp_mover_connect_request));
	if (error == NDMP_ILLEGAL_ARGS_ERR)
		request->mode = 3;
	else
		request->mode = mode;
	request->addr.addr_type = addr_type;
	(void) ndmp_dprintf(outfile,
		"mover_connect_core: tcp obj 0x%x\n", addr);
	if (addr_type == NDMP_ADDR_TCP) {
		if (addr != NULL)
			request->addr = *addr;
		else {
			ndmp_dprintf(outfile,
				"mover_connect_core send failed\n");
			return (1);
		}
	}
	ndmp_lprintf(outfile, "REQUEST : NDMP_MOVER_CONNECT\n");
	if (!process_request((void *) request,
		NDMP_MOVER_CONNECT, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_mover_connect_reply *)
						reply_mem)->error) {
			ndmp_mover_connect_reply_print(outfile,
				((ndmp_mover_connect_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * get_mover_state - sends the NDMP_MOVER_GET_STATE request and returns the
 * state of the mover machine Arguments : outfile : Log file handle conn
 * : Pointer to the connection handle Returns : ndmp_mover_state
 */
ndmp_mover_state
get_mover_state(FILE * logfile, conn_handle * conn)
{
	ndmp_message ndmpMessage = NDMP_MOVER_GET_STATE;
	void *reply_mem = NULL;
	int ret;
	/* send the request start */
	ret = process_request(NULL,
		ndmpMessage, conn, &reply_mem, logfile);
	/* This code is for the server NDMP_NOT_AUTHORIZED_ERR bug. */
	if (ret == E_MALFORMED_PACKET)
		return (ret);
	/* Extract ndmp_mover_state from reply and return */
	if (reply_mem == NULL) {
		return (ERROR);
	} else {
		ndmp_mover_get_state_reply *resultMsg;
		resultMsg = (ndmp_mover_get_state_reply *) reply_mem;
		return (resultMsg->state);
	}
}

/*
 * mover_get_state_core() : This request is used by the DMA to obtain
 * information about the Mover's operational state as represented by the
 * standard mover variable set.
 *
 * Arguments : ndmp_error - Error message. FILE * - handle to log file.
 * Connection * -  Connection handle. Returns : int - 0 for success and 1 for
 * failure.
 */
int
mover_get_state_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_mover_connect_request *request = NULL;
	ndmp_lprintf(outfile, "REQUEST : NDMP_MOVER_GET_STATE\n");
	if (!process_request((void *) request, NDMP_MOVER_GET_STATE,
			conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_mover_get_state_reply *)
				reply_mem)->error) {
			ndmp_mover_get_state_reply_print(outfile,
				((ndmp_mover_get_state_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * mover_mode_read_core() : This request is used to instruct the mover to
 * begin transferring the specified backup stream segment from the tape
 * subsystem to the data connection. The mover MUST be in the ACTIVE state to
 * accept and process a mover read request. Multiple outstanding read
 * requests are not allowed
 *
 * Arguments : ndmp_error - Error message. FILE * - handle to log file.
 * Connection * -  Connection handle. Returns : int - 0 for success and 1 for
 * failure.
 */
int
mover_read_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_mover_read_request *request = (ndmp_mover_read_request *)
		malloc(sizeof (ndmp_mover_read_request));
	request->offset.high = 0;
	request->offset.low = 0;
	request->length.high = 0;
	request->length.low = STD_REC_SIZE;
	if (error == NDMP_ILLEGAL_ARGS_ERR) {
		request->offset.high = 0;
		request->offset.low = 0;
		request->length.high = 0;
		request->length.low = 0;
	}
	ndmp_lprintf(outfile, "REQUEST : NDMP_MOVER_READ\n");
	if (!process_request((void *) request, NDMP_MOVER_READ,
		conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
		error == ((ndmp_mover_read_reply *)
			reply_mem)->error) {
			ndmp_mover_read_reply_print(outfile,
				((ndmp_mover_read_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * Initialize and cleanup methods start from here.
 */

/*
 * mover_set_rec_size_intl() : Initialize the server before calling the mover
 * set record size request.
 *
 * Arguemnts : ndmp_error - Error message expected. char * - Tape device name.
 * FILE * - Handle to log file. Connection * - Handle to connection object.
 * Returns : int - O for success and 1 for failure.
 */
static int
mover_set_rec_size_intl(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	ret += tape_open_core(NDMP_NO_ERR,
		tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);

	/* Return if the error is not NDMP_ILLEGAL_ARGS_ERR */
	if (error != NDMP_ILLEGAL_STATE_ERR)
		return (ret);

	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);
	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = STD_WIN_SIZE;
	ret += mover_set_window_core(NDMP_NO_ERR,
		NULL, &ndmpUQuadObj, outfile, conn);

	ret += mover_listen_core(NDMP_NO_ERR,
		NDMP_MOVER_MODE_WRITE, NDMP_ADDR_LOCAL, NULL, outfile, conn);
	return (ret);
}

/*
 * mover_set_rec_size_cleanup() : Cleanup the server after calling the mover
 * set record size request.
 *
 * Arguemnts : ndmp_error - Error message expected. FILE * - Handle to log file.
 * Connection * - Handle to connection object. Returns : int - O for success
 * and 1 for failure.
 */
static int
mover_set_rec_size_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error == NDMP_ILLEGAL_STATE_ERR) {
		ret += stop_mover(outfile, conn);
	}
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);
	return (ret);
}

/*
 * mover_set_window_size_intl() : Initialize the server before calling the
 * mover set window size request.
 *
 * Arguemnts : ndmp_error - Error message expected. char * - Tape device name.
 * FILE * - Handle to log file. Connection * - Handle to connection object.
 * Returns : int - O for success and 1 for failure.
 */
static int
mover_set_window_size_intl(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	ret += tape_open_core(NDMP_NO_ERR,
		tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);
	if (error != NDMP_PRECONDITION_ERR)
		ret += mover_set_rec_size_core(NDMP_NO_ERR,
			STD_REC_SIZE, outfile, conn);
	else
		ret += mover_set_rec_size_core(NDMP_NO_ERR,
			-1, outfile, conn);

	/* Return if the error is not NDMP_ILLEGAL_ARGS_ERR */
	if (error != NDMP_ILLEGAL_STATE_ERR)
		return (ret);

	ret += mover_listen_core(NDMP_NO_ERR, NDMP_MOVER_MODE_WRITE,
		NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_connect_core(NDMP_NO_ERR, NDMP_ADDR_LOCAL,
		NULL, outfile, conn);
	return (ret);
}

/*
 * mover_set_window_size_cleanup() : Cleanup the server after calling the
 * mover set window size request.
 *
 * Arguemnts : ndmp_error - Error message expected. FILE * - Handle to log file.
 * Connection * - Handle to connection object. Returns : int - O for success
 * and 1 for failure.
 */
static int
mover_set_window_size_cleanup(ndmp_error error,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error == NDMP_ILLEGAL_STATE_ERR) {
		ret = stop_data(outfile, conn);
		ret += stop_mover(outfile, conn);
	}
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * mover_connect_intl() : Initialize the server before calling the mover
 * connect request.
 *
 * Arguemnts : ndmp_error - Error message expected. char * - Tape device name.
 * FILE * - Handle to log file. Connection * - Handle to connection object.
 * Returns : int - O for success and 1 for failure.
 */
static int
mover_connect_intl(ndmp_error error, char *tape_dev,
	ndmp_addr_type addr_type, ndmp_addr ** tcp_obj,
		FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	if (error == NDMP_DEV_NOT_OPEN_ERR)
		return (ret);
	if (error == NDMP_PERMISSION_ERR)
		ret += tape_open_core(NDMP_NO_ERR,
			tape_dev, "NDMP_TAPE_READ_MODE", outfile, conn);
	else
		ret += tape_open_core(NDMP_NO_ERR,
			tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);

	if (error != NDMP_PRECONDITION_ERR) {
		ret += mover_set_rec_size_core(NDMP_NO_ERR,
			STD_REC_SIZE, outfile, conn);
	} else {
		ret += mover_set_rec_size_core(NDMP_NO_ERR,
			30, outfile, conn);
	}
	ndmpUQuadObj.high = 0;
	if (error != NDMP_PRECONDITION_ERR) {
		ndmpUQuadObj.low = STD_WIN_SIZE;
		ret += mover_set_window_core(NDMP_NO_ERR,
			NULL, &ndmpUQuadObj, outfile, conn);
	} else {
		ndmpUQuadObj.low = 31;
		ret += mover_set_window_core(NDMP_NO_ERR,
			NULL, &ndmpUQuadObj, outfile, conn);
	}

	if (error == NDMP_ILLEGAL_STATE_ERR)
		return (ret);
	if (addr_type != NDMP_ADDR_TCP) {
		ndmp_dprintf(outfile,
			"mover_connect_intl: "
			"NDMP_ADDR_LOCAL 0x%x\n", addr_type);
		ret += data_listen_core(NDMP_NO_ERR,
			NDMP_ADDR_LOCAL, NULL, outfile, conn);
	} else {
		ret += data_listen_core(NDMP_NO_ERR,
			NDMP_ADDR_TCP, tcp_obj, outfile, conn);
		ndmp_dprintf(outfile,
			"mover_connect_intl: "
			"NDMP_ADDR_TCP tcp obj 0x%x\n", *tcp_obj);
	}

	return (ret);
}

/*
 * mover_connect_cleanup() : Cleanup the server after calling the mover
 * connect request.
 *
 * Arguemnts : ndmp_error - Error message expected. FILE * - Handle to log file.
 * Connection * - Handle to connection object. Returns : int - O for success
 * and 1 for failure.
 */
static int
mover_connect_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = stop_data(outfile, conn);
		ret += stop_mover(outfile, conn);
	}
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * mover_listen_intl() : Initialize the server before calling the mover
 * listen request.
 *
 * Arguemnts : ndmp_error - Error message expected. char * - Tape device name.
 * FILE * - Handle to log file. Connection * - Handle to connection object.
 * Returns : int - O for success and 1 for failure.
 */
static int
mover_listen_intl(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	ndmp_dprintf(outfile,
		"mover_listen_intl : "
		"start, line -> %d\n", __LINE__);
	if (error == NDMP_DEV_NOT_OPEN_ERR) {
		ndmp_dprintf(outfile,
			"mover_listen_intl: line -> %d\n", __LINE__);
		return (ret);
	}
	ret = tape_open_core(NDMP_NO_ERR, tape_dev,
		"NDMP_TAPE_RDWR_MODE", outfile, conn);
	ndmp_dprintf(outfile, "mover_listen_intl: line -> %d\n", __LINE__);
	if (error == NDMP_PRECONDITION_ERR || error == NDMP_PERMISSION_ERR)
		return (ret);
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);

	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = STD_WIN_SIZE;
	ret += mover_set_window_core(NDMP_NO_ERR,
		NULL, &ndmpUQuadObj, outfile, conn);
	ndmp_dprintf(outfile,
		"mover_listen_intl : "
		"line -> %d, ret -> %d\n", __LINE__, ret);

	return (ret);
}

/*
 * mover_listen_cleanup() : Cleanup the server after calling the mover listen
 * request.
 *
 * Arguemnts : ndmp_error - Error message expected. FILE * - Handle to log file.
 * Connection * - Handle to connection object. Returns : int - O for success
 * and 1 for failure.
 */
static int
mover_listen_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret += stop_mover(outfile, conn);
	}
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * mover_read_intl() : Initialize the server before calling the mover read
 * request.
 *
 * Arguemnts : ndmp_error - Error message expected. char * - Tape device name.
 * FILE * - Handle to log file. Connection * - Handle to connection object.
 * Returns : int - O for success and 1 for failure.
 */
static int
mover_read_intl(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	if (error == NDMP_ILLEGAL_STATE_ERR)
		return (ret);
	ret += tape_open_core(NDMP_NO_ERR,
		tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);

	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low += STD_WIN_SIZE;
	ret += mover_set_window_core(NDMP_NO_ERR,
		NULL, &ndmpUQuadObj, outfile, conn);
	ret += data_listen_core(NDMP_NO_ERR,
		NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += mover_connect_core(NDMP_NO_ERR,
		NDMP_MOVER_MODE_WRITE, NDMP_ADDR_LOCAL,
			NULL, outfile, conn);

	return (ret);
}

/*
 * mover_read_cleanup() : Cleanup the server after calling the mover read
 * request.
 *
 * Arguemnts : ndmp_error - Error message expected. FILE * - Handle to log file.
 * Connection * - Handle to connection object. Returns : int - O for success
 * and 1 for failure.
 */
static int
mover_read_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = stop_data(outfile, conn);
		ret += stop_mover(outfile, conn);
	}
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * mover_continue_intl() : Initialize the server before calling the mover
 * continue request.
 *
 * Arguemnts : ndmp_error - Error message expected. char * - Tape device name.
 * FILE * - Handle to log file. Connection * - Handle to connection object.
 * Returns : int - O for success and 1 for failure.
 */
static int
mover_continue_intl(ndmp_error error, char *tape_dev,
	char *absBckDirPath, FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	if (error == NDMP_ILLEGAL_STATE_ERR)
		return (ret);
	ret += tape_open_core(NDMP_NO_ERR,
		tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);
	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = 1;
	ret += mover_set_window_core(NDMP_NO_ERR,
		NULL, &ndmpUQuadObj, outfile, conn);
	ret += mover_listen_core(NDMP_NO_ERR,
		NDMP_MOVER_MODE_READ, NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_connect_core(NDMP_NO_ERR,
		NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_start_backup_core(NDMP_NO_ERR,
		absBckDirPath, NULL, outfile, conn);
	/*
	 * Default timeout value is 5 secs.
	 */
	if (error != NDMP_NOT_AUTHORIZED_ERR) {
		/*
		 * Temporarily commented this code on 2nd Feb 2009. Instead
		 * of this method we need to use process_notfication method
		 */
		notify_qrec *list = NULL;
		ret = process_notification(conn,
			NDMP_NOTIFY_MOVER_PAUSED, &list, outfile);
	}
	ndmpUQuadObj.high = 0;
	if (error == NDMP_PRECONDITION_ERR) {
		ndmpUQuadObj.low = 0;
		mover_set_window_core(NDMP_NO_ERR,
			NULL, &ndmpUQuadObj, outfile, conn);
	} else {
		ndmpUQuadObj.low = STD_WIN_SIZE;
		ret += mover_set_window_core(NDMP_NO_ERR,
			NULL, &ndmpUQuadObj, outfile, conn);
	}
	return (ret);
}

/*
 * mover_continue_cleanup() : Cleanup the server after calling the mover
 * continue request.
 *
 * Arguemnts : ndmp_error - Error message expected. FILE * - Handle to log file.
 * Connection * - Handle to connection object. Returns : int - O for success
 * and 1 for failure.
 */
static int
mover_continue_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = stop_data(outfile, conn);
		ret += stop_mover(outfile, conn);
		ret += tape_close_core(NDMP_NO_ERR, outfile, conn);
	}
	return (ret);
}

/*
 * mover_close_intl() : Initialize the server before calling the mover close
 * request.
 *
 * Arguemnts : ndmp_error - Error message expected. char * - Tape device name.
 * FILE * - Handle to log file. Connection * - Handle to connection object.
 * Returns : int - O for success and 1 for failure.
 */
int
mover_close_intl(ndmp_error error, char *tape_dev,
	char *absBckDirPath, FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	if (error == NDMP_ILLEGAL_STATE_ERR)
		return (ret);
	ret += tape_open_core(NDMP_NO_ERR,
		tape_dev, "NDMP_TAPE_RDWR_MODE", outfile, conn);
	ret += mover_set_rec_size_core(NDMP_NO_ERR,
		STD_REC_SIZE, outfile, conn);

	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = 1;
	ret += mover_set_window_core(NDMP_NO_ERR,
		NULL, &ndmpUQuadObj, outfile, conn);

	ret += mover_listen_core(NDMP_NO_ERR,
		NDMP_MOVER_MODE_READ, NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_connect_core(NDMP_NO_ERR,
		NDMP_ADDR_LOCAL, NULL, outfile, conn);
	ret += data_start_backup_core(NDMP_NO_ERR,
		absBckDirPath, NULL, outfile, conn);
	/*
	 * Default timeout value is 5 secs.
	 */
	if (error != NDMP_NOT_AUTHORIZED_ERR) {
		/*
		 * Temporarily commented this code on 2nd Feb 2009. Instead
		 * of this method we need to use process_notfication method
		 */
		notify_qrec *list = NULL;
		ret = process_notification(conn,
			NDMP_NOTIFY_MOVER_PAUSED, &list, outfile);
	}
	return (ret);
}

/*
 * mover_close_cleanup() : Cleanup the server after calling the mover close
 * request.
 *
 * Arguemnts : ndmp_error - Error message expected. FILE * - Handle to log file.
 * Connection * - Handle to connection object. Returns : int - O for success
 * and 1 for failure.
 */
static int
mover_close_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = stop_data(outfile, conn);
		ret += stop_mover(outfile, conn);
	}
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * mover_stop_intl() : Initialize the server before calling the mover stop
 * request.
 *
 * Arguemnts : ndmp_error - Error message expected. char * - Tape device name.
 * FILE * - Handle to log file. Connection * - Handle to connection object.
 * Returns : int - O for success and 1 for failure.
 */
static int
mover_stop_intl(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	if (error == NDMP_ILLEGAL_STATE_ERR)
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
		NDMP_MOVER_MODE_READ, NDMP_ADDR_LOCAL, NULL, outfile, conn);

	ret += mover_abort_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * mover_stop_cleanup() : Cleanup the server after calling the mover abort
 * request.
 *
 * Arguemnts : ndmp_error - Error message expected. FILE * - Handle to log file.
 * Connection * - Handle to connection object. Returns : int - O for success
 * and 1 for failure.
 */
static int
mover_stop_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret += tape_close_core(NDMP_NO_ERR, outfile, conn);
	}
	return (ret);
}

/*
 * mover_abort_intl() : Initialize the server before calling the mover abort
 * request.
 *
 * Arguemnts : ndmp_error - Error message expected. char * - Tape device name.
 * FILE * - Handle to log file. Connection * - Handle to connection object.
 * Returns : int - O for success and 1 for failure.
 */
int
mover_abort_intl(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0;
	if (error == NDMP_ILLEGAL_STATE_ERR)
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
		NDMP_MOVER_MODE_READ, NDMP_ADDR_LOCAL, NULL, outfile, conn);

	return (ret);
}

/*
 * mover_abort_cleanup() : Cleanup the server after calling the mover abort
 * request.
 *
 * Arguemnts : ndmp_error - Error message expected. FILE * - Handle to log file.
 * Connection * - Handle to connection object. Returns : int - O for success
 * and 1 for failure.
 */
static int
mover_abort_cleanup(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = stop_mover(outfile, conn);
	}
	return (ret);
}
/*
 * Interface methods start here.
 */

/*
 * inf_mover_set_rec_size() : Executes all the steps in the test case. First
 * calls the initialize methods to set the test bed. Then sends the actual
 * request. Finally does the cleanup.
 *
 * Arguments :
 *	ndmp_error    - Error condition to test.
 *	FILE *        - Log file handle.
 *	char *        - Tape device.
 *	char *        - Record size.
 *	conn_handle * - Connection object handle.
 * Return :
 *	int           - 0 for success and 1 for failure.
 */
int
inf_mover_set_rec_size(ndmp_error error, char *tape_dev,
	char *rec_size, FILE * outfile, conn_handle * conn)
{
	int ret = 0, res = 0;
	long recSize;
	if (rec_size != NULL) {
		recSize = atol(rec_size);
		ndmp_dprintf(outfile,
			"inf_mover_set_rec_size: "
			"rec_size is %s %lu\n", rec_size, recSize);
	} else {
		recSize = 8192;
		ndmp_lprintf(outfile,
			"Record size is NULL, "
			"so setting it to" "8192\n");
	}
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_mover_set_record_size\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	ret = mover_set_rec_size_intl(error, tape_dev, outfile, conn);
	print_intl_result(ret, outfile);

	res = mover_set_rec_size_core(error, recSize, outfile, conn);
	print_test_result(res, outfile);

	ret = mover_set_rec_size_cleanup(error, outfile, conn);
	print_cleanup_result(ret, outfile);
	return (res);
}

/*
 * inf_mover_set_window_size() :
 * This request establishes a mover window in
 * terms of offset and length. A mover window represents the portion of the
 * overall backup stream that is accessible to the mover without intervening
 * DMA tape manipulation.
 *
 * Executes all the steps in the test case. First calls the initialize methods
 * to set the test bed. Then sends the actual request. Finally does the
 * cleanup.
 *
 * Arguments :
 *	ndmp_error    - Error condition to test.
 *	FILE *        - Log file handle.
 *	conn_handle * - Connection object handle.
 * Return :
 *	int           - 0 for success and 1 for failure.
 */
int
inf_mover_set_window_size(ndmp_error error,
	char *tape_dev, char *win_size, FILE * outfile, conn_handle * conn)
{
	ndmp_u_quad ndmpUQuadObj;
	int ret = 0, res = 0;
	int winSize;

	if (win_size != NULL)
		winSize = atol(win_size);
	else {
		winSize = 8192000;
		ndmp_lprintf(outfile,
			"Window size is NULL,"
			"so setting it to 8192000\n");
	}
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_mover_set_window_size\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	ret = mover_set_window_size_intl(error, tape_dev, outfile, conn);
	if (ret != 0 && error != NDMP_PRECONDITION_ERR) {
		(void) ndmp_fprintf(outfile,
			"Initialization failed.\n");
	}
	ndmpUQuadObj.high = 0;
	ndmpUQuadObj.low = winSize;
	switch (error) {
	case NDMP_NO_ERR:
		res = mover_set_window_core(NDMP_NO_ERR,
			NULL, &ndmpUQuadObj, outfile, conn);
		break;
	case NDMP_PRECONDITION_ERR:
		res = mover_set_window_core(NDMP_PRECONDITION_ERR,
			NULL, &ndmpUQuadObj, outfile, conn);
		break;
	case NDMP_ILLEGAL_ARGS_ERR:
		ndmpUQuadObj.low = ~(ushort_t)0;
		res = mover_set_window_core(NDMP_ILLEGAL_ARGS_ERR,
			NULL, 0, outfile, conn);
		break;
	case NDMP_ILLEGAL_STATE_ERR:
		res = mover_set_window_core(NDMP_ILLEGAL_STATE_ERR,
			NULL, &ndmpUQuadObj, outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		res = mover_set_window_core(NDMP_NOT_AUTHORIZED_ERR,
			NULL, &ndmpUQuadObj, outfile, conn);
		break;
	default:
		break;
	}

	ret = mover_set_window_size_cleanup(error, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"ndmp_mover_set_window_size cleanup failed\n");
	}
	if (res != 0) {
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
 * inf_mover_connect() :
 * This request is used by the DMA to instruct the
 * mover to establish a data connection to a Data Server or peer mover. A
 * connect request is only valid when the mover is in the IDLE state and
 * requires the tape drive to be opened. A successful connect request causes
 * the mover to transition to the ACTIVE state.
 *
 * Executes all the steps in the test case. First calls the initialize methods
 * to set the test bed. Then sends the actual request. Finally does the
 * cleanup.
 *
 * Arguments :
 *	ndmp_error  - Error condition to test.
 *	char *      - Tape device.
 *	FILE *      - Log file handle.
 *	conn_handle - Connection object handle.
 * Return :
 *	int         - 0 for success and 1 for failure.
 */
int
inf_mover_connect(ndmp_error error, char *tape_dev, char *mover_mode,
	char **addr_type, FILE * outfile, conn_handle * conn)
{
	int ret = 0, res = 0;
	ndmp_mover_mode mode;
	ndmp_addr_type addr;
	ndmp_addr *tcp_obj = NULL;
	char *addr_t = NULL;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_mover_connect\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	if (addr_type != NULL) {
		addr_t = *addr_type;
		if (addr_t != NULL)
			(void) ndmp_dprintf(stdout,
				"inf_mover_connect: addr_type %s\n", addr_t);
		else
			(void) ndmp_dprintf(stdout,
				"inf_mover_connect: addr_type is NULL\n");
	}
	if (mover_mode != NULL) {
		mode = convert_mover_mode(mover_mode);
		(void) ndmp_dprintf(outfile,
				"inf_mover_connect: mode is 0x%x\n", mode);
	} else {
		mode = NDMP_MOVER_MODE_READ;
		(void) ndmp_dprintf(outfile,
			"inf_mover_connect: mode is "
			"NDMP_MOVER_MODE_READ\n");
	}

	if (addr_type != NULL) {
		addr = convert_addr_type(addr_t);
		(void) ndmp_dprintf(outfile,
			"inf_mover_connect: "
			"addr_type 0x%x\n", addr);
	} else {
		(void) ndmp_dprintf(outfile,
			"inf_mover_connect: "
			"addr_type NDMP_ADDR_LOCAL\n");
		addr = NDMP_ADDR_LOCAL;
	}

	if (addr_t != NULL)
		(void) ndmp_dprintf(outfile,
			"inf_mover_connect: "
			"addr_type %s 0x%x\n", addr_t, addr);

	ret = mover_connect_intl(error, tape_dev,
		addr, &tcp_obj, outfile, conn);
	(void) ndmp_dprintf(outfile,
		"inf_mover_connect: "
		"tcp obj 0x%x\n", tcp_obj);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"Initialization failed. \n");
	}
	res = mover_connect_core(error, mode, addr, tcp_obj, outfile, conn);
	ret = mover_connect_cleanup(error, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"ndmp_mover_connect cleanup failed\n");
	}
	if (res != 0) {
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
 * inf_mover_listen():
 * This request is used by the DMA to instruct the mover
 * create a connection end point and listen for a subsequent data connection
 * from a Data Server or peer Tape Server (mover). This request is also used
 * by the DMA to obtain the address of connection end point the mover is
 * listening at. A listen request is only valid when the mover is in the IDLE
 * state.
 *
 * Executes all the steps in the test case. First calls the initialize methods
 * to set the test bed. Then sends the actual request. Finally does the
 * cleanup.
 *
 * Arguments :
 *	ndmp_error    - Error condition to test.
 *	char *        - Tape device.
 *	FILE *        - Log file handle.
 *	conn_handle * - Connection object handle.
 * Return :
 *	int           - 0 for success and 1 for failure.
 */
int
inf_mover_listen(ndmp_error error, char *tape_dev, char *mover_mode,
	char *addr_type, FILE * outfile, conn_handle * conn)
{
	int ret = 0, res = 0;
	ndmp_mover_mode mode;
	ndmp_addr_type  addr;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_mover_listen\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	ret = mover_listen_intl(error, tape_dev, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"Initialization failed. \n");
	}
	if (mover_mode != NULL)
		mode = convert_mover_mode(mover_mode);
	else
		mode = NDMP_MOVER_MODE_READ;
	if (addr_type != NULL)
		addr = convert_addr_type(addr_type);
	else
		addr = NDMP_ADDR_LOCAL;
	switch (error) {
	case NDMP_NO_ERR:
		res = mover_listen_core(NDMP_NO_ERR,
			mode, addr, NULL, outfile, conn);
		break;
	case NDMP_PRECONDITION_ERR:
		res = mover_listen_core(NDMP_PRECONDITION_ERR,
			mode, addr, NULL, outfile, conn);
		break;
	case NDMP_ILLEGAL_STATE_ERR:
		res = mover_listen_core(NDMP_ILLEGAL_STATE_ERR,
			mode, addr, NULL, outfile, conn);
		res = mover_listen_core(NDMP_ILLEGAL_STATE_ERR,
			mode, addr, NULL, outfile, conn);
		break;
	case NDMP_ILLEGAL_ARGS_ERR:
		/* Mode and Addr are illegal */
		res = mover_listen_core(NDMP_ILLEGAL_ARGS_ERR,
			3, 4, NULL, outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		res = mover_listen_core(NDMP_NOT_AUTHORIZED_ERR,
			mode, addr, NULL, outfile, conn);
		break;
	case NDMP_PERMISSION_ERR:
		res = mover_listen_core(NDMP_PERMISSION_ERR,
			mode, addr, NULL, outfile, conn);
		break;
	case NDMP_DEV_NOT_OPEN_ERR:
		res = mover_listen_core(NDMP_DEV_NOT_OPEN_ERR,
			mode, addr, NULL, outfile, conn);
		break;
	default:
		break;
	}

	if (error != NDMP_ILLEGAL_STATE_ERR) {
		ret = mover_listen_cleanup(error, outfile, conn);
		if (ret != 0) {
			(void) ndmp_fprintf(outfile,
				"ndmp mover_listen cleanup failed\n");
		}
	}
	if (res != 0) {
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
 * inf_mover_read():
 * This request is used by the DMA to instruct the mover to
 * begin transferring the specified backup stream segment from the tape
 * subsystem to the data connection. The mover MUST be in the ACTIVE state to
 * accept and process a mover read request. Multiple outstanding read
 * requests are not allowed.
 *
 * Executes all the steps in the test case. First calls the initialize methods
 * to set the test bed. Then sends the actual request. Finally does the
 * cleanup.
 *
 * Arguments :
 * 	ndmp_error    - Error condition to test.
 *	char *        - Tape device.
 *	FILE *        - Log file handle.
 *	conn_handle * - Connection object handle.
 * Return :
 *	int           - 0 for success and 1 for failure.
 */
int
inf_mover_read(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0, res = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_mover_read\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	ret = mover_read_intl(error, tape_dev, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"Initialization failed. \n");
	}
	switch (error) {
	case NDMP_NO_ERR:
		res = mover_read_core(NDMP_NO_ERR, outfile, conn);
		break;
	case NDMP_ILLEGAL_ARGS_ERR:
		res = mover_read_core(NDMP_ILLEGAL_ARGS_ERR,
			outfile, conn);
		break;
	case NDMP_ILLEGAL_STATE_ERR:
		res = mover_read_core(NDMP_ILLEGAL_STATE_ERR,
			outfile, conn);
		break;
	case NDMP_READ_IN_PROGRESS_ERR:
		res = mover_read_core(NDMP_NO_ERR,
			outfile, conn);
		res = mover_read_core(NDMP_READ_IN_PROGRESS_ERR,
			outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		res = mover_read_core(NDMP_NOT_AUTHORIZED_ERR,
			outfile, conn);
		break;
	default:
		break;
	}

	ret = mover_read_cleanup(error, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"ndmp_mover_read cleanup failed\n");
	}
	if (res != 0) {
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
 * inf_mover_get_state(): This request is used by the DMA to obtain information
 * about the Mover's operational state as represented by the standard mover
 * variable set.
 *
 * Executes all the steps in the test case.
 *
 * Arguments :
 *	ndmp_error    - Error condition to test.
 *	FILE *        - Log file handle.
 *	conn_handle * - Connection object handle.
 * Return : int       - 0 for success and 1 for failure.
 */
/* ARGSUSED */
int
inf_mover_get_state(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_mover_get_state\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	switch (error) {
	case NDMP_NO_ERR:
		ret = mover_get_state_core(NDMP_NO_ERR, outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		ret = mover_get_state_core(NDMP_NOT_AUTHORIZED_ERR,
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
 * inf_mover_continue():
 * This request is used by the DMA to instruct the
 * mover to transition from the PAUSED state to the ACTIVE state and to
 * resume the transfer of data stream between the data connection and the
 * tape subsystem.
 *
 * Executes all the steps in the test case. First calls the initialize methods
 * to set the test bed. Then sends the actual request. Finally does the
 * cleanup.
 *
 * Arguments :
 *	ndmp_error    - Error condition to test.
 *	char *        - Tape device.
 *	FILE *        - Log file handle.
 *	conn_handle * - Connection object handle.
 *	Return :
 *	int           - 0 for success and 1 for failure.
 */
int
inf_mover_continue(ndmp_error error, char *tape_dev,
	char *absBckDirPath, FILE * outfile, conn_handle * conn)
{
	int ret = 0, res = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_mover_continue\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	ndmp_dprintf(stdout,
		"line # connhandle  %d %d\n", __LINE__, conn->connhandle);

	ret = mover_continue_intl(error, tape_dev,
		absBckDirPath, outfile, conn);
	print_intl_result(ret, outfile);

	res = mover_continue_core(error, outfile, conn);
	print_test_result(res, outfile);

	ret = mover_continue_cleanup(error, outfile, conn);
	print_cleanup_result(ret, outfile);

	return (res);
}

/*
 * inf_mover_close():
 * This request is used by the DMA to instruct the mover
 * to gracefully close the current data connection and transition to the
 * HALTED state.
 *
 * Executes all the steps in the test case. First calls the initialize methods
 * to set the test bed. Then sends the actual request. Finally does the
 * cleanup.
 *
 * Arguments :
 *	ndmp_error    - Error condition to test.
 *	char *        - Tape device.
 *	FILE *        - Log file handle.
 *	conn_handle * - Connection object handle.
 * Return :
 *	int           - 0 for success and 1 for failure.
 */
int
inf_mover_close(ndmp_error error, char *tape_dev,
	char *absBckDirPath, FILE * outfile, conn_handle * conn)
{
	int ret = 0, res = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_mover_close\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	ret = mover_close_intl(error, tape_dev, absBckDirPath, outfile, conn);
	mover_get_state_core(NDMP_NO_ERR, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile, "Initialization failed. \n");
	}
	switch (error) {
	case NDMP_NO_ERR:
		res = mover_close_core(NDMP_NO_ERR, outfile, conn);
		break;
	case NDMP_ILLEGAL_STATE_ERR:
		res = mover_close_core(NDMP_ILLEGAL_STATE_ERR,
			outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		res = mover_close_core(NDMP_NOT_AUTHORIZED_ERR,
			outfile, conn);
		break;
	default:
		break;
	}

	ret = mover_close_cleanup(error, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"ndmp_mover_close cleanup failed\n");
	}
	if (res != 0) {
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
 * inf_mover_abort():
 * This request is used by the DMA to instruct the mover
 * to terminate any in progress mover operation, close the data connection if
 * present, and transition the mover to the to the HALTED state. An abort
 * request can be issued from any mover state except IDLE.
 *
 * Executes all the steps in the test case. First calls the initialize methods
 * to set the test bed. Then sends the actual request. Finally does the
 * cleanup.
 *
 * Arguments :
 *	ndmp_error    - Error condition to test.
 *	char *        - Tape device.
 *	FILE *        - Log file handle.
 *	conn_handle * - Connection object handle.
 * Return :
 *	int           - 0 for success and 1 for failure.
 */
int
inf_mover_abort(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0, res = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_mover_abort\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	ret = mover_abort_intl(error, tape_dev, outfile, conn);
	if (ret != 0 && error != NDMP_NOT_AUTHORIZED_ERR) {
		(void) ndmp_fprintf(outfile,
			"Initialization failed. \n");
	}
	switch (error) {
	case NDMP_NO_ERR:
		res = mover_abort_core(NDMP_NO_ERR, outfile, conn);
		break;
	case NDMP_ILLEGAL_STATE_ERR:
		res = mover_abort_core(NDMP_ILLEGAL_STATE_ERR,
			outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		res = mover_abort_core(NDMP_NOT_AUTHORIZED_ERR,
			outfile, conn);
		break;
	default:
		break;
	}

	ret = mover_abort_cleanup(error, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"ndmp_mover_abort cleanup failed\n");
	}
	if (res != 0) {
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
 * inf_mover_stop():
 * This request is used by the DMA to instruct the mover to
 * release all resources, reset all mover state variables (except
 * record_size), and transition the mover to the IDLE state.
 *
 * Executes all the steps in the test case. First calls the initialize methods
 * to set the test bed. Then sends the actual request. Finally does the
 * cleanup.
 *
 * Arguments :
 *	ndmp_error  - Error condition to test
 *	char *      - Tape device.
 *	FILE *      - Log file handle.
 *	conn_handle - Connection object handle.
 * Return :
 * 	int         - 0 for success and 1 for failure.
 */
int
inf_mover_stop(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0, res = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_mover_stop\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	ret = mover_stop_intl(error, tape_dev, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
			"Initialization failed. \n");
	}
	switch (error) {
	case NDMP_NO_ERR:
		res = mover_stop_core(NDMP_NO_ERR, outfile, conn);
		break;
	case NDMP_ILLEGAL_STATE_ERR:
		res = mover_stop_core(NDMP_ILLEGAL_STATE_ERR,
					outfile, conn);
		break;
	case NDMP_NOT_AUTHORIZED_ERR:
		res = mover_stop_core(NDMP_NOT_AUTHORIZED_ERR,
					outfile, conn);
		break;
	default:
		break;
	}

	ret = mover_stop_cleanup(error, outfile, conn);
	if (ret != 0) {
		(void) ndmp_fprintf(outfile,
				"ndmp_mover_stop cleanup failed\n");
	}
	if (res != 0) {
		(void) ndmp_fprintf(outfile,
				"Test case result : Fail\n");
		return (1);
	} else {
		(void) ndmp_fprintf(outfile,
				"Test case result : Pass\n");
		return (0);
	}
}

int
unit_test_mover_get_state(char *tape_dev, host_info * host, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_get_state: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) open_connection(host, &conn, logfile);
	inf_mover_get_state(NDMP_NO_ERR,
		tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_get_state: "
		"Test 1: NDMP_NO_ERR end\n");

	/* Test 2: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_get_state: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	inf_mover_get_state(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(host->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_get_state: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	return (1);
}

int
unit_test_mover_abort(char *tape_dev, host_info * host, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_abort: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_abort(NDMP_NO_ERR, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_abort: "
		"Test 1: NDMP_NO_ERR end\n");

	/* Test 2: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_abort: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_abort(NDMP_NOT_AUTHORIZED_ERR, tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(host->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_abort: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	/* Test 3: NDMP_ILLEGAL_STATE_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_abort: "
		"Test 3: NDMP_NO_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_abort(NDMP_ILLEGAL_STATE_ERR, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_abort: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	return (1);
}

/* NDMP_MOVER_STOP */
int
unit_test_mover_stop(char *tape_dev, host_info * host, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_stop: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_stop(NDMP_NO_ERR, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_stop: "
		"Test 1: NDMP_NO_ERR end\n");

	/*
	 * Test 2: NDMP_NOT_AUTHORIZED_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_stop: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_stop(NDMP_NOT_AUTHORIZED_ERR, tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(host->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_stop: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	/*
	 * Test 3: NDMP_ILLEGAL_STATE_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_stop: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_stop(NDMP_ILLEGAL_STATE_ERR, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_stop: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	return (1);
}

/*
 * NDMP_MOVER_CLOSE
 */
int
unit_test_mover_close(char *tape_dev, host_info * host, FILE * logfile)
{
	conn_handle conn;
	char *absBckDirPath = "/etc/cron.d";

	/*
	 * Test 1: NDMP_NO_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_close: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_close(NDMP_NO_ERR, tape_dev, absBckDirPath, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_close: "
		"Test 1: NDMP_NO_ERR end\n");

	/*
	 * Test 2: NDMP_NOT_AUTHORIZED_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_close: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_close(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, absBckDirPath, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(host->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_close: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	/*
	 * Test 3: NDMP_ILLEGAL_STATE_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_close: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_close(NDMP_ILLEGAL_STATE_ERR,
		tape_dev, absBckDirPath, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_close: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	return (1);
}

/* NDMP_MOVER_SET_RECORD_SIZE */
int
unit_test_mover_set_record_size(char *tape_dev,
	host_info * host, FILE * logfile)
{
	conn_handle conn;
	char *rec_size = "8192";

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_record_size: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_set_rec_size(NDMP_NO_ERR,
		tape_dev, rec_size, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_record_size: "
		"Test 1: NDMP_NO_ERR end\n");

	/* Test 2: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_record_size: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_set_rec_size(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, rec_size, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(host->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_record_size: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	/* Test 3: NDMP_ILLEGAL_STATE_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_record_size: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_set_rec_size(NDMP_ILLEGAL_STATE_ERR,
		tape_dev, rec_size, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_record_size: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	/*
	 * NDMP_ILLEGAL_ARGS_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_record_size: "
		"Test 4: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_set_rec_size(NDMP_ILLEGAL_ARGS_ERR,
		tape_dev, "-1", logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_record_size: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR end\n");

	return (1);
}

/* NDMP_MOVER_SET_WINDOW */
int
unit_test_mover_set_window_size(char *tape_dev,
	host_info * host, FILE * logfile)
{
	conn_handle conn;
	char *win_size = "8192000";

	/*
	 * Test 1: NDMP_NO_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_window_size: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_set_window_size(NDMP_NO_ERR,
		tape_dev, win_size, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_window_size: "
		"Test 1: NDMP_NO_ERR end\n");

	/*
	 * Test 2: NDMP_NOT_AUTHORIZED_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_window_size: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_set_window_size(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, win_size, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(host->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_window_size: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	/*
	 * NDMP_ILLEGAL_ARGS_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_window_size: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_set_window_size(NDMP_ILLEGAL_ARGS_ERR,
		tape_dev, 0, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_window_size: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	/*
	 * Test 4: NDMP_ILLEGAL_STATE_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_window_size: "
		"Test 4: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_set_window_size(NDMP_ILLEGAL_STATE_ERR,
		tape_dev, win_size, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_window_size: "
		"Test 4: NDMP_ILLEGAL_STATE_ERR end\n");

	/* Test 5: NDMP_PRECONDITION_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_window_size: "
		"Test 5: NDMP_PRECONDITION_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_set_window_size(NDMP_PRECONDITION_ERR,
		tape_dev, win_size, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_set_window_size: "
		"Test 5: NDMP_PRECONDITION_ERR end\n");

	return (1);
}

/*
 * NDMP_MOVER_CONNECT
 */
int
unit_test_mover_connect(char *tape_dev,
	host_info * host, FILE * logfile)
{
	conn_handle conn;
	char *mover_mode = "NDMP_MOVER_MODE_READ";
	char *addr_type = "NDMP_ADDR_LOCAL";
	ndmp_dprintf(stdout, "addr_type 0x%x\n", addr_type);
	/*
	 * Test 1: NDMP_NO_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) open_connection(host, &conn, logfile);
	inf_mover_connect(NDMP_NO_ERR,
		tape_dev, mover_mode, &addr_type, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 1: NDMP_NO_ERR end\n");

	/*
	 * Test 2: NDMP_NOT_AUTHORIZED_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	inf_mover_connect(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(host->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	/*
	 * Test 3: NDMP_ILLEGAL_STATE_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) open_connection(host, &conn, logfile);
	inf_mover_connect(NDMP_ILLEGAL_STATE_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	/*
	 * Test 4: NDMP_ILLEGAL_ARGS_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR start\n");
	(void) open_connection(host, &conn, logfile);
	inf_mover_connect(NDMP_ILLEGAL_ARGS_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR end\n");

	/*
	 * Test 5: NDMP_PRECONDITION_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 5: NDMP_PRECONDITION_ERR start\n");
	(void) open_connection(host, &conn, logfile);
	inf_mover_connect(NDMP_PRECONDITION_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 5: NDMP_PRECONDITION_ERR end\n");

	/*
	 * Test 6: NDMP_DEV_NOT_OPEN_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 6: NDMP_DEV_NOT_OPEN_ERR start\n");
	(void) open_connection(host, &conn, logfile);
	inf_mover_connect(NDMP_DEV_NOT_OPEN_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 6: NDMP_DEV_NOT_OPEN_ERR end\n");

	/*
	 * Test 7: NDMP_PERMISSION_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 7: NDMP_PERMISSION_ERR start\n");
	(void) open_connection(host, &conn, logfile);
	inf_mover_connect(NDMP_PERMISSION_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_connect: "
		"Test 7: NDMP_PERMISSION_ERR end\n");

	return (1);
}

/* NDMP_MOVER_LISTEN */
int
unit_test_mover_listen(char *tape_dev, host_info * host, FILE * logfile)
{
	conn_handle conn;
	char *mover_mode = "NDMP_MOVER_MODE_READ";
	char *addr_type = "NDMP_ADDR_TCP";

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_listen(NDMP_NO_ERR,
		tape_dev, mover_mode, addr_type, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 1: NDMP_NO_ERR end\n");

	/* Test 2: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_listen(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(host->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	/* Test 3: NDMP_ILLEGAL_STATE_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_listen(NDMP_ILLEGAL_STATE_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	/*
	 * Test 4: NDMP_ILLEGAL_ARGS_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 4: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_listen(NDMP_ILLEGAL_ARGS_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR end\n");

	/*
	 * Test 5: NDMP_PRECONDITION_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 5: NDMP_PRECONDITION_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_listen(NDMP_PRECONDITION_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 5: NDMP_PRECONDITION_ERR end\n");

	/* Test 6: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 6: NDMP_DEV_NOT_OPEN_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_listen(NDMP_DEV_NOT_OPEN_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 6: NDMP_DEV_NOT_OPEN_ERR end\n");

	/* Test 7: NDMP_PERMISSION_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 7: NDMP_PERMISSION_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_listen(NDMP_PERMISSION_ERR,
		tape_dev, NULL, NULL, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_listen: "
		"Test 7: NDMP_PERMISSION_ERR end\n");

	return (1);
}

/*
 * NDMP_MOVER_READ
 */
int
unit_test_mover_read(char *tape_dev,
	host_info * host, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_read: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_read(NDMP_NO_ERR, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_read: "
		"Test 1: NDMP_NO_ERR end\n");


	/* Test 3: NDMP_ILLEGAL_STATE_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_read: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_read(NDMP_ILLEGAL_STATE_ERR, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_read: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	/*
	 * Test 4: NDMP_ILLEGAL_ARGS_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_read: "
		"Test 4: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_read(NDMP_ILLEGAL_ARGS_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_read: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR end\n");

	/* Test 5: NDMP_READ_IN_PROGRESS_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_read: "
		"Test 5: NDMP_READ_IN_PROGRESS_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_read(NDMP_READ_IN_PROGRESS_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_read: "
		"Test 5: NDMP_READ_IN_PROGRESS_ERR end\n");

	/* Test 2: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_read: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_read(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(host->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_read: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	return (1);
}

/* NDMP_MOVER_CONTINUE */
int
unit_test_mover_continue(char *tape_dev,
	host_info * host, FILE * logfile)
{
	conn_handle conn;
	char *absBckDirPath = "/etc/cron.d/";

	/* Test 1: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_continue: "
		"Test 1: NDMP_NO_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d connhandle 0x%x\n",
		__FILE__, __LINE__, conn.connhandle);
	inf_mover_continue(NDMP_NO_ERR,
		tape_dev, absBckDirPath, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_continue: "
		"Test 1: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_ILLEGAL_STATE_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_continue: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_continue(NDMP_ILLEGAL_STATE_ERR,
		tape_dev, absBckDirPath, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_continue: "
		"Test 3: NDMP_ILLEGAL_STATE_ERR end\n");

	/*
	 * Test 4: NDMP_PRECONDITION_ERR
	 */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_continue: "
		"Test 4: NDMP_PRECONDITION_ERR start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_continue(NDMP_PRECONDITION_ERR,
		tape_dev, absBckDirPath, logfile, &conn);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	close_connection(&conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_continue: "
		"Test 4: NDMP_PRECONDITION_ERR end\n");

	/* Test 2: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_continue: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(host->password, "admn");
	(void) open_connection(host, &conn, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	inf_mover_continue(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, absBckDirPath, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(host->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_mover_continue: "
		"Test 2: NDMP_NOT_AUTHORIZED_ERR end\n");

	return (1);
}

#ifdef UNIT_TEST_MOVER

int
main(int argc, char *argv[])
{
	FILE *logfile = NULL;
	char *tape_dev = strdup("/dev/rmt/3n");
	host_info auth;
	auth.ipAddr = strdup("10.12.178.122");
	auth.userName = strdup("admin");
	auth.password = strdup("admin");
	auth.auth_type = NDMP_AUTH_TEXT;

	/* Open Log file */
	logfile = fopen("unit_test_mover.log", "w");
	(void) ndmp_dprintf(logfile, "main: start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	unit_test_mover_get_state(tape_dev, &auth, logfile);
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);
	unit_test_mover_abort(tape_dev, &auth, logfile);
	unit_test_mover_stop(tape_dev, &auth, logfile);
	unit_test_mover_close(tape_dev, &auth, logfile);
	unit_test_mover_set_record_size(tape_dev, &auth, logfile);
	unit_test_mover_set_window_size(tape_dev, &auth, logfile);
	unit_test_mover_connect(tape_dev, &auth, logfile);
	unit_test_mover_listen(tape_dev, &auth, logfile);
	unit_test_mover_read(tape_dev, &auth, logfile);
	unit_test_mover_continue(tape_dev, &auth, logfile);

	(void) ndmp_dprintf(stdout, "main: end\n");
	fclose(logfile);
	free(tape_dev);
	return (1);
}
#endif

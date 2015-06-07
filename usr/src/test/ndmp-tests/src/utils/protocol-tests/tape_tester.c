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
 * The Tape interface provides complete and exclusive control of a tape
 * drive. This files implements all the tape interfaces. There are four type
 * of methods for each interface. These methods types are extract request,
 * extract reply, print reply and compare reply.
 */

#include<string.h>
#include <ndmp.h>
#include <log.h>
#include <mover.h>
#include <ndmp_lib.h>
#include <ndmp_conv.h>
#include <ndmp_comm_lib.h>
#include <process_hdlr_table.h>
#include <tape_tester.h>
#include <ndmp_connect.h>

/*
 * ndmp_tape_open_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_tape_open_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_tape_open_reply *msg;
	msg = (ndmp_tape_open_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "ndmp_error = %s\n",
			    ndmpErrorCodeToStr(msg->error));
}

/*
 * ndmp_tape_close_reply_print
 *
 * Prints the reply object
 *
 * Parameters: out (input) - Handle to the output file ndmpMsg (input) - The
 * message to be printed
 *
 * Return: void
 */
void
ndmp_tape_close_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_tape_close_reply *msg;
	msg = (ndmp_tape_close_reply *) ndmpMsg;
	if (msg != 0)
		(void) ndmp_lprintf(out, "ndmp_error = %s\n",
				    ndmpErrorCodeToStr(msg->error));
	else
		(void) ndmp_lprintf(out, "ndmp_error = NULL \n");
}

/*
 * ndmp_tape_get_state_reply_print
 *
 * Prints the reply object
 *
 * Parameters: out (input) - Handle to the output file ndmpMsg (input) - The
 * message to be printed
 *
 * Return: void
 */
void
ndmp_tape_get_state_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_tape_get_state_reply *msg;
	msg = (ndmp_tape_get_state_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "unsupported %d \n", (int) msg->unsupported);
	(void) ndmp_lprintf(out, "ndmp_error  %s\n",
			    ndmpErrorCodeToStr(msg->error));
	(void) ndmp_lprintf(out, "flags %d\n", (int) msg->flags);
	(void) ndmp_lprintf(out, "file_num %ld\n", msg->file_num);
	(void) ndmp_lprintf(out, "soft_errors %d\n", (int) msg->soft_errors);
	(void) ndmp_lprintf(out, "block_size %d\n", (int) msg->block_size);
	(void) ndmp_lprintf(out, "blockno %d\n", (int) msg->blockno);
	print_ndmp_u_quad(out, msg->total_space);
	print_ndmp_u_quad(out, msg->space_remain);

}

/*
 * ndmp_tape_mtio_print
 */
void
ndmp_tape_mtio_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_tape_mtio_reply *msg;
	msg = (ndmp_tape_mtio_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "ndmp_error = %s\n",
			    ndmpErrorCodeToStr(msg->error));
	(void) ndmp_lprintf(out, "resid_count = %d\n", (int) msg->resid_count);
}

/*
 * ndmp_tape_write_print
 */
void
ndmp_tape_write_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_tape_write_reply *msg;
	msg = (ndmp_tape_write_reply *) ndmpMsg;
	(void) ndmp_lprintf(out, "ndmp_error %s \n",
			    ndmpErrorCodeToStr(msg->error));
	(void) ndmp_lprintf(out, "count %d \n", (int) msg->count);
}

/*
 * ndmp_tape_read_print
 */
void
ndmp_tape_read_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_tape_read_reply *reply;
	reply = (ndmp_tape_read_reply *) ndmpMsg;
	if (reply != 0) {
		(void) ndmp_lprintf(out, "error %s\n",
			ndmpErrorCodeToStr(reply->error));
		print_data_in(out, reply);
	}
}

/*
 * ndmp_tape_execute_cdb_print
 */
void
ndmp_tape_execute_cdb_reply_print(FILE * out, void *ndmpMsg, int cdb)
{
	ndmp_tape_execute_cdb_reply *replyMsg;
	replyMsg = (ndmp_tape_execute_cdb_reply *) ndmpMsg;
	if (replyMsg != 0) {
		(void) ndmp_lprintf(out, "error %s \n",
			ndmpErrorCodeToStr(replyMsg->error));
		(void) ndmp_lprintf(out, "status %d \n",
			replyMsg->status ? replyMsg->status : 'n');
		replyMsg->dataout_len ?
			(void) ndmp_lprintf(out, "dataout_len %d \n",
				(int) replyMsg->dataout_len) :
			(void) ndmp_lprintf(out, "dataout_len is null\n");
		print_datain(out, replyMsg, cdb);
		print_ext_sense(out, &(replyMsg->ext_sense));
	}
}

/*
 * tape_open_core() Basic method to send tape open request to the ndmp server
 */
int
tape_open_core(ndmp_error error, char *tape_dev,
	char *ndmp_tape_open_mode, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_tape_open_request *request =
	(ndmp_tape_open_request *) malloc(sizeof (ndmp_tape_open_request));
	/* Create and print the object start */
	if (ndmp_tape_open_mode == NULL)
		request->mode = NDMP_TAPE_RDWR_MODE;
	else if (!(strcmp(ndmp_tape_open_mode, "NDMP_TAPE_READ_MODE")))
		request->mode = NDMP_TAPE_READ_MODE;
	else if (!(strcmp(ndmp_tape_open_mode, "NDMP_TAPE_RDWR_MODE")))
		request->mode = NDMP_TAPE_RDWR_MODE;
	else
		request->mode = NDMP_TAPE_RAW_MODE;
	request->device = strdup(tape_dev);
	/* Create and print the object end */
	ndmp_lprintf(outfile, "REQUEST : NDMP_TAPE_OPEN\n");
	/* send the request start */
	if (!process_request((void *) request,
			NDMP_TAPE_OPEN, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_tape_open_reply *) reply_mem)->error) {
			ndmp_tape_open_reply_print(outfile,
				((ndmp_tape_open_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	/* send the request end */
	return (ERROR);
}

/*
 * tape_close_core() Basic method to send tape open request to the ndmp
 * server
 */
int
tape_close_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	/* Create and print the object end */
	ndmp_lprintf(outfile, "REQUEST : NDMP_TAPE_CLOSE\n");
	/* send the request start */
	if (!process_request(NULL, NDMP_TAPE_CLOSE,
			conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_tape_close_reply *) reply_mem)->error) {
			ndmp_tape_close_reply_print(outfile,
				(ndmp_tape_close_reply *) reply_mem);
			return (SUCCESS);
		}
	}
	/* send the request end */
	return (ERROR);
}

/*
 * tape_get_state_core() : This request returns the state of the tape drive
 * interface.
 */
int
tape_get_state_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	/* Create and print the object start */
	ndmp_lprintf(outfile, "REQUEST : NDMP_TAPE_GET_STATE\n");
	/* send the request start */
	if (!process_request(NULL, NDMP_TAPE_GET_STATE,
			conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_tape_get_state_reply *)
							reply_mem)->error) {
			ndmp_tape_get_state_reply_print(outfile,
				(ndmp_tape_get_state_reply *) reply_mem);
			return (SUCCESS);
		}
	}
	/* Compare and print the reply start */
	return (ERROR);
}

/*
 * tape_mtio_core() : This request provides access to common magnetic tape
 * I/O operations.
 */
int
tape_mtio_core(ndmp_error error, char *tape_op,
FILE * outfile, conn_handle * conn)
{
	ndmp_tape_mtio_request *request;

	void *reply_mem = NULL;
	/* Create and print the object start */
	ndmp_lprintf(outfile, "REQUEST : NDMP_TAPE_MTIO\n");
	/* Create and print the object end */
	request = (ndmp_tape_mtio_request *)
		malloc(sizeof (ndmp_tape_mtio_request));
	request->tape_op = convert_tape_mtio_op(tape_op);
	ndmp_dprintf(outfile, "tape op is %d\n", request->tape_op);
	request->count = 0;

	/* Send the request start */
	if (!process_request((void *) request,
		NDMP_TAPE_MTIO, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_tape_mtio_reply *) reply_mem)->error) {
			ndmp_tape_mtio_reply_print(outfile, reply_mem);
			return (SUCCESS);
		}
	}
	return (ERROR);
	/* Compare and print the reply end */
}

/*
 * tape_write_core() : This request writes data to the tape device. The
 * number of tape blocks written depends on the mode of the tape drive:
 *
 * - In variable block size mode, the NDMP Server writes count bytes of data to
 * one tape block.
 *
 * - In fixed block size mode, the NDMP Server writes the data to the number of
 * tape blocks computed as specified earlier. It is the client's
 * responsibility to ensure that count is a multiple of that fixed block
 * size.
 *
 * Arguments : error - ndmp_error data_out - Data to be written to Tape. FILE *
 * - Log file. Connection * - Connection handle.
 *
 * Return : Success is 0 and Failure is 1.
 */
int
tape_write_core(ndmp_error error, char *data_out,
	FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	/* Create and print the object start */
	ndmp_tape_write_request *request = (ndmp_tape_write_request *) malloc
	(sizeof (ndmp_tape_write_request));
	if (data_out == NULL) {
		request->data_out.data_out_val = strdup("ndmp_tape_write");
		request->data_out.data_out_len = strlen("ndmp_tape_write");
	} else {
		request->data_out.data_out_val = data_out;
		request->data_out.data_out_len = strlen(data_out);
	}
	ndmp_lprintf(outfile, "REQUEST : NDMP_TAPE_WRITE\n");
	/* send the request start */
	if (!process_request((void *) request,
		NDMP_TAPE_WRITE, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_tape_write_reply *) reply_mem)->error) {
			ndmp_tape_write_reply_print(outfile, reply_mem);
			return (SUCCESS);
		}
	}
	if (data_out == NULL) {
		free(request->data_out.data_out_val);
	}
	/* Compare and print the reply start */
	return (ERROR);
}

/*
 * tape_read_core() : This request reads data from the tape drive. The number
 * of tape blocks read depends on the mode of the tape drive:
 *
 * - In variable block size mode, the NDMP Server reads one tape block and
 * returns, at most, count bytes of data. If the tape block contains more
 * than count bytes, that data is discarded.
 *
 * - In fixed block size mode, the NDMP Server reads data from the number of
 * tape blocks computed as described earlier. It is the client's
 * responsibility to ensure that count is a multiple of the fixed block size.
 */
int
tape_read_core(ndmp_error error, int len, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	/* Create and print the object start */
	ndmp_tape_read_request *request =
	(ndmp_tape_read_request *) malloc(sizeof (ndmp_tape_read_request));
	request->count = len;
	ndmp_lprintf(outfile, "REQUEST : NDMP_TAPE_READ\n");
	/* send the request start */
	if (!process_request((void *) request,
		NDMP_TAPE_READ, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_tape_read_reply *) reply_mem)->error) {
			ndmp_tape_read_reply_print(outfile, reply_mem);
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * tape_execute_cdb_core() : This message behaves in exactly the same way as
 * the NDMP_SCSI_EXECUTE_CDB request except that it sends the CDB to the tape
 * device. This request SHOULD not be used to change the state of the tape
 * device (such as tape positioning).
 */
int
tape_execute_cdb_core(ndmp_error error, char *cdb,
	FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	/* Create and print the object start */
	ndmp_tape_execute_cdb_request *request =
		(ndmp_tape_execute_cdb_request *) malloc
	(sizeof (ndmp_tape_execute_cdb_request));
	request->flags = 1;
	request->timeout = 0;
	request->datain_len = 36;
	request->cdb.cdb_len = CDB_SIZE;
	request->cdb.cdb_val = (char *) malloc(CDB_SIZE);
	(void) create_cdb((struct cdb *)&(request->cdb), getCdbNum(cdb));
	request->dataout.dataout_len = 0;
	request->dataout.dataout_val = 0;
	ndmp_lprintf(outfile, "REQUEST : NDMP_TAPE_EXECUTE_CDB\n");
	/* send the request start */
	if (!process_request((void *) request,
		NDMP_TAPE_EXECUTE_CDB, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
		error == ((ndmp_tape_execute_cdb_reply *) reply_mem)->error) {
			ndmp_tape_execute_cdb_reply_print(outfile,
						reply_mem, getCdbNum(cdb));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * Initilize and Cleanup methods
 */
int
tape_open_intl(ndmp_error error, char **tape_dev,
	conn_handle * conn, FILE * outfile)
{
	char *command;
	int ret = 0;
	if (error == NDMP_NO_DEVICE_ERR) {
		*tape_dev = strdup("no dev err");
	}
	if (error == NDMP_DEVICE_OPENED_ERR)
		ret = tape_open_core(NDMP_NO_ERR, *tape_dev,
						NULL, outfile, conn);
	if (error == NDMP_NO_TAPE_LOADED_ERR) {
		ret = tape_open_core(NDMP_NO_ERR, *tape_dev,
						NULL, outfile, conn);
		command = strdup("UNLOAD");
		ret += tape_execute_cdb_core(NDMP_NO_ERR,
					command, outfile, conn);
		free(command);
		ret += tape_close_core(NDMP_NO_ERR, outfile, conn);
	}
	return (ret);
}

int
tape_open_cleanup(ndmp_error error, char *tape_dev,
	conn_handle * conn, FILE * outfile)
{
	char command[50];
	int ret = 0;
	ndmp_dprintf(stdout, "File %s:%d\n", __FILE__, __LINE__);
	if (error == NDMP_NO_DEVICE_ERR) {
		free(tape_dev);
		return (ret);
	}
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	if (error == NDMP_NO_TAPE_LOADED_ERR) {
		ndmp_dprintf(stdout, "%s:%d\n", __FILE__, __LINE__);
		memset(command, '\0', 50);
		strcpy(command, "LOAD");
		ndmp_dprintf(stdout, "%s:%d\n", __FILE__, __LINE__);
		ret = tape_open_core(NDMP_NO_ERR,
			tape_dev, "NDMP_TAPE_RAW_MODE", outfile, conn);
		ndmp_dprintf(stdout, "%s:%d\n", __FILE__, __LINE__);
		tape_execute_cdb_core(NDMP_NO_ERR, command, outfile, conn);
		ndmp_dprintf(stdout, "%s:%d\n", __FILE__, __LINE__);
		ret = tape_close_core(NDMP_NO_ERR, outfile, conn);
	} else
		ret = tape_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

int
tape_close_intl(ndmp_error error, char **tape_dev,
	conn_handle * conn, FILE * outfile)
{
	char *command;
	int ret = 0;

	if (error == NDMP_DEV_NOT_OPEN_ERR)
		return (0);
	if (error == NDMP_NO_TAPE_LOADED_ERR) {
		ret = tape_open_core(NDMP_NO_ERR, *tape_dev,
						NULL, outfile, conn);
		command = strdup("UNLOAD");
		ret += tape_execute_cdb_core(NDMP_NO_ERR,
					command, outfile, conn);
		free(command);
	}
	ret = tape_open_core(NDMP_NO_ERR, *tape_dev, NULL, outfile, conn);
	return (ret);
}

/*
 * tape_get_state_intl() Initialize, before executing tape get state request.
 */
int
tape_get_state_intl(ndmp_error error, char *tape_dev,
	conn_handle * conn, FILE * outfile)
{
	int ret = 0;
	if (error == NDMP_DEV_NOT_OPEN_ERR)
		return (0);
	ret = tape_open_core(NDMP_NO_ERR, tape_dev, NULL, outfile, conn);
	return (ret);
}

/*
 * tape_mtio_intl() Initialize, before executing tape mtio request.
 */
int
tape_mtio_intl(ndmp_error error, char *tape_dev,
	conn_handle * conn, FILE * outfile)
{
	char *command;
	int ret = 0;
	if (error == NDMP_DEV_NOT_OPEN_ERR)
		return (0);
	if (error == NDMP_NO_TAPE_LOADED_ERR) {
		ret = tape_open_core(NDMP_NO_ERR,
				tape_dev, NULL, outfile, conn);
		command = strdup("UNLOAD");
		ret += tape_execute_cdb_core(NDMP_NO_ERR,
					command, outfile, conn);
		free(command);
		ret += tape_close_core(NDMP_NO_ERR, outfile, conn);
	}
	ret = tape_open_core(NDMP_NO_ERR, tape_dev, NULL, outfile, conn);
	return (ret);
}

/*
 * tape_open_cleanup() Cleanup method for tape mtio interface.
 */
int
tape_mtio_cleanup(ndmp_error error, char *tape_dev,
	conn_handle * conn, FILE * outfile)
{
	int ret = 0;
	if (error == NDMP_DEV_NOT_OPEN_ERR || error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	if (error == NDMP_NO_TAPE_LOADED_ERR) {
		char *command = strdup("LOAD");
		ret = tape_open_core(NDMP_NO_ERR,
			tape_dev, "NDMP_TAPE_RAW_MODE", outfile, conn);
		tape_execute_cdb_core(NDMP_NO_ERR, command, outfile, conn);
		free(command);
	}
	ret = tape_close_core(NDMP_NO_ERR, outfile, conn);
	return (ret);
}

/*
 * tape_write_intl() Initialize, before executing tape write request.
 */
int
tape_write_intl(ndmp_error error, char *tape_dev,
	conn_handle * conn, FILE * outfile)
{
	char *tape_mode;
	char *command;
	int ret = 0;
	if (error == NDMP_DEV_NOT_OPEN_ERR || error == NDMP_NOT_AUTHORIZED_ERR)
		return (0);
	if (error == NDMP_NO_TAPE_LOADED_ERR) {
		ret = tape_open_core(NDMP_NO_ERR,
				tape_dev, NULL, outfile, conn);
		command = strdup("UNLOAD");
		ret += tape_execute_cdb_core(NDMP_NO_ERR,
					command, outfile, conn);
		free(command);
		return (ret);
	}
	if (error == NDMP_PERMISSION_ERR) {
		tape_mode = strdup("NDMP_TAPE_READ_MODE");
		ret = tape_open_core(NDMP_NO_ERR,
			tape_dev, tape_mode, outfile, conn);
		free(tape_mode);
		return (ret);
	}
	if (error == NDMP_DEVICE_BUSY_ERR) {
		ret = tape_open_core(NDMP_NO_ERR,
				tape_dev, NULL, outfile, conn);
		ret += mover_listen_core(NDMP_NO_ERR,
			NDMP_MOVER_MODE_READ, NDMP_ADDR_LOCAL,
				NULL, outfile, conn);
		return (ret);
	}
	ret = tape_open_core(NDMP_NO_ERR, tape_dev, NULL, outfile, conn);
	return (ret);
}

/*
 * tape_write_cleanup() Cleanup method for tape write interface.
 */
int
tape_write_cleanup(ndmp_error error, char *tape_dev,
	conn_handle * conn, FILE * outfile)
{
	int ret = 0;
	if (error == NDMP_DEV_NOT_OPEN_ERR || error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	if (error == NDMP_NO_TAPE_LOADED_ERR) {
		char *command = strdup("LOAD");
		ret = tape_open_core(NDMP_NO_ERR,
			tape_dev, "NDMP_TAPE_RAW_MODE", outfile, conn);
		ret += tape_execute_cdb_core(NDMP_NO_ERR,
						command, outfile, conn);
		free(command);
	}
	if (error == NDMP_DEVICE_BUSY_ERR) {
		(void) mover_abort_core(NDMP_NO_ERR, outfile, conn);
		ret = mover_stop_core(NDMP_NO_ERR, outfile, conn);
	}
	ret += tape_close_core(NDMP_NO_ERR, outfile, conn);
	return (ret);
}

/*
 * tape_read_intl() Initialize, before executing tape read request.
 */
int
tape_read_intl(ndmp_error error, char *tape_dev,
	int *len, conn_handle * conn, FILE * outfile)
{
	int ret = 0;
	char *data_out = "tape_write";
	char *tape_mtio_op = "NDMP_MTIO_REW";
	char *command;

	if (error == NDMP_DEV_NOT_OPEN_ERR)
		return (0);
	if (error == NDMP_NO_TAPE_LOADED_ERR) {
		ret = tape_open_core(NDMP_NO_ERR,
					tape_dev, NULL, outfile, conn);
		command = strdup("UNLOAD");
		ret += tape_execute_cdb_core(NDMP_NO_ERR,
						command, outfile, conn);
		free(command);
		ret += tape_close_core(NDMP_NO_ERR, outfile, conn);
	}
	if (error == NDMP_DEVICE_BUSY_ERR) {
		ret = tape_open_core(NDMP_NO_ERR,
					tape_dev, NULL, outfile, conn);
		ret += mover_listen_core(NDMP_NO_ERR,
			NDMP_MOVER_MODE_READ, NDMP_ADDR_LOCAL,
				NULL, outfile, conn);
		return (ret);
	}
	ret = tape_open_core(NDMP_NO_ERR, tape_dev, NULL, outfile, conn);
	ret += tape_write_core(NDMP_NO_ERR, data_out, outfile, conn);
	ret += tape_mtio_core(NDMP_NO_ERR, tape_mtio_op, outfile, conn);
	*len = strlen(data_out);
	return (ret);
}

/*
 * Interface methods
 */

/*
 * inf_tape_execute_cdb() : This message behaves in exactly the same way as
 * the NDMP_SCSI_EXECUTE_CDB request except that it sends the CDB to the tape
 * device.
 */
int
inf_tape_execute_cdb(ndmp_error error, char *cdb, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_tape_execute_cdb\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	/* Initialization */
	ret = tape_write_intl(error, tape_dev, conn, outfile);
	ndmp_dprintf(outfile, "inf_tape_execute_cdb: Intl return %d\n", ret);
	print_intl_result(ret, outfile);

	/* Send the request */
	if (error == NDMP_ILLEGAL_ARGS_ERR)
		cdb = strdup("illegal");
	if (cdb == NULL)
		cdb = strdup("INQUIRY");
	ret = tape_execute_cdb_core(error, cdb, outfile, conn);
	if (error == NDMP_ILLEGAL_ARGS_ERR)
		free(cdb);
	print_test_result(ret, outfile);

	/* Clean up */
	ret = tape_write_cleanup(error, tape_dev, conn, outfile);
	print_cleanup_result(ret, outfile);
	return (ret);
}

/*
 * inf_tape_write() : This request writes data to the tape device.
 */
int
inf_tape_read(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	int data_out_len = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_tape_read\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	/* Initialization */
	ret = tape_read_intl(error, tape_dev, &data_out_len, conn, outfile);
	ndmp_dprintf(outfile, "inf_tape_write: Intl return %d\n", ret);
	print_intl_result(ret, outfile);

	/* Send the request */
	ret = tape_read_core(error, data_out_len, outfile, conn);
	print_test_result(ret, outfile);

	/* Clean up */
	ret = tape_write_cleanup(error, tape_dev, conn, outfile);
	print_cleanup_result(ret, outfile);
	return (ret);
}

/*
 * inf_tape_write() : This request writes data to the tape device.
 */
int
inf_tape_write(ndmp_error error, char *data_out, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_tape_write\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	/* Initialization */
	ret = tape_write_intl(error, tape_dev, conn, outfile);
	ndmp_dprintf(outfile, "inf_tape_write: Intl return %d\n", ret);
	print_intl_result(ret, outfile);

	/* Send the request */
	ret = tape_write_core(error, data_out, outfile, conn);
	print_test_result(ret, outfile);

	/* Clean up */
	ret = tape_write_cleanup(error, tape_dev, conn, outfile);
	print_cleanup_result(ret, outfile);
	return (ret);
}

/*
 * inf_tape_mtio() : This request provides access to common magnetic tape I/O
 * operations.
 */
int
inf_tape_mtio(ndmp_error error, char *tape_mtio_op, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_tape_mtio\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	/* Initialization */
	ret = tape_mtio_intl(error, tape_dev, conn, outfile);
	ndmp_dprintf(outfile, "inf_tape_mtio: Intl return %d\n", ret);
	print_intl_result(ret, outfile);

	/* Send the request */
	ret = tape_mtio_core(error, tape_mtio_op, outfile, conn);
	print_test_result(ret, outfile);

	/* Clean up */
	ret = tape_mtio_cleanup(error, tape_dev, conn, outfile);
	print_cleanup_result(ret, outfile);
	return (ret);
}

/*
 * inf_tape_get_state() :
 */
int
inf_tape_get_state(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_tape_get_state\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	/* Initialization */
	ret = tape_get_state_intl(error, tape_dev, conn, outfile);
	print_intl_result(ret, outfile);

	/* Send the request */
	ret = tape_get_state_core(error, outfile, conn);
	print_test_result(ret, outfile);

	/* Clean up */
	if (error == NDMP_NO_ERR) {
		ret = tape_close_core(error, outfile, conn);
		print_cleanup_result(ret, outfile);
	}
	return (ret);
}

/*
 * inf_tape_open() :
 */
int
inf_tape_open(ndmp_error error, char *tape_dev, char *ndmp_tape_open_mode,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;

	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_tape_open\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	/* Initialization */
	ret = tape_open_intl(error, &tape_dev, conn, outfile);
	print_intl_result(ret, outfile);

	/* Send the request */
	ret = tape_open_core(error, tape_dev,
		ndmp_tape_open_mode, outfile, conn);
	print_test_result(ret, outfile);

	/* Clean up */
	ret = tape_open_cleanup(error, tape_dev, conn, outfile);
	print_cleanup_result(ret, outfile);
	return (ret);
}

/*
 * inf_tape_close() :
 */
int
inf_tape_close(ndmp_error error, char *tape_dev,
	FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_tape_close\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	/* Initialization */
	ret = tape_close_intl(error, &tape_dev, conn, outfile);
	print_intl_result(ret, outfile);

	/* Send the request */
	ret = tape_close_core(error, outfile, conn);
	print_test_result(ret, outfile);

	print_cleanup_result(tape_open_cleanup(error, tape_dev,
		conn, outfile), outfile);
	return (ret);
}

/*
 * NDMP_TAPE_OPEN
 */
int
unit_test_tape_open(host_info * auth, char *tape_dev, FILE * logfile)
{
	conn_handle conn;
	char *ndmp_tape_open_mode = NULL;

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_open: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_tape_open(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, ndmp_tape_open_mode, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_open: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	ndmp_dprintf(stdout, "File %s:%d\n", __FILE__, __LINE__);
	(void) open_connection(auth, &conn, logfile);
	ndmp_dprintf(stdout, "File %s:%d\n", __FILE__, __LINE__);
	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_open: "
		"Test 2: NDMP_NO_ERR start\n");
	ndmp_dprintf(stdout, "File %s:%d\n", __FILE__, __LINE__);
	inf_tape_open(NDMP_NO_ERR,
		tape_dev, ndmp_tape_open_mode, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_open: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEVICE_OPENED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_open: "
		"Test 3: NDMP_DEVICE_OPENED_ERR start\n");
	inf_tape_open(NDMP_DEVICE_OPENED_ERR,
		tape_dev, ndmp_tape_open_mode, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_open: "
		"Test 3: NDMP_DEVICE_OPENED_ERR end\n");

	/* Test 4: NDMP_NO_TAPE_LOADED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_open: "
		"Test 4: NDMP_NO_TAPE_LOADED_ERR start\n");
	inf_tape_open(NDMP_NO_TAPE_LOADED_ERR,
		tape_dev, ndmp_tape_open_mode, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_open: "
		"Test 4: NDMP_NO_TAPE_LOADED_ERR end\n");

	/* Test 5: NDMP_NO_DEVICE_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_open: "
		"Test 5: NDMP_NO_DEVICE_ERR start\n");
	inf_tape_open(NDMP_NO_DEVICE_ERR,
		tape_dev, ndmp_tape_open_mode, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_open: "
		"Test 5: NDMP_NO_DEVICE_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

/*
 * NDMP_TAPE_CLOSE
 */
int
unit_test_tape_close(host_info * auth, char *tape_dev, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_close: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_tape_close(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_close: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_close: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_tape_close(NDMP_NO_ERR, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_close: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_close: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR start\n");
	inf_tape_close(NDMP_DEV_NOT_OPEN_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_close: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR end\n");

	/* Test 4: NDMP_DEVICE_BUSY_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_close: "
		"Test 4: NDMP_DEVICE_BUSY_ERR start\n");
	inf_tape_close(NDMP_DEVICE_BUSY_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_close: "
		"Test 4: NDMP_DEVICE_BUSY_ERR end\n");

	/* Test 5: NDMP_NO_TAPE_LOADED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_close: "
		"Test 5: NDMP_NO_TAPE_LOADED_ERR start\n");
	inf_tape_close(NDMP_NO_TAPE_LOADED_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_close: "
		"Test 5: NDMP_NO_TAPE_LOADED_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

/*
 * NDMP_TAPE_GET_STATE
 */
int
unit_test_tape_get_state(host_info * auth, char *tape_dev, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_get_state: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_tape_get_state(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_get_state: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_get_state: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_tape_get_state(NDMP_NO_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_get_state: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_get_state: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR start\n");
	inf_tape_get_state(NDMP_DEV_NOT_OPEN_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_get_state: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

/*
 * NDMP_TAPE_MTIO
 */
int
unit_test_tape_mtio(host_info * auth, char *tape_dev, FILE * logfile)
{
	conn_handle conn;
	char *tape_mtio_op = "NDMP_MTIO_TUR";

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_mtio: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_tape_mtio(NDMP_NOT_AUTHORIZED_ERR,
		tape_mtio_op, tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_mtio: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_mtio: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_tape_mtio(NDMP_NO_ERR,
		tape_mtio_op, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_mtio: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_mtio: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR start\n");
	inf_tape_mtio(NDMP_DEV_NOT_OPEN_ERR,
		tape_mtio_op, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_mtio: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR end\n");

	/* Test 4: NDMP_ILLEGAL_ARGS_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_mtio: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR start\n");
	inf_tape_mtio(NDMP_ILLEGAL_ARGS_ERR,
		"illegalargs", tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_mtio: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR end\n");

	/* Test 5: NDMP_NO_TAPE_LOADED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_mtio: "
		"Test 5: NDMP_NO_TAPE_LOADED_ERR start\n");
	inf_tape_mtio(NDMP_NO_TAPE_LOADED_ERR,
		tape_mtio_op, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_mtio: "
		"Test 5: NDMP_NO_TAPE_LOADED_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

/*
 * NDMP_TAPE_WRITE
 */
int
unit_test_tape_write(host_info * auth, char *tape_dev, FILE * logfile)
{
	conn_handle conn;
	char *data_out = "unit_test_tape_write";

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_tape_write(NDMP_NOT_AUTHORIZED_ERR,
		data_out, tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_tape_write(NDMP_NO_ERR,
		data_out, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR start\n");
	inf_tape_write(NDMP_DEV_NOT_OPEN_ERR,
		data_out, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR end\n");

	/* Test 4: NDMP_PERMISSION_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 4: NDMP_PERMISSION_ERR start\n");
	inf_tape_write(NDMP_PERMISSION_ERR,
		data_out, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 4: NDMP_PERMISSION_ERR end\n");

	/* Test 5: NDMP_NO_TAPE_LOADED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 5: NDMP_NO_TAPE_LOADED_ERR start\n");
	inf_tape_write(NDMP_NO_TAPE_LOADED_ERR,
		data_out, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 5: NDMP_NO_TAPE_LOADED_ERR end\n");

	/* Test 6: NDMP_DEVICE_BUSY_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 6: NDMP_DEVICE_BUSY_ERR start\n");
	inf_tape_write(NDMP_DEVICE_BUSY_ERR,
		data_out, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_write: "
		"Test 6: NDMP_DEVICE_BUSY_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

/*
 * NDMP_TAPE_READ
 */
int
unit_test_tape_read(host_info * auth, char *tape_dev, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_read: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_tape_read(NDMP_NOT_AUTHORIZED_ERR,
		tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_read: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_read: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_tape_read(NDMP_NO_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_read: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_read: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR start\n");
	inf_tape_read(NDMP_DEV_NOT_OPEN_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_read: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR end\n");

	/* Test 4: NDMP_NO_TAPE_LOADED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_read: "
		"Test 4: NDMP_NO_TAPE_LOADED_ERR start\n");
	inf_tape_read(NDMP_NO_TAPE_LOADED_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_read: "
		"Test 4: NDMP_NO_TAPE_LOADED_ERR end\n");

	/* Test 5: NDMP_DEVICE_BUSY_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_read: "
		"Test 5: NDMP_DEVICE_BUSY_ERR start\n");
	inf_tape_read(NDMP_DEVICE_BUSY_ERR,
		tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_read: "
		"Test 5: NDMP_DEVICE_BUSY_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

/*
 * NDMP_TAPE_EXECUTE_CDB
 */
int
unit_test_tape_execute_cdb(host_info * auth, char *tape_dev, FILE * logfile)
{
	conn_handle conn;
	char *cdb = "INQUIRY";

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_execute_cdb: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_tape_execute_cdb(NDMP_NOT_AUTHORIZED_ERR,
		cdb, tape_dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_execute_cdb: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_execute_cdb: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_tape_execute_cdb(NDMP_NO_ERR,
		cdb, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_execute_cdb: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_execute_cdb: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR start\n");
	inf_tape_execute_cdb(NDMP_DEV_NOT_OPEN_ERR,
		cdb, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_execute_cdb: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR end\n");
	/* Test 4: NDMP_ILLEGAL_ARGS_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_execute_cdb: "
		"Test 4: NDMP_ILLEGAL_ARGS start\n");
	inf_tape_execute_cdb(NDMP_ILLEGAL_ARGS_ERR,
		cdb, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_execute_cdb: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR end\n");
	/* Test 5: NDMP_TIMEOUT_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_execute_cdb: "
		"Test 5: NDMP_TIMEOUT_ERR start\n");
	inf_tape_execute_cdb(NDMP_TIMEOUT_ERR,
		cdb, tape_dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_tape_execute_cdb: "
		"Test 5: NDMP_TIMEOUT_ERR end\n");

	close_connection(&conn, logfile);
	return (1);
}

#ifdef UNIT_TEST_TAPE

int
main(int argc, char *argv[])
{
	FILE *logfile = NULL;
	int ret;
	char *tape_dev = "/dev/rmt/2n";
	host_info auth;
	auth.ipAddr = strdup("10.12.178.122");
	auth.userName = strdup("admin");
	auth.password = strdup("admin");
	auth.auth_type = NDMP_AUTH_TEXT;

	/* Open Log file */
	logfile = fopen("unit_test_tape.log", "w+");
	(void) ndmp_dprintf(logfile, "main: start\n");

	/* unit test tape open */
	ndmp_dprintf(stdout, "File %s:%d\n", __FILE__, __LINE__);
	unit_test_tape_open(&auth, tape_dev, logfile);
	/* unit test tape close */
	unit_test_tape_close(&auth, tape_dev, logfile);
	/* unit test tape get state */
	unit_test_tape_get_state(&auth, tape_dev, logfile);

	/* unit test tape mtio */
	unit_test_tape_mtio(&auth, tape_dev, logfile);

	/* unit test tape write */
	unit_test_tape_write(&auth, tape_dev, logfile);

	/* unit test tape read */
	unit_test_tape_read(&auth, tape_dev, logfile);

	/* unit test tape execute cdb */
	unit_test_tape_execute_cdb(&auth, tape_dev, logfile);
	(void) ndmp_dprintf(stdout, "main: end\n");
	free(auth.ipAddr);
	free(auth.userName);
	free(auth.password);
	fclose(logfile);
	return (1);
}
#endif

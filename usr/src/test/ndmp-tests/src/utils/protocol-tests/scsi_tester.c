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
 * The SCSI Interface provides low-level control of SCSI devices. This files
 * implements all the scsi interfaces. There are four type of methods for
 * each interface. These methods types are extract request, extract reply,
 * print reply and compare reply.
 */

#include <stdio.h>
#include <string.h>

#include <ndmp.h>
#include <log.h>
#include <ndmp_conv.h>
#include <ndmp_lib.h>
#include <ndmp_comm_lib.h>
#include <ndmp_connect.h>

#include <scsi_tester.h>

/*
 * ndmp_scsi_open_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_scsi_open_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_scsi_open_reply *reply;
	if (ndmpMsg != NULL) {
		reply = ndmpMsg;
		(void) ndmp_lprintf(out, "ndmp_error %s \n",
				    ndmpErrorCodeToStr(reply->error));
	}
}

/*
 * ndmp_scsi_close_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_scsi_close_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_scsi_close_reply *reply;
	if (ndmpMsg != NULL) {
		reply = (ndmp_scsi_close_reply *) ndmpMsg;
		(void) ndmp_lprintf(out, "error %s \n",
				    ndmpErrorCodeToStr(reply->error));
	}
}

/*
 * ndmp_scsi_get_state_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_scsi_get_state_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_scsi_get_state_reply *reply;

	if (ndmpMsg != NULL) {
		reply = (ndmp_scsi_get_state_reply *) ndmpMsg;
		(void) ndmp_lprintf(out, "error %s \n",
			ndmpErrorCodeToStr(reply->error));
		(void) ndmp_lprintf(out, "target_controller %d \n",
			reply->target_controller);
		(void) ndmp_lprintf(out, "target_id %d \n", reply->target_id);
		(void) ndmp_lprintf(out, "target_lun %d \n", reply->target_lun);
	} else {
		(void) printf("ndmp_scsi_get_state_reply_print:"
			" reply is null\n");
	}
}

/*
 * ndmp_scsi_reset_device_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_scsi_reset_device_reply_print(FILE * out, void *ndmpMsg)
{
	ndmp_scsi_reset_device_reply *reply;

	if (ndmpMsg != NULL) {
		reply = (ndmp_scsi_reset_device_reply *) ndmpMsg;
		(void) ndmp_lprintf(out, "error %s \n",
			ndmpErrorCodeToStr(reply->error));
	}
}

/*
 * ndmp_scsi_execute_cdb_reply_print(): Prints the reply object.
 *
 * Arguments: FILE * - Handle to the log file. void *ndmpMsg - Reply object to
 * be printed in the log file.
 */
void
ndmp_scsi_execute_cdb_reply_print(FILE * out, void *ndmpMsg, int cdb)
{
	ndmp_scsi_execute_cdb_reply *reply;
	if (ndmpMsg != NULL) {
		reply = (ndmp_scsi_execute_cdb_reply *) ndmpMsg;
		(void) ndmp_lprintf(out, "error %s \n",
			ndmpErrorCodeToStr(reply->error));
		(void) ndmp_lprintf(out, "status %c \n", reply->status);
		(void) ndmp_lprintf(out, "dataout_len %d \n",
				    (int) reply->dataout_len);
		print_datain(out, reply, cdb);
		print_ext_sense(out, &(reply->ext_sense));
	}
}

/*
 * scsi_execute_cdb_core() : This message behaves in exactly the same way as
 * the NDMP_TAPE_EXECUTE_CDB request except that it sends the CDB to the scsi
 * device. This request SHOULD not be used to change the state of the scsi
 * device.
 */
int
scsi_execute_cdb_core(ndmp_error error,
	char *cdb, FILE * outfile, conn_handle * conn)
{
	void *reply_mem;
	/* Create and print the object start */
	ndmp_scsi_execute_cdb_request *request =
	(ndmp_scsi_execute_cdb_request *) malloc
	(sizeof (ndmp_scsi_execute_cdb_request));
	request->flags = 1;
	request->timeout = 0;
	request->datain_len = 36;
	request->cdb.cdb_len = CDB_SIZE;
	if (error == NDMP_ILLEGAL_ARGS_ERR)
		request->flags = (ushort_t) ~0;
	request->cdb.cdb_val = (char *) malloc(CDB_SIZE);
	(void) create_cdb((struct cdb *)(&(request->cdb)), getCdbNum(cdb));
	request->dataout.dataout_len = 0;
	request->dataout.dataout_val = 0;
	ndmp_lprintf(outfile, "REQUEST : NDMP_SCSI_EXECUTE_CDB\n");
	/* Create and print the object end */

	/* send the request start */
	if (!process_request((void *) request,
		NDMP_SCSI_EXECUTE_CDB, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_scsi_execute_cdb_reply *)
					reply_mem)->error) {
			ndmp_scsi_execute_cdb_reply_print(outfile,
				((ndmp_scsi_execute_cdb_reply *) reply_mem),
						getCdbNum(cdb));
			return (SUCCESS);
		}
	}
	return (ERROR);
}

/*
 * scsi_reset_device_core() Basic method to send scsi reset device request to
 * the ndmp server
 */
int
scsi_reset_device_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	/* Create and print the object end */
	ndmp_lprintf(outfile, "REQUEST : NDMP_SCSI_RESET_DEVICE\n");
	/* send the request start */
	if (!process_request(NULL,
		NDMP_SCSI_RESET_DEVICE, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
				error == ((ndmp_scsi_reset_device_reply *)
						reply_mem)->error) {
			ndmp_scsi_reset_device_reply_print(outfile,
				((ndmp_scsi_execute_cdb_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
	/* Compare and print the reply end */
}

/*
 * scsi_get_state_core() Basic method to send scsi get state request to the
 * ndmp server
 */
int
scsi_get_state_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem;
	/* Create and print the object end */
	ndmp_lprintf(outfile, "REQUEST : NDMP_SCSI_GET_STATE\n");
	/* send the request start */
	if (!process_request(NULL,
			NDMP_SCSI_GET_STATE, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
				error == ((ndmp_scsi_get_state_reply *)
						reply_mem)->error) {
			ndmp_scsi_get_state_reply_print(outfile,
				((ndmp_scsi_get_state_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	return (ERROR);
	/* Compare and print the reply end */
}

/*
 * tape_open_core() Basic method to send tape open request to the ndmp server
 */
int
scsi_open_core(ndmp_error error,
	char *device, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	ndmp_scsi_open_request *request = (ndmp_scsi_open_request *)
		malloc(sizeof (ndmp_scsi_open_request));
	/* Create and print the object start */
	request->device = strdup(device);
	/* Create and print the object end */
	ndmp_lprintf(outfile, "REQUEST : NDMP_SCSI_OPEN\n");
	/* Send the request start */
	if (!process_request((void *) request,
		NDMP_SCSI_OPEN, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL &&
			error == ((ndmp_scsi_open_reply *) reply_mem)->error) {
			ndmp_scsi_open_reply_print(outfile,
				((ndmp_scsi_open_reply *) reply_mem));
			return (SUCCESS);
		}
	}
	free(request->device);
	free(request);
	return (ERROR);
	/* Compare and print the reply end */
}

/*
 * scsi_close_core() Basic method to send scsi open request to the ndmp
 * server
 */
int
scsi_close_core(ndmp_error error, FILE * outfile, conn_handle * conn)
{
	void *reply_mem = NULL;
	/* Create and print the object start */
	ndmp_lprintf(outfile, "REQUEST : NDMP_SCSI_CLOSE\n");
	/* send the request start */
	if (!process_request(NULL,
		NDMP_SCSI_CLOSE, conn, &reply_mem, outfile)) {
		if (reply_mem != NULL && error != 0)
			ndmp_scsi_close_reply_print(outfile,
				((ndmp_scsi_close_reply *) reply_mem));
		return (SUCCESS);
	}
	return (ERROR);
}

/*
 * Intialize and Cleanup methods
 */

/*
 * scsi_close_intl() Do the initialization for the scsi close. Arguments :
 * device - scsi device to be opened.
 */
int
scsi_close_intl(ndmp_error error,
	char **device, conn_handle * conn, FILE * outfile)
{
	int ret = 0;
	if (error == NDMP_DEV_NOT_OPEN_ERR)
		return (ret);
	if (error == NDMP_NOT_AUTHORIZED_ERR) {
		scsi_open_core(NDMP_NO_ERR, *device, outfile, conn);
		return (ret);
	}
	ret = scsi_open_core(NDMP_NO_ERR, *device, outfile, conn);
	return (ret);
}

/*
 * scsi_open_intl() Do the initialization for the scsi open. Arguments :
 * device - scsi device to be opened.
 */
int
scsi_open_intl(ndmp_error error, char **device,
	conn_handle * conn, FILE * outfile)
{
	int ret = 0;
	if (error == NDMP_NOT_AUTHORIZED_ERR) {
		return (ret);
	}
	if (error == NDMP_NO_DEVICE_ERR)
		*device = strdup("no dev err");
	if (error == NDMP_DEVICE_OPENED_ERR)
		ret = scsi_open_core(NDMP_NO_ERR, *device, outfile, conn);
	return (ret);
}

/*
 * scsi_open_cleanup() Cleanup method for scsi open interface. Arguments :
 * error - ndmp Error device - Device to open. conn - Connection. outfile -
 * Log file.
 */
int
scsi_open_cleanup(ndmp_error error,
	char *device, conn_handle * conn, FILE * outfile)
{
	int ret = 0;

	if (error == NDMP_NO_DEVICE_ERR) {
		if (device != NULL)
			free(device);
		return (ret);
	}
	if (error == NDMP_NOT_AUTHORIZED_ERR)
		return (ret);
	/* this peice of code is for scsi get state */
	if (error == NDMP_DEV_NOT_OPEN_ERR)
		return (ret);
	ret = scsi_close_core(NDMP_NO_ERR, outfile, conn);

	return (ret);
}

/*
 * Interface level methods
 */

/*
 * inf_scsi_execute_cdb() : This message behaves in exactly the same way as
 * the NDMP_TAPE_EXECUTE_CDB request except that it sends the CDB to the scsi
 * device.
 */
int
inf_scsi_execute_cdb(ndmp_error error,
	char *cdb, char *dev, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_scsi_execute_cdb\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	/* Initialization */
	ret = scsi_close_intl(error, &dev, conn, outfile);
	print_intl_result(ret, outfile);

	/* Send the request */
	if (error == NDMP_ILLEGAL_ARGS_ERR)
		cdb = strdup("illegal");
	ret = scsi_execute_cdb_core(error, cdb, outfile, conn);
	if (error == NDMP_ILLEGAL_ARGS_ERR)
		free(cdb);
	print_test_result(ret, outfile);

	/* Clean up */
	ret = scsi_open_cleanup(error, dev, conn, outfile);
	print_cleanup_result(ret, outfile);
	return (ret);
}

/*
 * inf_scsi_reset_device() : The flow of the test case is decided by this
 * method.
 */
int
inf_scsi_reset_device(ndmp_error error,
	char *device, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_scsi_reset_device\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	/* Initialization */
	ret = scsi_close_intl(error, &device, conn, outfile);
	print_intl_result(ret, outfile);

	/* Send the request */
	ret = scsi_reset_device_core(error, outfile, conn);
	print_test_result(ret, outfile);

	/* Clean up */
	ret = scsi_open_cleanup(error, device, conn, outfile);
	print_cleanup_result(ret, outfile);

	return (ret);
}

/*
 * inf_scsi_get_state() : The flow of the test case is decided by this
 * method.
 */
int
inf_scsi_get_state(ndmp_error error,
	char *device, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_scsi_get_state\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	/* Initialization */
	ret = scsi_close_intl(error, &device, conn, outfile);
	print_intl_result(ret, outfile);

	/* Send the request */
	ret = scsi_get_state_core(error, outfile, conn);
	print_test_result(ret, outfile);

	/* Clean up */
	ret = scsi_open_cleanup(error, device, conn, outfile);
	print_cleanup_result(ret, outfile);

	return (ret);
}

/*
 * inf_scsi_open() : The flow of the test case is decided by this method.
 */
int
inf_scsi_open(ndmp_error error,
	char *device, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_scsi_open\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));

	/* Initialization */
	ret = scsi_open_intl(error, &device, conn, outfile);
	print_intl_result(ret, outfile);

	/* Send the request */
	ret = scsi_open_core(error, device, outfile, conn);
	print_test_result(ret, outfile);

	/* Clean up */
	ret = scsi_open_cleanup(error, device, conn, outfile);
	print_cleanup_result(ret, outfile);

	return (ret);
}

/*
 * inf_scsi_close() : The flow of the test case is decided by this method.
 */
int
inf_scsi_close(ndmp_error error,
	char *device, FILE * outfile, conn_handle * conn)
{
	int ret = 0;
	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_scsi_close\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	/* Initialization */
	ret = scsi_close_intl(error, &device, conn, outfile);
	print_intl_result(ret, outfile);

	/* Send the request */
	ret = scsi_close_core(error, outfile, conn);
	print_test_result(ret, outfile);
	return (ret);
}

/*
 * Unit test code
 */

/*
 * NDMP_SCSI_CLOSE
 */
int
unit_test_scsi_close(host_info * auth,
	char *device, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_close: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_scsi_close(NDMP_NOT_AUTHORIZED_ERR, device, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_close: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_close: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_scsi_close(NDMP_NO_ERR, device, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_close: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_close: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR start\n");
	inf_scsi_close(NDMP_DEV_NOT_OPEN_ERR, device, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_close: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR end\n");

	close_connection(&conn, logfile);
	return (1);
}

/*
 * NDMP_SCSI_RESET_DEVICE
 */
int
unit_test_scsi_reset_device(host_info * auth,
	char *device, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_reset_device: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_scsi_reset_device(NDMP_NOT_AUTHORIZED_ERR, device, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_reset_device: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_reset_device: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_scsi_reset_device(NDMP_NO_ERR, device, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_reset_device: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_reset_device: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR start\n");
	inf_scsi_reset_device(NDMP_DEV_NOT_OPEN_ERR, device, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_reset_device: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

/*
 * NDMP_SCSI_GET_STATE
 */
int
unit_test_scsi_get_state(struct host_info * auth,
	char *device, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_get_state: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_scsi_get_state(NDMP_NOT_AUTHORIZED_ERR, device, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_get_state: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_get_state: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_scsi_get_state(NDMP_NO_ERR, device, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_get_state: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_get_state: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR start\n");
	inf_scsi_get_state(NDMP_DEV_NOT_OPEN_ERR, device, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_get_state: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

/*
 * NDMP_SCSI_OPEN
 */
int
unit_test_scsi_open(host_info * auth, char *device, FILE * logfile)
{
	conn_handle conn;

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_open: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_scsi_open(NDMP_NOT_AUTHORIZED_ERR, device, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_open: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_open: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_scsi_open(NDMP_NO_ERR, device, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_open: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEVICE_OPENED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_open: "
		"Test 3: NDMP_DEVICE_OPENED_ERR start\n");
	inf_scsi_open(NDMP_DEVICE_OPENED_ERR, device, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_open: "
		"Test 3: NDMP_DEVICE_OPENED_ERR end\n");

	/* Test 4: NDMP_NO_DEVICE_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_open: "
		"Test 4: NDMP_NO_DEVICE_ERR start\n");
	inf_scsi_open(NDMP_NO_DEVICE_ERR, device, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_open: "
		"Test 4: NDMP_NO_DEVICE_ERR end\n");

	/* Test 5: NDMP_DEVICE_BUSY_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_open: "
		"Test 5: NDMP_DEVICE_BUSY_ERR start\n");
	inf_scsi_open(NDMP_DEVICE_BUSY_ERR, device, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_open: "
		"Test 5: NDMP_DEVICE_BUSY_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

/*
 * NDMP_SCSI_EXECUTE_CDB
 */
int
unit_test_scsi_execute_cdb(host_info * auth, char *dev, FILE * logfile)
{
	conn_handle conn;
	char *cdb = "INQUIRY";

	/* Test 1: NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_execute_cdb: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR start\n");
	strcpy(auth->password, "admn");
	(void) open_connection(auth, &conn, logfile);
	inf_scsi_execute_cdb(NDMP_NOT_AUTHORIZED_ERR, cdb, dev, logfile, &conn);
	close_connection(&conn, logfile);
	strcpy(auth->password, "admin");
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_execute_cdb: "
		"Test 1: NDMP_NOT_AUTHORIZED_ERR end\n");

	(void) open_connection(auth, &conn, logfile);

	/* Test 2: NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_execute_cdb: "
		"Test 2: NDMP_NO_ERR start\n");
	inf_scsi_execute_cdb(NDMP_NO_ERR, cdb, dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_execute_cdb: "
		"Test 2: NDMP_NO_ERR end\n");

	/* Test 3: NDMP_DEV_NOT_OPEN_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_execute_cdb: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR start\n");
	inf_scsi_execute_cdb(NDMP_DEV_NOT_OPEN_ERR, cdb, dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_execute_cdb: "
		"Test 3: NDMP_DEV_NOT_OPEN_ERR end\n");

	/* Test 4: NDMP_ILLEGAL_ARGS_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_execute_cdb: "
		"Test 4: NDMP_ILLEGAL_ARGS start\n");
	inf_scsi_execute_cdb(NDMP_ILLEGAL_ARGS_ERR, cdb, dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_execute_cdb: "
		"Test 4: NDMP_ILLEGAL_ARGS_ERR end\n");

	/* Test 5: NDMP_TIMEOUT_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_execute_cdb: "
		"Test 5: NDMP_TIMEOUT_ERR start\n");
	inf_scsi_execute_cdb(NDMP_TIMEOUT_ERR, cdb, dev, logfile, &conn);
	(void) ndmp_dprintf(logfile,
		"unit_test_scsi_execute_cdb: "
		"Test 5: NDMP_TIMEOUT_ERR end\n");

	close_connection(&conn, logfile);

	return (1);
}

#ifdef UNIT_TEST_SCSI

int
main(int argc, char *argv[])
{
	FILE *logfile = NULL;
	host_info auth;
	auth.ipAddr = strdup("10.12.178.122");
	auth.userName = strdup("admin");
	auth.password = strdup("admin");
	auth.auth_type = NDMP_AUTH_TEXT;
	char *device = "/dev/rmt/2n";

	/* Open Log file */
	logfile = fopen("unit_test_scsi.log", "w");
	(void) ndmp_dprintf(logfile, "main: start\n");

	/* unit test scsi open */
	unit_test_scsi_open(&auth, device, logfile);
	/* unit test scsi close */
	unit_test_scsi_close(&auth, device, logfile);

	/* unit test scsi get state */
	unit_test_scsi_get_state(&auth, device, logfile);

	/* unit test scsi reset device */
	unit_test_scsi_reset_device(&auth, device, logfile);

	/* unit test scsi execute cdb */
	unit_test_scsi_execute_cdb(&auth, device, logfile);

	(void) ndmp_dprintf(stdout, "main: end\n");
	free(auth.ipAddr);
	free(auth.userName);
	free(auth.password);
	fclose(logfile);
	return (1);
}
#endif

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
 * Notify Interface is used by the NDMP Server to indicate to the DMA that a
 * new state has been entered and/or some direct action is required. This
 * files implements all the notify interfaces.
 */
#include <string.h>
#include <ndmp.h>
#include <log.h>
#include <mover.h>
#include <data.h>
#include <ndmp_connect.h>
#include <ndmp_conv.h>
#include <ndmp_comm_lib.h>
#include <notify_tester.h>

int data_start_backup_intl(ndmp_error, char *, FILE *, conn_handle *);
int data_stop_cleanup(ndmp_error, FILE *, conn_handle *);
int mover_close_intl(ndmp_error, char *, char *, FILE *, conn_handle *);
int mover_abort_intl(ndmp_error, char *, FILE *, conn_handle *);
int create_host_info(host_info *, char **, FILE *);
int check_print_test_and_sub_case(char *, char *, FILE *);

/*
 * check_reason() Check the reason for the notification received.
 *
 * Arguments : msg - Ndmp message code. sub_msg - Reason. post - post object.
 *
 * Return : 0 - Success 1 - Error
 */
static int
check_post_reason(ndmp_message msg, int reason, void *post, FILE * outfile)
{
	switch (msg) {
		case NDMP_NOTIFY_DATA_HALTED:
		if (((ndmp_notify_data_halted_post *) post)->reason == reason)
			return (SUCCESS);
		else
			return (ERROR);
	case NDMP_NOTIFY_MOVER_HALTED:
		if (((ndmp_notify_mover_halted_post *) post)->reason == reason)
			return (SUCCESS);
		else
			return (ERROR);
	case NDMP_NOTIFY_MOVER_PAUSED:
		if (((ndmp_notify_mover_paused_post *) post)->reason == reason)
			return (SUCCESS);
		else
			return (ERROR);
	case NDMP_NOTIFY_CONNECTION_STATUS:
		if (((ndmp_notify_connection_status_post *) post)->
			reason == reason)
			return (SUCCESS);
		else
			return (ERROR);
	case NDMP_FH_ADD_NODE:
		return (SUCCESS);
	case NDMP_FH_ADD_DIR:
		return (SUCCESS);
	case NDMP_FH_ADD_FILE:
		return (SUCCESS);
	case NDMP_LOG_MESSAGE:
		if (((ndmp_log_message_post *) post)->log_type == reason)
			return (SUCCESS);
		else
			return (ERROR);
	case NDMP_LOG_FILE:
		if (((ndmp_log_file_post *) post)->recovery_status == reason)
			return (SUCCESS);
		else
			return (ERROR);
	default:
		ndmp_dprintf(outfile,
			"check_post_reason: Unknown post message\n");
	}
	return (ERROR);
}
/*
 * process_post(): Calls process_notification() to get the queue, checks the
 * queue for the required message. If the required message is received then
 * returns with success or else else loops till the stream is empty and no
 * more messages will be received. Deletes all the elements of the queue.
 *
 * Arguments : msg - Ndmp message to check for. sub_msg - Notification Reason,
 * -1 for any notification reason conn - connection handle. outfile - log
 * file.
 *
 * Return : 0 - Success 1 - Error
 */
int
process_post(ndmp_message msg, int sub_msg, FILE * outfile, conn_handle * conn)
{
	int ret = 1;
	int count = 0;
	notify_qrec *obj = NULL;
	notify_qrec *list = NULL;
	/* While loops for 5 times and returns if inteded notificaiton found */
	while (count < 5) {
		ret = process_notification(conn, msg, &list, outfile);
		if (ret == SUCCESS) {
			obj = search_element(list, msg, outfile);
			if (!check_post_reason(msg,
					sub_msg, obj->notify, outfile)) {
				delete_queue(&list, outfile);
				return (SUCCESS);
			} else {
				delete_queue(&list, outfile);
				return (ERROR);
			}
		} else {
			delete_queue(&list, outfile);
			count++;
			continue;
		}

	}
	return (ERROR);
}

/*
 * test_notify_data_mover_halted() Test the NDMP_NOTIFY_DATA_HALTED and
 * NDMP_NOTIFY_MOVER_HALTED related post messages. NDMP_NOTIFY_DATA_HALTED -
 * This message is used to notify the DMA that the NDMP Data Server has
 * halted. NDMP_NOTIFY_MOVER_HALTED - This message is used to notify the DMA
 * that the NDMP Tape Server has entered the halted state
 *
 * Arguments : test_case - Test case name. sub_case - Sub test case. tape_dev -
 * Tape device. abcBckDirPath - Path of the backup directory. outfile - log
 * file. conn - connection handle.
 *
 * Return : 0 - Success 1 - Failure
 */
int
test_notify_data_mover_halted(char *test_case, char *sub_case, char *tape_dev,
	char *abcBckDirPath, FILE * outfile, conn_handle * conn)
{
	int ret = 0, sub_msg = strToNdmpSubMessageCode(sub_case);
	ndmp_message msg = strToNdmpMessageCode(test_case);
	char *backup_type = "dump";
	if (check_print_test_and_sub_case(test_case,
				sub_case, outfile) == ERROR) {
		return (ERROR);
	}
	if (sub_msg == NDMP_MOVER_HALT_ABORTED) {
		ret = mover_abort_intl(NDMP_NO_ERR, tape_dev, outfile, conn);
		ret += mover_abort_core(NDMP_NO_ERR, outfile, conn);
	} else if (sub_msg == NDMP_MOVER_PAUSE_EOW) {
		mover_close_intl(NDMP_NOT_AUTHORIZED_ERR, tape_dev,
					abcBckDirPath, outfile, conn);
	} else {
		ret = data_start_backup_intl(NDMP_NO_ERR,
						tape_dev, outfile, conn);
		ret += data_start_backup_core(NDMP_NO_ERR,
				abcBckDirPath, backup_type, outfile, conn);
	}
	print_intl_result(ret, outfile);
	/* Now check and process for the post message */
	if (process_post(msg, sub_msg, outfile, conn)) {
		print_test_result(1, outfile);
	} else {
		print_test_result(0, outfile);
	}
	print_cleanup_result(data_start_backup_cleanup(NDMP_NO_ERR,
						outfile, conn), outfile);
	return (0);
}

/*
 * test_notify_connection() Test the NDMP_NOTIFY_CONNECTION_STATUS wtith
 * reasons 1.NDMP_CONNECTED, 2.NDMP_SHUTDOWN and NDMP_REFUSED. NDMP_REFUSED
 * is not implemented yet. This message is sent in response to a connection
 * establishment attempt. This message is always the first message sent on a
 * new connection. It is also used prior to NDMP Server shutdown to inform
 * the client that the server is shutting down. For reasons of backward
 * compatibility, it is guaranteed that the parameters of this message will
 * not change in any future release. The parameters MUST not change since
 * this message is sent prior to protocol version negotiation.
 *
 * Arguments : test_case - Test case name. sub_case - Sub test case. tape_dev -
 * Tape device. abcBckDirPath - Path of the backup directory. outfile - log
 * file. conn - connection handle.
 *
 * Return : 0 - Success 1 - Failure
 */
int
test_notify_connection(char *sub_case, host_info * host_details, FILE * outfile)
{
	int ret, sub_msg = strToNdmpSubMessageCode(sub_case);
	ndmp_message msg = NDMP_NOTIFY_CONNECTION_STATUS;
	conn_handle conn;
	ndmp_connect_open_reply *reply = NULL;

	if (sub_case == NULL) {
		(void) ndmp_fprintf(outfile, "Test case name : NULL\n");
		print_test_result(1, outfile);
		return (1);
	} else {
		(void) ndmp_fprintf(outfile,
			"Test case name : "
			"NDMP_NOTIFY_CONNECTION_STATUS - %s\n", sub_case);
		client_connect_open(host_details, &conn, &reply, outfile);
		ret = process_post(msg, sub_msg, outfile, &conn);
	}
	if (sub_msg == NDMP_SHUTDOWN) {
		ret = close_connection(&conn, outfile);
	}
	if ((sub_msg != NDMP_CONNECTED) && (sub_msg != NDMP_SHUTDOWN)) {
		(void) ndmp_fprintf(outfile, "Wrong sub_case argument\n");
		print_test_result(1, outfile);
		return (1);
	}
	print_test_result(ret, outfile);

	if (sub_msg == NDMP_CONNECTED) {
		close_connection(&conn, outfile);
	}
	return (0);
}

int
unit_test_notify(host_info * auth,
		char *tape, char *absBckDirpath, FILE * logfile)
{
	conn_handle conn;
	char test_case[50];
	char sub_case[50];

	/* Test 1: NDMP_NOTIFY_DATA_HALTED-NDMP_DATA_HALT_SUCCESSFUL */
	(void) ndmp_dprintf(logfile, "unit_test_notify: Test 1"
		" NDMP_NOTIFY_DATA_HALTED - NDMP_DATA_HALT_SUCCESSFUL start\n");
	(void) open_connection(auth, &conn, logfile);
	strcpy(test_case, "NDMP_NOTIFY_DATA_HALTED");
	strcpy(sub_case, "NDMP_DATA_HALT_SUCCESSFUL");
	(void) test_notify_data_mover_halted(test_case, sub_case,
				tape, absBckDirpath, logfile, &conn);
	close_connection(&conn, logfile);

	/* Test 2: NDMP_NOTIFY_MOVER_HALTED-NDMP_MOVER_HALT_CONNECTION_CLOSED */
	(void) ndmp_dprintf(logfile, "unit_test_notify: Test 2 "
		" NDMP_NOTIFY_MOVER_HALTED - "
		"NDMP_MOVER_HALT_CONNECTION_CLOSED start\n");
	(void) open_connection(auth, &conn, logfile);
	strcpy(test_case, "NDMP_NOTIFY_MOVER_HALTED");
	strcpy(sub_case, "NDMP_MOVER_HALT_CONNECTION_CLOSED");
	(void) test_notify_data_mover_halted(test_case,
			sub_case, tape, absBckDirpath, logfile, &conn);
	close_connection(&conn, logfile);

	/* Test 3: NDMP_NOTIFY_MOVER_HALTED-NDMP_MOVER_HALT_ABORTED */
	(void) ndmp_dprintf(logfile, "unit_test_notify: Test 3 "
		"NDMP_NOTIFY_MOVER_HALTED - "
		"NDMP_MOVER_HALT_ABORTED start\n");
	(void) open_connection(auth, &conn, logfile);
	strcpy(test_case, "NDMP_NOTIFY_MOVER_HALTED");
	strcpy(sub_case, "NDMP_MOVER_HALT_ABORTED");
	(void) test_notify_data_mover_halted(test_case,
			sub_case, tape, absBckDirpath, logfile, &conn);
	close_connection(&conn, logfile);

	/* Test 4: NDMP_NOTIFY_MOVER_PAUSED-NDMP_MOVER_PAUSE_EOW */
	(void) ndmp_dprintf(logfile, "unit_test_notify: Test 4 "
		"NDMP_NOTIFY_MOVER_PAUSED - "
		"NDMP_MOVER_PAUSE_EOW start\n");
	(void) open_connection(auth, &conn, logfile);
	strcpy(test_case, "NDMP_NOTIFY_MOVER_PAUSED");
	strcpy(sub_case, "NDMP_MOVER_PAUSE_EOW");
	(void) test_notify_data_mover_halted(test_case,
			sub_case, tape, absBckDirpath, logfile, &conn);
	close_connection(&conn, logfile);

	/* Test 4: NDMP_NOTIFY_CONNECTION_STATUS-NDMP_CONNECTED */
	(void) ndmp_dprintf(logfile, "unit_test_notify: Test 4 "
		"NDMP_NOTIFY_CONNECTION_STATUS - "
		"NDMP_CONNECTED start\n");
	strcpy(sub_case, "NDMP_CONNECTED");
	auth->protocol_version = 4;
	(void) test_notify_connection(sub_case, auth, logfile);

	return (1);
}

#ifdef UNIT_TEST_NOTIFY
int
main(int argc, char *argv[])
{
	FILE *logfile = NULL;
	char *tape_dev = "/dev/rmt/2n";
	char *absBckDirPath = "/etc/cron.d/";
	host_info auth;
	auth.ipAddr = strdup("10.12.178.122");
	auth.userName = strdup("admin");
	auth.password = strdup("admin");
	auth.auth_type = NDMP_AUTH_TEXT;

	/* Open Log file */
	logfile = fopen("unit_test_notify.log", "w");
	(void) ndmp_dprintf(logfile, "main: start\n");
	(void) ndmp_dprintf(stdout, "%s, %d \n", __FILE__, __LINE__);

	/*
	 * unit test notify
	 */
	unit_test_notify(&auth, tape_dev, absBckDirPath, logfile);

	(void) ndmp_dprintf(stdout, "main: end\n");
	free(auth.ipAddr);
	free(auth.userName);
	free(auth.password);
	fclose(logfile);
	return (1);
}
#endif

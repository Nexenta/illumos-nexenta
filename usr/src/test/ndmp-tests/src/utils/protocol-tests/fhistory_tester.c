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
 * The NDMP Server uses File History Interface to send file history entries
 * to the DMA. This files implements all the file history interfaces.
 */

#include <strings.h>
#include <ndmp.h>
#include <data.h>
#include <log.h>
#include <ndmp_connect.h>
#include <notify_tester.h>

int process_post(ndmp_message, int, FILE *, conn_handle *);
int check_print_test_and_sub_case(char *, char *, FILE *);
/*
 * get_fh_message_code(): Converts ndmp message string to ndmp message code.
 *
 * Arguments : char * - ndmp message string to be converted.
 *
 * Returns : ndmp_message - ndmp_message code.
 */
ndmp_message
get_fh_log_message_code(char *strNdmp)
{
	if (!(strcmp(strNdmp, "NDMP_FH_ADD_DIR")))
		return (NDMP_FH_ADD_DIR);
	if (!(strcmp(strNdmp, "NDMP_LOG_MESSAGE")))
		return (NDMP_LOG_MESSAGE);
	if (!(strcmp(strNdmp, "NDMP_LOG_ERROR")))
		return ((ndmp_message) NDMP_LOG_NORMAL);
	if (!(strcmp(strNdmp, "NDMP_FH_ADD_FILE")))
		return (NDMP_FH_ADD_DIR);
	if (!(strcmp(strNdmp, "NDMP_FH_ADD_NODE")))
		return (NDMP_FH_ADD_NODE);
	if (!(strcmp(strNdmp, "NDMP_LOG_NORMAL")))
		return ((ndmp_message) NDMP_LOG_NORMAL);
	if (!(strcmp(strNdmp, "NDMP_LOG_DEBUG")))
		return ((ndmp_message) NDMP_LOG_DEBUG);
	else
		return (ERROR);
}

/*
 * test_fh_add() : Test NDMP_FH_ADD_NODE, NDMP_FH_ADD_DIR and
 * NDMP_FH_ADD_FILE post messages.
 *
 * Arguments : test_case - Test case name. abcBckDirPath - Backup directory
 * path.
 *
 * Returns : SUCCESS - Sucess. Error - Failure.
 */
int
test_fh_add_log_msg(char *test_case, char *sub_case,
	char *tape_dev, char *abcBckDirPath, FILE * outfile, conn_handle * conn)
{
	int ret, sub_msg;
	char *backup_type = NULL;
	ndmp_message msg;

	ret = ERROR;
	if (sub_case != NULL) {
		sub_msg = get_fh_log_message_code(sub_case);
	} else {
		sub_msg = ERROR;
	}

	msg = get_fh_log_message_code(test_case);
	backup_type = "dump";

	if (check_print_test_and_sub_case(test_case,
				sub_case, outfile) == ERROR) {
		return (ERROR);
	}
	if (msg == NDMP_FH_ADD_NODE || msg == NDMP_FH_ADD_DIR ||
		msg == NDMP_FH_ADD_FILE || msg == NDMP_LOG_MESSAGE) {
		ret = data_start_backup_intl(NDMP_NO_ERR,
					tape_dev, outfile, conn);
		ret += data_start_backup_core(NDMP_NO_ERR,
				abcBckDirPath, backup_type, outfile, conn);
	} else {
		(void) ndmp_fprintf(outfile, "Illegal test case name\n");
	}
	print_intl_result(ret, outfile);
	/* Now check and process for the post message */
	if (process_post(msg, sub_msg, outfile, conn)) {
		print_test_result(ERROR, outfile);
	} else {
		print_test_result(SUCCESS, outfile);
	}
	print_cleanup_result(data_start_backup_cleanup(NDMP_NO_ERR,
						outfile, conn), outfile);
	return (SUCCESS);
}

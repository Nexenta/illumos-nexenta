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
 * Log Interface is used by the NDMP Server to send informational and
 * diagnostic data to the DMA. This files implements all the log interfaces.
 */

#include <strings.h>
#include <ndmp.h>
#include <ndmp_connect.h>
#include <ndmp_conv.h>
#include <data.h>
#include <notify_tester.h>

int check_print_test_and_sub_case(char *, char *, FILE *);

/*
 * test_log_file() : Test NDMP_RECOVERY_SUCCESSFUL,
 * NDMP_RECOVERY_FAILED_PERMISSION, NDMP_RECOVERY_FAILED_NOT_FOUND and
 * NDMP_RECOVERY_FAILED_NO_DIRECTORY post messages. This post sends a file
 * recovered message to the DMA. It is used during recovery to notify the DMA
 * that a file/directory specified in the recovery list sent in the
 * NDMP_DATA_START_RECOVER request has or has not been recovered.
 *
 * Arguments : test_case - Test case name. abcBckDirPath - Backup directory
 * path.
 *
 * Returns : SUCCESS - Sucess. Error - Failure.
 */
int
test_log_file(char *test_case, char *sub_case, char *tape_dev,
	char *abcBckDirPath, FILE * outfile, conn_handle * conn)
{
	char *backup_type;
	int ret = 0, sub_msg = strToNdmpSubMessageCode(sub_case);
	ndmp_message msg = strToNdmpMessageCode(test_case);
	FILE *dev_null = fopen("/dev/null", "w");
	char backup_dir[50];
	memset(backup_dir, '\0', 50);

	backup_type = "dump";
	if (check_print_test_and_sub_case(test_case,
			sub_case, outfile) == ERROR) {
		return (ERROR);
	}
	ret = inf_data_start_backup(NDMP_NO_ERR,
		tape_dev, abcBckDirPath, backup_type, dev_null, conn);
	if (sub_msg == NDMP_RECOVERY_FAILED_NOT_FOUND) {
		ret += data_start_recover_intl(NDMP_NOT_AUTHORIZED_ERR,
						tape_dev, outfile, conn);
	} else {
		ret += data_start_recover_intl(NDMP_NO_ERR,
						tape_dev, outfile, conn);
	}
	if (sub_msg == NDMP_RECOVERY_FAILED_NO_DIRECTORY) {
		strcpy(backup_dir, abcBckDirPath);
		abcBckDirPath = (char *)strcat(backup_dir, "/xzy");
	}
	if (sub_msg == NDMP_RECOVERY_FAILED_PERMISSION)
		abcBckDirPath = (void *)strcpy(backup_dir, "/home");
	ret += data_start_recover_core(NDMP_NO_ERR, NDMP_DATA_START_RECOVER,
				abcBckDirPath, backup_type, outfile, conn);
	print_intl_result(ret, outfile);
	if (ret == ERROR)
		return (ERROR);
	print_test_result(process_post(msg, sub_msg, outfile, conn), outfile);
	print_cleanup_result(data_start_recover_cleanup(NDMP_NO_ERR,
						outfile, conn), outfile);
	fclose(dev_null);
	/* Now check and process for the post message */
	return (SUCCESS);
}

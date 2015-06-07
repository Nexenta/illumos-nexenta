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
 * The sequence of operations to be executed for running a particular test
 * case, is decided here. This files also methods to parse the command line
 * input.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <ctype.h>
#include <pwd.h>
#include <time.h>
#include <unistd.h>
#include <ndmp.h>
#include <process_hdlr_table.h>
#include <log.h>
#include <mover.h>
#include <data.h>
#include <tape_tester.h>
#include <connect_tester.h>
#include <config_tester.h>
#include <notify_tester.h>
#include <scsi_tester.h>
#include <ndmp_connect.h>
#include <ndmp_conv.h>

int test_notify_data_mover_halted(char *, char *,
	char *, char *, FILE *, conn_handle *);
int create_host_info(host_info *, char **, FILE *);
int test_fh_add_log_msg(char *, char *, char *, char *, FILE *, conn_handle *);
int test_log_file(char *, char *, char *, char *, FILE *, conn_handle *);
int usage_check(int, FILE *);
void execute(int, char **);

/*
 * main() : The execution of the program starts from the main function In
 * this function we first parse and call the execute method.
 *
 * Returns:int, 0 on success, 1 on failure
 */
#ifdef NDMP_PROTOCOL_TEST
int
main(int argc, char *argv[])
{
	/* Check the usage */
	if (usage_check(argc, stdout)) {
		return (ERROR);
	}
	execute(argc, argv);
	return (SUCCESS);
}
#endif

/*
 * Code for version 2
 */

static void
mover_switcher(char **list, FILE * logfile, conn_handle * conn)
{
	ndmp_dprintf(logfile, "mover_switcher: \n");
	if (!(strncmp(list[INTERFACE], "mover_set_record_size", 19))) {
		inf_mover_set_rec_size(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[RECORDSIZE], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "mover_set_window_size", 19))) {
		inf_mover_set_window_size(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[WINDOWSIZE], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "mover_connect", 10))) {
		inf_mover_connect(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[MOVER_MODE],
			&(list[ADDR_TYPE]), logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "mover_listen", 10))) {
		inf_mover_listen(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[MOVER_MODE],
			list[ADDR_TYPE], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "mover_read", 10))) {
		inf_mover_read(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "mover_get_state", 13))) {
		inf_mover_get_state(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "mover_continue", 11))) {
		inf_mover_continue(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[FILE_SYS], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "mover_close", 10))) {
		inf_mover_close(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[FILE_SYS], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "mover_abort", 12))) {
		inf_mover_abort(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "mover_stop", 12))) {
		inf_mover_stop(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], logfile, conn);
	} else {
		(void) fprintf(logfile, "mover_switcher: Illegal interface\n");
	}
}

/*
 * tape_switcher() Based on the interface passed on the command line this
 * methods switches to a handler. This function then takes care of running
 * the interface. Arguments : list - An Array of command line arguments.
 * logfile - Log file conn - Connection handle.
 */
static void
tape_switcher(char **list, FILE * logfile, conn_handle * conn)
{
	ndmp_dprintf(logfile, "tape_switcher: \n");
	if (!(strncmp(list[INTERFACE], "tape_open", 9))) {
		inf_tape_open(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[TAPEMODE], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "tape_close", 10))) {
		inf_tape_close(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "tape_get_state", 13))) {
		inf_tape_get_state(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "tape_mtio", 8))) {
		inf_tape_mtio(strToNdmpErrorCode(list[ERROR_MSG]),
		list[MTIO_OP], list[TAPEDEV], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "tape_write", 9))) {
		inf_tape_write(strToNdmpErrorCode(list[ERROR_MSG]),
		list[WRITE_DATA], list[TAPEDEV], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "tape_read", 8))) {
		inf_tape_read(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "tape_execute_cdb", 8))) {
		inf_tape_execute_cdb(strToNdmpErrorCode(list[ERROR_MSG]),
		list[CDB], list[TAPEDEV], logfile, conn);
	} else {
		(void) fprintf(logfile, "tape_switcher: Illegal interface\n");
	}
}

/*
 * scsi_switcher() Calls appropriate method based on the argument passed on
 * the command line. Arguments : list - list to store all the values.
 */
static void
scsi_switcher(char **list, FILE * logfile, conn_handle * conn)
{
	(void) ndmp_dprintf(logfile, "scsi_switcher: \n");
	if (!(strncmp(list[INTERFACE], "scsi_open", 9))) {
		inf_scsi_open(strToNdmpErrorCode(list[ERROR_MSG]),
		list[DEVICE], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "scsi_close", 10))) {
		inf_scsi_close(strToNdmpErrorCode(list[ERROR_MSG]),
		list[DEVICE], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "scsi_get_state", 13))) {
		inf_scsi_get_state(strToNdmpErrorCode(list[ERROR_MSG]),
		list[DEVICE], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "scsi_reset_device", 15))) {
		inf_scsi_reset_device(strToNdmpErrorCode(list[ERROR_MSG]),
		list[DEVICE], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "scsi_execute_cdb", 8))) {
		inf_scsi_execute_cdb(strToNdmpErrorCode(list[ERROR_MSG]),
		list[CDB], list[DEVICE], logfile, conn);
	} else {
		(void) ndmp_dprintf(logfile,
			"scsi_switcher: Illegal interface\n");
	}
}

/*
 * config_switcher() Interface level switch method for Configuration module.
 * Based on the appropriate interface, the inf_xxx() method is called.
 *
 * Arguments : list - list with arguments
 */
static void
config_switcher(char **list, FILE * logfile, conn_handle * conn)
{
	(void) ndmp_dprintf(logfile, "config_switcher: \n");
	(void) inf_config(strToNdmpErrorCode(list[ERROR_MSG]),
		list[INTERFACE], logfile, conn);
}

/*
 * connect_switcher() Interface level switch method for connect module. Based
 * on the appropriate interface, the inf_xxx() method is called.
 *
 * Arguments : list - list with arguments
 */
static void
connect_switcher(char **list, FILE * logfile)
{
	host_info host;
	print_intl_result(create_host_info(&host, list, logfile), logfile);

	if (!(strncmp(list[INTERFACE], "NDMP_CONNECT_OPEN", 16))) {
		(void) inf_connect_open(strToNdmpErrorCode(list[ERROR_MSG]),
			&host, logfile);
	} else if (!(strncmp(list[INTERFACE], "NDMP_CONNECT_CLOSE", 16))) {
		(void) inf_connect_close(&host, logfile);
	} else if (!(strncmp(list[INTERFACE],
				"NDMP_CONNECT_CLIENT_AUTH", 16))) {
	(void) inf_connect_client_auth(strToNdmpErrorCode(list[ERROR_MSG]),
			&host, logfile);
	} else if (!(strncmp(list[INTERFACE],
				"NDMP_CONNECT_SERVER_AUTH", 16))) {
	(void) inf_connect_server_auth(strToNdmpErrorCode(list[ERROR_MSG]),
			&host, logfile);
	} else {
		(void) ndmp_fprintf(logfile,
			"connect_switcher: Illegal interface\n");
	}
}

/*
 * post_switcher() Interface level switch method for post module. Based on
 * the appropriate interface, the inf_xxx() method is called.
 *
 * Arguments : list - list with arguments
 */
static void
post_switcher(char **list, FILE * logfile, conn_handle * conn)
{
	if (!(strncmp(list[INTERFACE], "NDMP_NOTIFY_DATA_HALTED", 16))) {
		test_notify_data_mover_halted(list[INTERFACE], list[SUBMSG],
			list[TAPEDEV], list[FILE_SYS], logfile, conn);
	} else if (!(strncmp(list[INTERFACE],
				"NDMP_NOTIFY_MOVER", 16))) {
		test_notify_data_mover_halted(list[INTERFACE], list[SUBMSG],
			list[TAPEDEV], list[FILE_SYS], logfile, conn);
	} else if (!(strncmp(list[INTERFACE],
				"NDMP_NOTIFY_CONNECTION_STATUS", 25))) {
		host_info host;
		if (!print_intl_result(create_host_info(&host,
						list, logfile), logfile)) {
			test_notify_connection(list[SUBMSG], &host, logfile);
		}
	} else if (!(strncmp(list[INTERFACE], "NDMP_FH_ADD", 10))) {
		test_fh_add_log_msg(list[INTERFACE], list[SUBMSG],
			list[TAPEDEV], list[FILE_SYS], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "NDMP_LOG_MESSAGE", 10))) {
		test_fh_add_log_msg(list[INTERFACE], list[SUBMSG],
			list[TAPEDEV], list[FILE_SYS], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "NDMP_LOG_FILE", 10))) {
		test_log_file(list[INTERFACE], list[SUBMSG],
			list[TAPEDEV], list[FILE_SYS], logfile, conn);
	} else {
		(void) ndmp_fprintf(logfile,
			"post_switcher: Illegal interface\n");
	}
}

/*
 * data_switcher() Interface level switch method for data module. Based on
 * the appropriate interface, the inf_xxx() method is called.
 *
 * Arguments : list - list with arguments
 */
static void
data_switcher(char *list[], FILE * logfile, conn_handle * conn)
{
	ndmp_dprintf(logfile, "data_switcher(): conn 0x%x\n", conn);
	if (!(strncmp(list[INTERFACE], "data_connect", 11))) {
		inf_data_connect(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[MOVER_MODE], list[ADDR_TYPE],
							logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "data_listen", 10))) {
		inf_data_listen(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[ADDR_TYPE], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "data_start_backup", 15))) {
		inf_data_start_backup(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[FILE_SYS], list[BACKUP_TYPE],
							logfile, conn);
	} else if (!(strncmp(list[INTERFACE],
			"data_start_recover_filehist", 25))) {
		inf_data_start_recover_filehist(strToNdmpErrorCode(
			list[ERROR_MSG]), list[TAPEDEV], list[FILE_SYS],
			list[BACKUP_TYPE], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "data_start_recover", 15))) {
		inf_data_start_recover(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[FILE_SYS], list[BACKUP_TYPE],
							logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "data_get_state", 13))) {
		inf_data_get_state(strToNdmpErrorCode(list[ERROR_MSG]),
		logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "data_get_env", 11))) {
		inf_data_get_env(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[FILE_SYS], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "data_stop", 8))) {
		inf_data_stop(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], logfile, conn);
	} else if (!(strncmp(list[INTERFACE], "data_abort", 9))) {
		inf_data_abort(strToNdmpErrorCode(list[ERROR_MSG]),
		list[TAPEDEV], list[FILE_SYS], logfile, conn);
	} else {
		(void) fprintf(logfile, "data_switcher: Illegal interface\n");
	}
}

/*
 * module_switcher() Module level switch method. Based on the appropriate
 * interface, the xxxx_switcher() method is called.
 *
 * Arguments : list - list with arguments
 */
static void
module_switcher(char *list[], FILE * logfile, conn_handle * conn)
{
	ndmp_dprintf(logfile, "module_switcher: %s\n", list[INTERFACE]);
	if (!(strncmp(list[INTERFACE], "data", 4)))
		data_switcher(list, logfile, conn);
	else if (!(strncmp(list[INTERFACE], "move", 4)))
		mover_switcher(list, logfile, conn);
	else if (!(strncmp(list[INTERFACE], "tape", 4)))
		tape_switcher(list, logfile, conn);
	else if (!(strncmp(list[INTERFACE], "scsi", 4)))
		scsi_switcher(list, logfile, conn);
	else if (!(strncmp(list[INTERFACE], "NDMP_CONFIG", 11)))
		config_switcher(list, logfile, conn);
	else if (!(strncmp(list[INTERFACE], "NDMP_CONNECT", 11)))
		connect_switcher(list, logfile);
	else
		post_switcher(list, logfile, conn);
}

static void
parse_args(int argc, char **argv, char **list, FILE * logfile)
{
	int count = 0;
	logfile = stdout;
	ndmp_dprintf(logfile, "parse_args: start\n");

	for (count = 1; count < argc; count++) {
		if (!(strcmp(argv[count], "-fs")))
			list[FILE_SYS] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-inf")))
			list[INTERFACE] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-err")))
			list[ERROR_MSG] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-log"))) {
			ndmp_dprintf(stdout,
			"argv[%d] %s\n", count, argv[count + 1]);
			list[LOG_FILE] = strdup(argv[count + 1]);
		} else if (!(strcmp(argv[count], "-tape")))
			list[TAPEDEV] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-robot")))
			list[ROBOT] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-src")))
			list[SRC_MC] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-dest")))
			list[DEST_MC] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-src_user")))
			list[SRCUSER] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-src_pass")))
			list[SRCPSWD] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-dest_user")))
			list[DESTUSR] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-dest_pass")))
			list[DESTPSWD] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-config")))
			list[CONFFILE] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-rec_size")))
			list[RECORDSIZE] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-win_size")))
			list[WINDOWSIZE] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-restore")))
			list[RESTOREPATH] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-tape_mode")))
			list[TAPEMODE] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-log_level")))
			log_level = atoi(strdup(argv[count + 1]));
		else if (!(strcmp(argv[count], "-mover_mode")))
			list[MOVER_MODE] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-addr_type")))
			list[ADDR_TYPE] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-scsi_dev")))
			list[DEVICE] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-cdb")))
			list[CDB] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-mtio_op")))
			list[MTIO_OP] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-auth_type")))
			list[NDMPAUTH] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-ndmp_ver")))
			list[NDMPVERSION] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-auth_digest")))
			list[AUTHDIGEST] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-challenge")))
			list[CHALLENGE] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-sub_msg")))
			list[SUBMSG] = strdup(argv[count + 1]);
		else if (!(strcmp(argv[count], "-backup_type")))
			list[BACKUP_TYPE] = strdup(argv[count + 1]);
		else
			continue;
	}
	ndmp_dprintf(logfile, "parse_args: end\n");
}

/*
 * usage_check() : Checks the commandline usage. If the usage is not correct
 * guide on how the usage should be.
 */
int
usage_check(int argc, FILE * logfile)
{
	ndmp_dprintf(logfile, "usage_check: start\n");
	if (argc < 6) {
		(void) fprintf(stdout, "Incorrect usage\n"
			"Correct Usage is :\n"
			"\t./ndmp_proto_test\n\t\t-fs <file system>\n"
			"\t\t-inf <Interface to test>\n\t\t-err "
			"<Error Message>\n"
			"\t\t-sub_msg <Used for Post message testing>\n"
			"\t\t-addr_type "
			"<address type for backup. e.g. NDMP_ADDR_LOCAL>\n"
			"\t\t-log <Log File>\n"
			"\t\t-log_level <Log level e.g 0, 1 or 2>"
			"\n\t\t-src <Source IP>\n\t\t-dest <Destination IP>"
			"\n\t\t-src_user <User>\n\t\t-src_pass <Password>"
			"\n\t\t-dest_user "
			"<User>\n\t\t-dest_pass <Password>"
			"\n\t\t-tape <Tape Device>"
			"\n\t\t-robot <Changer>"
			"\n\t\t-tape_op <Tape Operation e.g NDMP_MTIO_FSF>"
			"\n\t\t-backup_type <Optional. e.g TAR. "
			"Default is DUMP>"
			"\n\t\t-rec_size <Mover record size>"
			"\n\t\t-win_size <Mover window size>"
			"\n\t\t-conn_type <Optional. e.g TCP. Default is LOCAL>"
			"\n\t\t-tape <Tape Device>"
			"\n\t\t-scsi_dev <e.g /dev/rmt/0n>"
			"\n\t\t-cdb <CDB in Upper Casee.g INQUIRY>"
			"\n\t\t-ndmp_ver <NDMP Protocol version e.g 4>"
			"\n\t\t-auth_digest <For MD5>"
			"\n\t\t-auth_type <Authentication type e.g "
			"NDMP_AUTH_TEXT>"
			"\n\t\t-challenge <challenge string, For "
			"Server auth>\n");
		return (ERROR);
	}
	return (SUCCESS);
}

/*
 * execute() The execution of the program starts from here.
 */
void
execute(int argc, char **argv)
{
	conn_handle conn;
	host_info host;
	char *cli_arg_list[MAX_ARGS];
	FILE *logfile = NULL;
	/*
	 * Create a list which has all the required arguments in correct
	 * order. The order is config file, interface, error, logfile name,
	 * tape device and robot.
	 */
	int i;
	for (i = 0; i < argc; i++) {
		if (argv[i] != NULL) {
			ndmp_dprintf(stdout,
				"argv[%d] %s, &argv[%d] 0x%x\n",
					i, argv[i], i, &argv[i]);
		}
	}
	logfile = stdout;
	for (i = 0; i < MAX_ARGS; i++) {
		cli_arg_list[i] = NULL;
	}
	parse_args(argc, argv, cli_arg_list, logfile);
	ndmp_dprintf(logfile, "V: %s", argv[3]);
	logfile = fopen(cli_arg_list[LOG_FILE], "a+");
	if (logfile == NULL) {
		ndmp_dprintf(logfile, "Could not open log file\n");
		exit(1);
	}
	host.auth_type = NDMP_AUTH_TEXT;
	host.ipAddr = cli_arg_list[SRC_MC];
	host.password = cli_arg_list[SRCPSWD];
	host.userName = cli_arg_list[SRCUSER];
	host.protocol_version = 4;
	if ((strncmp(cli_arg_list[INTERFACE], "NDMP_CONNECT", 12))) {
		if (open_connection(&host, &conn, logfile)) {
			ndmp_fprintf(logfile, "Connection not established\n");
			exit(0);
		}
	}
	module_switcher(cli_arg_list, logfile, &conn);
	if ((strncmp(cli_arg_list[INTERFACE], "NDMP_CONNECT", 12)) ||
	    ((strncmp(cli_arg_list[INTERFACE],
			"NDMP_NOTIFY_CONNECTION_STATUS", 20)))) {
		close_connection(&conn, logfile);
	}
	(void) fclose(logfile);
}

/*
 * End of file	: ndmp_proto_test.c
 */

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
 * The common library functions related to data, mover can be found here.
 * Some of the methods are also used by scsi and tape interface.
 */

#include<stdio.h>
#include<strings.h>
#include<stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <ndmp.h>
#include <log.h>
#include <ndmp_comm_lib.h>
#include <ndmp_connect.h>

/*
 * print_ndmp_u_quad() : Prints the ndmp_u_quad structure.
 */
void
print_ndmp_u_quad(FILE * outstream, ndmp_u_quad quad_t)
{
	(void) fprintf(outstream, "high: %ld; low: %ld\n",
		quad_t.high, quad_t.low);
}

/*
 * print_ndmp_pval() : Prints ndmp_pval structure.
 */
void
print_ndmp_pval(FILE * outstream, ndmp_pval * pval)
{
	if (pval != 0 && pval->name != 0)
		(void) fprintf(outstream, "name: %s\n", pval->name);
	if (pval != 0 && pval->value != 0)
		(void) fprintf(outstream, "value: %s\n", pval->value);
}

/*
 * print_ndmp_tcp_addr() : Print ndmp_tcp_addr structure.
 */
void
print_ndmp_tcp_addr(FILE * outstream, ndmp_tcp_addr * tcp_addr)
{
	int i;
	char str[100];
	(void) (void) memset(str, '\0', strlen(str));
	(void) fprintf(outstream, "ip_addr: %s\n",
		inet_ntop(AF_INET, &(tcp_addr->ip_addr), str, sizeof (str)));
	(void) fprintf(outstream, "port: %d\n", tcp_addr->port);
	(void) fprintf(outstream, "addr_env.addr_env_len: %d\n",
		tcp_addr->addr_env.addr_env_len);
	for (i = 0; i < tcp_addr->addr_env.addr_env_len; i++) {
		print_ndmp_pval(outstream, tcp_addr->addr_env.addr_env_val);
		if (i < (tcp_addr->addr_env.addr_env_len - 1))
			(tcp_addr->addr_env.addr_env_val)++;
	}
}

/*
 * print_ndmp_addr_type() : Prints ndmp_addr_type structure.
 */
void
print_ndmp_addr_type(FILE * outstream, ndmp_addr_type addr)
{

	switch (addr) {
		case NDMP_ADDR_LOCAL:
		(void) fprintf(outstream, "NDMP_ADDR_LOCAL\n");
		break;
	case NDMP_ADDR_TCP:
		(void) fprintf(outstream, "NDMP_ADDR_TCP\n");
		break;
	case NDMP_ADDR_RESERVED:
		(void) fprintf(outstream, "NDMP_ADDR_RESERVED\n");
		break;
	case NDMP_ADDR_IPC:
		(void) fprintf(outstream, "NDMP_ADDR_IPC\n");
		break;
	}
}


/*
 * print_ndmp_addr() : Prints ndmp_addr structure.
 */
void
print_ndmp_addr(FILE * outstream, ndmp_addr * addr)
{
	print_ndmp_addr_type(outstream, addr->addr_type);
	switch (addr->addr_type) {
	case NDMP_ADDR_TCP:
		(void) fprintf(outstream, "tcp_addr.tcp_addr_len: %d\n",
			addr->ndmp_addr_u.tcp_addr.tcp_addr_len);
		(void) fprintf(outstream, "tcp_addr.tcp_addr_val:\n");
		if (addr->ndmp_addr_u.tcp_addr.tcp_addr_val != 0)
			print_ndmp_tcp_addr(outstream,
			addr->ndmp_addr_u.tcp_addr.tcp_addr_val);
		break;
	case NDMP_ADDR_IPC:
		(void) fprintf(outstream,
			"ipc_addr.comm_data.comm_data_len: %d\n",
			addr->ndmp_addr_u.ipc_addr.comm_data.comm_data_len);
		(void) fprintf(outstream,
			"ipc_addr.comm_data.comm_data_val: %s\n",
			addr->ndmp_addr_u.ipc_addr.comm_data.comm_data_val);
		break;
	default:
		break;
	}
}

/*
 * ndmpMoverStateToStr() : Converts ndmp mover state code to ndmp mover state
 * string.
 */
char *
ndmpMoverStateToStr(ndmp_mover_state state, char *str_ndmp_mover_state)
{
	switch (state) {
		case NDMP_MOVER_STATE_IDLE:
		(void) strcpy(str_ndmp_mover_state,
			"NDMP_MOVER_STATE_IDLE");
		break;
	case NDMP_MOVER_STATE_LISTEN:
		(void) strcpy(str_ndmp_mover_state,
			"NDMP_MOVER_STATE_LISTEN");
		break;
	case NDMP_MOVER_STATE_ACTIVE:
		(void) strcpy(str_ndmp_mover_state,
			"NDMP_MOVER_STATE_ACTIVE");
		break;
	case NDMP_MOVER_STATE_PAUSED:
		(void) strcpy(str_ndmp_mover_state,
			"NDMP_MOVER_STATE_PAUSED");
		break;
	case NDMP_MOVER_STATE_HALTED:
		(void) strcpy(str_ndmp_mover_state,
		"NDMP_MOVER_STATE_HALTED");
		break;
	default:
		(void) strcpy(str_ndmp_mover_state, "ERROR");
	}
	return (str_ndmp_mover_state);
}

/*
 * ndmpMoverPauseReasonToStr() : COnverts ndmp mover pause reason code to
 * ndmp mover pause reason string.
 */
char *
ndmpMoverPauseReasonToStr(ndmp_mover_pause_reason reason,
	char *str_ndmp_mover_pause_reason)
{
	switch (reason) {
		case NDMP_MOVER_PAUSE_NA:
		(void) strcpy(str_ndmp_mover_pause_reason,
			"NDMP_MOVER_PAUSE_NA");
		break;
	case NDMP_MOVER_PAUSE_EOM:
		(void) strcpy(str_ndmp_mover_pause_reason,
			"NDMP_MOVER_PAUSE_EOM");
		break;
	case NDMP_MOVER_PAUSE_EOF:
		(void) strcpy(str_ndmp_mover_pause_reason,
			"NDMP_MOVER_PAUSE_EOF");
		break;
	case NDMP_MOVER_PAUSE_SEEK:
		(void) strcpy(str_ndmp_mover_pause_reason,
			"NDMP_MOVER_PAUSE_SEEK");
		break;
	case NDMP_MOVER_PAUSE_EOW:
		(void) strcpy(str_ndmp_mover_pause_reason,
			"NDMP_MOVER_PAUSE_EOW");
		break;
	}

	return (str_ndmp_mover_pause_reason);
}

/*
 * ndmpMoverHaltReasonToStr() : Converts ndmp mover halt reason code to ndmp
 * mover halt reason string.
 */
char *
ndmpMoverHaltReasonToStr(ndmp_mover_halt_reason reason,
	char *str_ndmp_mover_halt_reason)
{
	switch (reason) {
		case NDMP_MOVER_HALT_NA:
		(void) strcpy(str_ndmp_mover_halt_reason,
			"NDMP_MOVER_HALT_NA");
		break;
	case NDMP_MOVER_HALT_CONNECT_CLOSED:
		(void) strcpy(str_ndmp_mover_halt_reason,
			"NDMP_MOVER_HALT_CONNECT_CLOSED");
		break;
	case NDMP_MOVER_HALT_ABORTED:
		(void) strcpy(str_ndmp_mover_halt_reason,
			"NDMP_MOVER_HALT_ABORTED");
		break;
	case NDMP_MOVER_HALT_INTERNAL_ERROR:
		(void) strcpy(str_ndmp_mover_halt_reason,
			"NDMP_MOVER_HALT_INTERNAL_ERROR");
		break;
	case NDMP_MOVER_HALT_CONNECT_ERROR:
		(void) strcpy(str_ndmp_mover_halt_reason,
			"NDMP_MOVER_HALT_CONNECT_ERROR");
		break;
	case NDMP_MOVER_HALT_MEDIA_ERROR:
		(void) strcpy(str_ndmp_mover_halt_reason,
			"NDMP_MOVER_HALT_MEDIA_ERROR");
		break;
	}

	return (str_ndmp_mover_halt_reason);
}

/*
 * ndmpDataOperationToStr() : Converts ndmp data operation code to ndmp data
 * openration string.
 */
char *
ndmpDataOperationToStr(ndmp_data_operation operation,
	char *str_ndmp_data_operation)
{
	switch (operation) {
		case NDMP_DATA_OP_NOACTION:
		(void) strcpy(str_ndmp_data_operation,
			"NDMP_DATA_OP_NOACTION");
		break;
	case NDMP_DATA_OP_BACKUP:
		(void) strcpy(str_ndmp_data_operation,
			"NDMP_DATA_OP_BACKUP");
		break;
	case NDMP_DATA_OP_RECOVER:
		(void) strcpy(str_ndmp_data_operation,
		"NDMP_DATA_OP_RECOVER");
		break;
	case NDMP_DATA_OP_RECOVER_FILEHIST:
		(void) strcpy(str_ndmp_data_operation,
		"NDMP_DATA_OP_RECOVER_FILEHIST");
		break;
	}
	return (str_ndmp_data_operation);
}

/*
 * ndmpDataStateToStr() : Converts ndmp data state code to ndmp data state
 * sting.
 */
char *
ndmpDataStateToStr(ndmp_data_state state, char *str_ndmp_data_state)
{
	switch (state) {
		case NDMP_DATA_STATE_IDLE:
		(void) strcpy(str_ndmp_data_state,
			"NDMP_DATA_STATE_IDLE");
		break;
	case NDMP_DATA_STATE_ACTIVE:
		(void) strcpy(str_ndmp_data_state,
			"NDMP_DATA_STATE_ACTIVE");
		break;
	case NDMP_DATA_STATE_HALTED:
		(void) strcpy(str_ndmp_data_state,
			"NDMP_DATA_STATE_HALTED");
		break;
	case NDMP_DATA_STATE_LISTEN:
		(void) strcpy(str_ndmp_data_state,
			"NDMP_DATA_STATE_LISTEN");
		break;
	case NDMP_DATA_STATE_CONNECTED:
		(void) strcpy(str_ndmp_data_state,
			"NDMP_DATA_STATE_CONNECTED");
		break;
	}
	return (str_ndmp_data_state);
}

/*
 * ndmpDataHaltReasonToStr() : Converts ndmp data halt reason code to ndmp
 * data halt reason string.
 */
char *
ndmpDataHaltReasonToStr(ndmp_data_halt_reason reason,
	char *str_ndmp_data_halt_reason)
{
	switch (reason) {
		case NDMP_DATA_HALT_NA:
		(void) strcpy(str_ndmp_data_halt_reason,
			"NDMP_DATA_HALT_NA");
		break;
	case NDMP_DATA_HALT_SUCCESSFUL:
		(void) strcpy(str_ndmp_data_halt_reason,
			"NDMP_DATA_HALT_SUCCESSFUL");
		break;
	case NDMP_DATA_HALT_ABORTED:
		(void) strcpy(str_ndmp_data_halt_reason,
			"NDMP_DATA_HALT_ABORTED");
		break;
	case NDMP_DATA_HALT_INTERNAL_ERROR:
		(void) strcpy(str_ndmp_data_halt_reason,
			"NDMP_DATA_HALT_INTERNAL_ERROR");
		break;
	case NDMP_DATA_HALT_CONNECT_ERROR:
		(void) strcpy(str_ndmp_data_halt_reason,
			"NDMP_DATA_HALT_CONNECT_ERROR");
		break;
	}
	return (str_ndmp_data_halt_reason);
}

/*
 * convert_mover_mode : Converts the mover mode from a string to a enum.
 * Return : ndmp_mover_mode
 */
ndmp_mover_mode
convert_mover_mode(char *mover_mode)
{
	if (mover_mode == NULL) {
		return (NDMP_MOVER_MODE_READ);
	}
	if (!(strcmp(mover_mode, "NDMP_MOVER_MODE_READ")))
		return (NDMP_MOVER_MODE_READ);
	else if (!(strcmp(mover_mode, "NDMP_MOVER_MODE_WRITE")))
		return (NDMP_MOVER_MODE_WRITE);
	else
		return (NDMP_MOVER_MODE_READ);
}
/*
 * convert_mover_mode : Converts the mover mode from a string to a enum.
 * Return : ndmp_mover_mode
 */
ndmp_addr_type
convert_addr_type(char *addr_type)
{
	if (addr_type == NULL) {
		return (NDMP_ADDR_LOCAL);
	}
	if (!(strcmp(addr_type, "NDMP_ADDR_LOCAL")))
		return (NDMP_ADDR_LOCAL);
	else if (!(strcmp(addr_type, "NDMP_ADDR_TCP")))
		return (NDMP_ADDR_TCP);
	else if (!(strcmp(addr_type, "NDMP_ADDR_IPC")))
		return (NDMP_ADDR_IPC);
	else if (!(strcmp(addr_type, "NDMP_ADDR_RESERVED")))
		return (NDMP_ADDR_RESERVED);
	else
		return (NDMP_ADDR_IPC);
}

/*
 * convert_butype : Converts the backup type from a string to a int. Return :
 * ndmp_mover_mode
 */
int
convert_butype(char *backup_type)
{
	if (backup_type != NULL) {
		if (!(strcmp(backup_type, "tar")))
			return (STD_BACKUP_TYPE_TAR);
		else if (!(strcmp(backup_type, "dump")))
			return (STD_BACKUP_TYPE_DUMP);
		else
			return (-1);
	} else
		return (STD_BACKUP_TYPE_DUMP);
}

/*
 * convert_tape_op : Converts the ndmp_tape_mtio_op from a string to a enum.
 * Return : ndmp_tape_mtio_op
 */
ndmp_tape_mtio_op
convert_tape_mtio_op(char *tape_mtio_op)
{
	if (tape_mtio_op == NULL) {
		return (NDMP_MTIO_TUR);
	}
	if (!(strcmp(tape_mtio_op, "NDMP_MTIO_FSF")))
		return (NDMP_MTIO_FSF);
	else if (!(strcmp(tape_mtio_op, "NDMP_MTIO_BSF")))
		return (NDMP_MTIO_BSF);
	else if (!(strcmp(tape_mtio_op, "NDMP_MTIO_REW")))
		return (NDMP_MTIO_REW);
	else if (!(strcmp(tape_mtio_op, "NDMP_MTIO_OFF")))
		return (NDMP_MTIO_OFF);
	else if (!(strcmp(tape_mtio_op, "NDMP_MTIO_EOF")))
		return (NDMP_MTIO_EOF);
	else if (!(strcmp(tape_mtio_op, "NDMP_MTIO_TUR")))
		return (NDMP_MTIO_TUR);
	else
		return (-1);
}

/*
 * print_test_result() Helper method to print the test case result.
 */
int
print_test_result(int result, FILE * outfile)
{
	if (result == 0) {
		(void) ndmp_fprintf(outfile,
				    "Test case result : Pass\n");
		return (0);
	} else {
		(void) ndmp_fprintf(outfile,
				    "Test case result : Fail\n");
		return (1);
	}
}

/*
 * print_cleanup_result() Helper method to print the test cleanup result.
 */
int
print_cleanup_result(int result, FILE * outfile)
{
	if (result == 0) {
		(void) ndmp_fprintf(outfile,
				    "Cleanup Passed ...\n");
		return (0);
	} else {
		(void) ndmp_fprintf(outfile,
				    "Cleanup Failed ...\n");
		return (1);
	}
}

/*
 * print_intl_result() Helper method to print the test Initialization result.
 */
int
print_intl_result(int result, FILE * outfile)
{
	if (result == 0) {
		(void) ndmp_fprintf(outfile,
				    "Initialization Passed ...\n");
		return (0);
	} else {
		(void) ndmp_fprintf(outfile,
				    "Initialization Failed ...\n");
		return (1);
	}
}

/*
 * ndmp_err_to_string() Takes the error code as argument and return the
 * string.
 *
 * Argument : ndmp error code Returns : char * - Pointer to the string.
 */
char *
ndmp_err_to_string(ndmp_error error)
{
	if (error == NDMP_NO_ERR)
		return ("NDMP_NO_ERR");
	else if (error == NDMP_NOT_SUPPORTED_ERR)
		return ("NDMP_NOT_SUPPORTED_ERR");
	else if (error == NDMP_DEVICE_BUSY_ERR)
		return ("NDMP_DEVICE_BUSY_ERR");
	else if (error == NDMP_DEVICE_OPENED_ERR)
		return ("NDMP_DEVICE_OPENED_ERR");
	else if (error == NDMP_NOT_AUTHORIZED_ERR)
		return ("NDMP_NOT_AUTHORIZED_ERR");
	else if (error == NDMP_PERMISSION_ERR)
		return ("NDMP_PERMISSION_ERR");
	else if (error == NDMP_DEV_NOT_OPEN_ERR)
		return ("NDMP_DEV_NOT_OPEN_ERR");
	else if (error == NDMP_IO_ERR)
		return ("NDMP_IO_ERR");
	else if (error == NDMP_TIMEOUT_ERR)
		return ("NDMP_TIMEOUT_ERR");
	else if (error == NDMP_ILLEGAL_ARGS_ERR)
		return ("NDMP_ILLEGAL_ARGS_ERR");
	else if (error == NDMP_NO_TAPE_LOADED_ERR)
		return ("NDMP_NO_TAPE_LOADED_ERR");
	else if (error == NDMP_WRITE_PROTECT_ERR)
		return ("NDMP_WRITE_PROTECT_ERR");
	else if (error == NDMP_EOF_ERR)
		return ("NDMP_EOF_ERR");
	else if (error == NDMP_EOM_ERR)
		return ("NDMP_EOM_ERR");
	else if (error == NDMP_FILE_NOT_FOUND_ERR)
		return ("NDMP_FILE_NOT_FOUND_ERR");
	else if (error == NDMP_BAD_FILE_ERR)
		return ("NDMP_BAD_FILE_ERR");
	else if (error == NDMP_NO_DEVICE_ERR)
		return ("NDMP_NO_DEVICE_ERR");
	else if (error == NDMP_NO_BUS_ERR)
		return ("NDMP_NO_BUS_ERR");
	else if (error == NDMP_XDR_DECODE_ERR)
		return ("NDMP_XDR_DECODE_ERR");
	else if (error == NDMP_ILLEGAL_STATE_ERR)
		return ("NDMP_ILLEGAL_STATE_ERR");
	else if (error == NDMP_UNDEFINED_ERR)
		return ("NDMP_UNDEFINED_ERR");
	else if (error == NDMP_XDR_ENCODE_ERR)
		return ("NDMP_XDR_ENCODE_ERR");
	else if (error == NDMP_NO_MEM_ERR)
		return ("NDMP_NO_MEM_ERR");
	else if (error == NDMP_CONNECT_ERR)
		return ("NDMP_CONNECT_ERR");
	else if (error == NDMP_SEQUENCE_NUM_ERR)
		return ("NDMP_SEQUENCE_NUM_ERR");
	else if (error == NDMP_READ_IN_PROGRESS_ERR)
		return ("NDMP_READ_IN_PROGRESS_ERR");
	else if (error == NDMP_PRECONDITION_ERR)
		return ("NDMP_PRECONDITION_ERR");
	else if (error == NDMP_VERSION_NOT_SUPPORTED_ERR)
		return ("NDMP_VERSION_NOT_SUPPORTED_ERR");
	else if (error == NDMP_EXT_DUPL_CLASSES_ERR)
		return ("NDMP_EXT_DUPL_CLASSES_ERR");
	else if (error == NDMP_EXT_DANDN_ILLEGAL_ERR)
		return ("NDMP_EXT_DANDN_ILLEGAL_ERR");
	else
		return ("Unknown Error");
}

/*
 * create_host_info(): Helper method to fill to create host_info structure.
 *
 * Arguments : host - Address of host structure. list - Command line parameter
 * list. logfile - Log file.
 *
 * Return : SUCCESS - If Successful. ERROR - If Failure.
 */
int
create_host_info(host_info * host, char **list, FILE * logfile)
{
	if (list[NDMPAUTH] == NULL)
		host->auth_type = NDMP_AUTH_TEXT;
	else if (!(strcmp(list[NDMPAUTH], "NDMP_AUTH_NONE")))
		host->auth_type = NDMP_AUTH_NONE;
	else if (!(strcmp(list[NDMPAUTH], "NDMP_AUTH_TEXT")))
		host->auth_type = NDMP_AUTH_TEXT;
	else if (!(strcmp(list[NDMPAUTH], "NDMP_AUTH_MD5")))
		host->auth_type = NDMP_AUTH_MD5;
	else
		host->auth_type = NDMP_AUTH_TEXT;

	if (list[SRC_MC] == NULL) {
		ndmp_dprintf(logfile,
			"connect_switcher: source name/IP is null\n");
		return (ERROR);
	} else {
		host->ipAddr = list[SRC_MC];
	}
	if (list[SRCUSER] == NULL) {
		ndmp_dprintf(logfile,
			"connect_switcher: source user/pass is null\n");
		return (ERROR);
	} else {
		host->password = list[SRCPSWD];
		host->userName = list[SRCUSER];
	}
	if (list[NDMPVERSION] != NULL) {
		host->protocol_version = atoi(list[NDMPVERSION]);
	} else {
		host->protocol_version = 4;
	}
	return (SUCCESS);
}

/*
 * check_test_and_sub_case() : Check the test case and sub case string.
 *
 * Returns : SUCCESS - Sucess. Error - Failure.
 */
int
check_print_test_and_sub_case(char *test_case, char *sub_case, FILE * outfile)
{
	if (test_case == NULL && sub_case == NULL) {
		(void) ndmp_fprintf(outfile,
				    "Test case name : NULL\n");
		print_test_result(ERROR, outfile);
		return (ERROR);
	} else {
		if (test_case != NULL) {
			(void) ndmp_fprintf(outfile,
				"Test case name : %s - ", test_case);
			if (sub_case != NULL) {
				(void) ndmp_fprintf(outfile,
						    "%s\n", sub_case);
			}
		}
		return (SUCCESS);
	}
}

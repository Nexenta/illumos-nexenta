/*
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * BSD 3 Clause License
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *      - Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *      - Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *      - Neither the name of Sun Microsystems, Inc. nor the
 *      names of its contributors may be used to endorse or promote products
 *      derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY SUN MICROSYSTEMS, INC. ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL SUN MICROSYSTEMS, INC. BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/uio.h>
#include <stdarg.h>

#include <ndmp_connect.h>

/*
 * strToNdmpSubMessageCode(): Converts ndmp message string
 * to ndmp message code.
 *
 * Arguments :
 * 	char * -  ndmp message string.
 * Returns :
 * 	ndmp_message - ndmp_message code.
 */
ndmp_message
strToNdmpSubMessageCode(char *strNdmp)
{
	if (!(strcmp(strNdmp, "NDMP_MOVER_HALT_CONNECT_CLOSED")))
		return ((ndmp_message) NDMP_MOVER_HALT_CONNECT_CLOSED);
	if (!(strcmp(strNdmp, "NDMP_MOVER_HALT_ABORTED")))
		return ((ndmp_message) NDMP_MOVER_HALT_ABORTED);
	if (!(strcmp(strNdmp, "NDMP_MOVER_HALT_INTERNAL_ERROR")))
		return ((ndmp_message) NDMP_MOVER_HALT_INTERNAL_ERROR);
	if (!(strcmp(strNdmp, "NDMP_MOVER_HALT_CONNECT_ERROR")))
		return ((ndmp_message) NDMP_MOVER_HALT_CONNECT_ERROR);
	if (!(strcmp(strNdmp, "NDMP_MOVER_HALT_MEDIA_ERROR")))
		return ((ndmp_message) NDMP_MOVER_HALT_MEDIA_ERROR);

	if (!(strcmp(strNdmp, "NDMP_DATA_HALT_SUCCESSFUL")))
		return ((ndmp_message) NDMP_DATA_HALT_SUCCESSFUL);
	if (!(strcmp(strNdmp, "NDMP_DATA_HALT_ABORTED")))
		return ((ndmp_message) NDMP_DATA_HALT_ABORTED);
	if (!(strcmp(strNdmp, "NDMP_DATA_HALT_INTERNAL_ERROR")))
		return ((ndmp_message) NDMP_DATA_HALT_INTERNAL_ERROR);
	if (!(strcmp(strNdmp, "NDMP_DATA_HALT_CONNECT_ERROR")))
		return ((ndmp_message) NDMP_DATA_HALT_CONNECT_ERROR);

	if (!(strcmp(strNdmp, "NDMP_CONNECTED")))
		return ((ndmp_message) NDMP_CONNECTED);
	if (!(strcmp(strNdmp, "NDMP_SHUTDOWN")))
		return ((ndmp_message) NDMP_SHUTDOWN);
	if (!(strcmp(strNdmp, "NDMP_REFUSED")))
		return ((ndmp_message) NDMP_REFUSED);

	if (!(strcmp(strNdmp, "NDMP_MOVER_PAUSE_NA")))
		return ((ndmp_message) NDMP_MOVER_PAUSE_NA);
	if (!(strcmp(strNdmp, "NDMP_MOVER_PAUSE_EOM")))
		return ((ndmp_message) NDMP_MOVER_PAUSE_EOM);
	if (!(strcmp(strNdmp, "NDMP_MOVER_PAUSE_EOF")))
		return ((ndmp_message) NDMP_MOVER_PAUSE_EOF);
	if (!(strcmp(strNdmp, "NDMP_MOVER_PAUSE_SEEK")))
		return ((ndmp_message) NDMP_MOVER_PAUSE_SEEK);
	if (!(strcmp(strNdmp, "NDMP_MOVER_PAUSE_EOW")))
		return ((ndmp_message) NDMP_MOVER_PAUSE_EOW);

	if (!(strcmp(strNdmp, "NDMP_LOG_NORMAL")))
		return ((ndmp_message) NDMP_LOG_NORMAL);
	if (!(strcmp(strNdmp, "NDMP_LOG_DEBUG")))
		return ((ndmp_message) NDMP_LOG_DEBUG);
	if (!(strcmp(strNdmp, "NDMP_LOG_ERROR")))
		return ((ndmp_message) NDMP_LOG_ERROR);
	if (!(strcmp(strNdmp, "NDMP_LOG_WARNING")))
		return ((ndmp_message) NDMP_LOG_WARNING);

	if (!(strcmp(strNdmp, "NDMP_RECOVERY_SUCCESSFUL")))
		return ((ndmp_message) NDMP_RECOVERY_SUCCESSFUL);
	if (!(strcmp(strNdmp, "NDMP_RECOVERY_FAILED_PERMISSION")))
		return ((ndmp_message) NDMP_RECOVERY_FAILED_PERMISSION);
	if (!(strcmp(strNdmp, "NDMP_RECOVERY_FAILED_NOT_FOUND")))
		return ((ndmp_message) NDMP_RECOVERY_FAILED_NOT_FOUND);
	if (!(strcmp(strNdmp, "NDMP_RECOVERY_FAILED_NO_DIRECTORY")))
		return ((ndmp_message) NDMP_RECOVERY_FAILED_NO_DIRECTORY);
	if (!(strcmp(strNdmp, "NDMP_RECOVERY_FAILED_OUT_OF_MEMORY")))
		return ((ndmp_message) NDMP_RECOVERY_FAILED_OUT_OF_MEMORY);
	if (!(strcmp(strNdmp, "NDMP_RECOVERY_FAILED_IO_ERROR")))
		return ((ndmp_message) NDMP_RECOVERY_FAILED_IO_ERROR);
	if (!(strcmp(strNdmp, "NDMP_RECOVERY_FAILED_UNDEFINED_ERROR")))
		return ((ndmp_message) NDMP_RECOVERY_FAILED_UNDEFINED_ERROR);
	if (!(strcmp(strNdmp, "NDMP_RECOVERY_FAILED_FILE_PATH_EXISTS")))
		return ((ndmp_message) NDMP_RECOVERY_FAILED_FILE_PATH_EXISTS);

	else
		return (1000);
}

/*
 * strToNdmpMessageCode(): Converts ndmp message string to
 * ndmp message code.
 *
 * Arguments :
 * 	char * - ndmp message string to be converted.
 *
 * Returns :
 * 	ndmp_message - ndmp_message code.
 */
ndmp_message
strToNdmpMessageCode(char *strNdmp)
{
	if (!(strcmp(strNdmp, "NDMP_CONNECT_OPEN")))
		return (NDMP_CONNECT_OPEN);
	if (!(strcmp(strNdmp, "NDMP_CONNECT_CLIENT_AUTH")))
		return (NDMP_CONNECT_CLIENT_AUTH);
	if (!(strcmp(strNdmp, "NDMP_CONNECT_CLOSE")))
		return (NDMP_CONNECT_CLOSE);
	if (!(strcmp(strNdmp, "NDMP_CONNECT_SERVER_AUTH")))
		return (NDMP_CONNECT_SERVER_AUTH);

	if (!(strcmp(strNdmp, "NDMP_CONFIG_GET_HOST_INFO")))
		return (NDMP_CONFIG_GET_HOST_INFO);
	if (!(strcmp(strNdmp, "NDMP_CONFIG_GET_CONNECTION_TYPE")))
		return (NDMP_CONFIG_GET_CONNECTION_TYPE);
	if (!(strcmp(strNdmp, "NDMP_CONFIG_GET_AUTH_ATTR")))
		return (NDMP_CONFIG_GET_AUTH_ATTR);
	if (!(strcmp(strNdmp, "NDMP_CONFIG_GET_BUTYPE_INFO")))
		return (NDMP_CONFIG_GET_BUTYPE_INFO);
	if (!(strcmp(strNdmp, "NDMP_CONFIG_GET_FS_INFO")))
		return (NDMP_CONFIG_GET_FS_INFO);
	if (!(strcmp(strNdmp, "NDMP_CONFIG_GET_TAPE_INFO")))
		return (NDMP_CONFIG_GET_TAPE_INFO);
	if (!(strcmp(strNdmp, "NDMP_CONFIG_GET_SCSI_INFO")))
		return (NDMP_CONFIG_GET_SCSI_INFO);
	if (!(strcmp(strNdmp, "NDMP_CONFIG_GET_SERVER_INFO")))
		return (NDMP_CONFIG_GET_SERVER_INFO);
	if (!(strcmp(strNdmp, "NDMP_CONFIG_GET_EXT_LIST")))
		return (NDMP_CONFIG_GET_EXT_LIST);
	if (!(strcmp(strNdmp, "NDMP_CONFIG_SET_EXT_LIST")))
		return (NDMP_CONFIG_SET_EXT_LIST);

	if (!(strcmp(strNdmp, "NDMP_SCSI_OPEN")))
		return (NDMP_SCSI_OPEN);
	if (!(strcmp(strNdmp, "NDMP_SCSI_CLOSE")))
		return (NDMP_SCSI_CLOSE);
	if (!(strcmp(strNdmp, "NDMP_SCSI_GET_STATE")))
		return (NDMP_SCSI_GET_STATE);
	if (!(strcmp(strNdmp, "NDMP_SCSI_RESET_DEVICE")))
		return (NDMP_SCSI_RESET_DEVICE);
	if (!(strcmp(strNdmp, "NDMP_SCSI_EXECUTE_CDB")))
		return (NDMP_SCSI_EXECUTE_CDB);

	if (!(strcmp(strNdmp, "NDMP_TAPE_OPEN")))
		return (NDMP_TAPE_OPEN);
	if (!(strcmp(strNdmp, "NDMP_TAPE_CLOSE")))
		return (NDMP_TAPE_CLOSE);
	if (!(strcmp(strNdmp, "NDMP_TAPE_GET_STATE")))
		return (NDMP_TAPE_GET_STATE);
	if (!(strcmp(strNdmp, "NDMP_TAPE_MTIO")))
		return (NDMP_TAPE_MTIO);
	if (!(strcmp(strNdmp, "NDMP_TAPE_WRITE")))
		return (NDMP_TAPE_WRITE);
	if (!(strcmp(strNdmp, "NDMP_TAPE_READ")))
		return (NDMP_TAPE_READ);
	if (!(strcmp(strNdmp, "NDMP_TAPE_EXECUTE_CDB")))
		return (NDMP_TAPE_EXECUTE_CDB);

	if (!(strcmp(strNdmp, "NDMP_DATA_GET_STATE")))
		return (NDMP_DATA_GET_STATE);
	if (!(strcmp(strNdmp, "NDMP_DATA_START_BACKUP")))
		return (NDMP_DATA_START_BACKUP);
	if (!(strcmp(strNdmp, "NDMP_DATA_START_RECOVER")))
		return (NDMP_DATA_START_RECOVER);
	if (!(strcmp(strNdmp, "NDMP_DATA_ABORT")))
		return (NDMP_DATA_ABORT);
	if (!(strcmp(strNdmp, "NDMP_DATA_GET_ENV")))
		return (NDMP_DATA_GET_ENV);
	if (!(strcmp(strNdmp, "NDMP_DATA_STOP")))
		return (NDMP_DATA_STOP);
	if (!(strcmp(strNdmp, "NDMP_DATA_LISTEN")))
		return (NDMP_DATA_LISTEN);
	if (!(strcmp(strNdmp, "NDMP_DATA_CONNECT")))
		return (NDMP_DATA_CONNECT);
	if (!(strcmp(strNdmp, "NDMP_DATA_START_RECOVER_FILEHIST")))
		return (NDMP_DATA_START_RECOVER_FILEHIST);

	if (!(strcmp(strNdmp, "NDMP_NOTIFY_DATA_HALTED")))
		return (NDMP_NOTIFY_DATA_HALTED);
	if (!(strcmp(strNdmp, "NDMP_NOTIFY_CONNECTION_STATUS")))
		return (NDMP_NOTIFY_CONNECTION_STATUS);
	if (!(strcmp(strNdmp, "NDMP_NOTIFY_MOVER_HALTED")))
		return (NDMP_NOTIFY_MOVER_HALTED);
	if (!(strcmp(strNdmp, "NDMP_NOTIFY_MOVER_PAUSED")))
		return (NDMP_NOTIFY_MOVER_PAUSED);
	if (!(strcmp(strNdmp, "NDMP_NOTIFY_DATA_READ")))
		return (NDMP_NOTIFY_DATA_READ);

	if (!(strcmp(strNdmp, "NDMP_LOG_FILE")))
		return (NDMP_LOG_FILE);
	if (!(strcmp(strNdmp, "NDMP_LOG_MESSAGE")))
		return (NDMP_LOG_MESSAGE);

	if (!(strcmp(strNdmp, "NDMP_FH_ADD_FILE")))
		return (NDMP_FH_ADD_FILE);
	if (!(strcmp(strNdmp, "NDMP_FH_ADD_DIR")))
		return (NDMP_FH_ADD_DIR);
	if (!(strcmp(strNdmp, "NDMP_FH_ADD_NODE")))
		return (NDMP_FH_ADD_NODE);

	if (!(strcmp(strNdmp, "NDMP_MOVER_GET_STATE")))
		return (NDMP_MOVER_GET_STATE);
	if (!(strcmp(strNdmp, "NDMP_MOVER_LISTEN")))
		return (NDMP_MOVER_LISTEN);
	if (!(strcmp(strNdmp, "NDMP_MOVER_CONTINUE")))
		return (NDMP_MOVER_CONTINUE);
	if (!(strcmp(strNdmp, "NDMP_MOVER_ABORT")))
		return (NDMP_MOVER_ABORT);
	if (!(strcmp(strNdmp, "NDMP_MOVER_STOP")))
		return (NDMP_MOVER_STOP);
	if (!(strcmp(strNdmp, "NDMP_MOVER_SET_WINDOW")))
		return (NDMP_MOVER_SET_WINDOW);
	if (!(strcmp(strNdmp, "NDMP_MOVER_READ")))
		return (NDMP_MOVER_READ);
	if (!(strcmp(strNdmp, "NDMP_MOVER_CLOSE")))
		return (NDMP_MOVER_CLOSE);
	if (!(strcmp(strNdmp, "NDMP_MOVER_SET_RECORD_SIZE")))
		return (NDMP_MOVER_SET_RECORD_SIZE);
	if (!(strcmp(strNdmp, "NDMP_MOVER_CONNECT")))
		return (NDMP_MOVER_CONNECT);

	if (!(strcmp(strNdmp, "NDMP_EXT_STANDARD_BASE")))
		return (NDMP_EXT_STANDARD_BASE);

	if (!(strcmp(strNdmp, "NDMP_EXT_PROPRIETARY_BASE")))
		return (NDMP_EXT_PROPRIETARY_BASE);

	return (0);
}

/*
 * strToNdmpErrorCode() : Converts ndmp error code in string format
 * to ndmp error code in number format.
 *
 * Arguments :
 * 	char * - ndmp error code in string format.
 * Returns :
 * 	ndmp_error - ndmp_error code.
 */
ndmp_error
strToNdmpErrorCode(char *strNdmpErrorCode)
{
	if (! (strcmp(strNdmpErrorCode, "NDMP_NO_ERR")))
		return (NDMP_NO_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_NOT_SUPPORTED_ERR")))
		return (NDMP_NOT_SUPPORTED_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_DEVICE_BUSY_ERR")))
		return (NDMP_DEVICE_BUSY_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_DEVICE_OPENED_ERR")))
		return (NDMP_DEVICE_OPENED_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_NOT_AUTHORIZED_ERR")))
		return (NDMP_NOT_AUTHORIZED_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_PERMISSION_ERR")))
		return (NDMP_PERMISSION_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_DEV_NOT_OPEN_ERR")))
		return (NDMP_DEV_NOT_OPEN_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_IO_ERR")))
		return (NDMP_IO_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_TIMEOUT_ERR")))
		return (NDMP_TIMEOUT_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_ILLEGAL_ARGS_ERR")))
		return (NDMP_ILLEGAL_ARGS_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_NO_TAPE_LOADED_ERR")))
		return (NDMP_NO_TAPE_LOADED_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_WRITE_PROTECT_ERR")))
		return (NDMP_WRITE_PROTECT_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_EOF_ERR")))
		return (NDMP_EOF_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_EOM_ERR")))
		return (NDMP_EOM_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_FILE_NOT_FOUND_ERR")))
		return (NDMP_FILE_NOT_FOUND_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_BAD_FILE_ERR")))
		return (NDMP_BAD_FILE_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_NO_DEVICE_ERR")))
		return (NDMP_NO_DEVICE_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_NO_BUS_ERR")))
		return (NDMP_NO_BUS_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_XDR_DECODE_ERR")))
		return (NDMP_XDR_DECODE_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_ILLEGAL_STATE_ERR")))
		return (NDMP_ILLEGAL_STATE_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_UNDEFINED_ERR")))
		return (NDMP_UNDEFINED_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_XDR_ENCODE_ERR")))
		return (NDMP_XDR_ENCODE_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_NO_MEM_ERR")))
		return (NDMP_NO_MEM_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_CONNECT_ERR")))
		return (NDMP_CONNECT_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_SEQUENCE_NUM_ERR")))
		return (NDMP_SEQUENCE_NUM_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_READ_IN_PROGRESS_ERR")))
		return (NDMP_READ_IN_PROGRESS_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_PRECONDITION_ERR")))
		return (NDMP_PRECONDITION_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_CLASS_NOT_SUPPORTED_ERR")))
		return (NDMP_CLASS_NOT_SUPPORTED_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_VERSION_NOT_SUPPORTED_ERR")))
		return (NDMP_VERSION_NOT_SUPPORTED_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_EXT_DUPL_CLASSES_ERR")))
		return (NDMP_EXT_DUPL_CLASSES_ERR);
	if (! (strcmp(strNdmpErrorCode, "NDMP_EXT_DANDN_ILLEGAL_ERR")))
		return (NDMP_EXT_DANDN_ILLEGAL_ERR);
	return (0);
}

static char	strNdmpErrorCode[40];

/*
 * ndmpErrorCodeToStr() : Converts ndmp error code from
 * hex format to ndmp error code in string format.
 *
 * Arguments :
 * 	ndmp_error - ndmp_error code.
 * Returns :
 * 	char * - ndmp error code in string format.
 */
char *
ndmpErrorCodeToStr(ndmp_error ndmpErrorCode)
{
	switch (ndmpErrorCode) {
		case NDMP_NO_ERR:
			(void) strcpy(strNdmpErrorCode, "NDMP_NO_ERR");
			break;
		case NDMP_NOT_SUPPORTED_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_NOT_SUPPORTED_ERR");
			break;
		case NDMP_DEVICE_BUSY_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_DEVICE_BUSY_ERR");
			break;
		case NDMP_DEVICE_OPENED_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_DEVICE_OPENED_ERR");
			break;
		case NDMP_NOT_AUTHORIZED_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_NOT_AUTHORIZED_ERR");
			break;
		case NDMP_PERMISSION_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_PERMISSION_ERR");
			break;
		case NDMP_DEV_NOT_OPEN_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_DEV_NOT_OPEN_ERR");
			break;
		case NDMP_IO_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_IO_ERR");
			break;
		case NDMP_TIMEOUT_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_TIMEOUT_ERR");
			break;
		case NDMP_ILLEGAL_ARGS_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_ILLEGAL_ARGS_ERR");
			break;
		case NDMP_NO_TAPE_LOADED_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_NO_TAPE_LOADED_ERR");
			break;
		case NDMP_WRITE_PROTECT_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_WRITE_PROTECT_ERR");
			break;
		case NDMP_EOF_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_EOF_ERR");
			break;
		case NDMP_EOM_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_EOM_ERR");
			break;
		case NDMP_FILE_NOT_FOUND_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_FILE_NOT_FOUND_ERR");
			break;
		case NDMP_BAD_FILE_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_BAD_FILE_ERR");
			break;
		case NDMP_NO_DEVICE_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_NO_DEVICE_ERR");
			break;
		case NDMP_NO_BUS_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_NO_BUS_ERR");
			break;
		case NDMP_XDR_DECODE_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_XDR_DECODE_ERR");
			break;
		case NDMP_ILLEGAL_STATE_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_ILLEGAL_STATE_ERR");
			break;
		case NDMP_UNDEFINED_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_UNDEFINED_ERR");
			break;
		case NDMP_XDR_ENCODE_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_XDR_ENCODE_ERR");
			break;
		case NDMP_NO_MEM_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_NO_MEM_ERR");
			break;
		case NDMP_CONNECT_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_CONNECT_ERR");
			break;
		case NDMP_SEQUENCE_NUM_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_SEQUENCE_NUM_ERR");
			break;
		case NDMP_READ_IN_PROGRESS_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_READ_IN_PROGRESS_ERR");
			break;
		case NDMP_PRECONDITION_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_PRECONDITION_ERR");
			break;
		case NDMP_CLASS_NOT_SUPPORTED_ERR:
			(void) strcpy(strNdmpErrorCode,
			"NDMP_CLASS_NOT_SUPPORTED_ERR");
			break;
		case NDMP_VERSION_NOT_SUPPORTED_ERR:
			(void) strcpy(strNdmpErrorCode,
			"NDMP_VERSION_NOT_SUPPORTED_ERR");
			break;
		case NDMP_EXT_DUPL_CLASSES_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_EXT_DUPL_CLASSES_ERR");
			break;
		case NDMP_EXT_DANDN_ILLEGAL_ERR:
			(void) strcpy(strNdmpErrorCode,
			    "NDMP_EXT_DANDN_ILLEGAL_ERR");
			break;
		default:
			(void) strcpy(strNdmpErrorCode,
			    "UNKNOWN_NDMP_ERROR_CODE");
	}

	return (strNdmpErrorCode);
}
/*
 * End of file	:	ndmp_conv.c
 */

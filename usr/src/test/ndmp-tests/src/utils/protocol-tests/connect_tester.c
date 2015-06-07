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
 * Connect Interface authenticates the client and negotiates the version of
 * protocol to be used. This files implements all the connect interfaces.
 * There are four type of methods for each interface. These methods types are
 * extract request, extract reply, print reply and compare reply.
 */


#include <strings.h>
#include <ndmp_lib.h>
#include <ndmp_comm_lib.h>
#include <ndmp_connect.h>
#include <ndmp_conv.h>
#include <data.h>
#include <log.h>


/*
 * inf_connect_open() Test the ndmp connect open interface for different
 * error condition. This message negotiates the protocol version to be used
 * between the DMA and NDMP Server. This message is OPTIONAL if the DMA
 * agrees to the protocol version specified in the
 * NDMP_NOTIFY_CONNECTION_STATUS message. If sent, it MUST be the first
 * message type sent by the DMA. If the suggested protocol version is not
 * supported on the NDMP Server, an NDMP_ILLEGAL_ARGS_ERR MUST be returned.
 *
 * Arguments : error - Error condition to test ndmp_ver - NDMP version to test.
 * Default is 4 outfile - log file
 *
 * Return : 0 - Success 1 - Error
 */
int
inf_connect_open(ndmp_error error, host_info * host_details, FILE * outfile)
{
	conn_handle conn;
	ndmp_connect_open_reply *reply = NULL;

	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_connect_open\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	if (error == NDMP_ILLEGAL_ARGS_ERR) {
		host_details->protocol_version = -1;
	}
	client_connect_open(host_details, &conn, &reply, outfile);
	if (error == NDMP_ILLEGAL_STATE_ERR) {
		ndmp_connect_client_auth_reply *reply_ca = NULL;
		client_connect_authorize(host_details,
						&conn, &reply_ca, outfile);
		if (reply_ca->error != NDMP_NO_ERR) {
			(void) ndmp_fprintf(outfile, "inf_connect_close: "
				"Not able to authorize connection \n");
			print_test_result(1, outfile);
			return (1);
		}
		if (data_listen_core(NDMP_NO_ERR, NDMP_ADDR_LOCAL,
			NULL, outfile, &conn)) {
			(void) ndmp_fprintf(outfile, "inf_connect_close: "
				"Not able to do data listen\n");
		}
		if (data_connect_core(NDMP_NO_ERR, NDMP_ADDR_LOCAL,
			NULL, outfile, &conn)) {
			(void) ndmp_fprintf(outfile, "inf_connect_close: "
				"Not able to do data connect\n");
		}
		client_connect_open(host_details, &conn, &reply, outfile);
	}
	if (reply->error == error)
		print_test_result(0, outfile);
	else
		print_test_result(1, outfile);
	close_connection(&conn, outfile);
	return (0);
}

/*
 * inf_connect_client_auth() Test the ndmp NDMP_CONNECT_CLIENT_AUTH interface
 * for different error condition. This request authenticates the DMA to a
 * NDMP Server. Successful DMA authentication MUST occur prior to processing
 * most NDMP requests. Requests that do not require DMA authentication are
 * limited to NDMP_CONNECT_OPEN, NDMP_CONNECT_CLOSE,
 * NDMP_CONFIG_GET_SERVER_INFO, NDMP_CONFIG_GET_AUTH_ATTR and
 * NDMP_CONNECT_CLIENT_AUTH. Any other request received prior to successful
 * DMA authentication will result in a NDMP_NOT_AUTHORIZED reply error.
 *
 * Arguments : error - Error condition to test. host_details - Information about
 * the host. outfile - log file.
 *
 * Return : 0 - Success 1 - Error
 */
int
inf_connect_client_auth(ndmp_error error, host_info * host_details,
			FILE * outfile)
{
	conn_handle conn;
	ndmp_connect_open_reply *reply = NULL;
	ndmp_connect_client_auth_reply *reply_ca = NULL;

	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_connect_client_auth\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	client_connect_open(host_details, &conn, &reply, outfile);
	if (reply->error != NDMP_NO_ERR) {
		(void) ndmp_dprintf(outfile, "inf_connect_client_auth: "
			"Not able to open connection \n");
		print_test_result(1, outfile);
		return (1);
	}
	client_connect_authorize(host_details, &conn, &reply_ca, outfile);
	if (reply_ca != NULL && reply_ca->error == error) {
		print_test_result(0, outfile);
	} else {
		print_test_result(1, outfile);
	}
	close_connection(&conn, outfile);
	return (0);
}

/*
 * inf_connect_close() Test the ndmp NDMP_CONNECT_CLOSE interface for
 * different error condition. This message is used when the client wants to
 * close the NDMP connection. The DMA SHOULD send this message before
 * shutting down the TCP/IP connection. For reasons of backward
 * compatibility, it is guaranteed that the parameters of this message will
 * not change in any future release. The parameters MUST not change since
 * this message is sent prior to protocol version negotiation.
 *
 * Arguments : error - Error condition to test. host_details - Information about
 * the host. outfile - log file.
 *
 * Return : 0 - Success 1 - Error
 */
int
inf_connect_close(host_info * host_details, FILE * outfile)
{
	conn_handle conn;
	ndmp_connect_open_reply *reply = NULL;
	ndmp_connect_client_auth_reply *reply_ca = NULL;

	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_connect_close\n");
	client_connect_open(host_details, &conn, &reply, outfile);
	if (reply->error != NDMP_NO_ERR) {
		(void) ndmp_fprintf(outfile, "inf_connect_close: "
			"Not able to open connection \n");
		print_test_result(1, outfile);
		return (1);
	}
	client_connect_authorize(host_details, &conn, &reply_ca, outfile);
	if (reply_ca->error != NDMP_NO_ERR) {
		(void) ndmp_fprintf(outfile, "inf_connect_close: "
			"Not able to authorize connection \n");
		print_test_result(1, outfile);
		return (1);
	}
	print_test_result(client_connect_close(&conn, outfile), outfile);
	return (0);
}

/*
 * inf_connect_server_auth() Test the ndmp NDMP_CONNECT_SERVER_AUTH interface
 * for different error condition. This optional request is used by the DMA to
 * force the NDMP Server to authenticate itself. The DMA may use this request
 * when there is a security requirement to validate the sever identity. A DMA
 * MUST authenticate itself to the server using the NDMP_CONNECT_CLIENT_AUTH
 * prior to issuing this request.
 *
 * Arguments : error - Error condition to test. host_details - Information about
 * the host. ndmp_ver - NDMP version to test. Default is 4. challenge -
 * Challenge string. outfile - log file.
 *
 * Return : 0 - Success 1 - Error
 */
int
inf_connect_server_auth(ndmp_error error, host_info * host_details,
			FILE * outfile)
{
	conn_handle conn;
	char *challenge = "bad";
	ndmp_connect_open_reply *reply = NULL;
	ndmp_connect_client_auth_reply *reply_ca = NULL;
	ndmp_connect_server_auth_reply *reply_sa = NULL;

	(void) ndmp_fprintf(outfile,
		"Test case name : ndmp_connect_server_auth\n");
	(void) ndmp_fprintf(outfile,
		"Error condition : %s\n", ndmpErrorCodeToStr(error));
	client_connect_open(host_details, &conn, &reply, outfile);
	if (reply->error != NDMP_NO_ERR) {
		(void) ndmp_dprintf(outfile, "inf_connect_server_auth: "
			"Not able to open connection \n");
		print_test_result(1, outfile);
		return (1);
	}
	client_connect_authorize(host_details, &conn, &reply_ca, outfile);
	if (reply_ca->error != NDMP_NO_ERR) {
		(void) ndmp_dprintf(outfile, "inf_connect_server_auth: "
			"Not able to authorize connection \n");
		print_test_result(1, outfile);
		return (1);
	}
	if (error == NDMP_ILLEGAL_ARGS_ERR &&
		host_details->server_challenge == NULL) {
		strcpy(host_details->server_challenge, challenge);
	}
	server_connect_auth(host_details, &conn, &reply_sa, outfile);
	if (reply_sa != NULL && reply_sa->error == error) {
		print_test_result(0, outfile);
	} else {
		print_test_result(1, outfile);
	}
	close_connection(&conn, outfile);
	return (0);
}

/* ARGSUSED */
int
unit_test_connect(host_info * auth, FILE * logfile)
{
	/* Test : NDMP_NO_ERR */
	(void) ndmp_dprintf(logfile,
		"unit_test_connect: Test 1: connect_open NDMP_NO_ERR\n");
	(void) inf_connect_open(NDMP_NO_ERR, auth, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_connect: Test 2: connect_client_auth NDMP_NO_ERR\n");
	(void) inf_connect_client_auth(NDMP_NO_ERR, auth, logfile);
	(void) ndmp_dprintf(logfile,
		"unit_test_connect: Test 3: connect_server_auth NDMP_NO_ERR\n");
	(void) inf_connect_server_auth(NDMP_NO_ERR, auth, logfile);

	/* NDMP_NOT_SUPPORTED_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_connect:"
		" Test 4: connect_open NDMP_NOT_SUPPORTED_ERR\n");
	(void) inf_connect_open(NDMP_NOT_SUPPORTED_ERR, auth, logfile);
	(void) ndmp_dprintf(logfile, "unit_test_connect:"
		" Test 5: connect_server_auth NDMP_NOT_SUPPORTED_ERR\n");
	(void) inf_connect_server_auth(NDMP_NOT_SUPPORTED_ERR, auth, logfile);

	/* Test : NDMP_NOT_AUTHORIZED_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_connect:"
		" Test 6: connect_client_auth NDMP_NOT_AUTHORIZED_ERR\n");
	(void) inf_connect_client_auth(NDMP_NOT_AUTHORIZED_ERR, auth, logfile);
	(void) ndmp_dprintf(logfile, "unit_test_connect:"
		" Test 7: connect_client_auth NDMP_NOT_AUTHORIZED_ERR\n");
	(void) inf_connect_server_auth(NDMP_NOT_AUTHORIZED_ERR, auth, logfile);

	/* NDMP_ILLEGAL_ARGS_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_connect:"
		" Test 8: connect_open NDMP_ILLEGAL_ARGS_ERR\n");
	(void) inf_connect_open(NDMP_ILLEGAL_ARGS_ERR, auth, logfile);
	(void) ndmp_dprintf(logfile, "unit_test_connect:"
		" Test 9: connect_client_auth NDMP_ILLEGAL_ARGS_ERR\n");
	(void) inf_connect_client_auth(NDMP_ILLEGAL_ARGS_ERR, auth, logfile);
	(void) ndmp_dprintf(logfile, "unit_test_connect:"
		" Test 10: connect_server_auth NDMP_ILLEGAL_ARGS_ERR\n");
	(void) inf_connect_server_auth(NDMP_ILLEGAL_ARGS_ERR, auth, logfile);

	/* NDMP_ILLEGAL_STATE_ERR */
	(void) ndmp_dprintf(logfile, "unit_test_connect:"
		" Test 11: connect_open NDMP_ILLEGAL_STATE_ERR\n");
	(void) inf_connect_open(NDMP_ILLEGAL_STATE_ERR, auth, logfile);

	/* Connect Close */
	(void) ndmp_dprintf(logfile, "unit_test_connect:"
		" Test 12: connect_close\n");
	(void) inf_connect_close(auth, logfile);

	return (1);
}

#ifdef UNIT_TEST_CONNECT
int
main(int argc, char *argv[])
{
	FILE *logfile = NULL;
	host_info auth;
	auth.ipAddr = strdup("10.12.178.122");
	auth.userName = strdup("admin");
	auth.password = strdup("admin");
	auth.auth_type = NDMP_AUTH_TEXT;
	strcpy(auth.client_digest, "digest");
	auth.protocol_version = 4;
	strcpy(auth.server_challenge, "challenge");

	/* Open Log file */
	logfile = fopen("unit_test_connect.log", "w");
	(void) ndmp_dprintf(logfile, "main: start\n");

	/* unit test tape open */
	ndmp_dprintf(stdout, "File %s:%d\n", __FILE__, __LINE__);
	/* unit test connect module */
	(void) unit_test_connect(&auth, logfile);
	(void) ndmp_dprintf(stdout, "main: end\n");
	free(auth.ipAddr);
	free(auth.userName);
	free(auth.password);
	fclose(logfile);
	return (1);
}
#endif

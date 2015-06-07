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
 * Copyright 2015 Nexenta Systems, Inc. All rights reserved.
 */

#ifndef _TSET_SAMPLE_H
#define	_TSET_SAMPLE_H

/*
 * Sample function declarations
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	SHORT_TIME	10

extern 	int	TsetSampleStartup();
extern	int	TsetSampleCleanup();

extern	int	TsetSampleStartupReboot();
extern	int	TsetSampleCleanupReboot();

extern	void	PrintSpecificVariables(void);

extern	int	num_of_remote_machines;
extern	int	num_of_clients;

extern	int	management_server;
extern	int	remote_machine;
extern	int	client;

extern	int	management_server_sysno;
extern	int	*remote_machines_sysno_array;
extern	int	*clients_sysno_array;

extern	int	management_server_sysid;
extern	int	*remote_machines_sysid_array;
extern	int	*clients_sysid_array;

extern	char	*management_server_sysname;
extern	char	**remote_machines_sysname_array;
extern	char	**clients_sysname_array;

extern	int	first_remote_machine;
extern	int	second_remote_machine;
extern	int	third_remote_machine;
extern	int	fourth_remote_machine;

extern	int	first_client;
extern	int	second_client;
extern	int	third_client;
extern	int	fourth_client;

extern	int	SampleReboot(char *node_name, int timeout);
extern	int	SampleWaitForReboot(char *node_name, int timeout);

extern	int	IsManagementServer(int rem_sysno);
extern	int	IsRemoteMachine(int rem_sysno);
extern	int	IsClient(int rem_sysno);

#define	TEST_PANIC		0x00000001
#define	TEST_HANG		0x00000002
#define	TEST_FAIL		0x00000004
#define	TEST_SU			0x00000008
#define	TEST_NONSU		0x00000010

#define	TEST_MASTER		0x00000040

#define	TEST_MANAGEMENT_SERVER	0x00000080

#define	TEST_1_REMOTE_MACHINE	0x00000100
#define	TEST_2_REMOTE_MACHINE	0x00000200
#define	TEST_3_REMOTE_MACHINE	0x00000400
#define	TEST_4_REMOTE_MACHINE	0x00000800

#define	TEST_1_CLIENT		0x00001000
#define	TEST_2_CLIENT		0x00002000
#define	TEST_3_CLIENT		0x00004000
#define	TEST_4_CLIENT		0x00008000

extern int  CheckCondition(int condition);

#define	TestConditions(cond)	if (CheckCondition(cond)) { \
					return;	\
				}

#ifdef __cplusplus
}
#endif

#endif /* _TSET_SAMPLE_H */

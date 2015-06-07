#
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

#
# BSD 3 Clause License
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#       - Redistributions of source code must retain the above copyright
#         notice, this list of conditions and the following disclaimer.
#
#       - Redistributions in binary form must reproduce the above copyright
#         notice, this list of conditions and the following disclaimer in
#         the documentation and/or other materials provided with the
#         distribution.
#
#       - Neither the name of Sun Microsystems, Inc. nor the
#         names of its contributors may be used to endorse or promote products
#         derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY SUN MICROSYSTEMS, INC. "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL SUN MICROSYSTEMS, INC. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

#
# This file contains all the sub routines for the
# CONFIG interface methods. Each Method tests different
# error conditions depending on the input file
#
#
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

use strict;
use warnings;

our $log_flag = 1;
our $option = "cli";
sub config_get_auth_attr_nne {
	my $interface = "NDMP_CONFIG_GET_AUTH_ATTR";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_auth_attr_nae {
	my $interface = "NDMP_CONFIG_GET_AUTH_ATTR";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_server_info_nne {
	my $interface = "NDMP_CONFIG_GET_SERVER_INFO";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_scsi_info_nne {
	my $interface = "NDMP_CONFIG_GET_SCSI_INFO";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_scsi_info_nae {
	my $interface = "NDMP_CONFIG_GET_SCSI_INFO";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_host_info_nne {
	my $interface = "NDMP_CONFIG_GET_HOST_INFO";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_fs_info_nae {
	my $interface = "NDMP_CONFIG_GET_FS_INFO";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_ext_list_dandn {
	my $interface = "NDMP_CONFIG_GET_EXT_LIST";
	my $error = "NDMP_EXT_DANDN_ILLEGAL_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_conn_type_nne {
	my $interface = "NDMP_CONFIG_GET_CONNECTION_TYPE";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_conn_type_nae {
	my $interface = "NDMP_CONFIG_GET_CONNECTION_TYPE";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_butype_nne {
	my $interface = "NDMP_CONFIG_GET_BUTYPE_INFO";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_butype_nae {
	my $interface = "NDMP_CONFIG_GET_BUTYPE_INFO";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}

sub config_get_tape_info_nne {
	my $interface = "NDMP_CONFIG_GET_TAPE_INFO";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub config_get_tape_info_nae {
	my $interface = "NDMP_CONFIG_GET_TAPE_INFO";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
1;


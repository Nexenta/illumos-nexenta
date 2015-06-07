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
# CONNECT interface methods. Each Method tests different
# error conditions depending on the input file
#
#
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

use strict;
use warnings;

our $log_flag = 1;
our $option = "cli";
sub connect_open_nne {
	my $interface = "NDMP_CONNECT_OPEN";
	my $error = "NDMP_NO_ERR";
	my $version = "4";
	my %args = ('option',$option,'inf',$interface,'err',$error,'ndmp_ver',$version);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_open_iae {
	my $interface = "NDMP_CONNECT_OPEN";
	my $error = "NDMP_ILLEGAL_ARGS_ERR";
	my $version = "5";
	my %args = ('option',$option,'inf',$interface,'err',$error,'ndmp_ver',$version);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_open_ise {
	my $interface = "NDMP_CONNECT_OPEN";
	my $error = "NDMP_ILLEGAL_STATE_ERR";
	my $version = "4";
	my %args = ('option',$option,'inf',$interface,'err',$error,'ndmp_ver',$version);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_open_nse {
	my $interface = "NDMP_CONNECT_OPEN";
	my $error = "NDMP_NOT_SUPPORTED_ERR";
	my $version = "4";
	my %args = ('option',$option,'inf',$interface,'err',$error,'ndmp_ver',$version);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_client_auth_nne {
	my $interface = "NDMP_CONNECT_CLIENT_AUTH";
	my $error = "NDMP_NO_ERR";
	my $auth_type = "NDMP_AUTH_TEXT";
	my %args = ('option',$option,'inf',$interface,'err',$error,'auth_type',$auth_type);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_client_auth_nae {
	my $interface = "NDMP_CONNECT_CLIENT_AUTH";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my $auth_type = "NDMP_AUTH_TEXT";
	my %args = ('option',$option,'inf',$interface,'err',$error,'auth_type',$auth_type);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_client_auth_nse {
	my $interface = "NDMP_CONNECT_CLIENT_AUTH";
	my $error = "NDMP_NOT_SUPPORTED_ERR";
	my $auth_type = "NDMP_AUTH_NONE";
	my %args = ('option',$option,'inf',$interface,'err',$error,'auth_type',$auth_type);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_client_auth_iae {
	my $interface = "NDMP_CONNECT_CLIENT_AUTH";
	my $error = "NDMP_ILLEGAL_ARGS_ERR";
	my $auth_type = "NDMP_AUTH_NONE";
	my %args = ('option',$option,'inf',$interface,'err',$error,'auth_type',$auth_type);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_close_nne {
	my $interface = "NDMP_CONNECT_CLOSE";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_server_auth_nne {
	my $interface = "NDMP_CONNECT_SERVER_AUTH";
	my $error = "NDMP_NO_ERR";
	my $auth_type = "NDMP_AUTH_TEXT";
	my %args = ('option',$option,'inf',$interface,'err',$error,'auth_type',$auth_type);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_server_auth_nae {
	my $interface = "NDMP_CONNECT_SERVER_AUTH";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my $auth_type = "NDMP_AUTH_TEXT";
	my %args = ('option',$option,'inf',$interface,'err',$error,'auth_type',$auth_type);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub connect_server_auth_iae {
	my $interface = "NDMP_CONNECT_SERVER_AUTH";
	my $error = "NDMP_ILLEGAL_ARGS_ERR";
	my $auth_type = "NDMP_AUTH_NONE";
	my %args = ('option',$option,'inf',$interface,'err',$error,'auth_type',$auth_type);
	ndmp_execute::ndmp_execute_cli(\%args);
}
1;


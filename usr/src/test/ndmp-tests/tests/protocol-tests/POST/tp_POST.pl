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
# POST interface methods. Each Method tests different
# error conditions depending on the input file
#
#
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

use strict;
use warnings;

our $log_flag = 1;
our $fs_name = $ENV{'NDMP_FS'};
our $option = "cli";
 
sub ndmp_fh_add_dir {
	my $interface = "NDMP_FH_ADD_DIR";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub ndmp_fh_add_file {
	my $interface = "NDMP_FH_ADD_FILE";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub ndmp_fh_add_node {
    	my $interface = "NDMP_FH_ADD_NODE";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub ndmp_recovery_failed_not_found {
	my $interface = "NDMP_LOG_FILE";
	my $sub_msg = "NDMP_RECOVERY_FAILED_NOT_FOUND";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub ndmp_recovery_failed_no_directory {
    	my $interface = "NDMP_LOG_FILE";
	my $sub_msg = "NDMP_RECOVERY_FAILED_NO_DIRECTORY";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub ndmp_recovery_failed_permission {
	my $interface = "NDMP_LOG_FILE";
	my $sub_msg = "NDMP_RECOVERY_FAILED_PERMISSION";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub ndmp_recovery_successful {
    	my $interface = "NDMP_LOG_FILE";
	my $sub_msg = "NDMP_RECOVERY_SUCCESSFUL";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub ndmp_log_message_ndmp_log_error {
	my $interface = "NDMP_LOG_MESSAGE";
	my $sub_msg = "NDMP_LOG_ERROR";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub ndmp_log_message_ndmp_log_normal {
    	my $interface = "NDMP_LOG_MESSAGE";
	my $sub_msg = "NDMP_LOG_NORMAL";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub notify_connection_status_ndmp_connected {
	my $interface = "NDMP_NOTIFY_CONNECTION_STATUS";
	my $sub_msg = "NDMP_CONNECTED";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub notify_connection_status_ndmp_shutdown {
    	my $interface = "NDMP_NOTIFY_CONNECTION_STATUS";
	my $sub_msg = "NDMP_SHUTDOWN";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub notify_data_halt_successful {
	my $interface = "NDMP_NOTIFY_DATA_HALTED";
	my $sub_msg = "NDMP_DATA_HALT_SUCCESSFUL";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub notify_mover_halt_aborted {
	my $interface = "NDMP_NOTIFY_MOVER_HALTED";
	my $sub_msg = "NDMP_MOVER_HALT_ABORTED";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub notify_mover_halt_connection_closed {
	my $interface = "NDMP_NOTIFY_MOVER_HALTED";
	my $sub_msg = "NDMP_MOVER_HALT_CONNECT_CLOSED";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub notify_mover_pause_eow {
	my $interface = "NDMP_NOTIFY_MOVER_PAUSED";
	my $sub_msg = "NDMP_MOVER_PAUSE_EOW";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'sub_msg',$sub_msg);
	ndmp_execute::ndmp_execute_cli(\%args);
}
1;

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
# DATA interface methods. Each Method tests different
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

sub data_abort_ise {
        my $interface = "data_abort";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_abort_nne {
        my $interface = "data_abort";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_abort_nae {
        my $interface = "data_abort";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_connect_ise {
        my $interface = "data_connect";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_connect_nne {
        my $interface = "data_connect";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
        $args{ 'err' } = "";
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_connect_nae {
        my $interface = "data_connect";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}

sub data_connect_iae {
        my $interface = "data_connect";
        my $error = "NDMP_ILLEGAL_ARGS_ERR";
	my $addr_type = "NDMP_ADDR_IPC";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'addr_type',$addr_type);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub data_get_env_ise {
        my $interface = "data_get_env";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_get_env_nae {
        my $interface = "data_get_env";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_get_env_nne {
        my $interface = "data_get_env";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_get_state_nae {
        my $interface = "data_get_state";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_get_state_nne {
        my $interface = "data_get_state";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_start_backup_ise {
        my $interface = "data_start_backup";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_start_backup_nne {
        my $interface = "data_start_backup";
        my $error = "NDMP_NO_ERR";
	my @butype = ("tar","dump");
	my $backup_type = "tar";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'backup_type',$backup_type);
	foreach $backup_type (@butype) {
		$args{'backup_type'} = $backup_type;
        	ndmp_execute::ndmp_execute_cli(\%args);
	}
}
sub data_start_backup_iae {
        my $interface = "data_start_backup";
        my $error = "NDMP_ILLEGAL_ARGS_ERR";
	my $backup_type = "cpio";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'backup_type',$backup_type);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_start_backup_nae {
        my $interface = "data_start_backup";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_start_recover_ise {
        my $interface = "data_start_recover";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_start_recover_nne {
        my $interface = "data_start_recover";
        my $error = "NDMP_NO_ERR";
	my @butype = ("tar","dump");
	my $backup_type = "tar";
	my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'backup_type',$backup_type);
	foreach $backup_type (@butype) {
		$args{'backup_type'} = $backup_type;
		ndmp_execute::ndmp_execute_cli(\%args);
	}
}
sub data_start_recover_nae {
        my $interface = "data_start_recover";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_start_recover_iae {
        my $interface = "data_start_recover";
        my $error = "NDMP_ILLEGAL_ARGS_ERR";
	my $backup_type = "cpio";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'backup_type',$backup_type);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_start_recover_filehist_nse {
        my $interface = "data_start_recover_filehist";
        my $error = "NDMP_NOT_SUPPORTED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_stop_ise {
        my $interface = "data_stop";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_stop_nne {
        my $interface = "data_stop";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_stop_nae {
        my $interface = "data_stop";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_listen_iae {
        my $interface = "data_listen";
        my $error = "NDMP_ILLEGAL_ARGS_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_listen_ise {
        my $interface = "data_listen";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub data_listen_nne {
        my $interface = "data_listen";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}

1;

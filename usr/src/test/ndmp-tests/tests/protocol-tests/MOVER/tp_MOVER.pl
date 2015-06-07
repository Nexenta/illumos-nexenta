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
# MOVER interface methods. Each Method tests different
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

sub mover_abort_ise {
        my $interface = "mover_abort";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}

sub mover_abort_nae {
        my $interface = "mover_abort";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_abort_nne {
        my $interface = "mover_abort";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_close_nne {
        my $interface = "mover_close";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_close_nae {
        my $interface = "mover_close";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_close_ise {
        my $interface = "mover_close";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_connect_ce {
        my $interface = "mover_connect";
        my $error = "NDMP_CONNECT_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_connect_dnoe {
        my $interface = "mover_connect";
        my $error = "NDMP_DEVICE_NOT_OPEN_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_connect_ise {
        my $interface = "mover_connect";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_connect_nae {
        my $interface = "mover_connect";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_connect_nne {
        my $interface = "mover_connect";
        my $error = "NDMP_NO_ERR";
	my @conn_type = ("NDMP_ADDR_LOCAL","NDMP_ADDR_TCP");
	my $conn = "NDMP_ADDR_LOCAL";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'addr_type',$conn);
	foreach $conn (@conn_type) {
	    $args{'addr_type'} = $conn;
	    ndmp_execute::ndmp_execute_cli(\%args);
	}
}
sub mover_connect_pe {
        my $interface = "mover_connect";
        my $error = "NDMP_PERMISSION_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_continue_nne {
        my $interface = "mover_continue";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_continue_ise {
        my $interface = "mover_continue";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}

sub mover_continue_nae {
        my $interface = "mover_continue";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_continue_pe {
        my $interface = "mover_continue";
        my $error = "NDMP_PRECONDITION_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_get_state_nae {
        my $interface = "mover_get_state";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_get_state_nne {
        my $interface = "mover_get_state";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_listen_dnoe {
        my $interface = "mover_listen";
        my $error = "NDMP_DEV_NOT_OPEN_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_listen_iae {
        my $interface = "mover_listen";
        my $error = "NDMP_ILLEGAL_ARGS_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_listen_ise {
        my $interface = "mover_listen";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_listen_nae {
        my $interface = "mover_listen";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_listen_nne {
        my $interface = "mover_listen";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_listen_pe {
        my $interface = "mover_listen";
        my $error = "NDMP_PERMISSION_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_read_iae {
        my $interface = "mover_read";
        my $error = "NDMP_ILLEGAL_ARGS_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_read_ise {
        my $interface = "mover_read";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_read_nae {
        my $interface = "mover_read";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_read_nne {
        my $interface = "mover_read";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_read_rip {
        my $interface = "mover_read";
        my $error = "NDMP_READ_IN_PROGRESS_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_set_record_size_iae {
        my $interface = "mover_set_record_size";
        my $error = "NDMP_ILLEGAL_ARGS_ERR";
	my $record_size = 0;
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'rec_size',$record_size);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_set_record_size_ise {
        my $interface = "mover_set_record_size";
	my $record_size = 8192;
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'rec_size',$record_size);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_set_record_size_nae {
        my $interface = "mover_set_record_size";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my $record_size = 8192;
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'rec_size',$record_size);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_set_record_size_nne {
        my $interface = "mover_set_record_size";
        my $error = "NDMP_NO_ERR";
	my @rec_sizes = (1,8192,4294967294,4294967295);
	my $record_size=1;
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'rec_size',$record_size);
	foreach my $rec_size (@rec_sizes) {
	    $args{'rec_size'} = $rec_size;
	    ndmp_execute::ndmp_execute_cli(\%args);
	}
}
sub mover_set_window_size_iae {
        my $interface = "mover_set_window_size";
        my $error = "NDMP_ILLEGAL_ARGS_ERR";
	my $win_size = 0;
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'win_size',$win_size);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_set_window_size_ise {
        my $interface = "mover_set_window_size";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
	 my $win_size = 8192;
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'win_size',$win_size);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_set_window_size_nae {
        my $interface = "mover_set_window_size";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my $win_size = 8192;
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'win_size',$win_size);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_set_window_size_nne {
        my $interface = "mover_set_window_size";
        my $error = "NDMP_NO_ERR";
	my @win_sizes = (1,8192,4294967294,4294967295);
	my $win_size = 1;
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'win_size',$win_size);
	foreach my $window (@win_sizes) {
	    $args{'win_size'} = $window;
	    ndmp_execute::ndmp_execute_cli(\%args);
	}
}
sub mover_set_window_size_pce {
        my $interface = "mover_set_window_size";
        my $error = "NDMP_PRECONDITION_ERR";
	my $win_size = 8192;
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error,'win_size',$win_size);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_stop_ise {
        my $interface = "mover_stop";
        my $error = "NDMP_ILLEGAL_STATE_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);

}
sub mover_stop_nae {
        my $interface = "mover_stop";
        my $error = "NDMP_NOT_AUTHORIZED_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
sub mover_stop_nne {
        my $interface = "mover_stop";
        my $error = "NDMP_NO_ERR";
        my %args = ('fs',$fs_name,'option',$option,'inf',$interface,'err',$error);
        ndmp_execute::ndmp_execute_cli(\%args);
}
1;

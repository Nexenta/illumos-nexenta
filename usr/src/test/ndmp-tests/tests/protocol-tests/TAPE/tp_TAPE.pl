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
# TAPE interface methods. Each Method tests different
# error conditions depending on the input file
#
#
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

use strict;
use warnings;

our $log_flag = 1;
our $option = "cli";
sub tape_close_dnoe {
	my $interface = "tape_close";
	my $error = "NDMP_DEVICE_NOT_OPEN_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_close_nae {
	my $interface = "tape_close";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_close_nne {
	my $interface = "tape_close";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_exec_dnoe {
	my $interface = "tape_execute_cdb";
	my $error = "NDMP_DEVICE_NOT_OPEN_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_exec_nae {
	my $interface = "tape_execute_cdb";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_exec_nne {
	my $interface = "tape_execute_cdb";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_getstate_dnoe {
	my $interface = "tape_get_state";
	my $error = "NDMP_DEVICE_NOT_OPEN_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_getstate_nne {
	my $interface = "tape_get_state";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_mtio_dnoe {
	my $interface = "tape_mtio";
	my $error = "NDMP_DEVICE_NOT_OPEN_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_mtio_iae {
	my $interface = "tape_mtio";
	my $error = "NDMP_ILLEGAL_ARGS_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_mtio_nae {
	my $interface = "tape_mtio";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_mtio_nne {
	my $interface = "tape_mtio";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_open_doe {
	my $interface = "tape_open";
	my $error = "NDMP_DEVICE_OPENED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_open_nae {
	my $interface = "tape_open";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_open_nde {
	my $interface = "tape_open";
	my $error = "NDMP_NO_DEVICE_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_open_nne {
	my $interface = "tape_open";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_open_nte {
	my $interface = "tape_open";
	my $error = "NDMP_NO_TAPE_LOADED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_open_wpe {
	my $interface = "tape_open";
	my $error = "NDMP_WRITE_PROTECT_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_read_dnoe {
	my $interface = "tape_read";
	my $error = "NDMP_DEV_NOT_OPEN_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_read_nae {
	my $interface = "tape_read";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_read_nne {
	my $interface = "tape_read";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_write_dnoe {
	my $interface = "tape_write";
	my $error = "NDMP_DEV_NOT_OPEN_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_write_nae {
	my $interface = "tape_write";
	my $error = "NDMP_NOT_AUTHORIZED_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
sub tape_write_nne {
	my $interface = "tape_read";
	my $error = "NDMP_NO_ERR";
	my %args = ('option',$option,'inf',$interface,'err',$error);
	ndmp_execute::ndmp_execute_cli(\%args);
}
1;

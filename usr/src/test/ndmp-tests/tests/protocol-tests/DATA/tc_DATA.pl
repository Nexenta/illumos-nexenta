#! /usr/perl5/bin/perl
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
# This is DATA interface test case file. This file invokes the different 
# NDMP DATA interface tests.
#
#
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

use strict;
use warnings;

our @iclist=("ic1","ic2","ic3","ic4","ic5","ic6","ic7","ic8","ic9","ic10","ic11","ic12","ic13","ic14","ic15","ic16","ic17",\
		"ic18","ic19","ic20","ic21","ic22","ic23","ic24","ic25","ic26","ic27");

our @ic1	=("data_abort_nne");
our @ic2	=("data_abort_nae");
our @ic3	=("data_abort_ise");
our @ic4	=("data_connect_ise");
our @ic5	=("data_connect_nne");
our @ic6	=("data_connect_nae");
our @ic7	=("data_connect_iae");
our @ic8	=("data_get_env_ise");
our @ic9	=("data_get_env_nae");
our @ic10	=("data_get_env_nne");
our @ic11	=("data_get_state_nae");
our @ic12	=("data_get_state_nne");
our @ic13	=("data_start_backup_iae");
our @ic14	=("data_start_backup_ise");
our @ic15	=("data_start_backup_nae");
our @ic16	=("data_start_backup_nne");
our @ic17	=("data_start_recover_iae");
our @ic18	=("data_start_recover_ise");
our @ic19	=("data_start_recover_nae");
our @ic20	=("data_start_recover_nne");
our @ic21	=("data_start_recover_filehist_nse");
our @ic22	=("data_stop_ise");
our @ic23	=("data_stop_nae");
our @ic24	=("data_stop_nne");
our @ic25	=("data_listen_iae");
our @ic26	=("data_listen_ise");
our @ic27	=("data_listen_nne");



sub startup() {
	&tet'infoline("This is the startup");
}

sub cleanup() {
	&tet'infoline("This is the cleanup");
}

require "tp_DATA";

require "$ENV{\"CTI_SUITE\"}/lib/ndmp_execute";
require "$ENV{\"CTI_ROOT\"}/lib/ctiutils.pl";
require "$ENV{\"CTI_ROOT\"}/lib/ctilib.pl";
1;

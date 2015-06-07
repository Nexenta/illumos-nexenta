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
# This is MOVER interface test case file. This file invokes the different 
# NDMP MOVER interface tests.
#
#
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

use strict;
use warnings;

our @iclist=("ic1","ic2","ic3","ic4","ic5","ic6","ic7","ic8","ic9","ic10","ic11","ic12","ic13","ic14","ic15","ic16","ic17",
		"ic18","ic19","ic20","ic21","ic22","ic23","ic24","ic25","ic26","ic27","ic28","ic29","ic30","ic31","ic32",
		"ic33","ic34","ic35","ic36","ic37","ic38","ic39","ic40","ic41");

our @ic1	=("mover_abort_ise");
our @ic2	=("mover_abort_nae");
our @ic3	=("mover_abort_nne");
our @ic4	=("mover_close_nne");
our @ic5        =("mover_close_nae");
our @ic6        =("mover_close_ise");
our @ic7	=("mover_connect_ce");
our @ic8	=("mover_connect_dnoe");
our @ic9	=("mover_connect_ise");
our @ic10	=("mover_connect_nae");
our @ic11	=("mover_connect_nne");
our @ic12	=("mover_connect_pe");
our @ic13	=("mover_continue_nne");
our @ic14       =("mover_continue_ise");
our @ic15       =("mover_continue_nae");
our @ic16       =("mover_continue_pe");
our @ic17	=("mover_get_state_nae");
our @ic18	=("mover_get_state_nne");
our @ic19	=("mover_listen_dnoe");
our @ic20	=("mover_listen_iae");
our @ic21	=("mover_listen_ise");
our @ic22	=("mover_listen_nae");
our @ic23	=("mover_listen_nne");
our @ic24	=("mover_listen_pe");
our @ic25	=("mover_read_iae");
our @ic26	=("mover_read_ise");
our @ic27	=("mover_read_nae");
our @ic28	=("mover_read_nne");
our @ic29	=("mover_read_rip");
our @ic30	=("mover_set_record_size_iae");
our @ic31	=("mover_set_record_size_ise");
our @ic32	=("mover_set_record_size_nae");
our @ic33	=("mover_set_record_size_nne");
our @ic34	=("mover_set_window_size_iae");
our @ic35	=("mover_set_window_size_ise");
our @ic36	=("mover_set_window_size_nae");
our @ic37	=("mover_set_window_size_nne");
our @ic38	=("mover_set_window_size_pce");
our @ic39	=("mover_stop_ise");
our @ic40	=("mover_stop_nae");
our @ic41	=("mover_stop_nne");



sub startup() {
	&tet'infoline("This is the startup");
}

sub cleanup() {
	&tet'infoline("This is the cleanup");
}

require "tp_MOVER";

require "$ENV{\"CTI_SUITE\"}/lib/ndmp_execute";
require "$ENV{\"CTI_ROOT\"}/lib/ctiutils.pl";
require "$ENV{\"CTI_ROOT\"}/lib/ctilib.pl";
1;

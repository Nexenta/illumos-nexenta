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
# This is TAPE interface test case file. This file invokes the different 
# NDMP TAPE interface tests.
#
#
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

use strict;
use warnings;

our @iclist=("ic1","ic2","ic3","ic4","ic5","ic6","ic7","ic8","ic9","ic10","ic11","ic12","ic13","ic14","ic15","ic16","ic17",\
	     "ic18","ic19","ic20","ic21","ic22","ic23","ic24");

our @ic1	=("tape_close_dnoe");
our @ic2	=("tape_close_nae");
our @ic3	=("tape_close_nne");
our @ic4	=("tape_exec_dnoe");
our @ic5	=("tape_exec_nae");
our @ic6	=("tape_exec_nne");
our @ic7	=("tape_getstate_dnoe");
our @ic8	=("tape_getstate_nne");
our @ic9	=("tape_mtio_dnoe");
our @ic10	=("tape_mtio_iae");
our @ic11	=("tape_mtio_nae");
our @ic12	=("tape_mtio_nne");
our @ic13	=("tape_open_doe");
our @ic14	=("tape_open_nae");
our @ic15	=("tape_open_nde");
our @ic16	=("tape_open_nne");
our @ic17	=("tape_open_nte");
our @ic18	=("tape_open_wpe");
our @ic19	=("tape_read_dnoe");
our @ic20	=("tape_read_nae");
our @ic21	=("tape_read_nne");
our @ic22	=("tape_write_dnoe");
our @ic23	=("tape_write_nae");
our @ic24	=("tape_write_nne");

sub startup() {
	&tet'infoline("This is the startup");
}

sub cleanup() {
	&tet'infoline("This is the cleanup");
}

require "tp_TAPE";

require "$ENV{\"CTI_SUITE\"}/lib/ndmp_execute";
require "$ENV{\"CTI_ROOT\"}/lib/ctiutils.pl";
require "$ENV{\"CTI_ROOT\"}/lib/ctilib.pl";
1;

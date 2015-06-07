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
# This is SCSI interface test case file. This file invokes the different 
# NDMP SCSI interface tests.
#
#
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

use strict;
use warnings;

our @iclist=("ic1","ic2","ic3","ic4","ic5","ic6","ic7","ic8","ic9","ic10","ic11","ic12","ic13","ic14","ic15","ic16","ic17");

our @ic1=("scsi_close_dnoe");
our @ic2=("scsi_close_nae");
our @ic3=("scsi_close_nne");
our @ic4=("scsi_exec_dnoe");
our @ic5=("scsi_exec_nae");
our @ic6=("scsi_exec_nne");
our @ic7=("scsi_exec_iae");
our @ic8=("scsi_get_state_dnoe");
our @ic9=("scsi_get_state_nae");
our @ic10=("scsi_get_state_nne");
our @ic11=("scsi_open_doe");
our @ic12=("scsi_open_nae");
our @ic13=("scsi_open_nne");
our @ic14=("scsi_open_nde");
our @ic15=("scsi_reset_device_dnoe");
our @ic16=("scsi_reset_device_nae");
our @ic17=("scsi_reset_device_nne");

sub startup() {
	&tet'infoline("This is the startup");
}

sub cleanup() {
	&tet'infoline("This is the cleanup");
}

require "tp_SCSI";

require "$ENV{\"CTI_SUITE\"}/lib/ndmp_execute";
require "$ENV{\"CTI_ROOT\"}/lib/ctiutils.pl";
require "$ENV{\"CTI_ROOT\"}/lib/ctilib.pl";
1;

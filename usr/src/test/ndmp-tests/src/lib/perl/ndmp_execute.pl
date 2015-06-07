#! /usr/perl5/bin/perl
#
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
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
# This is the file used for the invoking of the ndmp_proto_test binary with proper
# scenario file. This has got method to invoke the ndmp_proto_test with various
# parameters. Later once we migrate to new version of NDMP proto test suite this
# level execution will be taken out
#
#
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

use strict;
use warnings;

package ndmp_execute;
require	Exporter;
our	@ISA=qw(Exporter);
our	@EXPORT=qw(ndmp_execute);

#
# This is the main method which will invoke the ndmp_proto_test
# This method can also be called by just invoking ndmp_execute() method
# with the correct parameters
# Parameters are : 1st Parameter-- Input file Name
# 		   2nd Parameter -- Whether you wanno creat the log file (1-To create new log, 0 - To use existing log)
# For Eg: my $res = ndmp_execute::ndmp_execute("$ENV{\"TET_SUITE_ROOT\"}/ndmp/data/tape/tape_open_NNE.in",1);
# 	  printf "Result got from the execution is ---> $res \n";
#


sub ndmp_execute
{
	my ($handle,$create_log) = @_;
	my $log = ("/var/tmp/tmp_log");


	my $master_log = get_recent_log();

	my ($NDMP_SERVER_IP,$NDMP_USER,$NDMP_PASSWORD,$NDMP_TAPE_DEV,$NDMP_ROBOT,$NDMP_AUTH) =
		($ENV{'NDMP_SERVER_IP'},$ENV{'NDMP_USER'},$ENV{'NDMP_PASSWORD'},$ENV{'NDMP_TAPE_DEV'},$ENV{'NDMP_ROBOT'},$ENV{'NDMP_AUTH'});


	if ( ($create_log) || ($master_log =~ /""/) ) {
		$master_log = log_file();
	}

	my $ndmp_binary = ("$ENV{\"CTI_SUITE\"}/bin/ndmp_proto_test");
	my $file_path=$handle;


	if ($file_path =~ /.*NAE.*/i) {
		$NDMP_USER = "amin";
	}


	input_dev_file($file_path,$NDMP_TAPE_DEV,$NDMP_ROBOT);

	if ($file_path =~ /.*tape_open_NDE.*/i) {
		tape_no_dev($file_path);
	}

	#sleep(5);

	if (($file_path =~ /.*(ndmp_log_file).*/i) ||
		($file_path =~ /.*(ndmp_log_message).*/i) ||
		($file_path =~ /.*(ndmp_notify).*/i) ||
		($file_path =~ /.*(ndmp_fh_.*)/i)) {

		my $int_name = $1;
		my $temp_file = $file_path;
		$temp_file =~ /.*($int_name.*)/i;
		my @args = split(/\./,$1);
		my $arg1 = uc($args[0]);
		my $arg2 = uc($args[1]);
		my $res = system("$ndmp_binary $NDMP_SERVER_IP $NDMP_USER $NDMP_PASSWORD $NDMP_AUTH $file_path $log $arg1 $arg2 -r 1");
		my $pwd = `pwd`;
		chomp($pwd);
		my $post_log = $pwd."/PostMessage.log";
		test_case_name($file_path,$master_log);
		if (post_message($post_log)) {
			write_to_master_log($post_log,$master_log);
			&cti'fail("protocol test failed");
			return;
		}
		else{
			write_to_master_log($post_log,$master_log);
			&cti'pass("protocol tested successfully");
			return;
		}

	} else {
		test_case_name($file_path,$master_log);
		if ( ($file_path =~ /.*mover_continue_NNE.*/i) ||
		($file_path =~ /.*mover_close_NNE.*/i) ||
		($file_path =~ /.*data_start_recover_NNE.*/i) ||
		($file_path =~ /.*data_abort_NNE.*/i) ||
		($file_path =~ /.*data_start_backup_NNE.*/i) ||
		($file_path =~ /.*data_get_env_NNE.*/i) ) {

			if ($file_path =~ /.*data_start_recover_NNE.*/i) {
				my $res= system("$ndmp_binary $NDMP_SERVER_IP $NDMP_USER $NDMP_PASSWORD $NDMP_AUTH $file_path $log NDMP_DATA_START_RECOVER -r 1");
			} else {
				my $res= system("$ndmp_binary $NDMP_SERVER_IP $NDMP_USER $NDMP_PASSWORD $NDMP_AUTH $file_path $log NDMP_DATA_START_BACKUP -r 1");
			}

		} else {
			my $res= system("$ndmp_binary $NDMP_SERVER_IP $NDMP_USER $NDMP_PASSWORD $NDMP_AUTH $file_path $log -r 1");
		}

	}

	if (parse_log($log, $file_path)) {
		write_to_master_log($log,$master_log);
		&cti'fail("protocol test failed");
	} else {
		write_to_master_log($log,$master_log);
		&cti'pass("protocol tested successfully");
	}
}

#
# Following function will retrun the environment variables read
#
#	NDMP_SERVER_IP
#	NDMP_USER
#	NDMP_PASSWORD
#	NDMP_TAPE_DEV
#	NDMP_ROBOT
#

sub get_env
{
	my @env;
	foreach (sort keys %ENV) {
        	if ($_ =~ /NDMP_SERVER_IP/){
                	push @env,"$ENV{$_}";
        	}
        	if ($_ =~ /NDMP_USER/){
                	push @env,"$ENV{$_}";
        	}

        	if ($_ =~ /NDMP_PASSWORD/){
                	push @env,"$ENV{$_}";
        	}

        	if ($_ =~ /NDMP_TAPE_DEV/){
        		push @env,"$ENV{$_}";
		}
        	if ($_ =~ /NDMP_ROBOT/){
                	push @env,"$ENV{$_}";
        	}
        	if ($_ =~ /NDMP_PORT/){
        		push @env,"$ENV{$_}";
		}
        	if ($_ =~ /NDMP_AUTH/){
        		push @env,"$ENV{$_}";
		}
	}
	return (@env);
}

#
# This Function gets the recent log created in the path "/var/tmp/tests"
# This is required for the creation of different log files for each iteration
#

sub get_recent_log
{
	my $log_path = "/var/tmp/tests/";
	my @file_list = `ls -t $log_path`;
	if ((scalar @file_list) != 0) {
		$log_path = $log_path.$file_list[0];
		return ($log_path);
	} else {
		return("");
	}
}

#
# This Function writes the log to the master log file
# And also it writes log to the Journal file using
# CTI::reportfile interface
#

sub write_to_master_log
{
	my ($temp_log, $master_log2) = @_;
	#
	#Following Line Prints the Log messages to the Journal file from the temporary log
	#Starts Here
	#

	&cti'reportfile ($temp_log,"Detailed log");

	#
	#Ends Here
	#

	open TMP, "< $temp_log" or die "Can't open $temp_log : $!";
	open MASTER, "+>> $master_log2" or die "Can't open $master_log2 : $!";
	my $line;
	while (<TMP>) {
		$line = $_;
		print MASTER "$line";
		#print "$line";
	}
	close(TMP);
	close(MASTER);
	`rm -rf $temp_log`;
}

#
# This Function does the sanity on the NDMP server
# It checks for the tape device and rewinds the tape before
# starting any tests
#

sub sanity
{
	my $command_name = ("$ENV{\"CTI_SUITE\"}/bin/ndmp_proto_test");
	my $tape_open  = ("$ENV{\"CTI_SUITE\"}/data/tape/tape_open_NNE.in");
	my $tape_rew = ("$ENV{\"CTI_SUITE\"}/data/tape/tape_rew.in");
	my $tmp_file  = ("$ENV{\"CTI_SUITE\"}/bin/shen");
	my ($NDMP_SERVER_IP,$NDMP_USER,$NDMP_PASSWORD,$NDMP_AUTH,$NDMP_TAPE_DEV,$NDMP_ROBOT) =
		($ENV{'NDMP_SERVER_IP'},$ENV{'NDMP_USER'},$ENV{'NDMP_PASSWORD'},$ENV{'NDMP_AUTH'},$ENV{'NDMP_TAPE_DEV'},$ENV{'NDMP_ROBOT'});
	input_dev_file($tape_open,$NDMP_TAPE_DEV,$NDMP_ROBOT);
	system ("$command_name $NDMP_SERVER_IP $NDMP_USER $NDMP_PASSWORD $NDMP_AUTH $tape_open $tmp_file -r 1");
	open IN, "< $tmp_file" or die "Can't open $tmp_file : $!";
	my @lines=<IN>;
	foreach my $lin(@lines) {
		chomp($lin);
		if ($lin =~ /.*NDMP_NO_DEVICE_ERR.*/i) {
			print "Recieved NDMP_NO_DEVICE_ERR from the NDMP Server\n";
			print "Exiting the program\n";
			close(IN);
			my $ss=`rm -f $tmp_file`;
			exit(101);
		}

	}
	my $ss=`rm -f $tmp_file`;
	input_dev_file($tape_rew,$NDMP_TAPE_DEV,$NDMP_ROBOT);
	system ("$command_name $NDMP_SERVER_IP $NDMP_USER $NDMP_PASSWORD $NDMP_AUTH $tape_rew $tmp_file -r 1");
	open IN, "< $tmp_file" or die "Can't open $tmp_file : $!";
	my @lines_new=<IN>;
	my $flag = 0;
	foreach my $lin(@lines_new) {
		chomp($lin);
		if ($lin =~ /.*NDMP_NO_ERR.*/i) {
			$flag = 1;
		}

	}
	close(IN);
	if (!$flag) {
		print "Exiting the program as the tape rewind did n't succeed\n";
		exit(101);
	}

	#
	#Opening the Confile to create the confile_NAE
	# Starts Here

	#
	#Ends Here
	#

	my $result_dir = `mkdir -p /var/tmp/tests`;

}

#
# This function does substitution of the wrong tape
# device name in the input file as it is required to
# generate NDMP_NO_DEVICE_ERR
#


sub tape_no_dev
{
	my ($file_name) = @_;
	my $invalid_dev = "/dev/rmt/n";
	#
	#Opening the input file to add the device file name
	#Starts Here

	open OUT, "+< $file_name" or die "Can't open $file_name : $!";
	my @file;
	while(<OUT>) {
		$_ =~ s/\/dev.*/$invalid_dev/i;
		push @file,"$_";
	}
	close(OUT);

	open OUT, "+< $file_name" or die "Can't open $file_name : $!";
	foreach my $line(@file) {
		 print OUT "$line";
	}
	close(OUT);

	#
	#Ends Here
	#
}

#
# log_file() creates the log file in the /var/tmp/tests path
# Log file name is generated on the localtime
#

sub log_file
{
	my $result_dir = `mkdir -p /var/tmp/tests`;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,
	$yday,$isdst)=localtime(time);
	$year=$year+1900;
	$mon=$mon+1;
	my $log_file= ("/var/tmp/tests/log$year$mon$mday-$hour$min$sec.out");
	return ($log_file);
}

#
# Following function prints the Test case Name to the log file
# This is based upon the short names used in the input files
#

sub test_case_name
{
	my ($file_name,$log) = @_;
	open LOG,"+>> $log" or die "Can't open $log : $!";
	print LOG "\n=====================================================\n";
	if ($file_name =~ /.*data\/.*\/(.*)_NNE.*/i) {
	    	cti'report("Test Name  : ndmp_$1, Case : NDMP_NO_ERR\n");
		print LOG "Test Name  : ndmp_$1, Case : NDMP_NO_ERR\n";
	}

	if ($file_name=~ /.*data\/.*\/(.*)_NAE.*/i) {
		cti'report("Test Name  : ndmp_$1, Case :NDMP_NOT_AUTHORIZED_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case : NDMP_NOT_AUTHORIZED_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_IAE.*/i) {
	    	cti'report("Test Name  : ndmp_$1, Case :NDMP_ILLEGAL_ARGS\n");
		print LOG "Test Name  :ndmp_$1,  Case : NDMP_ILLEGAL_ARGS\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_DOE.*/i) {
		cti'report("Test Name  : ndmp_$1, Case :NDMP_DEVICE_OPEN_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_DEVICE_OPEN_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_DNOE.*/i) {
		cti'report("Test Name  : ndmp_$1, Case :NDMP_DEVICE_NOT_OPEN_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_DEVICE_NOT_OPEN_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_NIE.*/i) {
		cti'report("Test Name  : ndmp_$1, Case :NDMP_IO_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_IO_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_WPE.*/i) {
	    	cti'report("Test Name  : ndmp_$1, Case :NDMP_WRITE_PROTECT_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_WRITE_PROTECT_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_ISE.*/i) {
		cti'report("Test Name  : ndmp_$1, Case :NDMP_ILLEGAL_STATE_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_ILLEGAL_STATE_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_CE.*/i) {
	    	cti'report("Test Name  : ndmp_$1, Case :NDMP_CONNECT_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_CONNECT_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_NDE.*/i) {
		cti'report("Test Name  : ndmp_$1, Case :NDMP_NO_DEVICE_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_NO_DEVICE_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_NSE.*/i) {
	    	cti'report("Test Name  : ndmp_$1, Case :NDMP_NOT_SUPPORTED_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_NOT_SUPPORTED_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_PE.*/i) {
		cti'report("Test Name  : ndmp_$1, Case :NDMP_PERMISSION_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_PERMISSION_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_NTE.*/i) {
	    	cti'report("Test Name  : ndmp_$1, Case :NDMP_NO_TAPE_LOADED_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_NO_TAPE_LOADED_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_RIP.*/i) {
		cti'report("Test Name  : ndmp_$1, Case :NDMP_READ_IN_PROGRESS_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_READ_IN_PROGRESS_ERR\n";
	}

	if ($file_name=~/.*data\/.*\/(.*)_PCE.*/i) {
	    	cti'report("Test Name  : ndmp_$1, Case :NDMP_PRECONDITION_ERR\n");
		print LOG "Test Name  :ndmp_$1,  Case: NDMP_PRECONDITION_ERR\n";
	}
	print LOG "=====================================================\n";
	close(LOG);

}

#
# input_dev_file() function substitutes the Tape device and
# scsi device names from the dev_file to the input file
#

sub input_dev_file
{
	my ($input,$NDMP_TAPE_DEV,$NDMP_ROBOT) = @_;

	#
	# ENV variables are copied to the @lines variable
	#Starts Here
	#

	my @lines= ($NDMP_TAPE_DEV,$NDMP_ROBOT);

	#
	#Ends Here
	#


	#
	#Opening the input file to add the device file name
	#Starts Here

	open OUT, "+< $input" or die "Can't open $input : $!";
	my @file;
	while(<OUT>) {
		my $flag=0;
		if(($_ =~ s/\/dev.*changer.*/$lines[1]/gi)) {
			$flag=1;
		}
		$_ =~ s/\/dev.*/$lines[0]/ if (!$flag);
		push @file,"$_";
	}
	close(OUT);
	open OUT, "+< $input" or die "Can't open $input : $!";
	foreach my $line(@file) {
		print OUT "$line";
	}
	close(OUT);

	#
	#Ends Here
	#

}

#
# Following function writes the Postmessage.log to the Master log file
# This was required as the Post messge interfaces generate different
# log than the other interfaces like SCSI and Tape
#

sub post_message
{
	my ($post_log) = @_;
	open POST, "< $post_log" or die "Can't open $post_log : $!";
	my $line;
	my $flag =0;
	my @contents = <POST>;
	while (<POST>) {
		$line = $_;
		if ($line =~ /ERROR/i) {
			$flag = 1;
		}
	}
	close(POST);
	open POST, "> $post_log" or die "Can't open $post_log : $!";
	my $len = scalar @contents;
	my $i;
	for ($i = 0; $i<$len;$i++) {
		if ($i == 0) {
			print POST "===================================================\n";
		}
		print POST "$contents[$i]";
	}
	print POST "===================================================\n";
	close (POST);

	if ($flag) {
		return (1);
	} else {
		return (0);
	}

}

#
# This function pareses the log file and flags whether the result is PASS/FAIL
# And also it writes TEST CASE RESULT into the log file
#

sub parse_log
{
	my ($input,$test_name) = @_;
	my $flag = 0;
	my $tname="";
	$test_name =~ s/.*data\/.*\/(.*)\.in/$1/;
	$test_name = uc($test_name);
	$test_name = "NDMP_".$test_name;
	my @tests = split(/_/,$test_name);
	my $count = scalar @tests;
	my $i;
	my $message=parse_error($tests[$count-1]);
	for ($i=0; $i< $count-1; $i++) {
		$tname = $tname."_".$tests[$i];
	}
	my $error = $tests[$i];
	$error = parse_error($error);
	$tname =~ s/_(.*)/$1/;

	if ($tname =~ /NDMP_MOVER_SET_WINDOW_SIZE/i) {
		$tname = "NDMP_MOVER_SET_WINDOW";
	}
	if ( $tname =~ /ndmp_config_get_conn_type/i) {
		$tname = "NDMP_CONFIG_GET_CONNECTION_TYPE";
	}
	open OUT, "< $input" or die "Can't open $input : $!";
	my @file;
	my $line1;
	my $flag2 = 0;
	my $prev_line="";
	while(<OUT>) {
		$line1 = $_;
		if(($line1 =~ /$tname/) || ($line1 =~ /NDMP_TAPE_GET_STATE/i) || ($flag2)) {
			if (($line1 =~ /$error/i)) {
				$flag = 1 ;
			}
			$flag2=1;
		}
		if ( ($flag) && ($line1 =~ /TEST\sCASE\sRESULT\s:\s(.*)/) ) {
			if ( $1 =~ /SUCCESS/ ) {
				return (0);
			} else {
				return (1);
			}
			$flag =0;
		}
		$prev_line = $line1;
	}

	close(OUT);

}

#
# Following is the helper function required to interpret the short names
# to the proper error messages
#

sub parse_error
{
	my ($error_message) = @_;

	if ($error_message =~ /NNE/ ) {
		return ("NDMP_NO_ERR");
	}

	if ($error_message =~ /DOE/) {
		return ("NDMP_DEVICE_OPENED_ERR");
	}

	if ($error_message =~ /NAE/ ) {
		return ("NDMP_NOT_AUTHORIZED_ERR");
	}

	if ($error_message =~ /IAE/ ) {
		return ("NDMP_ILLEGAL_ARGS");
	}

	if ($error_message =~ /DNOE/ ) {
		return ("NDMP_DEV_NOT_OPEN_ERR");
	}

	if ($error_message =~ /NIE/ ) {
		return ("NDMP_IO_ERR");
	}

	if ($error_message =~ /WPE/ ) {
		return ("NDMP_WRITE_PROTECT_ERR");
	}

	if ($error_message =~ /ISE/ ) {
		return ("NDMP_ILLEGAL_STATE_ERR");
	}

	if ($error_message =~ /CE/ ) {
		return ("NDMP_CONNECT_ERR");
	}

	if ($error_message =~ /NDE/ ) {
		return ("NDMP_NO_DEVICE_ERR");
	}

	if ($error_message =~ /NSE/ ) {
		return ("NDMP_NOT_SUPPORTED_ERR");
	}

	if ($error_message =~ /PE/ ) {
		return ("NDMP_PERMISSION_ERR");
	}

	if ($error_message =~ /NTE/ ) {
		return ("NDMP_NO_TAPE_LOADED_ERR");
	}

	if ($error_message =~ /RIP/ ) {
		return ("NDMP_READ_IN_PROGRESS_ERR");
	}

	if ($error_message =~ /PCE/ ) {
		return ("NDMP_PRECONDITION_ERR");
	}

	if ($error_message =~ /DANDN/ ) {
		return ("NDMP_EXT_DANDN_ILLEGAL_ERR");
	}

}

sub ndmp_execute_cli
{
    my ($args_ref) = @_;
    my ($NDMP_SERVER_IP,$NDMP_USER,$NDMP_PASSWORD,$NDMP_TAPE_DEV,$NDMP_ROBOT)
    	= ($ENV{'NDMP_SERVER_IP'},$ENV{'NDMP_USER'}, $ENV{'NDMP_PASSWORD'},$ENV{'NDMP_TAPE_DEV'},$ENV{'NDMP_ROBOT'});
    my ($NDMP_AUTH,$LOG_LEVEL) = ($ENV{'NDMP_AUTH'},$ENV{'LOG_LEVEL'});
    my $ndmp_binary = ("$ENV{\"CTI_SUITE\"}/bin/ndmp_proto_test");
    my $log_path = log_file();

        my $cmd = "$ndmp_binary";
        my @check_keys = ('option','fs','inf','err','level','rec_size','win_size','addr_type','backup_type','cdb','auth_type','ndmp_ver','sub_msg');
        foreach my $opt (@check_keys) {
                if ( defined $args_ref->{ $opt } ) {
                        $cmd = $cmd." -$opt ".$args_ref->{ $opt };
                }
        }
	if ( defined $args_ref->{'err'})  {
		if ( $args_ref->{'err'} =~ /NDMP_NOT_AUTHORIZED_ERR/ ) {
			$NDMP_PASSWORD = "amin";
		} elsif ($args_ref->{'err'} =~ /NDMP_NO_DEVICE_ERR/ ) {
			$NDMP_ROBOT = $NDMP_ROBOT."shen";
		}
	}


        $cmd = $cmd." -log $log_path  -tape $NDMP_TAPE_DEV -robot";
	if ( ($LOG_LEVEL==0) || ($LOG_LEVEL==1) || ($LOG_LEVEL==2) ) {
                $cmd = $cmd." $NDMP_ROBOT -src $NDMP_SERVER_IP";
                $cmd = $cmd." -src_user $NDMP_USER -src_pass $NDMP_PASSWORD";
                $cmd = $cmd." -log_level $LOG_LEVEL";
        }else {
                $LOG_LEVEL=0;
                $cmd = $cmd." $NDMP_ROBOT -src $NDMP_SERVER_IP";
                $cmd = $cmd." -src_user $NDMP_USER -src_pass $NDMP_PASSWORD";
                $cmd = $cmd." -log_level $LOG_LEVEL";
        }
        $cmd = $cmd." -scsi_dev $NDMP_ROBOT";
        my $res = system("$cmd");
        log_parse_print($log_path,$args_ref);
	sleep(3);

}

sub log_parse_print
{
        my ($log_name,$args_ref) = @_;
        open OUT, "< $log_name" or die "Can't open $log_name : $!";
        my $line;
        my $prev_line = "";
        while(<OUT>) {
                $line = $_;
                if  ( $prev_line =~ /Test\scase\sname\s:\s.*/i ) {
                        &cti'report("$prev_line\n");
                        &cti'report("$line\n");
			if ( defined $args_ref-> {'rec_size'} ) {
			    &cti'report("Testing for Record Size :",$args_ref-> {'rec_size'},"\n");
			}
			if ( defined $args_ref-> {'win_size'} ) {
			    &cti'report("Testing for WIndow Size :",$args_ref-> {'win_size'},"\n");
			}
			if ( defined $args_ref-> {'addr_type'} ) {
			    &cti'report("Testing with",$args_ref-> {'addr_type'},"\n");
			}
			if ( defined $args_ref-> {'backup_type'} ) {
				&cti'report("Testing with",$args_ref-> {'backup_type'},"\n");
			}

                }

                if ($line =~ /TEST\sCASE\sRESULT\s:\s(.*)/i ) {
                        if ( $1 =~ /PASS/i ) {
                                &cti'pass("protocol tested successfully");
                        } else {
                                &cti'fail("protocol test failed");
                        }
                }
                $prev_line = $line;
        }

        close(OUT);
	&cti'reportfile ($log_name,"Detailed log");
}


1;

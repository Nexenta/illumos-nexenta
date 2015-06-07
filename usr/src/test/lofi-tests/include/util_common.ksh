#
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)util_common.ksh	1.2	08/12/19 SMI"
#

#
# Common utilities for test functions
#

TMPDIR=/tmp
EXECUTION_RECORD=${TMPDIR}/execution_record_$$


#
# NAME:
#	delete_execution_record
#
# SYNOPSIS:
#	delete_execution_record
#
# DESCRIPTION:
#	Delete the file created to contain the record of commands executed.
#
# RETURN VALUE:
#	Undefined (not set)
#
function delete_execution_record {
	$RM -f $EXECUTION_RECORD 2>/dev/null
}


#
# NAME:
#	display_execution_record
#
# SYNOPSIS:
#	display_execution_record
#
# DESCRIPTION:
#	Show the contents of the file containing a record of commands executed
#	by a test case.  A header and footer are printed to visually separate
#	the output from the rest of the journal file.  This function is
#	typically called by a failed test purpose in order to display the
#	exact list of commands that were executed.  (Note:  Do to the
#	mysteries of how UNIX shells work, it's not unusual for output from
#	actions taken before or after this function is called to be mixed
#	in with the output of this function in the journal file.)
#
# RETURN VALUE:
#	Undefined (not set)
#
function display_execution_record {
	if [[ -z "$EXECUTION_RECORD" ]]; then
		return
	fi

	typeset output=${TMPDIR}/final_execution_record_$$
	echo "------Record of commands executed------" >$output
	echo "Phase      Command" >>$output
	echo "---------  ----------------------------" >> $output
	cat $EXECUTION_RECORD >> $output
	echo "------End of cmd execution record------" >> $output
	cti_reportfile $output
	$RM -f $output 2>/dev/null
	delete_execution_record
}


#
# NAME:
#	create_execution_record
#
# SYNOPSIS:
#	create_execution_record
#
# DESCRIPTION:
#	Create the file to contain the record of commands executed, after
#	first deleting any pre-existing file.  This function is typically
#	called at the beginning of a test purpose, to create/clean-out
#	the file that contains the record of commands executed.
#
# RETURN VALUE:
#	Not set
#
function create_execution_record {
	if [[ -z "$EXECUTION_RECORD" ]]; then
		return
	fi

	delete_execution_record
	touch $EXECUTION_RECORD
}


#
# NAME:
#	record_cmd_execution
#
# SYNOPSIS:
#	record_cmd_execution <command>
#
# DESCRIPTION:
#	Copy the specified command into the record of commands executed.
#
#	This function is intended to be used to build a record of the
#	commands executed during the course of a test purpose.  The tp
#	function, as well as utility functions it calls that execute
#	commands, should call this function for each command they execute.
#	The resulting record of commands can then be displayed if the test
#	purpose fails, providing a list of the exact commands executed as
#	an aid in reproducing/troubleshooting the failure.
#
# RETURN VALUE:
#	Not set
#
function record_cmd_execution {
	if [[ -z "$EXECUTION_RECORD" ]]; then
		return
	fi

	echo "${ex_phase}  $*" >> $EXECUTION_RECORD
}


#
# NAME:
#	execution_phase_setup
#
# SYNOPSIS:
#	execution_phase_setup
#
# DESCRIPTION:
#	Set the current execution phase (used by the record_execution_record)
#	function to 'setup'.
#
# RETURN VALUE:
#	Not set
#
function execution_phase_setup {
	ex_phase="setup    "
}


#
# NAME:
#	execution_phase_assert
#
# SYNOPSIS:
#	execution_phase_assert
#
# DESCRIPTION:
#	Set the current execution phase (used by the record_execution_record)
#	function to 'assert'.
#
# RETURN VALUE:
#	Not set
#
function execution_phase_assert {
	ex_phase="assertion"
}


#
# NAME:
#	execution_phase_cleanup
#
# SYNOPSIS:
#	execution_phase_cleanup
#
# DESCRIPTION:
#	Set the current execution phase (used by the record_execution_record)
#	function to 'cleanup'.
#
# RETURN VALUE:
#	Not set
#
function execution_phase_cleanup {
	ex_phase="cleanup  "
}


#
# NAME:
#	 extract_assertion_info
#
# SYNOPSIS:
#	extract_assertion_info <test_source_filename>
#
# DESCRIPTION:
#	A function to extract the assertion information from the test source
#	file. It prints out the assertion information in a standard format to
#	stdout (and thus to the journal file). 
#
#       
# ARGUMENTS:
#	$1 - the file where the header information is. Typically this is the
#	     test case source file.
#	$2 - this optional argument identifies a specific assertion for a file
#	     that contains multiple assertions.  If provided, only this
#	     assertion will be extracted.
#
# RETURNS:
#	No return code is set.  The function prints information to stdout
#	(and thus to the journal file).
#
function extract_assertion_info {

	typeset tmpfile=${TMPDIR}/extract_assertion_info_$$

	# Extract the assertion info from the test source file and
	# place it in a temporary file.
	nawk -v specific_assert=$2 '

 BEGIN {
		in_assertion	    = 0;
		turn_off_printing       = 0;
	}


	#
	# End of the .spec content. This finds the end of the assertion
	#
	/^# +end +__stc_assertion/ {
		in_assertion = 0;
		next;
	}



	#
	# Beginning of the .spec content. This finds the beginning
	# of the assertion.
	#
	/^# +start +__stc_assertion__/ {
		in_assertion = 1;
		next;
	}


	#
	# This grabs the "ASSERTION: testname" line.  If no specific
	# assertion was identified we will grab any "ASSERTION:" line we
	# find.  If a specific assertion was identified, make sure the
	# "ASSERTION:" line matches it -- if not, this assertion is not
	# the one we are looking for.
	#
	/^.+ASSERTION:/ && (in_assertion) {
		if ( specific_assert == "" || specific_assert == $NF ) {
			a=substr($0, index($0, "#") + length("#"));
			#remove any leading spaces
			sub(/^ +/, "", a);
			printf("%s\n\n", a);
			turn_off_printing = 1;
			next;
		} else {
			in_assertion = 0;
		}
	}

	#
	# This prints the actual assertion statement. STC calls this the
	# description and requires one for every ASSERTION:.

	#
	/^.+DESCRIPTION:/ && (in_assertion) {
	    a=substr($0, index($0, "DESCRIPTION:") + length("DESCRIPTION:"));
		a=substr($0, index($0, "#") + length("#"));
		#remove any leading spaces
		sub(/^ +/, "", a);
		printf("%s\n\n", a);
	       turn_off_printing = 0;
	       next;
	}

	#
	# List of interfaces targeted by the current assertion. STC requires
	# one of these for every ASSERTION:
	#
	#/^.+INTERFACES:/ && (in_assertion) {
	#	in_assertion = 0;
	#}

	/^.+STRATEGY:/ && (in_assertion) {
		#use in_assertion =1 to print the strategy.
		in_assertion = 0;

		#use in_assertion =1 to print the strategy.
		in_assertion = 0;
	}

	# Body of the assertion comments.
	#
	(in_assertion) && length && !(turn_off_printing) {
		a=substr($0,index($0,"#")+1);
		printf("%s\n", a);
	}

	' $1 > $tmpfile

	# Copy the extracted information into the journal and then
	# clean up after ourselves.
	cti_reportfile $tmpfile
	rm -rf $tmpfile
}


#
# NAME:
#	extract_line_from_file
#
# SYNOPSIS:
#	extract_line_from_file <filename> <line number>
#
# DESCRIPTION:
#	Verify that the specified file exists and is readable, then extract
#	the specified line from the file.  The line extracted is echoed to
#	stdout so that it can be captured by the calling function.
#
# RETURN VALUES:
#	0	Successfully extracted the specified line from the file.
#	1	Unable to access file.
#	2	Could not locate the specified line in the file.
#
function extract_line_from_file {
	typeset filename="$1"
	typeset line_number="$2"

	# Make sure the file exists and is readable.
	if [[ ! -r "$filename" ]]; then
		cti_report "File $filename doesn't exist or isn't readable" \
		    "by this process"
		return 1
	fi

	# Read in each line of the file until we've obtained the Nth line
	# (where N equals the argument passed in specifying the desired line
	# number).
	typeset line_num=0
	typeset matching_line=""
	{ while read line; do
		let line_num=$line_num+1
		if (( $line_num == $line_number )); then
			matching_line="$line"
			break
		fi
	done } < $filename

	# Make sure we actually obtained something.
	if [[ -z "$matching_line" ]]; then
		cti_report "Unable to find line number $line_number in file" \
		    "$filename"
		return 2
	fi

	# Print the line to stdout so that the calling function can capture it.
	echo $matching_line

	return 0
}


#
# NAME
#	tp_within_parameters
#
# SYNOPSIS
#	tp_within_parameters <list name> <param> [<list name> <param> ...]
#
# DESCRIPTION
#	This function was designed primarily for use by dynamically generated
#	tests.  In these tests the same test purposes is reused multiple
#	times, executing with a different combination of parameter values each
#	time.  The suite allows users to restrict which parameters values are
#	desired by setting variables in the file:
#
#		$TET_SUITE_ROOT/lofi/config/test_config
#
#	(or by making the same variable assignments on the command line).
#	This function is called by such test purposes to determine if the
#	set of parameters for the current iteration fits within any
#	restrictions the user might have set.
#
#	For each parameter the test purpose is concerned about, it passes in
#	the name of the variable containing the list of desired parameters
#	along with the current value of that parameter.  If the list variable
#	specified is not set then the user has not placed restrictions on that
#	particular parameter.  If the variable is set, then the function
#	compares the current parameter value against the list of desired
#	values.  If the parameter value is not on the 'desired' list the test
#	purpose should not be run.
#
#	Multiple parameter lists and current values can be specified in one
#	call to this function (see SYNOPSIS).  The function evaluates all of
#	them, and if any one parameter value is found to be missing from the
#	corresponding list of desired values then the function calls
#	cti_unsupported() and gives a return value of 1.  When this happens,
#	the calling test purpose should return immediately.
#
#	Note that while this function was written for test purposes using
#	dynamically-generated test parameters, static test purposes can make
#	use of it as well.
#
# RETURN VALUES
#	0	Test purpose fits within current paramters and should be run
#	1	Test purpose doesn't fit current parameters and should not run
function tp_within_parameters {

	typeset param_list_name param_list current_param match
	typeset status=0

	while [[ -n "$@" ]]; do
		# Extract first variable name and current parameter value from
		# the head of the list.
		unset match
		param_list_name="$1"
		current_param="$2"
		shift 2

		# Use 'eval' to get at the contents of the specified variable,
		# which will provide us with the list of desired values.
		eval param_list=\$$param_list_name

		# If the list of desired values is empty, the user placed no
		# restrictions on this paramter and we can skip over it.  If
		# the list isn't empty, see if the current parameter value is
		# on the 'desired' list.
		if [[ -n "$param_list" ]]; then
			for param in $param_list; do
				if [[ "$param" = "$current_param" ]]; then
					match=1
				fi
			done
			if [[ -z "$match" ]]; then
				cti_report "Parameter '$current_param' not" \
				    "in $param_list_name ('$param_list')"
				status=1
			fi
		fi
	done

	if (( $status != 0 )); then
		cti_untested "Test purpose does not fit user-defined" \
		    "execution criteria"
	fi
	return $status
}

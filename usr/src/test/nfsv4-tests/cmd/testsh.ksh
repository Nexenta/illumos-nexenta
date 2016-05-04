#! /usr/bin/ksh -p
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

[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

NAME=$(basename $0)
CDIR=$(pwd)

. $TESTROOT/libsmf.shlib

# proc to check if running as root
# Usage: is_root [testname] [tmessage]
#	testname  optional; if provided, add to the output
#	tmessage  optional; if provided, must be followed by testname
# The main purpose of testname and message is to provide a line that emulates
# an assertion, so that the failure is captured in the summary and reported.
# On success, it just returns 0, on failure, a message is printed, and
# exit UNINITIATED is issued.
function is_root
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	TName=$1
	[[ -n $TName ]] && TName="$TName: "
	Msg=$2
	Stat=""
	[[ -n $Msg ]] && Stat="\tTest UNINITIATED: " || Msg="\c"
	id | grep "0(root)" > /dev/null 2>&1
	if (( $? != 0 )); then
		echo "$TName$Msg"
		echo "${Stat}Must run the tests as root."
		exit $UNINITIATED
	fi
	return 0
}

# proc to get a field from ls -l (owner or group) and print it to stdout
# Usage: get_val position filepath
#	gets ${position}th parameter from "ls -l ${filepath}
function get_val
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	if (( $# != 2 )); then
		echo "error_bad_#_parameters"
		return 1
	fi
	pos=$1
	path=$2

	ls -l $path > $TMPDIR/getval.out 2> $TMPDIR/getval.err
	res=$?
	if [[ $DEBUG != 0 ]]; then
		cat $TMPDIR/getval.out >&2
		cat $TMPDIR/getval.err >&2
	fi
	if (( res != 0 )); then
		if [[ $DEBUG == 0 ]]; then
			echo "stdout was:" >&2
			cat $TMPDIR/getval.out >&2
			echo "stderr was:" >&2
			cat $TMPDIR/getval.err >&2
		fi
		rm -f $TMPDIR/getval.out $TMPDIR/getval.err 2> /dev/null
		return $res
	fi
 	out=$(awk "{print \$$pos}" $TMPDIR/getval.out 2> $TMPDIR/getval.err)
	res=$?
	[[ $DEBUG != 0 ]] && echo $out >&2
	(( res != 0 )) && cat $TMPDIR/getval.err >&2
	rm -f $TMPDIR/getval.out $TMPDIR/getval.err 2> /dev/null
	echo $out

	return $res
}


# proc to get a field from getfacl and print it to stdout
# Usage: get_val field_key filepath
#	looks for the field_key, and prints its value
#example get_acl_val user:root /aPath/myfile
function get_acl_val
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	if (( $# != 2 )); then
		echo "error_bad_#_parameters"
		return 1
	fi
	key=$1
	path=$2

	getfacl $path > $TMPDIR/getval.out 2> $TMPDIR/getval.err
	res=$?
	if [[ $DEBUG != 0 ]]; then
		cat $TMPDIR/getval.out >&2
		cat $TMPDIR/getval.err >&2
	fi
	if (( res != 0 )); then
		if [[ $DEBUG == 0 ]]; then
			echo "stdout was:" >&2
			cat $TMPDIR/getval.out >&2
			echo "stderr was:" >&2
			cat $TMPDIR/getval.err >&2
		fi
		rm -f $TMPDIR/getval.out $TMPDIR/getval.err 2> /dev/null
		return $res
	fi
 	out=$(grep "$key" $TMPDIR/getval.out | awk '{print $1}' \
		2> $TMPDIR/getval.err)
	res=$?
	[[ $DEBUG != 0 ]] && echo "stdout was: <$out>" >&2
	(( res != 0 )) && cat $TMPDIR/getval.err >&2
	rm -f $TMPDIR/getval.out $TMPDIR/getval.err 2> /dev/null
	temp=$(echo $out | awk -F: '{print $2}')
	[[ -n $temp ]] && echo $temp

	return $res
}

# proc to check result and print out failure messages
# Usage: ckres test_operation status expected_st op_result_msg
# 	test_operation	string describing operation tested
#	status		result (status) from operation
#	expected_st	expected result (status)
#	op_result_msg	file or string diagnostic to print if failure
# test_code can be used to substitute FAIL. Also, expected_st
# can take several values separated by '|' and behave as true if any of the
# values matches $status.

function ckres
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	op=$1
	st=$2
	expt=$3
	if [[ -n $4 ]]; then
		res=$4
		# if $res is an operation output file, get its content
		if [[ -f $res ]]; then
			res=$(cat $res)
		else
			# is a string, get all components from $4 to last
			shift; shift; shift
			res="$@"
		fi
	fi
	tmp=$(echo $expt | sed 's/|/ /g')
	expt=$tmp
	code="FAIL"
	# if exported var for code different from FAIL
	[[ -n $ckres_code ]] && code=$ckres_code
	ret=$(echo $expt | grep "$st")
	if (( $? != 0 )); then
		echo "\tTest $code: $op returned ($st), expected ($expt)"
		[[ -n $res ]] && echo "\t\tres = $res\n"
	else
		echo "\tTest PASS"
	fi
	return $st
}

# proc to check result and print out failure messages. It is a improved version
# of the original ckres().
# Usage: ckres2 <-s> test_operation status expected_st op_result_msg logfile
#		result_str
#	-s 		output nothing if the check passes
# 	test_operation	string describing operation tested
#	status		result (status) from operation
#	expected_st	expected result (status)
#	op_result_msg	user-specified error message to print if it fails
#	logfile		the file which contains diagnostic information
#	result_str	Alternative result string to use instead of FAIL
# expected_st can take several values separated by '|' and behave as true
# if any of them is matched against.
#
# Compared with the original ckres(), it has the following new features:
#
# 1) User-specified error message and logfile are represented by two different
#    arguments now. The format of the failure message is:
#
#    <content of logfile>
#    \tTest FAIL
#    \t\terr=$msg
#
# 2) User can specify alternative result string on failure with the $result_str
#    argument. This is useful in testcase-specific setup code, where the result
#    string should be "UNRESOLVED", instead of "FAIL".
# 3) If alternative result string is "ERROR" or "WARNING", the failure message
#    has a different format:
#
#    <content of logfile>
#    ERROR: $msg
#
#    This is useful in setup code unrelated to specific testcase.
# 4) If -s option is specified, ckres output nothing if the check passes.
#    This is useful in that one can call ckres2() multiple times to in
#    different checking steps in a single testcase.
# 5) More helpful return value. ckres2() returns 0 if result string matches
#    the expected one; and 1 if not.
# 6) More strict checking. ckres2() checks if result string matches EXACTLY
#    with the expected string.

function ckres2
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	subcheck=0
	if [[ $1 == -s ]]; then
                subcheck=1
                shift
        fi

	op=$1
	res=$2
	exp=$3
	msg=$4
	[[ -n $5 ]] && errlog=$5
	[[ -n $6 ]] && alt_str=$6

	# set error string. Use $alt_str if user specified it.
	code=FAIL
	[[ -n $alt_str ]] && code=$alt_str

	matched=0
	echo "$exp" | grep "|" > /dev/null
	if (( $? == 1 )); then
		[[ $exp == $res ]] && matched=1
	else
		i=1
		while true; do
			var=$(echo "$exp" | cut -d\| -f$i)
			# if we have run through all the values
			[[ -z $var ]] && break
			# if we find a matched value
			[[ $var == $res ]] && matched=1 && break
			# continue the loop
			i=$((i + 1))
		done
	fi

	if (( matched == 0 )); then
		# error log
		[[ -f $errlog ]] && cat $errlog && rm -f $errlog

		# summary of operation result
		if [[ $code == ERROR || $code == WARNING ]]; then
			echo "$code: $msg\n"
		else
			echo "\tTest $code: $op returned ($res), expected ($exp)"
			# user-specified error message
			[[ -n $msg ]] && echo "\t\terr = $msg\n"
		fi

		return 1
	else
		[[ -f $errlog ]] && rm -f $errlog
		(( subcheck != 1 )) && echo "\tTest PASS"
		return 0
	fi
}

# proc to check return code and print out failure messages
# if return-code is 0, this function simply return back 0.
# Usage: ckreturn [-r] return_code error_message [err_detail_file]
#               [result_string]
#       -r              Invert the test logic (failure becomes return_code = 0)
#       return_code     Return code to check
#       error_message   The fail message to print at FAIL
#       err_detail_file The file to cat out if exists, on failure
#       result_string   Alternative result string to use instead of FAIL
#
#                       A result string of "WARNING" or "ERROR" will prevent
#                       the use of the assertion result format (\tTest XXX: msg)

function ckreturn
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
        USAGE=\
"Usage: ckreturn [-r] return_code error_message [err_detail_file] \
\t\t\t[result_string]\n\
\tif -r is specified, error condition becomes return_code = 0,\n\
\tif result_string is not specified, \"FAIL\" is assumed."
        typeset n=$#
        typeset inv_flg=0
        # requested negative logic (rc == 0)?
        if [[ $1 == -r ]]; then
                n=$((n - 1))
                inv_flg=1
                shift
        fi
        # verify needed args are provided and get them
        (( n < 2 || n > 4 )) && echo $USAGE && exit $OTHER
        typeset rc=$1
        typeset msg=$2
        typeset cf=""
        (( n >= 3 )) && cf=$3
        typeset res="FAIL"
        (( n >= 4 )) && res=$4

        #check if appropriate error condition is present
        typeset tst=0
        if (( inv_flg == 0 )); then
                (( rc != 0 )) && tst=1
        else # -r was specified
                (( rc == 0 )) && tst=1
        fi

        # on error, cat info file and print Test result message
        if (( tst == 1 )); then
                [[ -n $cf && -f $cf ]] && cat $cf && rm -f $cf
                typeset TEST="\tTest "
                [[ $res == @(WARNING|ERROR) ]] && TEST=""
                echo "$TEST$res: $msg"
        fi
        #propagate original return code
        return $rc
}


# Proc to poll until a condition is met or the specified timeout expires.
# If condition's returned value met the criteria supplied, is considered
# successful and the polling finishes, otherwise keep polling after a second
# delay until timeout expires.
# The returned value is that of the condition passed (as a string).
# Usage: poll timeout test condition
#	timeout		timeout in seconds
#	criteria	success criteria for returned code of condition
#	condition	condition to be polling on

function poll
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	
	timeout=$1
	criteria=$2
	shift
	shift
	condition=$@
	# change return code ($?) in criteria to $st
	criteria=$(echo $criteria | sed 's/\$\?/\$st/g')

	# loop until condition is met or timeout is reached
	i=0
	while (( i < timeout ))
	do
        	sleep 1
        	i=$((i + 1))
        	eval $condition > /dev/null 2>&1
		st=$?
        	eval [[ $criteria ]] && break
	done
	return $st
}


# proc to print string describing assertion.
#	Usage: assertion assertion_name description_msg expected value
#	also global variable NAME must contain the name of the current test file
function assertion
{
	Aname=$1
	ASSERTION=$2
	shift
	shift
	Expected=$@
	echo "$NAME{$Aname}: $ASSERTION, expect $Expected"
}

# proc to get domain by hostname, using korn shell
#       Usage: get_domain hostname FQDN(optional)
#       hostname       hostname of the machine
#       FQDN           a flag, if set, return full fully qualified domain name
#       DEBUG           global to enable debugging mode
#
function get_domain
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
         mach=$1
         FQDN=$2
         ns="dig"

         [[ -z $mach ]] && return 1
         res=$(getent hosts $mach)
         (( $? != 0 )) && return 1
         ipaddr=$(echo $res | nawk '{print $1}')
         $ns @$DNS_SERVER +noqu -x $ipaddr > $TMPDIR/$ns.out.$$ 2>&1
         res=$(cat $TMPDIR/$ns.out.$$ | grep 'PTR')
         ret=$?
         [[ $ret != 0 && -n $DEBUG && $DEBUG != 0 ]] \
	     && cat $TMPDIR/$ns.out.$$ >&2
         rm -f $TMPDIR/$ns.out.$$
         (( ret != 0 )) && return 1

         res=$(echo $res | nawk '{print $5}' | tr "[:upper:]" "[:lower:]")
	 res=${res%.}
         if [[ $FQDN != FQDN ]]; then
                 mn1=$(echo $res | cut -d. -f1)
                 res=$(echo $res | sed "s/$mn1.//")
         fi

         echo $res
         return $ret
}


# proc to remotely execute one or more commands, using korn shell.
#	Usage: execute machine user command_string(rest of line)
#	machine		remote machine to execute command
#	user		target user on remote system
#	command_string	any desired command(s) (korn shell)
#	DEBUG		global to enable debugging mode
#	UNIX_RES	global to detect failures, if unix standard is followed
#			for return codes (0=OK, !0=failure).
#	This proc in addition to execute remote command, adds code for
#	getting the return code from last operation, and to trace
#	the remote execution asenabled by set -x (depending on $DEBUG).
#
# note: Take care of not redirection stderr to stdout as that will cause
#	a very messy output in debug mode, and possible test failures.

function execute
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	
	rmach=$1
	ruser=$2
	shift; shift
	SETD=""
	[[ -n $DEBUG && $DEBUG != 0 ]] \
		&& SETD="DEBUG=$DEBUG; export DEBUG; set -x; "
	rcmd="$SETD$@"
	# by default, expect UNIX standard result codes
	UNIX_RES=${UNIX_RES:=1}

	file=$TMPDIR/$rmach.$$.out
	file2=$TMPDIR/exec.result
	ssh -o "StrictHostKeyChecking no" $rmach -l $ruser "$rcmd; print -u 2 \"returned=(\$?)\"" > $file 2> $file2
	ret=$?
	if (( ret != 0 )); then
		cat $file2
		return $ret
	fi
	cat $file
	tag=0
	# if debug info, ignore error message length criteria
	if [[ -n $DEBUG && $DEBUG != 0 ]]; then
		errl=0
	else
		errl=$(grep -v 'print -u 2' $file2| grep -v 'returned=('| wc -l)
	fi
	ret=$(grep -v 'print -u 2' $file2 | grep 'returned=(' | \
		sed 's/^.*returned=(//' | sed 's/).*$//')
	# if DEBUG on, mark reason for printing file2
	[[ -n $DEBUG && $DEBUG != 0 ]] && tag=2
	# if error, overwrite reason for printing file2
	[[ $errl != 0 && $DEBUG == 0 ]] || \
		(( UNIX_RES != 0 && ret != 0 )) || \
		[[ $ret == 0 && $errl != 0 && -n $DEBUG && $DEBUG != 0 ]] && tag=1
	[[ -n $DEBUG && $DEBUG != 0 ]] || (( errl != 0 )) || \
		(( ret != 0 && UNIX_RES != 0 )) && cat $file2 >&2
		
	rm -f $file $file2 > /dev/null 2>&1
	return $ret
}


# proc to remotely execute one or more commands in the background,
#	using korn shell.
#	Usage: executebg machine user command_string(rest of line)
#	machine		remote machine to execute command
#	user		target user on remote system
#	command_string	any desired command(s) (korn shell)
#	DEBUG		global to enable debugging mode
#	This proc execute remote command in the background
#	getting the return code from rsh. stdout and stderr are directed
#	 to files for getting results or diagnostics. But execution
#	tracing (debug) is not enabled on remote system.
#
# note: Take care of not redirection stderr to stdout as that will cause
#	a very messy output in debug mode, and possible test failures.

function executebg
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	rmach=$1
	ruser=$2
	shift; shift
	rcmd=$@
	file=$TMPDIR/$rmach.$$.out
	file2=$TMPDIR/exec.result
	ssh -o "StrictHostKeyChecking no" $rmach -l $ruser "/usr/bin/ksh -c $rcmd" >$file  2>$file2 &
	ret=$?
	sleep 1
	[[ -s $file ]] && cat $file 2> /dev/null
	[[ -s $file2 ]] && cat $file2 >&2
	rm -f $file $file2 > /dev/null 2>&1

	return $ret
}


# wrapper proc to mount an NFS file system
#	Usage: mountit server remote_path local_path NFS_version
#we have a local environment variable "MNT_OPT"  to the function
#if you need some extra mount options at the delegation test,
#you may need to export it before the test,for example
#in an RDMA enable system,export MNT_OPT="proto=rdma"

function mountit
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	server=$1
	rpath=$2
	lpath=$3
	version=$4
	options="rw,vers=$version"
	export MNT_OPT
	[[ -z $MNT_OPT ]] || options="rw,$MNT_OPT,vers=$version"

	is_cipso "vers=$version" $server
	if (( $? == CIPSO_NFSV2 )); then
		echo "CIPSO NFSv2 not supported under Trusted Extensions"
		return 1
	fi

	mount -F nfs -o $options $server:$rpath $lpath
	res=$?
	(( res != 0 )) && \
		echo "mount -F nfs -o $options $server:$rpath $lpath FAILED"
	return $res
}

# wrapper proc to mount an NFS file system
#	Usage: umountit local_path [kill_flag]
#	tries to umount path, if unsuccessful, gets and prints PIDs of
#	procs using that NFS file system, and if the kill flag is set
#	and there is any process, tries to kill them and retry the umount

function umountit
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	lpath=$1
	kflag=0
	(( $# > 1 )) && kflag=1
	umount $lpath
	res=$?
	if [ $res != "0" ]; then
		echo "initial umount unsuccessful ..."
		echo "fuser -cu $lpath output:"
		out=$(fuser -cu $lpath 2> /dev/null)
		fuser -cu $lpath
		echo "info for processes involved:"
		pids=$(echo $out|sed 's/^[^0-9]*//')
		pids=$(echo $pids|sed 's/[^0-9]*)//g')
		echo $pids | grep "^[0-9].*" > /dev/null 2>&1
		(( $? != 0 )) && return $res
		ps -fp "$pids"
		if (( kflag != 0 )); then
			echo "killing processes"
			for i in $pids
			do
				echo "kill -9 $i"
				kill -9 $i
			done
			# small delay for kills to finish
			sleep 5
			umount $lpath
			res=$?
			(( res != 0 )) && echo "umount $lpath FAILED ($res)"
		fi
	fi
	return $res
}


# proc to convert user names to user ids
#	Usage:	get_uid user_name_string
function get_uid
{
	uid=$1
	uid=$(id $uid | sed 's/^.*uid=//' | sed 's/(.*$//' 2>/dev/null)
	res=$?
	(( res != 0 )) && return $res
	echo $uid
	return $res
}


# proc to convert group names to group ids
#	Usage:	get_gid group_name_string
function get_gid
{
	uid=$1
	gid=$(id $uid | sed 's/^.*gid=//' | sed 's/(.*$//' 2>/dev/null)
        res=$?
	(( res != 0 )) && return $res
        echo $gid
        return $res
}


# proc to conditionally print a message and the content of an error file,
#	and erase that temporal error file.
#
#	Usage:	dprint	"message" [temp_error_file]
#	message			Any string surrounded by double (or single)
#				quote marks.
#	temp_error_file		Optional temporal file with debug information.
function dprint
{
	[[ -z $DEBUG || $DEBUG == 0 ]] && return
	(( $# < 1 )) && return
	msg=$1
	echo $msg
	if (( $# >= 2 )); then
		efile=$2
		if [[ -f $efile ]]; then
			echo "\tstderr has:\n$(cat $efile)"
			rm -f $efile > /dev/null 2>&1
		fi
	fi
}

function get_del
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	(( $# != 1 )) && echo "USAGE: get_del <SERVER>" >&2 && return $FAIL
	SERVER=$1
	GET_DEL="sharectl get -p SERVER_DELEGATION nfs"
	res=$(execute $SERVER root "$GET_DEL")
	if (( $? != 0 )); then
		assertion setup \
		"ERROR: Cannot get delegation policy for $SERVER." \
			"Get to succeed" >&2
		echo "stdout=<$res>" >&2
		return $UNINITIATED
	else
		[[ $DEBUG != 0 ]] && echo "stdout=<$res>" >&2
		res=$(echo $res | awk -F= '{print $2}')
		if [[ $res == @(off|OFF) ]]; then
			echo off
		else
			echo on
		fi
	fi
	return 0
}

function set_del
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	if (( $# != 2 )); then
		echo "USAGE: set_del <SERVER> <on/off>" >&2
                assertion setup \
                "ERROR: Could not set delegation policy for $SERVER" \
                        "Set to succeed" >&2
		echo "\tTest UNINITIATED: Terminating" >&2
		return $UNINITIATED
	fi
	SERVER=$1
	value=$2
	echo $value | egrep "on|off" > /dev/null 2>&1
	if (( $? != 0 )); then
		assertion setup \
		"ERROR: bad delegation policy value ($value)" \
			"'on' or 'off'" >&2
		echo "\tTest UNINITIATED: Terminating" >&2
		return $UNINITIATED
	fi
	SET_DEL="sharectl set -p SERVER_DELEGATION=$value nfs"
	res=$(execute $SERVER root "$SET_DEL" 2> $TMPDIR/result)
	if (( $? != 0 )); then
	        assertion setup \
        	"ERROR: Cannot set delegation policy for $SERVER." \
			"Set to succeed" >&2
		echo "stdout=<$res>" >&2
		echo "stderr=<$(cat $TMPDIR/result)>" >&2
		echo "\tTest UNINITIATED: Terminating" >&2
		rm -f $TMPDIR/result > /dev/null 2>&1
		return $UNINITIATED
	else
		[[ $DEBUG != 0 ]] && cat $TMPDIR/result >&2
		rm -f $TMPDIR/result > /dev/null 2>&1
		wait_now 10 "[[ \$(execute $SERVER root sharectl get -p \
		SERVER_DELEGATION nfs | awk -F= '{print \$2}') == $value ]]"
		if (( $? != 0 )); then
			assertion setup \
			"ERROR: the delegation policy for $SERVER has not been \
				updated to $value even after 10 seconds." \
				"Set to succeed" >&2
			return $UNINITIATED
		fi
	fi

	# Make sure the server is out of the grace period before moving on.
	# Take advantage of nfs client behavior to do it
	touch $MNTPTR/wait_for_grace_period
	rm -f $MNTPTR/wait_for_grace_period >/dev/null 2>&1
	return 0
}

# proc to convert a return code integer to its equivalent string
#
#       Usage:  rc2str return_code
#       return_code     return code to convert to its equivalent string

function rc2str
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

        (( $# != 1 )) && echo "USAGE: rc2str return_code" && exit 1

        typeset rc=$1
        case $rc in
                0 )     echo "PASS" ;;
                1 )     echo "FAIL" ;;
                2 )     echo "UNRESOLVED" ;;
                3 )     echo "NOTINUSE" ;;
                4 )     echo "UNSUPPORTED" ;;
                5 )     echo "UNTESTED" ;;
                6 )     echo "UNINITIATED" ;;
                7 )     echo "NORESULT" ;;
                8 )     echo "WARNING" ;;
                9 )     echo "TIMED_OUT" ;;
                10 )    echo "OTHER" ;;
                * )     echo "OTHER: (rc=$rc)" ;;
        esac

        return 0
}

# Clean up function
function deleg_cleanit
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	if [[ $NAMEATTR == ON ]]; then
		runat $OPF "rm -f deleg.* endless*"
		rm -f $OPF
		rm -f $TMPDIR/as_*
	fi

	rm -f $TMPDIR/tstres > /dev/null 2>&1
	rm -f $TMPDIR/result > /dev/null 2>&1
	rm -f $TMPDIR/stat.tmp > /dev/null 2>&1

	rm -f $TESTDIR/deleg.* $TESTDIR/endless_*.*
	ls $TESTDIR/deleg.* $TESTDIR/endless_*.* > /dev/null 2>&1
	(( $? == 0 )) && echo "WARNING: (Tests CLEANUP) could not remove \
		$TESTDIR/deleg.* $TESTDIR/endless_*.*"

	cd /
	umountit $TESTDIR clean
	if (( $? != 0 )); then
		umount -f $TESTDIR
		(( $? != 0 )) && echo "WARNING: (Test CLEANUP) could not \
			umount -f $TESTDIR"
	fi
	rmdir $TESTDIR
	(( $? != 0 )) && echo "WARNING: (Test CLEANUP) Cannot rmdir $TESTDIR"

	res=$(execute $CLIENT2 root "umount $TESTDIR")
	if (( $? != 0 )); then
		echo "WARNING: Cannot umount $TESTDIR on $CLIENT2.\nres = $res"
		res=$(execute $CLIENT2 root "umount -f $TESTDIR")
		if (( $? != 0 )); then
			echo "\t(Test CLEANUP) Cannot umount -f \
				$TESTDIR on $CLIENT2."
			echo "res = $res"
		fi
	fi
	res=$(execute $CLIENT2 root "rmdir $TESTDIR")
	(( $? != 0 )) && echo "(Test CLEANUP) WARNING: Cannot rmdir $TESTDIR \
				on $CLIENT2.\nres = $res"
}

# Usage: ck_zone [return_flg] [err_msg]
#	return_flg (optional); if provided and not 0, it will returned
#            to the caller when in non-global zone; otherwise
#            it will exit
#	err_msg (optional); if provided, it will be added to the output
#            when in non-global zone
#
# This proc is to verify if the current zone is a non-global zone
# 	Yes, it just returns 0 without any messages printed;
#	No, it prints an error message and return/exit 4 (UNSUPPORTED).
#
# The original vesion locates under usr/ontest/util/stc/nfs/nfs-util.ksh

function ck_zone
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	Return=$1
	ErrMsg=$2
	[[ -z $ErrMsg ]] && \
		ErrMsg="This test is not supported in non-global zone."
	zn=$(/usr/bin/zonename)
	if [[ $zn != global ]]; then
		echo "ck_zone: current zonename is <$zn>"
		echo "  $ErrMsg"
		if (( Return == 0 )); then
			echo "\tTest UNSUPPORTED: Terminating"
			exit 4
		else
			return 4
		fi
	fi
	return 0
}

# ------------------------------------------------------------------------
# is_cipso
# --------
# Determine whether the connection to be NFS mounted is
# a CIPSO connection and if it is return a value corresponding
# to NFSv2 | NFSv3 | NFSv4.
#
# usage: is_cipso <mount options> <server name>
#
#	Example usage:
#
#		if [[ -n $MNTOPTS ]]; then
#			is_cipso $MNTOPTS $SERVER
#			if (( $? == CIPSO_NFSV4 )); then
#				<setup server exported dir to include   >
#				<non-global path in its exported dir    >
#				<setup client mount point dir to include>
#				<non-global path                        >
#			fi
#		fi
#
# return:	0: NOT cipso
# 		1: IS cipso NFSv2
# 		2: IS cipso NFSv3
# 		3: IS cipso and NOT NFSv2 or NFSv3
#
# Original version is located in: usr/ontest/util/stc/nfs/common_funcs.shlib
# ------------------------------------------------------------------------
CIPSO_NOT=0
CIPSO_NFSV2=1
CIPSO_NFSV3=2
CIPSO_NFSV4=3

function is_cipso
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	if (( $# < 2 )); then
		/bin/echo "is_cipso() wrong number of args!"
		return $CIPSO_NOT
	fi

	M_OPTS=$1
	ASERVER=$2

	if [[ -x /usr/sbin/tninfo ]]; then
		/usr/sbin/tninfo -h $ASERVER | grep cipso >/dev/null 2>&1
		(( $? != 0 )) && return $CIPSO_NOT

		echo "$M_OPTS" | grep "vers=2" >/dev/null 2>&1
		(( $? == 0 )) && return $CIPSO_NFSV2

		echo "$M_OPTS" | grep "vers=3" >/dev/null 2>&1
		(( $? == 0 )) && return $CIPSO_NFSV3
		return $CIPSO_NFSV4
	fi
	return $CIPSO_NOT
}

# ------------------------------------------------------------------------
# cipso_check_mntpaths()
# ----------------------
# 1.  Check that any zones exist.
# 2.  Check that at least one non-global zone exists.
# 3.  Check that the server's exported directory contains
#     a path to a non-global zone's directory.
# 4.  Check that the client's mount point dir contains a path
#     to the same non-global zone that's in the server's
#     exported directory path.
#
#	An example of valid paths are:
#	------------------------------
#	server's exported directory:    /zone/public/root/var/tmp/junk
#	client's mount point directory: /zone/public/mnt
#
#	Then the client can mount it via:
#	---------------------------------
#	mount -F nfs <server>:/zone/public/root/var/tmp/junk /zone/public/mnt
#
# usage: cipso_check_mntpaths <server's export dir> <client's mnt pnt>
#
# return:	0: Everything is OK
# 		1: No non global zones exist
# 		2: No non global zone path in server's exported dir
# 		3: No non global zone path in client's mount point dir
#
# Original version is located in: usr/ontest/util/stc/nfs/common_funcs.shlib
# ------------------------------------------------------------------------
CIPSO_NO_NG_ZONE=1
CIPSO_NO_EXPORT_ZONEPATH=2
CIPSO_NO_MNTPT_ZONEPATH=3

function cipso_check_mntpaths
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	if (( $# < 2 )); then
		/bin/echo "cipso_check_mntpaths() wrong number of args!"
		return $CIPSO_NO_NG_ZONE
	fi

	[[ -z $ZONE_PATH ]] && return $CIPSO_NO_NG_ZONE

	srvdir=$1
	clntdir=$2

	zlist=$(/usr/sbin/zoneadm list)
	[[ -z $zlist ]] && return $CIPSO_NO_NG_ZONE

	[[ $zlist == global ]] && return $CIPSO_NO_NG_ZONE

	fnd=0
	for azone in $zlist
	do
		[[ $azone == global ]] && continue
		X=$(zoneadm -z $azone list -p | cut -d ":" -f 4)
		[[ -z $X ]] && continue
		X1=$(echo $X | sed -e 's/\// /g' | awk '{print $1}')
		X2=$(echo $X | sed -e 's/\// /g' | awk '{print $2}')
		Y1=$(echo $ZONE_PATH | sed -e 's/\// /g' | awk '{print $1}')
		Y2=$(echo $ZONE_PATH | sed -e 's/\// /g' | awk '{print $2}')
		if [[ $X1 == $Y1 && $X2 == $Y2 ]]; then
			fnd=1
			break
		fi
	done

	(( fnd == 0 )) && return $CIPSO_NO_NG_ZONE

	echo $srvdir | /bin/grep "^$ZONE_PATH" >/dev/null 2>&1
	(( $? != 0 )) && return $CIPSO_NO_EXPORT_ZONEPATH

	echo $clntdir | /bin/grep "^$ZONE_PATH" >/dev/null 2>&1
	(( $? != 0 )) && return $CIPSO_NO_MNTPT_ZONEPATH
	return 0
}

# A wait function to verify a specified condition
# Usage: wait_now max_TIMER the_condition
#      max_TIMER    the maximum timer to wait
#      condition    the condition to break the wait:
#               "true"  wait_now{} returns 0
#               "false" wait_now{} continues until the TIMER
#

function wait_now
{
    [[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
    (( $# < 2 )) && \
        echo "Usage: wait_now max_TIMER the_condition" && \
        return -1

    Timer=$1
    shift
    Wcond=$@

    i=0
    while (( i < Timer ))
    do
        eval $Wcond
        (( $? == 0 )) && return 0
        sleep 1
        i=$((i + 1))
    done
    echo "wait_now function failed"
    return $i
}

function start_fmri
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x
	(( $# == 0 )) && \
	    echo "Usage: start_fmri fmri [host]" &&
	    return -1
	typeset fmri=$1 host=$2
	typeset msg cmd ret=0 res
	if [[ -z $host ]]; then
		msg="Warning: Failed to start $fmri on $CLIENT"
		smf_fmri_transition_state do $fmri online 10 \
		    > $TMPDIR/fmri.out.$$ 2>&1
		ret=$?
		ckreturn $ret "$msg" $TMPDIR/fmri.out.$$
		return $ret
	else
		msg="Warning: Failed to start $fmri on $host"
		cmd=". $TMPDIR/libsmf.shlib; \
		    smf_fmri_transition_state do $fmri online 10; \
		    t=\$?; echo \"ret=\$t\""
		res=$(execute $host root "$cmd")
		ret=$(echo $res | grep "ret=" | sed 's/.*ret=/ret=/' | \
		    awk -F= '{print $NF}' | awk '{print $1}')
		ckreturn $ret "$msg"
		return $ret
	fi
}

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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# TCL testproc.tcl
#       Useful procs to help during testing

# TESTROOT directory; must be set in the environment already
set TESTROOT $env(TESTROOT)

source [file join ${TESTROOT} tcl.init]

# NFSv4 constant:
set OPEN4_RESULT_CONFIRM        2


#--------------------------------------------------------------------
#  Prints message to both STDOUT and log file.
#  Usage: logputs log_file_id mesg_string
#
proc logputs { log mesg } {
        if {[catch {puts $log $mesg} res]} {
                puts stderr "cannot write to log file (id=$log)"
                puts stderr $mesg
                exit 99
        }
}

#--------------------------------------------------------------------
# Prints messages to log/stdio's based on debug_level flag.  If the
# debug_level is non-zero and the DEBUG flag is not on, the message
# string will not be printed.
#   Usage: putmsg logid debug_level msg_string
#
proc putmsg { log debug_level mesg } {
        global DEBUG
        if { $debug_level == 0 || $DEBUG != 0 } {
            if {[catch {puts $log $mesg} res]} {
                puts stderr "cannot write to log file (id=$log)"
                puts stderr $mesg
                # XXX Do we need to exit here??? or Warning above is enough
                exit 99
            }
        }
}

#--------------------------------------------------------------------
#  Prints standard PASS/FAIL message to STDOUT
#  Usage: logres testres
#
proc logres { tres } {
        switch $tres {
            PASS        { puts stdout "         Test PASS" }
            FAIL        { puts stdout "         Test FAIL" }
            default     { puts stderr "         Test result unknown" }
        }
}

#--------------------------------------------------------------------
#  Checks if server can accept nfsv4 connections
#  Usage: ck_server server log_file_id
proc ck_server {SERVER log} {
        set val [catch {connect $SERVER} res]
        if {$val != 0} {
                logputs $log "argv0: Server $SERVER not ready <$res>"
                return 1
        } else {
                disconnect
                return 0
        }
}

#--------------------------------------------------------------------
# Execute compound op. Check for one of several possible result codes.
#  Usage: check_op {op1 ... opN} {expected_status_value(s)} fail_mesg
#       Executes the compound with operations op1 to opN, checking
#       for any of expected errors, printing failure message and debug
#       info to the log (stdout) if different status then expected.
#       Return value is always the result of the compound.
#       Expected status values is a list within braces of possible
#       options for status (A OR B OR C ...) to declare test success.
#       op1 to opN must be enclosed within braces.
#
proc check_op { ops exp_res_options {mesg "Test FAIL:"} {log stdout}} {

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

        set result [compound $ops]
        if {[lsearch $exp_res_options $status] == -1} {
                putmsg $log 0 "$mesg"
                putmsg $log 1 "compound $ops"
                putmsg $log 1 "$result"
                putmsg $log 0 "status was $status expected $exp_res_options"
                putmsg $log 1 " "
        }
        return $result
}


#--------------------------------------------------------------------
# Verifies the path is a file
#  Usage: isafile $path
# 	path:	the path to be verified in component format
#		e.g. {export test file1}
#  Return:
#       type: the file-type of the $path
#       NULL: if something failed during the process.
#
proc isafile { path } {
        global NULL

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

        set fh [get_fh $path]
	if {"$fh" == ""} {
		putmsg stderr 1 "unable to get FH for <$path>"
		return $NULL
	}
        set ops "Putfh $fh; Getattr type"
        set result [compound $ops]
        set type [lindex [lindex [lindex [lindex $result 1] 2] 0] 1]
        if {$status != "OK"} {
                putmsg stderr 1 \
			"ERROR: compound \{$ops\} returned status=$status"
                putmsg stderr 1 "result is: $result"
                return $NULL
        }       
        if {$type != "reg"} {
                putmsg stderr 1 "<$path> is not a file"
                return $NULL
        }
        return $type
}

#--------------------------------------------------------------------
# Verifies the path is a dir
#  Usage: isadir $path
# 	path:	the path to be verified in component format
#		e.g. {export test dir1}
#  Return:
#       type: the file-type of the $path
#       NULL: if something failed during the process.
#
proc isadir { path } {
        global NULL

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

        set fh [get_fh $path]
	if {"$fh" == ""} {
		putmsg stderr 1 "unable to get FH for <$path>"
		return $NULL
	}
        set ops "Putfh $fh; Getattr type"
        set result [compound $ops]
        set type [lindex [lindex [lindex [lindex $result 1] 2] 0] 1]
        if {$status != "OK"} {
                putmsg stderr 1 \
			"ERROR: compound \{$ops\} returned status=$status"
                putmsg stderr 1 "result is: $result"
                return $NULL
        }       
        if {$type != "dir"} {
                putmsg stderr 1 "<$path> is not a directory"
                return $NULL
        }
        return $type
}

#--------------------------------------------------------------------
# Kills named processes
#  Usage: killproc $process_name

proc killproc { name } {
        set pids [exec sh -c \
		"ps -e | grep -w $name | sed -e 's/^  *//' -e 's/ .*//'"]
        if { $pids != "" } {
                exec kill $pids
                }
        }


#---------------------------------------------------------
# Generic test procedure to validate the result.
#  Usage: ckres opname status expcode results prn-pass return_code
#         return FALSE if result code error doesn't match any of expected
#	  values (one or more separated by '|' chars).
#
proc ckres {op status exp res {prn 0} {code "FAIL"}} {
	global DEBUG

	# in case more than one result is valid, create list of them
	set nexp [split $exp '|']
	if {[lsearch -exact $nexp $status] == -1} {
            putmsg stderr 0 \
		"\t Test $code: $op returned ($status), expected ($exp)"
            putmsg stderr 1 "\t   res=($res)"
            putmsg stderr 1 "  "
            return false
	} else {
            if {$prn == 0} {
                putmsg stdout 0 "\t Test PASS"
            }
            return true
	}
}


#---------------------------------------------------------
# Generic test procedure to validate the given filehandle.  The
# 'continue-flag' indicates if this procedure should be continued.
#   Usage: verf_fh filehandle continue-flag prn-pass
#          return FALSE if verification fails
#
proc verf_fh {fh cont {prn 0}} {
    global DEBUG

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

    # stop the verification if 'continue-flag' is FALSE
    if {[string equal $cont "false"]} { return false }

    set res [compound {Putfh $fh; Getfh}]
    if {$status != "OK"} {
        putmsg stderr 0 "\t Test FAIL: verf_fh returned ($status)."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        return false
    } else {
        # verify the filehandle it get back is the same
        set nfh [lindex [lindex $res 1] 2]
        if {"$fh" != "$nfh"} {
                putmsg stderr 0 "\t Test FAIL: verf_fh new FH is different"
                putmsg stderr 1 "\t   old fh=($fh)"
                putmsg stderr 1 "\t   new fh=($nfh)"
                putmsg stderr 1 "  "
                return false
        }
        if {$prn == 0} {
                putmsg stdout 0 "\t Test PASS"
        }
    }
}


#---------------------------------------------------------
# Generic test procedure to verify two given filehandles are the same.
#  Usage: fh_equal FH1 FH2 continue-flag prn-pass
#       fh1:  filehandle 1 to be checked
#       fh2:  filehandle 2 to be checked
#       cont: continue-flag (true|false) if we should continue
#       prn:  flag to indication if PASS message should be printed
#
#  Return:
#       true:  if fh1 and fh2 are the same
#       false: if filehandles are not different
#
proc fh_equal {fh1 fh2 cont prn} {
    global DEBUG

    # stop the verification if 'continue-flag' is FALSE
    if {[string equal $cont "false"]} { return false }

    if {"$fh1" != "$fh2"} {
        if {$prn == 0} {
            # do not print error in case user want to compare with NOT-equal
            putmsg stderr 0 "\t Test FAIL: filehandles are not the same."
            putmsg stderr 1 "\t   fh1=($fh1)"
            putmsg stderr 1 "\t   fh2=($fh2)"
            putmsg stderr 1 "  "
        }
        return false
    } else {
        if {$prn == 0} {
                putmsg stdout 0 "\t Test PASS"
        }
        return true
    }
}


#---------------------------------------------------------
# Generic test procedure to create a filename longer than maxname
#  Usage: set_maxname dir_FH
#       dfh:  the directory FH where the filename to be created
#
#  Return: 
#       name: the new filename
#       NULL: if something failed during the process.
#
proc set_maxname {dfh} {
    global DEBUG NULL

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

    # first get the system's maxname value
    set res [compound {Putfh $dfh; Getattr maxname}]
    if {"$status" != "OK"} {
            putmsg stderr 0 "\t Test UNRESOLVED: Unable to get dfh(maxname)"
            putmsg stderr 1 "\t   res=($res)"
            putmsg stderr 1 "  "
            return $NULL
    }
    set maxn [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
    set name [string repeat "a" $maxn]
    # and add 1 extra byte
    append name Z
    return $name
}


#---------------------------------------------------------
# Test procedure to get server lease (grace) period
#  Usage: getleasetm 
# 	No argument needed
#
#  Return: 
#	leasetm: the server least time
#	-1:  	 if anything fails during the process
#
proc getleasetm {} {

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

    set res [compound {Putrootfh; Getattr lease_time}]
    if {$status != "OK"} {
	putmsg stderr 1 "getleasetm failed, status=$status"
	putmsg stderr 1 "\t res=$res"
	return -1
    }
    return [extract_attr [lindex [lindex $res 1] 2] lease_time]
}


#--------------------------------------------------------------------
# setclient() Wrap for setclientid operation
#  Usage: setclient verifier owner Acid Acidverf Ares {cb_prog netid addr}
#	verifier: string to identify the client
#	owner:    owner_id to set the clientid
#	Acid:     Name of the external variable to hold the clientid
#	Acidverf: Name of the external variable to hold the clientid verifier
#	Ares:     Name of the external variable to hold the operation's results
#	cb_prog:  the callback program
#	netid:    the callback program netid
#	addr:     the callback program address
#
#  Return:
#	Returns the status of the operation.
#	Also the value of the clientid, clientid_verifier and results of the
#	operation are directly stored in the variables (local to the calling
#	environment) whose names are stored in Acid, Acidverf and Ares
#	respectively.
#


proc setclient {verifier owner Aclientid Averifier Ares {callbck {0 0 0}}} {
	upvar 1 $Aclientid clientid
	upvar 1 $Averifier cid_verf
	upvar 1 $Ares res

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

	set res [compound {Setclientid $verifier $owner $callbck}]
	putmsg stdout 1 "\n"
	putmsg stdout 1 "Setclientid $verifier $owner $callbck"
	putmsg stdout 1 "Res=$res"
	if {$status == "OK"} {
		set clientid [lindex [lindex [lindex $res 0] 2] 0]
		set cid_verf [lindex [lindex [lindex $res 0] 2] 1]
	} else {
		set clientid ""
		set cid_verf ""
	}

	putmsg stdout 1 "return $status"
	return $status
}

#--------------------------------------------------------------------
# setclientconf() Wrap for setclientid_confirm op.
#  Usage: setclientconf clientid cid_verf Ares
#	clientid: clientid provided by the server
#	verifier: server provided verifier to identify the clientid
#	Ares:     Name of the external variable to hold the operation's results
#
#  Return:
#	Returns the status of the operation.
#	Also the value of the results of the operation is directly stored
#	in the variable (local to the calling environment) whose name
#	is stored in Ares.
#


proc setclientconf {clientid verifier Ares} {
	upvar 1 $Ares res

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

	set res [compound {Setclientid_confirm $clientid $verifier}]
	putmsg stdout 1 "\n"
	putmsg stdout 1 "Setclientid_confirm $clientid $verifier"
	putmsg stdout 1 "Res: $res"

	putmsg stdout 1 "return $status"
	return $status
}

#---------------------------------------------------------
# Generic test procedure to set and confirm a clientid
#  Usage: getclientid owner cb_prog netid addr
#       owner:   owner_id to set the clientid
#       cb_prog: the callback program
#       netid:   the callback program netid
#       addr:    the callback program address
#
#  Return: 
#       clientid: the clientid set/confirmed
#       -1:        if something failed during the process.
#
proc getclientid {owner {cb_prog 0} {netid 0} {addr 0}} {
    global DEBUG

    # default a unique verifier
    set verifier "[pid][expr int([expr [expr rand()] * 100000000])]"

    # negotiate cleintid
    set clientid ""
    set cidverf ""
    set res ""
    putmsg stdout 1 "getclientid: verifier=($verifier), owner=($owner)"
    set status [setclient $verifier $owner clientid cidverf res \
	{$cb_prog $netid $addr}]
    if {$status != "OK"} {
	putmsg stderr 0 "getclientid: Setclientid($verifier $owner) failed."
	return -1
    }

    # confirm clientid
    set status [setclientconf $clientid $cidverf res]
    if {$status != "OK"} {
	putmsg stderr 0 \
		"getclientid: Setclientid_confirm($clientid $cidverf) failed."
	return -1
    }

    return $clientid
}


#---------------------------------------------------------
# Generic test procedure to open and confirm a file
#  Usage: basic_open dfh fname otype cid_owner Asid Aoseqid Astatus
#		[seqid] [close] [mode] [size] [access] [deny] [ctype]
#       dfh:	  directory FH where the file is located
#       fname:	  the filename of the file to be opened
#       otype:	  the opentype
#       cid_owner: the {clientid owner} paire used to open the file
#       Asid:     the open_stateid to be returned
#       Aoseqid:  the open_seqid to be returned
#       Astatus:  the compound status to be returned
#       seqid:    the original seqid for OPEN, default 1
#       close:    flag to CLOSE the file or not, default "not to close"
#       mode:     the file mode for file creation, default 664
#       size:     the file size for file creation, default 0
#       access:   the file access to open the file, default READ/WRITE
#	deny:	  the file deny mode to open the file, default NONE
#       ctype:	  the createtype, default 0
#
#  Return: 
#       nfh: the new filehandle for the opened file
#       -1:  if OPEN failed during the process.
#       -2:  if CLOSE failed during the process.
#
proc basic_open {dfh fname otype cid_owner Asid Aoseqid Astatus \
    {seqid 1} {close 0} {mode 664} {size 0} {access 3} {deny 0} {ctype 0} } {
	global OPEN4_RESULT_CONFIRM
	upvar 1 $Asid stateid
	upvar 1 $Aoseqid oseqid
	upvar 1 $Astatus status

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	} else {
		set tag "basic_open"
	}
	set oseqid $seqid
	putmsg stdout 1 "  basic_open: Open $oseqid $access $deny $cid_owner"
	putmsg stdout 1 "\t\t$otype $ctype, mode $mode, size $size, 0 $fname"
	set res [compound {Putfh $dfh;
		Open $oseqid $access $deny "$cid_owner" \
			{$otype $ctype {{mode $mode} {size 0}}} {0 $fname};
		Getfh}]
	if {$status != "OK"} {
                putmsg stdout 1 "  basic_open: Open failed, status=($status)."
                putmsg stdout 1 "\tRes: $res"
                return -1
        }
        set stateid [lindex [lindex $res 1] 2]
        set rflags [lindex [lindex $res 1] 4] 
        set nfh [lindex [lindex $res 2] 2]
        # do open_confirm if needed, e.g. rflags has OPEN4_RESULT_CONFIRM set
        if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
            incr oseqid
            putmsg stderr 1 "  basic_open: Open_confirm $stateid $oseqid"
            set res [compound {Putfh $nfh; Open_confirm $stateid $oseqid}]
            if {$status != "OK"} {
		putmsg stdout 1 \
		    "  basic_open: Open_confirm failed, status=($status)."
		putmsg stdout 1 "\tRes: $res"
		return -2
	    }
	    set stateid [lindex [lindex $res 1] 2]
        }

	# set the size if caller specifies file(create) and size>0
	if { ($otype == 1) && ($size > 0) } {
            putmsg stderr 1 "  basic_open: Setattr $stateid {{size $size}}"
            set res [compound {Putfh $nfh; Setattr $stateid {{size $size}}}]
            if {$status != "OK"} {
                putmsg stderr 1 "  basic_open: Setattr failed, status=($status)"
		putmsg stdout 1 "\tRes: $res"
		return -5
	    }
        }

	# if caller specify "close=1", Close the file as well.
	if {$close == 1} {
            incr oseqid
            putmsg stderr 1 "  basic_open: Close $oseqid $stateid"
            set res [compound {Putfh $nfh; Close $oseqid $stateid}]
            if {$status != "OK"} {
                putmsg stderr 1 "  basic_open: Close failed, status=($status)."
		putmsg stdout 1 "\tRes: $res"
		return -3
	    }
        }

        return $nfh
}


#----------------------------------------------------------------------------
#
# creatv4_file  - This proc receives a full file name (path included) and
#       optionally file parameters, to create a remote file via open. 
#       Optional parameters are file creation mode and file size.
#       Returned value is NULL (0) if fails, or the filehandle of the new
#       file if sucessful.
#
proc creatv4_file {apath {mode 664} {size 0}} {
        global NULL env OPEN4_RESULT_CONFIRM
        global DELM

        # convert pathname to list, store filename and path separated;
        set path [ path2comp $apath $DELM ]
        set pathlen [expr [llength $path] -1]
        set filename [lindex $path $pathlen]
        set pathdir [lrange $path 0 [expr $pathlen - 1]]
                                                                          
	putmsg stdout 1 "  creatv4_file $apath $mode $size"
        putmsg stdout 1 "\nfilename=$filename"
        putmsg stdout 1 "pathdir=$pathdir"

        # check if file is there (it should not, we want to create it)
        set fh [get_fh $path]
        if {$fh != ""} {
                putmsg stderr 0 "File $apath already exists, no action taken."
                return $NULL
        }

        # set string id (this is unique for each execution)
        set id_string \
	    "[clock clicks] [expr int([expr [expr rand()] * 100000000])]]"

        # negotiate cleintid
	set clientid [getclientid $id_string]
        if {$clientid == -1} {
                putmsg stderr 0 "Unable to set clientid."
                return $NULL
        }
                                                             
        set dfh [get_fh $pathdir]
        if {$dfh == ""} {
                putmsg stderr 0 " Failed to get path directory FH."
                return $NULL
        }
        # Now create the file with OPEN
        set opentype		1
	set createmode          0
        set seqid 1
	set nfh [basic_open $dfh $filename $opentype "$clientid $id_string" \
		open_sid oseqid status $seqid 1 $mode $size]
        putmsg stdout 1 "Open call with argument list:"
        putmsg stdout 1 "  $seqid 3 0 {$clientid $id_string}"
        putmsg stdout 1 "  {$opentype $createmode {{mode $mode} {size $size}}}"
        putmsg stdout 1 "  {0 $filename}"
	if {($nfh < 0) && ($status != "OK")} {
        	putmsg stderr 0 "\t  basic_open failed, got status=($status)"
                return $NULL
        }

        return $nfh
}

#-----------------------------------------------------------------------
# Procedure to create a directory. Returns handle for directory or NULL. 
# 
proc creatv4_dir {dpath {mode 777} } { 
        global DELM 
 
        # convert pathname to list 
        set path [ path2comp $dpath $DELM ] 
        set pathlen [expr [llength $path] -1] 
        set dir_name [lindex $path $pathlen] 
        set pathdir [lrange $path 0 [expr $pathlen - 1]] 
 
        putmsg stdout 1 "  creatv4_dir $dpath $dir_name $mode" 
        putmsg stdout 1 "\ndir_name=$dir_name" 
        putmsg stdout 1 "pathdir=$pathdir" 
 
        set dfh [get_fh $pathdir] 
        if {$dfh == ""} { 
                putmsg stderr 0 " Failed to get path directory FH for dir creation." 
                return $NULL 
        } 
 
        # Now create the directory. 
        set res [compound {Putfh $dfh; Create $dir_name {{mode $mode}} d; Getfh} ] 
        if {$status != "OK"} { 
                putmsg stderr 0 \ 
                        " creatv4_dir: Directory creation failed, status=($status)." 
                putmsg stdout 0 "\tRes: $res" 
                return $NULL 
        } 
 
        set dfh [lindex [lindex $res 2] 2] 
        return $dfh 
 
} 
 

#-----------------------------------------------------------------------
# Procedure to find if the server is still in the grace period
#
#  Usage: chk_grace [wait_to_expire]
#       wait_to_expire  any value different from 0 causes the routine
#                       to wait until the grace period expires
#
#  Return:
#       GRACE if server is during the grace period, OK, if not, or status code
#       on error.
#

proc chk_grace {{wait_to_expire 1}} {
	global env

	set fh [get_fh "$::BASEDIRS $env(TEXTFILE)"]
	set stateid {0 0}
	# use the lease time, as the approximation of the grace period
	set delay $env(LEASE_TIME)
	if {$delay <= 0} {
		set delay 90
	}
	set magic_time [expr $delay/4 * 1000]

	set counter 0
	# once is used to enter the loop unconditionally the first time
	# at that point, the rest of the loops depend on wait_to_expire only
	set once 1
	while {$wait_to_expire != 0 || $once == 1} {
		set once 0
		set res [compound {Putfh $fh; Read $stateid 0 16}]
		# only OK or GRACE are expected
		# or if in grace period, check if want to wait
		if {$status == "OK" || $status != "GRACE" || \
			$wait_to_expire == 0} {
			return $status
		}
		# If still in grace, wait for 1/4 of the grace period,
		#   and try again
		after $magic_time
		# loop for one lease period only
		incr counter
		if {$counter >= 4} {
			return $status
		}
	}
}

#---------------------------------------------------------
# Generic test procedure to connect to a nfsv4 server
#  Usage: Connect runname
#       runname:	the test run name of calling program
#				(default to the basename of pwd)
#	Also, it uses the following globals that must be set
#	  SERVER	nfsv4 server to connect to
#	  TRANSPORT	tcp or udp
#	  PORT		nfsv4 server port
#	  UNINITIATED	error code in case normal initialization failed
#	  DELM		the path delimiter
#
#  Return: 
#       nothing
#

proc Connect { {runname ""} {do_grace 1} } {
	global PORT TRANSPORT SERVER UNINITIATED DELM env TMPDIR

	if {$runname == ""} {
		set runname [lindex [split [pwd] $DELM] end]
	}
	putmsg stdout 1 "Connect {$SERVER $TRANSPORT $PORT}"
	# connect to the test server
	if {[catch {connect -p ${PORT} -t ${TRANSPORT} ${SERVER}} msg]} {
		putmsg stderr 0 "$runname{init}: Setup ${TRANSPORT} connection"
		putmsg stderr 0 \
			"\t Test UNINITIATED: unable to connect to $SERVER"
		putmsg stderr 0 $msg
		exit $UNINITIATED
	}
	# check if server in grace once only
	set filename [file join $TMPDIR "SERVER_NOT_IN_GRACE"]
	if {![file exist $filename]} {
		set fd [open $filename "w+" 0775]
		close $fd
		set grace 1
		while {$do_grace == 1 && $grace > 0} {
			set res [chk_grace]
			if {$res == "OK"} {
				break
			}
			if {$res != "GRACE"} {
				putmsg stderr 0 \
	"$runname{all}: error while checking if server in GRACE (got $res)"
				putmsg stderr 0 "	Test UNINITIATED"
				exit $UNINITIATED
			}
			incr grace
			# try 10 times (10 lease_periods)
			if {$grace > 10}   {
				putmsg stderr 0 \
	"$runname{all}: error server did not exit grace in 10 lease periods"
				putmsg stderr 0 "	Test UNINITIATED"
				exit $UNINITIATED
			}
		}
	}
}

#-----------------------------------------------------------------------
# Generic test procedure to disconnect from the nfsv4 server
#	and wait for a period of time.
#
#  Usage: Connect [waiting_time]
#	waiting_time	delay after disconnect, default 0
#
#  Return: 
#       nothing
#

proc Disconnect {{wait_for 0}} {
	putmsg stdout 1 "Disconnect $wait_for"
	#Disconnect and wait for specified number of seconds
	disconnect
	after [expr $wait_for * 1000]
}

#-----------------------------------------------------------------------
# Procedure to get the domain for machine.
#
#  Usage: get_domain machine [dns_server]
#	machine		machine name to get the domain
#	dns_server	in case getent does not use FQDN, DNS domain is used,
#			default server is environment var DNS_SERVER
#
#  Return: 
#	machine's domain if successful, or NULL on failure.
#

proc get_domain {machine {dns_server $::env(DNS_SERVER)}} {
	global NULL
	set mns ""
	set domain ""
	set machine [string tolower $machine]

	#first attempt to get the live domain from machine:/var/run/nfs4_domain
	if {[catch {exec rsh -n -l root $machine \
		"cat /var/run/nfs4_domain"} mns]} {
		putmsg stdout 1 "\trsh failed ($mns), trying DNS domain ..."
	} else {
		putmsg stdout 1 "\treturned $mns"
		set domain $mns
		# rsh will not fail when grep failed. 
		if {$domain != ""} {
			return $domain
		}
	}

	putmsg stdout 1 "\ncall to <get_domain $machine $dns_server>"
	set ns "dig"
	putmsg stdout 1 "getent hosts $machine"
	if {[catch {exec sh -c \
		"getent hosts $machine"} mns]} {
		putmsg stdout 1 "\tfailed ($mns), returning NULL"
		return $NULL
	}
	putmsg stdout 1 "\treturned $mns"

        set ipaddr [lrange [split $mns] 0 0]
        
	putmsg stdout 1 \
                   "$ns @$dns_server +noqu -x $ipaddr 2>&1 | grep 'PTR'"
	if {[catch {exec sh -c \
                    "$ns @$dns_server +noqu -x $ipaddr 2>&1 | grep 'PTR'"} \
                    names]} {
	   	    putmsg stdout 1 "\tfailed ($names), returning NULL"
		    return $NULL
	}
	putmsg stdout 1 "\treturned $names"

	set name ""
	set names [lrange [split $names] 1 end]
	if {[llength $names] == 1} {
		set name $names
		putmsg stdout 1 "$ns for $machine returned <$name>"
	} else {
		foreach i $names {
			putmsg stdout 1 "looking for $machine in $i"
			set lname [string tolower $i]
			if {[string first $machine $lname] != -1} {
				set name $lname
				break
			}
		}
	}
	if {$name == ""} {
		putmsg stdout 1 "warning $machine not in {$names}"
		return $NULL
	}
       
	set name [lrange [split $name "."] 1 end]
	putmsg stdout 1 "domain in list form <$name>"
	set domain [lindex $name 0]
	if {[llength $name] > 1} {	
		foreach i [lrange $name 1 end] {
			set domain "$domain.$i"
		}
	}

        set domain [string trim $domain .]

	putmsg stdout 1 "\n\nThe domain for $machine is $domain\n\n"
	return $domain
}

#-----------------------------------------------------------------------
# Procedure to test if seqid should be incremented based on status
#
#  Usage: should_seqid_incr status_code
#	status_code	status code returned by compound
#
#  Return: 
#	0 if seqid should not be incremented, 1 otherwise
#

proc should_seqid_incr {status_code} {
	 set bad_errors "BAD_SEQID BAD_STATEID STALE_STATEID STALE_CLIENTID \
NOFILEHANDLE BADXDR RESOURCE"
        if {[lsearch $bad_errors $status_code] == -1} {
		return 1
	} else {
		return 0
	}
}

#-----------------------------------------------------------------------
# Procedure to check if there is a CIPSO connection
# This is for Trusted Extensions testing.
#
#  Usage: is_cipso <node name>
#
#  Return: 
#	false if there is NOT a cipso connection
#	true if there is a cipso connection
#

proc is_cipso { nodename } {
	if {[catch {exec sh -c \
	    "/bin/test -x /usr/sbin/tninfo 2>/dev/null"}]} {
		return false
	}
	if {[catch {exec sh -c \
	    "/usr/sbin/tninfo -h $nodename | grep cipso 2>/dev/null"}]} {
		return false
	}
	return true
}

#-----------------------------------------------------------------------
# Procedure to get the current system time on both server and client
#
#  Usage: get_sctime <server> <client>
#
#  Return: 
#        string 
#

proc get_sctime { server client } {
	global DEBUG
	set srvSysTime  [exec rsh -n -l root $server "date"]
	set clntSysTime [clock seconds]
	set clntSysTime [clock format $clntSysTime]
	set retStr "server: $server, client: $client"
	set retStr "$retStr\n\tcurrent server time: $srvSysTime"
	set retStr "$retStr\n\tcurrent client time: $clntSysTime"
}

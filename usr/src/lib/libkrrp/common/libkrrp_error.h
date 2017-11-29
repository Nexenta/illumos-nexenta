/*
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 */

/*
 * Copyright 2017 Nexenta Systems, Inc. All rights reserved.
 */

#ifndef	_LIBKRRP_ERROR_H
#define	_LIBKRRP_ERROR_H

#include <sys/nvpair.h>

#include "libkrrp.h"
#include "krrp_error.h"

#ifdef	__cplusplus
extern "C" {
#endif

typedef enum {
	LIBKRRP_SESS_ERROR,
	LIBKRRP_SRV_ERROR,
	LIBKRRP_SESS_STATUS_ERROR
} libkrrp_error_type_t;

#define	LIBKRRP_ERRDESCR_EXPAND(m_libkrrp_errno, m_unix_errno, m_descr, ...) \
	    libkrrp_error_cmp(libkrrp_errno, LIBKRRP_ERRNO_##m_libkrrp_errno, \
	    unix_errno, m_unix_errno, flags, (char *)descr, \
	    m_descr, ##__VA_ARGS__) ||

#define	SET_ERROR_DESCR(X) (void) (X(LIBKRRP_ERRDESCR_EXPAND) B_FALSE)

#define	LIBKRRP_EMSG_IOCTLFAIL "ioctl failed (%s)"
#define	LIBKRRP_EMSG_SVCACTIVE "Service is already enabled"
#define	LIBKRRP_EMSG_SVCNOTACTIVE "Service is not enabled"
#define	LIBKRRP_EMSG_NOTSUP "Operation is not supported"
#define	LIBKRRP_EMSG_IOCTLDATAFAIL "Failed to unpack ioctl data"
#define	LIBKRRP_EMSG_EVBINDFAIL "Failed to bind to KRRP event channel"
#define	LIBKRRP_EMSG_EVSUBSCRIBEFAIL "Failed to subscribe to KRRP event channel"
#define	LIBKRRP_EMSG_EVREADFAIL "Failed to read event data"
#define	LIBKRRP_EMSG_BUSY "KRRP service is busy"
#define	LIBKRRP_EMSG_SESSID_NOENT "Session ID not specified"
#define	LIBKRRP_EMSG_SESSID_INVAL "Invalid session id"
#define	LIBKRRP_EMSG_SESSERR_INVAL "Invalid session error"
#define	LIBKRRP_EMSG_KSTATID_NOENT "kstat ID not specified"
#define	LIBKRRP_EMSG_KSTATID_INVAL "kstat ID must be %d characters in length"
#define	LIBKRRP_EMSG_SESS_ALREADY "Session already exists"
#define	LIBKRRP_EMSG_SESS_NOENT "Session does not exist"
#define	LIBKRRP_EMSG_SESS_NODATA1 "Session private data not specified"
#define	LIBKRRP_EMSG_SESS_NODATA2 "Session private data does not exist"
#define	LIBKRRP_EMSG_HOST_NOENT "Remote host is not specified"
#define	LIBKRRP_EMSG_SESS_BUSY "Session is busy"
#define	LIBKRRP_EMSG_HOST_INVAL "Invalid remote host"
#define	LIBKRRP_EMSG_ADDR_INVAL "Invalid listening address"
#define	LIBKRRP_EMSG_PORT_NOENT "Remote port not specified"
#define	LIBKRRP_EMSG_PORT_INVAL "Remote port must be in range (%d .. %d)"
#define	LIBKRRP_EMSG_SESS_CONN_ALREADY "Session connection already exists"
#define	LIBKRRP_EMSG_CREATEFAIL "Failed to create socket (%s)"
#define	LIBKRRP_EMSG_SETSOCKOPTFAIL "Failed to set socket options (%s)"
#define	LIBKRRP_EMSG_CONNFAIL "Failed to connect socket (%s)"
#define	LIBKRRP_EMSG_SENDFAIL "Failed to send data (%s)"
#define	LIBKRRP_EMSG_RECVFAIL "Failed to receive data (%s)"
#define	LIBKRRP_EMSG_UNEXPCLOSE "Connection unexpectedly closed"
#define	LIBKRRP_EMSG_UNEXPEND "Connection unexpectedly ended"
#define	LIBKRRP_EMSG_AUTH_NOENT "Authentication data not specified"
#define	LIBKRRP_EMSG_BADRESP "Unexpected response has been received"
#define	LIBKRRP_EMSG_NOMEM "Not enough space"
#define	LIBKRRP_EMSG_BIGPAYLOAD "Payload is too big"
#define	LIBKRRP_EMSG_SESS_PDUENGINE_ALREADY "PDU engine already exists"
#define	LIBKRRP_EMSG_DBLKSZ_NOENT "dblk size not specified"
#define	LIBKRRP_EMSG_DBLKSZ_INVAL "dblk size must be in range (%d .. %d)"
#define	LIBKRRP_EMSG_MAXMEMSZ_NOENT "Maximum memory size not specified"
#define	LIBKRRP_EMSG_MAXMEMSZ_INVAL "Maximum memory size cannot be less than %d"
#define	LIBKRRP_EMSG_SESS_PDUENGINE_NOMEM "Failed to preallocate PDUs"
#define	LIBKRRP_EMSG_FAKEDSZ_NOENT "Fake stream size not specified"
#define	LIBKRRP_EMSG_FAKEDSZ_INVAL "Fake stream size cannot be 0"
#define	LIBKRRP_EMSG_ZFSGCTXFAIL "Failed to initialize global ZFS context"
#define	LIBKRRP_EMSG_SRCDS_NOENT "Source dataset not specified"
#define	LIBKRRP_EMSG_SRCDS_INVAL "Invalid source dataset"
#define	LIBKRRP_EMSG_SRCSNAP_INVAL "Invalid source snapshot"
#define	LIBKRRP_EMSG_CMNSNAP_INVAL "Invalid common snapshot"
#define	LIBKRRP_EMSG_SESS_STREAM_ALREADY "Session stream already exists"
#define	LIBKRRP_EMSG_DSTDS_NOENT "Destination dataset not specified"
#define	LIBKRRP_EMSG_DSTDS_INVAL "Invalid destination dataset"
#define	LIBKRRP_EMSG_SESS_STARTED "Session already started"
#define	LIBKRRP_EMSG_SESS_CONN_NOENT "Session connection does not exist"
#define	LIBKRRP_EMSG_SESS_PDUENGINE_NOENT "Session PDU engine does not exist"
#define	LIBKRRP_EMSG_STREAM_NOENT "Stream does not exist"
#define	LIBKRRP_EMSG_STREAM_EOPNOTSUPP "The source dataset for continuous " \
	    "replication must not have WBC enabled parents"
#define	LIBKRRP_EMSG_SNAP_NAMES_EQUAL \
	    "Source and common snapshots have the same name"
#define	LIBKRRP_EMSG_SESS_RUN_ONCE_INCOMPAT \
	    "Cannot run non-continuous stream once"
#define	LIBKRRP_EMSG_SRCDS_NOTEXIST "Source dataset does not exist"
#define	LIBKRRP_EMSG_DSTDS_NOTEXIST "Destination dataset does not exist"
#define	LIBKRRP_EMSG_SRCSNAP_NOTEXIST "Source snapshot does not exist"
#define	LIBKRRP_EMSG_CMNSNAP_NOTEXIST "Common snapshot does not exist"
#define	LIBKRRP_EMSG_SESS_THROTTLE_RECV \
	    "Throttle limit can be set only for sender session"
#define	LIBKRRP_EMSG_SESS_SEND_STOP_ALREADY "Session is already stopping"
#define	LIBKRRP_EMSG_SESS_SEND_STOP_RECV "Cannot stop session " \
	    "at the receiver side"
#define	LIBKRRP_EMSG_SESS_NOTACTIVE "Session is not running"
#define	LIBKRRP_EMSG_CFGTYPE_NOENT "Configuration type not specified"
#define	LIBKRRP_EMSG_CFGTYPE_INVAL "Invalid configuration type"
#define	LIBKRRP_EMSG_BINDFAIL "Failed to bind socket (%s)"
#define	LIBKRRP_EMSG_LISTENFAIL "Failed to listen socket (%s)"
#define	LIBKRRP_EMSG_LSTPORT_NOENT "Listening port is not defined"
#define	LIBKRRP_EMSG_LSTPORT_INVAL "Listenng port must be in range (%d .. %d)"
#define	LIBKRRP_EMSG_SRVRECONF "Server is in re-configuring state"
#define	LIBKRRP_EMSG_SRVNOTRUN "Server is not running"
#define	LIBKRRP_EMSG_SESSPINGTIMEOUT "Session ping timeout"
#define	LIBKRRP_EMSG_OK "No error"
#define	LIBKRRP_EMSG_UNKNOWN "Unknown error"
#define	LIBKRRP_EMSG_NOORIGIN "Destination does not have origin snapshot"
#define	LIBKRRP_EMSG_WRITEFAIL "Session write stream error (%s)"
#define	LIBKRRP_EMSG_SNAPMISMATCH "Most recent snapshot does not match " \
	    "incremental source"
#define	LIBKRRP_EMSG_DESTMODIFIED "Destination has been modified since most " \
	    "recent snapshot"
#define	LIBKRRP_EMSG_DESTEXISTS "Destination already exists"
#define	LIBKRRP_EMSG_WRITEINVAL "Invalid stream"
#define	LIBKRRP_EMSG_CHKSUMMISMATCH "Invalid stream (checksum mismatch)"
#define	LIBKRRP_EMSG_OLDPOOL "Pool must be upgraded to receive this stream"
#define	LIBKRRP_EMSG_DESTQUOTA "Destination space quota exceeded"
#define	LIBKRRP_EMSG_DESTNOSPACE "Destination is out of space"
#define	LIBKRRP_EMSG_READFAIL "Session read stream error (%s)"
#define	LIBKRRP_EMSG_NOTEARLIERSNAP \
	    "Not an earlier snapshot from the same fs"
#define	LIBKRRP_EMSG_SENDMBLKFAIL "ksocket_sendmblk error (%s)"
#define	LIBKRRP_EMSG_SNAPFAIL "Failed to create snapshot (%s)"
#define	LIBKRRP_EMSG_CONNTIMEOUT_INVAL \
	    "Connection timeout must be in range (%d .. %d)"
#define	LIBKRRP_EMSG_REMOTE_NODE_ERROR "remote node error"
#define	LIBKRRP_EMSG_THROTTLE_NOENT "Throttle limit not specified"
#define	LIBKRRP_EMSG_THROTTLE_INVAL \
	    "Throttle limit must be 0 or greater than or equal to %d"
#define	LIBKRRP_EMSG_AUTOSNAP_INVAL \
	    "Impossible to activate ZFS Autosnap for given dataset"
#define	LIBKRRP_EMSG_SESS_CREATE_WRITE_STREAM_FAIL \
	    "Cannot create write stream for sender session"
#define	LIBKRRP_EMSG_SESS_CREATE_READ_STREAM_FAIL \
	    "Cannot create read stream for receiver or fake compound session"
#define	LIBKRRP_EMSG_SESS_CREATE_INVAL "Cannot create compound session with " \
	    "the sender flag or the authentication digest"
#define	LIBKRRP_EMSG_SESS_CREATE_CONN_INVAL \
	    "Cannot create connection for compound session"

#define	LIBKRRP_EMSG_RESUMETOKEN_INVAL \
	    "Resume token is corrupt (invalid format)"
#define	LIBKRRP_EMSG_RESUMETOKEN_ENOTSUP \
	    "Resume token is corrupt (invalid version)"
#define	LIBKRRP_EMSG_RESUMETOKEN_EBADMSG \
	    "Resume token is corrupt (payload is not hex-encoded)"
#define	LIBKRRP_EMSG_RESUMETOKEN_ECKSUM \
	    "Resume token is corrupt (incorrect checksum failed)"
#define	LIBKRRP_EMSG_RESUMETOKEN_ENOSR \
	    "Resume token is corrupt (decompression failed)"
#define	LIBKRRP_EMSG_RESUMETOKEN_ENODATA \
	    "Resume token is corrupt (nvlist_unpack failed)"

#define	LIBKRRP_EMSG_SKIP_SNAPS_MASK_EINVAL \
	    "Skip snapshots mask is invalid"
#define	LIBKRRP_EMSG_SKIP_SNAPS_MASK_EMSGSIZE \
	    "Skip snapshots mask is too long"
#define	LIBKRRP_EMSG_SKIP_SNAPS_MASK_ENAMETOOLONG \
	    "Skip snapshots mask (property name) is too long"
#define	LIBKRRP_EMSG_SKIP_SNAPS_MASK_E2BIG \
	    "Skip snapshots mask (property value) is too long"

#define	LIBKRRP_EMSG_RUN_ONCE_RECV "Impossible to use the option 'run-once' " \
	    "at the receiver side"
#define	LIBKRRP_EMSG_STREAM_POOL_FAULT "Failed to read configuration of " \
	    "target ZFS pool"
#define	LIBKRRP_EMSG_SESS_CREATE_AUTH_INVAL "Authentication digest " \
	    "must not be greater than %d characters in length"
#define	LIBKRRP_EMSG_DSNAMETOOLONG "Failed to create autosnapshot: " \
	    "dataset name too long"
#define	LIBKRRP_EMSG_CANNOT_STOP_SESS "Cannot stop non-continuous session"
#define	LIBKRRP_EMSG_SESS_CREATE_CONN_AUTH_INVAL "Invalid authentication digest"
#define	LIBKRRP_EMSG_KEEPSNAPS_INVAL \
	    "The number of keep snapshots must be in range (%d .. %d)"
#define LIBKRRP_EMSG_SESS_ENOTSUP \
	    "Operation is not supported for this type of session"
#define LIBKRRP_EMSG_PROPS_INVAL "Failed to validate ZFS properties"
#define LIBKRRP_EMSG_PROPS_ENOMEM "Failed to initialize ZFS library"

#define	libkrrp_error_init(error) (void) memset(error, 0, \
	    sizeof (libkrrp_error_t));

#define	LIBKRRP_ERRDESCR_MAP(X) \
	X(SVCNOTACTIVE, 0, LIBKRRP_EMSG_SVCNOTACTIVE) \
	X(SVCACTIVE, 0, LIBKRRP_EMSG_SVCACTIVE) \
	X(IOCTLFAIL, 0, LIBKRRP_EMSG_IOCTLFAIL, \
	    krrp_unix_errno_to_str(unix_errno)) \
	X(NOTSUP, 0, LIBKRRP_EMSG_NOTSUP) \
	X(IOCTLDATAFAIL, 0, LIBKRRP_EMSG_IOCTLDATAFAIL) \
	X(KSTATID, EINVAL, LIBKRRP_EMSG_KSTATID_INVAL, \
	    KRRP_KSTAT_ID_STRING_LENGTH - 1) \
	X(NOMEM, 0, LIBKRRP_EMSG_NOMEM) \
	X(SESSID, EINVAL, LIBKRRP_EMSG_SESSID_INVAL) \
	X(SESSID, ENOENT, LIBKRRP_EMSG_SESSID_NOENT) \
	X(SESSERR, EINVAL, LIBKRRP_EMSG_SESSERR_INVAL) \
	X(OK, 0, LIBKRRP_EMSG_OK) \
	X(EVBINDFAIL, 0, LIBKRRP_EMSG_EVBINDFAIL) \
	X(EVSUBSRIBEFAIL, 0, LIBKRRP_EMSG_EVSUBSCRIBEFAIL) \
	X(EVREADFAIL, 0, LIBKRRP_EMSG_EVREADFAIL) \
	X(PROPS, EINVAL, LIBKRRP_EMSG_PROPS_INVAL) \
	X(PROPS, ENOMEM, LIBKRRP_EMSG_PROPS_ENOMEM) \

#define	UNIX_ERRNO_MAP(X) \
	X(EPERM)	/* Not super-user			*/ \
	X(ENOENT)	/* No such file or directory		*/ \
	X(ESRCH)	/* No such process			*/ \
	X(EINTR)	/* interrupted system call		*/ \
	X(EIO)		/* I/O error				*/ \
	X(ENXIO)	/* No such device or address		*/ \
	X(E2BIG)	/* Arg list too long			*/ \
	X(ENOEXEC)	/* Exec format error			*/ \
	X(EBADF)	/* Bad file number			*/ \
	X(ECHILD)	/* No children				*/ \
	X(EAGAIN)	/* Resource temporarily unavailable	*/ \
	X(ENOMEM)	/* Not enough core			*/ \
	X(EACCES)	/* Permission denied			*/ \
	X(EFAULT)	/* Bad address				*/ \
	X(ENOTBLK)	/* Block device required		*/ \
	X(EBUSY)	/* Mount device busy			*/ \
	X(EEXIST)	/* File exists				*/ \
	X(EXDEV)	/* Cross-device link			*/ \
	X(ENODEV)	/* No such device			*/ \
	X(ENOTDIR)	/* Not a directory			*/ \
	X(EISDIR)	/* Is a directory			*/ \
	X(EINVAL)	/* Invalid argument			*/ \
	X(ENFILE)	/* File table overflow			*/ \
	X(EMFILE)	/* Too many open files			*/ \
	X(ENOTTY)	/* Inappropriate ioctl for device	*/ \
	X(ETXTBSY)	/* Text file busy			*/ \
	X(EFBIG)	/* File too large			*/ \
	X(ENOSPC)	/* No space left on device		*/ \
	X(ESPIPE)	/* Illegal seek				*/ \
	X(EROFS)	/* Read only file system		*/ \
	X(EMLINK)	/* Too many links			*/ \
	X(EPIPE)	/* Broken pipe				*/ \
	X(EDOM)		/* Math arg out of domain of func	*/ \
	X(ERANGE)	/* Math result not representable	*/ \
	X(ENOMSG)	/* No message of desired type		*/ \
	X(EIDRM)	/* Identifier removed			*/ \
	X(ECHRNG)	/* Channel number out of range		*/ \
	X(EL2NSYNC)	/* Level 2 not synchronized		*/ \
	X(EL3HLT)	/* Level 3 halted			*/ \
	X(EL3RST)	/* Level 3 reset			*/ \
	X(ELNRNG)	/* Link number out of range		*/ \
	X(EUNATCH)	/* Protocol driver not attached		*/ \
	X(ENOCSI)	/* No CSI structure available		*/ \
	X(EL2HLT)	/* Level 2 halted			*/ \
	X(EDEADLK)	/* Deadlock condition.			*/ \
	X(ENOLCK)	/* No record locks available.		*/ \
	X(ECANCELED)	/* Operation canceled			*/ \
	X(ENOTSUP)	/* Operation not supported		*/ \
\
	/* Filesystem Quotas */ \
	X(EDQUOT)	/* Disc quota exceeded			*/ \
\
	/* Convergent Error Returns */ \
	X(EBADE)	/* invalid exchange			*/ \
	X(EBADR)	/* invalid request descriptor		*/ \
	X(EXFULL)	/* exchange full			*/ \
	X(ENOANO)	/* no anode				*/ \
	X(EBADRQC)	/* invalid request code			*/ \
	X(EBADSLT)	/* invalid slot				*/ \
	X(EDEADLOCK)	/* file locking deadlock error		*/ \
\
	X(EBFONT)	/* bad font file fmt			*/ \
\
	/* Interprocess Robust Locks */ \
	X(EOWNERDEAD)	/* process died with the lock 		*/ \
	X(ENOTRECOVERABLE)	/* lock is not recoverable 	*/ \
\
	/* stream problems */ \
	X(ENOSTR)	/* Device not a stream			*/ \
	X(ENODATA)	/* no data (for no delay io)		*/ \
	X(ETIME)	/* timer expired			*/ \
	X(ENOSR)	/* out of streams resources		*/ \
\
	X(ENONET)	/* Machine is not on the network	*/ \
	X(ENOPKG)	/* Package not installed		*/ \
	X(EREMOTE)	/* The object is remote			*/ \
	X(ENOLINK)	/* the link has been severed		*/ \
	X(EADV)		/* advertise error			*/ \
	X(ESRMNT)	/* srmount error			*/ \
\
	X(ECOMM)	/* Communication error on send		*/ \
	X(EPROTO)	/* Protocol error			*/ \
\
	/* Interprocess Robust Locks */ \
	X(ELOCKUNMAPPED)	/* locked lock was unmapped	*/ \
\
	X(ENOTACTIVE)	/* Facility is not active		*/ \
	X(EMULTIHOP)	/* multihop attempted			*/ \
	X(EBADMSG)	/* trying to read unreadable message	*/ \
	X(ENAMETOOLONG)	/* path name is too long		*/ \
	X(EOVERFLOW)	/* value too large to be stored in data type */ \
	X(ENOTUNIQ)	/* given log. name not unique		*/ \
	X(EBADFD)	/* f.d. invalid for this operation	*/ \
	X(EREMCHG)	/* Remote address changed		*/ \
\
	/* shared library problems */ \
	X(ELIBACC)	/* Can't access a needed shared lib.	*/ \
	X(ELIBBAD)	/* Accessing a corrupted shared lib.	*/ \
	X(ELIBSCN)	/* .lib section in a.out corrupted.	*/ \
	X(ELIBMAX)	/* Attempting to link in too many libs.	*/ \
	X(ELIBEXEC)	/* Attempting to exec a shared library.	*/ \
	X(EILSEQ)	/* Illegal byte sequence.		*/ \
	X(ENOSYS)	/* Unsupported file system operation	*/ \
	X(ELOOP)	/* Symbolic link loop			*/ \
	X(ERESTART)	/* Restartable system call		*/ \
	X(ESTRPIPE)	/* if pipe/FIFO, don't sleep in stream head */ \
	X(ENOTEMPTY)	/* directory not empty			*/ \
	X(EUSERS)	/* Too many users (for UFS)		*/ \
\
	/* BSD Networking Software argument errors 		*/ \
	X(ENOTSOCK)	/* Socket operation on non-socket 	*/ \
	X(EDESTADDRREQ)	/* Destination address required 	*/ \
	X(EMSGSIZE)	/* Message too long 			*/ \
	X(EPROTOTYPE)	/* Protocol wrong type for socket 	*/ \
	X(ENOPROTOOPT)	/* Protocol not available 		*/ \
	X(EPROTONOSUPPORT)	/* Protocol not supported 	*/ \
	X(ESOCKTNOSUPPORT)	/* Socket type not supported 	*/ \
	X(EOPNOTSUPP)	/* Operation not supported on socket */ \
	X(EPFNOSUPPORT)	/* Protocol family not supported 	*/ \
	X(EAFNOSUPPORT)	/* Address family not supported by protocol family */ \
	X(EADDRINUSE)	/* Address already in use */ \
	X(EADDRNOTAVAIL)	/* Can't assign requested address */ \
\
	/* operational errors */ \
	X(ENETDOWN)	/* Network is down 			*/ \
	X(ENETUNREACH)	/* Network is unreachable 		*/ \
	X(ENETRESET)	/* Network dropped connection because of reset */ \
	X(ECONNABORTED)	/* Software caused connection abort 	*/ \
	X(ECONNRESET)	/* Connection reset by peer 		*/ \
	X(ENOBUFS)	/* No buffer space available 		*/ \
	X(EISCONN)	/* Socket is already connected 		*/ \
	X(ENOTCONN)	/* Socket is not connected 		*/ \
	/* XENIX has 135 - 142 */ \
	X(ESHUTDOWN)	/* Can't send after socket shutdown 	*/ \
	X(ETOOMANYREFS)	/* Too many references: can't splice 	*/ \
	X(ETIMEDOUT)	/* Connection timed out 		*/ \
	X(ECONNREFUSED)	/* Connection refused 			*/ \
	X(EHOSTDOWN)	/* Host is down 			*/ \
	X(EHOSTUNREACH)	/* No route to host 			*/ \
	X(EALREADY)	/* operation already in progress 	*/ \
	X(EINPROGRESS)	/* operation now in progress 		*/ \
\
	/* SUN Network File System */ \
	X(ESTALE)	/* Stale NFS file handle 		*/ \

int libkrrp_error_from_nvl(nvlist_t *, libkrrp_error_t *);
void libkrrp_error_set(libkrrp_error_t *, libkrrp_errno_t, int, uint32_t);
boolean_t libkrrp_error_cmp(libkrrp_errno_t, libkrrp_errno_t, int, int, int,
    char *, char *, ...);
const char *krrp_unix_errno_to_str(int);
void libkrrp_common_error_description(libkrrp_error_type_t,
    libkrrp_error_t *, libkrrp_error_descr_t);
void libkrrp_set_error_description(libkrrp_handle_t *hdl, const char *descr);
#ifdef	__cplusplus
}
#endif

#endif	/* _LIBKRRP_ERROR_H */

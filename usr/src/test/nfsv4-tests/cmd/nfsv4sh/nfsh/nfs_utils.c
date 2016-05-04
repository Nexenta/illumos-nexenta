/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#include "nfs4_prot.h"
#include "nfstcl4.h"
#include "tcl.h"


/*
 * utility functions used by nfstcl client tool.
 */

/*
 * Return 1 if bitno is set in the bitmap
 */
int
getbit(bitmap4 *bmp, int bitno) {
	int inx = bitno / 32;
	int off = bitno % 32;

	if ((bmp->bitmap4_len == 0) ||
	    (inx > (bmp->bitmap4_len - 1)))
		return (0);

	return ((bmp->bitmap4_val[inx] & (1 << off)) != 0);
}

/*
 * Set a specific bit in the bitmap
 */
void
setbit(bitmap4 *bmp, int bitno) {
	int inx = bitno / 32;
	int off = bitno % 32;

	if ((bmp->bitmap4_len == 0) ||
	    (inx > (bmp->bitmap4_len - 1)))
		bmp->bitmap4_len = inx + 1;

	bmp->bitmap4_val[inx] |= 1 << off;
}

/*
 * Convert a binary string into a hexadecimal string
 */
char *
bin2hex(char *p, unsigned len)
/* char		*p;	 binary object to convert to a hex string */
/* unsigned	len;	 size of the binary object in bytes */
{
	int i, j;
	static char hbuff[2049];
	static char hexstr[] = "0123456789ABCDEF";
	char toobig = 0;
	static char toobigstr[] = "<Too Big>";

	/* check for buffer overflow and truncate to fit */
	if (len * 2 > sizeof (hbuff) - 1) {
		toobig++;
		len = (sizeof (hbuff) - sizeof (toobigstr) - 1)/ 2;
	}

	j = 0;
	/* convert to ascii */
	for (i = 0; i < len; i++) {
		hbuff[j++] = hexstr[p[i] >> 4	& 0x0f];
		hbuff[j++] = hexstr[p[i]	& 0x0f];
	}
	hbuff[j] = '\0';

	if (toobig) {
		hbuff[sizeof (hbuff) - strlen(toobigstr) - 1] = '\0';
		strcat(hbuff, toobigstr);
	}

	return (hbuff);
}

/*
 * Convert a hexadecimal string into a binary string
 */
char *
hex2bin(char *p, unsigned len)
/* char		*p;	hex string to convert  to a binary object */
/* unsigned	len;	size in bytes for result (binary object) */
{
	int i;
	int c1, c2;
	static char hbuff[1025]; /* XXX Max string is 1024 chars */
	char *op = hbuff;
	char *p2 = NULL;
	unsigned cur_len;
	static char inx[256];
	static int toobig = 0;
	char hexUpper[] = "0123456789ABCDEF";
	char hexLower[] = "0123456789abcdef";

	/* Build a mapping table */
	for (i = 0; i < 16; i++) {
		inx[hexUpper[i]] = i;
		inx[hexLower[i]] = i;
	}

	/* number of hex characters needed */
	len *= 2;

	/* check for buffer overflow and truncate to fit */
	cur_len = strlen(p);
	if (cur_len > (sizeof (hbuff) - 1)*2) {
		toobig++;
		cur_len = (sizeof (hbuff) - 1)*2;
	}
	if (len > (sizeof (hbuff) - 1)*2) {
		toobig++;
		len = (sizeof (hbuff) - 1)*2;
	}

	/* if needed pad with leading zeros */
	if (cur_len < len) {
		unsigned j = len - cur_len;

		p2 = malloc(len + 1);
		if (p2 == NULL) {
			perror("NOMEM");
			exit(1);
		}
		memset(p2, '0', j);
		p2[j] = '\0';
		strcat(p2, p);
		p = p2;
	}

	/* Now use the mapping table to map the chars to binary */
	while (*p) {
		if (strlen(p) == 1)
			c1 = 0;
		else
			c1 = inx[*p++] & 0x0f;
		c2 = inx[*p++] & 0x0f;
		*op++ = c1 << 4 | c2;
	}

	if (p2 != NULL)
		free(p2);

	return (hbuff);
}


/*
 * Convert an ASCII string to a UTF8 string.
 * XXX Currently this routine just copies the
 * string into a utf8string structure.
 */
utf8string *
str2utf8(char *str)
{
	utf8string *tmp;

	tmp = malloc(sizeof (utf8string));

	tmp->utf8string_val = (char *)strdup(str);
	tmp->utf8string_len = strlen(str);

	return (tmp);
}

/*
 * Convert a UTF8 string to a C string
 * XXX Currently this routine just copies the
 * string from a utf8string structure.
 */
char *
utf82str(utf8string u)
{
	char *str = malloc(u.utf8string_len + 1);

	(void) memcpy(str, u.utf8string_val, u.utf8string_len);
	*(str + u.utf8string_len) = '\0';

	return (str);
}

/*
 * Given the string list of components of the pathname,
 * convert them to pathname4 structure.
 */
int
str2pathname(Tcl_Interp *interp, char *strs, pathname4 *pn)
{
	int lc;
	char **lv;
	char buf[80];
	component4 *tmp;
	int i;

	/*
	 * Convert the "strs" (in the form of components,
	 * e.g. {export v4 file}) argument into an array
	 * of strings.
	 */
	if (Tcl_SplitList(interp, strs, &lc, (CONST84 char ***)&lv) != TCL_OK) {
		sprintf(buf, "str2pathname error, can't split {%s}", strs);
		interp->result = buf;
		return (TCL_ERROR);
	}

	tmp = calloc(lc, sizeof (component4 *));

	for (i = 0; i < lc; i++) {
		tmp[i] = *str2utf8(lv[i]);
	}

	pn->pathname4_len = lc;
	pn->pathname4_val = tmp;
	free((char *)lv);

	return (TCL_OK);
}

char *
errstr(nfsstat4 status)
{
	switch (status) {
	case NFS4_OK:			return "OK";
	case NFS4ERR_PERM: 		return "PERM";
	case NFS4ERR_NOENT: 		return "NOENT";
	case NFS4ERR_IO: 		return "IO";
	case NFS4ERR_NXIO: 		return "NXIO";
	case NFS4ERR_ACCESS: 		return "ACCESS";
	case NFS4ERR_EXIST: 		return "EXIST";
	case NFS4ERR_XDEV: 		return "XDEV";
	/* error slot reserved for error 19 */
	case NFS4ERR_NOTDIR: 		return "NOTDIR";
	case NFS4ERR_ISDIR: 		return "ISDIR";
	case NFS4ERR_INVAL: 		return "INVAL";
	case NFS4ERR_FBIG: 		return "FBIG";
	case NFS4ERR_NOSPC: 		return "NOSPC";
	case NFS4ERR_ROFS: 		return "ROFS";
	case NFS4ERR_MLINK: 		return "MLINK";
	case NFS4ERR_NAMETOOLONG:	return "NAMETOOLONG";
	case NFS4ERR_NOTEMPTY: 		return "NOTEMPTY";
	case NFS4ERR_DQUOT: 		return "DQUOT";
	case NFS4ERR_STALE: 		return "STALE";
	case NFS4ERR_BADHANDLE: 	return "BADHANDLE";
	case NFS4ERR_BAD_COOKIE:	return "BAD_COOKIE";
	case NFS4ERR_NOTSUPP: 		return "NOTSUPP";
	case NFS4ERR_TOOSMALL: 		return "TOOSMALL";
	case NFS4ERR_SERVERFAULT:	return "SERVERFAULT";
	case NFS4ERR_BADTYPE: 		return "BADTYPE";
	case NFS4ERR_DELAY: 		return "DELAY";
	case NFS4ERR_SAME: 		return "SAME";
	case NFS4ERR_DENIED: 		return "DENIED";
	case NFS4ERR_EXPIRED: 		return "EXPIRED";
	case NFS4ERR_LOCKED: 		return "LOCKED";
	case NFS4ERR_GRACE: 		return "GRACE";
	case NFS4ERR_FHEXPIRED: 	return "FHEXPIRED";
	case NFS4ERR_SHARE_DENIED:	return "SHARE_DENIED";
	case NFS4ERR_WRONGSEC: 		return "WRONGSEC";
	case NFS4ERR_CLID_INUSE: 	return "CLID_INUSE";
	case NFS4ERR_RESOURCE: 		return "RESOURCE";
	case NFS4ERR_MOVED: 		return "MOVED";
	case NFS4ERR_NOFILEHANDLE:	return "NOFILEHANDLE";
	case NFS4ERR_MINOR_VERS_MISMATCH:return "MINOR_VERS_MISMATCH";
	case NFS4ERR_STALE_CLIENTID: 	return "STALE_CLIENTID";
	case NFS4ERR_STALE_STATEID: 	return "STALE_STATEID";
	case NFS4ERR_OLD_STATEID: 	return "OLD_STATEID";
	case NFS4ERR_BAD_STATEID: 	return "BAD_STATEID";
	case NFS4ERR_BAD_SEQID: 	return "BAD_SEQID";
	case NFS4ERR_NOT_SAME: 		return "NOT_SAME";
	case NFS4ERR_LOCK_RANGE: 	return "LOCK_RANGE";
	case NFS4ERR_SYMLINK: 		return "SYMLINK";
	case NFS4ERR_RESTOREFH: 	return "RESTOREFH";
	case NFS4ERR_LEASE_MOVED: 	return "LEASE_MOVED";
	case NFS4ERR_ATTRNOTSUPP: 	return "ATTRNOTSUPP";
	case NFS4ERR_NO_GRACE: 		return "NO_GRACE";
	case NFS4ERR_RECLAIM_BAD: 	return "RECLAIM_BAD";
	case NFS4ERR_RECLAIM_CONFLICT: 	return "RECLAIM_CONFLICT";
	case NFS4ERR_BADXDR: 		return "BADXDR";
	case NFS4ERR_LOCKS_HELD: 	return "LOCKS_HELD";
	case NFS4ERR_OPENMODE: 		return "OPENMODE";
	case NFS4ERR_BADOWNER:		return "BADOWNER";
	case NFS4ERR_BADCHAR:		return "BADCHAR";
	case NFS4ERR_BADNAME:		return "BADNAME";
	case NFS4ERR_BAD_RANGE:		return "BAD_RANGE";
	case NFS4ERR_LOCK_NOTSUPP:	return "LOCK_NOTSUPP";
	case NFS4ERR_OP_ILLEGAL:	return "OP_ILLEGAL";
	case NFS4ERR_DEADLOCK:		return "DEADLOCK";
	case NFS4ERR_FILE_OPEN:		return "FILE_OPEN";
	case NFS4ERR_ADMIN_REVOKED:	return "ADMIN_REVOKED";
	case NFS4ERR_CB_PATH_DOWN:	return "CB_PATH_DOWN";

	default: 			return "unknown err";
	}
}

nfsstat4
str2err(char *status)
{
	if ((strcmp("OK", status)) == 0)
		return (NFS4_OK);
	else if ((strcmp("PERM", status)) == 0)
		return (NFS4ERR_PERM);
	else if ((strcmp("NOENT", status)) == 0)
		return (NFS4ERR_NOENT);
	else if ((strcmp("IO", status)) == 0)
		return (NFS4ERR_IO);
	else if ((strcmp("NXIO", status)) == 0)
		return (NFS4ERR_NXIO);
	else if ((strcmp("ACCESS", status)) == 0)
		return (NFS4ERR_ACCESS);
	else if ((strcmp("EXIST", status)) == 0)
		return (NFS4ERR_EXIST);
	else if ((strcmp("XDEV", status)) == 0)
		return (NFS4ERR_XDEV);
	/* error slot reserved for error 19 */
		/* available */
	else if ((strcmp("NOTDIR", status)) == 0)
		return (NFS4ERR_NOTDIR);
	else if ((strcmp("ISDIR", status)) == 0)
		return (NFS4ERR_ISDIR);
	else if ((strcmp("INVAL", status)) == 0)
		return (NFS4ERR_INVAL);
	else if ((strcmp("FBIG", status)) == 0)
		return (NFS4ERR_FBIG);
	else if ((strcmp("NOSPC", status)) == 0)
		return (NFS4ERR_NOSPC);
	else if ((strcmp("ROFS", status)) == 0)
		return (NFS4ERR_ROFS);
	else if ((strcmp("MLINK", status)) == 0)
		return (NFS4ERR_MLINK);
	else if ((strcmp("NAMETOOLONG", status)) == 0)
		return (NFS4ERR_NAMETOOLONG);
	else if ((strcmp("NOTEMPTY", status)) == 0)
		return (NFS4ERR_NOTEMPTY);
	else if ((strcmp("DQUOT", status)) == 0)
		return (NFS4ERR_DQUOT);
	else if ((strcmp("STALE", status)) == 0)
		return (NFS4ERR_STALE);
	else if ((strcmp("BADHANDLE", status)) == 0)
		return (NFS4ERR_BADHANDLE);
	else if ((strcmp("BAD_COOKIE", status)) == 0)
		return (NFS4ERR_BAD_COOKIE);
	else if ((strcmp("NOTSUPP", status)) == 0)
		return (NFS4ERR_NOTSUPP);
	else if ((strcmp("TOOSMALL", status)) == 0)
		return (NFS4ERR_TOOSMALL);
	else if ((strcmp("SERVERFAULT", status)) == 0)
		return (NFS4ERR_SERVERFAULT);
	else if ((strcmp("BADTYPE", status)) == 0)
		return (NFS4ERR_BADTYPE);
	else if ((strcmp("DELAY", status)) == 0)
		return (NFS4ERR_DELAY);
	else if ((strcmp("SAME", status)) == 0)
		return (NFS4ERR_SAME);
	else if ((strcmp("DENIED", status)) == 0)
		return (NFS4ERR_DENIED);
	else if ((strcmp("EXPIRED", status)) == 0)
		return (NFS4ERR_EXPIRED);
	else if ((strcmp("LOCKED", status)) == 0)
		return (NFS4ERR_LOCKED);
	else if ((strcmp("GRACE", status)) == 0)
		return (NFS4ERR_GRACE);
	else if ((strcmp("FHEXPIRED", status)) == 0)
		return (NFS4ERR_FHEXPIRED);
	else if ((strcmp("SHARE_DENIED", status)) == 0)
		return (NFS4ERR_SHARE_DENIED);
	else if ((strcmp("WRONGSEC", status)) == 0)
		return (NFS4ERR_WRONGSEC);
	else if ((strcmp("CLID_INUSE", status)) == 0)
		return (NFS4ERR_CLID_INUSE);
	else if ((strcmp("RESOURCE", status)) == 0)
		return (NFS4ERR_RESOURCE);
	else if ((strcmp("MOVED", status)) == 0)
		return (NFS4ERR_MOVED);
	else if ((strcmp("NOFILEHANDLE", status)) == 0)
		return (NFS4ERR_NOFILEHANDLE);
	else if ((strcmp("MINOR_VERS_MISMATCH", status)) == 0)
		return (NFS4ERR_MINOR_VERS_MISMATCH);
	else if ((strcmp("STALE_CLIENTID", status)) == 0)
		return (NFS4ERR_STALE_CLIENTID);
	else if ((strcmp("STALE_STATEID", status)) == 0)
		return (NFS4ERR_STALE_STATEID);
	else if ((strcmp("OLD_STATEID", status)) == 0)
		return (NFS4ERR_OLD_STATEID);
	else if ((strcmp("BAD_STATEID", status)) == 0)
		return (NFS4ERR_BAD_STATEID);
	else if ((strcmp("BAD_SEQID", status)) == 0)
		return (NFS4ERR_BAD_SEQID);
	else if ((strcmp("NOT_SAME", status)) == 0)
		return (NFS4ERR_NOT_SAME);
	else if ((strcmp("LOCK_RANGE", status)) == 0)
		return (NFS4ERR_LOCK_RANGE);
	else if ((strcmp("SYMLINK", status)) == 0)
		return (NFS4ERR_SYMLINK);
	else if ((strcmp("RESTOREFH", status)) == 0)
		return (NFS4ERR_RESTOREFH);
	else if ((strcmp("LEASE_MOVED", status)) == 0)
		return (NFS4ERR_LEASE_MOVED);
	else if ((strcmp("ATTRNOTSUPP", status)) == 0)
		return (NFS4ERR_ATTRNOTSUPP);
	else if ((strcmp("NO_GRACE", status)) == 0)
		return (NFS4ERR_NO_GRACE);
	else if ((strcmp("RECLAIM_BAD", status)) == 0)
		return (NFS4ERR_RECLAIM_BAD);
	else if ((strcmp("RECLAIM_CONFLICT", status)) == 0)
		return (NFS4ERR_RECLAIM_CONFLICT);
	else if ((strcmp("BADXDR", status)) == 0)
		return (NFS4ERR_BADXDR);
	else if ((strcmp("LOCKS_HELD", status)) == 0)
		return (NFS4ERR_LOCKS_HELD);
	else if ((strcmp("OPENMODE", status)) == 0)
		return (NFS4ERR_OPENMODE);
	else if ((strcmp("BADOWNER", status)) == 0)
		return (NFS4ERR_BADOWNER);
	else if ((strcmp("BADCHAR", status)) == 0)
		return (NFS4ERR_BADCHAR);
	else if ((strcmp("BADNAME", status)) == 0)
		return (NFS4ERR_BADNAME);
	else if ((strcmp("BAD_RANGE", status)) == 0)
		return (NFS4ERR_BAD_RANGE);
	else if ((strcmp("LOCK_NOTSUPP", status)) == 0)
		return (NFS4ERR_LOCK_NOTSUPP);
	else if ((strcmp("OP_ILLEGAL", status)) == 0)
		return (NFS4ERR_OP_ILLEGAL);
	else if ((strcmp("DEADLOCK", status)) == 0)
		return (NFS4ERR_DEADLOCK);
	else if ((strcmp("FILE_OPEN", status)) == 0)
		return (NFS4ERR_FILE_OPEN);
	else if ((strcmp("ADMIN_REVOKED", status)) == 0)
		return (NFS4ERR_ADMIN_REVOKED);
	else if ((strcmp("CB_PATH_DOWN", status)) == 0)
		return (NFS4ERR_CB_PATH_DOWN);
	else
		return (-1);
}

/*
 * Convert an integer to ascii
 */
char *
itoa(int i)
{
	static char buff[32];

	(void) sprintf(buff, "%d", i);

	return (buff);
}

/*
 * This converts a list of attribute names into
 * a bitmap.
 *
 * The readdir, nverify, setattr and verify ops use this.
 */
int
names2bitmap(Tcl_Interp *interp, char *names, bitmap4 *bmp)
{
	int largc;
	char **largv;
	int i;
	int bitno;

	/*
	 * Convert the attribute names in the list
	 * argument into an array of strings.
	 */
	if (Tcl_SplitList(interp, names, &largc,
	    (CONST84 char ***)&largv) != TCL_OK) {

		interp->result = "List error in getattr";

		return (TCL_ERROR);
	}

	/*
	 * Allocate an array big enough for 5*32 = 160 attrs
	 * and hope that's enough.
	 * Set the length to 0 word initially. The setbit()
	 * function will increase it if necessary.
	 */
	bmp->bitmap4_len = 0;
	bmp->bitmap4_val = calloc(5, sizeof (uint32_t));

	/*
	 * Now go through the string array and for each
	 * attribute determine its bit number and set
	 * the bit in the bitmap.
	 */
	for (i = 0; i < largc; i++) {
		char buf[4096];

		bitno =  name2bit(largv[i]);
		if (bitno < 0) {
			sprintf(buf, "Invalid attr name [%s]", largv[i]);
			interp->result = buf;
			if (largv)
				free((char *)largv);
			return (TCL_ERROR);
		}
		setbit(bmp, bitno);
	}

	free((char *)largv);
	return (TCL_OK);
}

/*
 * This converts a list of access bits into associated string
 */
char *
access2name(uint32_t abits)
{
	static char buf[80];

	buf[0] = '\0';
	if (abits & ACCESS4_READ)
		strcat(buf, "READ,");
	if (abits & ACCESS4_LOOKUP)
		strcat(buf, "LOOKUP,");
	if (abits & ACCESS4_MODIFY)
		strcat(buf, "MODIFY,");
	if (abits & ACCESS4_EXTEND)
		strcat(buf, "EXTEND,");
	if (abits & ACCESS4_DELETE)
		strcat(buf, "DELETE,");
	if (abits & ACCESS4_EXECUTE)
		strcat(buf, "EXECUTE,");
	if (buf[0] != '\0')
		buf[strlen(buf) - 1] = '\0';

	return (buf);
}

/*
 * Converts the nfsace4 structure to string list, and return the buffer
 */
char *
prn_ace4(nfsace4 ace)
{
	static char buf[256];
	char acltype[20];
	char aclflag[20];
	char aclmask[20];

	switch (ace.type) {
	case ACE4_ACCESS_ALLOWED_ACE_TYPE:
		sprintf(acltype, "ACCESS_ALLOWED_TYPE");
		break;
	case ACE4_ACCESS_DENIED_ACE_TYPE:
		sprintf(acltype, "ACCESS_DENIED_TYPE");
		break;
	case ACE4_SYSTEM_AUDIT_ACE_TYPE:
		sprintf(acltype, "SYSTEM_AUDIT_TYPE");
		break;
	case ACE4_SYSTEM_ALARM_ACE_TYPE:
		sprintf(acltype, "SYSTEM_ALARM_TYPE");
		break;
	default:
		break;
	}
	switch (ace.flag) {
	case ACE4_FILE_INHERIT_ACE:
		sprintf(aclmask, "FILE_INHERIT");
		break;
	case ACE4_DIRECTORY_INHERIT_ACE:
		sprintf(aclmask, "DIR_INHERIT");
		break;
	case ACE4_NO_PROPAGATE_INHERIT_ACE:
		sprintf(aclmask, "NO_PROPAGATE");
		break;
	case ACE4_INHERIT_ONLY_ACE:
		sprintf(aclmask, "INHERIT_ONLY");
		break;
	case ACE4_SUCCESSFUL_ACCESS_ACE_FLAG:
		sprintf(acltype, "SUCCESS_ACCESS");
		break;
	case ACE4_FAILED_ACCESS_ACE_FLAG:
		sprintf(acltype, "FAILED_ACCESS");
		break;
	case ACE4_IDENTIFIER_GROUP:
		sprintf(acltype, "ID_GROUP");
		break;
	default:
		break;
	}
	sprintf(buf, "%s %s %s %s",
	    acltype, aclflag, aclmask, utf82str(ace.who));
	return (buf);
}

/*
 * Converts the nfsace4 structure to string list, and return the buffer
 */
char *
out_ace4(nfsace4 ace, int symbolic_out)
{
#define	ACL_MEMSIZE	20

	size_t	buf_size = 256;
	char	*buf;
	size_t	ret_len;
	char	acltype[ACL_MEMSIZE];
	char	aclflag[ACL_MEMSIZE];
	char	aclmask[ACL_MEMSIZE];

	(void) snprintf(acltype, sizeof (acltype), "%d", ace.type);
	(void) snprintf(aclflag, sizeof (aclflag), "%x", ace.flag);
	(void) snprintf(aclmask, sizeof (aclmask), "%x", ace.access_mask);

#if DEBUG_ACL
	(void) printf("%d %x %x %s\n", ace.type, ace.flag,
	    ace.access_mask, utf82str(ace.who));

	out_ace4_type(ace);
	out_ace4_flag(ace);
	out_ace4_mask(ace);
	ace4_check(ace);
#endif

	buf =  malloc(buf_size);
	if (buf == NULL) {
		perror("malloc(buf_size)");
		(void) fprintf(stderr, " -- file %s, line %d\n",
		    __FILE__, __LINE__);
		goto fin;
	}
	for (;;) {
		ret_len = snprintf(buf, buf_size, "%s %s %s %s",
		    acltype, aclflag, aclmask, utf82str(ace.who));
		if (ret_len < buf_size) {
			break;
		} else {
			buf_size = ret_len + 1;
			buf = realloc(buf, buf_size);
		}
	}
fin:
	return (buf);

#undef ACL_MEMSIZE
}

void
out_ace4_type(nfsace4 ace)
{
	switch (ace.type) {
	case ACE4_ACCESS_ALLOWED_ACE_TYPE:
		(void) printf("\ttype: ACE4_ACCESS_ALLOWED_ACE_TYPE\n");
		break;
	case ACE4_ACCESS_DENIED_ACE_TYPE:
		(void) printf("\ttype: ACE4_ACCESS_DENIED_ACE_TYPE\n");
		break;
	case ACE4_SYSTEM_AUDIT_ACE_TYPE:
		(void) printf("\ttype: ACE4_SYSTEM_AUDIT_ACE_TYPE\n");
		break;
	case ACE4_SYSTEM_ALARM_ACE_TYPE:
		(void) printf("\ttype: ACE4_SYSTEM_ALARM_ACE_TYPE\n");
		break;
	default:
		(void) printf("\ttype: Unknown type\n");
		break;
	}
}

void
out_ace4_flag(nfsace4 ace)
{
	if (ace.flag == 0) {
		(void) printf("\tflag: NOT SET\n");
		return;
	}

	if (ace.flag & ACE4_FILE_INHERIT_ACE)
		(void) printf("\tflag: ACE4_FILE_INHERIT_ACE\n");
	if (ace.flag & ACE4_DIRECTORY_INHERIT_ACE)
		(void) printf("\tflag: ACE4_DIRECTORY_INHERIT_ACE\n");
	if (ace.flag & ACE4_NO_PROPAGATE_INHERIT_ACE)
		(void) printf("\tflag: ACE4_NO_PROPAGATE_INHERIT_ACE\n");
	if (ace.flag & ACE4_INHERIT_ONLY_ACE)
		(void) printf("\tflag: ACE4_INHERIT_ONLY_ACE\n");
	if (ace.flag & ACE4_SUCCESSFUL_ACCESS_ACE_FLAG)
		(void) printf("\tflag: ACE4_SUCCESSFUL_ACCESS_ACE_FLAG\n");
	if (ace.flag & ACE4_FAILED_ACCESS_ACE_FLAG)
		(void) printf("\tflag: ACE4_FAILED_ACCESS_ACE_FLAG\n");
	if (ace.flag & ACE4_IDENTIFIER_GROUP)
		(void) printf("\tflag: ACE4_IDENTIFIER_GROUP\n");
}

void
out_ace4_mask(nfsace4 ace)
{
	if (ace.access_mask == 0) {
		(void) printf("\tmask: NOT SET\n");
		return;
	}

	(void) printf("\tmask: ");

	if (ace.access_mask & ACE4_READ_DATA)
		(void) printf("ACE4_READ_DATA ");
	if (ace.access_mask & ACE4_WRITE_DATA)
		(void) printf("ACE4_WRITE_DATA ");
	if (ace.access_mask & ACE4_APPEND_DATA)
		(void) printf("ACE4_APPEND_DATA ");
	if (ace.access_mask & ACE4_READ_NAMED_ATTRS)
		(void) printf("ACE4_READ_NAMED_ATTRS ");
	if (ace.access_mask & ACE4_WRITE_NAMED_ATTRS)
		(void) printf("ACE4_WRITE_NAMED_ATTRS ");
	if (ace.access_mask & ACE4_EXECUTE)
		(void) printf("ACE4_EXECUTE ");
	if (ace.access_mask & ACE4_DELETE_CHILD)
		(void) printf("ACE4_DELETE_CHILD ");
	if (ace.access_mask & ACE4_READ_ATTRIBUTES)
		(void) printf("ACE4_READ_ATTRIBUTES ");
	if (ace.access_mask & ACE4_WRITE_ATTRIBUTES)
		(void) printf("ACE4_WRITE_ATTRIBUTES ");
	if (ace.access_mask & ACE4_DELETE)
		(void) printf("ACE4_DELETE ");
	if (ace.access_mask & ACE4_READ_ACL)
		(void) printf("ACE4_READ_ACL ");
	if (ace.access_mask & ACE4_WRITE_ACL)
		(void) printf("ACE4_WRITE_ACL ");
	if (ace.access_mask & ACE4_WRITE_OWNER)
		(void) printf("ACE4_WRITE_OWNER ");
	if (ace.access_mask & ACE4_SYNCHRONIZE)
		(void) printf("ACE4_SYNCHRONIZE ");

	if (ace.access_mask == ACE4_GENERIC_READ)
		(void) printf("ACE4_GENERIC_READ ");
	if (ace.access_mask == ACE4_GENERIC_WRITE)
		(void) printf("ACE4_GENERIC_WRITE ");
	if (ace.access_mask == ACE4_GENERIC_EXECUTE)
		(void) printf("ACE4_GENERIC_EXECUTE ");

	(void) printf("\n");
}

/*
 * Perform some basic minimal sanity checks. In time if these
 * checks grow in complexity can be split into seperate functions.
 */
void
ace4_check(nfsace4 ace)
{

	/*
	 * Flag checks - check for illegal combinations and invalid
	 * values.
	 */
	if (ace.flag & ACE4_INHERIT_ONLY_ACE) {
		if (!(ace.flag & ACE4_FILE_INHERIT_ACE) ||
		    !(ace.flag & ACE4_DIRECTORY_INHERIT_ACE)) {
			(void) printf("** Warning - Invalid FLAG settings\n");
		}
	}

	if ((ace.flag & ACE4_SUCCESSFUL_ACCESS_ACE_FLAG) ||
	    (ace.flag & ACE4_FAILED_ACCESS_ACE_FLAG) ||
	    (ace.flag & ACE4_NO_PROPAGATE_INHERIT_ACE)) {
		(void) printf("** Warning - Invalid FLAG settings\n");
	}

	/*
	 * Mask checks - check for invalid values.
	 */
	if ((ace.access_mask & ACE4_DELETE) ||
	    (ace.access_mask & ACE4_WRITE_OWNER) ||
	    (ace.access_mask & ACE4_SYNCHRONIZE)) {
		(void) printf("** Warning - Invalid MASK settings\n");
	}

	if (ace.type == ACE4_ACCESS_ALLOWED_ACE_TYPE) {
		if (!(ace.access_mask & ACE4_READ_ATTRIBUTES) ||
		    !(ace.access_mask & ACE4_READ_ACL)) {
			(void) printf("** Warninf - Missing attributes\n");
		}
	}
}


/*
 * ----------------------------------------------------------------------
 *
 * getInnerCmd --
 *
 *	This function is invoked within substitution to get any commands
 *	enclosed within brackets '[' ']'. It copies the enclosed text from
 *	the original string to the target string. Also, it advances the
 *	pointer of the original string to the next character after the
 *	closing bracket.
 *
 *
 * ----------------------------------------------------------------------
 */

int
getInnerCmd(char *target, char **original)
{
	char	*curr = *original;
	int	nested = 0,
	    i;

	/* check for matching brackets */
	while (*curr != 0) {
		switch (*curr) {
		case '[':
			nested++;
			break;
		case ']':
			nested--;
			break;
		default:
			break;
		}
		if (nested == 0)
			break;

		i = (int)(curr - *original);
		curr++;
	}

	if (nested != 0 && *curr == 0) {
		sprintf(target, "ERROR Mismatched brackets. Missing %c.\n",
		    (nested > 0) ? ']' : '[');
		return (TCL_ERROR);
	}

	if (*curr != ']') {
		sprintf(target, "ERROR Unexpected syntax error getInnerCmd\n");
		return (TCL_ERROR);
	}

	/* copy inner commands (skipping outer brakects) */
	i = (int)(curr - *original);
	strncpy(target, *original + 1, i);
	target[i] = '\0';
	/* move original pointer to next char after ']' */
	*original = curr + 1;
	return (TCL_OK);
}

/*
 * ----------------------------------------------------------------------
 *
 * substitution --
 *
 *	This function is invoked to process substitution on a single
 *	item(string). Performs backslash, variable and command substitution.
 *	Result string is stored in the standard place.
 *
 *	Caution: 'result' is static memory and will be rewriten by each
 *		substitution call, as well as other TCL calls. It must be
 *		copied or used right after the call to substitution.
 *
 * ----------------------------------------------------------------------
 */

int
substitution(Tcl_Interp *interp, char *CONST strng)
{
	static Tcl_DString result;
	char *p, *old, *value;
	int code, count, doVars = 1, doCmds = 0, doBackslashes = 1;
	Tcl_Interp *iPtr = (Tcl_Interp *) interp;

	/*
	 * Scan through the string one character at a time, performing
	 * command, variable, and backslash substitutions.
	 */

	Tcl_DStringInit(&result);
	if (strng == NULL) { /* if no string, return success */
		Tcl_DStringResult(interp, &result);
		return (TCL_OK);
	}
	old = p = strng;
	while (*p != 0) {
		switch (*p) {
		case '\\':
			if (doBackslashes) {
				char buf[TCL_UTF_MAX];

				if (p != old) {
					Tcl_DStringAppend(&result, old, p-old);
				}
				Tcl_DStringAppend(&result, buf,
				    Tcl_UtfBackslash(p, &count, buf));
				p += count;
				old = p;
			} else {
				p++;
			}
			break;

		case '$':
			if (doVars) {
				if (p != old) {
					Tcl_DStringAppend(&result, old, p-old);
				}
				value = (char *)Tcl_ParseVar(interp, p,
				    (CONST84 char **)&p);
				if (value == NULL) {
					Tcl_DStringFree(&result);
					return (TCL_ERROR);
				}
				Tcl_DStringAppend(&result, value, -1);
				old = p;
			} else {
				p++;
			}
			break;

		case '[':
			if (doCmds) {
				if (p != old) {
					Tcl_DStringAppend(&result, old, p-old);
				}

				{
					int	code;
					char	*tmp;

					if ((tmp = malloc(strlen(p))) == NULL) {
						perror("out of memory");
						exit(1);
					}

					code = getInnerCmd(tmp, &p);
					if (code == TCL_ERROR) {
						fprintf(stderr, tmp);
						Tcl_DStringFree(&result);
						return (code);
					}

					code = Tcl_EvalEx(interp, tmp, -1, 0);
					free(tmp);
					if (code == TCL_ERROR) {
						Tcl_DStringFree(&result);
						return (code);
					}
					old = p;
				}
				Tcl_DStringAppend(&result, iPtr->result, -1);
				Tcl_ResetResult(interp);
			} else {
				p++;
			}
			break;

		default:
			p++;
			break;
		}
	}
	if (p != old) {
		Tcl_DStringAppend(&result, old, p-old);
	}
	Tcl_DStringResult(interp, &result);
	return (TCL_OK);
}


/*
 * ----------------------------------------------------------------------
 *
 * find_file --
 *
 *	This function is used to search filename on the directories listed
 *	on the environment variable whose name is passed in mypath, using
 *	the field separators defined in mysep.
 *	Default values for mypath and mysep are "PATH" and ":", respectively.
 *	To use the default values pass an empty string to mypath and/ or mysep.
 *	If the environment variable is found, then a search for filename
 *	takes place under each directory listed in the path.
 *	If filename is found, search stops and a string pointer to its
 *	complete name (path included) is returned. Otherwise, NULL pointer
 *	is returned. If filename is an empty string, NULL is returned.
 *	This function is similar to the "which" command in unix.
 *
 *
 * ----------------------------------------------------------------------
 */

char *
find_file(char *file, char *mypath, char *mysep)
{
	int 		i;
	char		path[4096],
	    *orig_path,
	    *rest_path;
	static char	filename[PATH_MAX];
	const char	*PATH = "PATH",
	    *SEP = ":";
	struct stat	buf;

	if (file[0] == '\0')
		return (NULL);

/* use defaults if info not provided */
	if (mypath[0] == '\0')
		mypath = (char *)PATH;
	if (mysep[0] == '\0')
		mysep = (char *)SEP;

	if ((orig_path = getenv(mypath)) == NULL) {
		fprintf(stderr, "%s was not found in the"
		    " environment variables\n",
		    mypath);
		return (NULL);
	}

	strcpy(path, orig_path);

	i = 0;
	rest_path = path;
	while (strtok(rest_path, mysep) != NULL) {
		sprintf(filename, "%s/%s", rest_path, file);
		if (stat(filename, &buf) == 0) {
			i = 1;
			break;
		}
		rest_path += strlen(rest_path) + 1;
	}

	if (i)
		return (filename);
	else
		return (NULL);
}


/*
 * Given the string of the stateid in form of {seqid other}
 * convert them to stateid4 structure.
 */
int
str2stateid(Tcl_Interp *interp, char *strs, stateid4 *sp)
{
	int lc;
	char **lv;
	char buf[80];
	uint_t slen;
	int tmp;

	/* split the stateid4 strings to seqid and other */
	if (Tcl_SplitList(interp, strs, &lc, (CONST84 char ***)&lv) != TCL_OK) {
		sprintf(buf, "str2stateid error, can't split {%s}", strs);
		interp->result = buf;
		return (TCL_ERROR);
	}
	if (lc != 2) {
		sprintf(buf, "str2stateid error, {%s} needs 2 fields", strs);
		interp->result = buf;
		if (lv)
			free((char *)lv);
		return (TCL_ERROR);
	}

	sp->seqid = (uint32_t)atoi(lv[0]);

	/*
	 * try to take care of special stateid cases,
	 * e.g. all 0's or all 1's.
	 */
	tmp = (uint64_t)strtoll(lv[1], NULL, 16);
	if ((sp->seqid == 0) && (tmp == 0)) {
		(void) memset((void *) sp, 0, sizeof (stateid4));
	} else if (((sp->seqid == 1) || (sp->seqid == 0)) && (tmp == 1)) {
		(void) memset((void *) sp, 0xFF, sizeof (stateid4));
		sp->seqid = 0xffffffff;
	} else {
		slen = strlen(lv[1]) / 2;
		(void) memcpy(&sp->other, hex2bin(lv[1], (unsigned)slen),
		    sizeof (sp->other));
	}

	free((char *)lv);
	return (TCL_OK);
}

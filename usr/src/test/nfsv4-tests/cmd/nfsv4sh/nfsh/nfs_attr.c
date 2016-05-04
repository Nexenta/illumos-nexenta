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

#define	ATTR_NAME_LEN	25 /* longest attr name + space separator + null char */

/* attributes table */
ATTRINFO attr_info[] = {
	{"supported_attrs",	de_bitmap,	en_unimpl	}, /*  0 */
	{"type",		de_type,	en_type		}, /*  1 */
	{"fh_expire_type",	de_uint32,	en_uint32	}, /*  2 */
	{"change",		de_uint64,	en_uint64	}, /*  3 */
	{"size",		de_uint64,	en_uint64	}, /*  4 */
	{"link_support",	de_bool,	en_bool		}, /*  5 */
	{"symlink_support",	de_bool,	en_bool		}, /*  6 */
	{"named_attr",		de_bool,	en_bool		}, /*  7 */
	{"fsid",		de_fsid,	en_fsid		}, /*  8 */
	{"unique_handles",	de_bool,	en_bool		}, /*  9 */
	{"lease_time",		de_uint32,	en_uint32	}, /* 10 */
	{"rdattr_error",	de_stat4,	en_stat4	}, /* 11 */
	{"acl",			de_acl,		en_acl		}, /* 12 */
	{"aclsupport",		de_uint32,	en_uint32	}, /* 13 */
	{"archive",		de_bool,	en_bool		}, /* 14 */
	{"cansettime",		de_bool,	en_bool		}, /* 15 */
	{"case_insensitive",	de_bool,	en_bool		}, /* 16 */
	{"case_preserving",	de_bool,	en_bool		}, /* 17 */
	{"chown_restricted",	de_bool,	en_bool		}, /* 18 */
	{"filehandle",		de_fhandle,	en_fhandle	}, /* 19 */
	{"fileid",		de_uint64,	en_uint64	}, /* 20 */
	{"files_avail",		de_uint64,	en_uint64	}, /* 21 */
	{"files_free",		de_uint64,	en_uint64	}, /* 22 */
	{"files_total",		de_uint64,	en_uint64	}, /* 23 */
	{"fs_locations",	de_fslocation,	en_unimpl	}, /* 24 */
	{"hidden",		de_bool,	en_bool		}, /* 25 */
	{"homogeneous",		de_bool,	en_bool		}, /* 26 */
	{"maxfilesize",		de_uint64,	en_uint64	}, /* 27 */
	{"maxlink",		de_uint32,	en_uint32	}, /* 28 */
	{"maxname",		de_uint32,	en_uint32	}, /* 29 */
	{"maxread",		de_uint64,	en_uint64	}, /* 30 */
	{"maxwrite",		de_uint64,	en_uint64	}, /* 31 */
	{"mimetype",		de_utf8string,	en_utf8string	}, /* 32 */
	{"mode",		de_mode,	en_mode		}, /* 33 */
	{"no_trunc",		de_bool,	en_bool		}, /* 34 */
	{"numlinks",		de_uint32,	en_uint32	}, /* 35 */
	{"owner",		de_utf8string,	en_utf8string	}, /* 36 */
	{"owner_group",		de_utf8string,	en_utf8string	}, /* 37 */
	{"quota_avail_hard",	de_uint64,	en_uint64	}, /* 38 */
	{"quota_avail_soft",	de_uint64,	en_uint64	}, /* 39 */
	{"quota_used",		de_uint64,	en_uint64	}, /* 40 */
	{"rawdev",		de_specdata,	en_specdata	}, /* 41 */
	{"space_avail",		de_uint64,	en_uint64	}, /* 42 */
	{"space_free",		de_uint64,	en_uint64	}, /* 43 */
	{"space_total",		de_uint64,	en_uint64	}, /* 44 */
	{"space_used",		de_uint64,	en_uint64	}, /* 45 */
	{"system",		de_bool,	en_bool		}, /* 46 */
	{"time_access",		de_time,	en_time		}, /* 47 */
	{"time_access_set",	de_time,	en_timeset	}, /* 48 */
	{"time_backup",		de_time,	en_time		}, /* 49 */
	{"time_create",		de_time,	en_time		}, /* 50 */
	{"time_delta",		de_time,	en_time		}, /* 51 */
	{"time_metadata",	de_time,	en_time		}, /* 52 */
	{"time_modify",		de_time,	en_time		}, /* 53 */
	{"time_modify_set",	de_time,	en_timeset	}, /* 54 */
	{"mounted_on_fileid",	de_uint64,	en_uint64	}  /* 55 */
};

int tblsize = sizeof (attr_info) / sizeof (attr_info[0]);

#ifdef DEBUG_ACL
static void debug_print_bitmap(char *name, bitmap4 *bitmap);
static void debug_print_attrvals(char *name, attrlist4 *attrvals);
static void debug_print_nvpairs(char *name, char *nvpairs);
#endif


/*
 * Given an attribute name - return its bit number.
 */
int
name2bit(char *name)
{
	int i;

	for (i = 0; i < tblsize; i++)
		if (strcmp(name, attr_info[i].name) == 0)
			return (i);
	return (-1);
}

/*
 * Given an attribute bit number - return its name.
 */
char *
bit2name(int bit)
{
	if ((bit < 0) || (bit > (tblsize - 1)))
		return ("unknown");

	return (attr_info[bit].name);
}

/*
 * Given the attribute bitmap - prints the names where the bit is set.
 */
void
prn_attrname(Tcl_DString *strp, bitmap4 *bmp)
{
	int i;

	for (i = 0; i < tblsize; i++) {

		if (!getbit(bmp, i))
			continue;

		Tcl_DStringAppendElement(strp, bit2name(i));
	}
}


/* ------------------------------- */
/* Attribute decoding functions.   */
/* ------------------------------- */

int
de_bool(XDR *xdrp, Tcl_DString *strp, char *name) {

	bool_t b;

	if (xdr_bool(xdrp, &b) == FALSE)
		return (TCL_ERROR);

	Tcl_DStringAppendElement(strp, name);
	Tcl_DStringAppendElement(strp, b ? "true":"false");

	return (TCL_OK);
}

int
de_time(XDR *xdrp, Tcl_DString *strp, char *name) {

	nfstime4 t;
	char buf[64];

	if (xdr_nfstime4(xdrp, &t) == FALSE)
		return (TCL_ERROR);

	Tcl_DStringAppendElement(strp, name);
	Tcl_DStringStartSublist(strp);

	(void) sprintf(buf, "%lld", t.seconds);
	Tcl_DStringAppendElement(strp, buf);

	(void) sprintf(buf, "%u", t.nseconds);
	Tcl_DStringAppendElement(strp, buf);

	Tcl_DStringEndSublist(strp);

	return (TCL_OK);
}

int
de_uint64(XDR *xdrp, Tcl_DString *strp, char *name) {

	uint64_t val;
	char buf[64];

	if (xdr_uint64_t(xdrp, &val) == FALSE)
		return (TCL_ERROR);

	Tcl_DStringAppendElement(strp, name);
	(void) sprintf(buf, "%llu", val);
	Tcl_DStringAppendElement(strp, buf);

	return (TCL_OK);
}

int
de_uint32(XDR *xdrp, Tcl_DString *strp, char *name) {

	uint32_t val;
	char buf[64];

	if (xdr_uint32_t(xdrp, &val) == FALSE)
		return (TCL_ERROR);

	Tcl_DStringAppendElement(strp, name);
	(void) sprintf(buf, "%u", val);
	Tcl_DStringAppendElement(strp, buf);

	return (TCL_OK);
}

int
de_type(XDR *xdrp, Tcl_DString *strp, char *name) {

	fattr4_type t;
	char *p;

	if (xdr_fattr4_type(xdrp, &t) == FALSE)
		return (TCL_ERROR);

	switch (t) {
	case NF4REG:		p = "reg"; break;
	case NF4DIR:		p = "dir"; break;
	case NF4BLK:		p = "blk"; break;
	case NF4CHR:		p = "chr"; break;
	case NF4LNK:		p = "lnk"; break;
	case NF4SOCK:		p = "sock"; break;
	case NF4FIFO:		p = "fifo"; break;
	case NF4ATTRDIR:	p = "attrdir"; break;
	case NF4NAMEDATTR:	p = "namedattr"; break;
	default:		p = "unknown"; break;
	}

	Tcl_DStringAppendElement(strp, name);
	Tcl_DStringAppendElement(strp, p);

	return (TCL_OK);
}

int
de_bitmap(XDR *xdrp, Tcl_DString *strp, char *name) {

	bitmap4 supported;
	int maxattr;
	int i;

	(void) memset(&supported, 0, sizeof (bitmap4));
	if (xdr_fattr4_supported_attrs(xdrp, &supported) == FALSE)
		return (TCL_ERROR);

	Tcl_DStringAppendElement(strp, name);
	Tcl_DStringStartSublist(strp);

	/*
	 * Get the bit numbers (byte#s-of-int * 8 bits)
	 */
	maxattr = supported.bitmap4_len * sizeof (uint32_t) * 8;

	/*
	 * Test each attribute bit in the bitmap.
	 * If it's set, append its name to the list
	 */
	for (i = 0; i < maxattr; i++) {
		if (! getbit(&supported, i))
			continue;

		Tcl_DStringAppendElement(strp, bit2name(i));
	}
	Tcl_DStringEndSublist(strp);

	return (TCL_OK);
}

int
de_fsid(XDR *xdrp, Tcl_DString *strp, char *name) {

	fsid4 fsid;
	char buf[64];

	if (xdr_fsid4(xdrp, &fsid) == FALSE)
		return (TCL_ERROR);

	Tcl_DStringAppendElement(strp, name);

	Tcl_DStringStartSublist(strp);
	(void) sprintf(buf, "%llu", fsid.major);
	Tcl_DStringAppendElement(strp, buf);

	(void) sprintf(buf, "%llu", fsid.minor);
	Tcl_DStringAppendElement(strp, buf);
	Tcl_DStringEndSublist(strp);

	return (TCL_OK);
}

int
de_fhandle(XDR *xdrp, Tcl_DString *strp, char *name) {

	fattr4_filehandle fh;
	unsigned fh_len;
	char *fh_val;

	fh.nfs_fh4_val = NULL;
	if (xdr_fattr4_filehandle(xdrp, &fh) == FALSE)
		return (TCL_ERROR);

	fh_len = fh.nfs_fh4_len;
	fh_val = fh.nfs_fh4_val;

	Tcl_DStringAppendElement(strp, name);
	Tcl_DStringAppendElement(strp, bin2hex(fh_val, fh_len));

	return (TCL_OK);
}

int
de_mode(XDR *xdrp, Tcl_DString *strp, char *name) {

	mode4 m;
	char buf[64];

	if (xdr_fattr4_mode(xdrp, &m) == FALSE)
		return (TCL_ERROR);
	Tcl_DStringAppendElement(strp, name);
	(void) sprintf(buf, "%o", m);
	Tcl_DStringAppendElement(strp, buf);

	return (TCL_OK);
}

int
de_specdata(XDR *xdrp, Tcl_DString *strp, char *name) {

	static specdata4 dev;
	char buf[64];

	if (xdr_specdata4(xdrp, &dev) == FALSE)
		return (TCL_ERROR);

	Tcl_DStringAppendElement(strp, name);
	(void) sprintf(buf, "%u %u", dev.specdata1, dev.specdata2);
	Tcl_DStringAppendElement(strp, buf);

	return (TCL_OK);
}

int
de_utf8string(XDR *xdrp, Tcl_DString *strp, char *name) {

	static utf8string res;
	char *p;

	if (xdr_utf8string(xdrp, &res) == FALSE)
		return (TCL_ERROR);

	p = malloc(res.utf8string_len + 1);
	(void) strncpy(p, res.utf8string_val, res.utf8string_len);
	p[res.utf8string_len] = '\0';

	Tcl_DStringAppendElement(strp, name);
	Tcl_DStringAppendElement(strp, p);

	free(p);
	return (TCL_OK);
}

int
de_stat4(XDR *xdrp, Tcl_DString *strp, char *name) {

	nfsstat4 s;

	if (xdr_nfsstat4(xdrp, &s) == FALSE)
		return (TCL_ERROR);

	Tcl_DStringAppendElement(strp, name);
	Tcl_DStringAppendElement(strp, errstr(s));

	return (TCL_OK);
}

int
de_unimpl(XDR *xdrp, Tcl_DString *strp, char *name) {

	int b;
	xdr_bool(xdrp, &b);	/* just advance the pointer */
	Tcl_DStringAppendElement(strp, name);
	Tcl_DStringAppendElement(strp, "not-yet-impl in nfsv4shell");

	return (TCL_OK);
}

int
de_acl(XDR *xdrp, Tcl_DString *strp, char *name) {
	static	fattr4_acl facl;	/* acl struct to be decoded */
	char	*acl_buf; 		/* buffer of decoded values to output */
	int	ret;
	int	i;

#ifdef DEBUG_ACL
	(void) fprintf(stderr, "\nde_acl(xdrp, strp, name)\n");
	(void) fprintf(stderr, "\txdrp == %p, strp == %p, name == %s\n",
		xdrp, strp, name ? name : "NULL");
#endif

	if (xdr_fattr4_acl(xdrp, &facl) == FALSE) {
#ifdef DEBUG_ACL
	(void) fprintf(stderr, "xdr_fattr4_acl() failed\n");
#endif
		ret = TCL_ERROR;
		goto fin;
	}

	Tcl_DStringAppendElement(strp, name);
	Tcl_DStringStartSublist(strp);
	for (i = 0; i < facl.fattr4_acl_len; i++) {
		acl_buf = out_ace4(facl.fattr4_acl_val[i], 0);
		Tcl_DStringAppendElement(strp, acl_buf);
	}
	Tcl_DStringEndSublist(strp);
	ret = TCL_OK;

fin:
	xdr_free(xdr_fattr4_acl, (char *)&facl);
	return (ret);
}

int
de_fslocation(XDR *xdrp, Tcl_DString *strp, char *name) {
	static	fattr4_fs_locations fsl; /* fs_locations struct to be decoded */
	char	fs_buf[2048]; 		/* buffer of decoded values to output */
	int	ret;
	int	i, j;
	fs_location4 newloc;		/* the new rootpath location */

#ifdef DEBUG_ATTR
	(void) fprintf(stderr, "\nde_fslocation(xdrp, strp, name)\n");
	(void) fprintf(stderr, "\txdrp == %p, strp == %p, name == %s\n",
		xdrp, strp, name ? name : "NULL");
#endif /* DEBUG_ATTR */

	if (xdr_fattr4_fs_locations(xdrp, &fsl) == FALSE) {
#ifdef DEBUG_ATTR
	(void) fprintf(stderr, "xdr_fattr4_fs_locations() failed\n");
#endif /* DEBUG_ATTR */
		ret = TCL_ERROR;
		goto fin;
	}

	Tcl_DStringAppendElement(strp, name);

	Tcl_DStringStartSublist(strp);
	sprintf(fs_buf, "");
	for (i = 0; i < fsl.fs_root.pathname4_len; i++) {
	    strcat(fs_buf, utf82str(fsl.fs_root.pathname4_val[i]));
	    if (i < (fsl.fs_root.pathname4_len - 1))
			strcat(fs_buf, " ");
	}
	Tcl_DStringAppendElement(strp, fs_buf);

	Tcl_DStringStartSublist(strp);
	for (i = 0; i < fsl.locations.locations_len; i++) {
	    newloc = fsl.locations.locations_val[i];

	    Tcl_DStringStartSublist(strp);
	    sprintf(fs_buf, "");
	    for (j = 0; j < newloc.server.server_len; j++) {
		strcat(fs_buf, utf82str(newloc.server.server_val[j]));
		if (j < (newloc.server.server_len - 1))
			strcat(fs_buf, " ");
	    }
	    Tcl_DStringAppendElement(strp, fs_buf);

	    sprintf(fs_buf, "");
	    for (j = 0; j < newloc.rootpath.pathname4_len; j++) {
		strcat(fs_buf, utf82str(newloc.rootpath.pathname4_val[j]));
		if (j < (newloc.rootpath.pathname4_len - 1))
			strcat(fs_buf, " ");
	    }
	    Tcl_DStringAppendElement(strp, fs_buf);
	    Tcl_DStringEndSublist(strp);
	}
	Tcl_DStringEndSublist(strp);

	Tcl_DStringEndSublist(strp);
	ret = TCL_OK;

fin:
	xdr_free(xdr_fattr4_fs_locations, (char *)&fsl);
	return (ret);
}

/* ------------------------------- */
/* Attribute encoding functions.   */
/* ------------------------------- */

int
en_bool(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	bool_t b;
	char buf[80];

	substitution(interp, vp);
	vp = interp->result;
	if ((strcmp(vp, "true")) == 0)
		b = TRUE;
	else if ((strcmp(vp, "false")) == 0)
		b = FALSE;
	else {
		sprintf(buf, "%s - boolean value", vp);
		interp->result = buf;
		return (TCL_ERROR);
	}

	if (xdr_bool(xdrp, &b) == FALSE)
		return (TCL_ERROR);
	al->attrlist4_len += xdr_sizeof(xdr_bool, &b);

	return (TCL_OK);
}

int
en_fhandle(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	fattr4_filehandle fh;
	char buf[80];

	substitution(interp, vp);
	vp = interp->result;
	fh.nfs_fh4_len = strlen(vp) / 2;
	fh.nfs_fh4_val = malloc(fh.nfs_fh4_len);
	if (fh.nfs_fh4_val == NULL) {
		interp->result = "malloc failure in en_fhandle";
		return (TCL_ERROR);
	}
	(void) memcpy(fh.nfs_fh4_val,
		hex2bin(vp, ((unsigned)fh.nfs_fh4_len)), fh.nfs_fh4_len);

	if (xdr_fattr4_filehandle(xdrp, &fh) == FALSE)
		return (TCL_ERROR);

	al->attrlist4_len += xdr_sizeof(xdr_fattr4_filehandle, &fh);

	return (TCL_OK);
}

int
en_type(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	fattr4_type t;
	char buf[80];

	substitution(interp, vp);
	vp = interp->result;
	if ((strcmp(vp, "reg")) == 0)
		t = NF4REG;
	else if ((strcmp(vp, "dir")) == 0)
		t = NF4DIR;
	else if ((strcmp(vp, "blk")) == 0)
		t = NF4BLK;
	else if ((strcmp(vp, "chr")) == 0)
		t = NF4CHR;
	else if ((strcmp(vp, "lnk")) == 0)
		t = NF4LNK;
	else if ((strcmp(vp, "sock")) == 0)
		t = NF4SOCK;
	else if ((strcmp(vp, "fifo")) == 0)
		t = NF4FIFO;
	else if ((strcmp(vp, "attrdir")) == 0)
		t = NF4ATTRDIR;
	else if ((strcmp(vp, "namedattr")) == 0)
		t = NF4NAMEDATTR;
	else {
		sprintf(buf, "%s - unknown type", vp);
		interp->result = buf;
		return (TCL_ERROR);
	}

	if (xdr_fattr4_type(xdrp, &t) == FALSE)
		return (TCL_ERROR);
	al->attrlist4_len += xdr_sizeof(xdr_fattr4_type, &t);

	return (TCL_OK);
}

int
en_fsid(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	fattr4_fsid val;
	char buf[80];
	int lc;
	char **lv;
	int code = TCL_ERROR;

	/* need to split the fsid strings to major and minor */
	if (Tcl_SplitList(interp, vp, &lc, (CONST84 char ***)&lv) != TCL_OK) {
		sprintf(buf, "encoding fsid error, can't split {%s}", vp);
		interp->result = buf;
		return (code);
	}
	if (lc != 2) {
		sprintf(buf, "encoding fsid error, {%s} needs 2 fields", vp);
		interp->result = buf;
		goto lv_exit;
	}

	/* convert the strings to major & minor */
	substitution(interp, lv[0]);
	val.major = (uint64_t)strtoull(interp->result, NULL, 10);
	substitution(interp, lv[1]);
	val.minor = (uint64_t)strtoull(interp->result, NULL, 10);

	if (xdr_fattr4_fsid(xdrp, &val) == FALSE)
		goto lv_exit;

	al->attrlist4_len += xdr_sizeof(xdr_fattr4_fsid, &val);
	code = TCL_OK;

lv_exit:
	if (lv)
		free((char *)lv);
	return (code);
}

int
en_uint64(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	uint64_t val;

	substitution(interp, vp);
	vp = interp->result;
	val = (uint64_t)strtoull(vp, NULL, 0);

	if (xdr_uint64_t(xdrp, &val) == FALSE)
		return (TCL_ERROR);
	al->attrlist4_len += xdr_sizeof(xdr_uint64_t, &val);

	return (TCL_OK);
}

int
en_uint32(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	uint32_t val;

	substitution(interp, vp);
	vp = interp->result;
	val = (uint32_t)atoi(vp);

	if (xdr_uint32_t(xdrp, &val) == FALSE)
		return (TCL_ERROR);
	al->attrlist4_len += xdr_sizeof(xdr_uint32_t, &val);

	return (TCL_OK);
}

int
en_specdata(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {
	specdata4 sd4;
	char buf[80];
	int lc;
	char **lv;
	int code = TCL_ERROR;

	/* need to split the specdata strings to specdata1 and specdata2 */
	if (Tcl_SplitList(interp, vp, &lc, (CONST84 char ***)&lv) != TCL_OK) {
		sprintf(buf, "encoding specdata error, can't split {%s}", vp);
		interp->result = buf;
		return (code);
	}
	if (lc != 2) {
		sprintf(buf, "encoding specdata error, {%s} needs 2 fields",
			vp);
		interp->result = buf;
		goto lv_exit;
	}

	/* convert the strings to specdata1 & specdata2 */
	substitution(interp, lv[0]);
	sd4.specdata1 = (uint32_t)atoi(interp->result);
	substitution(interp, lv[1]);
	sd4.specdata2 = (uint32_t)atoi(interp->result);

	if (xdr_specdata4(xdrp, &sd4) == FALSE)
		goto lv_exit;
	al->attrlist4_len += xdr_sizeof(xdr_specdata4, &sd4);
	code = TCL_OK;

lv_exit:
	if (lv)
		free((char *)lv);
	return (code);
}

int
en_mode(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	mode4 m;
	int   m_i;
	char buf[80];

	substitution(interp, vp);
	vp = interp->result;
	m_i = strtoll(vp, NULL, 8);
	if (m_i < 0)
		return (TCL_ERROR);
	else
		m = (mode4) m_i;

	if (xdr_mode4(xdrp, &m) == FALSE)
		return (TCL_ERROR);
	al->attrlist4_len += xdr_sizeof(xdr_mode4, &m);

	return (TCL_OK);
}

int
en_utf8string(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	utf8string *val;

	substitution(interp, vp);
	vp = interp->result;
	val = (utf8string *) str2utf8(vp);

	if (xdr_utf8string(xdrp, val) == FALSE)
		return (TCL_ERROR);
	al->attrlist4_len += xdr_sizeof(xdr_utf8string, val);

	return (TCL_OK);
}

int
en_time(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	nfstime4 tm;
	char buf[80];
	int lc;
	char **lv;
	int code = TCL_ERROR;

	/* need to split the time strings to second and nsecond */
	if (Tcl_SplitList(interp, vp, &lc, (CONST84 char ***)&lv) != TCL_OK) {
		sprintf(buf, "encoding time error, can't split {%s}", vp);
		interp->result = buf;
		return (code);
	}
	if (lc != 2) {
		sprintf(buf, "encoding time error, {%s} needs 2 fields", vp);
		interp->result = buf;
		goto lv_exit;
	}

	/* convert the strings to second & nsecond */
	substitution(interp, lv[0]);
	tm.seconds = (int64_t)strtoll(interp->result, NULL, 10);
	substitution(interp, lv[1]);
	tm.nseconds = (uint32_t)strtol(interp->result, NULL, 10);

	if (xdr_nfstime4(xdrp, &tm) == FALSE)
		goto lv_exit;
	al->attrlist4_len += xdr_sizeof(xdr_nfstime4, &tm);
	code = TCL_OK;

lv_exit:
	if (lv)
		free((char *)lv);
	return (code);
}

int
en_timeset(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	settime4 st;
	char buf[80];
	int lc;
	char **lv;
	int code = TCL_ERROR;

	/*
	 * Assumed it always set to server's time; otherwise time
	 * arguments are needed.  Thus set argument format to:
	 *   {name 0} -> time_how4 will be SET_TO_SERVER_TIME4;
	 *   {name {sec nsec}} -> time_how4 will be SET_TO_CLIENT_TIME4;
	 */

	/* need to split the time strings to second and nsecond */
	if (Tcl_SplitList(interp, vp, &lc, (CONST84 char ***)&lv) != TCL_OK) {
		sprintf(buf, "encoding time error, can't split {%s}", vp);
		interp->result = buf;
		return (code);
	}
	if (lc == 1) {
		st.set_it = 0;		/* SET_TO_SERVER_TIME4 */
	} else if (lc == 2) {
		st.set_it = 1;		/* SET_TO_CLIENT_TIME4 */
		/* convert the strings to second & nsecond */
		substitution(interp, lv[0]);
		st.settime4_u.time.seconds =
		    (int64_t)strtoll(interp->result, NULL, 10);
		substitution(interp, lv[1]);
		st.settime4_u.time.nseconds
		    = (uint32_t)strtol(interp->result, NULL, 10);
	} else {
		sprintf(buf,
		    "encoding time error, {%s} has more than 2 fields", vp);
		interp->result = buf;
		goto lv_exit;
	}

	if (xdr_settime4(xdrp, &st) == FALSE)
		goto lv_exit;
	al->attrlist4_len += xdr_sizeof(xdr_settime4, &st);
	code = TCL_OK;

lv_exit:
	if (lv)
		free((char *)lv);
	return (code);
}

int
en_stat4(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	nfsstat4 err;

	substitution(interp, vp);
	vp = interp->result;
	err = str2err(vp);

	if (xdr_nfsstat4(xdrp, &err) == FALSE)
		return (TCL_ERROR);
	al->attrlist4_len += xdr_sizeof(xdr_nfsstat4, &err);

	return (TCL_OK);
}

int
en_unimpl(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	char buf[80];

	sprintf(buf, "this bit value %s is not implemented", vp);
	interp->result = buf;

	return (TCL_ERROR);
}

/*
 * Given a bitmap that describes which attributes are
 * contained in the XDR stream, this function decodes
 * the attributes and appends them to a list of strings.
 * e.g. "{{type dir} {size 1614} {mode 666}}"
 */
int
attr_decode(Tcl_Interp *interp, Tcl_DString *strp,
    bitmap4 *bmp, attrlist4 *attrvals)
{
	XDR xdrs;
	ATTRINFO *aip;
	int i;

#ifdef DEBUG_ACL
	(void) fprintf(stderr,
	    "\nattr_decode(interp, strp, bmp, attrvals)\n"
	    "\tinterp == %p"
	    "\tstrp == %p\n",
	    interp, strp);
	debug_print_bitmap("bmp", bmp);
	debug_print_attrvals("attrvals", attrvals);
#endif
	Tcl_DStringStartSublist(strp);

	xdrmem_create(&xdrs, attrvals->attrlist4_val,
	    attrvals->attrlist4_len, XDR_DECODE);

	for (i = 0; i < tblsize; i++) {

		if (!getbit(bmp, i))
			continue;

		aip = &attr_info[i];

		Tcl_DStringStartSublist(strp);

		if ((aip->defunc)(&xdrs, strp, aip->name) != TCL_OK) {
			char buf[80];

			sprintf(buf, "attr=%s, decode error", aip->name);
			interp->result = buf;
#ifdef DEBUG_ACL
			(void) fprintf(stderr,
			    "\tinterp->result == %s\n"
			    "attr_decode() == TCL_ERROR\n",
			    interp->result);
#endif
			return (TCL_ERROR);
		}

		Tcl_DStringEndSublist(strp);
	}

	Tcl_DStringEndSublist(strp);


	xdr_destroy(&xdrs);
#ifdef DEBUG_ACL
	(void) fprintf(stderr, "attr_decode() == TCL_OK\n");
#endif
	return (TCL_OK);
}

/*
 * This split a list of attribute {names val} pairs to get names and
 * attribute values; and set it to its bitmap and attrlists.
 */
int
attr_encode(Tcl_Interp *interp, char *nvpairs, bitmap4 *bmp, attrlist4 *al)
{
	int attrcnt = 0;
	char **attrnv = NULL;
	int lc = 0;
	char **lv = NULL;
	char *names = NULL;
	char **vp = NULL;
	char buf[512] = "";
	char **tmp = NULL;
	char *temp = NULL;
	int bitno = 0;
	int i = 0;
	int code = TCL_ERROR;

#ifdef DEBUG_ACL
	(void) fprintf(stderr,
	    "\nattr_encode(interp, nvpairs, bmp, al)\n"
	    "\tinterp == %p\n",
	    interp);
	debug_print_nvpairs("nvpairs", nvpairs);
	(void) fprintf(stderr, "\tbmp == %p\n", bmp);
	(void) fprintf(stderr, "\tal == %p\n", al);
#endif

	/*
	 * First split the name_val pairs of the attributes.
	 * should get attr count and {name val} string.
	 */
	if (Tcl_SplitList(interp, nvpairs, &attrcnt,
	    (CONST84 char ***)&attrnv) != TCL_OK) {
		sprintf(buf, "Error in Tcl_SplitList():\n%s\n"
		    "attr_encode(): can't split nvpairs={%s}",
		    Tcl_GetStringResult(interp),
		    (nvpairs == NULL ? "" : nvpairs));
		goto buf_exit;
	}

	/*
	 * Allocate an array for the names;
	 * assume longest name + space separator + null char
	 * has ATTR_NAME_LEN bytes per name.
	 */
	names = calloc(attrcnt, ATTR_NAME_LEN);
	if (names == NULL) {
		sprintf(buf, "Out of memory in attr_encode()");
		goto buf_exit;
	}

	names[0] = '\0';
	if ((vp = calloc(tblsize, sizeof (char *))) == NULL) {
		sprintf(buf, "Out of memory in attr_encode()");
		goto buf_exit;
	}

	/* Now go through the list  ... */
	for (i = 0; i < attrcnt; i++) {
		char lv0[1024] = "";
		char lv1[1024] = "";

		/* Has to split it again for from {name val} pair */
		if (Tcl_SplitList(interp, attrnv[i], &lc,
		    (CONST84 char ***)&lv) != TCL_OK) {
			sprintf(buf, "Error in Tcl_SplitList():\n%s\n"
			    "attr_encode(): can't split attrnv[%d]={%s}",
			    Tcl_GetStringResult(interp), i,
			    (attrnv[i] == NULL ? "" : attrnv[i]));
			goto buf_exit;
		}
		switch (lc) {
		case 0:
			if ((tmp = malloc(2*sizeof (char *))) == NULL) {
				sprintf(buf, "Out of memory in attr_encode()");
				goto buf_exit;
			}
			tmp[0] = "";
			tmp[1] = "";
			if (lv) {
				free((char *)lv);
			}
			lv = tmp;
			break;
		case 1:	/* val is empty */
			if ((tmp = malloc(2*sizeof (char *))) == NULL) {
				sprintf(buf, "Out of memory in attr_encode()");
				goto buf_exit;
			}
			tmp[1] = "";
			tmp[0] = tmp[1];
			if (lv) { /* kind of paranoid check since lc == 1 */
				tmp[0] = lv[0];
				free((char *)lv);
			}
			lv = tmp;
			break;
		case 2:	/* when lc ==  2, every thing is OK */
			break;
		default:
			if (lc < 0)
				/* paranoid test since lc should not be < 0 */
				goto error_exit;
			/* (lc > 2) take rest of the tokens as one */
			if ((temp = strstr(attrnv[i], lv[1])) == NULL) {
				/* no tokens? */
				goto error_exit;
			}
			lv[1] = temp;
			break;
		}

		substitution(interp, lv[0]);
		strcpy(lv0, interp->result);
		if (lv[0] != '\0') {
			strcat(names, lv0);
		}
		if (names[0] != '\0') { /* if any name is stored */
			strcat(names, " ");
		}

		/* build the attribute value array */
		if (lv0[0] != '\0') { /* if not empty */
			if ((bitno = name2bit(lv0)) < 0) {
				sprintf(buf,
				"set_attrvals(): incorrect attribute name [%s]",
				    lv0);
				goto buf_exit;
			}

			substitution(interp, lv[1]);
			strcpy(lv1, interp->result);
			vp[bitno] = malloc(sizeof (lv1) + 1);
			if (vp[bitno] == NULL) {
				sprintf(buf, "Out of memory in attr_encode()");
				goto buf_exit;
			}
			strcpy(vp[bitno], lv1);
		}
	}

	/* now set the bitmap */
	if ((names2bitmap(interp, names, bmp)) != TCL_OK) {
		sprintf(buf, "attr_encode could not set bitmap");
		goto buf_exit;
	}

	/* and the attrlist */
	if ((names2alist(interp, bmp, al, vp)) != TCL_OK) {
		sprintf(buf, "attr_encode could not set attrlist");
		goto buf_exit;
	}

	code = TCL_OK;
	goto lv_exit;

error_exit:
	sprintf(buf, "attr_encode(): error in {name val}, {%s} lc=%d",
	    (attrnv == NULL) ? "NULL" : attrnv[i], lc);
buf_exit:
	Tcl_SetResult(interp, buf, TCL_VOLATILE);
lv_exit:
	/* free temporal attribute values and array of pointers */
	for (i = 0; i < tblsize; i++) {
		if (vp) {
			if (vp[i]) {
				free(vp[i]);
			}
		}
	}
	if (vp) {
		free(vp);
	}
	if (lv)
		free((char *)lv);
	if (attrnv)
		free((char *)attrnv);
	if (names)
		free(names);
	return (code);
}

/*
 * Given the attribute bitmap and value, build the attrlists.
 */
int
names2alist(Tcl_Interp *interp, bitmap4 *bmp, attrlist4 *al, char **vp)
{
	XDR xdrs;
	ATTRINFO *aip;
	int i;
	int vsize;
	char buf[128];

	/*
	 * There are only 14 writable attributes (for Setattr);
	 * But try to allocate big enough memory size and
	 * hope it's enough.
	 */
	vsize = 14 * 128;
	al->attrlist4_len = 0;
	al->attrlist4_val = malloc(vsize);

	xdrmem_create(&xdrs, al->attrlist4_val, vsize, XDR_ENCODE);

	for (i = 0; i < tblsize; i++) {
		if (!getbit(bmp, i))
			continue;

		if (al->attrlist4_len >= vsize) {
			interp->result =
			    "attribute encode error, attrlist len too long.";
			return (TCL_ERROR);
		}

		aip = &attr_info[i];

#ifdef DEBUG_ACL
		if (aip->enfunc == en_acl) {
			(void) fprintf(stderr,
			    "attr_encode(), line %d: about to call en_acl()\n",
			    __LINE__);
		}
#endif
		if ((aip->enfunc)(&xdrs, interp, vp[i], al) != TCL_OK) {
			sprintf(buf, "%s - %s",
			    "attribute encode error", interp->result);
			interp->result = buf;
			return (TCL_ERROR);
		}
	}

	xdr_destroy(&xdrs);

	return (TCL_OK);
}

int
en_acl(XDR *xdrp, Tcl_Interp *interp, char *vp, attrlist4 *al) {

	static fattr4_acl facl;
	nfsace4	*ace;
	char ebuf[80];
	char *aval;
	char **lv1, **lv2;
	int lc1, lc2;
	int i, ret;

#ifdef DEBUG_ACL
	(void) fprintf(stderr, "\nen_acl(xdrp, interp, vp, al)\n");
	(void) fprintf(stderr,
	    "\txprp == %p, interp == %p\n"
	    "\tvp == %s\n",
	    xdrp, interp, vp ? vp : "NULL");
	debug_print_attrvals("al", al);
#endif

	/* split the acl_val for ace entries */
	if (Tcl_SplitList(interp, vp, &lc1, (CONST84 char ***)&lv1) != TCL_OK) {
		(void) sprintf(ebuf,
			"encoding time error, can't split {%s}", vp);
		interp->result = ebuf;
		return (TCL_ERROR);
	}
	if (lc1 <= 0) {
		(void) sprintf(ebuf,
			"encoding acl error, {%s} can't be <= 0", vp);
		interp->result = ebuf;
		if (lv1)
			free((char *)lv1);
		return (TCL_ERROR);
	}
#ifdef DEBUG_ACL
	(void) fprintf(stderr, "Total of %d ace entries: \n", lc1);
#endif

	ace = (nfsace4 *)calloc(lc1, sizeof (nfsace4));
	if (ace == (nfsace4 *)NULL) {
		perror("calloc((nfsace4))");
		(void) fprintf(stderr, "%d -- file %s, line %d\n",
			lc1, __FILE__, __LINE__);
		ret = TCL_ERROR;
		goto fin;
	}

	for (i = 0; i < lc1; i++) {
		substitution(interp, lv1[i]);
		aval = interp->result;
		/* Now split the acl_val entries */
		if (Tcl_SplitList(interp, aval, &lc2,
		    (CONST84 char ***)&lv2) != TCL_OK) {
		    (void) sprintf(ebuf, "fail to split {%s}[%d]", aval, i);
		    interp->result = ebuf;
		    return (TCL_ERROR);
		}
		if (lc2 != 4) {
		    (void) sprintf(ebuf,
			"en_acl(): not enough ace members, need 4\n");
		    interp->result = ebuf;
		    if (lv2)
			free((char *)lv2);
		    return (TCL_ERROR);
		}

		substitution(interp, lv2[0]);
		ace[i].type = (uint32_t)strtol(interp->result, NULL, 10);
		substitution(interp, lv2[1]);
		ace[i].flag = (uint32_t)strtol(interp->result, NULL, 16);
		substitution(interp, lv2[2]);
		ace[i].access_mask = (uint32_t)strtol(interp->result, NULL, 16);
		substitution(interp, lv2[3]);
		ace[i].who = *str2utf8(interp->result);
#ifdef DEBUG_ACL
		(void) fprintf(stderr, "ace[%d]: type=%d,", i, ace[i].type);
		(void) fprintf(stderr, "flag=%x,", ace[i].flag);
		(void) fprintf(stderr, "access_mask=%x,", ace[i].access_mask);
		(void) fprintf(stderr, "who=%s\n", interp->result);
#endif
		free((char *)lv2);
	}

	facl.fattr4_acl_len = lc1;
	facl.fattr4_acl_val = ace;
	if (xdr_fattr4_acl(xdrp, &facl) == FALSE) {
#ifdef DEBUG_ACL
		(void) fprintf(stderr,
		    "en_acl(), line %d: xdr_fattr4_acl(xdrp, facl) failed\n",
		    __LINE__);
#endif
		ret = TCL_ERROR;
		goto fin;
	}
	al->attrlist4_len += xdr_sizeof(xdr_fattr4_acl, &facl);
	ret = TCL_OK;

fin:
	xdr_free(xdr_fattr4_acl, (char *)&facl);
	free((char *)lv1);
#ifdef DEBUG_ACL
	(void) fprintf(stderr, "attr_encode() == %s\n",
		(ret == TCL_OK) ? "TCL_OK" : "TCL_ERROR");
#endif
	return (ret);
}

#ifdef DEBUG_ACL

static void
debug_print_bitmap(char *name, bitmap4 *bitmap)
{
	uint_t i;

	(void) fprintf(stderr, "\t%s->bitmap4_len == %u\n",
	    name, bitmap->bitmap4_len);
	for (i = 0; i < bitmap->bitmap4_len; i++)
		(void) fprintf(stderr,
		    "\t%s->bitmap4_val[%u] == 0x%x\n",
		    name, i, bitmap->bitmap4_val[i]);
}

static void
debug_print_attrvals(char *name, attrlist4 *attrlist)
{
	uint_t i;

	(void) fprintf(stderr, "\t%s->attrlist4_len == %u\n",
	    name, attrlist->attrlist4_len);
	for (i = 0; i < attrlist->attrlist4_len; i++)
		(void) fprintf(stderr,
		    "\t%s->attrlist4_val[%u] == 0x%x\n",
		    name, i, attrlist->attrlist4_val[i]);
}

static void
debug_print_nvpairs(char *name, char *nvpairs)
{
	if (nvpairs == NULL) {
		(void) fprintf(stderr, "\t%s == NULL\n", name);
	} else {
		(void) fprintf(stderr, "\t%s == %s\n", name, nvpairs);
	}
}

#endif

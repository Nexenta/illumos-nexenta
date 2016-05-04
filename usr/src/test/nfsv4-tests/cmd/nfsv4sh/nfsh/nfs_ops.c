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

#include <rpc/rpc.h>
#include <rpc/clnt.h>
#include <rpc/clnt_soc.h>
#include "nfs4_prot.h"
#include "nfstcl4.h"

/* nfsv4 operations table */
NFSOP nfs_op[] = {
	{"Access",			Access	},
	{"Close",			Close	},
	{"Commit",			Commit	},
	{"Create",			Create	},
	{"Delegpurge",			Delegpurge},
	{"Delegreturn",			Delegreturn},
	{"Getattr",			Getattr	},
	{"Getfh",			Getfh	},
	{"Illegal",			Illegal },
	{"Link",			Link	},
	{"Lock",			Lock	},
	{"Lockt",			Lockt	},
	{"Locku",			Locku	},
	{"Lookup",			Lookup	},
	{"Lookupp",			Lookupp	},
	{"Nverify",			Nverify	},
	{"Open",			Open	},
	{"Openattr",			Openattr},
	{"Open_confirm",		Open_confirm},
	{"Open_downgrade",		Open_downgrade},
	{"Putfh",			Putfh	},
	{"Putpubfh",			Putpubfh},
	{"Putrootfh",			Putrootfh},
	{"Read",			Read	},
	{"Readdir",			Readdir	},
	{"Readlink",			Readlink},
	{"Release_lockowner",		Release_lockowner},
	{"Remove",			Remove	},
	{"Rename",			Rename	},
	{"Renew",			Renew	},
	{"Restorefh",			Restorefh},
	{"Savefh",			Savefh	},
	{"Secinfo",			Secinfo	},
	{"Setattr",			Setattr	},
	{"Setclientid",			Setclientid},
	{"Setclientid_confirm",		Setclientid_confirm},
	{"Verify",			Verify	},
	{"Write",			Write	},
	{0,				0	},
};

/* ------------------------------ */
/* Operation request functions.   */
/* ------------------------------ */

int
Access(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	uint32_t access;
	char *acl, ac;

	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result = "Usage: Access { rlmtdx i(0x100) }";
		return (TCL_ERROR);
	}

	opp->argop = OP_ACCESS;

	access = (uint32_t)0;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	acl = argv[1];
	while ((ac = *acl++) != '\0') {
		switch (ac) {
		case 'r':
			access = access | (uint32_t)ACCESS4_READ;
			break;
		case 'l':
			access = access | (uint32_t)ACCESS4_LOOKUP;
			break;
		case 'm':
			access = access | (uint32_t)ACCESS4_MODIFY;
			break;
		case 't':
			access = access | (uint32_t)ACCESS4_EXTEND;
			break;
		case 'd':
			access = access | (uint32_t)ACCESS4_DELETE;
			break;
		case 'x':
			access = access | (uint32_t)ACCESS4_EXECUTE;
			break;
		case 'i':
			access = access | (uint32_t)0x00000100;
			break;
		default:
			interp->result =
			    "Unknown accessreq, use {rlmtdx i(0x100)}";
			return (TCL_ERROR);
		}
	}

	opp->nfs_argop4_u.opaccess.access = access;

	return (TCL_OK);
}

int
Close(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	stateid4 stateid;
	nfs_argop4 *opp = new_argop();

	if (argc < 3) {
		interp->result = "Usage: Close seqid stateid{seqid other}";
		return (TCL_ERROR);
	}

	opp->argop = OP_CLOSE;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.opclose.seqid = (seqid4) atoi(argv[1]);
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	if (str2stateid(interp, argv[2], &stateid) != TCL_OK) {
		interp->result = "Close: str2stateid() error";
		return (TCL_ERROR);
	}
	opp->nfs_argop4_u.opclose.open_stateid = stateid;

	return (TCL_OK);
}

int
Commit(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();

	if (argc < 3) {
		interp->result = "Usage: Commit offset count";
		return (TCL_ERROR);
	}

	opp->argop = OP_COMMIT;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.opcommit.offset = (offset4) atol(argv[1]);
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	opp->nfs_argop4_u.opcommit.count = (count4) atoi(argv[2]);

	return (TCL_OK);
}

int
Create(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	char ct;
	char buf[80];
	char lv4[1024], lv5[1024];
	createtype4 ctype;
	bitmap4 bm;
	attrlist4 av;

	nfs_argop4 *opp = new_argop();

	if (argc < 4) {
		interp->result = "Usage: Create objname "
		    "{{name val} {name val} ...}\n       "
		    "s | f | d | l linkdata | b specd1 specd2 | "
		    "c specd1 specd2";
		return (TCL_ERROR);
	}

	opp->argop = OP_CREATE;

	substitution(interp, argv[3]);
	argv[3] = interp->result;
	ct = *argv[3];
	if (argc >= 5) {
		substitution(interp, argv[4]);
		strcpy(lv4, interp->result);
	}
	if (argc >= 6) {
		substitution(interp, argv[5]);
		strcpy(lv5, interp->result);
	}
	switch (ct) {
	case 'l':	ctype.type = NF4LNK;
		if (argc != 5) {
			interp->result = "Usage: "
			    "Create objname {attrs} l linkdata";
			return (TCL_ERROR);
		}
		ctype.createtype4_u.linkdata = *str2utf8(lv4);
		break;
	case 'b':	ctype.type = NF4BLK;
		if (argc != 6) {
			interp->result = "Usage: "
			    "Create objname {attrs} b specd1 specd2";
			return (TCL_ERROR);
		}
		ctype.createtype4_u.devdata.specdata1 =
		    (uint32_t)atoi(lv4);
		ctype.createtype4_u.devdata.specdata2 =
		    (uint32_t)atoi(lv5);
		break;
	case 'c':	ctype.type = NF4CHR;
		if (argc != 6) {
			interp->result = "Usage: "
			    "Create objname {attrs} c specd1 specd2";
			return (TCL_ERROR);
		}
		ctype.createtype4_u.devdata.specdata1 =
		    (uint32_t)atoi(lv4);
		ctype.createtype4_u.devdata.specdata2 =
		    (uint32_t)atoi(lv5);
		break;
	case 's':	ctype.type = NF4SOCK; break;
	case 'f':	ctype.type = NF4FIFO; break;
	case 'd':	ctype.type = NF4DIR;  break;
	/*
	 * XXX the following 'r' type is added for testing BADTYPE
	 */
	case 'r':	ctype.type = NF4REG;  break;
	default:
		sprintf(buf, "Unknown create-type [%c]", ct);
		interp->result = buf;
		return (TCL_ERROR);
	}

	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.opcreate.objname = *str2utf8(argv[1]);

	substitution(interp, argv[2]);
	argv[2] = interp->result;
	if ((attr_encode(interp, argv[2], &bm, &av)) != TCL_OK)
		return (TCL_ERROR);
	opp->nfs_argop4_u.opcreate.createattrs.attrmask = bm;
	opp->nfs_argop4_u.opcreate.createattrs.attr_vals = av;

	opp->nfs_argop4_u.opcreate.objtype = ctype;

	return (TCL_OK);
}

int
Delegpurge(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();

	if (argc < 2) {
		interp->result = "Usage: Delegpurge clientid";
		return (TCL_ERROR);
	}

	opp->argop = OP_DELEGPURGE;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.opdelegpurge.clientid = strtoull(argv[1], NULL, 16);

	return (TCL_OK);
}

int
Delegreturn(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	int lc;
	char **lv;
	stateid4 stateid;

	nfs_argop4 *opp = new_argop();

	if (argc < 2) {
		interp->result = "Usage: Delegreturn stateid{seqid other}";
		return (TCL_ERROR);
	}

	opp->argop = OP_DELEGRETURN;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	if (str2stateid(interp, argv[1], &stateid) != TCL_OK) {
		interp->result = "Delegreturn: str2stateid() error";
		return (TCL_ERROR);
	}

	opp->nfs_argop4_u.opdelegreturn.deleg_stateid = stateid;

	return (TCL_OK);
}

int
Getattr(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	bitmap4 bm;
	int err;
	char lv1[2048];

	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result =
		    "Usage: Getattr { attrname attrname ... }";
		return (TCL_ERROR);
	}

	opp->argop = OP_GETATTR;

	substitution(interp, argv[1]);
	strcpy(lv1, interp->result);
	err = names2bitmap(interp, lv1, &bm);
	if (err != TCL_OK)
		return (err);

	opp->nfs_argop4_u.opgetattr.attr_request = bm;

	return (TCL_OK);
}

int
Getfh(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();
	if (argc != 1) {
		interp->result = "Arguments ignored!\nUsage: Getfh";
	}
	opp->argop = OP_GETFH;

	return (TCL_OK);
}

int
Illegal(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();
	if (argc != 1) {
		interp->result = "Arguments ignored!\nUsage: Illegal";
	}
	opp->argop = OP_ILLEGAL;

	return (TCL_OK);
}

int
Link(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result = "Usage: Link newname";
		return (TCL_ERROR);
	}

	opp->argop = OP_LINK;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.oplink.newname = *str2utf8(argv[1]);

	return (TCL_OK);
}

int
Lock(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	int	lt;
	bool_t	rc;
	stateid4 stateid;
	lock_owner4 lowner;
	seqid4 lseqid;
	seqid4 oseqid;
	int lc;
	char **lv;
	char buf[80], lv2[1024];

	nfs_argop4 *opp = new_argop();

	if (argc < 8) {
		interp->result =
		    "Usage: Lock ltype(1|2|3|4) reclaim(T|F) offset "
		    "length newlock(T|F)\n       "
		    "stateid{seqid other} lseqid {oseqid clientid lowner}";
		return (TCL_ERROR);
	}

	opp->argop = OP_LOCK;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	lt = atoi(argv[1]);
	switch (lt) {
	case 1:
		opp->nfs_argop4_u.oplock.locktype = READ_LT;
		break;
	case 2:
		opp->nfs_argop4_u.oplock.locktype = WRITE_LT;
		break;
	case 3:
		opp->nfs_argop4_u.oplock.locktype = READW_LT;
		break;
	case 4:
		opp->nfs_argop4_u.oplock.locktype = WRITEW_LT;
		break;
	default:
		sprintf(buf, "Unknown lock-type [%s]", argv[1]);
		interp->result = buf;
		return (TCL_ERROR);
	}
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	rc = argv[2][0];
	switch (rc) {
	case 'T':
	case 't':
		opp->nfs_argop4_u.oplock.reclaim = TRUE;
		break;
	case 'F':
	case 'f':
		opp->nfs_argop4_u.oplock.reclaim = FALSE;
		break;
	default:
		sprintf(buf, "Unknown reclaim [%s]; should be T|F", argv[2]);
		interp->result = buf;
		return (TCL_ERROR);
	}
	substitution(interp, argv[3]);
	argv[3] = interp->result;
	opp->nfs_argop4_u.oplock.offset = (offset4) strtoull(argv[3], NULL, 10);
	substitution(interp, argv[4]);
	argv[4] = interp->result;
	opp->nfs_argop4_u.oplock.length = (length4) strtoull(argv[4], NULL, 10);
	substitution(interp, argv[5]);
	argv[5] = interp->result;
	rc = argv[5][0];
	substitution(interp, argv[6]);
	argv[6] = interp->result;
	if (str2stateid(interp, argv[6], &stateid) != TCL_OK) {
		interp->result = "Lock: str2stateid() error";
		return (TCL_ERROR);
	}
	substitution(interp, argv[7]);
	argv[7] = interp->result;
	lseqid = (seqid4) atoi(argv[7]);
	/*
	 * argv[8] is for new open only;
	 * Need to split "{oseqid clientid owner}".
	 */
	substitution(interp, argv[8]);
	argv[8] = interp->result;
	if (Tcl_SplitList(interp, argv[8], &lc,
	    (CONST84 char ***)&lv) != TCL_OK) {
		sprintf(buf, "Lock arg error, can't split {%s}", argv[8]);
		interp->result = buf;
		return (TCL_ERROR);
	}
	if (lc < 3) {
		sprintf(buf,
		    "Lock arg error, {%s} needs at least 3 fields", argv[8]);
		interp->result = buf;
		if (lv)
			free((char *)lv);
		return (TCL_ERROR);
	}
	substitution(interp, lv[0]);
	oseqid = (seqid4)atoi(interp->result);
	substitution(interp, lv[1]);
	lowner.clientid = (clientid4)strtoull(interp->result, NULL, 16);
	substitution(interp, lv[2]);
	strcpy(lv2, interp->result);
	lowner.owner.owner_val = lv2;
	lowner.owner.owner_len = strlen(lowner.owner.owner_val);
	switch (rc) {
	case 'T':
	case 't':
	opp->nfs_argop4_u.oplock.locker.new_lock_owner = TRUE;
	opp->nfs_argop4_u.oplock.locker.locker4_u.open_owner.open_stateid =
	    stateid;
	opp->nfs_argop4_u.oplock.locker.locker4_u.open_owner.open_seqid =
	    oseqid;
	opp->nfs_argop4_u.oplock.locker.locker4_u.open_owner.lock_seqid =
	    lseqid;
	opp->nfs_argop4_u.oplock.locker.locker4_u.open_owner.lock_owner =
	    lowner;
	break;
	case 'F':
	case 'f':
	opp->nfs_argop4_u.oplock.locker.new_lock_owner = FALSE;
	opp->nfs_argop4_u.oplock.locker.locker4_u.lock_owner.lock_stateid =
	    stateid;
	opp->nfs_argop4_u.oplock.locker.locker4_u.lock_owner.lock_seqid =
	    lseqid;
	break;
	default:
		sprintf(buf, "Unknown newlock [%s]; should be T|F", argv[5]);
		interp->result = buf;
		if (lv)
			free((char *)lv);
		return (TCL_ERROR);
	}

	if (lv)
		free((char *)lv);
	return (TCL_OK);
}

int
Lockt(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	int	lt;
	bool_t	rc;
	char buf[80], lv3[1024];

	nfs_argop4 *opp = new_argop();

	if (argc != 6) {
		interp->result = "Usage: Lockt type(1|2|3|4) "
		    "clientid lowner offset length";
		return (TCL_ERROR);
	}

	opp->argop = OP_LOCKT;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	lt = atoi(argv[1]);
	switch (lt) {
	case 1:
		opp->nfs_argop4_u.oplockt.locktype = READ_LT;
		break;
	case 2:
		opp->nfs_argop4_u.oplockt.locktype = WRITE_LT;
		break;
	case 3:
		opp->nfs_argop4_u.oplockt.locktype = READW_LT;
		break;
	case 4:
		opp->nfs_argop4_u.oplockt.locktype = WRITEW_LT;
		break;
	default:
		sprintf(buf, "Unknown lock-type [%s]", argv[1]);
		interp->result = buf;
		return (TCL_ERROR);
	}
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	opp->nfs_argop4_u.oplockt.owner.clientid =
	    (clientid4) strtoull(argv[2], NULL, 16);

	substitution(interp, argv[3]);
	strcpy(lv3, interp->result);

	opp->nfs_argop4_u.oplockt.owner.owner.owner_val = lv3;
	opp->nfs_argop4_u.oplockt.owner.owner.owner_len = strlen(lv3);
	substitution(interp, argv[4]);
	argv[4] = interp->result;
	opp->nfs_argop4_u.oplockt.offset =
	    (offset4) strtoull(argv[4], (char **)NULL, 10);
	substitution(interp, argv[5]);
	argv[5] = interp->result;
	opp->nfs_argop4_u.oplockt.length =
	    (length4) strtoull(argv[5], (char **)NULL, 10);

	return (TCL_OK);
}

int
Locku(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	int	lt;
	char buf[80];
	stateid4 stateid;

	nfs_argop4 *opp = new_argop();

	if (argc != 6) {
		interp->result =
		    "Usage: Locku type(1|2|3|4) lseqid "
		    "lstateid{seqid other} offset length";
		return (TCL_ERROR);
	}

	opp->argop = OP_LOCKU;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	lt = atoi(argv[1]);
	switch (lt) {
	case 1:
		opp->nfs_argop4_u.oplocku.locktype = READ_LT;
		break;
	case 2:
		opp->nfs_argop4_u.oplocku.locktype = WRITE_LT;
		break;
	case 3:
		opp->nfs_argop4_u.oplocku.locktype = READW_LT;
		break;
	case 4:
		opp->nfs_argop4_u.oplocku.locktype = WRITEW_LT;
		break;
	default:
		sprintf(buf, "Unknown locktype [%s]", argv[1]);
		interp->result = buf;
		return (TCL_ERROR);
	}
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	opp->nfs_argop4_u.oplocku.seqid = (seqid4)atoi(argv[2]);
	substitution(interp, argv[3]);
	argv[3] = interp->result;
	if (str2stateid(interp, argv[3], &stateid) != TCL_OK) {
		interp->result = "Locku: str2stateid() error";
		return (TCL_ERROR);
	}
	opp->nfs_argop4_u.oplocku.lock_stateid = stateid;
	substitution(interp, argv[4]);
	argv[4] = interp->result;
	opp->nfs_argop4_u.oplocku.offset =
	    (offset4) strtoull(argv[4], (char **)NULL, 10);
	substitution(interp, argv[5]);
	argv[5] = interp->result;
	opp->nfs_argop4_u.oplocku.length =
	    (length4) strtoull(argv[5], (char **)NULL, 10);

	return (TCL_OK);
}

int
Lookup(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result = "Usage: Lookup objname";
		return (TCL_ERROR);
	}

	opp->argop = OP_LOOKUP;

	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.oplookup.objname = *str2utf8(argv[1]);

	return (TCL_OK);
}

int
Lookupp(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();
	if (argc != 1) {
		interp->result = "Arguments ignored!\nUsage: Lookupp";
	}
	opp->argop = OP_LOOKUPP;

	return (TCL_OK);
}

int
Nverify(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	bitmap4 bm;
	attrlist4 av;
	char lv1[2048];

	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result =
		    "Usage: Nverify { {name val} {name val} ... }";
		return (TCL_ERROR);
	}

	opp->argop = OP_NVERIFY;

	substitution(interp, argv[1]);
	strcpy(lv1, interp->result);
	if ((attr_encode(interp, lv1, &bm, &av)) != TCL_OK)
		return (TCL_ERROR);

	opp->nfs_argop4_u.opnverify.obj_attributes.attrmask = bm;
	opp->nfs_argop4_u.opnverify.obj_attributes.attr_vals = av;

	return (TCL_OK);
}

int
Open(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();

	if (argc != 7) {
		interp->result =
		    "Usage: Open\n       oseqid "
		    "access(1|2|3) deny(0|1|2|3) {clientid open_owner}\n"
		    "       {opentype(0|1) createmode(0|1|2) "
		    "{{name val} {name val}...} | createverf}\n       "
		    "{claim(0|1|2|3) {filename | delegate_type | "
		    "{delegate_stateid filename}}}\n       ";
		return (TCL_ERROR);
	}

	opp->argop = OP_OPEN;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.opopen.seqid = (seqid4)atoi(argv[1]);
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	opp->nfs_argop4_u.opopen.share_access = (uint32_t)atoi(argv[2]);
	substitution(interp, argv[3]);
	argv[3] = interp->result;
	opp->nfs_argop4_u.opopen.share_deny = (uint32_t)atoi(argv[3]);
	/* no substitution is needed for argv[4] to argv[6] here, */
	/* since its done inside the set_xxxxx() functions */
	if (set_owner(interp, argv[4], &opp->nfs_argop4_u.opopen.owner)
	    != TCL_OK)
		return (TCL_ERROR);
	if (set_opentype(interp, argv[5], &opp->nfs_argop4_u.opopen.openhow)
	    != TCL_OK)
		return (TCL_ERROR);
	if (set_openclaim(interp, argv[6], &opp->nfs_argop4_u.opopen.claim)
	    != TCL_OK)
		return (TCL_ERROR);

	return (TCL_OK);
}

int
Openattr(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	bool_t cdir;
	char buf[80];

	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result = "Usage: Openattr createdir(T|F)";
		return (TCL_ERROR);
	}

	opp->argop = OP_OPENATTR;

	substitution(interp, argv[1]);
	argv[1] = interp->result;
	cdir = argv[1][0];
	switch (cdir) {
	case 'T':
	case 't':
		opp->nfs_argop4_u.opopenattr.createdir = TRUE;
		break;
	case 'F':
	case 'f':
		opp->nfs_argop4_u.opopenattr.createdir = FALSE;
		break;
	default:
		sprintf(buf, "Unknown createdir [%s]; should be T|F", argv[1]);
		interp->result = buf;
		return (TCL_ERROR);
	}

	return (TCL_OK);
}

int
Open_confirm(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	stateid4 stateid;
	nfs_argop4 *opp = new_argop();

	if (argc != 3) {
		interp->result = "Usage: Open_confirm "
		    "open_stateid{seqid other} seqid";
		return (TCL_ERROR);
	}

	opp->argop = OP_OPEN_CONFIRM;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	if (str2stateid(interp, argv[1], &stateid) != TCL_OK) {
		interp->result = "Open_confirm: str2stateid() error";
		return (TCL_ERROR);
	}
	opp->nfs_argop4_u.opopen_confirm.open_stateid = stateid;
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	opp->nfs_argop4_u.opopen_confirm.seqid = (seqid4) atoi(argv[2]);

	return (TCL_OK);
}

int
Open_downgrade(ClientData clientData, Tcl_Interp *interp,
    int argc, char *argv[])
{
	stateid4 stateid;
	nfs_argop4 *opp = new_argop();

	if (argc != 5) {
		interp->result =
		    "Usage: Open_downgrade stateid{seqid other} "
		    "seqid access deny";
		return (TCL_ERROR);
	}

	opp->argop = OP_OPEN_DOWNGRADE;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	if (str2stateid(interp, argv[1], &stateid) != TCL_OK) {
		interp->result = "Open_downgrade: str2stateid() error";
		return (TCL_ERROR);
	}
	opp->nfs_argop4_u.opopen_downgrade.open_stateid = stateid;
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	opp->nfs_argop4_u.opopen_downgrade.seqid = (seqid4)atoi(argv[2]);
	substitution(interp, argv[3]);
	argv[3] = interp->result;
	opp->nfs_argop4_u.opopen_downgrade.share_access =
	    (uint32_t)atoi(argv[3]);
	substitution(interp, argv[4]);
	argv[4] = interp->result;
	opp->nfs_argop4_u.opopen_downgrade.share_deny =
	    (uint32_t)atoi(argv[4]);

	return (TCL_OK);
}

int
Putfh(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	char *fhstr;
	int fhlen;
	char *fhp;

	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result = "Usage: Putfh <fh>";
		return (TCL_ERROR);
	}

	opp->argop = OP_PUTFH;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	fhstr = argv[1];
	fhlen = (strlen(fhstr) + 1) / 2;

	fhp = malloc(fhlen);
	if (fhp == NULL) {
		interp->result = "malloc failure in Putfh";
		return (TCL_ERROR);
	}
	(void) memcpy(fhp, hex2bin(fhstr, (unsigned)fhlen), fhlen);

	opp->nfs_argop4_u.opputfh.object.nfs_fh4_len = fhlen;
	opp->nfs_argop4_u.opputfh.object.nfs_fh4_val = fhp;

	return (TCL_OK);
}

int
Putpubfh(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();
	if (argc != 1) {
		interp->result = "Arguments ignored!\nUsage: Putpubfh";
	}
	opp->argop = OP_PUTPUBFH;

	return (TCL_OK);
}

int
Putrootfh(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();
	if (argc != 1) {
		interp->result = "Arguments ignored!\nUsage: Putrootfh";
	}
	opp->argop = OP_PUTROOTFH;

	return (TCL_OK);
}

int
Read(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	stateid4 stateid;
	nfs_argop4 *opp = new_argop();

	if (argc != 4) {
		interp->result = "Usage: Read stateid{seqid other} "
		    "offset count";
		return (TCL_ERROR);
	}

	opp->argop = OP_READ;

	substitution(interp, argv[1]);
	argv[1] = interp->result;
	if (str2stateid(interp, argv[1], &stateid) != TCL_OK) {
		interp->result = "Read: str2stateid() error";
		return (TCL_ERROR);
	}
	opp->nfs_argop4_u.opread.stateid = stateid;
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	opp->nfs_argop4_u.opread.offset =
	    (offset4) strtoull(argv[2], (char **)NULL, 10);
	substitution(interp, argv[3]);
	argv[3] = interp->result;
	opp->nfs_argop4_u.opread.count = (count4) atoi(argv[3]);

	return (TCL_OK);
}

int
Readdir(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_cookie4 cookie;
	verifier4 verf;
	count4 dircount;
	count4 maxcount;
	bitmap4 bm;
	int err;
	char lv3[1024], lv4[1024], lv5[2048];

	nfs_argop4 *opp = new_argop();

	if (argc != 6) {
		interp->result =
		    "Usage: Readdir cookie verf "
		    "dircount maxcount {attrname ...}";
		return (TCL_ERROR);
	}

	opp->argop = OP_READDIR;

	substitution(interp, argv[1]);
	argv[1] = interp->result;

	cookie = (nfs_cookie4) strtoull(argv[1], NULL, 10);

	substitution(interp, argv[2]);
	argv[2] = interp->result;
	(void) memcpy(verf, hex2bin(argv[2], sizeof (verf)), sizeof (verf));

	substitution(interp, argv[3]);
	strcpy(lv3, interp->result);
	if (Tcl_GetInt(interp, lv3, (int *)&dircount) != TCL_OK)
		goto err;

	substitution(interp, argv[4]);
	strcpy(lv4, interp->result);
	if (Tcl_GetInt(interp, lv4, (int *)&maxcount) != TCL_OK)
		goto err;

	opp->nfs_argop4_u.opreaddir.cookie = cookie;
	(void) memcpy(opp->nfs_argop4_u.opreaddir.cookieverf,
	    verf, sizeof (verf));
	opp->nfs_argop4_u.opreaddir.dircount = dircount;
	opp->nfs_argop4_u.opreaddir.maxcount = maxcount;

	substitution(interp, argv[5]);
	strcpy(lv5, interp->result);
	err = names2bitmap(interp, lv5, &bm);
	if (err != TCL_OK)
		return (err);

	opp->nfs_argop4_u.opreaddir.attr_request = bm;

	return (TCL_OK);

err:
	return (TCL_ERROR);
}

int
Readlink(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();
	if (argc != 1) {
		interp->result = "Arguments ignored!\nUsage: Readlink";
	}
	opp->argop = OP_READLINK;

	return (TCL_OK);
}

int
Release_lockowner(ClientData clientData, Tcl_Interp *interp,
	int argc, char *argv[])
{
	char tmp[1024];
	nfs_argop4 *opp = new_argop();

	if (argc != 3) {
		interp->result = "Usage: Release_lockowner clientid lowner";
		return (TCL_ERROR);
	}

	opp->argop = OP_RELEASE_LOCKOWNER;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.oprelease_lockowner.lock_owner.clientid =
	    (clientid4) strtoull(argv[1], NULL, 16);

	substitution(interp, argv[2]);
	strcpy(tmp, interp->result);
	opp->nfs_argop4_u.oprelease_lockowner.lock_owner.owner.owner_val = tmp;
	opp->nfs_argop4_u.oprelease_lockowner.lock_owner.owner.owner_len =
	    strlen(tmp);

	return (TCL_OK);
}

int
Remove(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result = "Usage: Remove target";
		return (TCL_ERROR);
	}

	opp->argop = OP_REMOVE;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.oplink.newname = *str2utf8(argv[1]);

	return (TCL_OK);
}

int
Rename(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();

	if (argc != 3) {
		interp->result = "Usage: Rename oldname newname";
		return (TCL_ERROR);
	}

	opp->argop = OP_RENAME;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.oprename.oldname = *str2utf8(argv[1]);
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	opp->nfs_argop4_u.oprename.newname = *str2utf8(argv[2]);

	return (TCL_OK);
}

int
Renew(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result = "Usage: Renew clientid";
		return (TCL_ERROR);
	}

	opp->argop = OP_RENEW;

	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.oprenew.clientid =
	    (clientid4) strtoull(argv[1], NULL, 16);

	return (TCL_OK);
}

int
Restorefh(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();
	if (argc != 1) {
		interp->result = "Arguments ignored!\nUsage: Restorefh";
	}
	opp->argop = OP_RESTOREFH;

	return (TCL_OK);
}

int
Savefh(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();
	if (argc != 1) {
		interp->result = "Arguments ignored!\nUsage: Savefh";
	}
	opp->argop = OP_SAVEFH;

	return (TCL_OK);
}

int
Secinfo(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result = "Usage: Secinfo name";
		return (TCL_ERROR);
	}

	opp->argop = OP_SECINFO;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.opsecinfo.name = *str2utf8(argv[1]);

	return (TCL_OK);
}

int
Setattr(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	bitmap4 bm;
	attrlist4 av;
	stateid4 stateid;
	char lv2[2048];

	nfs_argop4 *opp = new_argop();

	if (argc != 3) {
		interp->result =
		    "Usage: Setattr stateid{seqid other}"
		    " { {name val} {name val} ... }";
		return (TCL_ERROR);
	}
	opp->argop = OP_SETATTR;

	substitution(interp, argv[1]);
	argv[1] = interp->result;
	if (str2stateid(interp, argv[1], &stateid) != TCL_OK) {
		interp->result = "Setattr: str2stateid() error";
		return (TCL_ERROR);
	}
	opp->nfs_argop4_u.opsetattr.stateid = stateid;

	substitution(interp, argv[2]);
	strcpy(lv2, interp->result);
	if ((attr_encode(interp, lv2, &bm, &av)) != TCL_OK)
		return (TCL_ERROR);
	opp->nfs_argop4_u.opsetattr.obj_attributes.attrmask = bm;
	opp->nfs_argop4_u.opsetattr.obj_attributes.attr_vals = av;

	return (TCL_OK);
}

int
Setclientid(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	char lv2[1024];
	nfs_argop4 *opp = new_argop();

	if (argc != 4) {
		interp->result =
		    "Usage: Setclientid verifier id {cb_prog netid addr} \n\
\t(The callback is not yet implemented; its values are set to NULL.)";
		return (TCL_ERROR);
	}

	opp->argop = OP_SETCLIENTID;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	(void) memcpy(opp->nfs_argop4_u.opsetclientid.client.verifier,
	    hex2bin(argv[1], sizeof (verifier4)), sizeof (verifier4));

	substitution(interp, argv[2]);
	strcpy(lv2, interp->result);
	opp->nfs_argop4_u.opsetclientid.client.id.id_val = lv2;
	opp->nfs_argop4_u.opsetclientid.client.id.id_len = strlen(lv2);

	/*
	 * XXX The callback program has not yet been implemented;
	 * thus it uses NULL for these temporary.
	 */
	opp->nfs_argop4_u.opsetclientid.callback.cb_program = 0;
	opp->nfs_argop4_u.opsetclientid.callback.cb_location.r_netid = NULL;
	opp->nfs_argop4_u.opsetclientid.callback.cb_location.r_addr = NULL;


	/*
	 * XXX callback_ident is not yet implemented, nor it is the interface
	 * to get its value from the user. Use 0 as a temporal value.
	 * This is to avoid modifying all occurrences of setclientid in
	 * testcases while callback is not implemented.
	 */
	opp->nfs_argop4_u.opsetclientid.callback_ident = 0;

	return (TCL_OK);
}

int
Setclientid_confirm(ClientData clientData, Tcl_Interp *interp,
    int argc, char *argv[])
{
	nfs_argop4 *opp = new_argop();

	if (argc != 3) {
		interp->result =
		    "Usage: Setclientid_confirm clientid verifier";
		return (TCL_ERROR);
	}

	opp->argop = OP_SETCLIENTID_CONFIRM;
	substitution(interp, argv[1]);
	argv[1] = interp->result;
	opp->nfs_argop4_u.opsetclientid_confirm.clientid =
	    (clientid4) strtoull(argv[1], NULL, 16);
	substitution(interp, argv[2]);
	argv[2] = interp->result;
	(void) memcpy(
	    opp->nfs_argop4_u.opsetclientid_confirm.setclientid_confirm,
	    hex2bin(argv[2], sizeof (verifier4)), sizeof (verifier4));

	return (TCL_OK);
}

int
Verify(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	bitmap4 bm;
	attrlist4 av;
	char lv1[2048];

	nfs_argop4 *opp = new_argop();

	if (argc != 2) {
		interp->result =
		    "Usage: Verify { {name val} {name val} ... }";
		return (TCL_ERROR);
	}

	opp->argop = OP_VERIFY;

	substitution(interp, argv[1]);
	strcpy(lv1, interp->result);
	if ((attr_encode(interp, lv1, &bm, &av)) != TCL_OK)
		return (TCL_ERROR);

	opp->nfs_argop4_u.opverify.obj_attributes.attrmask = bm;
	opp->nfs_argop4_u.opverify.obj_attributes.attr_vals = av;

	return (TCL_OK);
}

int
Write(ClientData clientData, Tcl_Interp *interp, int argc, char *argv[])
{
	stateid4 stateid;
	offset4 offset;
	stable_how4 stable;
	char *data;
	int datalen;
	char *dp;
	char sh, dt, buf[1024];

	nfs_argop4 *opp = new_argop();

	if (argc != 6) {
		interp->result = "Usage: Write stateid{seqid other} "
		    "offset how-u|d|f datatype-a|h {data}";
		return (TCL_ERROR);
	}

	opp->argop = OP_WRITE;

	substitution(interp, argv[1]);
	argv[1] = interp->result;
	if (str2stateid(interp, argv[1], &stateid) != TCL_OK) {
		interp->result = "Write: str2stateid() error";
		return (TCL_ERROR);
	}
	opp->nfs_argop4_u.opwrite.stateid = stateid;

	substitution(interp, argv[2]);
	argv[2] = interp->result;
	opp->nfs_argop4_u.opwrite.offset =
	    (offset4) strtoull(argv[2], (char **)NULL, 10);

	substitution(interp, argv[3]);
	argv[3] = interp->result;
	sh = *argv[3];
	switch (sh) {
	case 'u':	stable = UNSTABLE4; break;
	case 'd':	stable = (uint32_t)DATA_SYNC4; break;
	case 'f':	stable = (uint32_t)FILE_SYNC4; break;
	default:
		sprintf(buf, "Unknown stable_how (%s);\n", argv[3]);
		strcat(buf, "use u-UNSTABLE, d-DATA_SYNC, f-FILE_SYNC");
		interp->result = buf;
		return (TCL_ERROR);
	}
	opp->nfs_argop4_u.opwrite.stable = stable;

	substitution(interp, argv[4]);
	argv[4] = interp->result;
	dt = *argv[4];

	/* save the data from interp->result to avoid being overwritten */
	substitution(interp, argv[5]);
	argv[5] = interp->result;
	datalen = strlen(argv[5]);
	data = malloc(datalen);
	if (data == NULL) {
		interp->result = "Write: malloc() error";
		return (TCL_ERROR);
	}
	(void) memcpy(data, argv[5], datalen);
	switch (dt) {
	case 'a':
		opp->nfs_argop4_u.opwrite.data.data_val = data;
		opp->nfs_argop4_u.opwrite.data.data_len = datalen;
		break;
	case 'h':	/* XXX user entered HEX data, utf8string? */
		datalen = strlen(data) / 2;
		dp = malloc(datalen);
		if (dp == NULL) {
			interp->result = "malloc failure in Write";
			return (TCL_ERROR);
		}
		(void) memcpy(dp, hex2bin(data, (unsigned)datalen), datalen);
		opp->nfs_argop4_u.opwrite.data.data_val = dp;
		opp->nfs_argop4_u.opwrite.data.data_len = datalen;
	default:
		sprintf(buf, "Unknown data-type(%s);\n", argv[4]);
		strcat(buf, "use a-ASCII, h-HEX_DATA");
		interp->result = buf;
		return (TCL_ERROR);
	}

	return (TCL_OK);
}


/* ---------------------------------------- */
/* Operation result evaluation functions.   */
/* ---------------------------------------- */

/*
 * Now the functions to decode the result
 */

int
Access_res(Tcl_Interp *interp, Tcl_DString *strp, ACCESS4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Access");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		char buf[80];

		Tcl_DStringStartSublist(strp);

		sprintf(buf, "supported %s",
		    access2name(resp->ACCESS4res_u.resok4.supported));
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "access %s",
		    access2name(resp->ACCESS4res_u.resok4.access));
		Tcl_DStringAppendElement(strp, buf);

		Tcl_DStringEndSublist(strp);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Close_res(Tcl_Interp *interp, Tcl_DString *strp, CLOSE4res *resp)
{
	char buf[80];
	stateid4 stateid;

	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Close");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	stateid = resp->CLOSE4res_u.open_stateid;
	sprintf(buf, "%lu %s", stateid.seqid,
	    bin2hex(stateid.other, sizeof (stateid.other)));
	Tcl_DStringAppendElement(strp, buf);

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Commit_res(Tcl_Interp *interp, Tcl_DString *strp, COMMIT4res *resp)
{
	char buf[80];
	verifier4 verf;

	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Commit");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		(void) memcpy(verf, resp->COMMIT4res_u.resok4.writeverf,
		    sizeof (verf));
		sprintf(buf, "%s", bin2hex(verf, sizeof (verf)));
		Tcl_DStringAppendElement(strp, buf);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Create_res(Tcl_Interp *interp, Tcl_DString *strp, CREATE4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Create");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		char buf[80];
		change_info4 c;

		c = resp->CREATE4res_u.resok4.cinfo;
		Tcl_DStringStartSublist(strp);

		sprintf(buf, "atomic %s", c.atomic ? "true" : "false");
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "before %.8llx", c.before);
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "after %.8llx", c.after);
		Tcl_DStringAppendElement(strp, buf);

		Tcl_DStringStartSublist(strp);
		prn_attrname(strp, &resp->CREATE4res_u.resok4.attrset);
		Tcl_DStringEndSublist(strp);

		Tcl_DStringEndSublist(strp);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Delegpurge_res(Tcl_Interp *interp, Tcl_DString *strp, DELEGPURGE4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Delegpurge");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Delegreturn_res(Tcl_Interp *interp, Tcl_DString *strp, DELEGRETURN4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Delegreturn");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Getattr_res(Tcl_Interp *interp, Tcl_DString *strp, GETATTR4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Getattr");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		bitmap4 bm;
		attrlist4 attrvals;
		int err;

		bm = resp->GETATTR4res_u.resok4.obj_attributes.attrmask;
		attrvals = resp->GETATTR4res_u.resok4.obj_attributes.attr_vals;
		err = attr_decode(interp, strp, &bm, &attrvals);
		if (err != TCL_OK)
			return (TCL_ERROR);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Getfh_res(Tcl_Interp *interp, Tcl_DString *strp, GETFH4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Getfh");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		unsigned fh_len;
		char *fh_val;

		fh_len = resp->GETFH4res_u.resok4.object.nfs_fh4_len;
		fh_val = resp->GETFH4res_u.resok4.object.nfs_fh4_val;
		Tcl_DStringAppendElement(strp, bin2hex(fh_val, fh_len));
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Illegal_res(Tcl_Interp *interp, Tcl_DString *strp, ILLEGAL4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Illegal");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Link_res(Tcl_Interp *interp, Tcl_DString *strp, LINK4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Link");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		char buf[80];
		change_info4 c;

		c = resp->LINK4res_u.resok4.cinfo;
		Tcl_DStringStartSublist(strp);

		sprintf(buf, "atomic %s", c.atomic ? "true" : "false");
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "before %.8llx", c.before);
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "after %.8llx", c.after);
		Tcl_DStringAppendElement(strp, buf);

		Tcl_DStringEndSublist(strp);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Lock_res(Tcl_Interp *interp, Tcl_DString *strp, LOCK4res *resp)
{
	char buf[80];

	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Lock");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		stateid4 stateid;
		stateid = resp->LOCK4res_u.resok4.lock_stateid;
		sprintf(buf, "%lu %s", stateid.seqid,
		    bin2hex(stateid.other, sizeof (stateid.other)));
		Tcl_DStringAppendElement(strp, buf);
	} else {
		if (resp->status == NFS4ERR_DENIED) {
			lock_owner4 lowner;

			sprintf(buf, "%llu %llu %d",
			    resp->LOCK4res_u.denied.offset,
			    resp->LOCK4res_u.denied.length,
			    resp->LOCK4res_u.denied.locktype);
			Tcl_DStringAppendElement(strp, buf);
			lowner = resp->LOCK4res_u.denied.owner;
			sprintf(buf, "%llx ", lowner.clientid);
			if (lowner.owner.owner_val != NULL)
				strncat(buf, lowner.owner.owner_val,
				    lowner.owner.owner_len);
			Tcl_DStringAppendElement(strp, buf);
		}
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Lockt_res(Tcl_Interp *interp, Tcl_DString *strp, LOCKT4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Lockt");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4ERR_DENIED) {
		char buf[80];
		lock_owner4 lowner;

		sprintf(buf, "%llu %llu %d",
		    resp->LOCKT4res_u.denied.offset,
		    resp->LOCKT4res_u.denied.length,
		    resp->LOCKT4res_u.denied.locktype);
		Tcl_DStringAppendElement(strp, buf);
		lowner = resp->LOCKT4res_u.denied.owner;
		sprintf(buf, "%llx ", lowner.clientid);
		if (lowner.owner.owner_val != NULL)
			strncat(buf, lowner.owner.owner_val,
			    lowner.owner.owner_len);
		Tcl_DStringAppendElement(strp, buf);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Locku_res(Tcl_Interp *interp, Tcl_DString *strp, LOCKU4res *resp)
{
	char buf[80];
	stateid4 stateid;

	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Locku");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	stateid = resp->LOCKU4res_u.lock_stateid;
	sprintf(buf, "%lu %s", stateid.seqid,
	    bin2hex(stateid.other, sizeof (stateid.other)));
	Tcl_DStringAppendElement(strp, buf);

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Lookup_res(Tcl_Interp *interp, Tcl_DString *strp, LOOKUP4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Lookup");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Lookupp_res(Tcl_Interp *interp, Tcl_DString *strp, LOOKUPP4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Lookupp");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Nverify_res(Tcl_Interp *interp, Tcl_DString *strp, NVERIFY4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Nverify");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Open_res(Tcl_Interp *interp, Tcl_DString *strp, OPEN4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Open");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		char buf[80];
		change_info4 c;
		stateid4 stateid;

		/* Stateid for open */
		stateid = resp->OPEN4res_u.resok4.stateid;
		sprintf(buf, "%lu %s", stateid.seqid,
		    bin2hex(stateid.other, sizeof (stateid.other)));
		Tcl_DStringAppendElement(strp, buf);

		/* Directory Change Info */
		Tcl_DStringStartSublist(strp);
		c = resp->OPEN4res_u.resok4.cinfo;
		sprintf(buf, "atomic %s", c.atomic ? "true" : "false");
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "before %.8llx", c.before);
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "after %.8llx", c.after);
		Tcl_DStringAppendElement(strp, buf);
		Tcl_DStringEndSublist(strp);

		/* Result flags */
		sprintf(buf, "%u", resp->OPEN4res_u.resok4.rflags);
		Tcl_DStringAppendElement(strp, buf);

		/* Info of the attribute from Open */
		Tcl_DStringStartSublist(strp);
		prn_attrname(strp, &resp->OPEN4res_u.resok4.attrset);
		Tcl_DStringEndSublist(strp);

		/* Info on any open delegation */
		switch (resp->OPEN4res_u.resok4.delegation.delegation_type) {
		open_read_delegation4 dr;
		open_write_delegation4 dw;
		nfs_modified_limit4 *p;
		uint32_t s;
		uint32_t b;

		case OPEN_DELEGATE_NONE:
		Tcl_DStringAppendElement(strp, "NONE");
		break;

		case OPEN_DELEGATE_READ:
		Tcl_DStringStartSublist(strp);
		Tcl_DStringAppendElement(strp, "READ");
		dr = resp->OPEN4res_u.resok4.delegation.open_delegation4_u.read;
		sprintf(buf, "%lu %s", dr.stateid.seqid,
		    bin2hex(dr.stateid.other,
		    sizeof (dr.stateid.other)));
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "%s %s",
		    dr.recall ? "true" : "false",
		    prn_ace4(dr.permissions));
		Tcl_DStringAppendElement(strp, buf);
		Tcl_DStringEndSublist(strp);
		break;

		case OPEN_DELEGATE_WRITE:
		Tcl_DStringStartSublist(strp);
		Tcl_DStringAppendElement(strp, "WRITE");
		dw =
		    resp->OPEN4res_u.resok4.delegation.open_delegation4_u.write;
		sprintf(buf, "%lu %s", dw.stateid.seqid,
		    bin2hex(dw.stateid.other,
		    sizeof (dw.stateid.other)));
		Tcl_DStringAppendElement(strp, buf);

		switch (dw.space_limit.limitby) {
		case NFS_LIMIT_SIZE:
		s = dw.space_limit.nfs_space_limit4_u.filesize;
		sprintf(buf, "%s %s %llu %s",
		    dw.recall ? "true" : "false",
		    "SIZE", s, prn_ace4(dw.permissions));
		Tcl_DStringAppendElement(strp, buf);
		break;

		case NFS_LIMIT_BLOCKS:
		p = &(dw.space_limit.nfs_space_limit4_u.mod_blocks);
		s = p->num_blocks;
		b = p->bytes_per_block;
		sprintf(buf, "%s %s %lu %lu %s",
		    dw.recall ? "true" : "false",
		    "BLOCKS", s, b, prn_ace4(dw.permissions));
		Tcl_DStringAppendElement(strp, buf);
		break;

		default:
		break;
		}

		Tcl_DStringEndSublist(strp);
		break;

		default:
		break;
		}
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Openattr_res(Tcl_Interp *interp, Tcl_DString *strp, OPENATTR4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Openattr");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Open_confirm_res(Tcl_Interp *interp, Tcl_DString *strp, OPEN_CONFIRM4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Open_confirm");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		char buf[80];
		stateid4 stateid;

		stateid = resp->OPEN_CONFIRM4res_u.resok4.open_stateid;
		sprintf(buf, "%lu %s", stateid.seqid,
		    bin2hex(stateid.other, sizeof (stateid.other)));
		Tcl_DStringAppendElement(strp, buf);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Open_downgrade_res(Tcl_Interp *interp, Tcl_DString *strp,
    OPEN_DOWNGRADE4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Open_downgrade");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		char buf[80];
		stateid4 stateid;

		stateid = resp->OPEN_DOWNGRADE4res_u.resok4.open_stateid;
		sprintf(buf, "%lu %s", stateid.seqid,
		    bin2hex(stateid.other, sizeof (stateid.other)));
		Tcl_DStringAppendElement(strp, buf);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Putfh_res(Tcl_Interp *interp, Tcl_DString *strp, PUTFH4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Putfh");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Putpubfh_res(Tcl_Interp *interp, Tcl_DString *strp, PUTPUBFH4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Putpubfh");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Putrootfh_res(Tcl_Interp *interp, Tcl_DString *strp, PUTROOTFH4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Putrootfh");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Read_res(Tcl_Interp *interp, Tcl_DString *strp, READ4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Read");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		bool_t eof;
		uint_t len;
		char *val;
		char buf[80];

		eof = resp->READ4res_u.resok4.eof;
		len = resp->READ4res_u.resok4.data.data_len;
		val = resp->READ4res_u.resok4.data.data_val;

		Tcl_DStringStartSublist(strp);
		sprintf(buf, "eof %s", eof ? "true" : "false");
		Tcl_DStringAppendElement(strp, buf);

		sprintf(buf, "len %u", len);
		Tcl_DStringAppendElement(strp, buf);

		if (val != NULL) {
			char *np;
			np = malloc(len + 1);
			snprintf(np, (len + 1), "%s", val);
			Tcl_DStringAppendElement(strp, np);
			free(np);
		}
		Tcl_DStringEndSublist(strp);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Readdir_res(Tcl_Interp *interp, Tcl_DString *strp, READDIR4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Readdir");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		nfs_cookie4 cookie;
		verifier4 verf;
		bool_t eof;
		entry4 *d;
		bitmap4 bm;
		attrlist4 attrvals;

		/* The cookie verifier */
		(void) memcpy(verf, resp->READDIR4res_u.resok4.cookieverf,
		    sizeof (verf));
		Tcl_DStringAppendElement(strp,
		    bin2hex(verf, sizeof (verf)));

		/* The directory list */
		Tcl_DStringStartSublist(strp);
		eof = resp->READDIR4res_u.resok4.reply.eof;
		for (d = resp->READDIR4res_u.resok4.reply.entries;
		    d != NULL; d = d->nextentry) {
			char buf[64];

			Tcl_DStringStartSublist(strp);
			sprintf(buf, "%llu", d->cookie);
			Tcl_DStringAppendElement(strp, buf);
			Tcl_DStringAppendElement(strp, utf82str(d->name));

			bm = d->attrs.attrmask;
			attrvals = d->attrs.attr_vals;
			attr_decode(interp, strp, &bm, &attrvals);
			Tcl_DStringEndSublist(strp);
		}
		Tcl_DStringEndSublist(strp);
		Tcl_DStringAppendElement(strp, eof ? "true" : "false");
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Readlink_res(Tcl_Interp *interp, Tcl_DString *strp, READLINK4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Readlink");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		linktext4 l;
		char buf[256];

		l = resp->READLINK4res_u.resok4.link;
		snprintf(buf, l.utf8string_len + 1, "%s", l.utf8string_val);
		Tcl_DStringAppendElement(strp, buf);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Release_lockowner_res(Tcl_Interp *interp, Tcl_DString *strp,
	RELEASE_LOCKOWNER4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Release_lockowner");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Remove_res(Tcl_Interp *interp, Tcl_DString *strp, REMOVE4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Remove");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		change_info4 c;
		char buf[80];

		c = resp->REMOVE4res_u.resok4.cinfo;
		Tcl_DStringStartSublist(strp);

		sprintf(buf, "atomic %s", c.atomic ? "true" : "false");
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "before %.8llx", c.before);
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "after %.8llx", c.after);
		Tcl_DStringAppendElement(strp, buf);

		Tcl_DStringEndSublist(strp);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Rename_res(Tcl_Interp *interp, Tcl_DString *strp, RENAME4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Rename");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		change_info4 c;
		char buf[80];

		/* source cinfo */
		c = resp->RENAME4res_u.resok4.source_cinfo;
		Tcl_DStringStartSublist(strp);
		Tcl_DStringAppendElement(strp, "source");

		sprintf(buf, "atomic %s", c.atomic ? "true" : "false");
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "before %.8llx", c.before);
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "after %.8llx", c.after);
		Tcl_DStringAppendElement(strp, buf);

		Tcl_DStringEndSublist(strp);

		/* target cinfo */
		c = resp->RENAME4res_u.resok4.target_cinfo;
		Tcl_DStringStartSublist(strp);
		Tcl_DStringAppendElement(strp, "target");

		sprintf(buf, "atomic %s", c.atomic ? "true" : "false");
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "before %.8llx", c.before);
		Tcl_DStringAppendElement(strp, buf);
		sprintf(buf, "after %.8llx", c.after);
		Tcl_DStringAppendElement(strp, buf);

		Tcl_DStringEndSublist(strp);

	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Renew_res(Tcl_Interp *interp, Tcl_DString *strp, RENEW4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Renew");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Restorefh_res(Tcl_Interp *interp, Tcl_DString *strp, RESTOREFH4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Restorefh");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Savefh_res(Tcl_Interp *interp, Tcl_DString *strp, SAVEFH4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Savefh");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Secinfo_res(Tcl_Interp *interp, Tcl_DString *strp, SECINFO4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Secinfo");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		secinfo4 *sp;
		char buf[80];
		char buf2[10];
		int i;

		Tcl_DStringStartSublist(strp);
		for (i = 0;
		    i < resp->SECINFO4res_u.resok4.SECINFO4resok_len;
		    i++) {

			sp = &resp->SECINFO4res_u.resok4.SECINFO4resok_val[i];

			if (sp->flavor == AUTH_SYS) {
				sprintf(buf, "AUTH_SYS");
			} else if (sp->flavor == AUTH_NONE) {
				sprintf(buf, "AUTH_NONE");
			} else if (sp->flavor == AUTH_DH) {
				sprintf(buf, "AUTH_DH");
			} else if (sp->flavor == RPCSEC_GSS) {
				/*
				 * XXX used hardcoded mapping here:
				 *	For Solaris,
				 *	KRB5-OID=2A864886F712010202
				 *	(in HEX); * XXX Need HEX
				 *	values for LIBKEY & SPKM3 OID
				 *	mapping as well.
				 */
				char krboid[] = "2A864886F712010202";
				char lkeyoid[] = "1.3.6.1.5.5.9";
				char spkmoid[] = "1.3.6.1.5.5.1.3";
				char *oid;
				rpcsec_gss_info rinfo;

				sprintf(buf, "RPCSEC_GSS ");
				rinfo = sp->secinfo4_u.flavor_info;
				oid = bin2hex(rinfo.oid.sec_oid4_val,
				    rinfo.oid.sec_oid4_len);
				if ((strcmp(oid, krboid)) == 0) {
					strcat(buf, "KRB5");
				} else if ((strcmp(oid, lkeyoid)) == 0) {
					strcat(buf, "LIBKEY");
				} else if ((strcmp(oid, spkmoid)) == 0) {
					strcat(buf, "SPKM3");
				} else {
					strcat(buf, oid);
				}
				sprintf(buf2, " %u", rinfo.qop);
				strcat(buf, buf2);
				switch (rinfo.service) {
				case RPC_GSS_SVC_NONE:
					strcat(buf, " NONE");
					break;
				case RPC_GSS_SVC_INTEGRITY:
					strcat(buf, " INTEGRITY");
					break;
				case RPC_GSS_SVC_PRIVACY:
					strcat(buf, " PRIVACY");
					break;
				default:
					break;
				}
			} else {	/* unknown flavor, no mapping */
				sprintf(buf, "%u", sp->flavor);
			}
			Tcl_DStringAppendElement(strp, buf);
		}
		Tcl_DStringEndSublist(strp);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Setattr_res(Tcl_Interp *interp, Tcl_DString *strp, SETATTR4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Setattr");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	Tcl_DStringStartSublist(strp);
	prn_attrname(strp, &resp->attrsset);
	Tcl_DStringEndSublist(strp);

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Setclientid_res(Tcl_Interp *interp, Tcl_DString *strp, SETCLIENTID4res *resp)
{
	verifier4 verf;
	char buf[80];

	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Setclientid");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		/* the setclientid verifier */
		(void) memcpy(verf,
		    resp->SETCLIENTID4res_u.resok4.setclientid_confirm,
		    sizeof (verf));
		sprintf(buf, "%llx %s",
		    resp->SETCLIENTID4res_u.resok4.clientid,
		    bin2hex(verf, sizeof (verf)));
	} else if (resp->status == NFS4ERR_CLID_INUSE) {
		sprintf(buf, "%s %s",
		    resp->SETCLIENTID4res_u.client_using.r_netid,
		    resp->SETCLIENTID4res_u.client_using.r_addr);
	}
	Tcl_DStringAppendElement(strp, buf);
	Tcl_DStringEndSublist(strp);

	return (TCL_OK);
}

int
Setclientid_confirm_res(Tcl_Interp *interp, Tcl_DString *strp,
    SETCLIENTID_CONFIRM4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Setclientid_confirm");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Verify_res(Tcl_Interp *interp, Tcl_DString *strp, VERIFY4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Verify");
	Tcl_DStringAppendElement(strp, errstr(resp->status));
	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

int
Write_res(Tcl_Interp *interp, Tcl_DString *strp, WRITE4res *resp)
{
	Tcl_DStringStartSublist(strp);
	Tcl_DStringAppendElement(strp, "Write");
	Tcl_DStringAppendElement(strp, errstr(resp->status));

	if (resp->status == NFS4_OK) {
		verifier4 verf;
		char buf[81];

		/* the write count */
		sprintf(buf, "%u ", resp->WRITE4res_u.resok4.count);

		/* the stable_how */
		switch (resp->WRITE4res_u.resok4.committed) {
		case 0:
			strcat(buf, "UNSTABLE");
			break;
		case 1:
			strcat(buf, "DATA_SYNC");
			break;
		case 2:
			strcat(buf, "FILE_SYNC");
			break;
		default:
			strcat(buf, "UNKNOWN");
			break;
		}

		/* the write verifier */
		(void) memcpy(verf, resp->WRITE4res_u.resok4.writeverf,
		    sizeof (verf));
		strcat(buf, " ");
		strcat(buf, bin2hex(verf, sizeof (verf)));
		Tcl_DStringAppendElement(strp, buf);
	}

	Tcl_DStringEndSublist(strp);
	return (TCL_OK);
}

/*
 * Called to handle a compound result
 */
int
compound_result(Tcl_Interp *interp, COMPOUND4res *resp)
{
	int ops_complete;
	nfs_resop4 *resop;
	Tcl_DString str;
	int i;
	int err = TCL_OK;

	Tcl_SetVar(interp, "status", errstr(resp->status), 0);

	if (resp->tag.utf8string_val == NULL)
		Tcl_SetVar(interp, "tag", "", 0);
	else {
		Tcl_SetVar(interp, "tag", utf82str(resp->tag), 0);
	}

	ops_complete = resp->resarray.resarray_len;
	Tcl_SetVar(interp, "opcount", itoa(ops_complete), 0);

	Tcl_DStringInit(&str);

	for (i = 0; i < ops_complete; i++) {
		resop = &resp->resarray.resarray_val[i];
		switch (resop->resop) {
		case OP_ACCESS:
			err = Access_res(interp, &str,
			    &resop->nfs_resop4_u.opaccess);
			break;

		case OP_CLOSE:
			err = Close_res(interp, &str,
			    &resop->nfs_resop4_u.opclose);
			break;

		case OP_COMMIT:
			err = Commit_res(interp, &str,
			    &resop->nfs_resop4_u.opcommit);
			break;

		case OP_CREATE:
			err = Create_res(interp, &str,
			    &resop->nfs_resop4_u.opcreate);
			break;

		case OP_DELEGPURGE:
			err = Delegpurge_res(interp, &str,
			    &resop->nfs_resop4_u.opdelegpurge);
			break;

		case OP_DELEGRETURN:
			err = Delegreturn_res(interp, &str,
			    &resop->nfs_resop4_u.opdelegreturn);
			break;

		case OP_GETATTR:
			err = Getattr_res(interp, &str,
			    &resop->nfs_resop4_u.opgetattr);
			break;

		case OP_GETFH:
			err = Getfh_res(interp, &str,
			    &resop->nfs_resop4_u.opgetfh);
			break;

		case OP_ILLEGAL:
			err = Illegal_res(interp, &str,
			    &resop->nfs_resop4_u.opillegal);
			break;

		case OP_LINK:
			err = Link_res(interp, &str,
			    &resop->nfs_resop4_u.oplink);
			break;

		case OP_LOCK:
			err = Lock_res(interp, &str,
			    &resop->nfs_resop4_u.oplock);
			break;

		case OP_LOCKT:
			err = Lockt_res(interp, &str,
			    &resop->nfs_resop4_u.oplockt);
			break;

		case OP_LOCKU:
			err = Locku_res(interp, &str,
			    &resop->nfs_resop4_u.oplocku);
			break;

		case OP_LOOKUP:
			err = Lookup_res(interp, &str,
			    &resop->nfs_resop4_u.oplookup);
			break;

		case OP_LOOKUPP:
			err = Lookupp_res(interp, &str,
			    &resop->nfs_resop4_u.oplookupp);
			break;

		case OP_NVERIFY:
			err = Nverify_res(interp, &str,
			    &resop->nfs_resop4_u.opnverify);
			break;

		case OP_OPEN:
			err = Open_res(interp, &str,
			    &resop->nfs_resop4_u.opopen);
			break;

		case OP_OPENATTR:
			err = Openattr_res(interp, &str,
			    &resop->nfs_resop4_u.opopenattr);
			break;

		case OP_OPEN_CONFIRM:
			err = Open_confirm_res(interp, &str,
			    &resop->nfs_resop4_u.opopen_confirm);
			break;

		case OP_OPEN_DOWNGRADE:
			err = Open_downgrade_res(interp, &str,
			    &resop->nfs_resop4_u.opopen_downgrade);
			break;

		case OP_PUTFH:
			err = Putfh_res(interp, &str,
			    &resop->nfs_resop4_u.opputfh);
			break;

		case OP_PUTPUBFH:
			err = Putpubfh_res(interp, &str,
			    &resop->nfs_resop4_u.opputpubfh);
			break;

		case OP_PUTROOTFH:
			err = Putrootfh_res(interp, &str,
			    &resop->nfs_resop4_u.opputrootfh);
			break;

		case OP_READ:
			err = Read_res(interp, &str,
			    &resop->nfs_resop4_u.opread);
			break;

		case OP_READDIR:
			err = Readdir_res(interp, &str,
			    &resop->nfs_resop4_u.opreaddir);
			break;

		case OP_READLINK:
			err = Readlink_res(interp, &str,
			    &resop->nfs_resop4_u.opreadlink);
			break;

		case OP_RELEASE_LOCKOWNER:
			err = Release_lockowner_res(interp, &str,
			    &resop->nfs_resop4_u.oprelease_lockowner);
			break;

		case OP_REMOVE:
			err = Remove_res(interp, &str,
			    &resop->nfs_resop4_u.opremove);
			break;

		case OP_RENAME:
			err = Rename_res(interp, &str,
			    &resop->nfs_resop4_u.oprename);
			break;

		case OP_RENEW:
			err = Renew_res(interp, &str,
			    &resop->nfs_resop4_u.oprenew);
			break;

		case OP_RESTOREFH:
			err = Restorefh_res(interp, &str,
			    &resop->nfs_resop4_u.oprestorefh);
			break;

		case OP_SAVEFH:
			err = Savefh_res(interp, &str,
			    &resop->nfs_resop4_u.opsavefh);
			break;

		case OP_SECINFO:
			err = Secinfo_res(interp, &str,
			    &resop->nfs_resop4_u.opsecinfo);
			break;

		case OP_SETATTR:
			err = Setattr_res(interp, &str,
			    &resop->nfs_resop4_u.opsetattr);
			break;

		case OP_SETCLIENTID:
			err = Setclientid_res(interp, &str,
			    &resop->nfs_resop4_u.opsetclientid);
			break;

		case OP_SETCLIENTID_CONFIRM:
			err = Setclientid_confirm_res(interp, &str,
			    &resop->nfs_resop4_u.opsetclientid_confirm);
			break;

		case OP_VERIFY:
			err = Verify_res(interp, &str,
			    &resop->nfs_resop4_u.opverify);
			break;

		case OP_WRITE:
			err = Write_res(interp, &str,
			    &resop->nfs_resop4_u.opwrite);
			break;

		default:
			(void) sprintf(interp->result,
			    "Unknown op in result: %d",
			    resop->resop);
			err = TCL_ERROR;
			break;
		}

		if (err != TCL_OK) {
			Tcl_DStringFree(&str);
			return (err);
		}
	}

	Tcl_DStringResult(interp, &str);

	return (TCL_OK);
}

void
op_createcom(Tcl_Interp *interp)
{
	int i;

	for (i = 0; nfs_op[i].name != NULL; i++) {
		Tcl_CreateCommand(interp,
		    nfs_op[i].name, nfs_op[i].func,
		    (ClientData)		NULL,
		    (Tcl_CmdDeleteProc *)	NULL);
	}
}

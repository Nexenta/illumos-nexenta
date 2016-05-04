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

/*
 * Given the "claim" argument of:
 * {claim_type {filename|delegate_type|{delegate_stateid filename}}
 * fill in the open_claim4 structure.
 * Return TCL_ERROR on failure.
 */

int
set_openclaim(Tcl_Interp *interp, char *cargl, open_claim4 *cl)
{
	int lc;
	char **lv;
	char buf[80];
	char lv1[1024], lv2[1024];
	int otype;
	stateid4 stateid;

	/* First split the "cargl" to get the correct argument */
	if (Tcl_SplitList(interp, cargl, &lc,
	    (CONST84 char ***)&lv) != TCL_OK) {
		sprintf(buf, "set_openclaim error, can't split {%s}", cargl);
		interp->result = buf;
		return (TCL_ERROR);
	}
	if (lc < 2) {
		sprintf(buf,
		    "set_openclaim error, {%s} needs at least 2 fields",
		    cargl);
		interp->result = buf;
		if (lv)
			free((char *)lv);
		return (TCL_ERROR);
	}

	/* Get the opentype, set different argument value base on it */
	substitution(interp, lv[0]);
	otype = (int)atoi(interp->result);

	substitution(interp, lv[1]);
	strcpy(lv1, interp->result);
	substitution(interp, lv[2]);
	strcpy(lv2, interp->result);

	switch (otype) {
	case 0:		/* CLAIM_NULL */
		if (lc != 2) {
			interp->result =
			    "set_openclaim of CLAIM_NULL, need (0 filename)";
			if (lv)
				free((char *)lv);
			return (TCL_ERROR);
		}
		cl->claim = CLAIM_NULL;
		cl->open_claim4_u.file = *str2utf8(lv1);
		break;
	case 1:		/* CLAIM_PREVIOUS */
		if (lc != 2) {
			interp->result =
			    "set_openclaim of CLAIM_PREVIOUS,"
			    " need (delegate_type)";
			if (lv)
				free((char *)lv);
			return (TCL_ERROR);
		}
		cl->claim = CLAIM_PREVIOUS;
		cl->open_claim4_u.delegate_type = (uint32_t)atoi(lv1);
		break;
	case 2:		/* CLAIM_DELEGATE_CUR */
		if (lc != 3) {
			interp->result =
			    "set_openclaim of CLAIM_DELEGATE_CUR,"
			    " need (filename delegate_stateid)";
			if (lv)
				free((char *)lv);
			return (TCL_ERROR);
		}
		cl->claim = CLAIM_DELEGATE_CUR;
		cl->open_claim4_u.delegate_cur_info.file = *str2utf8(lv1);
		if (str2stateid(interp, lv2, &stateid) != TCL_OK) {
			interp->result = "set_openclaim: str2stateid() error";
			return (TCL_ERROR);
		}
		cl->open_claim4_u.delegate_cur_info.delegate_stateid = stateid;
		break;
	case 3:		/* CLAIM_DELEGATE_PREV */
		if (lc != 2) {
			interp->result =
			    "set_openclaim of CLAIM_DELEGATE_PREV,"
			    " need (3 filename)";
			if (lv)
				free((char *)lv);
			return (TCL_ERROR);
		}
		cl->claim = CLAIM_DELEGATE_PREV;
		cl->open_claim4_u.file_delegate_prev = *str2utf8(lv1);
		break;
	default:
		interp->result = "set_openclaim error, Unknown type";
		if (lv)
			free((char *)lv);
		return (TCL_ERROR);
	}

	free((char *)lv);
	return (TCL_OK);
}

/*
 * Given the "opentype" argument ({type {mode attr} {mode verf}},
 * fill in the opentype4 structure.  Return TCL_ERROR on failure.
 */

int
set_opentype(Tcl_Interp *interp, char *targl, openflag4 *of)
{
	int lc;
	char **lv;
	char buf[80];
	char lv1[1024], lv2[1024];
	int otype;
	int cmode;

	/* First split the "targl" to get the correct argument */
	if (Tcl_SplitList(interp, targl, &lc,
	    (CONST84 char ***)&lv) != TCL_OK) {
		sprintf(buf, "set_opentype error, can't split {%s}", targl);
		interp->result = buf;
		return (TCL_ERROR);
	}
	if (lc < 3) {
		sprintf(buf,
		    "set_opentype error, {%s} needs at least 3 fields", targl);
		interp->result = buf;
		if (lv)
			free((char *)lv);
		return (TCL_ERROR);
	}

	/* Get the type, set different argument value base on it */
	substitution(interp, lv[0]);
	otype = (int)atoi(interp->result);

	substitution(interp, lv[1]);
	strcpy(lv1, interp->result);
	substitution(interp, lv[2]);
	strcpy(lv2, interp->result);

	switch (otype) {
	case 0:		/* OPEN4_NOCREATE */
		of->opentype = OPEN4_NOCREATE;
		break;
	case 1:		/* OPEN4_CREATE */
		of->opentype = OPEN4_CREATE;
		cmode = (int)atoi(lv1);

		switch (cmode) {
			bitmap4 bm;
			attrlist4 av;
			verifier4 verf;

		case 0:		/* UNCHECKED */
			if (lc < 3) {
				interp->result =
				    "set_opentype: OPEN4_CREATE/UNCHECKED,"
				    " need ({name val} ... createattrs)";
				if (lv)
					free((char *)lv);
				return (TCL_ERROR);
			}
			of->openflag4_u.how.mode = UNCHECKED4;
			if ((attr_encode(interp, lv2, &bm, &av)) != TCL_OK)
				return (TCL_ERROR);
			of->openflag4_u.how.createhow4_u.createattrs.attrmask
			    = bm;
			of->openflag4_u.how.createhow4_u.createattrs.attr_vals
			    = av;
			break;
		case 1:		/* GUARDED */
			if (lc < 3) {
				interp->result =
				    "set_opentype: OPEN4_CREATE/GUARDED,"
				    " need ({name val} ... createattrs)";
				if (lv)
					free((char *)lv);
				return (TCL_ERROR);
			}
			of->openflag4_u.how.mode = GUARDED4;
			if ((attr_encode(interp, lv2, &bm, &av)) != TCL_OK) {
				if (lv)
					free((char *)lv);
				return (TCL_ERROR);
			}
			of->openflag4_u.how.createhow4_u.createattrs.attrmask
			    = bm;
			of->openflag4_u.how.createhow4_u.createattrs.attr_vals
			    = av;
			break;
		case 2:		/* EXCLUSIVE */
			if (lc < 3) {
				interp->result =
				    "set_opentype: OPEN4_CREATE/EXCLUSIVE,"
				    " need (createverf)";
				if (lv)
					free((char *)lv);
				return (TCL_ERROR);
			}
			memcpy(&verf, hex2bin(lv2, sizeof (verf)),
			    sizeof (verf));
			of->openflag4_u.how.mode = EXCLUSIVE4;
			memcpy(of->openflag4_u.how.createhow4_u.createverf,
			    &verf, NFS4_VERIFIER_SIZE);
			break;
		default:
			break;
		}
		break;
	default:
		break;
	}

	free((char *)lv);
	return (TCL_OK);
}

/*
 * Given the "openowner" argument (in form of {clientid owner})
 * fill in the open_owner4 structure.
 * Return TCL_ERROR on failure.
 */

int
set_owner(Tcl_Interp *interp, char *argl, open_owner4 *oo)
{
	int lc;
	char **lv;
	char buf[80];
	char lv0[1024] = "";
	static char lv1[1024];

	lv1[0] = 0;
	/* First split the "argl" to get the correct argument */
	if (Tcl_SplitList(interp, argl, &lc, (CONST84 char ***)&lv) != TCL_OK) {
		sprintf(buf, "set_owner error, can't split {%s}", argl);
		interp->result = buf;
		return (TCL_ERROR);
	}
	if (lc < 2) {
		sprintf(buf,
		    "set_owner error, {%s} needs at least 2 fields", argl);
		interp->result = buf;
		if (lv)
			free((char *)lv);
		return (TCL_ERROR);
	}
	substitution(interp, lv[0]);
	strcpy(lv0, interp->result);
	oo->clientid = (clientid4) strtoull(lv0, NULL, 16);
	substitution(interp, lv[1]);
	strcpy(lv1, interp->result);
	oo->owner.owner_len = strlen(lv1);
	oo->owner.owner_val = lv1;

	free((char *)lv);
	return (TCL_OK);
}

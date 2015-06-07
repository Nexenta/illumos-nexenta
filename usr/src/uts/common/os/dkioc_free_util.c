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
 * Copyright 2015 Nexenta Inc.  All rights reserved.
 */

#include <sys/sunddi.h>
#include <sys/dkio.h>
#include <sys/dkioc_free_util.h>

#ifdef	_KERNEL

#include <sys/sysmacros.h>
#include <sys/file.h>

#define	DFL_COPYIN_MAX_EXTS	(1024 * 1024)

/*
 * Copy-in convenience function for variable-length dkioc_free_list_t
 * structures. The pointer to copied from is in `arg' (may be a pointer
 * to userspace), `ddi_flags' indicate whether the pointer is from user-
 * or kernelspace (FKIOCTL) and `kmflags' are the flags passed to
 * kmem_zalloc when allocating the new structure.
 * Returns the copied structure on success and NULL on copy failure.
 */
dkioc_free_list_t *
dfl_copyin(void *arg, int ddi_flags, int kmflags)
{
	dkioc_free_list_t *dfl;

	if (ddi_flags & FKIOCTL) {
		dkioc_free_list_t *dfl_in = arg;
		dfl = kmem_zalloc(DFL_SZ(dfl_in->dfl_num_exts), kmflags);
		if (dfl == NULL)
			return (NULL);
		bcopy(dfl_in, dfl, DFL_SZ(dfl_in->dfl_num_exts));
	} else {
		uint64_t num_exts;

		if (ddi_copyin(((uint8_t *)arg) + offsetof(dkioc_free_list_t,
		    dfl_num_exts), &num_exts, sizeof (num_exts), ddi_flags) ||
		    num_exts > DFL_COPYIN_MAX_EXTS)
			return (NULL);

		dfl = kmem_zalloc(DFL_SZ(num_exts), kmflags);
		if (dfl == NULL)
			return (NULL);
		if (ddi_copyin(arg, dfl, DFL_SZ(num_exts), ddi_flags)) {
			dfl_free(dfl);
			return (NULL);
		}

		/* not valid from userspace */
		dfl->dfl_ck_func = NULL;
		dfl->dfl_ck_arg = NULL;
	}

	return (dfl);
}

/* Frees a variable-length dkioc_free_list_t structure. */
void
dfl_free(dkioc_free_list_t *dfl)
{
	kmem_free(dfl, DFL_SZ(dfl->dfl_num_exts));
}

#else	/* !KERNEL */

#include <stdlib.h>
#include <strings.h>

dkioc_free_list_t *
dfl_copyin(void *arg, int ddi_flags, int kmflags)
/*ARGSUSED*/
{
	dkioc_free_list_t *dfl, *dfl_in = arg;
	dfl = malloc(DFL_SZ(dfl_in->dfl_num_exts));
	if (dfl == NULL)
		return (NULL);
	bcopy(dfl_in, dfl, DFL_SZ(dfl_in->dfl_num_exts));
	return (dfl);
}

void
dfl_free(dkioc_free_list_t *dfl)
{
	free(dfl);
}

#endif	/* !KERNEL */

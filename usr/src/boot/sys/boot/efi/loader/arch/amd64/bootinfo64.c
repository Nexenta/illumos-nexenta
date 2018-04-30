/*-
 * Copyright (c) 1998 Michael Smith <msmith@freebsd.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/cdefs.h>
#include <stand.h>
#include <machine/cpufunc.h>
#include <machine/psl.h>
#include <machine/specialreg.h>

/*
 * Check to see if this CPU supports long mode.
 */
static int
bi_checkcpu(void)
{
    char *cpu_vendor;
    int vendor[3];
    u_long rflags;
    unsigned int regs[4];

    /* Check for presence of "cpuid". */
    rflags = read_rflags();
    write_rflags(rflags ^ PSL_ID);
    if (!((rflags ^ read_rflags()) & PSL_ID))
	return (0);

    /* Fetch the vendor string. */
    do_cpuid(0, regs);
    vendor[0] = regs[1];
    vendor[1] = regs[3];
    vendor[2] = regs[2];
    cpu_vendor = (char *)vendor;

    /* Check for vendors that support AMD features. */
    if (strncmp(cpu_vendor, INTEL_VENDOR_ID, 12) != 0 &&
	strncmp(cpu_vendor, AMD_VENDOR_ID, 12) != 0 &&
	strncmp(cpu_vendor, CENTAUR_VENDOR_ID, 12) != 0)
	return (0);

    /* Has to support AMD features. */
    do_cpuid(0x80000000, regs);
    if (!(regs[0] >= 0x80000001))
	return (0);

    /* Check for long mode. */
    do_cpuid(0x80000001, regs);
    return (regs[3] & AMDID_LM);
}

void
bi_isadir(void)
{
	if (bi_checkcpu())
		setenv("ISADIR", "amd64", 1);
	else
		setenv("ISADIR", "", 1);
}

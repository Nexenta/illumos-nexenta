/*
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * BSD 3 Clause License
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *      - Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *      - Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *      - Neither the name of Sun Microsystems, Inc. nor the
 *      names of its contributors may be used to endorse or promote products
 *      derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY SUN MICROSYSTEMS, INC. ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL SUN MICROSYSTEMS, INC. BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#include <stdio.h>
#include <stdarg.h>

#include <log.h>

/*
 * ndmp_fprintf() :
 * Prints if the Log level is 0
 *
 * Arguments :
 * 	FILE * - Ouput stream.
 * 	char * - Format string.
 */
void
ndmp_fprintf(FILE *stream, char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	(void) vfprintf(stream, fmt, ap);
	va_end(ap);
	fflush(stream);
}

/*
 * ndmp_lprintf() :
 * Prints if the Log level is 1
 */
void
ndmp_lprintf(FILE *stream, char *fmt, ...)
{
	int ndmp_debug = 0;
#ifdef DEBUG
	ndmp_debug = 1;
#endif
	va_list ap;
	if (ndmp_debug || (log_level > 0)) {
		va_start(ap, fmt);
		(void) vfprintf(stream, fmt, ap);
		va_end(ap);
		fflush(stream);
	}
}

/*
 * ndmp_dprintf() : The debug prints are done with this methods help.
 * The debug messages get printed only if DEBUG variable is set in
 * Makefile. The method signature is similar to fprintf().
 * The log level is 2.
 *
 * Arguments :
 * 	FILE * - Ouput stream.
 * 	char * - Format string.
 */
void
ndmp_dprintf(FILE *stream, char *fmt, ...)
{
	int ndmp_debug = 0;
#ifdef DEBUG
	ndmp_debug = 1;
#endif
	va_list ap;
	if (ndmp_debug || (log_level > 1)) {
		va_start(ap, fmt);
		(void) vfprintf(stream, fmt, ap);
		va_end(ap);
		fflush(stream);
	}
}

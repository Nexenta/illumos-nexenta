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
# Copyright 2017 Nexenta Systems, Inc.  All rights reserved.
#

# This is a "lint tail" that removes all the
# uninteresting lines from our lint output.
# Narrower impact than LINTCHECKFLAGS

# kernel vs user differences...
/: v?s?n?printf in .* .E_INCONS_VAL_TYPE_DECL2.$/	{ next; }
/: v?s?n?printf in .* .E_INCONS_VAL_TYPE_USED2.$/	{ next; }
/: netstack_.* in .* .E_INCONS_ARG_DECL2.$/		{ next; }
/: netstack_.* in .* .E_INCONS_VAL_TYPE_DECL2.$/	{ next; }
/: strsignal .* .E_FUNC_DECL_VAR_ARG2.$/		{ next; }
/: strsignal .* .E_INCONS_VAL_TYPE_DECL2.$/		{ next; }
/: strsignal\( .* .E_FUNC_DECL_VAR_ARG2.$/		{ next; }
/: strsignal\(.* .E_INCONS_ARG_DECL2.$/			{ next; }

# The mb_put/md_get functions are intentionally used both
# with and without return value checks.  Not a concern.
/: mb_init.* .E_FUNC_RET_[A-Z]*_IGNOR/			{ next; }
/: mb_put_.* .E_FUNC_RET_[A-Z]*_IGNOR/			{ next; }
/: md_get_.* .E_FUNC_RET_[A-Z]*_IGNOR/			{ next; }

# let's keep the stream.c derived code as it was, warts and all
/\/fake_stream\.c.* .E_SEC_SPRINTF_UNBOUNDED_COPY./	{ next; }
/\/fake_stream\.c.* .E_BAD_PTR_CAST_ALIGN./		{ next; }

{ print; }

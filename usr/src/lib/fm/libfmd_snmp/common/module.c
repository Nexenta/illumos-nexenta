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
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * Copyright 2018 Nexenta Systems, Inc.
 */

#include <fm/fmd_adm.h>
#include <fm/fmd_snmp.h>

#include <net-snmp/net-snmp-config.h>
#include <net-snmp/net-snmp-includes.h>
#include <net-snmp/agent/net-snmp-agent-includes.h>

#include <errno.h>
#include <libuutil.h>
#include <pthread.h>
#include <stddef.h>

#include "sunFM_impl.h"
#include "module.h"

static uu_avl_pool_t	*mod_name_avl_pool;
static uu_avl_pool_t	*mod_index_avl_pool;
static uu_avl_t		*mod_name_avl;
static uu_avl_t		*mod_index_avl;

#define	VALID_AVL_STATE	(mod_name_avl_pool != NULL &&		\
	mod_index_avl_pool != NULL && mod_name_avl != NULL &&	\
	mod_index_avl != NULL)

/*
 * Update types.  Single-index and all are mutually exclusive.
 */
#define	UCT_INDEX	0x1
#define	UCT_ALL		0x2
#define	UCT_FLAGS	0x3

#define	MODULE_DATA_VALID(d)	((d)->d_valid == valid_stamp)

static ulong_t		max_index;
static int		valid_stamp;
static pthread_mutex_t	update_lock;

static Netsnmp_Node_Handler	sunFmModuleTable_handler;

static sunFmModule_data_t *
key_build(const char *name, const ulong_t index)
{
	static sunFmModule_data_t	key;

	key.d_index = index;
	if (name)
		(void) strlcpy(key.d_ami_name, name, sizeof (key.d_ami_name));
	else
		key.d_ami_name[0] = '\0';

	return (&key);
}

/*
 * If name is the name of a module we have previously seen and indexed, return
 * data for it.  Otherwise, return NULL.  Note that the module may not be
 * valid; that is, it may have been removed from the fault manager since its
 * information was last updated.
 */
static sunFmModule_data_t *
module_lookup_name(const char *name)
{
	sunFmModule_data_t	*key;

	key = key_build(name, 0);
	return (uu_avl_find(mod_name_avl, key, NULL, NULL));
}

/*
 * If index corresponds to a module we have previously seen and indexed, return
 * data for it.  Otherwise, return NULL.  Note that the module may not be
 * valid; that is, it may have been removed from the fault manager since its
 * information was last updated.
 */
static sunFmModule_data_t *
module_lookup_index_exact(const ulong_t index)
{
	sunFmModule_data_t	*key;

	key = key_build(NULL, index);
	return (uu_avl_find(mod_index_avl, key, NULL, NULL));
}

/*
 * If index corresponds to a valid (that is, extant as of latest information
 * from the fault manager) fmd module, return the data for that module.
 * Otherwise, return the data for the valid module whose index is as close as
 * possible to index but not lower.  This preserves the lexicographical
 * ordering required for GETNEXT processing.
 */
static sunFmModule_data_t *
module_lookup_index_nextvalid(const ulong_t index)
{
	sunFmModule_data_t	*key, *data;
	uu_avl_index_t		idx;

	key = key_build(NULL, index);

	if ((data = uu_avl_find(mod_index_avl, key, NULL, &idx)) != NULL &&
	    MODULE_DATA_VALID(data))
		return (data);

	data = uu_avl_nearest_next(mod_index_avl, idx);

	while (data != NULL && !MODULE_DATA_VALID(data))
		data = uu_avl_next(mod_index_avl, data);

	return (data);
}

/*
 * Possible update the contents of a single module within the cache.  This
 * is our callback from fmd_module_iter.
 */
static int
modinfo_update_one(const fmd_adm_modinfo_t *modinfo, void *arg)
{
	const sunFmModule_update_ctx_t *update_ctx =
	    (sunFmModule_update_ctx_t *)arg;
	sunFmModule_data_t *data = module_lookup_name(modinfo->ami_name);

	/*
	 * An fmd module we haven't seen before.  We're obligated to index
	 * it and link it into our cache so that we can find it, but we're
	 * not obligated to fill it in completely unless we're doing a
	 * thorough update or this is the module we were asked for.  This
	 * avoids unnecessary iteration and memory manipulation for data
	 * we're not going to return for this request.
	 */
	if (data == NULL) {
		uu_avl_index_t idx;

		DEBUGMSGTL((MODNAME_STR, "found new fmd module %s\n",
		    modinfo->ami_name));
		if ((data = SNMP_MALLOC_TYPEDEF(sunFmModule_data_t)) == NULL) {
			(void) snmp_log(LOG_ERR, MODNAME_STR ": Out of memory "
			    "for new module data at %s:%d\n", __FILE__,
			    __LINE__);
			return (1);
		}
		/*
		 * We allocate indices sequentially and never reuse them.
		 * This ensures we can always return valid GETNEXT responses
		 * without having to reindex, and it provides the user a
		 * more consistent view of the fault manager.
		 */
		data->d_index = ++max_index;
		DEBUGMSGTL((MODNAME_STR, "index %lu is %s@%p\n", data->d_index,
		    modinfo->ami_name, data));

		(void) strlcpy(data->d_ami_name, modinfo->ami_name,
		    sizeof (data->d_ami_name));

		uu_avl_node_init(data, &data->d_name_avl, mod_name_avl_pool);
		(void) uu_avl_find(mod_name_avl, data, NULL, &idx);
		uu_avl_insert(mod_name_avl, data, idx);

		uu_avl_node_init(data, &data->d_index_avl, mod_index_avl_pool);
		(void) uu_avl_find(mod_index_avl, data, NULL, &idx);
		uu_avl_insert(mod_index_avl, data, idx);

		DEBUGMSGTL((MODNAME_STR, "completed new module %lu/%s@%p\n",
		    data->d_index, data->d_ami_name, data));
	}

	data->d_valid = valid_stamp;

	DEBUGMSGTL((MODNAME_STR, "timestamp updated for %lu/%s@%p: %d\n",
	    data->d_index, data->d_ami_name, data, data->d_valid));

	if ((update_ctx->uc_type & UCT_ALL) ||
	    update_ctx->uc_index == data->d_index) {
		(void) strlcpy(data->d_ami_vers, modinfo->ami_vers,
		    sizeof (data->d_ami_vers));
		(void) strlcpy(data->d_ami_desc, modinfo->ami_desc,
		    sizeof (data->d_ami_desc));
		data->d_ami_flags = modinfo->ami_flags;
	}

	return (!(update_ctx->uc_type & UCT_ALL) &&
	    update_ctx->uc_index == data->d_index);
}

/*
 * Update some or all module data from fmd.  If thorough is set, all modules
 * will be indexed and their data cached.  Otherwise, updates will stop once
 * the module matching index has been updated.
 *
 * Returns appropriate SNMP error codes.
 */
static int
modinfo_update(sunFmModule_update_ctx_t *update_ctx)
{
	fmd_adm_t *adm;

	ASSERT(update_ctx != NULL);
	ASSERT((update_ctx->uc_type & (UCT_INDEX|UCT_ALL)) !=
	    (UCT_INDEX|UCT_ALL));
	ASSERT((update_ctx->uc_type & ~UCT_FLAGS) == 0);
	ASSERT(VALID_AVL_STATE);

	if ((adm = fmd_adm_open(update_ctx->uc_host, update_ctx->uc_prog,
	    update_ctx->uc_version)) == NULL) {
		(void) snmp_log(LOG_ERR, MODNAME_STR ": Communication with fmd "
		    "failed: %s\n", strerror(errno));
		return (SNMP_ERR_RESOURCEUNAVAILABLE);
	}

	++valid_stamp;
	if (fmd_adm_module_iter(adm, modinfo_update_one, update_ctx) != 0) {
		(void) snmp_log(LOG_ERR, MODNAME_STR ": fmd module information "
		    "update failed: %s\n", fmd_adm_errmsg(adm));
		fmd_adm_close(adm);
		return (SNMP_ERR_RESOURCEUNAVAILABLE);
	}

	DEBUGMSGTL((MODNAME_STR, "module iteration completed\n"));

	fmd_adm_close(adm);
	return (SNMP_ERR_NOERROR);
}

static void
request_update(void)
{
	sunFmModule_update_ctx_t	uc;

	/*
	 * The current modinfo_update implementation offers minimal savings
	 * for the use of index-only updates; therefore we always do a full
	 * update.  If it becomes advantageous to limit updates to a single
	 * index, the contexts can be queued by the handler instead.
	 */
	uc.uc_host = NULL;
	uc.uc_prog = FMD_ADM_PROGRAM;
	uc.uc_version = FMD_ADM_VERSION;
	uc.uc_index = 0;
	uc.uc_type = UCT_ALL;

	(void) modinfo_update(&uc);
}

/*ARGSUSED*/
static int
module_compare_name(const void *l, const void *r, void *private)
{
	sunFmModule_data_t	*l_data = (sunFmModule_data_t *)l;
	sunFmModule_data_t	*r_data = (sunFmModule_data_t *)r;

	ASSERT(l_data != NULL && r_data != NULL);

	return (strcmp(l_data->d_ami_name, r_data->d_ami_name));
}

/*ARGSUSED*/
static int
module_compare_index(const void *l, const void *r, void *private)
{
	sunFmModule_data_t	*l_data = (sunFmModule_data_t *)l;
	sunFmModule_data_t	*r_data = (sunFmModule_data_t *)r;

	ASSERT(l_data != NULL && r_data != NULL);

	return (l_data->d_index < r_data->d_index ? -1 :
	    l_data->d_index > r_data->d_index ? 1 : 0);
}

int
sunFmModuleTable_init(void)
{
	static oid sunFmModuleTable_oid[] = { SUNFMMODULETABLE_OID };
	netsnmp_table_registration_info *table_info;
	netsnmp_handler_registration *handler;
	int err;

	if ((err = pthread_mutex_init(&update_lock, NULL)) != 0) {
		(void) snmp_log(LOG_ERR, MODNAME_STR ": mutex_init failure: "
		    "%s\n", strerror(err));
		return (MIB_REGISTRATION_FAILED);
	}

	if ((table_info =
	    SNMP_MALLOC_TYPEDEF(netsnmp_table_registration_info)) == NULL)
		return (MIB_REGISTRATION_FAILED);

	if ((handler = netsnmp_create_handler_registration("sunFmModuleTable",
	    sunFmModuleTable_handler, sunFmModuleTable_oid,
	    OID_LENGTH(sunFmModuleTable_oid), HANDLER_CAN_RONLY)) == NULL) {
		SNMP_FREE(table_info);
		return (MIB_REGISTRATION_FAILED);
	}

	/*
	 * The Net-SNMP template uses add_indexes here, but that
	 * function is unsafe because it does not check for failure.
	 */
	if (netsnmp_table_helper_add_index(table_info, ASN_UNSIGNED) == NULL) {
		SNMP_FREE(table_info);
		SNMP_FREE(handler);
		return (MIB_REGISTRATION_FAILED);
	}

	table_info->min_column = SUNFMMODULE_COLMIN;
	table_info->max_column = SUNFMMODULE_COLMAX;

	if ((mod_name_avl_pool = uu_avl_pool_create("mod_name",
	    sizeof (sunFmModule_data_t),
	    offsetof(sunFmModule_data_t, d_name_avl), module_compare_name,
	    UU_AVL_DEBUG)) == NULL) {
		snmp_free_varbind(table_info->indexes);
		SNMP_FREE(table_info);
		SNMP_FREE(handler);
	}

	if ((mod_name_avl = uu_avl_create(mod_name_avl_pool, NULL,
	    UU_AVL_DEBUG)) == NULL) {
		(void) snmp_log(LOG_ERR, MODNAME_STR ": mod_name_avl creation "
		    "failed: %s\n", uu_strerror(uu_error()));
		snmp_free_varbind(table_info->indexes);
		SNMP_FREE(table_info);
		SNMP_FREE(handler);
		uu_avl_pool_destroy(mod_name_avl_pool);
		return (MIB_REGISTRATION_FAILED);
	}

	if ((mod_index_avl_pool = uu_avl_pool_create("mod_index",
	    sizeof (sunFmModule_data_t),
	    offsetof(sunFmModule_data_t, d_index_avl),
	    module_compare_index, UU_AVL_DEBUG)) == NULL) {
		snmp_free_varbind(table_info->indexes);
		SNMP_FREE(table_info);
		SNMP_FREE(handler);
		uu_avl_destroy(mod_name_avl);
		uu_avl_pool_destroy(mod_name_avl_pool);
	}

	if ((mod_index_avl = uu_avl_create(mod_index_avl_pool, NULL,
	    UU_AVL_DEBUG)) == NULL) {
		(void) snmp_log(LOG_ERR, MODNAME_STR ": mod_index_avl creation "
		    "failed: %s\n", uu_strerror(uu_error()));
		snmp_free_varbind(table_info->indexes);
		SNMP_FREE(table_info);
		SNMP_FREE(handler);
		uu_avl_destroy(mod_name_avl);
		uu_avl_pool_destroy(mod_name_avl_pool);
		uu_avl_pool_destroy(mod_index_avl_pool);
		return (MIB_REGISTRATION_FAILED);
	}

	if ((err = netsnmp_register_table(handler, table_info)) !=
	    MIB_REGISTERED_OK) {
		snmp_free_varbind(table_info->indexes);
		SNMP_FREE(table_info);
		SNMP_FREE(handler);
		uu_avl_destroy(mod_name_avl);
		uu_avl_pool_destroy(mod_name_avl_pool);
		uu_avl_destroy(mod_index_avl);
		uu_avl_pool_destroy(mod_index_avl_pool);
		return (err);
	}

	return (MIB_REGISTERED_OK);
}

/*
 * These two functions form the core of GET/GETNEXT handling (the
 * only kind we do).  They perform two functions:
 *
 * - First, frob the request to set all the index variables to correspond
 *   to the value that's going to be returned.  For GET, this is a nop;
 *   for GETNEXT it always requires some work.
 * - Second, find and return the fmd module information corresponding to
 *   the (possibly updated) indices.
 *
 * These should be as fast as possible; they run in the agent thread.
 */
static sunFmModule_data_t *
sunFmModuleTable_nextmod(netsnmp_handler_registration *reginfo,
    netsnmp_table_request_info *table_info)
{
	sunFmModule_data_t	*data;
	netsnmp_variable_list	*var;
	ulong_t index;

	/*
	 * If we have no index, we must make one.
	 */
	if (table_info->number_indexes < 1) {
		oid tmpoid[MAX_OID_LEN];
		index = 1;

		DEBUGMSGTL((MODNAME_STR, "nextmod: no indexes given\n"));
		var = SNMP_MALLOC_TYPEDEF(netsnmp_variable_list);
		(void) snmp_set_var_typed_value(var, ASN_UNSIGNED,
		    (uchar_t *)&index, sizeof (index));
		(void) memcpy(tmpoid, reginfo->rootoid,
		    reginfo->rootoid_len * sizeof (oid));
		tmpoid[reginfo->rootoid_len] = 1;	/* Entry is .1 */
		tmpoid[reginfo->rootoid_len + 1] = table_info->colnum;
		if (build_oid(&var->name, &var->name_length, tmpoid,
		    reginfo->rootoid_len + 2, var) != SNMPERR_SUCCESS) {
			snmp_free_varbind(var);
			return (NULL);
		}
		DEBUGMSGTL((MODNAME_STR, "nextmod: built fake index: "));
		DEBUGMSGVAR((MODNAME_STR, var));
		DEBUGMSG((MODNAME_STR, "\n"));
	} else {
		var = snmp_clone_varbind(table_info->indexes);
		index = *var->val.integer;
		DEBUGMSGTL((MODNAME_STR, "nextmod: received index: "));
		DEBUGMSGVAR((MODNAME_STR, var));
		DEBUGMSG((MODNAME_STR, "\n"));
		index++;
	}

	snmp_free_varbind(table_info->indexes);
	table_info->indexes = NULL;
	table_info->number_indexes = 0;

	if ((data = module_lookup_index_nextvalid(index)) == NULL) {
		DEBUGMSGTL((MODNAME_STR, "nextmod: exact match not found for "
		    "index %lu; trying next column\n", index));
		if (table_info->colnum >=
		    netsnmp_find_table_registration_info(reginfo)->max_column) {
			snmp_free_varbind(var);
			DEBUGMSGTL((MODNAME_STR, "nextmod: out of columns\n"));
			return (NULL);
		}
		table_info->colnum++;
		index = 1;

		data = module_lookup_index_nextvalid(index);
	}

	if (data == NULL) {
		DEBUGMSGTL((MODNAME_STR, "nextmod: exact match not found for "
		    "index %lu; stopping\n", index));
		snmp_free_varbind(var);
		return (NULL);
	}

	*var->val.integer = data->d_index;
	table_info->indexes = var;
	table_info->number_indexes = 1;

	DEBUGMSGTL((MODNAME_STR, "matching data is %lu/%s@%p\n", data->d_index,
	    data->d_ami_name, data));

	return (data);
}

/*ARGSUSED*/
static sunFmModule_data_t *
sunFmModuleTable_mod(netsnmp_handler_registration *reginfo,
    netsnmp_table_request_info *table_info)
{
	ASSERT(table_info->number_indexes == 1);

	return (module_lookup_index_exact(table_info->index_oid[0]));
}

/*ARGSUSED*/
static int
sunFmModuleTable_handler(netsnmp_mib_handler *handler,
    netsnmp_handler_registration *reginfo, netsnmp_agent_request_info *reqinfo,
    netsnmp_request_info *request)
{
	netsnmp_table_request_info	*table_info;
	sunFmModule_data_t		*data;
	ulong_t				modstate;
	int				ret = SNMP_ERR_NOERROR;

	/*
	 * We don't support MODE_GETBULK directly, so all bulk requests should
	 * come through bulk_to_next helper.  Make sure it stays that way.
	 */
	ASSERT(reqinfo->mode == MODE_GET || reqinfo->mode == MODE_GETNEXT);

	(void) pthread_mutex_lock(&update_lock);
	request_update();

	for (; request != NULL; request = request->next) {
		table_info = netsnmp_extract_table_info(request);
		if (table_info == NULL)
			continue;

		ASSERT(table_info->colnum >= SUNFMMODULE_COLMIN);
		ASSERT(table_info->colnum <= SUNFMMODULE_COLMAX);

		/*
		 * table_info->colnum contains the column number requested.
		 * table_info->indexes contains a linked list of snmp variable
		 * bindings for the indexes of the table.  Values in the list
		 * have been set corresponding to the indexes of the
		 * request.  We have other guarantees as well:
		 *
		 * - The column number is always within range.
		 * - If we have no index data, table_info->index_oid_len is 0.
		 * - We will never receive requests outside our table nor
		 *   those with the first subid anything other than 1 (Entry)
		 *   nor those without a column number.  This is true even
		 *   for GETNEXT requests.
		 */
		switch (reqinfo->mode) {
		case MODE_GET:
			data = sunFmModuleTable_mod(reginfo, table_info);
			if (data == NULL)
				goto out;
			break;
		case MODE_GETNEXT:
			data = sunFmModuleTable_nextmod(reginfo, table_info);
			if (data == NULL)
				goto out;
			break;
		default:
			(void) snmp_log(LOG_ERR, MODNAME_STR
			    ": unsupported request mode: %d\n", reqinfo->mode);
			ret = SNMP_ERR_GENERR;
			goto out;
		}

		switch (table_info->colnum) {
		case SUNFMMODULE_COL_NAME:
			(void) netsnmp_table_build_result(reginfo, request,
			    table_info, ASN_OCTET_STR,
			    (uchar_t *)data->d_ami_name,
			    strlen(data->d_ami_name));
			break;
		case SUNFMMODULE_COL_VERSION:
			(void) netsnmp_table_build_result(reginfo, request,
			    table_info, ASN_OCTET_STR,
			    (uchar_t *)data->d_ami_vers,
			    strlen(data->d_ami_vers));
			break;
		case SUNFMMODULE_COL_STATUS:
			modstate = (data->d_ami_flags & FMD_ADM_MOD_FAILED) ?
			    SUNFMMODULE_STATE_FAILED : SUNFMMODULE_STATE_ACTIVE;
			(void) netsnmp_table_build_result(reginfo, request,
			    table_info, ASN_INTEGER, (uchar_t *)&modstate,
			    sizeof (modstate));
			break;
		case SUNFMMODULE_COL_DESCRIPTION:
			(void) netsnmp_table_build_result(reginfo, request,
			    table_info, ASN_OCTET_STR,
			    (uchar_t *)data->d_ami_desc,
			    strlen(data->d_ami_desc));
			break;
		default:
			break;
		}
	}

out:
	(void) pthread_mutex_unlock(&update_lock);
	return (ret);
}

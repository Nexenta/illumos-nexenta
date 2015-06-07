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
 * Copyright 2012 Nexenta Systems, Inc.  All rights reserved.
 */

#include <libaoe.h>
#include <dbus/dbus.h>

static const char *AOE_DEV_PATH = "/devices/aoe:admin";

#define	OPEN_AOE	0
#define	OPEN_EXCL_AOE	O_EXCL

static struct {
	int		errnum;
	const char	*errmsg;
} errtab[] = {
	{ AOE_STATUS_ERROR_ALREADY, 		"already exists" },
	{ AOE_STATUS_ERROR_BUSY,		"driver busy" },
	{ AOE_STATUS_ERROR_CREATE_MAC,		"cannot create link" },
	{ AOE_STATUS_ERROR_CREATE_PORT,		"general failure" },
	{ AOE_STATUS_ERROR_GET_LINKINFO,	"cannot get link information" },
	{ AOE_STATUS_ERROR_INVAL_ARG,		"invalid argument" },
	{ AOE_STATUS_ERROR_MAC_LEN,		"linkname too long" },
	{ AOE_STATUS_ERROR_MAC_NOT_FOUND,	"not found" },
	{ AOE_STATUS_ERROR_MORE_DATA,		"more data" },
	{ AOE_STATUS_ERROR_OFFLINE_DEV,		"port busy" },
	{ AOE_STATUS_ERROR_OPEN_DEV,		"cannot open aoe device" },
	{ AOE_STATUS_ERROR_OPEN_MAC,		"cannot open link" },
	{ AOE_STATUS_ERROR_PERM,		"permission denied" }
};

static int aoe_cfg_scf_init(scf_handle_t **, scf_service_t **, int);

static int
aoe_convert_error_code(aoeio_stat_t aoeio_status)
{
	int status;
	switch (aoeio_status) {
	case AOEIOE_INVAL_ARG:
		status = AOE_STATUS_ERROR_INVAL_ARG;
		break;
	case AOEIOE_BUSY:
		status = AOE_STATUS_ERROR_BUSY;
		break;
	case AOEIOE_ALREADY:
		status = AOE_STATUS_ERROR_ALREADY;
		break;
	case AOEIOE_CREATE_MAC:
		status = AOE_STATUS_ERROR_CREATE_MAC;
		break;
	case AOEIOE_OPEN_MAC:
		status = AOE_STATUS_ERROR_OPEN_MAC;
		break;
	case AOEIOE_CREATE_PORT:
		status = AOE_STATUS_ERROR_CREATE_PORT;
		break;
	case AOEIOE_MAC_NOT_FOUND:
		status = AOE_STATUS_ERROR_MAC_NOT_FOUND;
		break;
	case AOEIOE_OFFLINE_FAILURE:
		status = AOE_STATUS_ERROR_OFFLINE_DEV;
		break;
	case AOEIOE_MORE_DATA:
		status = AOE_STATUS_ERROR_MORE_DATA;
		break;
	default:
		status = AOE_STATUS_ERROR;
	}

	return (status);
}

/*
 * Open for aoe module
 *
 * flag - open flag (OPEN_AOE, OPEN_EXCL_AOE)
 * fd - pointer to integer. On success, contains the aoe file descriptor
 */
static AOE_STATUS
aoe_open(int flag, int *fd)
{
	int	ret;

	if ((*fd = open(AOE_DEV_PATH, O_NDELAY | O_RDONLY | flag)) != -1) {
		ret = AOE_STATUS_OK;
	} else {
		if (errno == EPERM || errno == EACCES)
			ret = AOE_STATUS_ERROR_PERM;
		else
			ret = AOE_STATUS_ERROR_OPEN_DEV;
	}

	return (ret);
}

/*
 * This routine is used to remove a single entry in the
 * SCF database for a given AoE port.
 * Input:
 *   portid          - The integer of the AoE port ID.
 *   linknames       - A comma-separated string of link interface names. e.g.
 *                     e1000g1,e1000g2,e1000g3
 *   module          - The optional module name string, or NULL.
 *   is_promisc      - (The value is 1 or 0) 1 if promiscuous mode is
 *                     to be set for the MAC interfaces. Otherwise, 0.
 *   is_target       - (The value is 1 or 0) 1 if the AoE port is to be
 *                     used as a target port. Otherwise, 0, that is, the
 *                     port is used as an initiator port.
 *   policy          - The port policy of sending packets:
 *                       0 - no policy.
 *                       1 - failover policy
 *                       2 - round robin policy
 *                       3 - weighted load balancing policy
 *                     as defined in aoe_cli_policy_t.
 *   add_remove_flag - AOE_SCF_ADD or AOE_SCF_REMOVE.
 */
static int
aoe_add_remove_scf_entry(uint32_t portid, char *linknames, char *module,
	int is_promisc, int is_target, aoe_cli_policy_t policy,
	int add_remove_flag)
{
	boolean_t	create_prop = B_FALSE;
	boolean_t	found = B_FALSE;
	char		buf[AOE_PORT_LIST_LEN] = {0};
	char		member_name[AOE_PORT_LIST_LEN] = {0};
	int		commit_ret;
	int		i = 0;
	int		last_alloc = 0;
	int		ret = AOE_STATUS_OK;
	int		value_array_size = 0;
	int 		port_list_alloc = 100;
	scf_handle_t	*handle = NULL;
	scf_iter_t	*value_iter = NULL;
	scf_property_t	*prop = NULL;
	scf_propertygroup_t *pg = NULL;
	scf_service_t	*svc = NULL;
	scf_transaction_entry_t *entry = NULL;
	scf_transaction_t *tran = NULL;
	scf_value_t	**value_set = NULL;
	scf_value_t	*value_lookup = NULL;

	/*
	 * Definition of the string 'member_name' used in this routine:
	 *
	 * The string member_name is a semi-colon (':') separated
	 * string of the parameters to describe an AoE port. The current
	 * format is a string for the snprintf routine : "%s:%s:%d:%d:%d:%d".
	 * The output lookes like
	 * <linknames>:<module>:<portid>:<is_promisc>:<is_target>:<policy>
	 * where the values of linknames, module, portid, is_promisc,
	 * is_target, and policy are defined above as the input parameters
	 * of this routine.
	 *
	 * The member_name is the string to be add or removed in the
	 * SCF database.
	 */
	(void) snprintf(member_name, AOE_PORT_LIST_LEN, "%s:%s:%d:%d:%d:%d",
	    linknames, module, portid, is_promisc, is_target, policy);

	ret = aoe_cfg_scf_init(&handle, &svc, is_target);
	if (ret != AOE_STATUS_OK)
		goto out;

	if (((pg = scf_pg_create(handle)) == NULL) ||
	    ((tran = scf_transaction_create(handle)) == NULL) ||
	    ((entry = scf_entry_create(handle)) == NULL) ||
	    ((prop = scf_property_create(handle)) == NULL) ||
	    ((value_iter = scf_iter_create(handle)) == NULL)) {
		ret = AOE_STATUS_ERROR;
		goto out;
	}

	/* Get property group or create it */
	if (scf_service_get_pg(svc, AOE_PG_NAME, pg) == -1) {
		if ((scf_error() == SCF_ERROR_NOT_FOUND)) {
			if (scf_service_add_pg(svc, AOE_PG_NAME,
			    SCF_GROUP_APPLICATION, 0, pg) == -1) {
				syslog(LOG_ERR, "add pg failed - %s",
				    scf_strerror(scf_error()));
				ret = AOE_STATUS_ERROR;
			} else {
				create_prop = B_TRUE;
			}
		} else {
			syslog(LOG_ERR, "get pg failed - %s",
			    scf_strerror(scf_error()));
			ret = AOE_STATUS_ERROR;
		}
		if (ret != AOE_STATUS_OK)
			goto out;
	}

	/* Make sure property exists */
	if (create_prop == B_FALSE) {
		if (scf_pg_get_property(pg, AOE_PORT_LIST_PROP, prop) == -1) {
			if ((scf_error() == SCF_ERROR_NOT_FOUND)) {
				create_prop = B_TRUE;
			} else {
				syslog(LOG_ERR, "get property failed - %s",
				    scf_strerror(scf_error()));
				ret = AOE_STATUS_ERROR;
				goto out;
			}
		}
	}

	/* Begin the transaction */
	if (scf_transaction_start(tran, pg) == -1) {
		syslog(LOG_ERR, "start transaction failed - %s",
		    scf_strerror(scf_error()));
		ret = AOE_STATUS_ERROR;
		goto out;
	}

	value_set = (scf_value_t **)calloc(1,
	    sizeof (*value_set) * (last_alloc = port_list_alloc));
	if (value_set == NULL) {
		ret = AOE_STATUS_ERROR_NOMEM;
		goto out;
	}

	if (create_prop) {
		if (scf_transaction_property_new(tran, entry,
		    AOE_PORT_LIST_PROP, SCF_TYPE_USTRING) == -1) {
			if (scf_error() == SCF_ERROR_EXISTS) {
				ret = AOE_STATUS_ERROR_EXISTS;
			} else {
				syslog(LOG_ERR,
				    "transaction property new failed - %s",
				    scf_strerror(scf_error()));
				ret = AOE_STATUS_ERROR;
			}
			goto out;
		}
	} else {
		if (scf_transaction_property_change(tran, entry,
		    AOE_PORT_LIST_PROP, SCF_TYPE_USTRING) == -1) {
			syslog(LOG_ERR,
			    "transaction property change failed - %s",
			    scf_strerror(scf_error()));
			ret = AOE_STATUS_ERROR;
			goto out;
		}

		if (scf_pg_get_property(pg, AOE_PORT_LIST_PROP, prop) == -1) {
			syslog(LOG_ERR, "get property failed - %s",
			    scf_strerror(scf_error()));
			ret = AOE_STATUS_ERROR;
			goto out;
		}

		value_lookup = scf_value_create(handle);
		if (value_lookup == NULL) {
			syslog(LOG_ERR, "scf value alloc failed - %s",
			    scf_strerror(scf_error()));
			ret = AOE_STATUS_ERROR;
			goto out;
		}

		if (scf_iter_property_values(value_iter, prop) == -1) {
			syslog(LOG_ERR, "iter value failed - %s",
			    scf_strerror(scf_error()));
			ret = AOE_STATUS_ERROR;
			goto out;
		}

		while (scf_iter_next_value(value_iter, value_lookup) == 1) {
			char *linknames_iter = NULL;
			char buftmp[AOE_PORT_LIST_LEN] = {0};

			bzero(buf, sizeof (buf));
			if (scf_value_get_ustring(value_lookup,
			    buf, MAXNAMELEN) == -1) {
				syslog(LOG_ERR, "iter value failed- %s",
				    scf_strerror(scf_error()));
				ret = AOE_STATUS_ERROR;
				break;
			}
			(void) strcpy(buftmp, buf);
			linknames_iter = strtok(buftmp, ":");
			if (strncmp(linknames_iter, linknames,
			    MAXLINKNAMELEN) == 0) {
				if (add_remove_flag == AOE_SCF_ADD) {
					ret = AOE_STATUS_ERROR_EXISTS;
					break;
				} else {
					found = B_TRUE;
					continue;
				}
			}

			value_set[i] = scf_value_create(handle);
			if (value_set[i] == NULL) {
				syslog(LOG_ERR, "scf value alloc failed - %s",
				    scf_strerror(scf_error()));
				ret = AOE_STATUS_ERROR;
				break;
			}

			if (scf_value_set_ustring(value_set[i], buf) == -1) {
				syslog(LOG_ERR, "set value failed 1- %s",
				    scf_strerror(scf_error()));
				ret = AOE_STATUS_ERROR;
				break;
			}

			if (scf_entry_add_value(entry, value_set[i]) == -1) {
				syslog(LOG_ERR, "add value failed - %s",
				    scf_strerror(scf_error()));
				ret = AOE_STATUS_ERROR;
				break;
			}

			i++;

			if (i >= last_alloc) {
				last_alloc += port_list_alloc;
				value_set = realloc(value_set,
				    sizeof (*value_set) * last_alloc);
				if (value_set == NULL) {
					ret = AOE_STATUS_ERROR;
					break;
				}
			}
		}
	}

	value_array_size = i;
	if (!found && (add_remove_flag == AOE_SCF_REMOVE))
		ret = AOE_STATUS_ERROR_MEMBER_NOT_FOUND;
	if (ret != AOE_STATUS_OK)
		goto out;

	if (add_remove_flag == AOE_SCF_ADD) {
		/* Create the new entry */
		value_set[i] = scf_value_create(handle);
		if (value_set[i] == NULL) {
			syslog(LOG_ERR, "scf value alloc failed - %s",
			    scf_strerror(scf_error()));
			ret = AOE_STATUS_ERROR;
			goto out;
		} else {
			value_array_size++;
		}

		/* Set the new member name */
		if (scf_value_set_ustring(value_set[i], member_name) == -1) {
			syslog(LOG_ERR, "set value failed 2- %s",
			    scf_strerror(scf_error()));
			ret = AOE_STATUS_ERROR;
			goto out;
		}

		/* Add the new member */
		if (scf_entry_add_value(entry, value_set[i]) == -1) {
			syslog(LOG_ERR, "add value failed - %s",
			    scf_strerror(scf_error()));
			ret = AOE_STATUS_ERROR;
			goto out;
		}
	}

	if ((commit_ret = scf_transaction_commit(tran)) != 1) {
		syslog(LOG_ERR, "transaction commit failed - %s",
		    scf_strerror(scf_error()));
		if (commit_ret == 0)
			ret = AOE_STATUS_ERROR_BUSY;
		else
			ret = AOE_STATUS_ERROR;
		goto out;
	}

out:
	/* Free resources */
	if (handle != NULL)
		scf_handle_destroy(handle);
	if (svc != NULL)
		scf_service_destroy(svc);
	if (pg != NULL)
		scf_pg_destroy(pg);
	if (tran != NULL)
		scf_transaction_destroy(tran);
	if (entry != NULL)
		scf_entry_destroy(entry);
	if (prop != NULL)
		scf_property_destroy(prop);
	if (value_iter != NULL)
		scf_iter_destroy(value_iter);
	if (value_lookup != NULL)
		scf_value_destroy(value_lookup);

	/* Free value_set scf resources */
	if (value_array_size > 0) {
		for (i = 0; i < value_array_size; i++)
			scf_value_destroy(value_set[i]);
	}
	/* Free the pointer array to the resources */
	if (value_set != NULL)
		free(value_set);

	return (ret);
}

/*
 * This routine is used to remove all the entries in the
 * SCF database for a given AoE port.
 * Input:
 *   portid          - The AoE port ID.
 *   module          - The optional modules name, or NULL.
 *   add_remove_flag - AOE_SCF_ADD or AOE_SCF_REMOVE.
 */
static AOE_STATUS
aoe_add_remove_scf_entries(uint32_t portid, char *module, int add_remove_flag)
{
	AOE_STATUS	status;
	aoe_port_list_t	*portlist = NULL;
	dladm_handle_t	handle;
	int		i, j;
	uint32_t	port_num;

	status = aoe_get_port_list(&port_num, &portlist);

	if (status != AOE_STATUS_OK)
		return (AOE_STATUS_ERROR);

	if (port_num == 0) {
		/* No AoE Ports Found! */
		free(portlist);
		return (AOE_STATUS_OK);
	}

	if (dladm_open(&handle) != DLADM_STATUS_OK)
		handle = NULL;

	for (i = 0; i < port_num; i++) {
		aoe_port_instance_t *pi = &portlist->ports[i];
		char linknames[MAXLINKNAMELEN];
		int promisc = 0;

		if (pi->api_port_id != portid)
			continue;

		bzero(linknames, sizeof (linknames));
		for (j = 0; j < pi->api_mac_cnt; j++) {
			aoe_mac_instance_t *mi = &pi->api_mac[j];
			char linkname[MAXLINKNAMELEN];
			dladm_status_t rc;

			rc = dladm_datalink_id2info(handle,
			    mi->ami_mac_linkid, NULL, NULL, NULL,
			    linkname, MAXLINKNAMELEN - 1);

			if (handle == NULL || rc != DLADM_STATUS_OK)
				continue;

			if (j > 0)
				(void) strcat(linknames, ",");
			(void) strcat(linknames, linkname);
			promisc = mi->ami_mac_promisc;
		}
		(void) aoe_add_remove_scf_entry(portid, (char *)linknames,
		    module, promisc, (pi->api_port_type == AOE_CLIENT_TARGET),
		    pi->api_port_policy, add_remove_flag);
		break;
	}

	if (handle != NULL)
		dladm_close(handle);
	free(portlist);

	return (AOE_STATUS_OK);
}

/*
 * portid	: numeric id of the port
 * linknames	: interface names list
 * promisc	: whether to enable promisc mode for interface
 * type		: 0 - initiator, 1 - target
 * policy	: 0 - disabled, 1 - failover, 2 - round-robin, 3 - load balance
 * module	: module name
 */
AOE_STATUS
aoe_create_port(int portid, char *linknames, int promisc, aoe_cli_type_t type,
    aoe_cli_policy_t policy, char *module)
{
	AOE_STATUS	status;
	aoeio_create_port_param_t param;
	aoeio_t		aoeio;
	char		*clntoken;
	char		*nlntoken;
	char		*olinknames;
	datalink_class_t class;
	datalink_id_t	linkid;
	dladm_handle_t	handle;
	int		aoe_fd;
	int		i = 0;

	bzero(&param, sizeof (aoeio_create_port_param_t));
	bzero(&aoeio, sizeof (aoeio_t));

	if (linknames == NULL)
		return (AOE_STATUS_ERROR_INVAL_ARG);

	param.acp_force_promisc = promisc;
	param.acp_port_id = portid;
	param.acp_port_policy = policy;
	param.acp_port_type = type;

	if (module != NULL &&
	    strncmp(module, "(null)", AOE_ACP_MODLEN) &&
	    strlcpy(param.acp_module, module, AOE_ACP_MODLEN) >=
	    AOE_ACP_MODLEN)
		return (AOE_STATUS_ERROR_INVAL_ARG);

	/* Parse interface names */
	if (dladm_open(&handle) != DLADM_STATUS_OK)
		return (AOE_STATUS_ERROR);

	olinknames = clntoken = nlntoken = strdup(linknames);
	for (;;) {
		clntoken = strsep(&nlntoken, ",");
		if (strlen(clntoken) > MAXLINKNAMELEN - 1) {
			dladm_close(handle);
			free(olinknames);
			return (AOE_STATUS_ERROR_MAC_LEN);
		}
		if (dladm_name2info(handle, clntoken, &linkid, NULL, &class,
		    NULL) != DLADM_STATUS_OK) {
			dladm_close(handle);
			(void) aoe_add_remove_scf_entry(portid, linknames,
			    module, promisc, (type == AOE_CLIENT_TARGET),
			    policy, AOE_SCF_REMOVE);
			free(olinknames);
			return (AOE_STATUS_ERROR_GET_LINKINFO);
		}
		param.acp_mac_linkid[i++] = linkid;
		if (nlntoken == NULL)
			break;
	};

	dladm_close(handle);
	free(olinknames);

	if ((status = aoe_open(OPEN_AOE, &aoe_fd)) != AOE_STATUS_OK)
		return (status);

	aoeio.aoeio_cmd = AOEIO_CREATE_PORT;
	aoeio.aoeio_ibuf = (uintptr_t)&param;
	aoeio.aoeio_ilen = sizeof (aoeio_create_port_param_t);
	aoeio.aoeio_xfer = AOEIO_XFER_WRITE;

	if (ioctl(aoe_fd, AOEIO_CMD, &aoeio) == 0) {
		(void) aoe_add_remove_scf_entries(param.acp_port_id,
		    module, AOE_SCF_ADD);
		status = AOE_STATUS_OK;
	} else
	{
		status = aoe_convert_error_code(aoeio.aoeio_status);
		syslog(LOG_ERR, "AoE ioctl failed. status=%u", status);
	}
	(void) close(aoe_fd);

	return (status);
}

#define	MAX_SIGN_SIZE 10

void
aoe_detach_devices_from_hal(int portid)
{
	char sign[MAX_SIGN_SIZE];
	const char aoe_sign[] = "aoeblk";
	DBusConnection *conn;
	DBusError err;
	DBusMessage *msg;
	DBusPendingCall *pending;
	char **dev_list;
	char **dev_iter;
	int dev_amount;

	(void) snprintf(sign, MAX_SIGN_SIZE, "%x", portid);

	dbus_error_init(&err);

	/* Establish D-Bus connection */
	conn = dbus_bus_get(DBUS_BUS_SYSTEM, &err);
	if (dbus_error_is_set(&err)) {
		dbus_error_free(&err);
		return;
	}
	(void) dbus_connection_ref(conn);

	/* Get list of devices handled by hal */
	msg = dbus_message_new_method_call(
	    DBUS_HAL_DESTINATION,
	    DBUS_HAL_PATH,
	    DBUS_HAL_INTERFACE,
	    DBUS_HAL_COM_DEV_LIST);
	if (!msg)
		goto exit_ref;
	(void) dbus_connection_send_with_reply(conn, msg, &pending, -1);
	dbus_connection_flush(conn);
	dbus_message_unref(msg);
	dbus_pending_call_block(pending);
	msg = dbus_pending_call_steal_reply(pending);
	dbus_pending_call_unref(pending);
	if (!msg)
		goto exit_ref;
	(void) dbus_message_get_args(msg, &err, DBUS_TYPE_ARRAY,
	    DBUS_TYPE_STRING, &dev_list, &dev_amount, DBUS_TYPE_INVALID);
	dbus_message_unref(msg);
	if (dbus_error_is_set(&err)) {
		dbus_error_free(&err);
		goto exit_ref;
	}

	/*
	 * walk through the list and send "remove" for all aoeblk devices
	 * with appropriate portid.
	 */
	for (dev_iter = dev_list; *dev_iter; ++dev_iter)
		if (strstr(*dev_iter, aoe_sign) && strstr(*dev_iter, sign)) {
			msg = dbus_message_new_method_call(
			    DBUS_HAL_DESTINATION,
			    DBUS_HAL_PATH,
			    DBUS_HAL_INTERFACE,
			    DBUS_HAL_COM_DEV_REM);
			if (!msg)
				break;
			(void) dbus_message_append_args(msg, DBUS_TYPE_STRING,
			    dev_iter, DBUS_TYPE_INVALID);
			(void) dbus_connection_send_with_reply(conn,
			    msg, &pending, -1);
			dbus_connection_flush(conn);
			dbus_message_unref(msg);
			dbus_pending_call_block(pending);
			dbus_pending_call_unref(pending);
		}

	dbus_free_string_array(dev_list);

exit_ref:
	dbus_connection_unref(conn);
}

AOE_STATUS
aoe_delete_port(int portid)
{
	aoeio_delete_port_param_t aoe_del_port;
	aoeio_t		aoeio;
	int		aoe_fd;
	int		io_ret = 0;
	uint32_t	status;

	aoe_detach_devices_from_hal(portid);

	if ((status = aoe_open(OPEN_AOE, &aoe_fd)) != AOE_STATUS_OK)
		return (status);

	aoe_del_port.adp_port_id = portid;
	(void) aoe_add_remove_scf_entries(aoe_del_port.adp_port_id,
	    NULL, AOE_SCF_REMOVE);

	bzero(&aoeio, sizeof (aoeio));
	aoeio.aoeio_cmd = AOEIO_DELETE_PORT;

	/* Only 4 bytes here, need to change */
	aoeio.aoeio_ilen = sizeof (aoeio_delete_port_param_t);
	aoeio.aoeio_xfer = AOEIO_XFER_READ;
	aoeio.aoeio_ibuf = (uintptr_t)&aoe_del_port;

	io_ret = ioctl(aoe_fd, AOEIO_CMD, &aoeio);
	if (io_ret != 0) {
		status = aoe_convert_error_code(aoeio.aoeio_status);
		syslog(LOG_ERR, "AoE ioctl failed. status=%u", status);
	}
	else
		status = AOE_STATUS_OK;

	(void) close(aoe_fd);
	return (status);
}

AOE_STATUS
aoe_get_port_list(uint32_t *port_num, aoe_port_list_t **ports)
{
	aoe_port_list_t	*inportlist = NULL;
	aoeio_t		aoeio;
	int		aoe_fd;
	int		bufsize;
	int		retry = 0;
	int		size = 64; /* default first attempt */
	uint32_t	status = AOE_STATUS_OK;

	if (port_num == NULL || ports == NULL)
		return (AOE_STATUS_ERROR_INVAL_ARG);

	*port_num = 0;
	*ports = NULL;

	if ((status = aoe_open(OPEN_AOE, &aoe_fd)) != AOE_STATUS_OK)
		return (status);

	/* Get AoE port list */
	bzero(&aoeio, sizeof (aoeio_t));
	retry = 0;

	do {
		bufsize = sizeof (aoe_port_instance_t) * (size - 1) +
		    sizeof (aoe_port_list_t);
		inportlist = (aoe_port_list_t *)malloc(bufsize);
		aoeio.aoeio_cmd = AOEIO_GET_PORT_LIST;
		aoeio.aoeio_olen = bufsize;
		aoeio.aoeio_xfer = AOEIO_XFER_READ;
		aoeio.aoeio_obuf = (uintptr_t)inportlist;

		if (ioctl(aoe_fd, AOEIO_CMD, &aoeio) != 0) {
			if (aoeio.aoeio_status == AOEIOE_MORE_DATA) {
				size = inportlist->num_ports;
			}
			free(inportlist);
			switch (aoeio.aoeio_status) {
			case AOEIOE_INVAL_ARG:
				status = AOE_STATUS_ERROR_INVAL_ARG;
				(void) close(aoe_fd);
				return (status);
			case AOEIOE_BUSY:
				status = AOE_STATUS_ERROR_BUSY;
				retry++;
				break;
			case AOEIOE_MORE_DATA:
				status = AOE_STATUS_ERROR_MORE_DATA;
				retry++;
			default:
				status = AOE_STATUS_ERROR;
				(void) close(aoe_fd);
				return (status);
			}
		} else {
			status = AOE_STATUS_OK;
			break;
		}
	} while (retry <= 3 && status != AOE_STATUS_OK);

	if (status == AOE_STATUS_OK && inportlist->num_ports > 0) {
		*port_num = inportlist->num_ports;
		*ports = inportlist;
	}
	(void) close(aoe_fd);
	return (status);
}

const char *
aoe_strerror(AOE_STATUS error)
{
	int	i;

	for (i = 0; i < sizeof (errtab) / sizeof (errtab[0]); i++) {
		if (errtab[i].errnum == error)
			return (errtab[i].errmsg);
	};

	return ("unknown error");
}

/*
 * Initialize scf aoe service access
 * handle - returned handle
 * service - returned service handle
 */
static int
aoe_cfg_scf_init(scf_handle_t **handle, scf_service_t **service, int is_target)
{
	int		ret;
	scf_scope_t	*scope = NULL;

	if ((*handle = scf_handle_create(SCF_VERSION)) == NULL) {
		syslog(LOG_ERR, "scf_handle_create failed - %s",
		    scf_strerror(scf_error()));
		ret = AOE_STATUS_ERROR;
		goto err;
	}

	if (scf_handle_bind(*handle) == -1) {
		syslog(LOG_ERR, "scf_handle_bind failed - %s",
		    scf_strerror(scf_error()));
		ret = AOE_STATUS_ERROR;
		goto err;
	}

	if ((*service = scf_service_create(*handle)) == NULL) {
		syslog(LOG_ERR, "scf_service_create failed - %s",
		    scf_strerror(scf_error()));
		ret = AOE_STATUS_ERROR;
		goto err;
	}

	if ((scope = scf_scope_create(*handle)) == NULL) {
		syslog(LOG_ERR, "scf_scope_create failed - %s",
		    scf_strerror(scf_error()));
		ret = AOE_STATUS_ERROR;
		goto err;
	}

	if (scf_handle_get_scope(*handle, SCF_SCOPE_LOCAL, scope) == -1) {
		syslog(LOG_ERR, "scf_handle_get_scope failed - %s",
		    scf_strerror(scf_error()));
		ret = AOE_STATUS_ERROR;
		goto err;
	}

	if (scf_scope_get_service(scope,
	    is_target ? AOE_TARGET_SERVICE : AOE_INITIATOR_SERVICE,
	    *service) == -1) {
		syslog(LOG_ERR, "scf_scope_get_service failed - %s",
		    scf_strerror(scf_error()));
		ret = AOE_STATUS_ERROR_SERVICE_NOT_FOUND;
		goto err;
	}

	scf_scope_destroy(scope);

	return (AOE_STATUS_OK);

err:
	if (*handle != NULL)
		scf_handle_destroy(*handle);

	if (*service != NULL) {
		scf_service_destroy(*service);
		*service = NULL;
	}

	if (scope != NULL)
		scf_scope_destroy(scope);

	return (ret);
}

AOE_STATUS
aoe_load_config(uint32_t port_type, AOE_SMF_PORT_LIST **portlist)
{
	PAOE_SMF_PORT_INSTANCE pi;
	char		buf[AOE_PORT_LIST_LEN] = {0};
	int		bufsize, retry;
	int		commit_ret;
	int		pg_or_prop_not_found = 0;
	int		size = AOE_MAX_MACOBJ; /* default first attempt */
	scf_handle_t	*handle = NULL;
	scf_iter_t	*value_iter = NULL;
	scf_property_t	*prop = NULL;
	scf_propertygroup_t *pg = NULL;
	scf_service_t	*svc = NULL;
	scf_transaction_entry_t	*entry = NULL;
	scf_transaction_t *tran = NULL;
	scf_value_t	*value_lookup = NULL;
	unsigned int	port_index;

	commit_ret = aoe_cfg_scf_init(&handle, &svc,
	    (port_type == AOE_PORTTYPE_TARGET));
	if (commit_ret != AOE_STATUS_OK) {
		goto out;
	}

	if (((pg = scf_pg_create(handle)) == NULL) ||
	    ((tran = scf_transaction_create(handle)) == NULL) ||
	    ((entry = scf_entry_create(handle)) == NULL) ||
	    ((prop = scf_property_create(handle)) == NULL) ||
	    ((value_iter = scf_iter_create(handle)) == NULL))
		goto out;

	if (scf_service_get_pg(svc, AOE_PG_NAME, pg) == -1) {
		pg_or_prop_not_found = 1;
		goto out;
	}

	if (scf_pg_get_property(pg, AOE_PORT_LIST_PROP, prop) == -1) {
		pg_or_prop_not_found = 1;
		goto out;
	}

	value_lookup = scf_value_create(handle);
	if (value_lookup == NULL) {
		syslog(LOG_ERR, "scf value alloc failed - %s",
		    scf_strerror(scf_error()));
		goto out;
	}

	port_index = 0;

	do {
		if (scf_iter_property_values(value_iter, prop) == -1) {
			syslog(LOG_ERR, "iter value failed - %s",
			    scf_strerror(scf_error()));
			goto out;
		}

		retry = 0;
		bufsize = sizeof (AOE_SMF_PORT_INSTANCE) * (size - 1) +
		    sizeof (AOE_SMF_PORT_LIST);
		*portlist = (PAOE_SMF_PORT_LIST)malloc(bufsize);

		while (scf_iter_next_value(value_iter, value_lookup) == 1) {
			aoe_cli_policy_t policy;
			aoe_cli_type_t	type;
			int		promisc;
			int		portid;
			char		*remainder = NULL;
			uint8_t		*linknames = NULL;
			uint8_t		*module = NULL;

			bzero(buf, sizeof (buf));
			if (scf_value_get_ustring(value_lookup,
			    buf, MAXNAMELEN) == -1) {
				syslog(LOG_ERR, "iter value failed - %s",
				    scf_strerror(scf_error()));
				break;
			}
			linknames = (uint8_t *)strtok(buf, ":");
			module = (uint8_t *)strtok(NULL, ":");
			remainder = strtok(NULL, "#");
			(void) sscanf(remainder, "%d:%d:%d:%d",
			    &portid, &promisc, &type, &policy);
			if (port_index >= size) {
				free(*portlist);
				retry = 1;
				size *= 2;
				break;
			} else {
				pi = &(*portlist)->ports[port_index++];
				(void) strlcpy((char *)pi->linknames,
				    (char *)linknames, MAXLINKNAMELEN);
				pi->promisc = promisc;
				pi->type = type;
				pi->policy = policy;
				pi->id = portid;
				if (module == NULL ||
				    strncmp((char *)module, "(null)",
				    AOE_ACP_MODLEN) == 0)
					bzero(pi->module,
					    AOE_ACP_MODLEN);
				else
					(void) strlcpy(pi->module,
					    (char *)module, AOE_ACP_MODLEN);
			}
		}
		(*portlist)->port_num = port_index;
	} while (retry == 1);

	return (AOE_STATUS_OK);
out:
	/* Free resources */
	if (handle != NULL)
		scf_handle_destroy(handle);
	if (svc != NULL)
		scf_service_destroy(svc);
	if (pg != NULL)
		scf_pg_destroy(pg);
	if (tran != NULL)
		scf_transaction_destroy(tran);
	if (entry != NULL)
		scf_entry_destroy(entry);
	if (prop != NULL)
		scf_property_destroy(prop);
	if (value_iter != NULL)
		scf_iter_destroy(value_iter);
	if (value_lookup != NULL)
		scf_value_destroy(value_lookup);

	if (pg_or_prop_not_found == 1)
		return (AOE_STATUS_OK);
	else
		return (AOE_STATUS_ERROR);
}

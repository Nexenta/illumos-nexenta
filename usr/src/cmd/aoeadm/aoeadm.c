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

#include <sys/aoe.h>

#include <libaoe.h>
#include <libdllink.h>
#include <libintl.h>
#include <libscf.h>
#include <locale.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <syslog.h>
#include <wchar.h>

/* Define an abbreviation for gettext to save typing */
#define	_(s)	gettext(s)

static int	aoeadm_create_port(int, char **);
static int	aoeadm_delete_port(int, char **);
static int	aoeadm_list_ports(int, char **);
static void	print_port_info(aoe_port_instance_t *, char *, int);
static void	usage(void);

typedef struct aoeadm_command {
	const char	*name;
	int		(*func)(int argc, char **argv);
} aoeadm_command_t;

static aoeadm_command_t cmdtable[] = {
	{ "create-initiator",	aoeadm_create_port	},
	{ "create-target",	aoeadm_create_port	},
	{ "delete-initiator",	aoeadm_delete_port	},
	{ "delete-target",	aoeadm_delete_port	},
	{ "list-initiator",	aoeadm_list_ports	},
	{ "list-target",	aoeadm_list_ports	}
};
/* Note: Update this value if necessary when cmdtable is updated */
#define	MAX_AOEADM_CMDLEN	16

static const char	*cmdname;

extern const char	*__progname;


int
main(int argc, char **argv)
{
	int	i;

	(void) setlocale(LC_ALL, "");
#if !defined(TEXT_DOMAIN)
#define	TEXT_DOMAIN "SYS_TEST"
#endif
	(void) textdomain(TEXT_DOMAIN);

	if (argc < 2)
		usage();

	if (strnlen(argv[1], MAX_AOEADM_CMDLEN+1) > MAX_AOEADM_CMDLEN) {
		(void) fprintf(stderr, _("Invalid argument.\n"));
		usage();
		return (1);
	}
	for (i = 0; i < sizeof (cmdtable) / sizeof (cmdtable[0]); i++) {
		/*
		 * The following strcmp is safe because we've
		 * already validated the size of argv[1].
		 */
		if (strcmp(argv[1], cmdtable[i].name) == 0) {
			cmdname = argv[1];
			return (cmdtable[i].func(argc - 1, argv + 1));
		}
	};

	usage();
	/* NOTREACHED */
	return (0);
}

static int
aoeadm_create_port(int argc, char **argv)
{
	AOE_STATUS	ret;
	aoe_cli_policy_t policy = AOE_POLICY_NONE;
	char		c;
	char		*linknames;
	char		*module = NULL;
	int		portid;
	int		promisc = 0;

	while ((c = getopt(argc, argv, "fm:p:")) != -1) {
		switch (c) {
		case 'f':
			promisc = 1;
			break;
		case 'm':
			module = optarg;
			break;
		case 'p':
			if (strcmp(optarg, "failover") == 0)
				policy = AOE_POLICY_FAILOVER;
			else if (strcmp(optarg, "loadbalance") == 0)
				policy = AOE_POLICY_LOADBALANCE;
			else if (strcmp(optarg, "roundrobin") == 0)
				policy = AOE_POLICY_ROUNDROBIN;
			else
				usage();
			break;
		default:
			usage();
		}
	}

	argc -= optind;
	argv += optind;

	if (argc < 2)
		usage();

	errno = 0;
	portid = strtol(argv[0], (char **)NULL, 10);
	if (errno != 0 || portid < 0)
		usage();
	linknames = argv[1];

	if (strcmp(cmdname, "create-initiator") == 0)
		ret = aoe_create_port(portid, linknames, promisc,
		    AOE_CLIENT_INITIATOR, policy, module);
	else
		ret = aoe_create_port(portid, linknames, promisc,
		    AOE_CLIENT_TARGET, policy, module);

	if (ret != AOE_STATUS_OK) {
		(void) fprintf(stderr, _("Failed to create port: %s\n"),
		    aoe_strerror(ret));
	}

	return (ret);
}

static int
aoeadm_delete_port(int argc, char **argv)
{
	AOE_STATUS	ret;
	int		portid;

	if (argc < 2)
		usage();

	errno = 0;
	portid = strtol(argv[1], (char **)NULL, 10);
	if (errno != 0 || portid < 0)
		usage();

	ret = aoe_delete_port(portid);

	if (ret != AOE_STATUS_OK) {
		(void) fprintf(stderr, _("Failed to delete port: %s\n"),
		    aoe_strerror(ret));
	}

	return (ret);
}

static int
aoeadm_list_ports(int argc, char **argv)
{
	AOE_STATUS	ret;
	aoe_port_list_t	*portlist = NULL;
	char		c;
	dladm_handle_t	handle;
	int		i;
	int		portid = -1;
	int		verbose = 0;
	uint32_t	nports;

	while ((c = getopt(argc, argv, "v")) != -1) {
		switch (c) {
		case 'v':
			verbose = 1;
			break;
		default:
			usage();
		}
	}

	argc -= optind;
	argv += optind;

	if (argc == 1) {
		errno = 0;
		portid = strtol(argv[0], (char **)NULL, 10);
		if (errno != 0 || portid < 0)
			usage();
	}

	ret = aoe_get_port_list(&nports, &portlist);

	if (ret != AOE_STATUS_OK) {
		(void) fprintf(stderr, _("Failed to list ports: %s\n"),
		    aoe_strerror(ret));
		return (ret);
	}

	if (nports == 0) {
		free(portlist);
		return (0);
	}

	if (dladm_open(&handle) != DLADM_STATUS_OK)
		handle = NULL;

	for (i = 0; i < nports; i++) {
		aoe_port_instance_t *pi = &portlist->ports[i];
		char		linknames[AOE_MAX_MACOBJ * MAXLINKNAMELEN];
		int		j;

		if (portid >= 0 && pi->api_port_id != portid)
			continue;

		if ((pi->api_port_type == AOE_CLIENT_INITIATOR &&
		    strcmp(cmdname, "list-target") == 0) ||
		    (pi->api_port_type == AOE_CLIENT_TARGET &&
		    strcmp(cmdname, "list-initiator") == 0))
			continue;

		/* Convert linkid to interface name */
		for (j = 0; j < pi->api_mac_cnt; j++) {
			aoe_mac_instance_t *mi = &pi->api_mac[j];
			char	*linkname = linknames + j * MAXLINKNAMELEN;

			if (handle == NULL ||
			    dladm_datalink_id2info(handle, mi->ami_mac_linkid,
			    NULL, NULL, NULL, linkname, MAXLINKNAMELEN - 1) !=
			    DLADM_STATUS_OK)
				(void) strcpy(linkname, "<unknown>");
		}

		print_port_info(pi, linknames, verbose);

		if (portid >= 0) {
			if (handle != NULL)
				dladm_close(handle);
			free(portlist);
			return (0);
		}
	}

	if (handle != NULL)
		dladm_close(handle);
	free(portlist);

	return (portid >= 0 ? 1 : 0);
}

static void
print_port_info(aoe_port_instance_t *pi, char *linknames, int verbose)
{
	int	i;

	if (pi == NULL)
		return;

	if (pi->api_port_type == AOE_CLIENT_INITIATOR)
		(void) printf(_("Initiator: aoe.port"));
	else
		(void) printf(_("Target: aoe.shelf"));
	(void) printf("%d\n", pi->api_port_id);

	if (!verbose)
		return;

	(void) printf(_("    State\t\t: %s\n"),
	    (pi->api_port_state == AOE_PORT_STATE_ONLINE) ?
	    _("Online") : _("Offline"));
	(void) printf(_("    Multipath Policy\t: %s\n"),
	    (pi->api_port_policy == AOE_POLICY_NONE) ? _("Disabled") :
	    (pi->api_port_policy == AOE_POLICY_FAILOVER ?  _("Fail-Over") :
	    (pi->api_port_policy == AOE_POLICY_ROUNDROBIN ?
	    _("Round-Robin") : _("Load-Balance"))));
	(void) printf(_("    Maxxfer\t\t: %d bytes\n"), pi->api_maxxfer);
	(void) printf(_("    Interfaces\t\t: %d\n"), pi->api_mac_cnt);

	for (i = 0; i < pi->api_mac_cnt; i++) {
		aoe_mac_instance_t *mi = &pi->api_mac[i];
		int		j;

		(void) printf(_("\tInterface: %s\n"),
		    linknames + i * MAXLINKNAMELEN);
		(void) printf(_("\t    Link Id\t\t: %d\n"), mi->ami_mac_linkid);
		(void) printf(_("\t    Link State\t\t: %s\n"),
		    mi->ami_mac_link_state == AOE_MAC_LINK_STATE_UP ?
		    _("Up") : _("Down"));
		(void) printf(_("\t    Link MTU\t\t: %d\n"), mi->ami_mtu_size);
		(void) printf(_("\t    Primary MAC Address\t: "));
		for (j = 0; j < 6; j++)
			(void) printf("%02x", mi->ami_mac_factory_addr[j]);
		(void) printf(_("\n\t    Current MAC Address\t: "));
		for (j = 0; j < 6; j++)
			(void) printf("%02x", mi->ami_mac_current_addr[j]);
		(void) printf(_("\n\t    Promiscuous Mode\t: %s\n"),
		    mi->ami_mac_promisc == 1 ? _("On") : _("Off"));
		(void) printf(_("\t    TX frames\t\t: %ld\n"),
		    mi->ami_mac_tx_frames);
		(void) printf(_("\t    RX frames\t\t: %ld\n"),
		    mi->ami_mac_rx_frames);
	}
}

static void
usage(void)
{

	(void) fprintf(stderr, _(
"Usage:\n"
"\t%s create-initiator [-f] [-p policy] port link[,link,...]\n"
"\t%s create-target [-f] [-m module] [-p policy] shelf link[,link,...]\n"
"\t%s delete-initiator port\n"
"\t%s delete-target shelf\n"
"\t%s list-initiator [-v]\n"
"\t%s list-target [-v]\n"),
	    __progname, __progname, __progname,
	    __progname, __progname, __progname);

	exit(1);
}

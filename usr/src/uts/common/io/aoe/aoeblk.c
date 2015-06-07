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
 * Copyright 2013 Nexenta Systems, Inc. All rights reserved.
 */

#include <sys/aoe.h>
#include <sys/blkdev.h>
#include <sys/conf.h>
#include <sys/debug.h>
#include <sys/devops.h>
#include <sys/dktp/bbh.h>
#include <sys/dktp/cmdk.h>
#include <sys/errno.h>
#include <sys/file.h>
#include <sys/kmem.h>
#include <sys/ksynch.h>
#include <sys/log.h>
#include <sys/mac_client.h>
#include <sys/modctl.h>
#include <sys/modctl.h>
#include <sys/param.h>
#include <sys/pci.h>
#include <sys/stat.h>
#include <sys/stream.h>
#include <sys/stropts.h>
#include <sys/strsubr.h>
#include <sys/strsun.h>
#include <sys/sunndi.h>
#include <sys/sysmacros.h>
#include <sys/types.h>

static char *aoe_errlist[] =
{
	"no such error",
	"unrecognized command code",
	"bad argument parameter",
	"device unavailable",
	"config string present",
	"unsupported version",
	"target is reserved"
};

#define	list_empty(a) ((a)->list_head.list_next == &(a)->list_head)

#define	NECODES		(sizeof (aoe_errlist) / sizeof (char *) - 1)
#define	TIMERTICK	(hz / 10)
#define	MINTIMER	(50 * TIMERTICK)
#define	MAXTIMER	(hz << 4)
#define	MAXWAIT		60 /* MAXWAIT rexmit time, fail device. */
#define	DISCTIMER	10 /* Periodic disk discovery timer */

#define	OP_READ		0
#define	OP_WRITE	1
#define	OP_FLUSH	2

int aoeblk_maxwait = MAXWAIT;
int aoeblk_wc = 1;

/*
 * Driver's global variables
 */
static char aoeblk_ident[]		= "AOE IO block driver";

static int aoeblk_attach(dev_info_t *, ddi_attach_cmd_t);
static int aoeblk_detach(dev_info_t *, ddi_detach_cmd_t);

static struct dev_ops aoeblk_dev_ops = {
	DEVO_REV,
	0,
	ddi_no_info,
	nulldev,		/* identify */
	nulldev,		/* probe */
	aoeblk_attach,		/* attach */
	aoeblk_detach,		/* detach */
	nodev,			/* reset */
	NULL,			/* cb_ops */
	NULL,			/* bus_ops */
	ddi_power,		/* power */
	ddi_quiesce_not_needed	/* quiesce */
};

/* Standard Module linkage initialization for a Streams driver */
extern struct mod_ops mod_driverops;

static struct modldrv modldrv = {
	&mod_driverops,	    /* Type of module.  This one is a driver */
	aoeblk_ident,	    /* short description */
	&aoeblk_dev_ops	    /* driver specific ops */
};

static struct modlinkage modlinkage = {
	MODREV_1,
	{
		(void *)&modldrv,
		NULL,
	},
};

typedef struct aoeblk_stats {
	struct kstat_named	sts_rw_outofmemory;
	struct kstat_named	sts_rw_badoffset;
	struct kstat_named	sts_error_packets;
	struct kstat_named	sts_unsolicited_packets;
	struct kstat_named	sts_unsolicited_xfers;
	struct kstat_named	sts_bad_xfers;
	struct kstat_named	sts_rexmit_packets;
} aoeblk_stats_t;

typedef struct aoeblk_softc {
	dev_info_t		*dev;
	aoe_eport_t		*eport;
	aoe_frame_t		*bcast_f[AOE_MAX_MACOBJ];
	aoeblk_stats_t		*ks_data;
	kstat_t			*sc_intrstat;
	volatile timeout_id_t	discovery_timeout_id;
	kmutex_t		bd_mutex;
	list_t			bd_list;
} aoeblk_softc_t;

#define	DEVFL_UP	1	/* device is ready for AoE->ATA commands */
#define	DEVFL_OPEN	(1<<1)
#define	DEVFL_TKILL	(1<<2)	/* flag for timer to know when to kill self */
#define	DEVFL_EXT	(1<<3)	/* device accepts lba48 commands */
#define	DEVFL_CLOSEWAIT	(1<<4)	/* device is waiting for close to revalidate */
#define	DEVFL_ATTWAIT	(1<<5)	/* disk responded to ATA ID, to be attached */
#define	DEVFL_WC_UPDATE	(1<<6)	/* device needs to update write cache status */
#define	DEVFL_DESTROY	(1<<7)
#define	DEVFL_STATECHG	(1<<8)

/*
 * The maximum number of outstanding frames
 */
#define	AOEDISK_MAXFRAMES	8192	/* default value */
static int aoedisk_maxframes;

typedef struct xfer_private {
	uint32_t	msgs_cnt;
	uint32_t	msgs_sent;
	uint32_t	err_cnt;
} xfer_private_t;

#define	xfer_priv(x_v)	((xfer_private_t *)&(x_v)->x_dmac)

typedef struct aoedisk {
	list_node_t		node;
	list_t			frames;
	aoeblk_softc_t		*sc;
	bd_handle_t		bd_h;
	dev_info_t		*dev;
	void			*master_mac;
	aoe_eport_t		*eport;
	volatile timeout_id_t	rexmit_timeout_id;
	kmutex_t		ad_mutex;
	uint32_t		ad_flags;
	uint32_t		ad_status;
	unsigned long		ad_unit_id;
	unsigned short		ad_major;
	unsigned short		ad_minor;
	unsigned long		ad_unit;
	unsigned short		ad_lasttag;
	unsigned short		ad_rttavg;
	unsigned short		ad_mintimer;
	off_t			ad_nsectors;
	unsigned short		ad_nframes;
	char			ad_model[40];
	char			ad_serial[20];
	char			ad_version[8];
	char			ad_ident[512];
} aoedisk_t;

typedef struct aoeblk_frame {
	list_node_t		frm_node;
	void			*frm_req;
	caddr_t			frm_kaddr;
	uint32_t		frm_klen;
	uint32_t		frm_waited;
	uint32_t		frm_tag;
	uint32_t		frm_rsvd0;
	char			frm_hdr[AOEHDRSZ];
} aoeblk_frame_t;

static int aoeblk_read(void *arg, bd_xfer_t *xfer);
static int aoeblk_write(void *arg, bd_xfer_t *xfer);
static int aoeblk_flush(void *arg, bd_xfer_t *xfer);
static int aoeblk_reserve(void *arg, bd_xfer_t *xfer);
static void aoeblk_driveinfo(void *arg, bd_drive_t *drive);
static int aoeblk_mediainfo(void *arg, bd_media_t *media);
static int aoeblk_devid_init(void *, dev_info_t *, ddi_devid_t *);

static bd_ops_t aoeblk_ops = {
	BD_OPS_VERSION_0,
	aoeblk_driveinfo,
	aoeblk_mediainfo,
	aoeblk_devid_init,
	aoeblk_flush,
	aoeblk_read,
	aoeblk_write,
	aoeblk_reserve,
};

static void
aoeblk_driveinfo(void *arg, bd_drive_t *drive)
{
	aoedisk_t *d = (aoedisk_t *)arg;

	drive->d_removable = B_FALSE;
	drive->d_hotpluggable = B_TRUE;
	drive->d_target = d->ad_major;
	drive->d_lun = d->ad_minor;
	drive->d_maxxfer = d->eport->eport_maxxfer;

	if (d->ad_nframes <= 4) {
		drive->d_qsize = 1;
		drive->d_maxxfer *= d->ad_nframes;
	} else if (d->ad_nframes <= 8) {
		drive->d_qsize = 2;
		drive->d_maxxfer *= (d->ad_nframes / 2);
	} else if (d->ad_nframes <= 16) {
		drive->d_qsize = 4;
		drive->d_maxxfer *= (d->ad_nframes / 4);
	} else if (d->ad_nframes <= 1024) {
		drive->d_qsize = 8;
		drive->d_maxxfer *= (d->ad_nframes / 8);
	} else {
		drive->d_qsize = 64;
		drive->d_maxxfer *= (d->ad_nframes / 64);
	}
}

static int
aoeblk_mediainfo(void *arg, bd_media_t *media)
{
	aoedisk_t *d = (aoedisk_t *)arg;

	media->m_nblks = d->ad_nsectors;
	media->m_blksize = DEV_BSIZE;
	media->m_readonly = 0;

	if (d->ad_flags & DEVFL_CLOSEWAIT)
		return (1);
	return (0);
}

static int
aoeblk_get_modser(char *buf, int len)
{
	char *s;
	char ch;
	boolean_t ret;
	int tb = 0;
	int i;

	/*
	 * valid model/serial string must contain a non-zero non-space
	 * trim trailing spaces/NULL
	 */
	ret = B_FALSE;
	s = buf;
	for (i = 0; i < len; i++) {
		ch = *s++;
		if (ch != ' ' && ch != '\0')
			tb = i + 1;
		if (ch != ' ' && ch != '\0' && ch != '0')
			ret = B_TRUE;
	}

	if (ret == B_FALSE)
		return (0);

	return (tb);
}

static int
aoeblk_devid_init(void *arg, dev_info_t *dip, ddi_devid_t *devid)
{
	aoedisk_t *d = (aoedisk_t *)arg;
	char *hwid;
	int verlen, modlen, serlen, ret;
	unsigned short *tmp_ptr;

	/*
	 * devid_init call will be executed upon successful bd_attach()
	 * Lets store it in per-disk structure for future use.
	 */
	d->dev = dip;

	/*
	 * WORD 27 LEN 40: MODEL NAME
	 * WORD 23 LEN  8: VERSION
	 * WORD 10 LEN 20: SERIAL
	 */
	tmp_ptr = (unsigned short *)d->ad_ident;

	/*
	 * Device ID is a concatenation of model number, '=', serial number.
	 */
	hwid = kmem_alloc(CMDK_HWIDLEN, KM_SLEEP);
	bcopy(tmp_ptr + 27, hwid, 40);
	modlen = aoeblk_get_modser(hwid, 40);
	d->ad_model[modlen] = 0;
	bcopy(hwid, d->ad_model, modlen + 1);

	hwid[modlen++] = '=';

	bcopy(tmp_ptr + 10, hwid + modlen, 20);
	serlen = aoeblk_get_modser(hwid + modlen, 20);
	hwid[modlen + serlen] = 0;
	bcopy(hwid + modlen, d->ad_serial, serlen + 1);

	bcopy(tmp_ptr + 23, d->ad_version, 8);
	verlen = aoeblk_get_modser(d->ad_version, 8);
	d->ad_version[verlen] = 0;

	ret = ddi_devid_init(dip, DEVID_ATA_SERIAL,
	    modlen + serlen, hwid, devid);
	if (ret != DDI_SUCCESS) {
		kmem_free(hwid, CMDK_HWIDLEN);
		dev_err(dip, CE_WARN, "Cannot build devid for the device %d.%d",
		    d->ad_major, d->ad_minor);
		return (ret);
	}

	cmn_err(CE_NOTE,
	    "!%s%d/%s%d :\n    Model  : %s\n    Ver.   : %s\n    Serial : %s",
	    ddi_driver_name(d->sc->dev), ddi_get_instance(d->sc->dev),
	    ddi_driver_name(d->dev), ddi_get_instance(d->dev),
	    d->ad_model, d->ad_version, d->ad_serial);

	kmem_free(hwid, CMDK_HWIDLEN);
	return (DDI_SUCCESS);
}

static aoedisk_t *
aoedisk_lookup_by_unit(aoeblk_softc_t *sc, unsigned long unit)
{
	aoedisk_t *d = NULL;

	for (d = list_head(&sc->bd_list); d; d = list_next(&sc->bd_list, d)) {
		if (unit == d->ad_unit)
			break;
	}

	return (d);
}

static aoeblk_frame_t *
findframe(aoedisk_t *d, uint32_t tag)
{
	aoeblk_frame_t *f;

	mutex_enter(&d->ad_mutex);
	for (f = list_head(&d->frames); f; f = list_next(&d->frames, f)) {
		if (f->frm_tag == tag) {
			mutex_exit(&d->ad_mutex);
			return (f);
		}
	}
	mutex_exit(&d->ad_mutex);
	return (NULL);
}

static aoeblk_frame_t *
allocframe(aoedisk_t *d, void *mac, aoe_frame_t **af_out, int kmflag)
{
	aoe_frame_t *af;
	aoeblk_frame_t *f;
	aoe_eport_t *eport = d->eport;

	af = eport->eport_alloc_frame(eport, d->ad_unit_id, mac, kmflag);
	if (af == NULL) {
		return (NULL);
	}
	f = FRM2PRIV(af);
	af->af_netb = NULL;
	if (!eport->eport_alloc_netb(af, AOEHDRSZ, f->frm_hdr, kmflag)) {
		eport->eport_release_frame(af);
		return (NULL);
	}
	mutex_enter(&d->ad_mutex);
	f->frm_tag = (uint32_t)INPROCTAG;
	list_insert_tail(&d->frames, f);
	mutex_exit(&d->ad_mutex);

	*af_out = af;
	return (f);
}

static void
freeframe(aoedisk_t *d, aoeblk_frame_t *f)
{
	aoe_frame_t *af = PRIV2FRM(f);

	mutex_enter(&d->ad_mutex);
	ASSERT(f->frm_tag == (uint32_t)INPROCTAG);
	f->frm_tag = (uint32_t)FREETAG;
	f->frm_req = NULL;
	list_remove(&d->frames, f);
	mutex_exit(&d->ad_mutex);

	d->eport->eport_release_frame(af);
}

/*
 * Leave the top bit clear so we have tagspace for userland.
 * The bottom 16 bits are the xmit tick for rexmit/rttavg processing.
 * This driver reserves tag -1 to mean "unused frame."
 */
static inline uint32_t
newtag(aoedisk_t *d)
{
	register int n;

	n = ddi_get_lbolt() & 0xffff;
	n |= (++d->ad_lasttag & 0x7fff) << 16;
	return (n);
}

static int
aoehdr_atainit(aoedisk_t *d, aoe_hdr_t *h)
{
	uint32_t host_tag;

	host_tag = newtag(d);

	h->aoeh_type = htons(ETHERTYPE_AOE);
	h->aoeh_verfl = AOE_HVER;
	h->aoeh_major = htons(d->ad_major);
	h->aoeh_minor = d->ad_minor;
	h->aoeh_cmd = (unsigned char)AOECMD_ATA;
	h->aoeh_tag = htonl(host_tag);

	return ((int)host_tag);
}

static inline uint16_t
lhget16(uchar_t *p)
{
	uint16_t n;

	n = p[1];
	n <<= 8;
	n |= p[0];
	return (n);
}

static inline uint32_t
lhget32(uchar_t *p)
{
	uint32_t n;

	n = lhget16(p+2);
	n <<= 16;
	n |= lhget16(p);
	return (n);
}

/* How long since we sent this tag? */
static int
tsince(unsigned int tag)
{
	int n;

	n = ddi_get_lbolt() & 0xffff;
	n -= tag & 0xffff;
	if (n < 0)
		n += 1<<16;
	return (n);
}

static void
rexmit(aoedisk_t *d, aoeblk_frame_t *f)
{
	aoe_frame_t *af = PRIV2FRM(f);
	aoe_hdr_t *h;
	aoe_atahdr_t *ah;
	uint32_t oldtag;
	void *oldnetb;
	mblk_t *mp;
	aoe_eport_t *eport = d->eport;

	h = (aoe_hdr_t *)f->frm_hdr;
	ah = (aoe_atahdr_t *)(h+1);

	if (f->frm_tag == (uint32_t)INPROCTAG ||
	    f->frm_tag == (uint32_t)FREETAG ||
	    f->frm_req == NULL) {
		return;
	}
	oldtag = f->frm_tag;
	oldnetb = af->af_netb;
	f->frm_tag = (uint32_t)INPROCTAG;

	af->af_netb = NULL;
	mp = eport->eport_alloc_netb(af, AOEHDRSZ, f->frm_hdr, KM_SLEEP);
	if (mp == NULL) {
		af->af_netb = oldnetb;
		f->frm_tag = oldtag;
		dev_err(d->sc->dev, CE_WARN,
		    "Out of memory on rexmit frame hdr tag %x", oldtag);
		return;
	}

	if (f->frm_kaddr && ah->aa_aflags & AOEAFL_WRITE) {
		if (!eport->eport_alloc_netb(af, f->frm_klen,
		    f->frm_kaddr, KM_SLEEP)) {
			freeb(mp);
			af->af_netb = oldnetb;
			f->frm_tag = oldtag;
			dev_err(d->sc->dev, CE_WARN,
			    "Out of memory on rexmit frame tag %x", oldtag);
			return;
		}
	}
	f->frm_tag = newtag(d);
	h->aoeh_tag = htonl(f->frm_tag);

	/*
	 * Report accident... so that balancer can better estimate
	 * what MAC needs to be used next time...
	 */
	eport->eport_ctl(eport, af->af_mac,
	    AOE_CMD_PORT_UNIT_RETRANSMIT, (void *)d->ad_unit_id);

	eport->eport_tx_frame(af);
}

static void
aoeblk_downdisk(aoedisk_t *d, void *mac, int media_change)
{
	int i;

	/* disable timer */
	atomic_or_32(&d->ad_flags, DEVFL_TKILL);

	if (media_change && d->ad_flags & DEVFL_UP) {
		aoe_eport_t *eport = d->sc->eport;

		atomic_and_32(&d->ad_flags, ~DEVFL_UP);
		atomic_or_32(&d->ad_flags, DEVFL_CLOSEWAIT);

		/*
		 * State change will occure in rexmit timer
		 */
		atomic_or_32(&d->ad_flags, DEVFL_STATECHG);

		if (mac != NULL) {
			eport->eport_ctl(eport, mac,
			    AOE_CMD_PORT_UNIT_OFFLINE, (void *)d->ad_unit_id);
			return;
		}
		for (i = 0; i < eport->eport_mac_cnt; i++) {
			eport->eport_ctl(eport, eport->eport_mac[i],
			    AOE_CMD_PORT_UNIT_OFFLINE, (void *)d->ad_unit_id);
		}
	} else
		atomic_and_32(&d->ad_flags, ~DEVFL_UP);
}

static void
rexmit_timer(void *vp)
{
	int n, ntx;
	aoedisk_t *d = vp;
	register int timeout_ticks;
	aoeblk_frame_t *f;

	mutex_enter(&d->ad_mutex);

	/*
	 * Timeout is always ~150% of the moving average.
	 */
	timeout_ticks = d->ad_rttavg;
	timeout_ticks += timeout_ticks >> 1;
	ntx = 0;

	if (d->ad_flags & DEVFL_TKILL) {
		mutex_exit(&d->ad_mutex);
		return;
	}
	for (f = list_head(&d->frames); f; f = list_next(&d->frames, f)) {
		if (f->frm_tag != (uint32_t)FREETAG &&
		    f->frm_tag != (uint32_t)INPROCTAG &&
		    tsince(f->frm_tag) > timeout_ticks) {
			n = f->frm_waited += timeout_ticks;
			n /= hz;
			if (n > aoeblk_maxwait) {
				aoe_frame_t *af = PRIV2FRM(f);
				/* Waited too long.  Device failure. */
				aoeblk_downdisk(d, af->af_mac, 1);
				mutex_exit(&d->ad_mutex);
				dev_err(d->dev, CE_WARN, "device %d.%d is not "
				    "responding and in-recovery",
				    d->ad_major, d->ad_minor);
				return;
			}
			ntx++;
			rexmit(d, f);
			d->sc->ks_data->sts_rexmit_packets.value.ui64++;
		}
	}
	if (ntx) {
		n = d->ad_rttavg <<= 1;
		if (n > MAXTIMER)
			d->ad_rttavg = MAXTIMER;
	}

	if (d->rexmit_timeout_id)
		d->rexmit_timeout_id = timeout(rexmit_timer, d, TIMERTICK);
	mutex_exit(&d->ad_mutex);

	/*
	 * Trigger state change
	 */
	if (d->ad_flags & DEVFL_STATECHG) {
		atomic_and_32(&d->ad_flags, ~DEVFL_STATECHG);
		if (d->ad_flags & DEVFL_CLOSEWAIT) {
			if (d->bd_h)
				bd_state_change(d->bd_h);
		} else {
			if (d->bd_h) {
				(void) bd_detach_handle(d->bd_h);
				bd_free_handle(d->bd_h);
				d->bd_h = NULL;
			}
			atomic_or_32(&d->ad_flags, DEVFL_ATTWAIT);
		}
	}

	if (d->ad_flags & DEVFL_ATTWAIT) {
		int ret;

		atomic_and_32(&d->ad_flags, ~DEVFL_ATTWAIT);

		d->bd_h = bd_alloc_handle(d, &aoeblk_ops, NULL, KM_SLEEP);
		if (d->bd_h == NULL) {
			dev_err(d->dev, CE_WARN, "failed to allocate blkdev");
			return;
		}

		ret = bd_attach_handle(d->sc->dev, d->bd_h);
		if (ret != DDI_SUCCESS) {
			bd_free_handle(d->bd_h);
			d->bd_h = NULL;
			dev_err(d->sc->dev, CE_WARN, "failed to attach blkdev");
			return;
		}

		atomic_or_32(&d->ad_flags, DEVFL_UP);
		d->eport->eport_ctl(d->eport, d->master_mac,
		    AOE_CMD_PORT_UNIT_ONLINE, (void *)d->ad_unit_id);
	}
}

static void
calc_rttavg(aoedisk_t *d, unsigned int rtt)
{
	register long n;

	n = rtt;
	if (n < 0) {
		n = -((long)rtt);
		if (n < MINTIMER)
			n = MINTIMER;
		else if (n > MAXTIMER)
			n = MAXTIMER;
		d->ad_mintimer += (n - d->ad_mintimer) >> 1;
	} else if (n < d->ad_mintimer) {
		n = d->ad_mintimer;
	} else if (n > MAXTIMER) {
		n = MAXTIMER;
	}

	n -= d->ad_rttavg;
	d->ad_rttavg += n >> 2;

	/*
	 * We do not want to constantly retransmit if target
	 * is busy... bad for performance. So, give target
	 * more time would be reasonable
	 */
	if (d->ad_rttavg < MINTIMER)
		d->ad_rttavg = MINTIMER;
}

static void
aoeblk_atawc(aoedisk_t *d, void *mac)
{
	aoe_hdr_t *h;
	aoe_atahdr_t *ah;
	aoe_frame_t *af;
	aoeblk_frame_t *f;
	aoe_eport_t *eport = d->eport;

	f = allocframe(d, mac, &af, KM_NOSLEEP);
	if (f == NULL) {
		return;
	}
	h = (aoe_hdr_t *)f->frm_hdr;
	ah = (aoe_atahdr_t *)(h+1);

	/* Initialize the headers & frame. */
	f->frm_tag = (uint32_t)aoehdr_atainit(d, h);
	f->frm_waited = 0;

	/* Set up ata header. */
	ah->aa_cmdstat = (unsigned char)ATA_SETFEATURES;
	ah->aa_errfeat = aoeblk_wc ? ATA_SF_ENAB_WCACHE : ATA_SF_DIS_WCACHE;
	ah->aa_lba3 = 0xa0;

	f->frm_req = NULL;
	eport->eport_tx_frame(af);

	atomic_and_32(&d->ad_flags, ~DEVFL_WC_UPDATE);
}

static void
aoeblk_unwind(aoedisk_t *d)
{
	aoeblk_frame_t *f;

	for (f = list_head(&d->frames); f; f = list_next(&d->frames, f))
		f->frm_waited = 0;

	atomic_or_32(&d->ad_flags, DEVFL_UP);
	atomic_and_32(&d->ad_flags, ~DEVFL_CLOSEWAIT);

	/*
	 * State change will occure in rexmit timer
	 */
	atomic_or_32(&d->ad_flags, DEVFL_STATECHG);

	/* Re-enable rexmit timer */
	atomic_and_32(&d->ad_flags, ~DEVFL_TKILL);
	if (d->rexmit_timeout_id)
		d->rexmit_timeout_id = timeout(rexmit_timer, d, TIMERTICK);
}

static void
aoeblk_ataid_rsp(aoedisk_t *d, aoe_frame_t *fin, char *id)
{
	int n;

	(void *) memcpy(d->ad_ident, id, sizeof (d->ad_ident));
	for (n = 0; n < 512; n += 2) {
		unsigned char ch;
		ch = d->ad_ident[n];
		d->ad_ident[n] = d->ad_ident[n+1];
		d->ad_ident[n+1] = ch;
	}

	n = lhget16((uchar_t *)(id + (83<<1)));	/* Command set supported. */
	if (n & (1<<10)) {			/* LBA48 */
		atomic_or_32(&d->ad_flags, DEVFL_EXT);
		/* Number of LBA48 sectors */
		d->ad_nsectors = lhget32((uchar_t *)(id + (100<<1)));
	} else {
		atomic_and_32(&d->ad_flags, ~DEVFL_EXT);
		/* Number of LBA28 sectors */
		d->ad_nsectors = lhget32((uchar_t *)(id + (60<<1)));
	}

	mutex_enter(&d->ad_mutex);

	/*
	 * Use periodic discovery timer as iSCSI NOOP-style
	 * ping mechanism. We received good response for this
	 * unit path. Log it...
	 */
	d->ad_status = 0;

	if (d->ad_flags & DEVFL_CLOSEWAIT) {
		aoeblk_unwind(d);
		mutex_exit(&d->ad_mutex);
		dev_err(d->dev, CE_WARN,
		    "device %d.%d recovered and now online",
		    d->ad_major, d->ad_minor);
		return;
	}
	mutex_exit(&d->ad_mutex);

	/*
	 * Only one "master" MAC object exists per target
	 * and it is the one which responded to ATA identify.
	 */
	d->master_mac = fin->af_mac;
	atomic_or_32(&d->ad_flags, DEVFL_ATTWAIT);
}

static void
aoeblk_ata_rsp(aoeblk_softc_t *sc, aoe_frame_t *fin)
{
	aoedisk_t *d;
	aoe_hdr_t *hin = (aoe_hdr_t *)fin->af_data, *hout;
	aoe_atahdr_t *ahin, *ahout;
	unsigned long unit;
	register int tag;
	aoeblk_frame_t *fout;
	bd_xfer_t *xfer;
	xfer_private_t *x_priv = NULL;

	unit = AOEUNIT(ntohs(hin->aoeh_major), hin->aoeh_minor);

	mutex_enter(&sc->bd_mutex);
	d = aoedisk_lookup_by_unit(sc, unit);
	if (d == NULL) {
		mutex_exit(&sc->bd_mutex);
		dev_err(sc->dev, CE_WARN, "response from unknown device %d.%d",
		    ntohs(hin->aoeh_major), hin->aoeh_minor);
		return;
	}
	if (!(d->ad_flags & DEVFL_OPEN)) {
		mutex_exit(&sc->bd_mutex);
		return;
	}

	/*
	 * Target will copy original tag into reply message.
	 * We use that (obviously!) to find the right outstanding frame
	 */
	tag = ntohl(hin->aoeh_tag);
	fout = findframe(d, tag);
	if (fout == NULL) {
		mutex_exit(&sc->bd_mutex);
		calc_rttavg(d, -tsince(tag));
		sc->ks_data->sts_unsolicited_packets.value.ui64++;
		return;
	}

	hout = (aoe_hdr_t *)fout->frm_hdr;
	ahout = (aoe_atahdr_t *)(hout+1);

	xfer = fout->frm_req;
	if (xfer) {
		x_priv = xfer_priv(xfer);
		int n = ahout->aa_scnt << DEV_BSHIFT;

		if ((ahout->aa_aflags & AOEAFL_WRITE) == 0 &&
		    MBLKL(FRM2MBLK(fin)) - AOEHDRSZ < n) {
			mutex_exit(&sc->bd_mutex);
			sc->ks_data->sts_bad_xfers.value.ui64++;
			return;
		}

		if (x_priv->msgs_cnt >= x_priv->msgs_sent) {
			mutex_exit(&sc->bd_mutex);
			sc->ks_data->sts_unsolicited_xfers.value.ui64++;
			return;
		}

		atomic_inc_32(&x_priv->msgs_cnt);
	}

	fout->frm_tag = (uint32_t)INPROCTAG;
	calc_rttavg(d, tsince(tag));

	ahin = (aoe_atahdr_t *)(hin+1);
	if (ahin->aa_cmdstat & 0xa9) {	/* These bits cleared on success. */
		dev_err(d->dev, CE_WARN, "ATA error: cmd %x stat %x tag %x",
		    ahout->aa_cmdstat, ahin->aa_cmdstat, tag);
		switch (ahout->aa_cmdstat) {
		case ATA_READ:
		case ATA_READ48:
		case ATA_WRITE:
		case ATA_WRITE48:
		case ATA_FLUSHCACHE:
		case ATA_FLUSHCACHE48:
			atomic_inc_32(&x_priv->err_cnt);
			break;
		case ATA_SETFEATURES:
			break;
		default:
			;
		}
	} else {
		switch (ahout->aa_cmdstat) {
		case ATA_READ:
		case ATA_READ48:
			bcopy(((char *)hin) + AOEHDRSZ, fout->frm_kaddr,
			    fout->frm_klen);
			break;
		case ATA_WRITE:
		case ATA_WRITE48:
			break;
		case ATA_SETFEATURES:
			if (ahin->aa_errfeat & (1<<2)) {
				dev_err(sc->dev, CE_WARN,
				    "setfeatures failure for device %d.%d",
				    ntohs(hin->aoeh_major), hin->aoeh_minor);
			}
			break;
		case ATA_ATA_IDENTIFY:
			if (MBLKL(FRM2MBLK(fin)) - AOEHDRSZ < DEV_BSIZE) {
				dev_err(sc->dev, CE_WARN,
				    "ATA IDENTIFY failure for device %d.%d",
				    ntohs(hin->aoeh_major), hin->aoeh_minor);
				break;
			}
			aoeblk_ataid_rsp(d, fin, (char *)(ahin+1));
			atomic_or_32(&d->ad_flags, DEVFL_WC_UPDATE);
			break;
#if 0
		case ATA_SMART:
			/* n = m->m_len; */
			n = m->m_pkthdr.len;
			if (n > sizeof (f->f_hdr))
				n = sizeof (f->f_hdr);
			(void *) memcpy(f->f_hdr, hin, n);
			f->f_tag = INPROCTAG;
			wakeup(d);
			mtx_unlock(&d->ad_mtx);
			return;
#endif
		case ATA_FLUSHCACHE:
		case ATA_FLUSHCACHE48:
			break;
		default:
			dev_err(sc->dev, CE_WARN,
			    "unrecognized ATA command %xh from %d.%d",
			    ahout->aa_cmdstat, ntohs(hin->aoeh_major),
			    hin->aoeh_minor);
		}
	}

	if (xfer && x_priv->msgs_cnt == x_priv->msgs_sent) {
		bd_xfer_done(xfer, x_priv->err_cnt ? EIO : 0);
	}
	mutex_exit(&sc->bd_mutex);
	freeframe(d, fout);

	if (d->ad_flags & DEVFL_WC_UPDATE)
		aoeblk_atawc(d, fin->af_mac);
}

static void
aoeblk_ataid(aoedisk_t *d, void *mac)
{
	aoe_hdr_t *h;
	aoe_atahdr_t *ah;
	aoeblk_frame_t *f;
	aoe_frame_t *af;
	aoe_eport_t *eport = d->eport;

	f = allocframe(d, mac, &af, KM_NOSLEEP);
	if (f == NULL) {
		return;
	}
	h = (aoe_hdr_t *)f->frm_hdr;
	ah = (aoe_atahdr_t *)(h+1);

	/* Initialize the headers & frame. */
	f->frm_tag = (uint32_t)aoehdr_atainit(d, h);
	f->frm_waited = 0;

	/* This message initializes the device, so we reset the rttavg. */
	d->ad_rttavg = MAXTIMER;

	/* Set up ata header. */
	ah->aa_scnt = 1;
	ah->aa_cmdstat = ATA_ATA_IDENTIFY;
	ah->aa_lba3 = 0xa0;

	f->frm_req = NULL;
	eport->eport_tx_frame(af);
}

static void
aoeblk_cfg_rsp(aoeblk_softc_t *sc, aoe_frame_t *fin)
{
	aoe_hdr_t *h = (aoe_hdr_t *)fin->af_data;
	aoe_cfghdr_t *ch = (aoe_cfghdr_t *)(h+1);
	unsigned long unit;
	aoedisk_t *d;

	unit = AOEUNIT(ntohs(h->aoeh_major), h->aoeh_minor);

	mutex_enter(&sc->bd_mutex);
	d = aoedisk_lookup_by_unit(sc, unit);
	if (d && d->ad_flags & DEVFL_OPEN) {

		if (d->ad_flags & DEVFL_UP) {

			mutex_exit(&sc->bd_mutex);

			/*
			 * If this is matching shelf.slot response from
			 * the new MAC, record it as a new data path
			 */
			(void) d->eport->eport_report_unit(d->eport,
			    fin->af_mac, d->ad_unit, (char *)h->aoeh_src);

			(void) d->eport->eport_ctl(d->eport, fin->af_mac,
			    AOE_CMD_PORT_UNIT_ONLINE, (void *)d->ad_unit_id);

			d->ad_status = 0;
			return;
		}

		/*
		 * Target is still open and we just received healthy response.
		 * We will attempt to re-initialize.
		 */
		if (d->ad_flags & DEVFL_CLOSEWAIT) {
			/*
			 * Update number of max. outstanding frames
			 */
			d->ad_nframes = ntohs(ch->ac_bufcnt);
			if (d->ad_nframes > (unsigned short) aoedisk_maxframes)
				d->ad_nframes =
				    (unsigned short) aoedisk_maxframes;

			/*
			 * Update target address
			 */
			(void) d->eport->eport_report_unit(d->eport,
			    fin->af_mac, d->ad_unit, (char *)h->aoeh_src);

			mutex_exit(&sc->bd_mutex);

			d->ad_status = 0;
			goto send_ataid;
		}

		/*
		 * Skip otherwise...
		 */
		mutex_exit(&sc->bd_mutex);
		return;
	}
	mutex_exit(&sc->bd_mutex);

	/*
	 * Allocate new AoE device aoedisk
	 */
	d = kmem_zalloc(sizeof (aoedisk_t), KM_SLEEP);
	if (d == NULL) {
		dev_err(sc->dev, CE_WARN,
		    "unable create new device %lx", unit);
		return;
	}
	list_create(&d->frames, sizeof (aoeblk_frame_t),
	    offsetof(aoeblk_frame_t, frm_node));
	mutex_init(&d->ad_mutex, NULL, MUTEX_DRIVER, NULL);
	d->eport = sc->eport;
	d->sc = sc;
	d->dev = sc->dev;
	d->ad_nframes = ntohs(ch->ac_bufcnt);
	if (d->ad_nframes > (unsigned short) aoedisk_maxframes)
		d->ad_nframes = (unsigned short) aoedisk_maxframes;
	d->ad_unit = unit;
	d->ad_major = (unsigned short)AOEMAJOR(unit);
	d->ad_minor = (unsigned short)AOEMINOR(unit);

	/*
	 * Report new unit
	 */
	d->ad_unit_id = d->eport->eport_report_unit(d->eport, fin->af_mac,
	    d->ad_unit, (char *)h->aoeh_src);

	mutex_enter(&sc->bd_mutex);
	list_insert_tail(&sc->bd_list, d);
	mutex_exit(&sc->bd_mutex);

	atomic_or_32(&d->ad_flags, DEVFL_OPEN);
	atomic_and_32(&d->ad_flags, ~DEVFL_TKILL);
	d->rexmit_timeout_id = timeout(rexmit_timer, d, TIMERTICK);

send_ataid:
	/*
	 * Get nsectors, id, etc.. and initialize device
	 * on successful completion
	 */
	aoeblk_ataid(d, fin->af_mac);
}

static aoe_frame_t *
aoeblk_cfg(aoe_eport_t *eport, int mac_id, unsigned short aoemajor,
    unsigned short aoeminor)
{
	aoeblk_softc_t *sc = eport->eport_client_private;
	aoe_hdr_t *h;
	aoedisk_t *d;
	aoe_frame_t *af;
	aoeblk_frame_t *f;

	af = eport->eport_alloc_frame(eport, 0, eport->eport_mac[mac_id],
	    KM_SLEEP);
	if (af == NULL)
		return (NULL);
	f = FRM2PRIV(af);
	af->af_netb = NULL;
	if (!eport->eport_alloc_netb(af, sizeof (*h) +
	    sizeof (aoe_cfghdr_t), f->frm_hdr, KM_SLEEP)) {
		eport->eport_release_frame(af);
		return (NULL);
	}
	h = (aoe_hdr_t *)f->frm_hdr;

	(void *) memset((void *)h->aoeh_dst, 0xff, sizeof (h->aoeh_dst));
	h->aoeh_type = htons(ETHERTYPE_AOE);
	h->aoeh_verfl = AOE_HVER;
	h->aoeh_major = htons(aoemajor);
	h->aoeh_minor = (unsigned char)aoeminor;
	h->aoeh_cmd = (unsigned char)AOECMD_CFG;
	f->frm_tag = (ddi_get_lbolt() & 0xffff) | (1 << 16);
	h->aoeh_tag = htonl(f->frm_tag);

	ASSERT(MUTEX_HELD(&sc->bd_mutex));
	for (d = list_head(&sc->bd_list); d; d = list_next(&sc->bd_list, d)) {
		d->ad_status++;
	}

	eport->eport_tx_frame(af);

	return (af);
}

static inline void
put_lba(aoe_atahdr_t *ah, diskaddr_t lba)
{
	ah->aa_lba0 = (unsigned char)lba;
	ah->aa_lba1 = (unsigned char)(lba >>= 8);
	ah->aa_lba2 = (unsigned char)(lba >>= 8);
	ah->aa_lba3 = (unsigned char)(lba >>= 8);
	ah->aa_lba4 = (unsigned char)(lba >>= 8);
	ah->aa_lba5 = (unsigned char)(lba >>= 8);
}

static int
aoeblk_ata_rw(aoedisk_t *d, bd_xfer_t *xfer, int op)
{
	aoe_hdr_t *h;
	aoe_atahdr_t *ah;
	aoe_frame_t *af;
	aoeblk_frame_t *f;
	char extbit, cmd;
	int frags, kmflag;
	unsigned int msgs, i;
	xfer_private_t *x_priv = xfer_priv(xfer);
	aoe_eport_t *eport = d->eport;

	frags = eport->eport_maxxfer >> 9;

	if ((xfer->x_blkno + xfer->x_nblks) > d->ad_nsectors) {
		d->sc->ks_data->sts_rw_badoffset.value.ui64++;
		return (EINVAL);
	}

	bzero(x_priv, sizeof (*x_priv));

	kmflag = xfer->x_flags & BD_XFER_POLL ? KM_NOSLEEP : KM_SLEEP;

	/*
	 * Number of IO messages for this request
	 */
	msgs = (xfer->x_nblks + (frags - 1)) / frags;
	msgs = (msgs == 0 && op == OP_FLUSH) ? 1 : msgs;
	x_priv->msgs_sent = msgs;
	for (i = 0; i < msgs; i++) {
		int blkno, nblks;
		caddr_t kaddr;

		kaddr = xfer->x_kaddr + i * frags * DEV_BSIZE;
		nblks = frags;
		if (i == msgs - 1) {
			/*
			 * Adjust balance for the last one
			 */
			nblks = frags - (msgs * frags - xfer->x_nblks);
		}
		blkno = xfer->x_blkno + i * frags;

		/* Initialize the headers & frame. */
		f = allocframe(d, NULL, &af, kmflag);
		if (f == NULL) {
			d->sc->ks_data->sts_rw_outofmemory.value.ui64++;
			return (ENOMEM);
		}
		h = (aoe_hdr_t *)f->frm_hdr;
		ah = (aoe_atahdr_t *)(h+1);

		f->frm_tag = (uint32_t)aoehdr_atainit(d, h);
		f->frm_kaddr = kaddr;
		f->frm_klen = DEV_BSIZE * nblks;
		f->frm_waited = 0;

		/* Set up ata header. */
		ah->aa_scnt = (unsigned char)nblks;
		put_lba(ah, blkno);
		if (d->ad_flags & DEVFL_EXT) {
			ah->aa_aflags |= AOEAFL_EXT;
			extbit = 0x4;
		} else {
			extbit = 0;
			ah->aa_lba3 &= 0x0f;
			ah->aa_lba3 |= 0xe0;	/* LBA bit + obsolete 0xa0. */
		}
		if (op == OP_READ) {
			cmd = (char)ATA_READ;
		} else if (op == OP_WRITE) {
			cmd = ATA_WRITE;
			ah->aa_aflags |= AOEAFL_WRITE;
			if (!eport->eport_alloc_netb(af, f->frm_klen,
			    f->frm_kaddr, kmflag)) {
				freeframe(d, f);
				d->sc->ks_data->sts_rw_outofmemory.value.ui64++;
				return (ENOMEM);
			}
		} else { /* OP_FLUSH */
			cmd = (char)ATA_FLUSHCACHE;
			f->frm_kaddr = NULL;
			f->frm_klen = 0;
		}
		ah->aa_cmdstat = cmd | extbit;
		f->frm_req = xfer;
		eport->eport_tx_frame(af);
	}

	return (DDI_SUCCESS);
}

static int
aoeblk_read(void *arg, bd_xfer_t *xfer)
{
	return (aoeblk_ata_rw(arg, xfer, OP_READ));
}

static int
aoeblk_write(void *arg, bd_xfer_t *xfer)
{
	return (aoeblk_ata_rw(arg, xfer, OP_WRITE));
}

static int
aoeblk_flush(void *arg, bd_xfer_t *xfer)
{
	return (aoeblk_ata_rw(arg, xfer, OP_FLUSH));
}

static void
aoeblk_rsv_rsp(aoeblk_softc_t *sc, aoe_frame_t *fin)
{
	aoedisk_t *d;
	aoe_hdr_t *hin = (aoe_hdr_t *)fin->af_data;
	unsigned long unit;
	register int tag;
	aoeblk_frame_t *fout;
	int rc = 0;

	unit = AOEUNIT(ntohs(hin->aoeh_major), hin->aoeh_minor);

	mutex_enter(&sc->bd_mutex);
	d = aoedisk_lookup_by_unit(sc, unit);
	if (d == NULL) {
		mutex_exit(&sc->bd_mutex);
		return;
	}
	if (!(d->ad_flags & DEVFL_OPEN)) {
		mutex_exit(&sc->bd_mutex);
		return;
	}

	tag = ntohl(hin->aoeh_tag);
	fout = findframe(d, tag);
	if (fout == NULL) {
		mutex_exit(&sc->bd_mutex);
		sc->ks_data->sts_unsolicited_packets.value.ui64++;
		return;
	}

	if ((hin->aoeh_verfl & AOEFL_ERR) && (hin->aoeh_err == 6))
		rc = 1;	/* target is reserved */
	else
		rc = 0;	/* target is not reserved */

	fout->frm_tag = (uint32_t)INPROCTAG;
	bd_xfer_done(fout->frm_req, rc);
	mutex_exit(&sc->bd_mutex);

	mutex_enter(&d->ad_mutex);
	ASSERT(fout->frm_tag == (uint32_t)INPROCTAG);
	fout->frm_tag = (uint32_t)FREETAG;
	fout->frm_req = NULL;
	aoe_frame_t *af = PRIV2FRM(fout);
	list_remove(&d->frames, fout);
	d->eport->eport_release_frame(af);
	mutex_exit(&d->ad_mutex);
}

static int
aoeblk_reserve(void *arg, bd_xfer_t *xfer)
{
	aoedisk_t *d = (aoedisk_t *)arg;
	aoe_hdr_t *h;
	aoe_rsvhdr_t *rh;
	aoe_frame_t *af;
	aoeblk_frame_t *f;
	aoe_eport_t *eport = d->eport;
	aoeblk_softc_t *sc;
	uint8_t *addr;
	int hlen, rhlen, i;
	uint32_t free_mem = eport->cache_unit_size;

	if (xfer->x_flags & BD_XFER_POLL)
		return (EIO);

	sc = eport->eport_client_private;
	af = eport->eport_alloc_frame(eport, d->ad_unit_id, NULL, KM_SLEEP);
	if (!af)
		return (NULL);
	f = FRM2PRIV(af);
	hlen = sizeof (*h);

	if (xfer->x_flags & BD_XFER_MHD_TKOWN ||
	    xfer->x_flags & BD_XFER_MHD_QRESERVE)
		rhlen =  sizeof (*rh) +
		    (eport->eport_mac_cnt * sizeof (ether_addr_t));
	else if (xfer->x_flags & BD_XFER_MHD_RELEASE)
		rhlen =  sizeof (*rh);
	else if (xfer->x_flags & BD_XFER_MHD_STATUS)
		rhlen =  sizeof (*rh);
	else {
		eport->eport_release_frame(af);
		return (NULL);
	}
	af->af_netb = NULL;
	if (!eport->eport_alloc_netb(af, hlen + rhlen, f->frm_hdr, KM_SLEEP)) {
		eport->eport_release_frame(af);
		return (NULL);
	}
	free_mem -= hlen + rhlen;

	h = (aoe_hdr_t *)f->frm_hdr;
	f->frm_tag = newtag(d);
	f->frm_req = xfer;
	f->frm_kaddr = xfer->x_kaddr;
	f->frm_klen = 0;
	f->frm_waited = 0;

	h->aoeh_type = htons(ETHERTYPE_AOE);
	h->aoeh_verfl = AOE_HVER;
	h->aoeh_major = htons(d->ad_major);
	h->aoeh_minor = d->ad_minor;
	h->aoeh_cmd = (unsigned char)AOECMD_RSV;
	h->aoeh_tag = htonl(f->frm_tag);

	rh = (aoe_rsvhdr_t *)(h+1);
	if (xfer->x_flags & BD_XFER_MHD_TKOWN ||
	    xfer->x_flags & BD_XFER_MHD_QRESERVE) {
		rh->al_rcmd = AOE_RCMD_SET_LIST;
		rh->al_nmacs = sc->eport->eport_mac_cnt;
		for (i = 0; i < eport->eport_mac_cnt; i++) {
			if (free_mem < sizeof (ether_addr_t))
				goto buffer_overflow;
			addr = eport->eport_get_mac_addr(eport->eport_mac[i]);
			bcopy(addr, rh->al_addr[i], sizeof (ether_addr_t));
		}
	} else if (xfer->x_flags & BD_XFER_MHD_RELEASE) {
		rh->al_rcmd = AOE_RCMD_SET_LIST;
		rh->al_nmacs = 0;
	} else if (xfer->x_flags & BD_XFER_MHD_STATUS) {
		rh->al_rcmd = AOE_RCMD_READ_LIST;
		rh->al_nmacs = 0;
	}

	f->frm_req = xfer;

	mutex_enter(&d->ad_mutex);
	list_insert_tail(&d->frames, f);
	mutex_exit(&d->ad_mutex);

	eport->eport_tx_frame(af);

	return (DDI_SUCCESS);

buffer_overflow:
	eport->eport_free_netb(af->af_netb);
	eport->eport_release_frame(af);
	return (DDI_FAILURE);
}

/* ARGSUSED ksp */
static int
aoeblk_ksupdate(kstat_t *ksp, int rw)
{
	aoeblk_stats_t *ks = ksp->ks_data;
	aoeblk_softc_t *sc = ksp->ks_private;
	aoeblk_stats_t *ns = sc->sc_intrstat->ks_data;

	if (rw != KSTAT_READ)
		return (EACCES);

	ks->sts_rw_outofmemory = ns->sts_rw_outofmemory;
	ks->sts_rw_badoffset = ns->sts_rw_badoffset;
	ks->sts_error_packets = ns->sts_error_packets;
	ks->sts_unsolicited_packets = ns->sts_unsolicited_packets;
	ks->sts_unsolicited_xfers = ns->sts_unsolicited_xfers;
	ks->sts_bad_xfers = ns->sts_bad_xfers;
	ks->sts_rexmit_packets = ns->sts_rexmit_packets;

	return (0);
}

static void
aoeblk_rx_frame(aoe_frame_t *fin)
{
	aoe_hdr_t *h = (aoe_hdr_t *)fin->af_data;
	aoeblk_softc_t *sc = fin->af_eport->eport_client_private;
	uint32_t n;

	n = ntohl(h->aoeh_tag);
	if ((h->aoeh_verfl & AOEFL_RSP) == 0 || (n & ((uint32_t)1)<<31)) {
		char bcast_addr[sizeof (ether_addr_t)] = {
			    (char)0xff, (char)0xff, (char)0xff,
			    (char)0xff, (char)0xff, (char)0xff };
		if (bcmp(h->aoeh_dst, bcast_addr, sizeof (ether_addr_t)) != 0) {
			dev_err(sc->dev, CE_WARN,
			    "unsupported AoE frame with verfl %d tag %d cmd %d "
			    "error packet from %d.%d", h->aoeh_verfl, n,
			    h->aoeh_cmd, ntohs(h->aoeh_major), h->aoeh_minor);
		}
		goto release_exit;
	}

	if (h->aoeh_verfl & AOEFL_ERR) {
		n = h->aoeh_err;
		if (n > NECODES)
			n = 0;
		dev_err(sc->dev, CE_WARN,
		    "error packet from %d.%d; ecode=%d '%s'\n",
		    ntohs(h->aoeh_major), h->aoeh_minor,
		    h->aoeh_err, aoe_errlist[n]);
		sc->ks_data->sts_error_packets.value.ui64++;
		goto release_exit;
	}

	switch (h->aoeh_cmd) {
	case AOECMD_ATA:
		aoeblk_ata_rsp(sc, fin);
		break;
	case AOECMD_CFG:
		aoeblk_cfg_rsp(sc, fin);
		break;
	case AOECMD_RSV:
		aoeblk_rsv_rsp(sc, fin);
		break;
	default:
		dev_err(sc->dev, CE_WARN,
		    "unknown cmd %d\n", h->aoeh_cmd);
	}

release_exit:
	sc->eport->eport_free_netb(fin->af_netb);
	sc->eport->eport_release_frame(fin);
}

static void
aoeblk_port_event(aoe_eport_t *eport, uint32_t event)
{
	aoeblk_softc_t *sc = eport->eport_client_private;
	aoedisk_t *d;

	mutex_enter(&sc->bd_mutex);

	for (d = list_head(&sc->bd_list); d; d = list_next(&sc->bd_list, d)) {
		mutex_enter(&d->ad_mutex);
		switch (event) {
		case AOE_NOTIFY_EPORT_LINK_UP:
			aoeblk_unwind(d);
			break;
		case AOE_NOTIFY_EPORT_LINK_DOWN:
			aoeblk_downdisk(d, NULL, 0);
			break;
		default:
			;
		}
		mutex_exit(&d->ad_mutex);
	}

	mutex_exit(&sc->bd_mutex);
}

void
aoeblk_discover(void *arg)
{
	aoeblk_softc_t *sc = arg;
	aoedisk_t *d;
	int i;

	mutex_enter(&sc->bd_mutex);
	if (sc->discovery_timeout_id == 0) {
		mutex_exit(&sc->bd_mutex);
		return;
	}
	for (d = list_head(&sc->bd_list); d; d = list_next(&sc->bd_list, d)) {
		/*
		 * Non-zero ad_status means error, unit not responding
		 * and all paths offline, speed up unit failure.
		 */
		mutex_enter(&d->ad_mutex);
		if (d->ad_status >= 3 && d->ad_flags & DEVFL_UP) {
			aoeblk_downdisk(d, NULL, 1);
			dev_err(d->dev, CE_WARN, "device %d.%d is not "
			    "responding to ping discovery, in-recovery now",
			    d->ad_major, d->ad_minor);
		}
		mutex_exit(&d->ad_mutex);
	}
	for (i = 0; i < sc->eport->eport_mac_cnt; i++) {
		if (sc->bcast_f[i])
			sc->eport->eport_release_frame(sc->bcast_f[i]);
		sc->bcast_f[i] = aoeblk_cfg(sc->eport, i, 0xffff, 0xff);

		/*
		 * A bit of a delay between discovery requests would help
		 * to align targets for this port into arrays of active
		 * targets with matching shelf.slot.
		 */
		delay(1);
	}
	sc->discovery_timeout_id = timeout(aoeblk_discover, sc,
	    drv_usectohz(DISCTIMER*1000000));
	mutex_exit(&sc->bd_mutex);
}

static int
aoeblk_attach(dev_info_t *dip, ddi_attach_cmd_t cmd)
{
	int ret;
	aoeblk_softc_t *sc;
	aoeblk_stats_t *ks_data;
	aoe_client_t client;

	switch (cmd) {
	case DDI_ATTACH:
		break;

	case DDI_RESUME:
	case DDI_PM_RESUME:
		return (DDI_SUCCESS);

	default:
		dev_err(dip, CE_WARN, "cmd 0x%x not recognized", cmd);
		ret = DDI_FAILURE;
		goto exit;
	}

	sc = kmem_zalloc(sizeof (aoeblk_softc_t), KM_SLEEP);
	if (sc == NULL) {
		dev_err(dip, CE_WARN, "Cannot allocate softc memory");
		ret = DDI_FAILURE;
		goto exit;
	}
	ddi_set_driver_private(dip, sc);
	sc->dev = dip;

	/*
	 * This should not normally fail, since we don't use a persistent
	 * stat. We do it this way to avoid having to test for it at run
	 * time on the hot path.
	 */
	sc->sc_intrstat = kstat_create("aoeblk", ddi_get_instance(dip),
	    "intrs", "controller", KSTAT_TYPE_NAMED,
	    sizeof (aoeblk_stats_t) / sizeof (kstat_named_t),
	    KSTAT_FLAG_PERSISTENT);
	if (sc->sc_intrstat == NULL) {
		dev_err(dip, CE_WARN, "kstat_create failed");
		ret = DDI_FAILURE;
		goto exit_intrstat;
	}
	ks_data = (aoeblk_stats_t *)sc->sc_intrstat->ks_data;
	kstat_named_init(&ks_data->sts_rw_outofmemory,
	    "total_rw_outofmemory", KSTAT_DATA_UINT64);
	kstat_named_init(&ks_data->sts_rw_badoffset,
	    "total_rw_badoffset", KSTAT_DATA_UINT64);
	kstat_named_init(&ks_data->sts_error_packets,
	    "total_error_packets", KSTAT_DATA_UINT64);
	kstat_named_init(&ks_data->sts_unsolicited_packets,
	    "total_unsolicited_packets", KSTAT_DATA_UINT64);
	kstat_named_init(&ks_data->sts_unsolicited_xfers,
	    "total_unsolicited_xfers", KSTAT_DATA_UINT64);
	kstat_named_init(&ks_data->sts_bad_xfers,
	    "total_bad_xfers", KSTAT_DATA_UINT64);
	kstat_named_init(&ks_data->sts_rexmit_packets,
	    "total_rexmit_packets", KSTAT_DATA_UINT64);
	sc->ks_data = ks_data;
	sc->sc_intrstat->ks_private = sc;
	sc->sc_intrstat->ks_update = aoeblk_ksupdate;
	kstat_install(sc->sc_intrstat);

	/*
	 * Port driver supplies mac_id which is unique per mac (port).
	 * We are using it to identify "channel" via channelid below.
	 */
	ret = ddi_prop_get_int(DDI_DEV_T_ANY, dip,
	    DDI_PROP_DONTPASS | DDI_PROP_NOTPROM, "port_id", -1);
	if (ret == -1) {
		dev_err(dip, CE_WARN, "get port_id failed");
		goto exit_prop_get;
	}

	/*
	 * Get the configured maximum number of outstanding frames.
	 */
	aoedisk_maxframes = ddi_prop_get_int(DDI_DEV_T_ANY, dip,
	    DDI_PROP_DONTPASS | DDI_PROP_NOTPROM, "disk-max-frames",
	    AOEDISK_MAXFRAMES);

	client.ect_channelid = ret;
	client.ect_eport_flags = EPORT_FLAG_INI_MODE;
	client.ect_rx_frame = aoeblk_rx_frame;
	client.ect_port_event = aoeblk_port_event;
	client.ect_private_frame_struct_size = sizeof (aoeblk_frame_t);
	client.ect_client_port_struct = sc;
	sc->eport = aoe_register_client(&client);
	if (sc->eport == NULL) {
		dev_err(dip, CE_WARN, "AoE client registration failed");
		ret = DDI_FAILURE;
		goto exit_eport;
	}

	mutex_init(&sc->bd_mutex, NULL, MUTEX_DRIVER, NULL);
	list_create(&sc->bd_list, sizeof (aoedisk_t),
	    offsetof(aoedisk_t, node));

	/*
	 * This will activate RX path
	 */
	sc->eport->eport_ctl(sc->eport, NULL, AOE_CMD_PORT_ONLINE, NULL);

	sc->discovery_timeout_id = timeout(aoeblk_discover, sc,
	    drv_usectohz(1*1000000));

	return (DDI_SUCCESS);

exit_eport:
exit_prop_get:
	kstat_delete(sc->sc_intrstat);
exit_intrstat:
	kmem_free(sc, sizeof (aoeblk_softc_t));
exit:
	return (ret);
}

static int
aoeblk_detach(dev_info_t *dip, ddi_detach_cmd_t cmd)
{
	aoeblk_softc_t *sc = ddi_get_driver_private(dip);
	aoedisk_t *d;
	int i;

	switch (cmd) {
	case DDI_DETACH:
		break;

	case DDI_SUSPEND:
	case DDI_PM_SUSPEND:
		return (DDI_SUCCESS);

	default:
		dev_err(dip, CE_WARN, "cmd 0x%x unrecognized", cmd);
		return (DDI_FAILURE);
	}

	mutex_enter(&sc->bd_mutex);

	if (sc->discovery_timeout_id != 0) {
		while (untimeout(sc->discovery_timeout_id) == -1)
			;
		sc->discovery_timeout_id = 0;
	}

	for (i = 0; i < sc->eport->eport_mac_cnt; i++) {
		if (sc->bcast_f[i])
			sc->eport->eport_release_frame(sc->bcast_f[i]);
	}

	while (!list_empty(&sc->bd_list)) {
		d = list_head(&sc->bd_list);

		mutex_enter(&d->ad_mutex);
		atomic_and_32(&d->ad_flags, ~DEVFL_OPEN);

		aoeblk_downdisk(d, NULL, 0);

		if (d->rexmit_timeout_id != 0) {
			(void) untimeout(d->rexmit_timeout_id);
			d->rexmit_timeout_id = 0;
		}

		while (!list_empty(&d->frames)) {
			aoeblk_frame_t *f = list_head(&d->frames);
			aoe_frame_t *af = PRIV2FRM(f);
			list_remove(&d->frames, f);
			d->eport->eport_release_frame(af);
		}

		mutex_exit(&d->ad_mutex);

		list_remove(&sc->bd_list, d);
		kmem_free(d, sizeof (aoedisk_t));
	}

	mutex_exit(&sc->bd_mutex);

	sc->eport->eport_deregister_client(sc->eport);

	/* Note: we let aoe driver to detach us */
	kstat_delete(sc->sc_intrstat);
	kmem_free(sc, sizeof (aoeblk_softc_t));

	return (DDI_SUCCESS);
}

int
_init(void)
{
	int	rv;

	bd_mod_init(&aoeblk_dev_ops);

	if ((rv = mod_install(&modlinkage)) != 0) {
		bd_mod_fini(&aoeblk_dev_ops);
	}

	return (rv);
}

int
_fini(void)
{
	int	rv;

	if ((rv = mod_remove(&modlinkage)) == 0) {
		bd_mod_fini(&aoeblk_dev_ops);
	}

	return (rv);
}

int
_info(struct modinfo *modinfop)
{

	return (mod_info(&modlinkage, modinfop));
}

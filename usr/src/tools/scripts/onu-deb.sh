#!/bin/ksh93
#
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#
#
# Copyright 2014 Nexenta Systems, Inc. All rights reserved.
#
# Version 2.1

typeset REPODIR=
typeset TARGETBE=
typeset TARGETMOUNT=
typeset FULLPATH=
typeset DEBPKGS=
typeset -i PKGNUM=0
typeset -i CONSOLE=0

typeset TMPDIR=/tmp/apt.$$
typeset LOG=/root/upgrade.log.$$

AWK=/usr/bin/awk
BEADM=/usr/sbin/beadm
MKDIR=/usr/bin/mkdir
BOOTADM=/usr/sbin/bootadm
ECHO=/usr/bin/echo
CAT=/usr/bin/cat
CP=/usr/bin/cp
GREP=/usr/bin/grep
MV=/usr/bin/mv
APTGET=/usr/bin/apt-get
TOUCH=/usr/bin/touch
SED=/usr/bin/sed

usage()
{
	${ECHO} "Usage:"
	${ECHO} "	$0 -t [BE name] -d [path to local APT] [-v]"
	${ECHO}
	${ECHO} "Example:"
	${ECHO} "	$0 -t rootfs-nmu-\`date +%Y-%m-%d\` -d \$PWD/packages/i386/apt"
	exit 0
}

logcmd() {
	if (( CONSOLE == 0 )); then
		${ECHO} CMD: "$@" >> ${LOG}
		"$@" >> ${LOG} 2>&1
	else
		${ECHO} CMD: "$@" | tee ${LOG}
		"$@" | tee ${LOG} 2>&1
	fi
}

logmsg() {
	${ECHO} "$@" >> ${LOG}
	${ECHO} "$@"
}

logerr() {
	logmsg $@
	exit 1
}

logerrdie() {
	logmsg $@
	fullabort
}

fullabort() {
	logmsg "\nAborting. See ${LOG} for details\n"
	${ECHO} yes | ${BEADM} destroy -f ${TARGETBE} >/dev/null 2>&1
	exit 1
}

get_clones_dev()
{
    typeset TMP=$1
    typeset CLONEPKGS
    DEVPKGS=$(ls ${TMP}/var/lib/dpkg/info/*.postinst)
    for DEVPKG in $DEVPKGS
    do
	CLONE=$(cat ${DEVPKG} | ${GREP} update_drv | ${GREP} clone | wc -l)
	if [[ ${CLONE} > 0 ]]; then
		DEVPKG=$(basename ${DEVPKG} | ${SED} -e 's/\..*$//')
		CLONEPKGS="${CLONEPKGS} ${DEVPKG}"
	fi
    done
    echo ${CLONEPKGS}
}

rm_package_name()
{
    typeset RPKG=$1
    shift
    typeset RPKGS=$*
    typeset FOUND=
    for p in ${RPKGS}
    do
	if [[ ${p} != ${RPKG} ]]; then
		FOUND="${FOUND} $p"
	fi
    done
    echo ${FOUND}
}


###### main ######

while getopts :d:t:v i ; do
	case $i in
	d)
		REPODIR="${OPTARG}"
		;;
	t)
		TARGETBE="${OPTARG}"
		;;
	v)
		CONSOLE=1
		;;
	*)
		usage >&2
	esac
done
shift $((OPTIND - 1))

if (( $# != 0 )); then
        usage >&2
fi

[[ -z "${TARGETBE}" ]] && usage >&2
[[ -z "${REPODIR}" ]] && usage >&2

FULLPATH=$(echo ${REPODIR} | ${GREP} '^\/')

if [[ -z "${FULLPATH}" ]]; then
	logerr "Please use full path for -d option"
fi

if [[ ! -f ${REPODIR}/conf/distributions ]]; then
	logerr "Local APT unavailable, please check your path to repo dir: '${REPODIR}'"
fi

${ECHO} "$(basename $0) started at $(date)" > $LOG

logmsg "===== Creating BE ${TARGETBE}"
logcmd ${MKDIR} -p ${TMPDIR}
logcmd ${BEADM} create ${TARGETBE} || logerr "Cannot create BE"
logcmd ${BEADM} mount ${TARGETBE} ${TMPDIR} || legerrdie "Cannot mount BE"

logmsg "===== Setting apt sources"
logcmd ${CP} /etc/apt/sources.list /etc/apt/sources.list.saved || logerrdie "Can't save apt sources"
${ECHO} "deb file://${REPODIR} nza-kernel main" > /etc/apt/sources.list || logerrdie "Can't apply local apt url to sources"
logcmd ${CP} -f /etc/apt/sources.list ${TMPDIR}/etc/apt/sources.list || logerrdie "Can't copy new apt sources to ${TMPDIR}"

export APT_CLONE_ENV=1

logcmd ${APTGET} -R ${TMPDIR} update

PKGNUM=$(${APTGET} -R ${TMPDIR} -s upgrade | ${AWK} '/[0-9]+ upgraded,/{print $1 }')

if (( PKGNUM == 0 )); then
	logerrdie "Nothing to upgrade. Do you want to bump DEB_VERSION?"
fi

logmsg "===== Installing packages"
logcmd ${APTGET} -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -R ${TMPDIR} install -y --force-yes sunwcsd || logerrdie "Failed to install sunwcsd"
logcmd ${APTGET} -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -R ${TMPDIR} install -y --force-yes sunwcs || logerrdie "Failed to install sunwcs"
logcmd ${APTGET} -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -R ${TMPDIR} install -y --force-yes system-kernel || logerrdie "Failed to install system-kernel"
logcmd ${APTGET} -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -R ${TMPDIR} dist-upgrade -y --force-yes || logerrdie "Failed to install kernel packages"

logmsg "===== Reconfiguring drivers"
CLONEPKGS=$(get_clones_dev ${TMPDIR})
CLONEPKGS=$(rm_package_name "system-kernel" ${CLONEPKGS})
for CLONPKG in $CLONEPKGS
do
    DEBPKGS=$(rm_package_name ${CLONPKG} ${DEBPKGS})
done
DEBPKGS=$(rm_package_name "system-kernel" ${DEBPKGS})
DEBPKGS="system-kernel ${CLONEPKGS} ${DEBPKGS}"

for DEBPKG in ${DEBPKGS}
do
    [[ -f ${TMPDIR}/var/lib/dpkg/info/${DEBPKG}.prerm ]] && ( BASEDIR=${TMPDIR} ${TMPDIR}/var/lib/dpkg/info/${DEBPKG}.prerm upgrade >/dev/null 2>&1 )
    [[ -f ${TMPDIR}/var/lib/dpkg/info/${DEBPKG}.postinst ]] && ( BASEDIR=${TMPDIR} ${TMPDIR}/var/lib/dpkg/info/${DEBPKG}.postinst configure >/dev/null 2>&1 )
done

logmsg "===== Updating boot_archive and activating BE"
logcmd ${BOOTADM} update-archive -R ${TMPDIR} || logerrdie "Can't update boot_archive"
logcmd ${TOUCH} ${TMPDIR}/reconfigure

logcmd ${CP} /etc/apt/sources.list.saved /etc/apt/sources.list
logcmd ${CP} -f /etc/apt/sources.list ${TMPDIR}/etc/apt/sources.list

logcmd ${BEADM} umount ${TARGETBE}
logcmd ${BEADM} activate ${TARGETBE}

${CAT}<<-EOF

                          * * *
                      SYSTEM NOTICE

     The upgrade has completed successfully:
       - created new BE '${TARGETBE}'
       - created new GRUB menu entry
       - upgrade log saved to '$LOG'
       - the system is ready to reboot into the new BE

   +------------------------------------------------------------------+
   |                                                                  |
   |  At this point you have two options:                             |
   |                                                                  |
   |   1. You can reboot now, make sure that system is healthy.       |
   |                                                                  |
   |   2. Or, you can simply continue using the system as is and      |
   |      reboot to new BE later.                                     |
   |                                                                  |
   +------------------------------------------------------------------+
EOF

${ECHO} "$(basename $0) finished at $(date)" >> $LOG

exit 0

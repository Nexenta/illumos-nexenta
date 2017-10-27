#!/bin/ksh -p
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License, Version 1.0 only
# (the "License").  You may not use this file except in compliance
# with the License.
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
# Copyright 2011-2012 OmniTI Computer Consulting, Inc.  All rights reserved.
# Use is subject to license terms.
# Copyright 2015 Nexenta Systems, Inc. All rights reserved.

# system-unconfigure: removes system-specific configuration, preparing the
#   newly-cloned zone for use.  It is similar to sys-unconfig, but designed
#   only for use with zone cloning.

SED=/usr/bin/sed

bomb() {
  echo ======================================================
  echo "$*"
  echo ======================================================
  exit 1
}

while getopts "R:" opt; do
  case $opt in
    R)
      ALTROOT=$OPTARG
      if [[ -z "$ALTROOT" ]]; then
        bomb "Missing argument to option -R"
        exit 254
      fi
      ;;
  esac
done

blank_root_pw() {
  echo "--- Setting root's password to blank"
  cat $ALTROOT/etc/shadow | $SED -e 's%^root:[^:]*:%root:$5$kr1VgdIt$OUiUAyZCDogH/uaxH71rMeQxvpDEY2yX.x0ZQRnmeb9:%' > $ALTROOT/etc/shadow.blankroot
  mv $ALTROOT/etc/shadow.blankroot $ALTROOT/etc/shadow || \
    bomb "Failed to place modified $ALTROOT/etc/shadow"
}

clear_logs() {
  echo "--- Emptying log files"
  rm -f $ALTROOT/var/adm/messages.*
  rm -f $ALTROOT/var/log/syslog.*
  cat /dev/null > $ALTROOT/var/adm/messages
  cat /dev/null > $ALTROOT/var/log/syslog
}

disable_ldap() {
  echo "--- Disabling any LDAP configuration"
  rm -f $ALTROOT/var/ldap/ldap_client_cache
  rm -f $ALTROOT/var/ldap/ldap_client_cred
  rm -f $ALTROOT/var/ldap/ldap_client_file
  rm -f $ALTROOT/var/ldap/cachemgr.log
  # Trickery to twiddle service configs in the altroot
  # This was helpful: http://alexeremin.blogspot.com/2008/12/preparing-small-miniroot-with-zfs-and.html
  ROOTDIR=$ALTROOT
  SVCCFG_DTD=${ROOTDIR}/usr/share/lib/xml/dtd/service_bundle.dtd.1
  SVCCFG_REPOSITORY=${ROOTDIR}/etc/svc/repository.db
  SVCCFG=${ROOTDIR}/usr/sbin/svccfg
  export ROOTDIR SVCCFG_DTD SVCCFG_REPOSITORY SVCCFG
  $SVCCFG -s "network/ldap/client:default" setprop general/enabled=false
  return 0
}

reset_hosts() {
  if [[ -f $ALTROOT/etc/inet/hosts ]]; then
    echo "--- Resetting hosts file"
    cat > $ALTROOT/etc/inet/hosts.reset <<'EOF'
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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# Internet host table
#
::1		localhost
127.0.0.1	localhost loghost
EOF
    chmod 0644 $ALTROOT/etc/inet/hosts.reset
    mv $ALTROOT/etc/inet/hosts.reset $ALTROOT/etc/inet/hosts || \
      bomb "Failed to reset $ALTROOT/etc/inet/hosts"
fi
}

reset_init_default() {
  echo "--- Resetting init defaults"
  $SED -e 's/^TZ.*/TZ=UTC/' -i $ALTROOT/etc/default/init || \
    bomb "Failed to reset TZ in $ALTROOT/etc/default/init"
}

reset_networking() {
  echo "--- Removing network configuration files"
  rm -f $ALTROOT/etc/hostname.*
  rm -f $ALTROOT/etc/defaultdomain
  rm -f $ALTROOT/etc/defaultrouter
  rm -f $ALTROOT/etc/nodename
  rm -f $ALTROOT/etc/resolv.conf
  rm -f $ALTROOT/etc/inet/netmasks
  rm -f $ALTROOT/etc/inet/static_routes
  for file in $ALTROOT/etc/ipadm/*\.conf $ALTROOT/etc/dladm/*\.conf ; do
	if [ -f "$file" ]; then
		cp /dev/null "$file" || \
		    bomb "Failed to blank $ALTROOT/$file"
	fi
  done
}

reset_nsswitch() {
  echo "--- Resetting nsswitch.conf"
  cat > $ALTROOT/etc/nsswitch.conf.reset <<'EOF'
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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

#
# /etc/nsswitch.conf:
#
# "hosts:" and "services:" in this file are used only if the
# /etc/netconfig file has a "-" for nametoaddr_libs of "inet" transports.

passwd:     files
group:      files
hosts:      files
ipnodes:    files
networks:   files
protocols:  files
rpc:        files
ethers:     files
netmasks:   files
bootparams: files
publickey:  files
# At present there isn't a 'files' backend for netgroup;  the system will 
#   figure it out pretty quickly, and won't use netgroups at all.
netgroup:   files
automount:  files
aliases:    files
services:   files
printers:   user files

auth_attr:  files
prof_attr:  files
project:    files

tnrhtp:     files
tnrhdb:     files
EOF
  chmod 0644 $ALTROOT/etc/nsswitch.conf.reset
  mv $ALTROOT/etc/nsswitch.conf.reset $ALTROOT/etc/nsswitch.conf || \
    bomb "Failed to reset $ALTROOT/etc/nsswitch.conf"
}

reset_ssh_config() {
  echo "--- Resetting ssh configs"
  echo "------ Resetting PermitRootLogin to no"
  $SED -i -e 's%^PermitRootLogin.*$%PermitRootLogin no%' $ALTROOT/etc/ssh/sshd_config || \
    bomb "Failed to update PermitRootLogin in $ALTROOT/etc/ssh/sshd_config"
  echo "------ Generating new ssh host keys"
  for algo in rsa dsa; do
    mv $ALTROOT/etc/ssh/ssh_host_${algo}_key $ALTROOT/etc/ssh/ssh_host_${algo}_key.old
    mv $ALTROOT/etc/ssh/ssh_host_${algo}_key.pub $ALTROOT/etc/ssh/ssh_host_${algo}_key.pub.old
  done
  /usr/bin/ssh-keygen -q -t rsa -b 2048 -N '' -C root@unknown -f $ALTROOT/etc/ssh/ssh_host_rsa_key || \
    bomb "Failed to create new RSA host key $ALTROOT/etc/ssh/ssh_host_rsa_key"
  /usr/bin/ssh-keygen -q -t dsa -N '' -C root@unknown -f $ALTROOT/etc/ssh/ssh_host_dsa_key || \
    bomb "Failed to create new DSA host key $ALTROOT/etc/ssh/ssh_host_dsa_key"
  rm -f $ALTROOT/etc/ssh/ssh_host_*.old || \
    bomb "Failed to remove old key files"
}

reset_vfstab() {
  echo "--- Resetting vfstab"
  cat > $ALTROOT/etc/vfstab.reset <<'EOF'
#device		device		mount		FS	fsck	mount	mount
#to mount	to fsck		point		type	pass	at boot	options
#
/devices	-		/devices	devfs	-	no	-
/proc		-		/proc		proc	-	no	-
ctfs		-		/system/contract ctfs	-	no	-
objfs		-		/system/object	objfs	-	no	-
sharefs		-		/etc/dfs/sharetab	sharefs	-	no	-
fd		-		/dev/fd		fd	-	no	-
swap		-		/tmp		tmpfs	-	yes	-
EOF
  chmod 0644 $ALTROOT/etc/vfstab.reset
  mv $ALTROOT/etc/vfstab.reset $ALTROOT/etc/vfstab || \
    bomb "Failed to reset $ALTROOT/etc/vfstab"
}

# Do the things
reset_hosts
reset_vfstab
reset_networking
reset_init_default
blank_root_pw
clear_logs
disable_ldap
reset_ssh_config

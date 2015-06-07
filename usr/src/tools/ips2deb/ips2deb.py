#! /usr/bin/python2.6
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
# Copyright 2014 Nexenta Systems, Inc.  All rights reserved.
#

#
# Convert an ips manifest into Debian package source files.
#

import optparse
import sys

from pkg.manifest import Manifest
from pkg.fmri import PkgFmri, IllegalFmri
from os import makedirs, chown, chmod, listdir
from os.path import join, basename, dirname, exists, realpath
from shutil import rmtree, copyfile
from time import strftime
from pwd import getpwnam
from grp import getgrnam

# 
# These packages depend on sunwcs in our debian world, but this isn't 
# reflected in the manifests provided. This signifies the dependency.
# TODO: Pull into conffile?
#
spec = {'system-file-system-zfs':1,
        'system-file-system-zfs-tests':1,
        'system-file-system-udfs':1,
        'system-floating-point-scrubber':1,
        'system-tnf':1,
        'diagnostic-cpu-counters':1,
        'driver-network-eri':1,
        'compatibility-ucb':1,
        'diagnostic-powertop':1,
        'diagnostic-latencytop':1,
        'network-ipfilter':1,
        'developer-debug-mdb':1,
        'system-extended-system-utilities':1,
        'storage-library-network-array':1,
        'service-resource-cap':1,
        'developer-linker':1,
        'developer-dtrace':1,
        'driver-network-eri':1}

# 
# These packages will be ignored.
# TODO: Debian meta packages for consolidations?
#
ign = {'consolidation-osnet-osnet-message-files':1,
       'consolidation-osnet-osnet-incorporation':1,
       'consolidation-osnet-osnet-redist':1}

drep, dver, dpri = {}, {}, {}
#
# TODO: Is this better as a single def or a class?
# If this expands to do an any-all-or-none style build, it would probably 
# be better suited as a class definition.
#
class IPSConvert:
    """class for converting from ips packages"""
    def __init__(self, ips, args):

        self.dir = dirname(ips)
        self.name = basename(ips).split('.', 1)[0]
        self.args = args
        
        #
        # Suck the manifest into a class structure for parsing
        #
        self.mf = Manifest()
        self.mf.set_content(pathname=ips)
        
        self.depends = ['${shlibs:Depends}', '${misc:Depends}']
        self.post = [] # Holds str lines for pkgname.postinst
        self.pre = [] # '' pkgname.preinst
        self.rm = [] # '' pkgname.prerm
        self.fix = [] # '' pkgname.fixperms
        self.svc = {}

        pfmri = self.mf.get('pkg.fmri', None)
        self.pkgfmri = PkgFmri(pfmri) if pfmri else None
        self.pkgname = None
        self.process = False

        # Debian attrs (for pylint)
        self.origname = None
        self.rep = None
        self.pri = None
        self.wd = None
        self.ver = None
        self.arch = None
        self.origver = None           

    def initdebpkg(self):
        """Initialize the object for conversion to Debian format"""
        
        #
        # Some packages won't have fmri attributes. Old code skipped them, so we
        # will, too.
        #

        if not self.pkgfmri:
            if self.args.v:
                print "%s: No fmri attribute found. Skipping." % (self.name)
            return False

        #
        # We get our package names from the pkg.fmri attribute after
        # a little post processing
        #
        self.pkgname = self.pkgfmri.pkg_name.replace('/','-').replace('_','-') \
            .lower()
 
        #
        # This is mostly taken straight from the perl code.
        # There, we skipped any obsoleted or renamed packages, consolidations,
        # or packages we specifically mark to be ignored.
        #
        if self.mf.get('pkg.obsolete', None):
            if self.args.v:
                print "%s: Package is obsolete. Ignoring." % (self.pkgname)
            return
        elif 'consolidation' in self.pkgname:
            if self.args.v:
                print "%s: Package is a consolidation. Ignoring." \
                    % (self.pkgname)
            return
        elif ign.get(self.pkgname):
            if self.args.v:
                print "%s: Package is marked to be ignored." % (self.pkgname)
            return

        if self.mf.get('pkg.renamed', None):
            for rdep in self.mf.gen_actions_by_type('depend'):
                try:
                    repfmri = PkgFmri(rdep.attrs.get('fmri'))
                except(IllegalFmri) as err:
                    if 'build version' in str(err):
                        repfmri = PkgFmri(rdep.attrs.get('fmri').split('@')[0])
                    else:
                        raise
                rname = repfmri.pkg_name.replace('/','-') \
                    .replace('_','-').lower()
                if rname == "consolidation-osnet-osnet-incorporation":
                    continue
                reps = drep.get(rname) or []
                if self.pkgname not in reps:
                    reps.append(self.pkgname)
                    drep[rname] = reps

            return

        self.process = True

    def gendebpkg(self):
        """Generate a debian style package source from an ips manifest"""
 
        #
        # origver is XBS-ORIGINAL-VERSION, taken from part of 
        # the fmri's version string. 
        # origname is the debian "Provides" field. It comes from
        # everything after the last '/' in the fmri.
        #
        self.origver = self.args.origver or str(self.pkgfmri.version.release)
        self.origname = self.pkgfmri.pkg_name.rsplit('/', 1)[-1].lower()

        self.arch = self.mf.get('variant.arch', None)
        if (type(self.arch) == list and len(self.arch) != 0):
            self.arch = self.arch[0]
        self.arch = 'solaris-%s' % (self.arch or 'i386')

        #
        # Get the debian Replaces, Priorities, and Version fields, either from
        # CLI or ips2deb conf files.
        #
        self.rep = self.args.rep or ', '.join(drep.get(self.pkgname) or [])
        self.pri = self.args.pri or dpri.get(self.pkgname, [''])[0]
        self.ver = self.args.ver or dver.get(self.pkgname, [''])[0]

        # Dependencies
        
        #
        # Some packages were set to be dependent on sunwcs, even though it's not
        # directly listed in the manifest. We replicate that behavior. here.
        # There's other extra behavior when we generate sunwcs later on.
        # TODO: perhaps find a better way to handle this.
        #
        if self.args.spec or spec.get(self.pkgname):
            self.depends.append('sunwcs')

        for dep in self.mf.gen_actions_by_type('depend'):
            fmri = dep.attrs.get('fmri')

            #
            # Ignore dependencies we don't care about.
            # TODO: there has to be a cleaner way to do this...
            # TODO2: if this is 'cleaner', figure out which of these are
            # whole-string matches and clean up the REGEX.
            #
            if not fmri or dep.attrs['type'] != 'require':
                continue
            try:
                dfmri = PkgFmri(fmri)
            except(IllegalFmri) as err:
                if 'build version' in str(err):
                    dfmri = PkgFmri(fmri.split('@')[0])
                else:
                    raise
            if dfmri.is_name_match(
                '.*__TBD.*|.*consolidation.*|.*release/name.*|'
                '.*compatibility-packages-sunwxwplt.*|.*runtime/perl.*'):
                continue
            
            #
            # Same deal as pkgfmri.
            #
            depstr = dfmri.pkg_name.replace('/','-').replace('_','-').lower()

            if dep.attrs.get('pkg.debug.depend.file') and self.ver:
                if "driver-serial-usbsksp-usbs49-fw" in depstr or \
                    depstr in self.depends:
                    #
                    # the perl code filters out "sunwcsd" as a possible
                    # source of dependencies. Apparently, that's handled
                    # elsewhere in the new process, because removing the check
                    # for SUNWcsd here doesn't change anything, and we don't
                    # miss any dependencies without it.
                    #
                    continue
                depstr += ' (>= %s)' % (self.ver)

            self.depends.append(depstr)
        #
        # Get directory name for holding output, based either on CLI args or
        # The path to the file we're reading from
        #
        self.wd = join(self.args.wd or self.dir,
                       self.name) 
        #
        # Create the output directories, removing it if it already exists.
        #
        if exists(self.wd):
            rmtree(self.wd)
        makedirs(join(self.wd, 'debian'))

        bwd = join(self.wd, 'debian', self.pkgname)

        #
        # Create the directories for every dir action in the manifest.
        # Also adds related commands to package files.
        #
        for d in self.mf.gen_actions_by_type('dir'):
            pth = d.attrs['path']
            dest = join(bwd, pth)
            if not exists(dest):
                makedirs(dest, int(d.attrs['mode'], 8))

            #
            # Solaris, by default, won't let you chown a file as non-root.
            # However, we still want to build the package if we can't 
            # chown files.
            #
            try:
                chown(dest, getpwnam(d.attrs['owner']).pw_uid, 
                      getgrnam(d.attrs['group']).gr_gid)
            except(OSError) as err:
                if 'Not owner' in str(err):
                    pass
                else:
                    raise
            self.fix.append("chmod %s $DEST/%s" % (d.attrs['mode'], pth))
            self.fix.append("chown %s:%s $DEST/%s" % (d.attrs['owner'], 
                                                d.attrs['group'], pth))
            

        #
        # Copy all of the files from the file actions into their appropriate
        # directories. Also adds related commands to package files.
        #
        if self.pkgname == 'sunwcs' and self.mf.actions_bytype.get('file'):
            self.post.append(
"""cp -f $BASEDIR/usr/bin/cp $BASEDIR/usr/bin/ln
	cp -f $BASEDIR/usr/bin/cp $BASEDIR/usr/bin/mv
	cp -f $BASEDIR/usr/lib/isaexec $BASEDIR/usr/bin/ksh
	cp -f $BASEDIR/usr/lib/isaexec $BASEDIR/usr/bin/ksh93
	cp -f $BASEDIR/usr/lib/isaexec $BASEDIR/usr/sbin/rem_drv
	cp -f $BASEDIR/usr/lib/isaexec $BASEDIR/usr/sbin/update_drv""")

        for f in self.mf.gen_actions_by_type('file'):
            pth = f.attrs['path']
            
            #
            # From perl code:
            # 'use etc/motd from base-files package'
            #
            if 'etc/motd' in pth:
                continue
            self.fix.append("mkdir -p $DEST/" + dirname(pth))

            #
            # Some packages don't include a dir action for every directory in
            # the file actions. That's probably a bug, but we don't want to 
            # error out just because of that, so we might as well check to make
            # sure the directory exists.
            #
            dest = join(bwd, pth)
            if not exists(dirname(dest)):
                makedirs(dirname(dest))

            #
            # Try to find this file in the directories supplied via CLI.
            # If we can't, throw an error.
            #
            cpth = pth if f.hash == 'NOHASH' or f.attrs.get('chash') else f.hash
            src = ''
            for d in self.args.dir:
                if exists(join(d, cpth)):
                    src = join(d, cpth)

            if not src:
                raise Exception("Couldn't find %s in supplied directories" 
                    % (cpth))

            copyfile(src, dest)
            chmod(dest, int(f.attrs['mode'], 8))
            try:
                chown(dest, getpwnam(f.attrs['owner']).pw_uid, 
                      getgrnam(f.attrs['group']).gr_gid)
            except(OSError) as err:
                if 'Not owner' in str(err):
                    pass
                else:
                    raise

            self.fix.append(
"""test -f "$DEST/%s" || echo '== Missing: %s'
test -f "$DEST/%s" || exit 1
chmod %s "$DEST/%s"
chown %s:%s "$DEST/%s" """.strip(' ') % (pth, pth, pth, f.attrs['mode'], pth, 
                             f.attrs['owner'], f.attrs['group'], pth))
    
            pres = f.attrs.get('preserve')
            if pres == 'renamenew':
                self.fix.append("mv $DEST/%s $DEST/%s.new" % (pth, pth))
                self.post.append(
                    "([ -f $BASEDIR/%s ] || mv -f $BASEDIR/%s.new $BASEDIR/%s)" 
                    % (pth,pth,pth))

            elif pres == 'renameold':
                self.fix.append("mv $DEST/%s $DEST/%s.%s"
                    % (pth,pth,self.pkgname))
                self.post.append(
"""([ -f $BASEDIR/%s ] && cp -f $BASEDIR/%s $BASEDIR/%s.old )
	([ -f $BASEDIR/%s.%s ] && mv -f $BASEDIR/%s.%s $BASEDIR/%s )"""
        % (pth,pth,pth,pth,self.pkgname,pth,self.pkgname,pth))

            elif pres == 'legacy':
                self.fix.append("mv $DEST/%s $DEST/%s.%s"
                           % (pth,pth,self.pkgname))
                self.post.append(
"""([ -f $BASEDIR/%s ] || rm -f $BASEDIR/%s.%s )
	([ -f $BASEDIR/%s ] && mv -f $BASEDIR/%s $BASEDIR/%s.legacy )
	([ -f $BASEDIR/%s.%s ] && mv -f $BASEDIR/%s.%s $BASEDIR/%s )"""
        % (pth,pth,self.pkgname,pth,pth,pth,pth,pth,self.pkgname,pth))

            elif pres == 'true':
                self.fix.append("mv $DEST/%s $DEST/%s.%s"
                    % (pth,pth,self.pkgname))
                self.post.append(
"""([ -f $BASEDIR/%s.saved ] && mv -f $BASEDIR/%s.saved $BASEDIR/%s )
	([ -f $BASEDIR/%s ] || mv -f $BASEDIR/%s.%s $BASEDIR/%s )
	([ -f $BASEDIR/%s ] && rm -f $BASEDIR/%s.%s)"""
        % (pth,pth,pth,pth,pth,self.pkgname,pth,pth,pth,self.pkgname))
                self.rm.append(
                    "([ -f $BASEDIR/%s ] && "
                    "mv -f $BASEDIR/%s $BASEDIR/%s.saved)" % (pth,pth,pth))

            if f.attrs.get('variant.opensolaris.zone') == 'global':
                self.post.append(
                    '[ "$ZONEINST" = "1" ] && ([ -f $BASEDIR/%s ] && '
                    'rm -f $BASEDIR/%s)' % (pth,pth))

            rfmri = f.attrs.get('restart_fmri')
            if rfmri and not self.svc.get(rfmri):
                self.svc[rfmri] = 1
                self.post.append(
                    '[ "${BASEDIR}" = "/" ] && ( /usr/sbin/svcadm restart %s '
                    '|| true )' % (rfmri))


        # 
        # Add commands for each hardlink action into
        # the appropriate package files.
        #
        if self.pkgname == 'sunwcs' and self.mf.actions_bytype.get('hardlink'):
            self.fix.append(
"""mkdir -p $DEST/usr/bin && cp -f $DEST/usr/bin/cp $DEST/usr/bin/ln
mkdir -p $DEST/usr/bin && cp -f $DEST/usr/bin/cp $DEST/usr/bin/mv
mkdir -p $DEST/usr/bin && cp -f $DEST/usr/lib/isaexec $DEST/usr/bin/ksh
mkdir -p $DEST/usr/bin && cp -f $DEST/usr/lib/isaexec $DEST/usr/bin/ksh93
mkdir -p $DEST/usr/bin && cp -f $DEST/usr/lib/isaexec $DEST/usr/sbin/rem_drv
mkdir -p $DEST/usr/bin && cp -f $DEST/usr/lib/isaexec $DEST/usr/sbin/update_drv\
""")

        hlskip = ['usr/bin/ln', 'usr/bin/mv', 'usr/bin/ksh', 'usr/bin/ksh93', 
                  'usr/sbin/rem_drv', 'usr/sbin/update_drv']
        for hl in self.mf.gen_actions_by_type('hardlink'):
            pth = hl.attrs['path']
            #
            # There are some hardlinks we don't care about, so skip them.
            #
            if pth in hlskip: 
                continue
            
            if hl.attrs.get('variant.opensolaris.zone') == 'global':
                self.post.append(
                    '[ "$ZONEINST" = "1" ] || (mkdir -p $BASEDIR/%s && '
                    'cd $BASEDIR/%s && ln -f %s %s)'
                    % (dirname(pth), dirname(pth), 
                      hl.attrs['target'], basename(pth)))
                self.rm.append('[ "$ZONEINST" = "1" ] || rm -f $BASEDIR/%s'
                    % (pth))
            else:
                self.post.append(
                    "mkdir -p $BASEDIR/%s && (cd $BASEDIR/%s && ln -f %s %s)"
                    % (dirname(pth), dirname(pth), 
                      hl.attrs['target'], basename(pth)))
                self.rm.append('rm -f $BASEDIR/%s' % (pth))

        # 
        # Add appropriate commands for each driver action 
        # to the appropriate package files.
        # TODO: Do it "the IPS way"?
        #
        for drv in self.mf.gen_actions_by_type('driver'): 
            name = drv.attrs.get('name')
            privs = drv.attrs.get('privs')
            policy = drv.attrs.get('policy')
            devlink = drv.attrs.get('devlink')
            oPerm = drv.attrs.get('perms')
            oClPerm = drv.attrs.get('clone_perms')
            cls = drv.attrs.get('class')
            alias = drv.attrs.get('alias')
            opts = ''

            if type(cls) == list:
                cls = ' '.join(cls)
            if type(alias) == list:
                alias = '" "'.join(alias)
            if type(policy) == list:
                policy = ", ".join(policy)
            if type(oPerm) == list:
                oPerm = "','".join(oPerm)
            if type(privs) == list:
                privs = privs[0]
                
            if privs:
                opts += ' -P %s' % (privs)
            if policy:
                policy = policy.replace('"',"")
                opts += " -p \'%s\'" % (policy)
            
            clopts = opts
            if cls:
                opts += " -c '%s'" % (cls)
            if alias:
                opts += " -i '\"%s\"'" % (alias)

            if not oPerm:
                clopts = opts
            else:
                opts += " -m \'%s\'" % (oPerm.replace('"',"'"))

            self.post.append('[ "$ZONEINST" = "1" ] || '
                '(grep -c "^%s " $BASEDIR/etc/name_to_major >/dev/null '
                '|| ( add_drv -n  $BASEDIR_OPT %s %s ) )' 
                % (name, opts, name))
            self.rm.append(
                '[ "$ZONEINST" = "1" ] || ( rem_drv -n $BASEDIR_OPT %s )'
                % (name))
            
            if oClPerm:
                if type(oClPerm) != list:
                    oClPerm = [oClPerm]
                for perm in oClPerm:
                    perm = perm.replace('"','')
                    self.post.append('[ "$ZONEINST" = "1" ] || '
                        '(grep -c "^clone:%s" $BASEDIR/etc/minor_perm '
                        '>/dev/null || update_drv -n  -a $BASEDIR_OPT %s '
                        '-m \'%s\' clone)' % (perm, clopts, perm))
                    self.rm.append('[ "$ZONEINST" = "1" ] || '
                        '(grep -c "^clone:%s" $BASEDIR/etc/minor_perm '
                        '>/dev/null && update_drv -n  -d $BASEDIR_OPT %s '
                        '-m \'%s\' clone)' % (perm, clopts, perm))

            if devlink:
                devlink = devlink.replace('\\t','\t')
                fields = devlink.split()
                self.post.append('[ "$ZONEINST" = "1" ] || '
                    '(grep -c "^%s" $BASEDIR/etc/devlink.tab '
                    '>/dev/null || (echo "%s" >> $BASEDIR/etc/devlink.tab))'
                            % (fields[0], devlink))
                self.rm.append('[ "$ZONEINST" = "1" ] || '
                    '( cat $BASEDIR/etc/devlink.tab | sed -e \'/^%s/d\' '
                    '> $BASEDIR/etc/devlink.tab.new; '
                    'mv $BASEDIR/etc/devlink.tab.new '
                    '$BASEDIR/etc/devlink.tab )' % (fields[0]))

        # TODO: do we need this?
        if self.mf.actions_bytype.get('driver'):
            if len(self.post):
                self.post.append('')
            if len(self.rm):
                self.rm.append('')


        #
        # Add commands for each link action to the appropriate package files.
        #
        mediator = [] # temporary location for mediator command
        old_mtr = None;
        
        for link in self.mf.gen_actions_by_type('link'):
            pth = link.attrs['path']
            target = link.attrs['target']
            mtr = link.attrs.get('mediator')
            mtr_ver = link.attrs.get('mediator-version')
            mtr_pri = link.attrs.get('mediator-priority')

            if old_mtr and mtr != old_mtr:
                raise Exception("%s: multiple mediator groups per manifest "
                                "not supported"
                                % (self.pkgname))

            dire = dirname(pth)
            if not dire:
                dire = '.'

            alt = pth.replace("/","-")

            if mtr:
                alt_pri = 99
            elif mtr_pri == 'vendor':
                alt_pri = 10
            else:
                alt_pri = 0

            if mtr and link.attrs.get('variant.opensolaris.zone'):
                raise Exception("%s: mediated links using "
                                "variant.opensolaris.zone not supported"
                                % (self.pkgname))

            if mtr and len(mediator) == 0:
                makedirs(join(bwd, "var/mediator"))
                copyfile("/dev/null", join(bwd, "var/mediator/", self.pkgname))
                self.fix.append("mkdir -p $DEST/var/mediator")

                # The following will "just work" as our update-alternatives
                # honors the BASEDIR environment variable.
                mediator.append(
                    '(update-alternatives --quiet '
                    '--install /var/mediator/%s %s /var/mediator/%s %s'
                    %(mtr, mtr, self.pkgname, alt_pri))
                self.rm.append(
"""if [ "$1" != "upgrade" ]; then
	(update-alternatives --quiet --remove %s /var/mediator/%s)
fi
""" %(mtr, self.pkgname))

            if link.attrs.get('variant.opensolaris.zone') == 'global':
                self.post.append(
                    '[ "$ZONEINST" = "1" ] || (mkdir -p $BASEDIR/%s && '
                    'ln -f -s %s $BASEDIR/%s)' % (dire, target, pth))

            else: # != 'global'
                if mtr:
                    mediator.append('--slave /%s %s /%s/%s'
                                %(pth, alt, dire, target))
                else:
                    self.fix.append('mkdir -p $DEST/%s && ln -f -s %s $DEST/%s' 
                               % (dire, target, pth))

        if len(mediator):
            mediator.append(')')
            self.post.append(' '.join(mediator))

        # Groups
        for grp in self.mf.gen_actions_by_type('group'):
            self.post.append("""
	if ! getent group %s >/dev/null 2>&1 ; then
		groupadd -g %s %s
	fi""" % (grp.attrs['groupname'], grp.attrs['gid'], 
                grp.attrs['groupname']))    


        # Users
        for usr in self.mf.gen_actions_by_type('user'):
            name = usr.attrs['username']
            uid = usr.attrs['uid']
            gcos = usr.attrs.get('gcos-field')
            shell = usr.attrs.get('login-shell')
            grp = usr.attrs.get('group')
            self.post.append("""
	if ! getent passwd %s >/dev/null 2>&1 ; then
 	       useradd %s%s%s%s%s
	fi""" % (name, ' -c "%s"' % (gcos) if gcos else '',
                ' -s %s' % (shell) if shell else '',
                ' -u ' + uid, ' -g %s' % (grp) if grp else '', ' -m ' + name))


        return True

    def savedebpkg(self):
        """Create source files for a debian package"""
        #
        # If there are no actions we care about,
        # don't bother creating any files.
        #
        if not (len(self.depends) or self.mf.actions_bytype.get('dir') \
                    or self.mf.actions_bytype.get('file') \
                    or self.mf.actions_bytype.get('hardlink') \
                    or self.mf.actions_bytype.get('user') \
                    or self.mf.actions_bytype.get('group')):
            print "%s: Nothing to save. Exiting." % (self.pkgname)
            return

        control = open(join(self.wd, 'debian', 'control'), 'w')
        control.write("""Source: %s
Section: %s
Priority: %s
XBS-Original-Version: %s
XBS-Category: %s
Maintainer: %s

Package: %s
Architecture: %s
Depends: %s
Provides: %s%s
Description: %s
 %s
"""         % (self.pkgname, self.args.sect, self.pri, self.origver,
               self.args.sect, self.args.main, self.pkgname,
               self.arch, ', '.join(self.depends),
               self.origname.replace('_','-'), 
               '\nReplaces: %s' % (self.rep) if self.rep else '',
               self.mf.get('pkg.summary', 'none'),
               self.mf.get('pkg.description', 'none')))
        control.close()

        change = open(join(self.wd, 'debian', 'changelog'), 'w')
        change.write("""%s (%s) unstable; urgency=low

  * Temporary file, need only for package generation process

 -- %s  %s
""" % (self.pkgname, self.ver, self.args.main,
       strftime("%a, %d %h %Y %H:%M:%S %z")))
        change.close()

        compat = open(join(self.wd, 'debian', 'compat'),'w')
        compat.write('7\n')
        compat.close()

        copy = open(join(self.wd, 'debian', 'copyright'),'w')
        copy.write("""
Copyright:

Copyright (c) 2011 illumian.  All rights reserved.
Use is subject to license terms.

""")
        copy.close()


        fixperms = open(join(self.wd, 'debian',
                             self.pkgname + '.fixperms'), 'w')
        fixperms.write(
"""#!/bin/sh

export PATH=%s

%s
""" % ("/usr/bin:/sbin:/usr/sbin" if len(self.fix) else '', 
      '\n'.join(self.fix) if len(self.fix) else ''))
        fixperms.close()

        if len(self.post):
            postinst = open(join(self.wd, 'debian',
                                 self.pkgname + '.postinst'), 'w')
            postinst.write(
"""#!/bin/sh

# postinst script for %s
#
# see: dh_installdeb(1)

#set -e

# summary of how this script can be called:
#        * <postinst> \`configure\' <most-recently-configured-version>
#        * <old-postinst> \`abort-upgrade\' <new version>
#        * <conflictor\'s-postinst> \`abort-remove\' \`in-favour\' <package>
#          <new-version>
#        * <postinst> \`abort-remove\'
#        * <deconfigured\'s-postinst> \`abort-deconfigure\' \`in-favour\'
#          <failed-install-package> <version> \`removing\'
#          <conflicting-package> <version>
# for details, see http://www.debian.org/doc/debian-policy/ or
# the debian-policy package

PATH=/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

if [ "${BASEDIR:=/}" != "/" ]; then
    BASEDIR_OPT="-b $BASEDIR"
fi

case "$1" in
    configure)
        %s
    ;;

    abort-upgrade|abort-remove|abort-deconfigure)
    ;;

    *)
        echo "postinst called with unknown argument \'$1\'" >&2
        exit 1
    ;;
esac

# dh_installdeb will replace this with shell code automatically
# generated by other debhelper scripts.

#DEBHELPER#

exit 0
""" % (self.pkgname, '\n\t'.join(self.post)))
            postinst.close()


        if len(self.pre):
            preinst = open(join(self.wd, 'debian',
                                self.pkgname + '.preinst'), 'w')
            preinst.write(
"""#!/bin/sh
# preinst script for sunwcs
#
# see: dh_installdeb(1)

#set -e

# summary of how this script can be called:
#        * <new-preinst> \`install'
#        * <new-preinst> \`install' <old-version>
#        * <new-preinst> \`upgrade' <old-version>
#        * <old-preinst> \`abort-upgrade' <new-version>
# for details, see http://www.debian.org/doc/debian-policy/ or
# the debian-policy package

PATH=/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

if [ "${BASEDIR:=/}" != "/" ]; then
    BASEDIR_OPT="-b $BASEDIR"
fi

case "$1" in
    install|upgrade)
	%s
    ;;

    abort-upgrade)
    ;;

    *)
        echo "preinst called with unknown argument '$1'" >&2
        exit 1
    ;;
esac

# dh_installdeb will replace this with shell code automatically
# generated by other debhelper scripts.

#DEBHELPER#

exit 0
""" % ('\n\t'.join(self.pre)))
            preinst.close()

        if len(self.rm):
            prerm = open(join(self.wd, 'debian',
                              self.pkgname + '.prerm'), 'w')
            prerm.write(
"""#!/bin/sh
# prerm script for sunwcs
#
# see: dh_installdeb(1)

#set -e

# summary of how this script can be called:
#        * <prerm> \`remove\'
#        * <old-prerm> \`upgrade' <new-version>
#        * <new-prerm> \`failed-upgrade' <old-version>
#        * <conflictor's-prerm> \`remove' \`in-favour' <package> <new-version>
#        * <deconfigured\'s-prerm> \`deconfigure' \`in-favour'
#          <package-being-installed> <version> \`removing'
#          <conflicting-package> <version>
# for details, see http://www.debian.org/doc/debian-policy/ or
# the debian-policy package

PATH=/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

if [ "${BASEDIR:=/}" != "/" ]; then
    BASEDIR_OPT="-b $BASEDIR"
fi

case "$1" in
    remove|upgrade|deconfigure)
	%s
    ;;

    failed-upgrade)
    ;;

    *)
        echo "prerm called with unknown argument '$1'" >&2
        exit 1
    ;;
esac

# dh_installdeb will replace this with shell code automatically
# generated by other debhelper scripts.

#DEBHELPER#

exit 0
""" % ('\n\t'.join(self.rm)))
            prerm.close()
        rpath = join(self.wd, 'debian', 'rules')
        rules = open(rpath, 'w')
        rules.write(
"""#!/usr/bin/gmake -f
# -*- makefile -*-
# Sample debian/rules that uses debhelper.
# This file was originally written by Joey Hess and Craig Small.
# As a special exception, when this file is copied by dh-make into a
# dh-make output file, you may use that output file without restriction.
# This special exception was added by Craig Small in version 0.37 of dh-make.

# Uncomment this to turn on verbose mode.
#export DH_VERBOSE=1

#MYGATE := ${BASEGATE}
DEST := $(CURDIR)/debian/%s

##configure: configure-stamp
##configure-stamp:
##	dh_testdir
	# Add here commands to configure the package.
##	touch configure-stamp


##build: build-stamp
build:

##build-stamp: configure-stamp 
#	dh_testdir
	# Add here commands to compile the package.
#	touch $@

clean:
	dh_testdir
	dh_testroot
	-rm -f build-stamp configure-stamp

	# Add here commands to clean up after the build process.
#	-$(MAKE) clean
#	dh_clean

##install: build
install:
##	dh_testdir
##	dh_testroot
##	dh_clean -k 
##	dh_installdirs

	# Add here commands to install the package into debian/tmp.
#	mkdir -p $(CURDIR)/debian/tmp
#	mv proto/* $(CURDIR)/debian/tmp


# Build architecture-independent files here.
##binary-indep: build install
# We have nothing to do by default.

# Build architecture-dependent files here.
##binary-arch: build install
binary-arch:
	dh_testdir
	dh_testroot
#	test -f $(CURDIR)/debian/%s.fixperms && MYSRCDIR=$(MYGATE) DEST=$(DEST)\
 /bin/sh $(CURDIR)/debian/%s.fixperms
	test -f $(CURDIR)/debian/%s.fixperms && DEST=$(DEST)\
 /bin/sh $(CURDIR)/debian/%s.fixperms
#	dh_makeshlibs -p%s
	dh_makeshlibs
	dh_installdeb
	rm -f $(CURDIR)/debian/%s/DEBIAN/conffiles
#	dh_shlibdeps debian/tmp/lib/* debian/tmp/usr/lib/*
	-dh_shlibdeps -Xdebian/sunwcs/usr/kernel/* -- --ignore-missing-info
	dh_gencontrol
	dh_md5sums
	dh_builddeb -- -Zbzip2 -z9

##binary: binary-indep binary-arch
binary: binary-arch
##.PHONY: build clean binary-indep binary-arch binary install configure
.PHONY: clean binary-arch binary
""" % (self.pkgname, self.pkgname, self.pkgname, self.pkgname, self.pkgname,
       self.pkgname, self.pkgname))
        rules.close()
        chmod(rpath, 0777)
        conffiles = open(join(self.wd, 'debian',
                              self.pkgname + '.conffiles'), 'w')
        conffiles.write('\n')
        conffiles.close()


def parsespec(d, f):
    """create a dict() that contains the key/value pairs \
represented in a conffile"""
    d.update([(lambda a, b:[a, [b]])(*line.rstrip().split(':')) for line in f 
              if not line.startswith('#') and ':' in line])

def createparser():
    """create an OptionParser object"""
    cwd = dirname(realpath(__file__))
    parser = optparse.OptionParser(
        description='Convert a mogrified pkg manifest to Debian format')
    parser.add_option('-p', '--pkg', dest = 'path', action = 'append',
                        help = 'location of the manifest')
    parser.add_option('-v', '--verbose', dest = 'v', action = 'store_true',
                        help = 'output verbose stuff')
    parser.add_option('--pv', dest = 'ver', default = '1.0.0-deb',
                        help = 'package version')
    parser.add_option('--cv', dest = 'origver',
                        help = 'XBS-Original-Version Debian field')
    parser.add_option('-o', '--wd', dest = 'wd',
                        help = 'Where to store this package')
    parser.add_option('--mg', '--mfg', '--manifest_gate', dest = 'gate',
                        help = 'location of all manifests')
    parser.add_option('--maintainer', dest = 'main',
                        default = 'Nexenta Systems <maintainer@nexenta.com>',
                        help = 'Debian Maintainer Field')
    parser.add_option('--me', '--mfe', dest = 'ext', default = 'res', 
                        help = 'Extension of manifests (i.e. .mog, .mf)')
    parser.add_option('-s', '--section', '--category', dest = 'sect', 
                      default = 'undef', help = 'Debian Section field')
    parser.add_option('-r', '--priority', dest = 'pri', default = 'optional',
                        help = 'Debian Priority field')
    parser.add_option('--spec', dest = 'spec', action = 'store_true',
                        help = 'Whether this is a "special" package')
    parser.add_option('--rep', dest = 'rep',
                        help = 'Debian Replace field')
    parser.add_option('-d', '--dir', dest = 'dir', action = 'append', 
                      help = 'Path to top of tree of files included in packages'
                      '(i.e. proto/root_i386)')
    parser.add_option('--conf', dest = 'conf', default = '%s/../etc/' % (cwd),
                      help = 'Directory where the ips conf files are stored')
    return parser

# Start
def main(arglist):
    """main"""
    errs = False
    parser = createparser()
    (args, thing)  = parser.parse_args(arglist)

    #
    # Find the conffiles relative to the directory this script is in.
    #
    frep = open(join(args.conf, 'ips2deb.replaces'),'r')
    fver = open(join(args.conf, 'ips2deb.versions'),'r')
    fpri = open(join(args.conf, 'ips2deb.priorities'),'r')


    parsespec(drep, frep)
    parsespec(dver, fver)
    parsespec(dpri, fpri)

    if not args.dir:
        raise Exception("Need at least one -d/--dir option...")

    #
    # If a set of packages are specified, build those. 
    # Otherwise, build all of the packages in a directory.
    #
    if not args.path or args.path == 'all':
        if not args.gate:
            raise Exception('Manifest Gate path needed if no package specified')
        pkglist = [join(args.gate, f) for f in listdir(args.gate) 
                   if f.endswith('.%s' % (args.ext))]
    else:
        pkglist = args.path

    pkgs = []
    for pkg in pkglist:
        try:
            tmp = IPSConvert(pkg, args)
            tmp.initdebpkg()
            if tmp.process:
                pkgs.append(tmp)
        except Exception as err:
            print "\n\nError: %s\n%s: %s\n\n" % (pkg, type(err), err)
            errs = True

    for pkg in pkgs:
        try:
            pkg.gendebpkg()
            pkg.savedebpkg()
        except Exception as err:
            print "\n\nError: %s\n%s: %s\n\n" % (pkg.pkgname, type(err), err)
            errs = True

    frep.close()
    fver.close()
    fpri.close()

    return errs

if __name__ == '__main__':
    errors = main(sys.argv[1:])
    if errors:
        raise Exception("some errors occured during processing;\n"
            "Packages that didn't error out were still generated.\n")

# Copyright 2017 Nexenta Systems, Inc.
# Copyright 2016 Joyent, Inc.
# Copyright 2016 RackTop Systems.
#
<meta http-equiv="Content-Type" content="text/xhtml;charset=utf-8"></meta>
# CSS for the HTML version of the man pages.
# Current version is from mandoc 1.14.2.
MANCSS='
html { max-width: 100ex; }
body { font-family: Helvetica,Arial,sans-serif; }
table { margin-top: 0em; margin-bottom: 0em; }
td { vertical-align: top; }
ul, ol, dl { margin-top: 0em; margin-bottom: 0em; }
li, dt { margin-top: 1em; }
a.selflink { border-bottom: thin dotted; color: inherit; font: inherit;
    text-decoration: inherit; }
fieldset { border: thin solid silver; border-radius: 1em; text-align: center; }
input[name=expr] { width: 25%; }
table.results { margin-top: 1em; margin-left: 2em; font-size: smaller; }
table.head { width: 100%; border-bottom: 1px dotted #808080; margin-bottom: 1em;
    font-size: smaller; }
td.head-vol { text-align: center; }
td.head-rtitle { text-align: right; }
span.Nd { }
table.foot { width: 100%; border-top: 1px dotted #808080; margin-top: 1em;
    font-size: smaller; }
td.foot-os { text-align: right; }
div.manual-text { margin-left: 5ex; }
h1.Sh { margin-top: 2ex; margin-bottom: 1ex; margin-left: -4ex;
    font-size: 110%; }
h2.Ss { margin-top: 2ex; margin-bottom: 1ex; margin-left: -2ex;
    font-size: 105%; }
div.Pp { margin: 1ex 0ex; }
a.Sx { }
a.Xr { }
div.Bd { }
div.D1 { margin-left: 5ex; }
ul.Bl-bullet { list-style-type: disc; padding-left: 1em; }
li.It-bullet { }
ul.Bl-dash { list-style-type: none; padding-left: 0em; }
li.It-dash:before { content: "\2014  "; }
ul.Bl-item { list-style-type: none; padding-left: 0em; }
li.It-item { }
ul.Bl-compact > li { margin-top: 0ex; }
ol.Bl-enum { padding-left: 2em; }
li.It-enum { }
ol.Bl-compact > li { margin-top: 0ex; }
dl.Bl-diag { }
dt.It-diag { }
dd.It-diag { margin-left: 0ex; }
b.It-diag { font-style: normal; }
dl.Bl-hang { }
dt.It-hang { }
dd.It-hang { margin-left: 10.2ex; }
dl.Bl-inset { }
dt.It-inset { }
dd.It-inset { margin-left: 0ex; }
dl.Bl-ohang { }
dt.It-ohang { }
dd.It-ohang { margin-left: 0ex; }
dl.Bl-tag { margin-left: 10.2ex; }
dt.It-tag { float: left; margin-top: 0ex; margin-left: -10.2ex;
    padding-right: 2ex; vertical-align: top; }
dd.It-tag { clear: right; width: 100%; margin-top: 0ex; margin-left: 0ex;
    vertical-align: top; overflow: auto; }
dl.Bl-compact > dt { margin-top: 0ex; }
table.Bl-column { }
tr.It-column { }
td.It-column { margin-top: 1em; }
table.Bl-compact > tbody > tr > td { margin-top: 0ex; }
cite.Rs { font-style: normal; font-weight: normal; }
span.RsA { }
i.RsB { font-weight: normal; }
span.RsC { }
span.RsD { }
i.RsI { font-weight: normal; }
i.RsJ { font-weight: normal; }
span.RsN { }
span.RsO { }
span.RsP { }
span.RsQ { }
span.RsR { }
span.RsT { text-decoration: underline; }
a.RsU { }
span.RsV { }
span.eqn { }
table.tbl { }
table.Nm { }
b.Nm { font-style: normal; }
b.Fl { font-style: normal; }
b.Cm { font-style: normal; }
var.Ar { font-style: italic; font-weight: normal; }
span.Op { }
b.Ic { font-style: normal; }
code.Ev { font-style: normal; font-weight: normal; font-family: monospace; }
i.Pa { font-weight: normal; }
span.Lb { }
b.In { font-style: normal; }
a.In { }
b.Fd { font-style: normal; }
var.Ft { font-style: italic; font-weight: normal; }
b.Fn { font-style: normal; }
var.Fa { font-style: italic; font-weight: normal; }
var.Vt { font-style: italic; font-weight: normal; }
var.Va { font-style: italic; font-weight: normal; }
code.Dv { font-style: normal; font-weight: normal; font-family: monospace; }
code.Er { font-style: normal; font-weight: normal; font-family: monospace; }
span.An { }
a.Lk { }
a.Mt { }
b.Cd { font-style: normal; }
i.Ad { font-weight: normal; }
b.Ms { font-style: normal; }
span.St { }
a.Ux { }
.No { font-style: normal; font-weight: normal; }
.Em { font-style: italic; font-weight: normal; }
.Sy { font-style: normal; font-weight: bold; }
.Li { font-style: normal; font-weight: normal; font-family: monospace; }
'

		OLDIFS=$IFS
		IFS=/
		for dir in ${dirs_mk}; do
			print -- "-mkdir ${dir}" >> ${batch_file_mkdir}
			print "chdir ${dir}" >> ${batch_file_mkdir}
		done
		IFS=$OLDIFS
	print "<a class=\"print\" href=\"javascript:print()\">Print this page</a>"
	    <body id="SUNWwebrev">
	    </body>
	typeset cur="${1##$2?(/)}"

	#
	# If the first path was specified absolutely, and it does
	# not start with the second path, it's an error.
	#
	if [[ "$cur" = "/${1#/}" ]]; then
		# Should never happen.
		print -u2 "\nWARNING: relative_dir: \"$1\" not relative "
		print -u2 "to \"$2\".  Check input paths.  Framed webrev "
		print -u2 "will not be relocatable!"
		print $2
		return
	fi
var scrolling = 0;
var scount = 10;
function scrollByPix()
{
	if (scount <= 0) {
		sfactor *= 1.2;
		scount = 10;
	parent.lhs.scrollBy(0, sfactor);
	parent.rhs.scrollBy(0, sfactor);
function scrollToAnc(num)
{
	parent.lhs.scrollBy(0, -30);
	parent.rhs.scrollBy(0, -30);
function stopScroll()
{
	if (scrolling == 1) {
		scrolling = 0;
function startScroll()
{
	scrolling = 1;
	myInt = setInterval("scrollByPix()", 10);
function handlePress(b)
{
	case 1:
	case 2:
	case 3:
		sfactor = -3;
	case 4:
		sfactor = 3;
	case 5:
	case 6:
function handleRelease(b)
{
function keypress(ev)
{

function ValidateDiffNum()
{
	var val;
	var i;

	i = parseInt(val);
	if (isNaN(i)) {
		parent.nav.document.diff.display.value = getAncValue();
	} else {
		scrollToAnc(i);
	}
	return (false);
}

			error=2
			exit;
	my $parent = $ARGV[0];
	my $child = $ARGV[1];

	open(F, "git diff -M --name-status $parent..$child |");
		if ($1 >= 75) {		 # Probably worth treating as a rename
		}

	open(F, "git whatchanged --pretty=format:%B $parent..$child |");
		my ($unused, $fname, $fname2) = split(/\t/, $_);
		$fname = $fname2 if defined($fname2);
	}' ${parent} ${child} > $TMPFLIST
		file="$PDIR/$PF"
		$GIT ls-tree $GIT_PARENT $file | read o_mode type o_object junk
		$GIT cat-file $type $o_object > $olddir/$file 2>/dev/null

		if (( $? != 0 )); then
			rm -f $olddir/$file
		elif [[ -n $o_mode ]]; then
			# Strip the first 3 digits, to get a regular octal mode
			o_mode=${o_mode/???/}
			chmod $o_mode $olddir/$file
		else
			# should never happen
			print -u2 "ERROR: set mode of $olddir/$file"
		fi
		cp $CWS/$DIR/$F $newdir/$DIR/$F
		chmod $(get_file_mode $CWS/$DIR/$F) $newdir/$DIR/$F
	if [[ $SCM_MODE == "git" ]]; then
	-c <revision>: generate webrev for single revision (git only)
	-h <revision>: specify "head" revision for comparison (git only)
[[ -z $MANDOC ]] && MANDOC=`look_for_prog mandoc`
[[ -z $COL ]] && COL=`look_for_prog col`
cflag=
hflag=
while getopts "c:C:Dh:i:I:lnNo:Op:t:Uw" opt
	c)	cflag=1
		codemgr_head=$OPTARG
		codemgr_parent=$OPTARG~1;;

	h)	hflag=1
		codemgr_head=$OPTARG;;


if [[ $SCM_MODE == "git" ]]; then
		2>/dev/null)
	if [[ "$codemgr_ws" = *"/.git" ]]; then
		codemgr_ws=$(dirname $codemgr_ws) # Lose the '/.git'
	fi
git|subversion)
if [[ $SCM_MODE == "git" ]]; then
	# Check that "head" revision specified with -c or -h is sane
	if [[ -n $cflag || -n $hflag ]]; then
		head_rev=$($GIT rev-parse --verify --quiet "$codemgr_head")
		if [[ -z $head_rev ]]; then
			print -u2 "Error: bad revision ${codemgr_head}"
			exit 1
		fi
	if [[ -z $codemgr_head ]]; then
		codemgr_head="HEAD";
	# If we're not on a branch there's nothing we can do
	if [[ $this_branch != "(no branch)" ]]; then
		$GIT for-each-ref					\
		    --format='%(refname:short) %(upstream:short)'	\
		    refs/heads/ |					\
		    while read local remote; do
			if [[ "$local" == "$this_branch" ]]; then
				par_branch="$remote"
			fi
		done
		flist_from_git "$codemgr_head" "$real_parent"
		git_wxfile "$codemgr_head" "$real_parent"
		GIT_PARENT=$($GIT merge-base "$real_parent" "$codemgr_head")
	if [[ -n $cflag ]]; then
		PRETTY_PWS="previous revision (at ${pnode})"
	elif [[ $real_parent == */* ]]; then
	elif [[ -n $pflag && -z $parent_webrev ]]; then
		PRETTY_PWS="${CWS} (explicit revision ${pnode})"
	cnode=$($GIT --git-dir=${codemgr_ws}/.git rev-parse --short=12 \
	    ${codemgr_head} 2>/dev/null)

	if [[ -n $cflag || -n $hflag ]]; then
		PRETTY_CWS="${CWS} (explicit head at ${cnode})"
	else
		PRETTY_CWS="${CWS} (at ${cnode})"
	fi
	if [[ $SCM_MODE == "unknown" ]]; then
		print -u2 "    Unknown type of SCM in use"
	else
		print -u2 "    Unsupported SCM in use: $SCM_MODE"
	fi
	env_from_flist
	if [[ -z $CODEMGR_WS ]]; then
		print -u2 "SCM not detected/supported and " \
		    "CODEMGR_WS not specified"
		exit 1
		fi
	if [[ -z $CODEMGR_PARENT ]]; then
		print -u2 "SCM not detected/supported and " \
		    "CODEMGR_PARENT not specified"
		exit 1
	fi
	CWS=$CODEMGR_WS
	PWS=$CODEMGR_PARENT
	else

	#
	# The "git apply" command does not tolerate the spurious
	# "./" that we otherwise insert; be careful not to include
	# it in the paths that we pass to diff(1).
	#
	if [[ $PDIR == "." ]]; then
		ofile=old/$PF
	else
		ofile=old/$PDIR/$PF
	fi
	if [[ $DIR == "." ]]; then
		nfile=new/$F
	else
		nfile=new/$DIR/$F
	fi
	#	- GNU patch doesn't interpret the output of illumos diff
	#	  properly when it comes to adds and deletes.  We need to
	#	  do some "cleansing" transformations:
	#
	# Check if it's man page, and create plain text, html and raw (ascii)
	# output for the new version, as well as diffs against old version.
	#
	if [[ -f "$nfile" && "$nfile" = *.+([0-9])*([a-zA-Z]) && \
	    -x $MANDOC && -x $COL ]]; then
		$MANDOC -Tascii $nfile | $COL -b > $nfile.man.txt
		source_to_html txt < $nfile.man.txt > $nfile.man.txt.html
		print " man-txt\c"
		print "$MANCSS" > $WDIR/raw_files/new/$DIR/man.css
		$MANDOC -Thtml -Ostyle=man.css $nfile > $nfile.man.html
		print " man-html\c"
		$MANDOC -Tascii $nfile > $nfile.man.raw
		print " man-raw\c"
		if [[ -f "$ofile" && -z $mv_but_nodiff ]]; then
			$MANDOC -Tascii $ofile | $COL -b > $ofile.man.txt
			${CDIFFCMD:-diff -bt -C 5} $ofile.man.txt \
			    $nfile.man.txt > $WDIR/$DIR/$F.man.cdiff
			diff_to_html $F $DIR/$F "C" "$COMM" < \
			    $WDIR/$DIR/$F.man.cdiff > \
			    $WDIR/$DIR/$F.man.cdiff.html
			print " man-cdiffs\c"
			${UDIFFCMD:-diff -bt -U 5} $ofile.man.txt \
			    $nfile.man.txt > $WDIR/$DIR/$F.man.udiff
			diff_to_html $F $DIR/$F "U" "$COMM" < \
			    $WDIR/$DIR/$F.man.udiff > \
			    $WDIR/$DIR/$F.man.udiff.html
			print " man-udiffs\c"
			if [[ -x $WDIFF ]]; then
				$WDIFF -c "$COMM" -t "$WNAME Wdiff $DIR/$F" \
				    $ofile.man.txt $nfile.man.txt > \
				    $WDIR/$DIR/$F.man.wdiff.html 2>/dev/null
				if [[ $? -eq 0 ]]; then
					print " man-wdiffs\c"
				else
					print " man-wdiffs[fail]\c"
				fi
			fi
			sdiff_to_html $ofile.man.txt $nfile.man.txt $F.man $DIR \
			    "$COMM" > $WDIR/$DIR/$F.man.sdiff.html
			print " man-sdiffs\c"
			print " man-frames\c"
		fi
		rm -f $ofile.man.txt $nfile.man.txt
		rm -f $WDIR/$DIR/$F.man.cdiff $WDIR/$DIR/$F.man.udiff
	fi

# If the SCM detected is Git, and the configuration property user.name is
# available, use that, but be careful to properly escape angle brackets (HTML
# syntax characters) in the email address.
if [[ "$SCM_MODE" == git ]]; then
	preparer=$(git config user.name 2>/dev/null)
		sdiff_url="$(print $P.sdiff.html | url_encode)"
		frames_url="$(print $P.frames.html | url_encode)"
		print " ------ ------"
		print " ------ ------"
	manpage=
	if [[ -f $F.man.cdiff.html || \
	    -f $WDIR/raw_files/new/$P.man.txt.html ]]; then
		manpage=1
		print "<br/>man:"
	fi

	if [[ -f $F.man.cdiff.html ]]; then
		mancdiff_url="$(print $P.man.cdiff.html | url_encode)"
		manudiff_url="$(print $P.man.udiff.html | url_encode)"
		mansdiff_url="$(print $P.man.sdiff.html | url_encode)"
		manframes_url="$(print $P.man.frames.html | url_encode)"
		print "<a href=\"$mancdiff_url\">Cdiffs</a>"
		print "<a href=\"$manudiff_url\">Udiffs</a>"
		if [[ -f $F.man.wdiff.html && -x $WDIFF ]]; then
			manwdiff_url="$(print $P.man.wdiff.html | url_encode)"
			print "<a href=\"$manwdiff_url\">Wdiffs</a>"
		fi
		print "<a href=\"$mansdiff_url\">Sdiffs</a>"
		print "<a href=\"$manframes_url\">Frames</a>"
	elif [[ -n $manpage ]]; then
		print " ------ ------"
		if [[ -x $WDIFF ]]; then
			print " ------"
		fi
		print " ------ ------"
	fi

	if [[ -f $WDIR/raw_files/new/$P.man.txt.html ]]; then
		mantxt_url="$(print raw_files/new/$P.man.txt.html | url_encode)"
		print "<a href=\"$mantxt_url\">TXT</a>"
		manhtml_url="$(print raw_files/new/$P.man.html | url_encode)"
		print "<a href=\"$manhtml_url\">HTML</a>"
		manraw_url="$(print raw_files/new/$P.man.raw | url_encode)"
		print "<a href=\"$manraw_url\">Raw</a>"
	elif [[ -n $manpage ]]; then
		print " --- ---- ---"
	fi

	# Insert delta comments
	if [[ $SCM_MODE == "unknown" ]]; then
# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=5

# waf fails on python3_5: AttributeError: Can't pickle local object 'Context.__init__.<locals>.node_class'
PYTHON_COMPAT=( python{2_7,3_4} )
USE_RUBY="ruby20 ruby21 ruby22"

inherit eutils multiprocessing python-single-r1 ruby-single toolchain-funcs

MY_P="${P}DrO_o"

DESCRIPTION="X(cross)platform Music Multiplexing System. Next generation of the XMMS player"
HOMEPAGE="http://xmms2.org/wiki/Main_Page"
SRC_URI="mirror://sourceforge/${PN}/${MY_P}.tar.bz2"
LICENSE="GPL-2 LGPL-2.1"

SLOT="0"
KEYWORDS="alpha amd64 ppc x86"

IUSE="aac airplay +alsa ao asf cdda curl cxx ffmpeg flac gvfs ices
jack mac mlib-update mms +mad modplug mp3 mp4 musepack ofa oss
perl phonehome pulseaudio python ruby samba +server sid sndfile speex
test valgrind +vorbis vocoder wavpack xml zeroconf"

RDEPEND="server? (
		>=dev-db/sqlite-3.3.4

		aac? ( >=media-libs/faad2-2.0 )
		airplay? ( dev-libs/openssl:0= )
		alsa? ( media-libs/alsa-lib )
		ao? ( media-libs/libao )
		cdda? ( dev-libs/libcdio-paranoia
			>=media-libs/libdiscid-0.1.1
			>=media-sound/cdparanoia-3.9.8 )
		curl? ( >=net-misc/curl-7.15.1 )
		ffmpeg? ( virtual/ffmpeg )
		flac? ( media-libs/flac )
		gvfs? ( gnome-base/gnome-vfs )
		ices? ( media-libs/libogg
			media-libs/libshout
			media-libs/libvorbis )
		jack? ( >=media-sound/jack-audio-connection-kit-0.101.1 )
		mac? ( media-sound/mac )
		mms? ( virtual/ffmpeg
			>=media-libs/libmms-0.3 )
		modplug? ( media-libs/libmodplug )
		mad? ( media-libs/libmad )
		mp3? ( >=media-sound/mpg123-1.5.1 )
		musepack? ( media-sound/musepack-tools )
		ofa? ( media-libs/libofa )
		pulseaudio? ( media-sound/pulseaudio )
		samba? ( >=net-fs/samba-4.2 )
		sid? ( media-sound/sidplay
			media-libs/resid )
		sndfile? ( media-libs/libsndfile )
		speex? ( media-libs/speex
			media-libs/libogg )
		vorbis? ( media-libs/libvorbis )
		vocoder? ( sci-libs/fftw:3.0= media-libs/libsamplerate )
		wavpack? ( media-sound/wavpack )
		xml? ( dev-libs/libxml2 )
		zeroconf? ( net-dns/avahi[mdnsresponder-compat] )
	)

	>=dev-libs/glib-2.12.9
	cxx? ( >=dev-libs/boost-1.32 )
	perl? ( >=dev-lang/perl-5.8.8 )
	python? ( ${PYTHON_DEPS} )
	ruby? ( ${RUBY_DEPS} )
"

DEPEND="${RDEPEND}
	dev-lang/python
	virtual/pkgconfig
	perl? ( dev-perl/Module-Build
		virtual/perl-Module-Metadata )
	python? ( >=dev-python/cython-0.15.1
		dev-python/pyrex )
	test? ( dev-util/cunit
		valgrind? ( dev-util/valgrind ) )
"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

S="${WORKDIR}/${MY_P}"

pkg_setup() {
	# used both for building xmms2 and
	# optionally linking client library
	# against python
	python-single-r1_pkg_setup
}

# use_enable() is taken as proto
# $1 - useflag
# $2 - xmms2 option/plugin name (equals to $1 if not set)

xmms2_flag() {
	[[ -z $1 ]] && eerror "!!! empty arg. usage: xmms2_flag <USEFLAG> [<xmms2_flagname>]."

	local UWORD=${2:-$1}

	case $1 in
		ENABLED)
			echo ",${UWORD}"
			;;
		DISABLED)
			;;
		*)
			use $1 && echo ",${UWORD}"
			;;
	esac
}

src_prepare() {
	./waf # inflate waf
	cd .waf* || die
	epatch "${FILESDIR}/${PN}"-0.8DrO_o-waflib-fix-perl.patch #578778
	cd "${S}"
	epatch "${FILESDIR}/${P}"-ffmpeg-0.11.patch #443256
	epatch "${FILESDIR}/${P}"-libav-9-p2.patch #443256
	epatch "${FILESDIR}/${P}"-libav-9.patch #443256
	epatch "${FILESDIR}/${P}"-cython-0.19.1.patch
	epatch "${FILESDIR}/${P}"-memset.patch
	epatch "${FILESDIR}/${P}"-ffmpeg2.patch #536232
	epatch "${FILESDIR}/${P}"-cpython.patch
	epatch "${FILESDIR}/${P}"-modpug.patch #536046
	epatch "${FILESDIR}/${P}"-audio4-p1.patch #540890
	epatch "${FILESDIR}/${P}"-audio4-p2.patch
	epatch "${FILESDIR}/${P}"-audio4-p3.patch
	epatch "${FILESDIR}/${P}"-audio4-p4.patch
	epatch "${FILESDIR}/${P}"-audio4-p5.patch
	epatch "${FILESDIR}/${P}"-audio4-p6.patch
	epatch "${FILESDIR}/${P}"-audio4-p7.patch
	epatch "${FILESDIR}/${P}"-rtvg.patch #424377
	epatch "${FILESDIR}/${P}"-samba-4.patch

	if has_version dev-libs/libcdio-paranoia; then
		sed -i -e 's:cdio/cdda.h:cdio/paranoia/cdda.h:' src/plugins/cdda/cdda.c || die
	fi
	epatch_user
}

src_configure() {
	# ./configure alike options.
	local waf_params="--prefix=/usr \
			--libdir=/usr/$(get_libdir) \
			--with-target-platform=${CHOST} \
			--mandir=/usr/share/man \
			--infodir=/usr/share/info \
			--datadir=/usr/share \
			--sysconfdir=/etc \
			--localstatedir=/var/lib"

	local optionals=""
	local plugins=""
	if ! use server ; then
		waf_params+=" --without-xmms2d"
	else
		# some fun static mappings:
		local option_map=(	# USE		# sorted xmms2 option flag (same, as USE if empty)
					"phonehome	et"
					"ENABLED	launcher"
					"mlib-update	medialib-updater"
					"ENABLED	nycli"
					"		perl"
					"ENABLED	pixmaps"
					"		python"
					"		ruby"
					"DISABLED	tests"
					"DISABLED	vistest"
					"cxx		xmmsclient++"
					"cxx		xmmsclient++-glib"
					"DISABLED	xmmsclient-cf"
					"DISABLED	xmmsclient-ecore" # not in tree

					"test		tests"
				)

		local plugin_map=(	# USE		# sorted xmms2 plugin flag (same, as USE if empty)
					"		alsa"
					"		airplay"
					"		ao"
					"ffmpeg		apefile"
					"ffmpeg		avcodec"
					"		asf"
					"ENABLED	asx"
					"		cdda"
					"DISABLED	coreaudio" # MacOS only?
					"		curl"
					"ENABLED	cue"
					"zeroconf	daap"
					"ENABLED	diskwrite"
					"ENABLED	equalizer"
					"aac		faad"
					"ENABLED	file"
					"		flac"
					"ffmpeg		flv"
					"ffmpeg		tta"
					"DISABLED	gme" # not in tree
					"		gvfs"
					"ENABLED	html"
					"		ices"
					"ENABLED	icymetaint"
					"ENABLED	id3v2"
					"		jack"
					"ENABLED	karaoke"
					"ENABLED	m3u"
					"		mac"
					"		mms"
					"		mad"
					"		mp4" # bug #387961 (aac, mp3, ape can sit there)
					"mp3		mpg123"
					"		modplug"
					"		musepack"
					"DISABLED	nms" # not in tree
					"ENABLED	normalize"
					"ENABLED	null"
					"ENABLED	nulstripper"
					"		ofa"
					"		oss"
					"ENABLED	pls"
					"pulseaudio	pulse"
					"ENABLED	replaygain"
					"xml		rss"
					"		samba"
					"DISABLED	sc68" #not in tree
					"		sid"
					"		sndfile"
					"		speex"
					"DISABLED	sun" # {Open,Net}BSD only
					"DISABLED	tremor" # not in tree
					"		vorbis"
					"		vocoder"
					"ffmpeg		tta"
					"ENABLED	wave"
					"DISABLED	waveout" # windows only
					"		wavpack"
					"xml		xspf"
					"ENABLED	xml"
				)

		local option
		for option in "${option_map[@]}"; do
			optionals+=$(xmms2_flag $option)
		done

		local plugin
		for plugin in "${plugin_map[@]}"; do
			plugins+=$(xmms2_flag $plugin)
		done
	fi # ! server

	# pass them explicitely even if empty as we try to avoid magic deps
	waf_params+=" --with-optionals=${optionals:1}" # skip first ',' if yet
	waf_params+=" --with-plugins=${plugins:1}"
	waf_params+=" $(use_with valgrind)"

	CC="$(tc-getCC)"         \
	CPP="$(tc-getCPP)"       \
	AR="$(tc-getAR)"         \
	RANLIB="$(tc-getRANLIB)" \
	CXX="$(tc-getCXX)"       \
	    ./waf configure ${waf_params} || die "'waf configure' failed"
}

src_compile() {
	# waf is very keen to run tests in build phase (bug #424377) but
	# it does not bother running tests twice, so the hack below works:
	./waf --verbose build || ./waf --verbose build || die "waf build failed"
}

src_test() {
	# rerun tests
	./waf --alltests || die "waf --alltests failed"
}

src_install() {
	./waf --without-ldconfig --destdir="${D}" install || die "'waf install' failed"
	dodoc AUTHORS TODO
}

pkg_postinst() {
	elog "This version is built on experimental development code"
	elog "If you encounter any errors report them at http://bugs.xmms2.org"
	elog "and visit #xmms2 at irc://irc.freenode.net"
	if use phonehome ; then
		einfo ""
		einfo "The phone-home client xmms2-et was activated"
		einfo "This client sends anonymous usage-statistics to the xmms2"
		einfo "developers which may help finding bugs"
		einfo "Disable the phonehome useflag if you don't like that"
	fi
}

EAPI=8

inherit unpacker xdg

DESCRIPTION="Custom Discord client with Equicord preinstalled"
HOMEPAGE="https://github.com/Equicord/Equibop"
SRC_URI="https://github.com/Equicord/Equibop/releases/download/v${PV}/equibop_${PV}_amd64.deb -> ${P}.deb"
S=${WORKDIR}

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="bindist mirror strip"

RDEPEND="
	media-libs/alsa-lib
	app-accessibility/at-spi2-core
	dev-libs/glib:2
	dev-libs/expat
	app-crypt/libsecret
	net-print/cups
	dev-libs/nss
	sys-apps/dbus
	x11-libs/cairo
	x11-libs/libdrm
	x11-libs/libXext
	x11-libs/libXScrnSaver
	x11-libs/libxshmfence
	x11-libs/gtk+:3
	x11-libs/pango
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libXtst
	x11-libs/libxkbcommon
	media-libs/mesa[gbm(+)]
	x11-misc/xdg-utils
"
BDEPEND="$(unpacker_src_uri_depends)"

QA_PREBUILT="opt/* usr/lib/*"

src_unpack() { unpacker_src_unpack; }

src_install() {
	# Keep the upstream package's paths and executable modes intact.
	if [[ -d opt ]]; then cp -a opt "${ED}/"; fi
	if [[ -d usr ]]; then cp -a usr "${ED}/"; fi
	if [[ -d etc ]]; then cp -a etc "${ED}/"; fi
}

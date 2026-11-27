# Copyright 2026 Reedman27
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 optfeature toolchain-funcs xdg

DESCRIPTION="Add-ons for Window Maker: notifications, file browser, media keys, menus, themed from your wmaker theme"
HOMEPAGE="https://github.com/Reedman27/wm-desktop"
EGIT_REPO_URI="https://github.com/Reedman27/wm-desktop.git"

LICENSE="MIT"
SLOT="0"
IUSE="+files +mediakeys +notify +wraster +xinerama test"
RESTRICT="!test? ( test )"
# libwraster only matters to the programs that draw (wmfiles, wmnotify)
REQUIRED_USE="
	wraster? ( || ( files notify ) )
	xinerama? ( mediakeys )
"

# libwraster is built and installed by x11-wm/windowmaker (wrlib.pc); check with: equery f windowmaker | grep wrlib
DEPEND="
	x11-libs/libX11
	files? (
		x11-libs/libXft
		media-libs/fontconfig
	)
	notify? (
		x11-libs/libXft
		media-libs/fontconfig
		sys-apps/dbus
	)
	mediakeys? (
		x11-libs/libXft
		media-libs/fontconfig
	)
	xinerama? ( x11-libs/libXinerama )
	wraster? ( x11-wm/windowmaker )
"
RDEPEND="${DEPEND}"
BDEPEND="
	virtual/pkgconfig
	test? (
		x11-base/xorg-server[xvfb]
		sys-apps/dbus
		dev-libs/glib:2
		media-fonts/dejavu
		x11-misc/xdotool
	)
"

src_configure() {
	# the project is a plain Makefile; its switches are WITH_x=yes|no (yes = fail if the library is missing)
	MY_EMAKE=(
		PREFIX="${EPREFIX}/usr"
		WITH_FILES=$(usex files yes no)
		WITH_MEDIAKEYS=$(usex mediakeys yes no)
		WITH_XINERAMA=$(usex xinerama yes no)
		WITH_NOTIFY=$(usex notify yes no)
		WITH_WRASTER=$(usex wraster yes no)
	)
	tc-export CC PKG_CONFIG
}

src_compile() {
	emake "${MY_EMAKE[@]}"
}

src_test() {
	# starts its own Xvfb and private D-Bus; needs no display from the build user
	emake "${MY_EMAKE[@]}" check
}

src_install() {
	emake "${MY_EMAKE[@]}" DESTDIR="${D}" install
	einstalldocs
}

pkg_postinst() {
	xdg_pkg_postinst
	elog "To start wmmenud, wmnotify and wmmediakeys with Window Maker:  wm-autostart install"
	elog "(it only edits its own marked block in ~/GNUstep/Library/WindowMaker/autostart)"
	elog "Only one notification daemon can own org.freedesktop.Notifications; stop dunst/mako first."
	if use mediakeys; then
		elog "wmmediakeys finds its helpers at run time; keys already bound in sxhkd/xbindkeys are left to them."
		optfeature "volume keys (PipeWire)" media-video/wireplumber
		optfeature "volume keys (PulseAudio)" media-libs/libpulse
		optfeature "volume keys (plain ALSA)" media-sound/alsa-utils
		optfeature "play/pause/next keys for MPRIS players" media-sound/playerctl
		optfeature "play/pause/next keys for MPD" media-sound/mpc
		optfeature "brightness keys without a udev rule" app-misc/brightnessctl
		optfeature "default browser/mail/file manager for the launcher keys" x11-misc/xdg-utils
	fi
}

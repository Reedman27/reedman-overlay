# Copyright 2026 Reedman27
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo desktop git-r3 xdg

DESCRIPTION="Rust desktop client for the official Discord web app (Qt WebEngine, no Electron)"
HOMEPAGE="https://github.com/Reedman27/rustcord"
EGIT_REPO_URI="https://github.com/Reedman27/rustcord.git"

LICENSE="LGPL-3+"
SLOT="0"
# live ebuild: cargo downloads the crates while building
PROPERTIES="live"
RESTRICT="network-sandbox"

DEPEND="
	dev-qt/qtbase:6[dbus,gui,widgets]
	dev-qt/qtwebengine:6[widgets]
	sys-apps/dbus
"
RDEPEND="${DEPEND}"
BDEPEND="
	virtual/pkgconfig
	>=virtual/rust-1.75
"

src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack
}

src_compile() {
	cargo_src_compile -p rustcord-qt
}

src_install() {
	dobin "$(cargo_target_dir)/rustcord-qt"
	dosym rustcord-qt /usr/bin/rustcord
	domenu packaging/rustcord.desktop
	# the icon is drawn by the same code as the tray icon
	cargo_env cargo run --release -q -p rustcord-core --example dump -- png 256 > rustcord.png || die
	newicon -s 256 rustcord.png rustcord.png
	einstalldocs
}

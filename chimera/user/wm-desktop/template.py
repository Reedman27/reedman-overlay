# UNTESTED. Mirrors the Gentoo ebuild: plain Makefile, WITH_x switches, PREFIX/DESTDIR.
# libwraster comes from Window Maker, which cports does not package, so WITH_WRASTER=no.
# TODO: point source at a real tag/commit and fill sha256 (cbuild prints the expected hash).
pkgname = "wm-desktop"
pkgver = "0.1.0"
pkgrel = 0
build_style = "makefile"
make_build_args = ["PREFIX=/usr", "WITH_FILES=yes", "WITH_NOTIFY=yes", "WITH_WRASTER=no"]
make_install_args = ["PREFIX=/usr", "WITH_FILES=yes", "WITH_NOTIFY=yes", "WITH_WRASTER=no"]
make_check_target = "check"
hostmakedepends = ["pkgconf"]
makedepends = ["libx11-devel", "libxft-devel", "fontconfig-devel", "dbus-devel"]
pkgdesc = "Add-ons for Window Maker: notifications, file browser, menus"
maintainer = "Reedman27 <213130028+Reedman27@users.noreply.github.com>"
license = "MIT"
url = "https://github.com/Reedman27/wm-desktop"
source = f"{url}/archive/refs/tags/v{pkgver}.tar.gz"
sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
options = ["!check"]  # tests need Xvfb and a private D-Bus

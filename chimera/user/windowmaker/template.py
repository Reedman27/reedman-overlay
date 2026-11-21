pkgname = "windowmaker"
pkgver = "0.96.0"
pkgrel = 0
build_style = "gnu_configure"
configure_args = [
    "--disable-static",
    "--enable-modelock",
    "--enable-pango",
    "--enable-xinerama",
    # RandR support is left off on purpose: configure itself marks it
    # "NOT recommended, buggy"; Xinerama covers multi-monitor setups
    "--with-gnustepdir=/usr/lib/GNUstep",
]
# the release tarball ships a generated configure script, so no autoreconf
configure_gen = []
hostmakedepends = ["pkgconf"]
makedepends = [
    "fontconfig-devel",
    "freetype-devel",
    "giflib-devel",
    "libice-devel",
    "libjpeg-turbo-devel",
    "libpng-devel",
    "libsm-devel",
    "libtiff-devel",
    "libwebp-devel",
    "libx11-devel",
    "libxext-devel",
    "libxft-devel",
    "libxinerama-devel",
    "libxmu-devel",
    "libxpm-devel",
    "pango-devel",
]
pkgdesc = "NeXTSTEP-inspired window manager for X11"
license = "GPL-2.0-or-later"
url = "https://www.windowmaker.org"
source = f"https://github.com/window-maker/wmaker/releases/download/wmaker-{pkgver}/WindowMaker-{pkgver}.tar.gz"
sha256 = "4fe130ba23cf4aa21c156ec8f01f748df537d0604ec06c6bbcec896df1926f6d"
# the only tests are interactive X programs; they need a running display
# etcfiles: global defaults are installed to /etc/WindowMaker
options = ["!check", "etcfiles"]


def post_install(self):
    # KDE menu generator written in perl; Chimera has no perl in its base
    self.uninstall("usr/bin/wkdemenu.pl")
    # (upstream already installs usr/share/xsessions/wmaker.desktop)


@subpackage("windowmaker-devel")
def _(self):
    # headers and pkg-config files for libwraster, WINGs, WUtil and libWMaker
    return self.default_devel()

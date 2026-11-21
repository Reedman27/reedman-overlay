pkgname = "sxhkd"
pkgver = "0.6.2"
pkgrel = 0
build_style = "makefile"
make_build_args = ["PREFIX=/usr", "MANPREFIX=/usr/share/man"]
make_install_args = ["PREFIX=/usr", "MANPREFIX=/usr/share/man"]
hostmakedepends = ["pkgconf"]
makedepends = [
    "libxcb-devel",
    "xcb-util-devel",
    "xcb-util-keysyms-devel",
]
pkgdesc = "Simple X hotkey daemon"
license = "BSD-2-Clause"
url = "https://github.com/baskerville/sxhkd"
source = f"{url}/archive/{pkgver}.tar.gz"
# checked against upstream by scripts/pin-chimera.sh --check
sha256 = "1edc8b1a8b3631c10ba9cb9df1181830dacbbdf77adb558e31d5dd2029637386"
# upstream ships no test suite
options = ["!check"]


def post_install(self):
    self.install_license("LICENSE")

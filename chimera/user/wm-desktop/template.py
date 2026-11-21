pkgname = "wm-desktop"
# Upstream has no tagged releases yet, so this pins a commit of `main`
# (move it forward with scripts/pin-chimera.sh --force wm-desktop after editing _commit).
_commit = "097f77e97086b9383b7c70ae2c7dd5f8fed9bb92"
pkgver = "0.0.20261118"
pkgrel = 0
build_style = "makefile"
make_build_args = [
    "WITH_FILES=yes",
    "WITH_NOTIFY=yes",
    "WITH_WRASTER=yes",
]
# plain Makefile; its install target honours PREFIX and DESTDIR
make_install_args = list(make_build_args)
hostmakedepends = ["pkgconf"]
makedepends = [
    "dbus-devel",
    "fontconfig-devel",
    "libx11-devel",
    "libxft-devel",
    # libwraster (wrlib.pc) is built by the windowmaker template
    "windowmaker-devel",
]
depends = ["windowmaker"]
pkgdesc = "Add-ons for Window Maker: notifications, file browser, menus"
license = "MIT"
url = "https://github.com/Reedman27/wm-desktop"
source = f"{url}/archive/{_commit}.tar.gz"
# filled in by scripts/pin-chimera.sh (needs network access to github.com)
sha256 = "7c6e37b4d0a6a9af885fde9ca12bad294a641c562aa77bdb53d71fdeb0e85851"
# the tests start Xvfb, xdotool and a private D-Bus; not in the build container
options = ["!check"]


def post_install(self):
    self.install_license("LICENSE")

pkgname = "wm-desktop"
# Upstream has no tagged releases yet, so this pins a commit of `main`
# (move it forward with scripts/pin-chimera.sh --force wm-desktop after editing _commit).
_commit = "91859fd7e4096351335d03ba98a06b031a25b818"
pkgver = "0.0.20261127"
pkgrel = 0
build_style = "makefile"
make_build_args = [
    "WITH_FILES=yes",
    "WITH_MEDIAKEYS=yes",
    "WITH_XINERAMA=yes",
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
    "libxinerama-devel",
    # libwraster (wrlib.pc) is built by the windowmaker template
    "windowmaker-devel",
]
# wmmediakeys calls wpctl/playerctl/mpc/brightnessctl at run time and reports missing ones
depends = ["windowmaker"]
pkgdesc = "Add-ons for Window Maker: notifications, file browser, media keys, menus"
license = "MIT"
url = "https://github.com/Reedman27/wm-desktop"
source = f"{url}/archive/{_commit}.tar.gz"
# filled in by scripts/pin-chimera.sh (needs network access to github.com)
sha256 = "0a82879236343348b633cbdeddb2300cadf67eba03373fa3b350da69bf17d364"
# the tests start Xvfb, xdotool and a private D-Bus; not in the build container
options = ["!check"]


def post_install(self):
    self.install_license("LICENSE")

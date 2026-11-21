pkgname = "wmmedia"
# dockapps-collection has no tagged releases; this pins a commit of `main`
# (move it forward with scripts/pin-chimera.sh --force wmmedia after editing _commit).
_commit = "c8d9cb8f91c1e88515bf36839057c5d5a4fc23b7"
pkgver = "0.0.20261121"
pkgrel = 0
build_wrksrc = "wmmedia"
build_style = "makefile"
make_build_args = ["PREFIX=/usr"]
make_install_args = ["PREFIX=/usr"]
hostmakedepends = ["pkgconf"]
makedepends = [
    "libx11-devel",
    "libxext-devel",
]
depends = ["playerctl"]
pkgdesc = "Media-control dockapp for Window Maker"
license = "MIT"
url = "https://github.com/Reedman27/dockapps-collection"
source = f"{url}/archive/{_commit}.tar.gz"
# filled in by scripts/pin-chimera.sh (needs network access to github.com)
sha256 = "0aca4b2bb2caacf88f0e975bb59515052981b3ad8af7b38dbb53eca4bfbfd4b8"
# the tests start Xvfb and fake players; not available in the build container
options = ["!check"]


def post_install(self):
    self.install_license("LICENSE")

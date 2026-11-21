pkgname = "rustcord"
# rustcord has no tagged releases yet; this pins a commit of `main`
# (move it forward with scripts/update-pins.sh, then scripts/pin-chimera.sh --force rustcord).
_commit = "820a799ab12edfdd5e20124926d3086262a3bdce"
pkgver = "0.1.0.20261120"
pkgrel = 0
build_style = "cargo"
make_build_args = ["-p", "rustcord-qt"]
hostmakedepends = ["cargo-auditable", "pkgconf"]
makedepends = [
    "dbus-devel",
    "qt6-qtbase-devel",
    "qt6-qtwebengine-devel",
    "rust-std",
]
depends = ["qt6-qtwebengine"]
pkgdesc = "Rust desktop client for the official Discord web app"
license = "LGPL-3.0-or-later"
url = "https://github.com/Reedman27/rustcord"
source = f"{url}/archive/{_commit}.tar.gz"
# filled in by scripts/pin-chimera.sh (needs network access to github.com;
# a private repository needs a token, so make it public first)
sha256 = "cf24b05e5020b2582b37b435b0d5bd5d1f6ffd73ea80d6fe08f305d4637856c9"
# the tests need a display and a network connection
options = ["!check"]


def install(self):
    from cbuild.util import cargo

    self.install_bin(cargo.target_path(self, "rustcord-qt"))
    self.install_link("usr/bin/rustcord", "rustcord-qt")
    self.install_file("packaging/rustcord.desktop", "usr/share/applications")
    # generated from the code that draws the tray icon (cargo run -p rustcord-core
    # --example dump -- png 256); kept as a file so cross builds need not run it
    self.install_file(
        self.files_path / "rustcord.png",
        "usr/share/icons/hicolor/256x256/apps",
    )
    self.install_license("COPYING.LESSER")

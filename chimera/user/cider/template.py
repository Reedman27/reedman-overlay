# EXPERIMENTAL / UNTESTED. Chimera is musl-only and Cider is a glibc Electron
# binary, so this repackages it but the app very likely will not start without
# a glibc chroot/container. Nothing in reedman-meta depends on it.
pkgname = "cider"
pkgver = "4.0.17"
pkgrel = 0
broken = "Prebuilt Cider is a glibc Electron package and has not been adapted for Chimera musl."
archs = ["x86_64"]
pkgdesc = "Apple Music client by Cider Collective (prebuilt binary)"
license = "custom:proprietary"
url = "https://cider.sh"
_deb = f"cider-v{pkgver}-linux-x64.deb"
source = f"https://repo.cider.sh/apt/pool/main/{_deb}"
# scripts/bump-chimera.sh fills this in (needs network access to repo.cider.sh)
sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
skip_extraction = [_deb]
options = ["!strip", "!check", "!scanrundeps", "!scanshlibs"]


def install(self):
    # the deb ships everything in /usr/lib/cider; keep it in /opt like the Gentoo ebuild
    self.do(
        "sh",
        "-c",
        f"bsdtar -xf '{self.sources_path}/{_deb}' && "
        f"bsdtar -xf data.tar.* -C '{self.destdir}' && "
        f"mkdir -p '{self.destdir}/opt' && "
        f"mv '{self.destdir}/usr/lib/cider' '{self.destdir}/opt/cider'",
    )
    self.install_link("usr/bin/cider", "../../opt/cider/Cider")

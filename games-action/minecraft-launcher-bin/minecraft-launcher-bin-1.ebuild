# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker xdg

DESCRIPTION="Official Minecraft Launcher (repackaged from Mojang's .deb)"
HOMEPAGE="https://www.minecraft.net"
SRC_URI="https://launcher.mojang.com/download/Minecraft.deb -> ${P}.deb"
S="${WORKDIR}"

LICENSE="Mojang-EULA"
SLOT="0"
KEYWORDS="-* ~amd64"
# Fetch-restricted: the deb is unversioned upstream, so a download would break
# the Manifest as soon as Mojang updates it. Drop your copy into DISTDIR.
RESTRICT="bindist mirror fetch strip"

RDEPEND="
    dev-libs/nss
    media-libs/alsa-lib
    media-libs/libpulse
    media-libs/mesa
    net-misc/curl
    sys-apps/dbus
    virtual/jre:21
    x11-libs/gtk+:3
    x11-libs/libX11
    x11-libs/libXScrnSaver
    x11-libs/libXtst
    x11-misc/xdg-utils
"
BDEPEND="$(unpacker_src_uri_depends)"

QA_PREBUILT="opt/minecraft-launcher/*"

pkg_nofetch() {
    einfo "Download Minecraft.deb from ${HOMEPAGE}/download and copy it to:"
    einfo "  ${DISTDIR}/${P}.deb"
    einfo "then run: ebuild minecraft-launcher-bin-${PVR}.ebuild manifest"
}

src_unpack() {
    unpacker_src_unpack
}

src_install() {
    [[ -d opt/minecraft-launcher ]] || die "unexpected deb layout"
    insinto /opt
    doins -r opt/minecraft-launcher

    # make the bundled executables executable again
    local f
    while IFS= read -r -d '' f; do
        fperms +x "/${f}"
    done < <(find opt/minecraft-launcher -type f \
        \( -name 'minecraft-launcher' -o -name '*.so*' -o -name 'chrome-sandbox' -o -name 'crashpad_handler' \) -print0)

    dosym ../../opt/minecraft-launcher/minecraft-launcher /usr/bin/minecraft-launcher

    if [[ -d usr/share ]]; then
        insinto /usr/share
        doins -r usr/share/.
    fi
}

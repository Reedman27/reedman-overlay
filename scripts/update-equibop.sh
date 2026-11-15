#!/usr/bin/env bash
# Pin an Equibop release and its locally computed SHA-256 across native package recipes.
# Usage: scripts/update-equibop.sh [VERSION]   (no argument = newest upstream release)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
VER="${1:-}"
if [[ -z "$VER" ]]; then
  loc="$(curl -fsS -o /dev/null -w '%{redirect_url}' https://github.com/Equicord/Equibop/releases/latest || true)"
  VER="${loc##*/v}"
  [[ "$VER" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "Could not detect the newest Equibop release; pass a version explicitly." >&2; exit 1; }
  echo "Newest Equibop release: $VER"
fi
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
URL="https://github.com/Equicord/Equibop/releases/download/v${VER}/equibop_${VER}_amd64.deb"
curl -fL "$URL" -o "$TMP"
[[ "$(head -c 7 "$TMP")" == '!<arch>' ]] || { echo "Downloaded file is not a Debian archive" >&2; exit 1; }
SUM="$(sha256sum "$TMP" | awk '{print $1}')"
printf '%s\n' "$VER" > "$HERE/EQUIBOP_VERSION"
printf '%s\n' "$SUM" > "$HERE/EQUIBOP_SHA256"

sed -i -E "s/^pkgver=.*/pkgver=${VER}/; s/^sha256sums=.*/sha256sums=('${SUM}')/" "$HERE/arch/equibop-bin/PKGBUILD"
sed -i -E "s/^version=.*/version=${VER}/; s|^distfiles=.*|distfiles=\"${URL}\"|; s/^checksum=.*/checksum=\"${SUM}\"/" "$HERE/void/srcpkgs/equibop-bin/template"
sed -i -E "s/^Version:.*/Version:        ${VER}/; s|^Source0:.*|Source0:        ${URL}|" "$HERE/rpm/equibop-bin.spec"
cp "$HERE/rpm/equibop-bin.spec" "$HERE/opensuse/equibop-bin.spec"
rm -f "$HERE/net-im/equibop-bin"/equibop-bin-*.ebuild
cat > "$HERE/net-im/equibop-bin/equibop-bin-${VER}.ebuild" <<Ebuild
EAPI=8
inherit unpacker xdg
DESCRIPTION="Custom Discord client with Equicord preinstalled"
HOMEPAGE="https://github.com/Equicord/Equibop"
SRC_URI="${URL} -> \${P}.deb"
S=\"\${WORKDIR}\"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="mirror"
RDEPEND="media-libs/alsa-lib app-accessibility/at-spi2-core dev-libs/glib:2 dev-libs/expat app-crypt/libsecret net-print/cups dev-libs/nss sys-apps/dbus x11-libs/cairo x11-libs/libdrm x11-libs/libXext x11-libs/libXScrnSaver x11-libs/libxshmfence x11-libs/gtk+:3 x11-libs/pango x11-libs/libX11 x11-libs/libxcb x11-libs/libXcomposite x11-libs/libXdamage x11-libs/libXfixes x11-libs/libXrandr x11-libs/libXScrnSaver x11-libs/libXtst x11-libs/libxkbcommon media-libs/mesa[gbm(+)] x11-misc/xdg-utils"
BDEPEND="\$(unpacker_src_uri_depends)"
QA_PREBUILT="opt/* usr/lib/*"
src_unpack() { unpacker_src_unpack; }
src_install() {
  [[ ! -d opt ]] || cp -a opt "\${ED}/"
  [[ ! -d usr ]] || cp -a usr "\${ED}/"
  [[ ! -d etc ]] || cp -a etc "\${ED}/"
}
Ebuild
printf 'Equibop %s pinned; SHA-256: %s\n' "$VER" "$SUM"
printf 'On Gentoo, generate the Manifest with: ebuild net-im/equibop-bin/equibop-bin-%s.ebuild manifest\n' "$VER"

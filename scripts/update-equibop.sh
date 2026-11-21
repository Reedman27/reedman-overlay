#!/usr/bin/env bash
# Pin an Equibop release and its locally computed SHA-256 across native package recipes.
# Usage: scripts/update-equibop.sh [VERSION]   (no argument = newest upstream release)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/deb-common.sh
. "$HERE/scripts/deb-common.sh"
VER="${1:-}"
if [[ -z "$VER" ]]; then
  loc="$(curl -fsS -o /dev/null -w '%{redirect_url}' https://github.com/Equicord/Equibop/releases/latest)"
  VER="${loc##*/v}"
  [[ "$VER" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "Could not detect the newest Equibop release; pass a version explicitly." >&2; exit 1; }
  echo "Newest Equibop release: $VER"
  current="$(cat "$HERE/EQUIBOP_VERSION" 2>/dev/null || true)"
  if [[ "$VER" == "$current" && "${EQUIBOP_FORCE:-0}" != 1 ]]; then
    echo "Equibop is already current ($VER); skipping download."
    exit 0
  fi
fi
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
URL="https://github.com/Equicord/Equibop/releases/download/v${VER}/equibop_${VER}_amd64.deb"
curl -fL --retry 3 "$URL" -o "$TMP"
# Structure and metadata first: it must be a Debian package named equibop for amd64 at this version.
verify_equibop --metadata-only "$TMP" "$VER" || exit 1
SUM="$(sha256sum "$TMP" | awk '{print $1}')"
# A release that is already pinned must never silently change under us: that would mean upstream replaced the file.
OLD_SUM="$(tr -d '[:space:]' < "$HERE/EQUIBOP_SHA256" 2>/dev/null || true)"
if [[ "$VER" == "$(cat "$HERE/EQUIBOP_VERSION" 2>/dev/null || true)" && -n "$OLD_SUM" && "$SUM" != "$OLD_SUM" && "${EQUIBOP_FORCE:-0}" != 1 ]]; then
  echo "Equibop $VER is already pinned with SHA-256 $OLD_SUM but the download hashes to $SUM." >&2
  echo "Upstream may have replaced the release file. Investigate; set EQUIBOP_FORCE=1 only if you trust the new file." >&2
  exit 1
fi
if [[ -n "${EQUIBOP_ARTIFACT_DIR:-}" ]]; then
  mkdir -p "$EQUIBOP_ARTIFACT_DIR"
  cp "$TMP" "$EQUIBOP_ARTIFACT_DIR/equibop_${VER}_amd64.deb"
fi
printf '%s\n' "$VER" > "$HERE/EQUIBOP_VERSION"
printf '%s\n' "$SUM" > "$HERE/EQUIBOP_SHA256"

sed -i -E "s/^pkgver=.*/pkgver=${VER}/; s/^sha256sums=.*/sha256sums=('${SUM}')/" "$HERE/arch/equibop-bin/PKGBUILD"
sed -i -E "s/^version=.*/version=${VER}/; s|^distfiles=.*|distfiles=\"${URL}\"|; s/^checksum=.*/checksum=\"${SUM}\"/" "$HERE/void/srcpkgs/equibop-bin/template"
if [[ "${EQUIBOP_SKIP_GENTOO:-0}" != 1 ]]; then
  rm -f "$HERE/net-im/equibop-bin"/equibop-bin-*.ebuild
  cat > "$HERE/net-im/equibop-bin/equibop-bin-${VER}.ebuild" <<Ebuild
EAPI=8
inherit unpacker xdg
DESCRIPTION="Custom Discord client with Equicord preinstalled"
HOMEPAGE="https://github.com/Equicord/Equibop"
SRC_URI="${URL} -> \${P}.deb"
S="\${WORKDIR}"
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
else
  echo "Skipping Gentoo ebuild update (EQUIBOP_SKIP_GENTOO=1)."
fi

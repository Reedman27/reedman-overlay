#!/usr/bin/env bash
# Point chimera/user/cider/template.py at the version in the overlay's cider-bin ebuild
# and fill in its sha256 (downloads the .deb, so it needs access to repo.cider.sh).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$HERE/chimera/user/cider/template.py"
eb="$(ls "$HERE"/overlay/media-sound/cider-bin/cider-bin-*.ebuild | sort -V | tail -n1)"
pv="${eb##*/cider-bin-}"; pv="${pv%.ebuild}"
deb="cider-v$pv-linux-x64.deb"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://repo.cider.sh/apt/pool/main/$deb" -o "$tmp/$deb"
[[ "$(head -c 7 "$tmp/$deb")" == '!<arch>' ]] || { echo "not a .deb" >&2; exit 1; }
sum="$(sha256sum "$tmp/$deb" | cut -d' ' -f1)"
sed -i -e "s/^pkgver = .*/pkgver = \"$pv\"/" -e "s/^sha256 = .*/sha256 = \"$sum\"/" "$T"
echo "cider $pv sha256 $sum"

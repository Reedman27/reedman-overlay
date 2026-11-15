#!/usr/bin/env bash
# Build every RPM into out/ (run on Fedora; needs rpm-build, git, curl, binutils). Needs keys/RPM-GPG-KEY.
# Includes the hosted wm-desktop and minecraft-launcher-bin; Cider uses its own repo (reedmuhn-cider-repo).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
VER="$(cat "$HERE/VERSION")"
python3 "$HERE/scripts/gen.py" >/dev/null
[[ -s "$HERE/keys/RPM-GPG-KEY" ]] || { echo "keys/RPM-GPG-KEY missing: run scripts/fetch-keys.sh" >&2; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T"/{SOURCES,SPECS,BUILD,RPMS,SRPMS}
cp "$HERE/rpm/cider.repo" "$HERE/keys/RPM-GPG-KEY" "$T/SOURCES/"
SPEC_DIR="${SPEC_DIR:-$HERE/rpm}"
cp "$SPEC_DIR"/*.spec "$T/SPECS/"
# hosted packages: wm-desktop (source tarball from git) and minecraft-launcher-bin (Mojang's .deb, never committed)
WMV=0.1.0
git clone --depth 1 "${WM_DESKTOP_URL:-https://github.com/Reedman27/wm-desktop.git}" "$T/wm-desktop-$WMV"
rm -rf "$T/wm-desktop-$WMV/.git"; tar -C "$T" -czf "$T/SOURCES/wm-desktop-$WMV.tar.gz" "wm-desktop-$WMV"
curl -fSL "${MC_DEB_URL:-https://launcher.mojang.com/download/Minecraft.deb}" -o "$T/SOURCES/Minecraft.deb"
EQV="${EQUIBOP_VERSION:-$(cat "$HERE/EQUIBOP_VERSION")}"
curl -fSL "https://github.com/Equicord/Equibop/releases/download/v${EQV}/equibop_${EQV}_amd64.deb" -o "$T/SOURCES/equibop_${EQV}_amd64.deb"
if [[ -s "$HERE/EQUIBOP_SHA256" ]]; then expected="$(cat "$HERE/EQUIBOP_SHA256")"; actual="$(sha256sum "$T/SOURCES/equibop_${EQV}_amd64.deb" | awk '{print $1}')"; [[ "$expected" == "$actual" ]] || { echo "Equibop checksum mismatch; run scripts/update-equibop.sh ${EQV}" >&2; exit 1; }; fi
curl -fSL "https://repo.cider.sh/apt/pool/main/cider-v4.0.17-linux-x64.deb" -o "$T/SOURCES/cider-v4.0.17-linux-x64.deb"
[[ "$(head -c 7 "$T/SOURCES/Minecraft.deb")" == '!<arch>' ]] || { echo "Minecraft.deb is not a .deb" >&2; exit 1; }
ar p "$T/SOURCES/Minecraft.deb" "$(ar t "$T/SOURCES/Minecraft.deb" | grep '^control\.tar' | head -n1)" > "$T/control.tar"
raw="$(tar -xOf "$T/control.tar" ./control 2>/dev/null || tar -xOf "$T/control.tar" control)"
MCV="$(sed -n 's/^Version: *//p' <<<"$raw" | head -n1)"; MCV="${MCV%%[!0-9.]*}"
for s in "$T"/SPECS/*.spec; do
	rpmbuild -bb --define "_topdir $T" --define "pkgver $VER" --define "mcver $MCV" "$s"
done
mkdir -p "$HERE/out"; cp "$T"/RPMS/*/*.rpm "$HERE/out/"
ls -l "$HERE/out"/*.rpm

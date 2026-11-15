#!/usr/bin/env bash
# Download Mojang's official Minecraft launcher .deb, read its version from the
# package and generate games-action/minecraft-launcher-bin/minecraft-launcher-bin-<ver>.ebuild
# (+ Manifest) for it.
#
#   scripts/bump-minecraft.sh            # make/refresh the ebuild
#   scripts/bump-minecraft.sh --commit   # ...and git commit it
#
# Mojang's URL is unversioned: it always serves the newest launcher. So when
# Mojang releases an update, emerge fails with a checksum mismatch until you
# run this script again (and push the result).
set -euo pipefail

URL="${DEB_URL:-https://launcher.mojang.com/download/Minecraft.deb}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PKGDIR="$HERE/games-action/minecraft-launcher-bin"
TMPL="$HERE/scripts/minecraft-launcher-bin.ebuild.in"

# download into your own home, so no portage group is needed
export DISTDIR="${DISTDIR:-$HOME/.cache/minecraft-launcher-bin-distfiles}"
mkdir -p "$DISTDIR" "$PKGDIR"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "downloading $URL"
curl -fSL -o "$tmp/Minecraft.deb" "$URL"
[[ "$(head -c 7 "$tmp/Minecraft.deb")" == '!<arch>' ]] || { echo "downloaded file is not a .deb" >&2; exit 1; }

# version from the deb's control file
if command -v dpkg-deb >/dev/null; then
    raw="$(dpkg-deb -f "$tmp/Minecraft.deb" Version)"
else
    member="$(ar t "$tmp/Minecraft.deb" | grep '^control\.tar' | head -n1)"
    ar p "$tmp/Minecraft.deb" "$member" > "$tmp/control.tar"
    ctl="$(tar -xOf "$tmp/control.tar" ./control 2>/dev/null || tar -xOf "$tmp/control.tar" control)"
    raw="$(sed -n 's/^Version: *//p' <<<"$ctl" | head -n1)"
fi
pv="${raw%%[!0-9.]*}"
[[ "$pv" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "can't make a Gentoo version out of '$raw'" >&2; exit 1; }

ebuild="$PKGDIR/minecraft-launcher-bin-$pv.ebuild"
dist="$DISTDIR/minecraft-launcher-bin-$pv.deb"
cp "$tmp/Minecraft.deb" "$dist"
echo "upstream version: $pv (deb says '$raw')"

# nothing to do if the Manifest already pins exactly these bytes
sum="$(sha512sum "$dist" | cut -d' ' -f1)"
if [[ -e "$ebuild" ]] && grep -q "^DIST minecraft-launcher-bin-$pv.deb .*SHA512 $sum" "$PKGDIR/Manifest" 2>/dev/null; then
    echo "already up to date: $ebuild"; exit 0
fi

# back up first so a failure leaves the repo as it was
bk="$(mktemp -d)"
cp -a "$PKGDIR/." "$bk/"
restore() { rm -rf "$PKGDIR"; mkdir -p "$PKGDIR"; cp -a "$bk/." "$PKGDIR/"; rm -rf "$bk"; }

sed "s|@URI@|$URL|" "$TMPL" > "$ebuild"
# only the newest ebuild is kept (git history has the old ones)
find "$PKGDIR" -name 'minecraft-launcher-bin-*.ebuild' ! -name "minecraft-launcher-bin-$pv.ebuild" -print -delete
rm -f "$PKGDIR/Manifest"

if ! ebuild "$ebuild" manifest; then
    echo "manifest failed, restoring the previous files" >&2
    restore; exit 1
fi
rm -rf "$bk"

if [[ ! -e "$PKGDIR/metadata.xml" ]]; then
    cat > "$PKGDIR/metadata.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE pkgmetadata SYSTEM "https://www.gentoo.org/dtd/metadata.dtd">
<pkgmetadata>
  <maintainer type="person">
    <email>packages@reedmuhn.invalid</email>
    <name>Reedman27</name>
  </maintainer>
  <longdescription>
    Official Minecraft Launcher, repackaged from Mojang's Debian package.
    Regenerate with scripts/bump-minecraft.sh when Mojang ships an update.
  </longdescription>
</pkgmetadata>
XML
fi

if [[ "${1:-}" == "--commit" ]]; then
    git -C "$HERE" add -A games-action/minecraft-launcher-bin
    git -C "$HERE" commit -m "games-action/minecraft-launcher-bin: bump to $pv" || true
fi
echo "done: emerge -aq games-action/minecraft-launcher-bin"

#!/usr/bin/env bash
# Find the newest cider-v<ver>-linux-x64.deb in Cider Collective's apt pool and
# generate media-sound/cider-bin/cider-bin-<ver>.ebuild (+ Manifest) for it.
# Reads the pool directory listing directly: the repo's Packages index has been
# empty since Aug 2026, so apt-style lookups find nothing.
#
#   scripts/bump-cider.sh            # make/refresh the ebuild
#   scripts/bump-cider.sh --commit   # ...and git commit it
#   ARCH=arm64 scripts/bump-cider.sh # other arch (also change KEYWORDS yourself)
set -euo pipefail

POOL_URL="${POOL_URL:-https://repo.cider.sh/apt/pool/}"
ARCH="${ARCH:-x64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PKGDIR="$HERE/media-sound/cider-bin"
TMPL="$HERE/scripts/cider-bin.ebuild.in"

# Download into your own home, so no extra privileges (no portage group) are
# needed. `emerge` later fetches + hash-checks it itself, as root.
export DISTDIR="${DISTDIR:-$HOME/.cache/cider-bin-distfiles}"
mkdir -p "$DISTDIR"

crawl() {
	local l
	for l in $(curl -fsSL "$1" | grep -o 'href="[^"?]*"' | cut -d'"' -f2 | grep -v '^\.\./$'); do
		case "$l" in
			*/) crawl "$1$l" ;;
			*-linux-"$ARCH".deb) echo "$1$l" ;;
		esac
	done
}

# LISTING_FILE: a saved list of URLs, for testing without the network
if [[ -n "${LISTING_FILE:-}" ]]; then urls="$(grep -E -- "-linux-$ARCH\.deb$" "$LISTING_FILE")"
else urls="$(crawl "$POOL_URL")"; fi
[[ -n "$urls" ]] || { echo "no *-linux-$ARCH.deb files found under $POOL_URL" >&2; exit 1; }

# newest by version number: cider-v4.0.17-linux-x64.deb -> 4.0.17
uri="$(while read -r u; do
	v="${u##*/cider-v}"; v="${v%-linux-$ARCH.deb}"
	[[ "$v" =~ ^[0-9]+(\.[0-9]+)*$ ]] && echo "$v $u"
done <<<"$urls" | sort -V | tail -n1)"
pv="${uri%% *}"; uri="${uri#* }"
ebuild="$PKGDIR/cider-bin-$pv.ebuild"

echo "newest upstream: $pv  ($uri)"
# up to date only if the ebuild is auto-download AND has a Manifest with its hashes
if [[ -e "$ebuild" && -s "$PKGDIR/Manifest" ]] && ! grep -q 'fetch' "$ebuild"; then
	echo "already have $ebuild, nothing to do"; exit 0
fi
[[ -e "$ebuild" ]] && echo "(re)generating $ebuild and its Manifest"

# back everything up first so a failed download leaves the repo as it was
bk="$(mktemp -d)"
cp -a "$PKGDIR/." "$bk/"
restore() { rm -rf "$PKGDIR"; mkdir -p "$PKGDIR"; cp -a "$bk/." "$PKGDIR/"; rm -rf "$bk"; }

sed "s|@URI@|$uri|" "$TMPL" > "$ebuild"

# only the newest ebuild is kept (git history has the old ones); the Manifest is
# rebuilt from scratch so stale DIST lines for old distfiles don't linger
find "$PKGDIR" -name 'cider-bin-*.ebuild' ! -name "cider-bin-$pv.ebuild" -print -delete
rm -f "$PKGDIR/Manifest"

if ! ebuild "$ebuild" manifest; then      # downloads the deb and records its hashes
	echo "download/manifest failed, restoring the previous files" >&2
	restore; exit 1
fi

# sanity: it must really be a .deb (ar archive), not an HTML error page
dist="$DISTDIR/cider-bin-$pv.deb"
if [[ -r "$dist" ]] && [[ "$(head -c 7 "$dist")" != '!<arch>' ]]; then
	echo "downloaded file is not a .deb, restoring the previous files" >&2
	restore; exit 1
fi
rm -rf "$bk"
# Note: the repo's index is empty, so there is no upstream checksum to compare
# against. The Manifest now pins THIS download's hashes (trust on first use).

if [[ "${1:-}" == "--commit" ]]; then
	git -C "$HERE" add -A media-sound/cider-bin
	git -C "$HERE" commit -m "media-sound/cider-bin: bump to $pv" || true
fi
echo "done: emerge -aq media-sound/cider-bin"

#!/usr/bin/env bash
# Look at Cider Collective's apt repo, and if there is a newer cider than the
# newest ebuild here, generate media-sound/cider-bin-<ver>.ebuild + Manifest.
#
#   scripts/bump-cider.sh            # make the ebuild, update Manifest
#   scripts/bump-cider.sh --commit   # ...and git commit it
#   PKG=cider5 scripts/bump-cider.sh # if a future major gets a new package name
set -euo pipefail

REPO_URL="${REPO_URL:-https://repo.cider.sh/apt}"
SUITE="${SUITE:-stable}"
PKG="${PKG:-cider}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PKGDIR="$HERE/media-sound/cider-bin"
TMPL="$HERE/scripts/cider-bin.ebuild.in"

# PACKAGES_FILE lets you test against a saved index without the network
if [[ -n "${PACKAGES_FILE:-}" ]]; then
	index="$(cat "$PACKAGES_FILE")"
else
	index="$(curl -fsSL "$REPO_URL/dists/$SUITE/main/binary-amd64/Packages" 2>/dev/null \
		|| curl -fsSL "$REPO_URL/dists/$SUITE/main/binary-amd64/Packages.gz" | gunzip)"
fi

# newest stanza for $PKG: print "Version|Filename|SHA256"
line="$(awk -v pkg="$PKG" -v RS= -v FS='\n' '
	{ p=v=f=s=""
	  for (i=1;i<=NF;i++) {
	    if ($i ~ /^Package: /)  p=substr($i,10)
	    if ($i ~ /^Version: /)  v=substr($i,10)
	    if ($i ~ /^Filename: /) f=substr($i,11)
	    if ($i ~ /^SHA256: /)   s=substr($i,9)
	  }
	  if (p==pkg) print v "|" f "|" s }' <<<"$index" | sort -t'|' -k1,1V | tail -n1)"

[[ -n "$line" ]] || { echo "no package '$PKG' in $REPO_URL ($SUITE)" >&2; exit 1; }
IFS='|' read -r debver filename sha256 <<<"$line"

pv="${debver#*:}"        # drop epoch
pv="${pv%%-*}"           # drop debian revision
pv="${pv//[^0-9A-Za-z._]/}"
ebuild="$PKGDIR/cider-bin-$pv.ebuild"
uri="$REPO_URL/$filename"

echo "upstream: $debver  ->  cider-bin-$pv   ($uri)"
if [[ -e "$ebuild" ]]; then echo "already have $ebuild, nothing to do"; exit 0; fi

sed "s|@URI@|$uri|" "$TMPL" > "$ebuild"

# Fetch + write Manifest (needs permission to write DISTDIR, so run as root or
# in the portage group), then verify against the checksum the repo published.
ebuild "$ebuild" manifest
distfile="$(portageq distdir 2>/dev/null || echo /var/cache/distfiles)/cider-bin-$pv.deb"
if [[ -n "$sha256" && -r "$distfile" ]]; then
	got="$(sha256sum "$distfile" | cut -d' ' -f1)"
	if [[ "$got" != "$sha256" ]]; then
		echo "SHA256 MISMATCH: repo says $sha256, got $got" >&2
		rm -f "$ebuild"; exit 1
	fi
	echo "sha256 matches the apt index"
fi

# keep only the two newest ebuilds
ls "$PKGDIR"/cider-bin-*.ebuild | sort -V | head -n -2 | xargs -r rm -v

if [[ "${1:-}" == "--commit" ]]; then
	git -C "$HERE" add -A media-sound/cider-bin
	git -C "$HERE" commit -m "media-sound/cider-bin: bump to $pv"
fi
echo "done: emerge -av media-sound/cider-bin"

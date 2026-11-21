#!/usr/bin/env bash
# Resolve a branch/tag (default: HEAD) of an upstream repo to a full commit hash and write it to its pin file.
# Usage: scripts/update-pins.sh wm-desktop|dockapps|rustcord [ref]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
  wm-desktop) url=https://github.com/Reedman27/wm-desktop.git; file=WM_DESKTOP_REF ;;
  dockapps)   url=https://github.com/Reedman27/dockapps-collection.git; file=DOCKAPPS_REF ;;
  rustcord)   url=https://github.com/Reedman27/rustcord.git; file=RUSTCORD_REF ;;
  *) echo "usage: $0 wm-desktop|dockapps|rustcord [ref]" >&2; exit 2 ;;
esac
ref="${2:-HEAD}"
sha="$(git ls-remote "$url" "$ref" "$ref^{}" | awk 'END{print $1}')"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "could not resolve $ref in $url" >&2; exit 1; }
printf '# Pinned commit for %s (%s). Update with: scripts/update-pins.sh %s [ref]\n%s\n' "$url" "$ref" "$1" "$sha" > "$HERE/$file"
echo "$file -> $sha"
# keep the Chimera cports templates on the same commit; their sha256 needs re-pinning
# afterwards (scripts/pin-chimera.sh, needs network access to github.com)
case "$1" in wm-desktop) tpls=(wm-desktop) ;; dockapps) tpls=(wmvol wmmedia) ;; rustcord) tpls=(rustcord) ;; esac
for t in "${tpls[@]}"; do
  f="$HERE/chimera/user/$t/template.py"
  [[ -f "$f" ]] || continue
  sed -i -E "s/^_commit = \"[0-9a-f]{40}\"/_commit = \"$sha\"/; s/^pkgver = \"([0-9]+(\.[0-9]+)*)\.[0-9]{8}\"/pkgver = \"\1.$(date -u +%Y%m%d)\"/; s/^sha256 = \"[0-9a-f]{64}\"/sha256 = \"$(printf '0%.0s' $(seq 64))\"/" "$f"
  echo "chimera/user/$t -> $sha (sha256 reset; run scripts/pin-chimera.sh)"
done

#!/usr/bin/env bash
# Resolve a branch/tag (default: HEAD) of an upstream repo to a full commit hash and write it to its pin file.
# Usage: scripts/update-pins.sh wm-desktop|dockapps [ref]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
  wm-desktop) url=https://github.com/Reedman27/wm-desktop.git; file=WM_DESKTOP_REF ;;
  dockapps)   url=https://github.com/Reedman27/dockapps-collection.git; file=DOCKAPPS_REF ;;
  *) echo "usage: $0 wm-desktop|dockapps [ref]" >&2; exit 2 ;;
esac
ref="${2:-HEAD}"
sha="$(git ls-remote "$url" "$ref" "$ref^{}" | awk 'END{print $1}')"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "could not resolve $ref in $url" >&2; exit 1; }
printf '# Pinned commit for %s (%s). Update with: scripts/update-pins.sh %s [ref]\n%s\n' "$url" "$ref" "$1" "$sha" > "$HERE/$file"
echo "$file -> $sha"

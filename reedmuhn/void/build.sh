#!/usr/bin/env bash
# Build ReedMuhn packages with Void's native xbps-src builder.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
VOID_PACKAGES_DIR="${VOID_PACKAGES_DIR:-$HOME/void-packages}"
[[ -x "$VOID_PACKAGES_DIR/xbps-src" ]] || {
  echo "Set VOID_PACKAGES_DIR to a cloned void-packages checkout." >&2
  echo "See https://github.com/void-linux/void-packages for setup." >&2
  exit 1
}
python3 "$HERE/scripts/gen.py" >/dev/null
for src in "$HERE"/void/srcpkgs/*; do
  [[ -d "$src" ]] || continue
  cp -a "$src" "$VOID_PACKAGES_DIR/srcpkgs/"
done
for pkg in "$@"; do
  (cd "$VOID_PACKAGES_DIR" && ./xbps-src pkg "$pkg")
done
mkdir -p "$HERE/out/void"
find "$VOID_PACKAGES_DIR/hostdir/binpkgs" -maxdepth 1 -type f -name '*.xbps' -exec cp -f {} "$HERE/out/void/" \;

#!/usr/bin/env bash
# Debian/Devuan: enable what steam-installer needs: i386 multiarch plus the contrib and non-free
# components. Idempotent. Run as root. Test overrides: SOURCES_DIR, SOURCES_LIST, SKIP_DPKG=1, SKIP_UPDATE=1.
set -euo pipefail
DIR="${SOURCES_DIR:-/etc/apt/sources.list.d}"
LIST="${SOURCES_LIST:-/etc/apt/sources.list}"
[[ -n "${SKIP_DPKG:-}" || $EUID -eq 0 ]] || { echo "Run as root (or with sudo)" >&2; exit 1; }
for f in "$DIR"/*.sources; do
  [[ -f "$f" ]] || continue
  for c in contrib non-free; do
    sed -i -E "/^Components:/ { /(^|[[:space:]])$c([[:space:]]|$)/! s/\$/ $c/; }" "$f"
  done
done
if [[ -f "$LIST" ]]; then
  for c in contrib non-free; do
    sed -i -E "/^[[:space:]]*deb[[:space:]]/ { /[[:space:]]$c([[:space:]]|$)/! s/[[:space:]]main([[:space:]]|\$)/ main $c\1/; }" "$LIST"
  done
fi
[[ -n "${SKIP_DPKG:-}" ]] || dpkg --add-architecture i386
[[ -n "${SKIP_UPDATE:-}" ]] || apt-get update
echo "i386 and contrib/non-free enabled for Steam."

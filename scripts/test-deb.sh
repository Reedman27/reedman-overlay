#!/usr/bin/env bash
# Offline structural test for all generated DEB metapackages.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
command -v dpkg-deb >/dev/null || { echo 'dpkg-deb is required' >&2; exit 1; }
python3 "$HERE/scripts/gen.py"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
count=0
for d in "$HERE"/deb/reedmuhn-*/; do
  [[ -f "$d/DEBIAN/control" ]] || continue
  name="$(basename "$d")"
  [[ "$name" == reedmuhn-cider ]] && continue # requires the optional upstream Cider repository package
  cp -a "$d" "$work/$name"
  find "$work/$name" -type d -exec chmod g-s {} +
  find "$work/$name" -type d -exec chmod 755 {} +
  find "$work/$name" -type f -exec chmod 644 {} +
  dpkg-deb --root-owner-group --build "$work/$name" "$work/${name}.deb" >/dev/null
  dpkg-deb --info "$work/${name}.deb" >/dev/null
  dpkg-deb --field "$work/${name}.deb" Package | grep -Fx "$name" >/dev/null
  dpkg-deb --field "$work/${name}.deb" Architecture | grep -Fx all >/dev/null
  count=$((count + 1))
done
[[ "$count" -ge 6 ]] || { echo "Expected at least six core metapackages; built $count" >&2; exit 1; }
echo "PASS: built and inspected $count Debian metapackages"

#!/usr/bin/env bash
# Build every pacman package into out/ (metas, wm-desktop, minecraft-launcher-bin, reedmuhn-cider-repo) (run on Arch/EndeavourOS as a normal user; needs base-devel).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$HERE/scripts/gen.py" >/dev/null
[[ -s "$HERE/keys/ARCH-GPG-KEY" ]] || { echo "keys/ARCH-GPG-KEY missing: run scripts/fetch-keys.sh" >&2; exit 1; }
cp "$HERE/keys/ARCH-GPG-KEY" "$HERE/arch/reedmuhn-cider-repo/"
trap 'rm -f "$HERE/arch/reedmuhn-cider-repo/ARCH-GPG-KEY"' EXIT
mkdir -p "$HERE/out"
for d in "$HERE"/arch/*/; do
	( cd "$d" && PKGDEST="$HERE/out" makepkg -f --nodeps )
done
ls -l "$HERE/out"/*.pkg.tar.*

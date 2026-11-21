#!/usr/bin/env bash
# Build pacman packages into out/ (run on Arch/EndeavourOS as a normal user; needs base-devel).
#   arch/build.sh                    build everything
#   arch/build.sh rustcord wmvol     build only these (directory names under arch/)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$HERE/scripts/gen.py" >/dev/null
mkdir -p "$HERE/out"
if [[ $# -gt 0 ]]; then
	dirs=("$@")
else
	dirs=(); for d in "$HERE"/arch/*/; do dirs+=("$(basename "$d")"); done
fi
for d in "${dirs[@]}"; do
	[[ -d "$HERE/arch/$d" ]] || { echo "no such package directory: arch/$d" >&2; exit 2; }
	if [[ $d == reedmuhn-cider-repo ]]; then
		[[ -s "$HERE/keys/ARCH-GPG-KEY" ]] || { echo "keys/ARCH-GPG-KEY missing: run scripts/fetch-keys.sh" >&2; exit 1; }
		cp "$HERE/keys/ARCH-GPG-KEY" "$HERE/arch/reedmuhn-cider-repo/"
		trap 'rm -f "$HERE/arch/reedmuhn-cider-repo/ARCH-GPG-KEY"' EXIT
	fi
done
for d in "${dirs[@]}"; do
	( cd "$HERE/arch/$d" && PKGDEST="$HERE/out" makepkg -f --nodeps )
done
ls -l "$HERE/out"/*.pkg.tar.*

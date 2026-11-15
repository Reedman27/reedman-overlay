#!/usr/bin/env bash
# Run ON a Debian or Devuan machine (after apt-get update) to confirm every metapackage
# dependency exists in that release's repositories. Needs no root. Exit 1 if any are missing.
# Usage: scripts/check-deps.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
command -v apt-cache >/dev/null || { echo "apt-cache not found: run this on Debian/Devuan" >&2; exit 2; }
. /etc/os-release
echo "Checking against: ${PRETTY_NAME:-$ID} (${VERSION_CODENAME:-unknown})"
if [[ "${ID:-}" == devuan ]] && grep -rqs 'deb.debian.org\|ftp.debian.org' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
  echo "WARNING: Debian repositories found on a Devuan system; remove them." >&2
fi
missing=0
for c in "$HERE"/deb/reedmuhn-*/DEBIAN/control; do
  pkg="$(basename "$(dirname "$(dirname "$c")")")"
  [[ "$pkg" == reedmuhn-cider* ]] && continue
  deps="$(sed -n 's/^Depends: //p' "$c" | tr ',' '\n' | sed 's/([^)]*)//; s/|.*//; s/ //g')"
  for d in $deps; do
    [[ "$d" == wm-desktop ]] && continue   # built from source by build-deb.sh
    cand="$(apt-cache policy "$d" 2>/dev/null | sed -n 's/^ *Candidate: //p')"
    if [[ -z "$cand" || "$cand" == "(none)" ]]; then echo "MISSING  $d  (needed by $pkg)"; missing=1
    else echo "ok       $d $cand"; fi
  done
done
if [[ -f "$HERE/out/equibop_$(cat "$HERE/EQUIBOP_VERSION")_amd64.deb" ]]; then
  f="$HERE/out/equibop_$(cat "$HERE/EQUIBOP_VERSION")_amd64.deb"
  for d in $(dpkg-deb -f "$f" Depends | tr ',' '\n' | sed 's/([^)]*)//; s/|.*//; s/ //g'); do
    cand="$(apt-cache policy "$d" 2>/dev/null | sed -n 's/^ *Candidate: //p')"
    if [[ -z "$cand" || "$cand" == "(none)" ]]; then
      # t64-transition names are provided by renamed packages
      prov="$(apt-cache showpkg "$d" 2>/dev/null | sed -n '/Reverse Provides:/,$p' | sed 1d | head -1)"
      [[ -n "$prov" ]] && echo "ok       $d (provided by ${prov%% *}) [equibop]" || { echo "MISSING  $d  (needed by equibop)"; missing=1; }
    else echo "ok       $d $cand [equibop]"; fi
  done
fi
[[ $missing -eq 0 ]] && echo "All dependencies resolvable." || echo "Some dependencies are missing on this release; see above."
exit $missing

#!/usr/bin/env bash
# Run ON a Debian or Devuan machine (after `apt-get update`) to confirm that everything the ReedMuhn
# packages depend on can really be installed there. Needs no root and changes nothing.
#
#   scripts/check-deps.sh [--no-simulate]
#
# Every dependency is classified by where it comes from (deb/package-sources.conf):
#   debian/main        the normal Debian archive
#   debian/contrib     Debian archive, but a component that is not enabled by default
#   reedmuhn repo      built or mirrored by this repository and served by the ReedMuhn APT repository
#   out/               built locally into out/ but not (yet) in any configured APT repository
#   virtual            satisfied through a Provides: (for example the t64 library renames)
# Nothing is skipped. A dependency that cannot be satisfied is reported with how to fix it, and the script
# finishes with `apt-get -s install` of everything in out/ - the same resolver a real install would use.
# Exit codes: 0 all good, 1 something cannot be installed, 2 this is not a usable Debian/Devuan system.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/deb-common.sh
. "$HERE/scripts/deb-common.sh"
OUT="${OUT_DIR:-$HERE/out}"
simulate=1
case "${1:-}" in --no-simulate) simulate=0 ;; -h|--help) sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; "") ;; *) echo "unknown argument: $1" >&2; exit 2 ;; esac

command -v apt-cache >/dev/null || { echo "apt-cache not found: run this on Debian or Devuan" >&2; exit 2; }
# shellcheck disable=SC1090,SC1091
. "${OS_RELEASE:-/etc/os-release}"
echo "Checking against: ${PRETTY_NAME:-$ID} (${VERSION_CODENAME:-unknown}), architecture $(dpkg --print-architecture 2>/dev/null || echo unknown)"
if [[ "${ID:-}" == devuan ]] && grep -rqs 'deb.debian.org\|ftp.debian.org' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
  echo "WARNING: Debian repositories found on a Devuan system; remove them." >&2
fi
# A policy with no package lists at all means `apt-get update` never ran.
if ! apt-cache policy 2>/dev/null | grep -q '^ *[0-9]\+ http'; then
  echo "WARNING: apt has no downloaded package lists; run 'sudo apt-get update' first." >&2
fi

foreign="$(dpkg --print-foreign-architectures 2>/dev/null || true)"
have_i386=0; grep -qx i386 <<<"$foreign" && have_i386=1
problems=0

candidate() { apt-cache policy "$1" 2>/dev/null | sed -n 's/^ *Candidate: //p' | head -n1; }
component_of() { # archive component of the candidate (Section is "contrib/games" outside main)
  local s; s="$(apt-cache show --no-all-versions "$1" 2>/dev/null | sed -n 's/^Section: //p' | head -n1)"
  if [[ "$s" == */* ]]; then printf '%s' "${s%%/*}"; else printf 'main'; fi
}
provided_by() { apt-cache showpkg "$1" 2>/dev/null | awk '/^Reverse Provides:/ { on = 1; next } on && NF { print $1; exit }'; }
local_deb() { find "$OUT" -maxdepth 1 -name "${1}_*.deb" 2>/dev/null | sort -V | tail -n1; }

ALT_OK=0 ALT_WHERE="" ALT_VER="" ALT_WHY=""
eval_alt() { # <package> -> sets ALT_*
  local p="$1" origin cand prov f
  ALT_OK=0; ALT_WHERE=""; ALT_VER=""; ALT_WHY=""
  origin="$(deb_origin "$p")"
  cand="$(candidate "$p")"
  if [[ -n "$cand" && "$cand" != "(none)" ]]; then
    ALT_VER="$cand"
    case "$origin" in
      built|upstream|built-optional|upstream-optional) ALT_WHERE="reedmuhn repo" ;;
      *) ALT_WHERE="debian/$(component_of "$p")" ;;
    esac
    if [[ "$origin" == contrib+i386 && $have_i386 -eq 0 ]]; then
      ALT_WHY="$p needs the i386 architecture (dpkg --add-architecture i386): run sudo scripts/enable-steam-prereqs.sh"
      return
    fi
    ALT_OK=1; return
  fi
  prov="$(provided_by "$p")"
  if [[ -n "$prov" ]]; then ALT_OK=1; ALT_WHERE="virtual"; ALT_VER="provided by $prov"; return; fi
  f="$(local_deb "$p")"
  if [[ -n "$f" ]]; then ALT_OK=1; ALT_WHERE="out/"; ALT_VER="$(deb_field "$f" Version) (local build)"; return; fi
  case "$origin" in
    built)    ALT_WHY="built by this repository: run scripts/build-deb.sh" ;;
    upstream) ALT_WHY="mirrored by this repository: run scripts/build-deb.sh (needs the pinned EQUIBOP_SHA256)" ;;
    built-optional|upstream-optional) ALT_WHY="optional, not built by default (see the BUILD_* switches in scripts/build-deb.sh)" ;;
    contrib|contrib+i386) ALT_WHY="lives in Debian's contrib component, which is not enabled: run sudo scripts/enable-steam-prereqs.sh" ;;
    *) ALT_WHY="not found in the enabled repositories of ${PRETTY_NAME:-this system}; check the suites/components in your APT sources" ;;
  esac
}

# check_group <needed by> <group like "a|b">  -> prints one line, counts a problem when nothing satisfies it
check_group() {
  local by="$1" grp="$2" alt alts reasons=() shown=0
  IFS='|' read -ra alts <<<"$grp"
  for alt in "${alts[@]}"; do
    eval_alt "$alt"
    if (( ALT_OK )); then
      printf 'ok       %-15s %-18s %s  (needed by %s)\n' "$ALT_WHERE" "$alt" "$ALT_VER" "$by"
      shown=1; break
    fi
    reasons+=("$alt: $ALT_WHY")
  done
  if (( ! shown )); then
    printf 'MISSING  %-15s %-18s (needed by %s)\n' "-" "${grp//|/ | }" "$by"
    local r; for r in "${reasons[@]}"; do printf '           -> %s\n' "$r"; done
    problems=$((problems + 1))
  fi
}

echo
echo "== Metapackage dependencies (deb/reedmuhn-*/DEBIAN/control)"
for c in "$HERE"/deb/reedmuhn-*/DEBIAN/control; do
  [[ -f "$c" ]] || continue
  pkg="$(basename "$(dirname "$(dirname "$c")")")"
  # reedmuhn-cider needs reedmuhn-cider-repo, which is only built on request; check it when it exists.
  if [[ "$pkg" == reedmuhn-cider-repo ]]; then continue; fi
  if [[ "$pkg" == reedmuhn-cider ]] && [[ -z "$(local_deb reedmuhn-cider-repo)" ]]; then
    echo "skipped  reedmuhn-cider (optional: build it with BUILD_CIDER_REPO=1)"; continue
  fi
  while IFS= read -r grp; do check_group "$pkg" "$grp"; done < <(ctl_field "$c" Depends | dep_groups)
  while IFS= read -r grp; do
    # Recommends are not fatal; report the ones that cannot be satisfied.
    IFS='|' read -r first _ <<<"$grp"; eval_alt "$first"
    (( ALT_OK )) || printf 'note     recommended %s is not available (%s)\n' "$first" "$ALT_WHY"
  done < <(ctl_field "$c" Recommends | dep_groups)
done

echo
echo "== Dependencies of the standalone packages in out/"
shopt -s nullglob
n_standalone=0
for f in "$OUT"/*.deb; do
  base="$(deb_field "$f" Package)"
  [[ "$base" == reedmuhn-* ]] && continue
  n_standalone=$((n_standalone + 1))
  echo "-- $base $(deb_field "$f" Version) ($(deb_field "$f" Architecture))"
  while IFS= read -r grp; do check_group "$base" "$grp"; done < <(deb_field "$f" Depends | dep_groups)
done
(( n_standalone )) || echo "(no standalone packages in $OUT: run scripts/build-deb.sh first)"

sim_fail=0
if (( simulate )) && compgen -G "$OUT/*.deb" >/dev/null; then
  echo
  echo "== apt-get -s install of everything in out/"
  for mode in "--no-install-recommends" "--install-recommends"; do
    log="$(apt-get -s -y -o Debug::NoLocking=true install "$mode" "$OUT"/*.deb 2>&1)"; rc=$?
    if (( rc == 0 )); then
      echo "ok       simulated install resolves ($mode)"
    else
      echo "FAILED   simulated install ($mode):"
      grep -E '^(E:|The following packages have unmet|  *[A-Za-z0-9.+-]+ : )' <<<"$log" | sed 's/^/           /'
      sim_fail=1
    fi
  done
fi

echo
if (( problems == 0 && sim_fail == 0 )); then
  echo "All dependencies resolvable."; exit 0
fi
echo "$problems dependency problem(s)$( (( sim_fail )) && echo ' and a failed install simulation'); see above." >&2
exit 1

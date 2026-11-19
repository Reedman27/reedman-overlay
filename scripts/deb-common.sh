#!/usr/bin/env bash
# Shared helpers for the Debian scripts. Source it; do not execute it.
#   . "$(dirname "$0")/deb-common.sh"      (needs HERE to be the repository root)
# shellcheck shell=bash

DEB_CONF="${DEB_CONF:-$HERE/deb/package-sources.conf}"

# deb_origin <package>   -> origin recorded in deb/package-sources.conf (empty = Debian main)
deb_origin() {
  awk -v p="$1" '!/^[[:space:]]*(#|$)/ && $1 == p { print $2; exit }' "$DEB_CONF"
}

# deb_with_origin <origin>...   -> package names with any of those origins
deb_with_origin() {
  local o
  for o in "$@"; do
    awk -v o="$o" '!/^[[:space:]]*(#|$)/ && $2 == o { print $1 }' "$DEB_CONF"
  done
}

# ctl_field <control file> <Field>   -> field value, continuation lines joined with spaces
ctl_field() {
  awk -v f="$2" '
    index($0, f ":") == 1 { v = substr($0, length(f) + 2); sub(/^[ \t]+/, "", v); on = 1; next }
    on && /^[ \t]/        { c = $0; sub(/^[ \t]+/, "", c); v = v " " c; next }
    on                    { exit }
    END                   { print v }' "$1"
}

# dep_groups   (stdin: a Depends/Recommends value) -> one dependency group per line.
# Alternatives stay joined with "|"; version constraints, arch qualifiers and spaces are removed.
dep_groups() {
  tr ',' '\n' \
    | sed -E 's/\([^)]*\)//g; s/\[[^]]*\]//g; s/<[^>]*>//g; s/:(any|native)//g; s/[[:space:]]+//g' \
    | sed '/^$/d'
}

# deb_field <file.deb> <Field>
deb_field() { dpkg-deb -f "$1" "$2"; }

# is_deb_file <path>   -> 0 when the file starts with the ar magic of a Debian package
is_deb_file() { [[ "$(head -c 7 "$1" 2>/dev/null)" == '!<arch>' ]]; }

# verify_equibop [--metadata-only] <file.deb> <version>
# Checks a downloaded Equibop .deb before it may enter out/ or the APT repository: SHA-256 against
# $EQUIBOP_SHA256 (or the EQUIBOP_SHA256 file), then control data (name equibop, amd64, matching version).
# --metadata-only skips the checksum (used only while pinning a new release). Returns 1 on any failure.
verify_equibop() {
  local check_sha=1 file version expected actual pkg arch ver
  if [[ "${1:-}" == --metadata-only ]]; then check_sha=0; shift; fi
  file="$1"; version="$2"
  [[ -f "$file" ]] || { echo "verify-equibop: $file not found" >&2; return 1; }
  is_deb_file "$file" || { echo "verify-equibop: $file is not a Debian package (got an error page?)" >&2; return 1; }
  if (( check_sha )); then
    expected="${EQUIBOP_SHA256:-}"
    [[ -n "$expected" ]] || { [[ -s "$HERE/EQUIBOP_SHA256" ]] && expected="$(tr -d '[:space:]' < "$HERE/EQUIBOP_SHA256")"; }
    [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || { echo "verify-equibop: no valid pinned SHA-256: run scripts/update-equibop.sh $version" >&2; return 1; }
    actual="$(sha256sum "$file" | awk '{print $1}')"
    [[ "${expected,,}" == "$actual" ]] || { echo "verify-equibop: checksum mismatch for Equibop $version (pinned $expected, got $actual). Refusing to use the file." >&2; return 1; }
  fi
  pkg="$(deb_field "$file" Package)"; arch="$(deb_field "$file" Architecture)"; ver="$(deb_field "$file" Version)"
  [[ "$pkg" == equibop ]] || { echo "verify-equibop: package name is '$pkg', but reedmuhn-desktop depends on 'equibop'" >&2; return 1; }
  [[ "$arch" == amd64 ]]  || { echo "verify-equibop: architecture is '$arch'; the ReedMuhn APT repository is amd64" >&2; return 1; }
  [[ "$ver" == "$version" || "$ver" == "$version"-* ]] || { echo "verify-equibop: control Version is '$ver' but release $version was requested" >&2; return 1; }
  echo "equibop $ver ($arch): verified$( (( check_sha )) && echo ', SHA-256 matches the pin' )"
}

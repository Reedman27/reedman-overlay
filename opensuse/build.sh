#!/usr/bin/env bash
# Build the openSUSE (Tumbleweed, Leap) RPMs from opensuse/*.spec into out/. Also works on Fedora.
#
#   opensuse/build.sh [--no-deps] [--trust-new] [PKG ...]
#
# PKG is any of:
#   base desktop wmaker gaming networking development cider     the reedmuhn-* metapackages
#   cider-bin minecraft-launcher-bin equibop-bin                 repackaged upstream binaries
#   wm-desktop wmvol wmmedia                                     built from the Reedman27 repos
#   rustcord                                                     Qt WebEngine client (builds crates)
#   all                                                          everything except rustcord (default)
#
# Source handling: prebuilt upstream downloads (Cider, Minecraft) are pinned by sha256 in
# opensuse/SHA256SUMS the first time you build them (trust on first use); a later change is
# refused unless you pass --trust-new. Equibop uses ../EQUIBOP_SHA256. Git sources are cloned
# with your own git credentials (so a private repo works) at the commit in ../WM_DESKTOP_REF,
# ../DOCKAPPS_REF, or the current HEAD (rustcord; set RUSTCORD_REF to pin).
#
# Test overrides: CIDER_RPM_URL MC_DEB_URL EQUIBOP_DEB_URL WM_DESKTOP_URL DOCKAPPS_URL RUSTCORD_URL
# RPMBUILD_EXTRA (e.g. --nodeps). OUT_DIR changes the output directory.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SPECS="$HERE/opensuse"
OUT="${OUT_DIR:-$HERE/out}"
DEPS=1; TRUST=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --no-deps) DEPS=0 ;;
    --trust-new) TRUST=1 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

META_NAMES=(base desktop wmaker gaming networking development cider)
HOSTED=(cider-bin minecraft-launcher-bin equibop-bin wm-desktop wmvol wmmedia rustcord)
[[ $# -gt 0 ]] || set -- all
want=()
for a in "$@"; do
  case "$a" in
    all) want+=("${META_NAMES[@]/#/reedmuhn-}" "${HOSTED[@]:0:6}") ;;
    base|desktop|wmaker|gaming|networking|development|cider) want+=("reedmuhn-$a") ;;
    reedmuhn-*|cider-bin|minecraft-launcher-bin|equibop-bin|wm-desktop|wmvol|wmmedia|rustcord) want+=("$a") ;;
    *) echo "unknown package: $a (see --help)" >&2; exit 2 ;;
  esac
done
is_wanted() { local x; for x in "${want[@]}"; do [[ $x == "$1" ]] && return 0; done; return 1; }

SUDO=(); [[ $EUID -eq 0 ]] || SUDO=(sudo)
if   command -v zypper >/dev/null; then PM=zypper
elif command -v dnf    >/dev/null; then PM=dnf
else PM=; fi
install_pkgs() {
  (( DEPS )) || return 0
  [[ -n $PM ]] || { echo "no zypper or dnf found; install build dependencies yourself or use --no-deps" >&2; return 0; }
  if [[ $PM == zypper ]]; then "${SUDO[@]}" zypper --non-interactive install --no-recommends "$@"
  else "${SUDO[@]}" dnf install -y "$@"; fi
}
command -v rpmbuild >/dev/null || {
  (( DEPS )) || { echo "rpmbuild not found (package rpm-build)" >&2; exit 1; }
  install_pkgs rpm-build
}
for tool in curl git; do command -v "$tool" >/dev/null || install_pkgs "$tool"; done

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T"/{SOURCES,BUILD,RPMS,SRPMS,BUILDROOT} "$OUT"
cp "$SPECS/chromium-runtime.inc" "$T/SOURCES/"
VER="$(cat "$HERE/VERSION")"
DEFS=(--define "_topdir $T" --define "_sourcedir $T/SOURCES" --define "pkgver $VER")
XARGS=()
xdef() { XARGS+=(--define "$1 $2"); }
log() { printf '== %s\n' "$*" >&2; }

# --- pinning of prebuilt downloads ---------------------------------------------------------
SUMS="$SPECS/SHA256SUMS"; touch "$SUMS"
pin() {  # pin FILE   (verifies against, or records in, SHA256SUMS)
  local f="$1" name; name="$(basename "$f")"
  local have; have="$(sha256sum "$f" | awk '{print $1}')"
  local want_sum; want_sum="$(awk -v n="$name" '$2==n {print $1}' "$SUMS")"
  if [[ -z $want_sum ]]; then
    echo "$have  $name" >> "$SUMS"; log "pinned $name $have (first use: check it against upstream if you can)"
  elif [[ $want_sum != "$have" ]]; then
    if (( TRUST )); then sed -i "s|^$want_sum  $name\$|$have  $name|" "$SUMS"; log "re-pinned $name"
    else echo "checksum mismatch for $name:
  pinned $want_sum
  got    $have
If upstream really changed this file, re-run with --trust-new." >&2; exit 1; fi
  fi
}

fetch() { curl -fSL --retry 3 -o "$2" "$1"; }

# --- git sources ---------------------------------------------------------------------------
pinned_ref() { [[ -f "$HERE/$1" ]] && grep -v '^#' "$HERE/$1" | head -n1 || true; }
git_source() {  # git_source URL REF NAME  -> sets GIT_COMMIT, writes SOURCES/NAME-<commit>.tar.gz
  local url="$1" ref="$2" name="$3" d="$T/git-$3"
  mkdir -p "$d"; git -C "$d" init -q
  if [[ -n $ref ]]; then
    git -C "$d" fetch -q --depth 1 "$url" "$ref" 2>/dev/null || { rm -rf "$d"; git clone -q "$url" "$d"; git -C "$d" checkout -q "$ref"; }
    [[ -e "$d/.git/FETCH_HEAD" && ! -e "$d/Makefile" && ! -d "$d/crates" ]] && git -C "$d" checkout -q FETCH_HEAD 2>/dev/null || true
  else
    git -C "$d" fetch -q --depth 1 "$url" HEAD && git -C "$d" checkout -q FETCH_HEAD
  fi
  GIT_COMMIT="$(git -C "$d" rev-parse HEAD)"
  GIT_DATE="$(git -C "$d" log -1 --format=%cd --date=format:%Y%m%d)"
  git -C "$d" archive --format=tar.gz --prefix="$name-$GIT_COMMIT/" -o "$T/SOURCES/$name-$GIT_COMMIT.tar.gz" HEAD
}

prepare() {  # prepare PKG -> adds --define options to XARGS, stages sources
  local p="$1" url ref
  case "$p" in
    cider-bin)
      local f ver
      url="${CIDER_RPM_URL:-}"
      if [[ -z $url ]]; then
        local base="https://repo.cider.sh/rpm/RPMS/"
        f="$(curl -fsSL "$base" | grep -o 'cider-v[0-9][0-9.]*-linux-x64\.rpm' | sort -uV | tail -n1)"
        [[ -n $f ]] || { echo "no cider rpm found at $base" >&2; exit 1; }
        url="$base$f"
      fi
      f="$(basename "$url")"; ver="$(sed -n 's/^cider-v\([0-9.]*\)-linux-x64\.rpm$/\1/p' <<<"$f")"
      [[ -n $ver ]] || { echo "cannot read the version from $f" >&2; exit 1; }
      fetch "$url" "$T/SOURCES/$f"; pin "$T/SOURCES/$f"
      xdef cider_version "$ver" ;;
    minecraft-launcher-bin)
      local deb="$T/SOURCES/Minecraft.deb" raw ver
      fetch "${MC_DEB_URL:-https://launcher.mojang.com/download/Minecraft.deb}" "$deb"
      [[ "$(head -c 7 "$deb")" == '!<arch>' ]] || { echo "Minecraft.deb is not a .deb archive" >&2; exit 1; }
      mkdir -p "$T/mcdeb"; (cd "$T/mcdeb" && ar x "$deb" && for c in control.tar.*; do tar -xf "$c" --wildcards '*control' -O; break; done > control.txt)
      raw="$(cat "$T/mcdeb/control.txt")"
      ver="$(sed -n 's/^Version: *//p' <<<"$raw" | head -n1)"; ver="${ver%%[!0-9.]*}"
      [[ -n $ver ]] || { echo "cannot read the launcher version" >&2; exit 1; }
      # the launcher URL is unversioned, so the pin is per version
      cp "$deb" "$T/Minecraft-$ver.deb"; pin "$T/Minecraft-$ver.deb"; rm -f "$T/Minecraft-$ver.deb"
      xdef mcver "$ver" ;;
    equibop-bin)
      local ver; ver="${EQUIBOP_VERSION:-$(tr -d '[:space:]' < "$HERE/EQUIBOP_VERSION")}"
      local f="equibop_${ver}_amd64.deb"
      fetch "${EQUIBOP_DEB_URL:-https://github.com/Equicord/Equibop/releases/download/v${ver}/$f}" "$T/SOURCES/$f"
      local pinned="${EQUIBOP_SHA256:-$(tr -d '[:space:]' < "$HERE/EQUIBOP_SHA256" 2>/dev/null || true)}"
      if [[ -n $pinned ]]; then
        [[ "$pinned" == "$(sha256sum "$T/SOURCES/$f" | awk '{print $1}')" ]] \
          || { echo "Equibop checksum mismatch; run scripts/update-equibop.sh $ver" >&2; exit 1; }
      fi
      xdef eqver "$ver" ;;
    wm-desktop)
      git_source "${WM_DESKTOP_URL:-https://github.com/Reedman27/wm-desktop.git}" "$(pinned_ref WM_DESKTOP_REF)" wm-desktop
      xdef commit "$GIT_COMMIT"; xdef snapdate "$GIT_DATE" ;;
    wmvol|wmmedia)
      git_source "${DOCKAPPS_URL:-https://github.com/Reedman27/dockapps-collection.git}" "$(pinned_ref DOCKAPPS_REF)" dockapps-collection
      xdef commit "$GIT_COMMIT"; xdef snapdate "$GIT_DATE" ;;
    rustcord)
      git_source "${RUSTCORD_URL:-https://github.com/Reedman27/rustcord.git}" "${RUSTCORD_REF:-}" rustcord
      xdef commit "$GIT_COMMIT"; xdef snapdate "$GIT_DATE" ;;
    reedmuhn-*) ;;
  esac
}

# --- build ---------------------------------------------------------------------------------
built=()
for p in "${want[@]}"; do
  spec="$SPECS/$p.spec"
  [[ -f $spec ]] || { echo "no spec for $p (run scripts/gen.py for the metapackages)" >&2; exit 1; }
  log "$p"
  XARGS=()
  prepare "$p"
  args=("${DEFS[@]}" "${XARGS[@]}")
  if (( DEPS )); then
    mapfile -t need < <(rpmspec -q --buildrequires "${args[@]}" "$spec" 2>/dev/null | sort -u)
    (( ${#need[@]} )) && install_pkgs "${need[@]}"
  fi
  # shellcheck disable=SC2086
  rpmbuild -bb ${RPMBUILD_EXTRA:-} "${args[@]}" "$spec"
  built+=("$p")
done

cp "$T"/RPMS/*/*.rpm "$OUT/"
echo
echo "Built into $OUT:"
ls -1 "$T"/RPMS/*/*.rpm | xargs -n1 basename
if [[ $PM == zypper || -z $PM ]]; then
  echo
  echo "Install on openSUSE:  sudo zypper --allow-unsigned-rpm install $OUT/<file>.rpm   (or: ./bootstrap.sh --local ...)"
fi

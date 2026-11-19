#!/usr/bin/env bash
# Install selected ReedMuhn metapackages and optional standalone apps.
# Examples: ./bootstrap.sh base wmaker
#           ./bootstrap.sh base desktop gaming
# Debian/Devuan: adds the ReedMuhn APT repository if missing (one time), then runs a normal `apt install`.
# Add --local to install from packages you built into out/ instead (scripts/build-deb.sh).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT_DIR:-$HERE/out}"
DRY=0; LOCAL=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in --dry-run) DRY=1 ;; --local) LOCAL=1 ;; *) echo "unknown option: $1" >&2; exit 2 ;; esac
  shift
done
[[ $# -gt 0 ]] || { echo "Usage: $0 [--dry-run] [--local] base|desktop|wmaker|gaming|networking|development|cider|equibop|minecraft ..." >&2; exit 2; }
METAS=(); APPS=()
for item in "$@"; do
  case "$item" in
    base|desktop|wmaker|gaming|networking|development|cider) METAS+=("$item") ;;
    equibop) APPS+=(equibop-bin) ;;
    minecraft) APPS+=(minecraft-launcher-bin) ;;
    *) echo "unknown selection: $item" >&2; exit 2 ;;
  esac
done
SUDO=(); [[ $EUID -eq 0 ]] || SUDO=(sudo)
run() { printf '+ '; printf '%q ' "$@"; printf '\n'; (( DRY )) || "$@"; }
pick() { local f; f="$(find "$OUT" -maxdepth 1 -type f -name "$1" -printf '%f\n' 2>/dev/null | sort -V | tail -n1)"; [[ -n "$f" ]] || { echo "No matching build artifact ($1) in $OUT. Build packages first; see README.md." >&2; exit 1; }; printf '%s/%s' "$OUT" "$f"; }
has_meta() { local x; for x in "${METAS[@]}"; do [[ "$x" == "$1" ]] && return 0; done; return 1; }
has_app() { local x; for x in "${APPS[@]}"; do [[ "$x" == "$1" ]] && return 0; done; return 1; }

. "${OS_RELEASE:-/etc/os-release}"
ids=" ${ID:-} ${ID_LIKE:-} "
case "$ids" in
  *" alpine "*|*" chimera "*) family=musl ;;
  *" gentoo "*) family=gentoo ;;
  *" void "*) family=void ;;
  *" opensuse "*|*" opensuse-tumbleweed "*) family=opensuse ;;
  *" arch "*|*" endeavouros "*) family=arch ;;
  *" fedora "*) family=rpm ;;
  *" devuan "*|*" debian "*|*" ubuntu "*|*" linuxmint "*|*" antix "*|*" mx "*) family=deb ;;
  *) echo "Unsupported distro: ${PRETTY_NAME:-${ID:-unknown}}" >&2; exit 1 ;;
esac
echo "Detected ${PRETTY_NAME:-$ID} -> $family"

case "$family" in
  deb)
    if (( ! LOCAL )); then
      # Normal route: repository + apt. Nothing needs building.
      [[ -f /etc/apt/sources.list.d/reedmuhn.sources ]] || run "${SUDO[@]}" "$HERE/scripts/setup-apt-repo.sh"
      if has_meta gaming && [[ "${ID:-}" == debian || "${ID:-}" == devuan ]]; then
        run "${SUDO[@]}" "$HERE/scripts/enable-steam-prereqs.sh"
      fi
      pkgs=(); for m in "${METAS[@]}"; do pkgs+=("reedmuhn-$m"); done
      for a in "${APPS[@]}"; do case "$a" in equibop-bin) pkgs+=(equibop) ;; minecraft-launcher-bin) pkgs+=(minecraft-launcher) ;; esac; done
      run "${SUDO[@]}" apt-get install -y "${pkgs[@]}"
      exit 0
    fi
    files=()
    for m in "${METAS[@]}"; do files+=("$(pick "reedmuhn-${m}_*_all.deb")"); done
    has_meta wmaker && files+=("$(pick 'wm-desktop_*.deb')" "$(pick 'wmvol_*.deb')" "$(pick 'wmmedia_*.deb')")
    if has_meta cider; then
      repo_pkg="$(pick 'reedmuhn-cider-repo_*_all.deb')"
      run "${SUDO[@]}" apt-get install -y "$repo_pkg"
      run "${SUDO[@]}" apt-get update
    fi
    has_app minecraft-launcher-bin && files+=("$(pick 'minecraft-launcher_*.deb')")
    # reedmuhn-desktop depends on equibop: use the locally built .deb when present,
    # otherwise apt fetches it from the configured ReedMuhn repository.
    if has_meta desktop || has_app equibop-bin; then
      eq="$(find "$OUT" -maxdepth 1 -type f -name 'equibop_*_amd64.deb' 2>/dev/null | sort -V | tail -n1)"
      if [[ -n "$eq" ]]; then files+=("$eq")
      elif has_app equibop-bin; then echo "No equibop .deb in $OUT: run scripts/build-deb.sh (Equibop is built by default)" >&2; exit 1
      else echo "Note: no local equibop .deb; apt must find 'equibop' in the ReedMuhn repository (scripts/setup-apt-repo.sh)." >&2; fi
    fi
    # reedmuhn-gaming depends on winetricks and steam-installer: Debian "contrib" packages, and Steam also needs i386.
    if has_meta gaming; then
      case "${ID:-}" in
        debian|devuan) run "${SUDO[@]}" "$HERE/scripts/enable-steam-prereqs.sh" ;;
        *) echo "Note: scripts/enable-steam-prereqs.sh supports Debian/Devuan only; enable your distribution's Steam component (Ubuntu: multiverse) and i386 yourself." >&2 ;;
      esac
    fi
    run "${SUDO[@]}" apt-get install -y "${files[@]}"
    ;;
  rpm|opensuse)
    files=()
    for m in "${METAS[@]}"; do files+=("$(pick "reedmuhn-${m}-*.noarch.rpm")"); done
    has_meta wmaker && files+=("$(pick 'wm-desktop-*.rpm')")
    has_meta cider && [[ $family == rpm ]] && { run "${SUDO[@]}" dnf install -y "$(pick 'reedmuhn-cider-repo-*.noarch.rpm')"; run "${SUDO[@]}" dnf makecache; }
    has_app minecraft-launcher-bin && files+=("$(pick 'minecraft-launcher-bin-*.rpm')")
    has_app equibop-bin && files+=("$(pick 'equibop-bin-*.rpm')")
    if [[ $family == opensuse ]]; then run "${SUDO[@]}" zypper --non-interactive install "${files[@]}"
    else run "${SUDO[@]}" dnf install -y "${files[@]}"; fi
    ;;
  arch)
    files=()
    for m in "${METAS[@]}"; do files+=("$(pick "reedmuhn-${m}-*.pkg.tar.*")"); done
    has_meta wmaker && files+=("$(pick 'wm-desktop-*.pkg.tar.*')")
    has_meta cider && { run "${SUDO[@]}" pacman -U --needed "$(pick 'reedmuhn-cider-repo-*.pkg.tar.*')"; run "${SUDO[@]}" pacman -Syu; }
    has_app minecraft-launcher-bin && files+=("$(pick 'minecraft-launcher-bin-*.pkg.tar.*')")
    has_app equibop-bin && files+=("$(pick 'equibop-bin-*.pkg.tar.*')")
    run "${SUDO[@]}" pacman -U --needed "${files[@]}"
    ;;
  gentoo)
    echo "Install the local overlay at /var/db/repos/reedmuhn (see README.md), then emerge:"
    for m in "${METAS[@]}"; do echo "  emerge --ask app-metapackages/reedmuhn-$m"; done
    has_meta wmaker && echo "  emerge --ask x11-misc/wm-desktop"
    has_app minecraft-launcher-bin && echo "  emerge --ask games-action/minecraft-launcher-bin"
    has_app equibop-bin && echo "  emerge --ask net-im/equibop-bin"
    ;;
  void)
    echo "Build the requested XBPS templates first with:"
    pkgs=()
    for m in "${METAS[@]}"; do pkgs+=("reedmuhn-$m"); done
    has_meta wmaker && pkgs+=(wm-desktop)
    has_app minecraft-launcher-bin && pkgs+=(minecraft-launcher-bin)
    has_app equibop-bin && pkgs+=(equibop-bin)
    printf '  ./void/build.sh'; printf ' %q' "${pkgs[@]}"; printf '\n'
    echo "Then install from the local binpkgs repository (xbps-src indexes it):"
    printf '  sudo xbps-install --repository=%q' "$HOME/void-packages/hostdir/binpkgs"; printf ' %q' "${pkgs[@]}"; printf '\n'
    ;;
  musl)
    echo "Alpine/Chimera use musl. Equibop's upstream .deb and the current Electron payload are glibc-targeted; it is intentionally not offered here."
    echo "Use the generated musl metapackages only; Window Maker and standalone Electron applications are omitted where no native package exists."
    ;;
esac

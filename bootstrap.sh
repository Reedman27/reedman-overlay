#!/usr/bin/env bash
# Install selected ReedMuhn metapackages and optional standalone apps.
# Examples: ./bootstrap.sh base wmaker
#           ./bootstrap.sh base desktop equibop minecraft
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT_DIR:-$HERE/out}"
DRY=0
if [[ "${1:-}" == "--dry-run" ]]; then DRY=1; shift; fi
[[ $# -gt 0 ]] || { echo "Usage: $0 [--dry-run] base|desktop|wmaker|gaming|networking|development|cider|equibop|minecraft ..." >&2; exit 2; }
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
    files=()
    for m in "${METAS[@]}"; do files+=("$(pick "reedmuhn-${m}_*_all.deb")"); done
    has_meta wmaker && files+=("$(pick 'wm-desktop_*.deb')")
    if has_meta cider; then
      repo_pkg="$(pick 'reedmuhn-cider-repo_*_all.deb')"
      run "${SUDO[@]}" apt-get install -y "$repo_pkg"
      run "${SUDO[@]}" apt-get update
    fi
    has_app minecraft-launcher-bin && files+=("$(pick 'minecraft-launcher_*.deb')")
    has_app equibop-bin && files+=("$(pick 'equibop_*_amd64.deb')")
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

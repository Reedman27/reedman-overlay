#!/usr/bin/env bash
# Install selected ReedMuhn metapackages and optional standalone apps.
# Examples: ./bootstrap.sh base wmaker
#           ./bootstrap.sh base desktop gaming
# Debian/Devuan: builds the .debs with scripts/build-deb.sh (unless --local and they are already in out/), then installs.
# openSUSE/Fedora: builds the RPMs with opensuse/build.sh (unless --local and they are already in out/), then installs.
# Chimera: builds the cports templates with chimera/setup.sh and prints the apk install command.
# Gentoo/Arch/Void: builds or prints the native install steps.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT_DIR:-$HERE/out}"
DRY=0; LOCAL=0
usage() { cat <<'HELP'
ReedMuhn bootstrap: pick what you want, it detects your distro and does the rest.

  ./bootstrap.sh [--dry-run] [--local] <selection>...

Selections (combine freely):
  base         zsh, tmux, git, btop, fastfetch ... the command-line basics
  desktop      file manager, terminal, media, PipeWire, Equibop
  wmaker       Window Maker desktop (themed, with dock apps)
  gaming       Steam, Wine tools     networking   network tools
  development  dev tools             cider        Cider music player
  equibop      Discord client (Equibop)           minecraft  Minecraft launcher
  rustcord     Rustcord, the native Discord client

Examples:
  ./bootstrap.sh rustcord              just Rustcord
  ./bootstrap.sh base wmaker           a full Window Maker setup
  ./bootstrap.sh --dry-run base        show what would happen, change nothing

Options: --dry-run print the steps only; --local reuse packages already built in out/.
HELP
}
case "${1:-}" in -h|--help|help) usage; exit 0 ;; esac
while [[ "${1:-}" == --* ]]; do
  case "$1" in --dry-run) DRY=1 ;; --local) LOCAL=1 ;; *) echo "unknown option: $1" >&2; exit 2 ;; esac
  shift
done
[[ $# -gt 0 ]] || { usage >&2; exit 2; }
METAS=(); APPS=()
for item in "$@"; do
  case "$item" in
    base|desktop|wmaker|gaming|networking|development|cider) METAS+=("$item") ;;
    equibop) APPS+=(equibop-bin) ;;
    minecraft) APPS+=(minecraft-launcher-bin) ;;
    rustcord) APPS+=(rustcord) ;;
    *) echo "unknown selection: $item" >&2; exit 2 ;;
  esac
done
SUDO=(); [[ $EUID -eq 0 ]] || SUDO=(sudo)
run() { printf '+ '; printf '%q ' "$@"; printf '\n'; (( DRY )) || "$@"; }
pick() { local f; f="$(find "$OUT" -maxdepth 1 -type f -name "$1" -printf '%f\n' 2>/dev/null | sort -V | tail -n1)"; [[ -n "$f" ]] || { (( DRY )) && { printf "%s/%s" "$OUT" "$1"; return 0; }; echo "No matching build artifact ($1) in $OUT. Build packages first; see README.md." >&2; exit 1; }; printf '%s/%s' "$OUT" "$f"; }
has_meta() { local x; for x in "${METAS[@]}"; do [[ "$x" == "$1" ]] && return 0; done; return 1; }
has_app() { local x; for x in "${APPS[@]}"; do [[ "$x" == "$1" ]] && return 0; done; return 1; }

. "${OS_RELEASE:-/etc/os-release}"
ids=" ${ID:-} ${ID_LIKE:-} "
case "$ids" in
  *" chimera "*) family=chimera ;;
  *" alpine "*) family=alpine ;;
  *" gentoo "*) family=gentoo ;;
  *" void "*) family=void ;;
  *" opensuse "*|*" opensuse-tumbleweed "*|*" opensuse-leap "*|*" suse "*) family=opensuse ;;
  *" arch "*|*" endeavouros "*) family=arch ;;
  *" fedora "*) family=rpm ;;
  *" devuan "*|*" debian "*|*" ubuntu "*|*" linuxmint "*|*" antix "*|*" mx "*) family=deb ;;
  *) echo "Unsupported distro: ${PRETTY_NAME:-${ID:-unknown}}" >&2; exit 1 ;;
esac
echo "Detected ${PRETTY_NAME:-$ID} -> $family"

case "$family" in
  deb)
    if has_app rustcord; then
      echo "Rustcord has no .deb yet. Build it from source (needs Rust and the Qt6 WebEngine dev packages):" >&2
      echo "  git clone https://github.com/Reedman27/rustcord && cd rustcord && cargo build --release -p rustcord-qt" >&2
      (( ${#METAS[@]} > 0 || ${#APPS[@]} > 1 )) || exit 1
    fi
    if (( ! LOCAL )); then
      if (( DRY )); then echo "+ $HERE/scripts/build-deb.sh"
      else OUT_DIR="$OUT" "$HERE/scripts/build-deb.sh"; fi
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
    # reedmuhn-desktop depends on equibop: install the locally built .deb alongside it.
    if has_meta desktop || has_app equibop-bin; then
      eq="$(find "$OUT" -maxdepth 1 -type f -name 'equibop_*_amd64.deb' 2>/dev/null | sort -V | tail -n1 || true)"
      if [[ -n "$eq" ]]; then files+=("$eq")
      elif (( DRY )); then files+=("$OUT/equibop_*_amd64.deb")
      else echo "No equibop .deb in $OUT: run scripts/build-deb.sh (Equibop is built by default)" >&2; exit 1; fi
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
    # Packages to build (opensuse/build.sh also works on Fedora). Existing files in out/ are reused with --local.
    build=()
    for m in "${METAS[@]}"; do build+=("$m"); done
    has_meta wmaker && build+=(wm-desktop wmvol wmmedia)
    for a in "${APPS[@]}"; do build+=("$a"); done
    has_meta cider && [[ $family == opensuse ]] && build+=(cider-bin)
    if (( ! LOCAL )); then
      if (( DRY )); then echo "+ $HERE/opensuse/build.sh ${build[*]}"
      else OUT_DIR="$OUT" "$HERE/opensuse/build.sh" "${build[@]}"; fi
    fi
    files=()
    for m in "${METAS[@]}"; do files+=("$(pick "reedmuhn-${m}-*.noarch.rpm")"); done
    if has_meta wmaker; then for w in wm-desktop wmvol wmmedia; do files+=("$(pick "$w-*.rpm")"); done; fi
    has_meta cider && [[ $family == rpm ]] && { run "${SUDO[@]}" dnf install -y "$(pick 'reedmuhn-cider-repo-*.noarch.rpm')"; run "${SUDO[@]}" dnf makecache; }
    has_meta cider && [[ $family == opensuse ]] && files+=("$(pick 'cider-bin-*.rpm')")
    for a in "${APPS[@]}"; do files+=("$(pick "$a-*.rpm")"); done
    # the packages are unsigned local builds
    if [[ $family == opensuse ]]; then run "${SUDO[@]}" zypper --non-interactive --allow-unsigned-rpm install "${files[@]}"
    else run "${SUDO[@]}" dnf install -y "${files[@]}"; fi
    ;;
  arch)
    if (( ! LOCAL )); then
      # directories under arch/ to build for this selection
      ab=(); for m in "${METAS[@]}"; do ab+=("reedmuhn-$m"); done
      has_meta wmaker && ab+=(wm-desktop wmvol wmmedia)
      has_meta cider && ab+=(reedmuhn-cider-repo)
      has_app minecraft-launcher-bin && ab+=(minecraft-launcher-bin)
      has_app equibop-bin && ab+=(equibop-bin)
      has_app rustcord && { ab+=(rustcord); run "${SUDO[@]}" pacman -S --needed base-devel git cargo pkgconf qt6-base qt6-webengine; }
      run "$HERE/arch/build.sh" "${ab[@]}"
    fi
    files=()
    for m in "${METAS[@]}"; do files+=("$(pick "reedmuhn-${m}-*.pkg.tar.*")"); done
    if has_meta wmaker; then for w in wm-desktop wmvol-git wmmedia-git; do files+=("$(pick "$w-*.pkg.tar.*")"); done; fi
    has_meta cider && { run "${SUDO[@]}" pacman -U --needed "$(pick 'reedmuhn-cider-repo-*.pkg.tar.*')"; run "${SUDO[@]}" pacman -Syu; }
    has_app minecraft-launcher-bin && files+=("$(pick 'minecraft-launcher-bin-*.pkg.tar.*')")
    has_app equibop-bin && files+=("$(pick 'equibop-bin-*.pkg.tar.*')")
    has_app rustcord && files+=("$(pick 'rustcord-git-*.pkg.tar.*')")
    run "${SUDO[@]}" pacman -U --needed "${files[@]}"
    ;;
  gentoo)
    echo "Add the overlay once (see README.md), then:"
    pk=()
    for m in "${METAS[@]}"; do pk+=("app-metapackages/reedmuhn-$m"); done
    has_meta wmaker && pk+=(x11-misc/wm-desktop x11-plugins/wmvol x11-plugins/wmmedia)
    has_app minecraft-launcher-bin && pk+=(games-action/minecraft-launcher-bin)
    has_app equibop-bin && pk+=(net-im/equibop-bin)
    has_app rustcord && pk+=(net-im/rustcord)
    echo "  emerge -aq ${pk[*]}"
    ;;
  void)
    echo "Build the requested XBPS templates first with:"
    pkgs=()
    for m in "${METAS[@]}"; do pkgs+=("reedmuhn-$m"); done
    has_meta wmaker && pkgs+=(wm-desktop)
    has_app rustcord && echo "Note: there is no Void template for rustcord yet." >&2
    has_app minecraft-launcher-bin && pkgs+=(minecraft-launcher-bin)
    has_app equibop-bin && pkgs+=(equibop-bin)
    printf '  ./void/build.sh'; printf ' %q' "${pkgs[@]}"; printf '\n'
    echo "Then install from the local binpkgs repository (xbps-src indexes it):"
    printf '  sudo xbps-install --repository=%q' "$HOME/void-packages/hostdir/binpkgs"; printf ' %q' "${pkgs[@]}"; printf '\n'
    ;;
  chimera)
    for a in "${APPS[@]}"; do
      case "$a" in
        equibop-bin|minecraft-launcher-bin) echo "$a is a glibc/Electron or Java-launcher binary and is not offered on Chimera." >&2; exit 1 ;;
      esac
    done
    pk=()
    for m in "${METAS[@]}"; do pk+=("reedmuhn-$m"); done
    pk=("${pk[@]/reedmuhn-cider/}")
    has_meta wmaker && pk+=(windowmaker wm-desktop wmvol wmmedia sxhkd)
    has_app rustcord && pk+=(rustcord)
    pk=($(printf '%s\n' "${pk[@]}" | awk 'NF && !s[$0]++'))
    run "$HERE/chimera/setup.sh" "${pk[@]}"
    # Xorg input driver, seat/session services, ~/.xinitrc, a terminal and a working menu
    has_meta wmaker && run "$HERE/chimera/desktop-setup.sh"
    ;;
  alpine)
    echo "Alpine: only the generated musl metapackages are meaningful here; Window Maker, Cider and Equibop are not packaged for Alpine by this repository."
    ;;
esac

#!/bin/sh
# Build the ReedMuhn cports templates on Chimera Linux and print how to install them.
#
#   chimera/setup.sh [--no-pin] [--with-rustcord] [PKG ...]
#
# Default packages: windowmaker wm-desktop wmvol wmmedia sxhkd reedmuhn-base reedmuhn-wmaker
# (windowmaker goes first: wm-desktop needs its -devel package.)
# --with-rustcord adds rustcord, which pulls in Qt WebEngine and takes a long time to build.
#
# Environment: CPORTS=/path/to/cports (default ~/cports; cloned there if missing).
# Run as a normal user on Chimera (cbuild refuses root and needs user namespaces).
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CPORTS=${CPORTS:-$HOME/cports}
PIN=1; RC=0
while [ $# -gt 0 ]; do
  case $1 in
    --no-pin) PIN=0 ;;
    --with-rustcord) RC=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    --*) echo "unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
  shift
done
[ "$(id -u)" -ne 0 ] || { echo "run as a normal user, not root" >&2; exit 1; }
if [ $# -eq 0 ]; then
  set -- windowmaker wm-desktop wmvol wmmedia sxhkd reedmuhn-base reedmuhn-wmaker
  [ "$RC" -eq 0 ] || set -- "$@" rustcord
fi
for tool in git python3; do
  command -v "$tool" >/dev/null || { echo "missing $tool: apk add base-cbuild-host git" >&2; exit 1; }
done

# 1. source checksums (needs network; the cbuild sandbox has none)
if [ "$PIN" -eq 1 ]; then "$HERE/scripts/pin-chimera.sh"; fi

# 2. cports checkout with the templates copied in (symlinks for subpackages are kept)
[ -d "$CPORTS/.git" ] || git clone --depth 1 https://github.com/chimera-linux/cports.git "$CPORTS"
cp -a "$HERE/chimera/user/." "$CPORTS/user/"
cd "$CPORTS"

# 3. signing key (once) and build
[ -f etc/config.ini ] || cp etc/config.ini.example etc/config.ini
ls etc/keys/*.rsa >/dev/null 2>&1 || ./cbuild keygen
command -v ruff >/dev/null 2>&1 || { echo "installing ruff (needed by cbuild lint)"; doas apk add ruff || sudo apk add ruff; }
command -v ruff >/dev/null 2>&1 || { echo "installing ruff (needed by cbuild lint)"; doas apk add ruff || sudo apk add ruff; }
[ -d masterdir ] || ./cbuild binary-bootstrap
for p in "$@"; do
  ./cbuild lint "user/$p"
done
./cbuild relink-subpkgs
for p in "$@"; do
  echo "== building $p"
  ./cbuild pkg "user/$p"
done

cat <<EOF

Built into $CPORTS/packages/user. Install with :
  doas apk add --repository $CPORTS/packages/user --allow-untrusted $*
Better: copy your public key from etc/keys/ or ~/.config/cbuild-keys/ into /etc/apk/keys/ and drop --allow-untrusted.
Start Window Maker:  echo 'exec wmaker' > ~/.xinitrc && startx
EOF

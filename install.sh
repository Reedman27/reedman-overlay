#!/bin/sh
# ReedMuhn one-line installer: fetches (or updates) this repository and runs bootstrap.sh.
#
#   curl -fsSL https://raw.githubusercontent.com/Reedman27/reedman-overlay/main/install.sh | sh -s -- base wmaker
#   curl -fsSL https://raw.githubusercontent.com/Reedman27/reedman-overlay/main/install.sh | sh -s -- rustcord
#
# Anything after `--` is passed to bootstrap.sh (try --dry-run first, or no arguments for help).
# Environment: REEDMUHN_DIR (default ~/.local/share/reedmuhn-overlay), REEDMUHN_REPO (git URL).
set -eu
REPO=${REEDMUHN_REPO:-https://github.com/Reedman27/reedman-overlay.git}
DEST=${REEDMUHN_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/reedmuhn-overlay}
command -v git >/dev/null 2>&1 || { echo "git is required (install it with your package manager and re-run)" >&2; exit 1; }
if [ -d "$DEST/.git" ]; then
  echo "Updating $DEST"
  git -C "$DEST" pull --ff-only --quiet || echo "warning: could not update, using the existing copy" >&2
else
  echo "Cloning $REPO into $DEST"
  git clone --depth 1 --quiet "$REPO" "$DEST"
fi
exec "$DEST/bootstrap.sh" "$@"

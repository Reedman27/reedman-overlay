#!/usr/bin/env bash
# Debian/Devuan: add the ReedMuhn APT repository (Forgejo's built-in Debian package registry)
# so reedmuhn-desktop can fetch Equibop with plain `apt install`. Run as root.
# Defaults point at https://serverhat.tail973a97.ts.net:8443/api/packages/Reedman27/debian
# Overrides: FORGEJO_URL, FORGEJO_OWNER, REEDMUHN_DIST (default reedmuhn), APT_KEYRING_DIR,
#            APT_SOURCES_DIR, SKIP_UPDATE=1.
set -euo pipefail
FORGEJO_URL="${FORGEJO_URL:-https://serverhat.tail973a97.ts.net:8443}"
OWNER="${FORGEJO_OWNER:-Reedman27}"
DIST="${REEDMUHN_DIST:-reedmuhn}"
URL="${FORGEJO_URL%/}/api/packages/$OWNER/debian"
KEYDIR="${APT_KEYRING_DIR:-/etc/apt/keyrings}"; SRCDIR="${APT_SOURCES_DIR:-/etc/apt/sources.list.d}"
mkdir -p "$KEYDIR" "$SRCDIR"
curl -fsSL "$URL/repository.key" -o "$KEYDIR/reedmuhn.asc"
cat > "$SRCDIR/reedmuhn.sources" <<EOF
Types: deb
URIs: $URL
Suites: $DIST
Components: main
Architectures: amd64
Signed-By: $KEYDIR/reedmuhn.asc
EOF
[[ -n "${SKIP_UPDATE:-}" ]] || apt-get update
echo "ReedMuhn repository added ($URL, distribution $DIST)."

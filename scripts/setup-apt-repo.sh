#!/usr/bin/env bash
# Debian/Devuan: add the ReedMuhn APT repository (Forgejo's built-in Debian package registry) so that
#   apt install reedmuhn-base reedmuhn-desktop reedmuhn-wmaker ...
# works, including the packages ReedMuhn builds itself (wm-desktop, wmvol, wmmedia, equibop).
#
#   sudo scripts/setup-apt-repo.sh
#
# What it does, and only this:
#   * downloads the repository's public signing key and installs it as $APT_KEYRING_DIR/reedmuhn.asc
#   * writes ONE new file, $APT_SOURCES_DIR/reedmuhn.sources, with Signed-By pointing at that key
#   * runs apt-get update and checks that ReedMuhn packages are visible
# It never edits your other APT sources, never disables signature checking and never uses
# --allow-unauthenticated. To remove the repository, delete those two files.
#
# Trust: the key is downloaded over HTTPS from the repository host. To pin it, publish its fingerprint
# out-of-band and pass it in:  REEDMUHN_KEY_FPR=<40 hex digits> sudo -E scripts/setup-apt-repo.sh
# (needs gpg). Without a pin, the fingerprint is printed so you can compare it yourself.
#
# Defaults point at https://serverhat.tail973a97.ts.net:8443/api/packages/Reedman27/debian (distribution
# "reedmuhn", component "main"). Overrides: FORGEJO_URL, FORGEJO_OWNER, REEDMUHN_DIST, REEDMUHN_KEY_FILE
# (use a local key file instead of downloading), REEDMUHN_KEY_FPR, APT_KEYRING_DIR, APT_SOURCES_DIR,
# SKIP_UPDATE=1.
set -euo pipefail

FORGEJO_URL="${FORGEJO_URL:-https://serverhat.tail973a97.ts.net:8443}"
OWNER="${FORGEJO_OWNER:-Reedman27}"
DIST="${REEDMUHN_DIST:-reedmuhn}"
URL="${FORGEJO_URL%/}/api/packages/$OWNER/debian"
KEYDIR="${APT_KEYRING_DIR:-/etc/apt/keyrings}"; SRCDIR="${APT_SOURCES_DIR:-/etc/apt/sources.list.d}"
case "${1:-}" in -h|--help) sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; "") ;; *) echo "unknown argument: $1" >&2; exit 2 ;; esac

[[ "$DIST" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || { echo "Invalid distribution name: $DIST" >&2; exit 2; }
if [[ $EUID -ne 0 && -z "${APT_KEYRING_DIR:-}" ]]; then echo "Run as root (or with sudo)" >&2; exit 1; fi
if command -v dpkg >/dev/null && [[ "$(dpkg --print-architecture)" != amd64 ]]; then
  echo "WARNING: this repository serves amd64 (and architecture-independent) packages; this machine is $(dpkg --print-architecture)." >&2
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if [[ -n "${REEDMUHN_KEY_FILE:-}" ]]; then
  cp "$REEDMUHN_KEY_FILE" "$TMP/key.asc"
else
  command -v curl >/dev/null || { echo "curl is required (apt install curl ca-certificates)" >&2; exit 1; }
  curl -fsSL --retry 3 "$URL/repository.key" -o "$TMP/key.asc" \
    || { echo "Could not download $URL/repository.key (is the host reachable from this machine?)" >&2; exit 1; }
fi

# Refuse anything that is not an armored public key (for example an HTML error page).
head -n1 "$TMP/key.asc" | grep -q '^-----BEGIN PGP PUBLIC KEY BLOCK-----' \
  || { echo "The downloaded file is not an ASCII-armored PGP public key; refusing to use it." >&2; exit 1; }

want_fpr="$(tr -d '[:space:]' <<<"${REEDMUHN_KEY_FPR:-}")"
if command -v gpg >/dev/null; then
  fprs="$(gpg --show-keys --with-colons "$TMP/key.asc" 2>/dev/null | awk -F: '/^fpr/ { print $10 }')"
  [[ -n "$fprs" ]] || { echo "gpg could not read the downloaded key; refusing to use it." >&2; exit 1; }
  echo "Repository key fingerprint(s):"; printf "  %s\n" "${fprs//$'\n'/ }"
  if [[ -n "$want_fpr" ]]; then
    grep -qix "$want_fpr" <<<"$fprs" || { echo "Key fingerprint does not match REEDMUHN_KEY_FPR; refusing to trust it." >&2; exit 1; }
    echo "Fingerprint matches REEDMUHN_KEY_FPR."
  else
    echo "No REEDMUHN_KEY_FPR given: compare the fingerprint above with the one the repository owner published."
  fi
elif [[ -n "$want_fpr" ]]; then
  echo "REEDMUHN_KEY_FPR was given but gpg is not installed to check it (apt install gpg)." >&2; exit 1
else
  echo "NOTE: gpg is not installed, so the key fingerprint was not displayed."
fi

mkdir -p "$KEYDIR" "$SRCDIR"
install -m 0644 "$TMP/key.asc" "$KEYDIR/reedmuhn.asc"
cat > "$TMP/reedmuhn.sources" <<EOF
Types: deb
URIs: $URL
Suites: $DIST
Components: main
Architectures: amd64
Signed-By: $KEYDIR/reedmuhn.asc
EOF
install -m 0644 "$TMP/reedmuhn.sources" "$SRCDIR/reedmuhn.sources"
echo "Wrote $SRCDIR/reedmuhn.sources (distribution $DIST) and $KEYDIR/reedmuhn.asc."

[[ -n "${SKIP_UPDATE:-}" ]] && exit 0
apt-get update || { echo "apt-get update failed; the repository is configured but could not be read. Check connectivity and that packages have been published." >&2; exit 1; }

seen=0
for p in reedmuhn-base equibop wm-desktop wmvol wmmedia; do
  cand="$(apt-cache policy "$p" 2>/dev/null | sed -n 's/^ *Candidate: //p')"
  if [[ -n "$cand" && "$cand" != "(none)" ]]; then echo "ok  $p $cand"; seen=1; else echo "--  $p: not in the repository (yet)"; fi
done
(( seen )) || { echo "The repository is reachable but none of the ReedMuhn packages are listed: has scripts/publish-forgejo.sh been run for distribution '$DIST'?" >&2; exit 1; }
echo "ReedMuhn repository ready ($URL, distribution $DIST)."

#!/usr/bin/env bash
# Upload every .deb in out/ to the Forgejo Debian registry.
#   FORGEJO_USER=Reedman27 FORGEJO_TOKEN=xxxx scripts/publish-forgejo.sh
# The token needs write:package. Overrides: FORGEJO_URL, FORGEJO_OWNER, REEDMUHN_DIST, OUT_DIR, CURL.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
FORGEJO_URL="${FORGEJO_URL:-https://serverhat.tail973a97.ts.net:8443}"
OWNER="${FORGEJO_OWNER:-Reedman27}"; DIST="${REEDMUHN_DIST:-reedmuhn}"
OUT="${OUT_DIR:-$HERE/out}"; CURL="${CURL:-curl}"
: "${FORGEJO_USER:?set FORGEJO_USER}"; : "${FORGEJO_TOKEN:?set FORGEJO_TOKEN}"
shopt -s nullglob; files=("$OUT"/*.deb)
[[ ${#files[@]} -gt 0 ]] || { echo "No .deb files in $OUT: run scripts/build-deb.sh first" >&2; exit 1; }
for f in "${files[@]}"; do
  echo "Uploading $(basename "$f")"
  code="$($CURL -sS -o /dev/null -w '%{http_code}' --user "$FORGEJO_USER:$FORGEJO_TOKEN" --upload-file "$f" \
    "${FORGEJO_URL%/}/api/packages/$OWNER/debian/pool/$DIST/main/upload")"
  case "$code" in 201) ;; 409) echo "  already published (same version); bump VERSION to republish" ;; *) echo "  failed: HTTP $code" >&2; exit 1 ;; esac
done

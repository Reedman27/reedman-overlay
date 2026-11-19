#!/usr/bin/env bash
# Upload every .deb in out/ to the Forgejo Debian registry, then confirm they are listed in the APT index.
#
#   FORGEJO_USER=Reedman27 FORGEJO_TOKEN=xxxx scripts/publish-forgejo.sh
#   scripts/publish-forgejo.sh --dry-run          (checks everything, uploads nothing, needs no credentials)
#
# Credentials come only from the environment (FORGEJO_USER plus FORGEJO_TOKEN, or FORGEJO_TOKEN_FILE holding the
# token); nothing is stored in the repository, and the token is never put on a command line. The token needs the
# write:package scope.
#
# Before anything is uploaded the script refuses to continue if
#   * a file is not a valid .deb, or is neither amd64 nor architecture "all" (the APT index is amd64);
#   * an equibop .deb does not match the pinned EQUIBOP_SHA256 (see verify_equibop in scripts/deb-common.sh);
#   * a reedmuhn-* metapackage depends on a package this repository provides (wm-desktop, wmvol, wmmedia,
#     equibop - see deb/package-sources.conf) that is not in out/, because users could not install it.
#     Set PUBLISH_PARTIAL=1 only when those packages are already in the registry.
#
# Overrides: FORGEJO_URL, FORGEJO_OWNER, REEDMUHN_DIST (default reedmuhn), OUT_DIR, CURL, SKIP_VERIFY=1.
# A given package version can be uploaded only once (HTTP 409 is reported, not treated as failure): bump
# VERSION and run scripts/gen.py before republishing a changed metapackage.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/deb-common.sh
. "$HERE/scripts/deb-common.sh"

DRY=0
case "${1:-}" in
  --dry-run) DRY=1 ;;
  -h|--help) sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) echo "unknown argument: $1 (try --help)" >&2; exit 2 ;;
esac

FORGEJO_URL="${FORGEJO_URL:-https://serverhat.tail973a97.ts.net:8443}"
OWNER="${FORGEJO_OWNER:-Reedman27}"; DIST="${REEDMUHN_DIST:-reedmuhn}"
OUT="${OUT_DIR:-$HERE/out}"; CURL="${CURL:-curl}"
REPO="${FORGEJO_URL%/}/api/packages/$OWNER/debian"
[[ "$DIST" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || { echo "Invalid distribution name: $DIST" >&2; exit 2; }

if (( ! DRY )); then
  if [[ -z "${FORGEJO_TOKEN:-}" && -n "${FORGEJO_TOKEN_FILE:-}" ]]; then FORGEJO_TOKEN="$(tr -d '[:space:]' < "$FORGEJO_TOKEN_FILE")"; fi
  if [[ -z "${FORGEJO_USER:-}" || -z "${FORGEJO_TOKEN:-}" ]]; then
    cat >&2 <<EOF
Missing credentials. Set FORGEJO_USER and FORGEJO_TOKEN (a Forgejo access token with write:package):
  FORGEJO_USER=$OWNER FORGEJO_TOKEN=... scripts/publish-forgejo.sh
Create the token under Settings -> Applications on $FORGEJO_URL. Use --dry-run to check the packages without it.
EOF
    exit 1
  fi
fi

shopt -s nullglob
files=("$OUT"/*.deb)
(( ${#files[@]} )) || { echo "No .deb files in $OUT: run scripts/build-deb.sh first" >&2; exit 1; }
command -v dpkg-deb >/dev/null || { echo "dpkg-deb is required to inspect packages before upload" >&2; exit 1; }

# ---- preflight ----
declare -A have_pkg=()
names=(); versions=(); archs=()
for f in "${files[@]}"; do
  is_deb_file "$f" || { echo "Refusing to upload $f: not a Debian package" >&2; exit 1; }
  p="$(deb_field "$f" Package)"; v="$(deb_field "$f" Version)"; a="$(deb_field "$f" Architecture)"
  [[ -n "$p" && -n "$v" ]] || { echo "Refusing to upload $f: no Package/Version in its control data" >&2; exit 1; }
  case "$a" in amd64|all) ;; *) echo "Refusing to upload $(basename "$f"): architecture '$a' is not in the amd64 APT index" >&2; exit 1 ;; esac
  if [[ "$p" == equibop ]]; then
    verify_equibop "$f" "$v" || { echo "Refusing to publish an unverified Equibop package." >&2; exit 1; }
  fi
  have_pkg[$p]=1; names+=("$p"); versions+=("$v"); archs+=("$a")
done

if [[ -z "${PUBLISH_PARTIAL:-}" ]]; then
  bad=0
  for f in "${files[@]}"; do
    p="$(deb_field "$f" Package)"
    [[ "$p" == reedmuhn-* ]] || continue
    while IFS= read -r grp; do
      [[ "$grp" == *'|'* ]] && continue
      case "$(deb_origin "$grp")" in
        built|upstream)
          if [[ -z "${have_pkg[$grp]:-}" ]]; then
            echo "Refusing to publish: $p depends on $grp, which is not in $OUT. Run scripts/build-deb.sh (or set PUBLISH_PARTIAL=1 if $grp is already in the registry)." >&2
            bad=1
          fi ;;
      esac
    done < <(deb_field "$f" Depends | dep_groups)
  done
  (( bad == 0 )) || exit 1
fi

echo "Publishing to $REPO (distribution $DIST, component main):"
for i in "${!files[@]}"; do printf '  %-24s %-34s %s\n' "${names[$i]}" "${versions[$i]}" "$(deb_field "${files[$i]}" Architecture)"; done
if (( DRY )); then echo "Dry run: preflight passed, nothing uploaded."; exit 0; fi

# ---- upload ----
cfg_escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }
# The credentials reach curl through a config file descriptor, not argv, so they never show up in `ps`.
req() { $CURL -sS -K <(printf 'user = "%s:%s"\n' "$(cfg_escape "$FORGEJO_USER")" "$(cfg_escape "$FORGEJO_TOKEN")") "$@"; }

uploaded=0
for f in "${files[@]}"; do
  echo "Uploading $(basename "$f")"
  code="$(req -o /dev/null -w '%{http_code}' --upload-file "$f" "$REPO/pool/$DIST/main/upload")"
  case "$code" in
    201) uploaded=$((uploaded + 1)) ;;
    409) echo "  already published (same version); bump VERSION to republish a changed package" ;;
    401|403) echo "  rejected (HTTP $code): check FORGEJO_USER/FORGEJO_TOKEN and that the token has write:package for $OWNER" >&2; exit 1 ;;
    404) echo "  HTTP 404: check FORGEJO_URL ($FORGEJO_URL) and FORGEJO_OWNER ($OWNER), and that the Debian registry is enabled" >&2; exit 1 ;;
    *) echo "  failed: HTTP $code" >&2; exit 1 ;;
  esac
done
echo "$uploaded new file(s) uploaded."

# ---- verify that the APT index now lists everything ----
# Forgejo keeps one index per architecture: "all" packages (the metapackages) are in binary-all/Packages, the rest in
# binary-amd64/Packages. Each package is looked up in the index for its own architecture.
[[ -z "${SKIP_VERIFY:-}" ]] || exit 0
tmpfiles=(); trap 'rm -f "${tmpfiles[@]}"' EXIT
declare -A idx=()
for a in "${archs[@]}"; do
  [[ -z "${idx[$a]:-}" ]] || continue
  idx[$a]="$(mktemp)"; tmpfiles+=("${idx[$a]}")
  code="$(req -o "${idx[$a]}" -w '%{http_code}' "$REPO/dists/$DIST/main/binary-$a/Packages")"
  if [[ "$code" != 200 ]]; then
    echo "Uploaded, but the index $REPO/dists/$DIST/main/binary-$a/Packages returned HTTP $code; check it before announcing the repository." >&2
    exit 1
  fi
done
missing=0
for i in "${!names[@]}"; do
  if awk -v p="${names[$i]}" -v v="${versions[$i]}" 'BEGIN { RS = ""; FS = "\n" }
       { pk = ""; vr = ""; for (j = 1; j <= NF; j++) { if ($j ~ /^Package: /) pk = substr($j, 10); if ($j ~ /^Version: /) vr = substr($j, 10) } if (pk == p && vr == v) f = 1 }
       END { exit !f }' "${idx[${archs[$i]}]}"; then
    echo "indexed  ${names[$i]} ${versions[$i]} (${archs[$i]})"
  else
    echo "NOT INDEXED  ${names[$i]} ${versions[$i]} (${archs[$i]})" >&2; missing=1
  fi
done
(( missing == 0 )) || { echo "Some packages are not in the APT index." >&2; exit 1; }
echo "All packages are listed in the signed APT index (distribution $DIST). Next: doas apt update && doas apt install reedmuhn-base"
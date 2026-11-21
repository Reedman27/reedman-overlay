#!/usr/bin/env bash
# Debian/Devuan: enable what reedmuhn-gaming needs from the Debian archive.
#
#   sudo scripts/enable-steam-prereqs.sh [--dry-run] [--non-free]
#
# What is actually required (checked against Debian 13 package metadata):
#   winetricks       lives in the "contrib" component
#   steam-installer  lives in "contrib"; it depends on steam-libs-i386, so dpkg needs the i386 architecture
# So this script (1) adds "contrib" and (2) enables the i386 architecture. "non-free" is NOT needed by Steam or
# Wine; it is only for proprietary drivers such as NVIDIA's. Add it with --non-free (or ENABLE_NON_FREE=1) if you
# want it. "non-free-firmware" is never added or removed. Enabling i386 does not by itself make anything
# available: the packages must also be present in an enabled component, which is why both steps exist.
#
# Safety:
#   * Only entries that APT itself reports as the Debian/Devuan archive (Origin: Debian|Devuan, plus the usual
#     debian.org / devuan.org hosts) for THIS release are touched. Third-party repositories (Docker, Cider,
#     ReedMuhn, ...) are never edited, whatever their file is called.
#   * Both the one-line format (/etc/apt/sources.list, *.list) and deb822 (*.sources) are handled, wherever
#     the Debian entry lives. Nothing assumes a file called debian.sources.
#   * Components are only ever appended. Every file that changes is first copied to
#     $BACKUP_DIR/<timestamp>/ (default /var/backups/reedmuhn-apt), and a unified diff is printed.
#   * Idempotent: a second run changes nothing.
#
# Overrides (mainly for tests): SOURCES_DIR, SOURCES_LIST, BACKUP_DIR, OS_RELEASE, APT_POLICY_FILE,
#   CODENAME, SKIP_DPKG=1 (do not touch dpkg), SKIP_UPDATE=1 (no apt-get update / verification).
set -euo pipefail

DRY=0; WANT_NONFREE="${ENABLE_NON_FREE:-0}"
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --non-free) WANT_NONFREE=1 ;;
    -h|--help) sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $a (try --help)" >&2; exit 2 ;;
  esac
done

DIR="${SOURCES_DIR:-/etc/apt/sources.list.d}"
LIST="${SOURCES_LIST:-/etc/apt/sources.list}"
BACKUP_ROOT="${BACKUP_DIR:-/var/backups/reedmuhn-apt}"
[[ $DRY -eq 1 || -n "${SKIP_DPKG:-}" || $EUID -eq 0 ]] || { echo "Run as root (or with sudo), or use --dry-run" >&2; exit 1; }

# ---- which system is this? ----
# shellcheck disable=SC1090,SC1091
. "${OS_RELEASE:-/etc/os-release}"
case "${ID:-}" in
  debian|devuan) ;;
  *) echo "This helper supports Debian and Devuan only (found: ${PRETTY_NAME:-${ID:-unknown}})." >&2
     echo "On Ubuntu and derivatives Steam comes from the 'multiverse' component instead." >&2; exit 1 ;;
esac
CODENAME="${CODENAME:-${VERSION_CODENAME:-}}"
[[ "$CODENAME" =~ ^[a-z0-9]+$ ]] || { echo "Cannot determine the release codename; set CODENAME=trixie (or your release)." >&2; exit 1; }
if [[ -z "${SKIP_DPKG:-}" ]] && command -v dpkg >/dev/null && [[ "$(dpkg --print-architecture)" != amd64 ]]; then
  echo "WARNING: Steam's installer package is amd64 only; this machine is $(dpkg --print-architecture)." >&2
fi

WANT="contrib"; [[ "$WANT_NONFREE" == 1 ]] && WANT="contrib non-free"
SUITE_RE="^(${CODENAME}|stable)(-[a-z-]+)?\$"
HOST_RE='^https?://([A-Za-z0-9-]+\.)*(debian|devuan)\.org(:[0-9]+)?(/|$)'

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

policy() { if [[ -n "${APT_POLICY_FILE:-}" ]]; then cat "$APT_POLICY_FILE"; else apt-cache policy 2>/dev/null || true; fi; }

# Archive URIs that APT reports as Debian/Devuan (covers regional mirrors on other hostnames).
policy | awk '
  /^[ \t]+[0-9]+[ \t]+\//        { url = ""; next }
  /^[ \t]+[0-9]+[ \t]+https?:\/\// { url = $2; next }
  /^[ \t]+release /              { if (url != "" && ($0 ~ /o=Debian/ || $0 ~ /o=Devuan/)) print url; url = "" }
' | sort -u > "$WORK/trusted"

# ---- editors: read a file on stdin, write the edited file on stdout ----
AWK_COMMON='
function trim_uri(u) { sub(/\/+$/, "", u); return u }
function is_trusted(u,  t) { t = trim_uri(u); return (t in trusted) || (t ~ host_re) }
BEGIN { while ((getline l < trusted_file) > 0) trusted[trim_uri(l)] = 1; nw = split(want, W, " ") }
function missing(have,  k, add) { add = ""; for (k = 1; k <= nw; k++) if (!(W[k] in have)) add = add " " W[k]; return add }
'

edit_oneline() {
  awk -v trusted_file="$WORK/trusted" -v want="$WANT" -v host_re="$HOST_RE" -v suite_re="$SUITE_RE" -v qfile="$WORK/qualifying" "$AWK_COMMON"'
  {
    line = $0; comment = ""
    if (match(line, /[ \t]+#.*$/)) { comment = substr(line, RSTART); line = substr(line, 1, RSTART - 1) }
    n = split(line, T, /[ \t]+/); i = 1
    while (i <= n && T[i] == "") i++
    if (line ~ /^[ \t]*#/ || i > n || (T[i] != "deb" && T[i] != "deb-src")) { print $0; next }
    i++
    if (T[i] ~ /^\[/) { while (i <= n && T[i] !~ /\]$/) i++; i++ }
    uri = T[i]; suite = T[i + 1]; hasmain = 0; delete have
    for (j = i + 2; j <= n; j++) { have[T[j]] = 1; if (T[j] == "main") hasmain = 1 }
    add = missing(have)
    if (hasmain && is_trusted(uri) && suite ~ suite_re) {
      print "q" >> qfile                                   # a Debian archive entry we are responsible for
      if (add != "") { print line add comment; next }
    }
    print $0
  }'
}

edit_deb822() {
  awk -v trusted_file="$WORK/trusted" -v want="$WANT" -v host_re="$HOST_RE" -v suite_re="$SUITE_RE" -v qfile="$WORK/qualifying" "$AWK_COMMON"'
  function flush(  i, f, cur, v, uris, nu, u, ok, suites, ns, s, comps, nc, c, hasmain, add, ci) {
    cur = ""; ci = 0
    for (i = 1; i <= cnt; i++) {
      if (L[i] ~ /^#/) continue
      if (L[i] ~ /^[^ \t#][^:]*:/) {
        f = tolower(substr(L[i], 1, index(L[i], ":") - 1)); v = substr(L[i], index(L[i], ":") + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", v); val[f] = v; idx[f] = i; cont[f] = 0; cur = f
      } else if (L[i] ~ /^[ \t]/ && cur != "") {
        v = L[i]; gsub(/^[ \t]+|[ \t]+$/, "", v); val[cur] = val[cur] " " v; cont[cur]++
      }
    }
    if (("components" in idx) && cont["components"] == 0 && tolower(val["enabled"]) != "no") {
      ok = 0; nu = split(val["uris"], uris, /[ \t]+/)
      for (u = 1; u <= nu; u++) if (uris[u] != "" && is_trusted(uris[u])) ok = 1
      if (ok) {
        ok = 0; ns = split(val["suites"], suites, /[ \t]+/)
        for (s = 1; s <= ns; s++) if (suites[s] != "" && suites[s] ~ suite_re) ok = 1
      }
      if (ok) {
        delete have; hasmain = 0; nc = split(val["components"], comps, /[ \t]+/)
        for (c = 1; c <= nc; c++) { have[comps[c]] = 1; if (comps[c] == "main") hasmain = 1 }
        add = missing(have)
        if (hasmain) {
          print "q" >> qfile
          if (add != "") L[idx["components"]] = L[idx["components"]] add
        }
      }
    }
    for (i = 1; i <= cnt; i++) print L[i]
    cnt = 0; delete val; delete idx; delete cont
  }
  /^[ \t]*$/ { flush(); print; next }
  { L[++cnt] = $0 }
  END { flush() }'
}

# ---- apply to every APT source file ----
stamp="$(date +%Y%m%dT%H%M%S)"; changed=()
shopt -s nullglob
files=(); [[ -f "$LIST" ]] && files+=("$LIST")
files+=("$DIR"/*.list "$DIR"/*.sources)
for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  if [[ "$f" == *.sources ]]; then edit_deb822 < "$f" > "$WORK/new"; else edit_oneline < "$f" > "$WORK/new"; fi
  if ! cmp -s "$f" "$WORK/new"; then
    echo "== $f: adding ${WANT// /, } to the Debian archive entries"
    diff -u "$f" "$WORK/new" | sed '1,2d' || true
    if [[ $DRY -eq 0 ]]; then
      mkdir -p "$BACKUP_ROOT/$stamp"; cp -p "$f" "$BACKUP_ROOT/$stamp/$(basename "$f")"
      cat "$WORK/new" > "$f"          # rewrite in place: owner and mode of the original are kept
    fi
    changed+=("$f")
  fi
done
(( ${#changed[@]} == 0 )) || { [[ $DRY -eq 1 ]] && echo "(dry run: nothing was written)" || echo "Backups of changed files: $BACKUP_ROOT/$stamp/"; }

if (( ${#changed[@]} == 0 )); then
  if [[ -s "$WORK/qualifying" ]]; then
    echo "Already enabled in your Debian archive entries: ${WANT// /, }."
  else
    echo "Found no Debian/Devuan '$CODENAME main' entry to extend in $LIST or $DIR." >&2
    echo "Your sources may use a mirror that APT does not report as Debian, or an unusual layout." >&2
    echo "Add ${WANT// /, } to the Components of your Debian entry by hand, then re-run this script." >&2
    exit 1
  fi
fi

# ---- i386 ----
if [[ -z "${SKIP_DPKG:-}" ]]; then
  if dpkg --print-foreign-architectures | grep -qx i386; then
    echo "i386 architecture already enabled."
  elif [[ $DRY -eq 1 ]]; then
    echo "Would run: dpkg --add-architecture i386"
  else
    dpkg --add-architecture i386; echo "Enabled the i386 architecture."
  fi
fi

[[ $DRY -eq 1 || -n "${SKIP_UPDATE:-}" ]] || apt-get update

# ---- verify, so success means something ----
if [[ $DRY -eq 0 && -z "${SKIP_UPDATE:-}" ]]; then
  bad=0
  for p in winetricks steam-installer; do
    cand="$(apt-cache policy "$p" | sed -n 's/^ *Candidate: //p')"
    if [[ -n "$cand" && "$cand" != "(none)" ]]; then echo "ok  $p $cand"; else echo "MISSING  $p has no installation candidate" >&2; bad=1; fi
  done
  if (( bad )); then
    echo "Check 'apt-cache policy steam-installer'. Both packages are in Debian's contrib component for $CODENAME." >&2
    exit 1
  fi
  echo "Steam prerequisites are in place. Existing third-party repositories that do not ship i386 packages" \
       "should be limited with 'Architectures: amd64' (the ReedMuhn repository already is)."
fi

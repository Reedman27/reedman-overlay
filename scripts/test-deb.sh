#!/usr/bin/env bash
# Offline tests for the Debian packaging. Needs dpkg-deb, python3 and bash; no network, no root, no APT.
#   scripts/test-deb.sh
# 1. every generated metapackage builds and has the right fields
# 2. deb/package-sources.conf agrees with the metapackages (nothing the repo must provide is unlisted or unused)
# 3. build-deb.sh: opt-outs never leave a metapackage whose repo-provided dependency is missing
# 4. Equibop: only a file whose SHA-256 and metadata match the pin may enter out/
# 5. enable-steam-prereqs.sh edits only the Debian archive entries and keeps third-party sources intact
# 6. publish-forgejo.sh refuses an uninstallable set and publishes a complete one (against a mock Forgejo)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
command -v dpkg-deb >/dev/null || { echo 'dpkg-deb is required' >&2; exit 1; }
python3 "$HERE/scripts/gen.py" >/dev/null
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok   $*"; }

# ---------------------------------------------------------------- 1. metapackages
count=0
mkdir -p "$work/meta"
for d in "$HERE"/deb/reedmuhn-*/; do
  [[ -f "$d/DEBIAN/control" ]] || continue
  name="$(basename "$d")"
  [[ "$name" == reedmuhn-cider ]] && continue # requires the optional upstream Cider repository package
  cp -a "$d" "$work/meta/$name"
  find "$work/meta/$name" -type d -exec chmod g-s {} +
  find "$work/meta/$name" -type d -exec chmod 755 {} +
  find "$work/meta/$name" -type f -exec chmod 644 {} +
  dpkg-deb --root-owner-group --build "$work/meta/$name" "$work/meta/${name}.deb" >/dev/null
  dpkg-deb --info "$work/meta/${name}.deb" >/dev/null
  dpkg-deb --field "$work/meta/${name}.deb" Package | grep -Fx "$name" >/dev/null
  dpkg-deb --field "$work/meta/${name}.deb" Architecture | grep -Fx all >/dev/null
  count=$((count + 1))
done
[[ "$count" -ge 6 ]] || fail "expected at least six core metapackages; built $count"
ok "built and inspected $count Debian metapackages"

# ---------------------------------------------------------------- 2. conf <-> metapackages
# shellcheck source=scripts/deb-common.sh
. "$HERE/scripts/deb-common.sh"
used=" "
for c in "$HERE"/deb/reedmuhn-*/DEBIAN/control; do
  while IFS= read -r grp; do used+="${grp//|/ } "; done < <(ctl_field "$c" Depends | dep_groups)
done
for p in $(deb_with_origin built upstream); do
  [[ "$used" == *" $p "* ]] || fail "$p is marked '$(deb_origin "$p")' in deb/package-sources.conf but no metapackage depends on it"
done
for p in winetricks steam-installer; do
  [[ "$(deb_origin "$p")" == contrib* ]] || fail "$p must be listed as a contrib package in deb/package-sources.conf"
done
for p in wm-desktop wmvol wmmedia; do
  [[ -d "$HERE/deb/hosted/$p/debian" ]] || fail "no deb/hosted/$p/debian for the built package $p"
done
grep -Fq 'steam-installer' "$HERE/deb/reedmuhn-gaming/DEBIAN/control" || fail "reedmuhn-gaming lost steam-installer"
ok "deb/package-sources.conf matches the metapackage dependencies"

# ---------------------------------------------------------------- helpers for the build/publish tests
mkdeb() { # <outdir> <package> <version> <arch> [depends]
  local d="$work/mk/$2-$3"; rm -rf "$d"; mkdir -p "$d/DEBIAN" "$1"
  { echo "Package: $2"; echo "Version: $3"; echo "Architecture: $4"; echo "Maintainer: Test <test@example.invalid>"
    [[ -z "${5:-}" ]] || echo "Depends: $5"; echo "Description: test package"; } > "$d/DEBIAN/control"
  dpkg-deb --root-owner-group --build "$d" "$1/$2_$3_$4.deb" >/dev/null
}
new_repo() { # copy of the repository without out/ or .git, so build tests cannot touch the real tree
  rm -rf "$work/repo"; mkdir -p "$work/repo"
  tar -C "$HERE" --exclude=./out --exclude=./.git -cf - . | tar -C "$work/repo" -xf -
}

# ---------------------------------------------------------------- 3. opt-outs stay consistent
new_repo
log="$(cd "$work/repo" && BUILD_EQUIBOP=0 SKIP_WM_DESKTOP=1 SKIP_DOCKAPPS=1 scripts/build-deb.sh 2>&1)"
for m in base development networking gaming; do compgen -G "$work/repo/out/reedmuhn-${m}_*_all.deb" >/dev/null || fail "reedmuhn-$m was not built"; done
for m in desktop wmaker; do
  compgen -G "$work/repo/out/reedmuhn-${m}_*_all.deb" >/dev/null && fail "reedmuhn-$m was built although its repo-provided dependency was not"
  grep -q "SKIPPED reedmuhn-$m" <<<"$log" || fail "build did not say that reedmuhn-$m was skipped"
done
ok "build-deb.sh: opted-out dependencies skip their metapackages loudly"

# ---------------------------------------------------------------- 4. Equibop verification
eqdir="$work/eq"; mkdeb "$eqdir" equibop 3.3.4 amd64 "libc6"
eqsum="$(sha256sum "$eqdir/equibop_3.3.4_amd64.deb" | awk '{print $1}')"
build_eq() { # <sha> -> runs build-deb.sh in the scratch repo using the synthetic Equibop
  ( cd "$work/repo" && EQUIBOP_DEB_URL="file://$eqdir/equibop_3.3.4_amd64.deb" EQUIBOP_VERSION=3.3.4 EQUIBOP_SHA256="$1" \
    SKIP_WM_DESKTOP=1 SKIP_DOCKAPPS=1 scripts/build-deb.sh ) 2>&1
}
new_repo
build_eq "$eqsum" >/dev/null || fail "build with a correct Equibop checksum failed"
[[ -f "$work/repo/out/equibop_3.3.4_amd64.deb" ]] || fail "verified Equibop did not reach out/"
compgen -G "$work/repo/out/reedmuhn-desktop_*_all.deb" >/dev/null || fail "reedmuhn-desktop not built although equibop was"
new_repo
if build_eq "$(printf '0%.0s' {1..64})" >/dev/null; then fail "build accepted a wrong Equibop checksum"; fi
compgen -G "$work/repo/out/equibop_*.deb" >/dev/null && fail "unverified Equibop file was left in out/"
mkdeb "$work/eqbad" notequibop 3.3.4 amd64
if EQUIBOP_SHA256="$(sha256sum "$work/eqbad/notequibop_3.3.4_amd64.deb" | awk '{print $1}')" \
   verify_equibop "$work/eqbad/notequibop_3.3.4_amd64.deb" 3.3.4 >/dev/null 2>&1; then
  fail "verify_equibop accepted a package not named equibop"
fi
mkdeb "$work/eqarm" equibop 3.3.4 arm64
if EQUIBOP_SHA256="$(sha256sum "$work/eqarm/equibop_3.3.4_arm64.deb" | awk '{print $1}')" \
   verify_equibop "$work/eqarm/equibop_3.3.4_arm64.deb" 3.3.4 >/dev/null 2>&1; then
  fail "verify_equibop accepted a non-amd64 Equibop"
fi
ok "Equibop: wrong checksum, wrong name and wrong architecture are all rejected; nothing unverified lands in out/"

# ---------------------------------------------------------------- 5. Steam prerequisites helper
fx="$work/fx"; mkdir -p "$fx/d" "$fx/etc"
printf 'ID=debian\nVERSION_CODENAME=trixie\nPRETTY_NAME="Debian 13"\n' > "$fx/etc/os-release"
cat > "$fx/sources.list" <<'EOF'
deb http://deb.debian.org/debian/ trixie main non-free-firmware
deb http://security.debian.org/debian-security trixie-security main non-free-firmware
deb https://repo.cider.sh/apt stable main
deb https://packages.example.invalid/debian/13 trixie main
EOF
cat > "$fx/d/other.sources" <<'EOF'
Types: deb
URIs: https://download.example.invalid/linux/debian
Suites: trixie
Components: main
EOF
cat > "$fx/d/reedmuhn.sources" <<'EOF'
Types: deb
URIs: https://forge.example.invalid/api/packages/owner/debian
Suites: reedmuhn
Components: main
Architectures: amd64
EOF
cp "$fx/sources.list" "$fx/sources.list.orig"; cp "$fx/d/other.sources" "$fx/d/other.sources.orig"; cp "$fx/d/reedmuhn.sources" "$fx/d/reedmuhn.sources.orig"
steam() { OS_RELEASE="$fx/etc/os-release" SOURCES_LIST="$fx/sources.list" SOURCES_DIR="$fx/d" BACKUP_DIR="$fx/bak" \
          APT_POLICY_FILE=/dev/null SKIP_DPKG=1 SKIP_UPDATE=1 "$HERE/scripts/enable-steam-prereqs.sh" "$@"; }
steam --dry-run >/dev/null; cmp -s "$fx/sources.list" "$fx/sources.list.orig" || fail "--dry-run modified sources.list"
steam >/dev/null
grep -q '^deb http://deb.debian.org/debian/ trixie main non-free-firmware contrib$' "$fx/sources.list" || fail "contrib not added to the Debian entry"
grep -q 'trixie-security main non-free-firmware contrib$' "$fx/sources.list" || fail "contrib not added to the security entry"
grep -q 'non-free ' "$fx/sources.list" && fail "non-free was added without --non-free"
grep -q '^deb https://repo.cider.sh/apt stable main$' "$fx/sources.list" || fail "third-party Cider line was modified"
grep -q '^deb https://packages.example.invalid/debian/13 trixie main$' "$fx/sources.list" || fail "third-party trixie line was modified"
cmp -s "$fx/d/other.sources" "$fx/d/other.sources.orig" || fail "third-party deb822 file was modified"
cmp -s "$fx/d/reedmuhn.sources" "$fx/d/reedmuhn.sources.orig" || fail "the ReedMuhn sources file was modified"
[[ -n "$(find "$fx/bak" -name sources.list 2>/dev/null)" ]] || fail "no backup of sources.list"
before="$(cat "$fx/sources.list")"; steam >/dev/null; [[ "$before" == "$(cat "$fx/sources.list")" ]] || fail "second run changed sources.list"
nf="$(steam --dry-run --non-free)"; grep -q 'contrib non-free' <<<"$nf" || fail "--non-free did not request non-free"
ok "enable-steam-prereqs.sh: adds contrib only to Debian entries, keeps backups, idempotent, third-party sources untouched"

# ---------------------------------------------------------------- 6. publish against a mock Forgejo
mock="$work/mockcurl"; srv="$work/srv"; mkdir -p "$srv"
cat > "$mock" <<'EOF'
#!/usr/bin/env bash
# Minimal stand-in for the curl calls publish-forgejo.sh makes.
out=""; up=""; url=""; user=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -w) shift 2 ;;
    -K) user="$(cat "$2")"; shift 2 ;;
    --upload-file) up="$2"; shift 2 ;;
    -sS) shift ;;
    *) url="$1"; shift ;;
  esac
done
case "$user" in *"user:secret"*) ;; *) printf '401'; exit 0 ;; esac
if [[ -n "$up" ]]; then
  p="$(dpkg-deb -f "$up" Package)"; v="$(dpkg-deb -f "$up" Version)"
  if grep -qx "$p $v" "$MOCK_DB" 2>/dev/null; then printf '409'; else echo "$p $v" >> "$MOCK_DB"; printf '201'; fi
elif [[ "$url" == */Packages ]]; then
  while read -r p v; do printf 'Package: %s\nVersion: %s\nArchitecture: all\n\n' "$p" "$v"; done < "$MOCK_DB" > "$out"; printf '200'
else printf '404'; fi
EOF
chmod +x "$mock"
pub() { MOCK_DB="$srv/db" CURL="$mock" OUT_DIR="$1" FORGEJO_USER=user FORGEJO_TOKEN=secret EQUIBOP_SHA256="$eqsum" \
        "$HERE/scripts/publish-forgejo.sh" "${@:2}"; }
# 6a. a wmaker metapackage without its standalone packages must be refused
mkdir -p "$work/o1"; cp "$work/meta/reedmuhn-wmaker.deb" "$work/o1/reedmuhn-wmaker_1.0.4_all.deb"
if pub "$work/o1" --dry-run >/dev/null 2>&1; then fail "publish preflight accepted reedmuhn-wmaker without wm-desktop/wmvol/wmmedia"; fi
# 6b. complete set passes, and uploads once
mkdir -p "$work/o2"; cp "$work/o1"/*.deb "$work/o2/"; cp "$work/meta/reedmuhn-desktop.deb" "$work/o2/reedmuhn-desktop_1.0.4_all.deb"
for p in wm-desktop wmvol wmmedia; do mkdeb "$work/o2" "$p" 0.1.0+git20261111.abcdef0-1 amd64; done
cp "$eqdir/equibop_3.3.4_amd64.deb" "$work/o2/"
pub "$work/o2" --dry-run >/dev/null || fail "complete package set failed the preflight"
[[ ! -e "$srv/db" ]] || fail "--dry-run uploaded something"
pub "$work/o2" > "$work/pub.log" || { cat "$work/pub.log" >&2; fail "publish of a complete set failed"; }
[[ "$(wc -l < "$srv/db")" -eq 6 ]] || fail "expected 6 uploads, got $(wc -l < "$srv/db")"
grep -q 'indexed  equibop 3.3.4' "$work/pub.log" || fail "publish did not confirm the index"
again="$(pub "$work/o2" 2>&1)"; grep -q 'already published' <<<"$again" || fail "re-publish did not report HTTP 409 as already published"
# 6c. missing credentials fail with usage text, a wrong token is reported
if env -u FORGEJO_USER -u FORGEJO_TOKEN OUT_DIR="$work/o2" "$HERE/scripts/publish-forgejo.sh" 2>"$work/err"; then fail "publish ran without credentials"; fi
grep -q 'FORGEJO_USER' "$work/err" || fail "missing-credentials message does not mention FORGEJO_USER"
# 6d. an Equibop that does not match the pin is never uploaded
if MOCK_DB="$srv/db2" CURL="$mock" OUT_DIR="$work/o2" FORGEJO_USER=user FORGEJO_TOKEN=secret EQUIBOP_SHA256="$(printf '1%.0s' {1..64})" \
   "$HERE/scripts/publish-forgejo.sh" >/dev/null 2>&1; then fail "publish accepted an Equibop that does not match the pin"; fi
[[ ! -e "$srv/db2" ]] || fail "something was uploaded despite the Equibop mismatch"
ok "publish-forgejo.sh: refuses incomplete sets and unverified Equibop, uploads complete sets, verifies the index, reports 409"

echo "PASS: all Debian packaging tests"

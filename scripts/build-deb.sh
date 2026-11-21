#!/usr/bin/env bash
# Build the native Debian/Devuan packages into out/.
#
#   scripts/build-deb.sh
#
# The default build produces EVERYTHING a metapackage depends on:
#   * the six metapackages (reedmuhn-base, -desktop, -development, -gaming, -networking, -wmaker)
#   * wm-desktop, wmvol, wmmedia   built from source (deb/hosted/)
#   * equibop                      upstream amd64 .deb, mirrored only after a SHA-256 check
# Optional extras (off by default; no metapackage depends on them):
#   BUILD_MINECRAFT=1   mirror Mojang's launcher .deb (set MC_SHA256 to verify it)
#   BUILD_CIDER_REPO=1  build reedmuhn-cider-repo and the reedmuhn-cider metapackage
# Explicit opt-outs (for partial or offline builds):
#   BUILD_EQUIBOP=0  SKIP_WM_DESKTOP=1  SKIP_DOCKAPPS=1
# A metapackage whose repo-provided dependency was opted out is NOT built, and the build says so loudly, so
# out/ never contains a metapackage that its own repository cannot satisfy.
# Other inputs: WM_DESKTOP_REF / DOCKAPPS_REF (pin; see scripts/update-pins.sh), WM_DESKTOP_SRC / DOCKAPPS_SRC
# (local checkouts), EQUIBOP_VERSION, EQUIBOP_SHA256, EQUIBOP_DEB_URL (test override of the download URL).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/deb-common.sh
. "$HERE/scripts/deb-common.sh"
case "${1:-}" in -h|--help) sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; "") ;; *) echo "unknown argument: $1 (try --help)" >&2; exit 2 ;; esac

VER="$(tr -d '[:space:]' < "$HERE/VERSION")"
BUILD_EQUIBOP="${BUILD_EQUIBOP:-1}"

# ---- tools: fail early with a useful message ----
missing=()
need() { command -v "$1" >/dev/null 2>&1 || missing+=("$1 (package: $2)"); }
need dpkg-deb dpkg-dev; need python3 python3; need sha256sum coreutils
if [[ -z "${SKIP_WM_DESKTOP:-}" || -z "${SKIP_DOCKAPPS:-}" ]]; then need dpkg-buildpackage dpkg-dev; fi
if [[ -z "${SKIP_WM_DESKTOP:-}" && -z "${WM_DESKTOP_SRC:-}" ]] || [[ -z "${SKIP_DOCKAPPS:-}" && -z "${DOCKAPPS_SRC:-}" ]]; then need git git; fi
if [[ "$BUILD_EQUIBOP" == 1 || "${BUILD_MINECRAFT:-0}" == 1 ]]; then need curl curl; fi
if [[ "${BUILD_CIDER_REPO:-0}" == 1 ]]; then need gpg gnupg; fi
if (( ${#missing[@]} )); then
  printf 'Missing build tools:\n' >&2; printf '  %s\n' "${missing[@]}" >&2
  echo "Install the Debian build dependencies listed in docs/debian-devuan.md." >&2
  exit 2
fi

python3 "$HERE/scripts/gen.py" >/dev/null
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$HERE/out"
# Drop stale artifacts so old versions can never be picked up by this build or by the publish step.
rm -f "$HERE"/out/reedmuhn-*_all.deb "$HERE"/out/wm-desktop_*.deb "$HERE"/out/wmvol_*.deb "$HERE"/out/wmmedia_*.deb
[[ "$BUILD_EQUIBOP" == 1 ]] && rm -f "$HERE"/out/equibop_*.deb
[[ "${BUILD_MINECRAFT:-0}" == 1 ]] && rm -f "$HERE"/out/minecraft-launcher_*.deb

# ---- hosted source builds: wm-desktop, wmvol, wmmedia ----
# Sources are fetched at the commit pinned in WM_DESKTOP_REF / DOCKAPPS_REF (or the env var of the
# same name). With no pin the newest commit is used and a warning is printed. Either way the Debian
# version carries the upstream commit date and short hash (<base>+git<date>.<sha>-1), so different
# upstream code can never be published under the same package version.
pin() { # <env value> <file>  -> pinned ref, or empty
  if [[ -n "${1:-}" ]]; then printf '%s' "$1"; return; fi
  [[ -f "$2" ]] && grep -v '^[[:space:]]*#' "$2" | tr -d '[:space:]' || true
}
fetch_pinned() { # <url> <ref> <dest>
  local url="$1" ref="$2" dest="$3"
  git init -q "$dest"; git -C "$dest" remote add origin "$url"
  git -C "$dest" fetch -q --depth 1 origin "${ref:-HEAD}"
  git -C "$dest" checkout -q --detach FETCH_HEAD
}
stamp_changelog() { # <pkg> <source dir> <git dir or empty>
  local pkg="$1" dir="$2" gd="${3:-}" tmpl="$HERE/deb/hosted/$1/debian" base maint ver date sha
  base="$(sed -n '1s/^[^(]*(\([^)+-]*\).*/\1/p' "$tmpl/changelog")"
  maint="$(sed -n 's/^Maintainer: //p' "$tmpl/control" | head -n1)"
  ver="${base}-1"
  if [[ -n "$gd" ]] && sha="$(git -C "$gd" rev-parse --short=7 HEAD 2>/dev/null)"; then
    date="$(git -C "$gd" log -1 --format=%cd --date=format:%Y%m%d)"
    ver="${base}+git${date}.${sha}-1"
  fi
  rm -rf "$dir/debian"; cp -a "$tmpl" "$dir/debian"
  printf '%s (%s) unstable; urgency=medium\n\n  * Automated build of upstream commit %s.\n\n -- %s  %s\n' \
    "$pkg" "$ver" "${sha:-unknown}" "$maint" "$(date -R)" > "$dir/debian/changelog"
  echo "$pkg $ver" >&2
}

# wm-desktop is a separate project and is required by reedmuhn-wmaker.
if [[ -z "${SKIP_WM_DESKTOP:-}" ]]; then
  src="$W/wm-desktop"; gd=""
  if [[ -n "${WM_DESKTOP_SRC:-}" ]]; then
    cp -a "$WM_DESKTOP_SRC" "$src"; [[ -d "$src/.git" ]] && gd="$src"
  else
    ref="$(pin "${WM_DESKTOP_REF:-}" "$HERE/WM_DESKTOP_REF")"
    [[ -n "$ref" ]] || echo "WARNING: WM_DESKTOP_REF is not pinned; building the newest upstream commit." >&2
    fetch_pinned "${WM_DESKTOP_URL:-https://github.com/Reedman27/wm-desktop.git}" "$ref" "$src"; gd="$src"
  fi
  stamp_changelog wm-desktop "$src" "$gd"
  ( cd "$src" && dpkg-buildpackage -us -uc -b )
  cp "$W"/wm-desktop_*.deb "$HERE/out/"
fi

# wmvol and wmmedia are dockapps from one shared repository (same layout as the Gentoo ebuilds).
if [[ -z "${SKIP_DOCKAPPS:-}" ]]; then
  da="$W/dockapps-collection"; gd=""
  if [[ -n "${DOCKAPPS_SRC:-}" ]]; then
    cp -a "$DOCKAPPS_SRC" "$da"; [[ -d "$da/.git" ]] && gd="$da"
  else
    ref="$(pin "${DOCKAPPS_REF:-}" "$HERE/DOCKAPPS_REF")"
    [[ -n "$ref" ]] || echo "WARNING: DOCKAPPS_REF is not pinned; building the newest upstream commit." >&2
    fetch_pinned "${DOCKAPPS_URL:-https://github.com/Reedman27/dockapps-collection.git}" "$ref" "$da"; gd="$da"
  fi
  for app in wmvol wmmedia; do
    cp -a "$da/$app" "$W/$app"
    stamp_changelog "$app" "$W/$app" "$gd"
    ( cd "$W/$app" && dpkg-buildpackage -us -uc -b )
    cp "$W"/${app}_*.deb "$HERE/out/"
  done
fi

# ---- Equibop: upstream amd64 .deb, mirrored unmodified, only after verification ----
# The file is downloaded outside out/ and copied in ONLY once its SHA-256 and control metadata have been
# verified (verify_equibop in scripts/deb-common.sh). A mismatch aborts the build and leaves nothing behind in out/.
if [[ "$BUILD_EQUIBOP" == 1 ]]; then
  EQV="${EQUIBOP_VERSION:-$(tr -d '[:space:]' < "$HERE/EQUIBOP_VERSION")}"
  curl -fSL --retry 3 -o "$W/equibop.deb" \
    "${EQUIBOP_DEB_URL:-https://github.com/Equicord/Equibop/releases/download/v${EQV}/equibop_${EQV}_amd64.deb}"
  verify_equibop "$W/equibop.deb" "$EQV" || exit 1
  cp "$W/equibop.deb" "$HERE/out/equibop_$(deb_field "$W/equibop.deb" Version)_amd64.deb"
else
  echo "NOTE: BUILD_EQUIBOP=0 - equibop was not built; reedmuhn-desktop will be skipped." >&2
fi

# ---- Minecraft Launcher: standalone, never a metapackage dependency ----
if [[ "${BUILD_MINECRAFT:-0}" == 1 ]]; then
  curl -fSL --retry 3 "${MC_DEB_URL:-https://launcher.mojang.com/download/Minecraft.deb}" -o "$W/mc.deb"
  is_deb_file "$W/mc.deb" || { echo "Minecraft download is not a .deb" >&2; exit 1; }
  if [[ -n "${MC_SHA256:-}" ]]; then
    actual="$(sha256sum "$W/mc.deb" | awk '{print $1}')"
    [[ "$actual" == "$MC_SHA256" ]] || { echo "Minecraft checksum mismatch" >&2; exit 1; }
  else
    echo "WARNING: MC_SHA256 not supplied; verify the Mojang download before publishing." >&2
  fi
  cp "$W/mc.deb" "$HERE/out/minecraft-launcher_$(deb_field "$W/mc.deb" Version)_$(deb_field "$W/mc.deb" Architecture).deb"
fi

# ---- Cider: opt-in, because its upstream APT index has been unreliable ----
if [[ "${BUILD_CIDER_REPO:-0}" == 1 ]]; then
  [[ -s "$HERE/keys/APT-GPG-KEY" ]] || { echo "keys/APT-GPG-KEY missing: run scripts/fetch-keys.sh and verify the fingerprint" >&2; exit 1; }
  cp -a "$HERE/deb/reedmuhn-cider-repo" "$W/repo"
  sed "s/@VERSION@/$VER/" "$W/repo/DEBIAN/control.in" > "$W/repo/DEBIAN/control"
  rm "$W/repo/DEBIAN/control.in"
  install -d "$W/repo/usr/share/keyrings"
  gpg --dearmor < "$HERE/keys/APT-GPG-KEY" > "$W/repo/usr/share/keyrings/cider-archive-keyring.gpg"
  chmod 644 "$W/repo/usr/share/keyrings/cider-archive-keyring.gpg"
  find "$W/repo" -type d -exec chmod g-s {} +
  find "$W/repo" -type d -exec chmod 755 {} +
  find "$W/repo" -type f -exec chmod 644 {} +
  dpkg-deb --root-owner-group --build "$W/repo" "$HERE/out/reedmuhn-cider-repo_${VER}_all.deb"
fi

# ---- metapackages ----
# have_built <package>: a .deb of that package is in out/ (built or mirrored by this run).
have_built() { compgen -G "$HERE/out/${1}_*.deb" >/dev/null; }
skipped=()
for d in "$HERE"/deb/reedmuhn-*/; do
  n="$(basename "$d")"
  [[ "$n" == reedmuhn-cider-repo ]] && continue
  [[ "$n" == reedmuhn-cider && "${BUILD_CIDER_REPO:-0}" != 1 ]] && continue
  # Every dependency that this repository itself provides must exist in out/ for the metapackage to be buildable.
  lacking=()
  while IFS= read -r grp; do
    [[ "$grp" == *'|'* ]] && continue                       # alternatives: leave to APT
    case "$(deb_origin "$grp")" in
      built|upstream) have_built "$grp" || lacking+=("$grp") ;;
    esac
  done < <(ctl_field "$d/DEBIAN/control" Depends | dep_groups)
  if (( ${#lacking[@]} )); then
    echo "SKIPPED $n: depends on ${lacking[*]}, which this run did not build (opt-out flag set)." >&2
    skipped+=("$n"); continue
  fi
  cp -a "$d" "$W/$n"
  find "$W/$n" -type d -exec chmod g-s {} +
  find "$W/$n" -type d -exec chmod 755 {} +
  find "$W/$n" -type f -exec chmod 644 {} +
  dpkg-deb --root-owner-group --build "$W/$n" "$HERE/out/${n}_${VER}_all.deb"
done

echo
echo "Built into out/:"
for f in "$HERE"/out/*.deb; do
  [[ -f "$f" ]] || continue
  printf '  %-44s %-8s %s\n' "$(basename "$f")" "$(deb_field "$f" Architecture)" "$(deb_field "$f" Depends | cut -c1-90)"
done
if (( ${#skipped[@]} )); then
  echo "NOT built (missing repo-provided dependency): ${skipped[*]}" >&2
fi

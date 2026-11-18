#!/usr/bin/env bash
# Build native Debian/Devuan packages into out/.
# Core build: ./scripts/build-deb.sh
# Optional standalone apps / external integrations:
#   BUILD_MINECRAFT=1 BUILD_EQUIBOP=1 BUILD_CIDER_REPO=1 ./scripts/build-deb.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
VER="$(cat "$HERE/VERSION")"
python3 "$HERE/scripts/gen.py" >/dev/null
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$HERE/out"
# Drop stale core artifacts so old versions or an old opt-in Cider package cannot enter this build.
rm -f "$HERE"/out/reedmuhn-*_all.deb "$HERE"/out/wm-desktop_*.deb "$HERE"/out/wmvol_*.deb "$HERE"/out/wmmedia_*.deb

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

# Minecraft Launcher is a standalone package; never a gaming metapackage dependency.
if [[ "${BUILD_MINECRAFT:-0}" == 1 ]]; then
  curl -fSL "${MC_DEB_URL:-https://launcher.mojang.com/download/Minecraft.deb}" -o "$W/mc.deb"
  [[ "$(head -c 7 "$W/mc.deb")" == '!<arch>' ]] || { echo "Minecraft download is not a .deb" >&2; exit 1; }
  if [[ -n "${MC_SHA256:-}" ]]; then
    actual="$(sha256sum "$W/mc.deb" | awk '{print $1}')"
    [[ "$actual" == "$MC_SHA256" ]] || { echo "Minecraft checksum mismatch" >&2; exit 1; }
  else
    echo "WARNING: MC_SHA256 not supplied; verify the Mojang download before publishing." >&2
  fi
  cp "$W/mc.deb" "$HERE/out/minecraft-launcher_$(dpkg-deb -f "$W/mc.deb" Version)_$(dpkg-deb -f "$W/mc.deb" Architecture).deb"
fi

# Equibop is also standalone. Verify against EQUIBOP_SHA256 when one is supplied.
if [[ "${BUILD_EQUIBOP:-0}" == 1 ]]; then
  EQV="${EQUIBOP_VERSION:-$(cat "$HERE/EQUIBOP_VERSION")}"
  target="$HERE/out/equibop_${EQV}_amd64.deb"
  curl -fSL "https://github.com/Equicord/Equibop/releases/download/v${EQV}/equibop_${EQV}_amd64.deb" -o "$target"
  [[ "$(head -c 7 "$target")" == '!<arch>' ]] || { echo "Equibop download is not a .deb" >&2; exit 1; }
  if [[ -s "$HERE/EQUIBOP_SHA256" ]]; then
    expected="$(tr -d '[:space:]' < "$HERE/EQUIBOP_SHA256")"
    actual="$(sha256sum "$target" | awk '{print $1}')"
    [[ "$expected" == "$actual" ]] || { echo "Equibop checksum mismatch" >&2; exit 1; }
  else
    rm -f "$target"
    echo "EQUIBOP_SHA256 is missing: run scripts/update-equibop.sh $EQV first" >&2; exit 1
  fi
fi

# Cider uses its upstream APT repository and is opt-in because its index has been unreliable.
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

# Build the normal metapackages. Cider is only built when its upstream repo package is built.
for d in "$HERE"/deb/reedmuhn-*/; do
  n="$(basename "$d")"
  [[ "$n" == reedmuhn-cider-repo ]] && continue
  [[ "$n" == reedmuhn-cider && "${BUILD_CIDER_REPO:-0}" != 1 ]] && continue
  cp -a "$d" "$W/$n"
  find "$W/$n" -type d -exec chmod g-s {} +
  find "$W/$n" -type d -exec chmod 755 {} +
  find "$W/$n" -type f -exec chmod 644 {} +
  dpkg-deb --root-owner-group --build "$W/$n" "$HERE/out/${n}_${VER}_all.deb"
done

find "$HERE/out" -maxdepth 1 -type f -name '*.deb' -printf '%f\n' | sort

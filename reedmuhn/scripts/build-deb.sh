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
rm -f "$HERE"/out/reedmuhn-*_all.deb "$HERE"/out/wm-desktop_*.deb

# wm-desktop is a separate project and is required by reedmuhn-wmaker.
if [[ -z "${SKIP_WM_DESKTOP:-}" ]]; then
  src="$W/wm-desktop"
  if [[ -n "${WM_DESKTOP_SRC:-}" ]]; then cp -a "$WM_DESKTOP_SRC" "$src"
  else git clone --depth 1 "${WM_DESKTOP_URL:-https://github.com/Reedman27/wm-desktop.git}" "$src"; fi
  rm -rf "$src/debian"
  cp -a "$HERE/deb/hosted/wm-desktop/debian" "$src/debian"
  ( cd "$src" && dpkg-buildpackage -us -uc -b )
  cp "$W"/wm-desktop_*.deb "$HERE/out/"
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

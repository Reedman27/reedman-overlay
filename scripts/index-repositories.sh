#!/usr/bin/env bash
# Create native repository metadata from packages already built into out/.
# Requires apt-ftparchive, createrepo_c, repo-add and/or xbps-rindex for the formats used.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT_DIR:-$HERE/out}"
PUB="${REPO_DIR:-$HERE/repo}"
mkdir -p "$PUB"/{deb/pool/main,rpm,arch,void}
find "$OUT" -maxdepth 1 -type f -name '*.deb' -exec cp -f {} "$PUB/deb/pool/main/" \;
find "$OUT" -maxdepth 1 -type f -name '*.rpm' -exec cp -f {} "$PUB/rpm/" \;
find "$OUT" -maxdepth 1 -type f -name '*.pkg.tar.*' -exec cp -f {} "$PUB/arch/" \;
find "$OUT/void" -maxdepth 1 -type f -name '*.xbps' -exec cp -f {} "$PUB/void/" \; 2>/dev/null || true

if compgen -G "$PUB/deb/pool/main/*.deb" >/dev/null; then
  command -v apt-ftparchive >/dev/null || { echo 'Install apt-utils for apt-ftparchive' >&2; exit 1; }
  # Use codenames, not the moving "stable" alias. Devuan explicitly recommends this.
  read -r -a suites <<< "${DEB_SUITES:-trixie excalibur}"
  for suite in "${suites[@]}"; do
    [[ "$suite" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "Invalid APT suite: $suite" >&2; exit 1; }
    mkdir -p "$PUB/deb/dists/$suite/main/binary-amd64"
    (cd "$PUB/deb" && apt-ftparchive packages pool/main > "dists/$suite/main/binary-amd64/Packages")
    gzip -9kf "$PUB/deb/dists/$suite/main/binary-amd64/Packages"
    (cd "$PUB/deb" && apt-ftparchive \
      -o APT::FTPArchive::Release::Origin="ReedMuhn" \
      -o APT::FTPArchive::Release::Label="ReedMuhn" \
      -o APT::FTPArchive::Release::Suite="$suite" \
      -o APT::FTPArchive::Release::Codename="$suite" \
      -o APT::FTPArchive::Release::Components="main" \
      -o APT::FTPArchive::Release::Architectures="amd64" \
      release "dists/$suite" > "dists/$suite/Release")
    if [[ -n "${GPG_KEY_ID:-}" ]]; then
      (cd "$PUB/deb/dists/$suite" && gpg --default-key "$GPG_KEY_ID" --clearsign -o InRelease Release && gpg --default-key "$GPG_KEY_ID" -abs -o Release.gpg Release)
    else
      echo "WARNING: APT metadata for $suite is unsigned; do not publish it as a trusted repository." >&2
    fi
  done
fi

if compgen -G "$PUB/rpm/*.rpm" >/dev/null; then
  command -v createrepo_c >/dev/null || { echo 'Install createrepo_c to index RPMs' >&2; exit 1; }
  createrepo_c --update "$PUB/rpm"
fi

if compgen -G "$PUB/arch/*.pkg.tar.*" >/dev/null; then
  command -v repo-add >/dev/null || { echo 'Install pacman-contrib for repo-add' >&2; exit 1; }
  (cd "$PUB/arch" && repo-add reedmuhn.db.tar.gz ./*.pkg.tar.*)
fi

if compgen -G "$PUB/void/*.xbps" >/dev/null; then
  command -v xbps-rindex >/dev/null || { echo 'Install xbps to index Void packages' >&2; exit 1; }
  xbps-rindex --add "$PUB"/void/*.xbps
fi

echo "Repository metadata written to $PUB"

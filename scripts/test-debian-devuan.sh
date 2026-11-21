#!/usr/bin/env bash
# Run the shared ReedMuhn Debian packages once, then resolve the exact same artifacts on Devuan.
# Intended for GitHub Actions or another Linux host with Docker.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v docker >/dev/null 2>&1 || { echo "docker is required for the combined Debian/Devuan test" >&2; exit 2; }
docker info >/dev/null 2>&1 || { echo "Docker daemon is not available" >&2; exit 2; }

echo "== Debian: lint, offline tests, build once, resolve dependencies =="
docker run --rm \
  -v "$ROOT:/workspace" -w /workspace \
  debian:trixie bash -Eeuo pipefail -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
      git ca-certificates nodejs python3 curl shellcheck \
      build-essential dpkg-dev debhelper pkgconf gpg \
      libx11-dev libxext-dev libxft-dev libfontconfig-dev \
      libdbus-1-dev libwraster-dev
    shellcheck -x -S warning \
      scripts/build-deb.sh scripts/check-deps.sh scripts/deb-common.sh \
      scripts/enable-steam-prereqs.sh scripts/update-equibop.sh \
      scripts/test-deb.sh
    scripts/test-deb.sh
    scripts/enable-steam-prereqs.sh
    scripts/build-deb.sh
    scripts/check-deps.sh
  '

echo
echo "== Devuan: resolve the same Debian-built packages against Devuan =="
docker run --rm \
  -v "$ROOT:/workspace" -w /workspace \
  devuan/devuan:excalibur bash -Eeuo pipefail -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates
    scripts/enable-steam-prereqs.sh
    scripts/check-deps.sh
  '

echo
echo "PASS: Debian build and Devuan dependency resolution"

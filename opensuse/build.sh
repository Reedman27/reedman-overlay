#!/usr/bin/env bash
# Build native openSUSE Tumbleweed RPMs from the openSUSE-specific dependency mappings.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SPEC_DIR="$HERE/opensuse" "$HERE/rpm/build.sh"

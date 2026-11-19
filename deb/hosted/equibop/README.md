# Equibop on Debian-family systems

Equibop is an upstream-built amd64 `.deb`; this repository mirrors it unmodified so `reedmuhn-desktop` can depend on it and `apt install` works.

- Built by default (`scripts/build-deb.sh`; `BUILD_EQUIBOP=0` opts out).
- The download goes to a temporary directory and enters `out/` only after `verify_equibop` (scripts/deb-common.sh) confirms the SHA-256 in `EQUIBOP_SHA256`, and that the package is named `equibop`, is `amd64`, and has the pinned version. A mismatch aborts the build.
- `scripts/update-equibop.sh [version]` pins a new release (version + checksum, all distro recipes). It refuses to re-pin a version whose hash changed unless `EQUIBOP_FORCE=1`.
- `scripts/publish-forgejo.sh` re-verifies the file before upload; the `update-equibop` workflow publishes new releases automatically.
- Its own runtime dependencies (GTK, NSS, ...) come from Debian; the library renames in Trixie (`t64`) are satisfied through `Provides:`. `scripts/check-deps.sh` simulates the install to prove it.

Devuan users must keep Devuan's own APT repositories configured; do not add Debian repositories to Devuan.

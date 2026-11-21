# Hosted Debian-family packages

| Package | Source | Build behavior |
|---|---|---|
| `wm-desktop` | `https://github.com/Reedman27/wm-desktop` using this directory's `debian/` metadata | Built by default; required by `reedmuhn-wmaker` |
| `minecraft-launcher` | Mojang's official `.deb`, fetched at build time | Optional: `BUILD_MINECRAFT=1` |
| `equibop` | Equibop upstream amd64 `.deb` | Optional: `BUILD_EQUIBOP=1`; independently verify its checksum before publishing |

Cider is not mirrored here. `BUILD_CIDER_REPO=1` creates the package that configures Cider's upstream APT source, after its signing key has been fetched and verified. This integration is opt-in because the upstream package index has been unreliable.

All metapackage dependencies are resolved from the target system's own repositories. On Devuan, keep Devuan's own APT sources configured; do not add Debian repositories. Build artifacts are written to `out/` and are git-ignored.

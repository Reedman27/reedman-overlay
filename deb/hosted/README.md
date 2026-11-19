# Hosted Debian-family packages

| Package | Source | Build behavior |
|---|---|---|
| `wm-desktop` | `github.com/Reedman27/wm-desktop` with this directory's `debian/` | Built by default; required by `reedmuhn-wmaker` |
| `wmvol`, `wmmedia` | `github.com/Reedman27/dockapps-collection` | Built by default; required by `reedmuhn-wmaker` |
| `equibop` | Equibop upstream amd64 `.deb`, mirrored unmodified | **Built by default**; required by `reedmuhn-desktop`; `BUILD_EQUIBOP=0` opts out (then `reedmuhn-desktop` is skipped) |
| `minecraft-launcher` | Mojang's official `.deb` | Optional: `BUILD_MINECRAFT=1` |

`deb/package-sources.conf` records which packages are provided here; `scripts/publish-forgejo.sh` refuses to upload a metapackage set that lacks any of them. Equibop is only mirrored after `verify_equibop` (scripts/deb-common.sh) confirms its pinned SHA-256 (`EQUIBOP_SHA256`) and its control data.

Cider is not mirrored. `BUILD_CIDER_REPO=1` builds the package that configures Cider's upstream APT source after its key has been verified.

Other dependencies are resolved from the target system's repositories (`winetricks` and `steam-installer` need Debian `contrib`; see `docs/debian-devuan.md`). On Devuan keep Devuan's own sources. Output goes to `out/` (git-ignored).

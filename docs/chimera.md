# Chimera Linux packaging

The Chimera port is native cports templates under `chimera/user/`, not an Alpine APKBUILD overlay.
See [`chimera/README.md`](../chimera/README.md) and the generated [`chimera/INDEX.md`](../chimera/INDEX.md).

## What is ported

| Template | What it is |
| --- | --- |
| `windowmaker` (+ `windowmaker-devel`) | Window Maker 0.96.0 from the release tarball, clang/musl, pinned checksum |
| `wm-desktop` | notification daemon, file browser, menus (pinned commit of Reedman27/wm-desktop) |
| `wmvol`, `wmmedia` | dockapps from Reedman27/dockapps-collection (pinned commit) |
| `sxhkd` | hotkey daemon 0.6.2 |
| `rustcord` | the Qt WebEngine frontend of Rustcord (pinned commit); needs `qt6-qtwebengine` |
| `reedmuhn-*` | metapackages generated from `meta.json` |
| `cider` | marked broken: Cider is a glibc Electron binary |

Equibop and the Minecraft launcher are glibc/Java-launcher binaries and are not offered on Chimera.

## Usable desktop

`chimera/desktop-setup.sh` prepares everything around Window Maker: the X input driver (`xserver-xorg-minimal` alone has none), mesa, elogind/turnstile, PipeWire, fonts, a terminal (Chimera has no xterm), `~/.xinitrc` and a root menu. Run it after `chimera/setup.sh`, log in again, then `startx`.

## Build

On Chimera, as a normal user (not root, not in a chroot):

```sh
apk add base-cbuild-host git
chimera/setup.sh                 # windowmaker, wm-desktop, wmvol, wmmedia, sxhkd, reedmuhn-base, reedmuhn-wmaker
chimera/setup.sh --with-rustcord # add rustcord (pulls in Qt WebEngine; slow)
```

The script fills missing source checksums (`scripts/pin-chimera.sh`, the only step that needs GitHub),
copies the templates into a cports checkout (`CPORTS`, default `~/cports`), creates a signing key and
build root on first use, runs `cbuild lint`, `relink-subpkgs` and `cbuild pkg`, then prints the `apk` command.
`./bootstrap.sh base wmaker rustcord` runs the same thing.

## Checksums

The windowmaker and sxhkd archives are release tarballs; wm-desktop, wmvol, wmmedia and rustcord are
pinned commits whose `sha256` starts as a zero placeholder. `scripts/pin-chimera.sh` replaces those, and
`scripts/pin-chimera.sh --check` verifies all of them. `scripts/update-pins.sh` moves a pin to a newer
commit. rustcord must be public (or archive access given a token) for the download to work.

## What is verified

All templates pass `ruff` and `cbuild lint` against current cports, and the C programs compile with clang.
The CI workflow `.github/workflows/chimera.yml` runs a real `cbuild pkg` on every push; a real Chimera host
has not been used by the author of this overlay, so treat the first build as the actual test.

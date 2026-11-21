# ReedMuhn Overlay

Package recipes for a Window Maker desktop, Rustcord, Equibop, Cider and the Minecraft launcher, on
Chimera, Arch, Debian/Devuan/Ubuntu, Fedora/openSUSE, Void, Gentoo and Alpine.

## Install in one line

```sh
curl -fsSL https://raw.githubusercontent.com/Reedman27/reedman-overlay/main/install.sh | sh -s -- rustcord
```

Swap `rustcord` for whatever you want. It detects your distro, builds what is needed and installs it:

| Pick | You get |
| --- | --- |
| `rustcord` | Rustcord, the native Discord client |
| `base` | zsh, tmux, git, btop, fastfetch and friends |
| `wmaker` | a ready Window Maker desktop (on Chimera it also sets up Xorg, sound and `~/.xinitrc`) |
| `desktop` `gaming` `networking` `development` | more app bundles |
| `equibop` `cider` `minecraft` | single apps |

Combine them: `... | sh -s -- base wmaker rustcord`. Add `--dry-run` to see the steps without changing anything,
and run with no picks for help. Already cloned? Use `./bootstrap.sh rustcord`. To update later, run the same
line again.

Needs only `git` (plus `base-devel` on Arch, `base-cbuild-host` on Chimera). On Gentoo it prints the `emerge` line:
`eselect repository add reedman git https://github.com/Reedman27/reedman-overlay.git`, then `emerge -aq net-im/rustcord`.

## What is where

| Distro | Where |
| --- | --- |
| Chimera Linux | `chimera/user/` (cports), [docs](docs/chimera.md) |
| openSUSE Tumbleweed/Leap, Fedora | `opensuse/`, `rpm/`, [docs](docs/opensuse.md) |
| Gentoo | the repository root is the overlay |
| Arch / EndeavourOS | `arch/` |
| Void | `void/` |
| Alpine | `alpine/` (metapackages only) |
| Debian / Devuan / Ubuntu | `deb/`, [docs](docs/debian-devuan.md) (no Rustcord package yet) |

The metapackages for all families are generated from `meta.json` with `python3 scripts/gen.py`.
Rustcord is packaged with its Qt WebEngine frontend (`rustcord-qt`) on Chimera, openSUSE/Fedora, Gentoo and Arch.

## Chimera Linux

Window Maker 0.96.0, wm-desktop, wmvol, wmmedia, sxhkd and Rustcord are source-built cports templates.
See [chimera/README.md](chimera/README.md) and [docs/chimera.md](docs/chimera.md).

## Window Maker on Gentoo

The Gentoo overlay includes `x11-misc/wm-desktop` and dockapp ebuilds. See the package recipes
under `x11-misc/` and `x11-plugins/`.

## Other distributions

The repository contains native packaging under `deb/`, `arch/`, `rpm/`, `opensuse/`, `void/`,
and `alpine/`. Generate the metapackages for all supported families with:

```sh
python3 scripts/gen.py
```

Debian/Devuan package build and dependency checks are documented in
[docs/reedmuhn.md](docs/reedmuhn.md). Everything is built from GitHub sources; nothing is pulled from a
private or self-hosted registry.

## GitHub Actions

- `ReedMuhn CI (Debian + Devuan + metadata)` (`ci.yml`) validates `meta.json`, shell syntax and generated
  files, builds the Debian packages, resolves their dependencies on Debian and Devuan, and uploads the
  `.deb` files as a workflow artifact.
- `Chimera cports (lint + real cbuild)` (`chimera.yml`) checks upstream checksums, runs ruff and
  `cbuild lint`, and builds the Chimera templates with cbuild.
- `Weekly Rustcord pin update` (`update-rustcord.yml`) follows `main` of `Reedman27/rustcord`: when there is a new
  commit it bumps `RUSTCORD_REF` and the Chimera cport (commit, version, SHA-256) and opens a pull request.
  Run `Chimera cports` manually on that branch with *with_rustcord* ticked to test-build it.
- `Weekly Equibop update check` (`update-equibop.yml`) opens a pull request when upstream releases a new
  Equibop version. Enable *Settings > Actions > General > Allow GitHub Actions to create and approve
  pull requests* for it to work.

The workflows use GitHub's standard `GITHUB_TOKEN` and the free standard runners (`ubuntu-latest` / `ubuntu-24.04`);
no larger runners, self-hosted runners, paid features or secrets are needed. Everything has path filters,
concurrency cancelling and short artifact retention to keep minutes low. Pull requests opened by the update
workflows do not trigger other workflows (a GitHub rule for `GITHUB_TOKEN`); start them by hand with *Run workflow*.

# ReedMuhn Linux packages

A multi-distribution packaging repository for the ReedMuhn desktop setup. It has two jobs:

1. **Metapackages** that install a selected group of native distro packages.
2. **Hosted standalone applications** that ReedMuhn packages itself when an upstream package is not available in the right format.

The metapackages are generated from `meta.json`. Edit the logical package list and distro mappings there, then run `python3 scripts/gen.py`.

## Supported distributions

**Current release focus: Debian 13 (Trixie) and Devuan 6 (Excalibur).** The CI workflow checks package structure and APT dependency resolution against both. Other distro directories are experimental packaging work and are not currently claimed as supported.

On a real Debian or Devuan machine, run `scripts/check-deps.sh` (after `apt-get update`) to confirm every dependency exists on that release.

| Distribution | Status |
|---|---|
| Debian 13 (Trixie) | Primary target; package build and dependency-resolution CI |
| Devuan 6 (Excalibur) | Primary target; package build and dependency-resolution CI using Devuan's own repositories |
| Ubuntu, Linux Mint, antiX, MX Linux | Debian-format compatibility intended, not currently release-tested |
| Arch, Fedora, openSUSE, Gentoo, Void, Alpine, Chimera | Experimental recipes; not release-tested |

Kali, Garuda, Manjaro, Slackware, and NixOS are not targets. Devuan users must keep Devuan's own APT sources configured; do not add Debian repositories to Devuan. The repository publishes separate APT suites (`trixie` and `excalibur`) so clients can use their own release codename.

## Metapackages

Install only the groups you want; none of the groups pulls in another ReedMuhn meta.

| Package | Contents |
|---|---|
| `reedmuhn-base` | Zsh, Fastfetch, tmux, doas, btop, Git |
| `reedmuhn-desktop` | Thunar, File Roller, Alacritty, VLC, PipeWire, WirePlumber, pavucontrol, playerctl, Equibop |
| `reedmuhn-wmaker` | Window Maker, wm-desktop, picom, sxhkd, wmclock, wmmon, wmvol, wmmedia, wmsystemtray, Xorg |
| `reedmuhn-gaming` | Wine, Winetricks and Steam (Debian: `steam-installer`) |
| `reedmuhn-networking` | NetworkManager, Samba, Podman, chrony (Tailscale installed separately) |
| `reedmuhn-development` | Neovim, OpenJDK, ImageMagick, compiler/build tools |
| `reedmuhn-cider` | Cider client (native Cider repo where configured; repackaged binary on Gentoo, Void and openSUSE) |

Firefox and Bash are not explicit ReedMuhn dependencies. A package manager may still install Bash or another shell as a transitive dependency of a distro package; this repository does not remove system packages.

## Hosted standalone applications

These are separate packages, not dependencies of any metapackage:

- **`wm-desktop`** — built from [Reedman27/wm-desktop](https://github.com/Reedman27/wm-desktop).
- **`minecraft-launcher-bin`** — standalone package repackaged from Mojang's official Debian binary package.
- **`cider-bin`** — repackaged from Cider's upstream Debian binary package where no suitable native Cider repository is used.
- **`equibop-bin`** — unofficial native-package repackaging of Equibop's upstream amd64 `.deb` for Arch, RPM, Gentoo and Void. Debian-family systems use the upstream `.deb` artifact in our hosted APT pool.

Equibop is a third-party package. Equibop's own project says its community packages are unofficial and recommends the AppImage for broad distro coverage. The `.deb` repackages here are **x86_64/amd64 glibc packages**; they are not an Alpine/Chimera musl build. See [Equibop upstream](https://github.com/Equicord/Equibop).

The Equibop version is recorded in `EQUIBOP_VERSION`. To update it and fill in the downloaded artifact's SHA-256 in the native recipes:

```sh
scripts/update-equibop.sh 3.3.4
```

That script computes a hash from the downloaded release file; before publishing, compare it with a checksum/digest independently published by upstream if one is available. Gentoo's Manifest must also be generated with `ebuild ... manifest` on a Gentoo system.

## Build packages

Install the relevant distro build tools first. All generated binaries go to `out/` except Void, whose `xbps-src` output stays in the Void checkout's `hostdir/binpkgs`.

### Debian 13 / Devuan 6

```sh
sudo apt install build-essential dpkg-dev debhelper git pkgconf python3 curl libx11-dev libxext-dev libxft-dev \
  libfontconfig-dev libdbus-1-dev libwraster-dev
scripts/build-deb.sh
```

The default build compiles `wm-desktop`, `wmvol` and `wmmedia` (pinned via `WM_DESKTOP_REF` / `DOCKAPPS_REF`; see `scripts/update-pins.sh`), mirrors Equibop after verifying its pinned SHA-256, and builds the core metapackages, so nothing a metapackage depends on is silently left out. `winetricks` and `steam-installer` come from Debian `contrib` (run `scripts/enable-steam-prereqs.sh`). Optional extras are opt-in:

```sh
MC_SHA256=<verified-sha256> BUILD_MINECRAFT=1 scripts/build-deb.sh
```

Minecraft is an upstream binary mirror; do not publish it until its SHA-256 has been independently checked (`MC_SHA256`). Cider is opt-in because its upstream APT index has been unreliable; fetch and verify the upstream key before `BUILD_CIDER_REPO=1 scripts/build-deb.sh`. The opt-outs `BUILD_EQUIBOP=0`, `SKIP_WM_DESKTOP=1` and `SKIP_DOCKAPPS=1` exist for partial builds: a metapackage that needs an opted-out package is skipped rather than built uninstallable. See [debian-devuan.md](debian-devuan.md).

`reedmuhn-desktop` depends on `equibop` and `reedmuhn-gaming` depends on `steam-installer`, so one `apt install` fetches both:

1. Publish (on your build machine): `scripts/build-deb.sh`, `scripts/check-deps.sh`, then `FORGEJO_USER=Reedman27 FORGEJO_TOKEN=... scripts/publish-forgejo.sh` (`--dry-run` first). The token needs the `write:package` scope. Forgejo signs the repository itself.
2. On each Debian/Devuan machine, once (it must be able to reach your Forgejo host): `sudo scripts/setup-apt-repo.sh`
3. For Steam, once: `sudo scripts/enable-steam-prereqs.sh` (adds contrib and the i386 architecture, with backups; `bootstrap.sh gaming` does this for you).
4. `sudo apt install reedmuhn-desktop reedmuhn-gaming`

The repository is Forgejo's Debian package registry: `https://serverhat.tail973a97.ts.net:8443/api/packages/Reedman27/debian`, distribution `reedmuhn`, component `main`. A package version can only be uploaded once, so bump `VERSION` for each republish.

Equibop is amd64 only, so `reedmuhn-desktop` is installable on amd64 only.

## Host your own package repositories

Build packages first, then generate the native package indexes:

```sh
scripts/index-repositories.sh
```

This creates `repo/deb`, `repo/rpm`, `repo/arch`, and `repo/void`. Publish that directory tree with GitHub Pages or another static host. Configure signing before publishing: APT needs signed Release metadata, RPM packages should be signed, and Arch/Void repositories should use their package/index signing mechanisms. See [docs/hosting.md](docs/hosting.md).

The Gentoo overlay is hosted as a Git repository rather than a binary package index.

## Install helper

`bootstrap.sh` detects Debian-family, Fedora, openSUSE, Arch, Gentoo and Void systems. Example:

```sh
./bootstrap.sh base wmaker equibop minecraft
```

For Gentoo and Void it prints the corresponding native build/install steps rather than pretending that a binary package already exists locally. On Alpine/Chimera it deliberately does not try to install Equibop's glibc binary.

## Repository layout

- `meta.json` — source of truth for metapackage membership and package-name mappings.
- `scripts/gen.py` — generates DEB controls, RPM specs, PKGBUILDs, Gentoo ebuilds, APKBUILDs and Void templates.
- `deb/`, `rpm/`, `opensuse/`, `arch/`, `void/`, `alpine/`, `chimera/` — native packaging definitions. The Gentoo overlay lives at the repository root (`app-metapackages/`, `net-im/`, `x11-misc/`, `x11-plugins/`, ...).
- `out/` — generated build artifacts (ignored by Git; never commit binaries).
- `MAPPING-GAPS.md` — generated list of packages not mapped for every distro family.

## Verification status

The supported release target is intentionally limited to Debian Trixie and Devuan Excalibur. The workflow builds and inspects generated DEB metapackages, then asks each target's own APT resolver to resolve the core package dependencies. `wm-desktop` is built separately from its source repository; the `reedmuhn-wmaker` metapackage depends on that standalone package. Cider and the downloaded standalone binaries remain opt-in. No other distribution should be described as tested until it has its own native build and install test.

The maintainer email in `meta.json` is a reserved `.invalid` placeholder. Replace it with a real project contact before publishing packages. Sign the APT Release metadata before publishing the repository.

## Package versions

Metapackage dependencies are deliberately unversioned, so `apt` installs the newest version in your configured Debian or Devuan repositories (stable plus its updates; testing and unstable are never enabled by this project). To refresh Equibop to the newest upstream release, run `scripts/update-equibop.sh` with no argument, then `BUILD_EQUIBOP=1 scripts/build-deb.sh`.

# Debian and Devuan release notes

## GitHub Actions usage

The repository uses one combined `ci.yml` workflow for metadata, Chimera template checks,
the Debian package build, and Devuan dependency resolution. It builds the package set once
on Debian and tests those same artifacts on Devuan; it does not build the full package set
twice. The Equibop updater runs weekly (rather than every four hours) and can also be started
manually. Debian package artifacts are retained for 7 days.

The combined CI workflow runs as one GitHub-hosted job. Actual monthly Actions usage still
depends on build duration and how often matching branches/PRs are updated; GitHub's included
minutes and storage quotas depend on the account plan.


## Quick start (users)

```sh
./bootstrap.sh base wmaker gaming     # pick any of: base desktop wmaker gaming networking development
```

That is the whole thing: it adds the ReedMuhn repository once, prepares Steam's requirements only if you chose `gaming`, and runs one `apt install`. Everything below is for maintainers and troubleshooting; you never need to run those scripts by hand.


Supported targets: Debian 13 (Trixie) and Devuan 6 (Excalibur). Packages are `amd64` or architecture-independent only.

## Where every dependency comes from

`deb/package-sources.conf` is the single list the tooling uses (generator, build, dependency check).

| Package | Source | Notes |
|---|---|---|
| everything else (`zsh`, `wmaker`, `wine`, `sxhkd`, `wmsystemtray`, ...) | Debian `main` | `wmsystemtray` has a Trixie candidate, so it stays a plain Debian dependency |
| `winetricks` | Debian **contrib** | not installable until `contrib` is enabled |
| `steam-installer` | Debian **contrib** | depends on `steam-libs-i386`, so dpkg also needs the **i386** architecture |
| `wm-desktop`, `wmvol`, `wmmedia` | built here from source (`deb/hosted/`) | built by `scripts/build-deb.sh` |
| `equibop` | upstream amd64 `.deb`, mirrored after a SHA-256 check | built by `scripts/build-deb.sh` |

All of these are hard `Depends:`. Each is part of the advertised selection of its metapackage, and a hard dependency fails loudly (`apt` names the missing package) where a `Recommends:` would let APT skip Steam or Equibop without a word. Only Cider stays a `Recommends:`. `non-free` is not needed by Steam or Wine (it is for proprietary drivers such as NVIDIA); `non-free-firmware` is never touched.

`libsystemd-dev` came in as a dependency of `libdbus-1-dev`. It is a build-time package only: none of the built packages depends on systemd at run time (`wm-desktop` needs `libdbus-1-3`).

## Build

```sh
sudo apt install build-essential dpkg-dev debhelper git pkgconf python3 curl gpg \
  libx11-dev libxext-dev libxft-dev libfontconfig-dev libdbus-1-dev libwraster-dev
scripts/build-deb.sh          # metapackages + wm-desktop + wmvol + wmmedia + equibop (verified)
scripts/test-deb.sh           # offline tests, no root or network needed
scripts/check-deps.sh         # on the target machine, after apt-get update
```

The default build produces every package a metapackage needs. Explicit opt-outs: `BUILD_EQUIBOP=0`, `SKIP_WM_DESKTOP=1`, `SKIP_DOCKAPPS=1`. A metapackage that depends on an opted-out package is *not built* and the build says `SKIPPED`, so `out/` never holds an uninstallable metapackage. Opt-in extras: `BUILD_MINECRAFT=1`, `BUILD_CIDER_REPO=1`.

Equibop is downloaded outside `out/`, checked against `EQUIBOP_SHA256` and its control data (name `equibop`, `amd64`, matching version) by `verify_equibop` (in `scripts/deb-common.sh`), and only then copied in. `scripts/update-equibop.sh` pins a new release and refuses to re-pin a version whose hash changed.

## Steam and Winetricks

```sh
sudo scripts/enable-steam-prereqs.sh --dry-run   # show the exact edits
sudo scripts/enable-steam-prereqs.sh             # add contrib, enable i386, apt-get update, verify
```

It extends only the entries APT reports as the Debian/Devuan archive (any file, one-line or deb822), appends components, backs changed files up to `/var/backups/reedmuhn-apt/<timestamp>/` and is idempotent. `--non-free` additionally adds `non-free`. It then checks that `winetricks` and `steam-installer` have candidates.

## Installing

```sh
scripts/build-deb.sh                     # builds everything into out/ from GitHub sources
./bootstrap.sh --local base desktop wmaker   # or: sudo apt install ./out/reedmuhn-*_all.deb ./out/equibop_*_amd64.deb
```

The `.deb` files are also uploaded as a workflow artifact by the GitHub Actions CI. Run `scripts/enable-steam-prereqs.sh` before installing `reedmuhn-gaming`.

**Devuan must use Devuan's own system repositories.** Do not add Debian's `deb.debian.org` sources to Devuan.

## Current limitations

- There is no hosted APT repository: build locally or use the GitHub Actions artifact (see `docs/hosting.md` for static hosting on GitHub Pages).
- `reedmuhn-cider` needs the optional Cider repository package and is not part of the default build.
- Tailscale and Firefox-family browsers are not part of the metapackages (no suitable Debian package).
- Hosted source packages track upstream HEAD until `WM_DESKTOP_REF` / `DOCKAPPS_REF` are pinned (`scripts/update-pins.sh`).

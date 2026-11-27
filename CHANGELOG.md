# Changelog

## Unreleased
- wm-desktop: pinned to `6f318f0` (wmnotify shows a notification that an app sends twice only once).
- wm-desktop: pinned to `91859fd`, which adds `wmmediakeys` (volume, media, brightness and launcher keys with a themed on-screen display). Every recipe now builds it with `WITH_MEDIAKEYS=yes WITH_XINERAMA=yes` and adds libXinerama; Gentoo gets `+mediakeys` and `+xinerama` USE flags with `optfeature` hints, Arch `optdepends`, Fedora/openSUSE/Debian `Recommends: playerctl brightnessctl xdg-utils` (and `Suggests: mpc`). The runtime helpers stay optional everywhere. Chimera checksum re-pinned.
- Easier to use: one-line `install.sh` (clones or updates the repo and runs `bootstrap.sh`), real `bootstrap.sh --help`, Arch builds only the packages you picked (`arch/build.sh <dirs>`) and installs the build tools for Rustcord, and a clear message instead of an empty `apt-get install` when Rustcord is requested on Debian/Devuan.
- Rustcord: new `RUSTCORD_REF` pin and `scripts/update-pins.sh rustcord`; the weekly `update-rustcord.yml` workflow opens a PR when `Reedman27/rustcord` has new commits (free standard runners only). `chimera.yml` builds the rustcord cport on demand or when its template changes. The Chimera, Arch and openSUSE recipes no longer install a `COPYING` file, which upstream `main` does not ship (only `COPYING.LESSER`), so cbuild would have failed.
- GitHub-only: removed the Forgejo/Tailscale publishing and APT-repo helpers (`publish-forgejo.sh`, `setup-apt-repo.sh`) and their tests. `bootstrap.sh` on Debian/Devuan now builds the `.deb` files from GitHub sources (or uses `--local`) like the other families.
- Chimera: new `chimera/desktop-setup.sh` makes a fresh install boot into Window Maker (adds the missing X input driver, services, sound, fonts, terminal, `~/.xinitrc`, menu); the Chimera Xorg mapping now includes `xserver-xorg-input-libinput` and `mesa-dri`.
- Chimera: full Window Maker stack as cports templates (`windowmaker` rewritten with a `-devel` subpackage, `wm-desktop`, `wmvol`, `wmmedia`, `sxhkd`, `rustcord`), all passing ruff and `cbuild lint`; `chimera/setup.sh` builds them, `scripts/pin-chimera.sh` fills and verifies checksums, `scripts/test-chimera.sh` and `.github/workflows/chimera.yml` check them. Metapackages no longer use the unsupported `maintainer` field.
- openSUSE/Fedora: new tested specs for `cider-bin` (repackages upstream's RPM with openSUSE dependency names), `minecraft-launcher-bin`, `equibop-bin`, `wm-desktop`, `wmvol`, `wmmedia`, `rustcord`; new `opensuse/build.sh` (checksum pinning, git sources, dependency install). `update-equibop.sh` no longer overwrites the openSUSE spec with the Fedora one.
- Rustcord: packages for Chimera, openSUSE, Gentoo (`net-im/rustcord-9999`) and Arch (`rustcord-git`) based on the Qt WebEngine frontend.
- Arch: `wmvol-git` and `wmmedia-git`. Gentoo docs use `emerge -aq`.
- `bootstrap.sh`: real Chimera and openSUSE paths (build, then install), Alpine separated from Chimera, `rustcord` selection.
- Chimera: added a source-built `windowmaker` cports template for upstream 0.96.0, verified the source checksum against independent distribution metadata, mapped Window Maker and the minimal Xorg stack into `reedmuhn-wmaker`, and documented the cbuild workflow. Dockapps and `wm-desktop` remain explicitly unfinished for Chimera.
- Chimera: corrected generated metapackages to use cports' documented `build_style = "meta"` instead of the unsupported `metapackage = True` field; unfinished Cider and wm-desktop recipes are marked broken rather than appearing buildable.
- CI: migrated active workflows from `.forgejo/workflows/` to `.github/workflows/`. GitHub Actions now validates the repository, tests Debian/Devuan packaging, uploads built `.deb` files as workflow artifacts, and opens a PR for Equibop pin updates.
- GitHub portability: added GitHub Actions workflows and documented which package-hosting steps still require an external APT repository; marked shell scripts executable and ignored Python cache files.
- Debian: the default `scripts/build-deb.sh` now builds everything a metapackage depends on, Equibop included (`BUILD_EQUIBOP=0` opts out); a metapackage whose repo-provided dependency is opted out is skipped loudly instead of being built uninstallable.
- Debian: Equibop is downloaded outside `out/` and copied in only after SHA-256 and control-data verification (`verify_equibop` in `scripts/deb-common.sh`); a mismatch no longer leaves the file in `out/`. `update-equibop.sh` also refuses to re-pin a changed release.
- Debian: new `deb/package-sources.conf` (single list of repo-built, upstream-mirrored and `contrib` packages) read by `gen.py`, build, check and publish. Metapackage descriptions now say where non-default dependencies come from. Dependencies themselves are unchanged (all hard `Depends`).
- `scripts/enable-steam-prereqs.sh` rewritten: edits only entries APT reports as the Debian/Devuan archive (it used to append components to every `.sources` file and every `main` line, third-party repositories included), handles one-line and deb822 formats in any file, backs up, shows a diff, `--dry-run`, verifies candidates. `contrib` + i386 by default; `non-free` only with `--non-free`.
- `scripts/check-deps.sh` rewritten: classifies every dependency (Debian main/contrib, ReedMuhn repo, local `out/`, virtual), handles alternatives and `Provides`, checks standalone package dependencies, and finishes with `apt-get -s install` of everything in `out/`. Nothing is skipped.
- - `scripts/test-deb.sh` now tests the build opt-outs, Equibop verification and the Steam helper offline.
- `scripts/update-equibop.sh` skips the download when already current, can copy the `.deb` to `EQUIBOP_ARTIFACT_DIR`, honours `EQUIBOP_SKIP_GENTOO=1`, and no longer writes broken quoting into the generated Gentoo ebuild.
- Docs: metapackage table now lists Equibop and Steam; Debian/Devuan build-dependency lists include `python3`, `curl` and `libxext-dev`.

## 1.0.4
- Debian/Devuan: `wmvol` and `wmmedia` now have native packages built from `dockapps-collection` (`deb/hosted/`), so `reedmuhn-wmaker` includes them. Gentoo mappings added for the existing ebuilds.
- Hosted source builds are now pinnable: `WM_DESKTOP_REF` and `DOCKAPPS_REF` (set with `scripts/update-pins.sh`). Package versions are stamped `<base>+git<date>.<sha>-1`, so different upstream code never reuses a version. Unpinned builds still work but warn.
- `bootstrap.sh`, `check-deps.sh` and CI updated for the new packages; docs synchronised (Equibop/Steam are metapackage dependencies, audit document brought up to 1.0.4).

## 1.0.3
- `reedmuhn-desktop` now depends on `equibop` (served from the ReedMuhn APT repository; `bootstrap.sh` uses the local build when present).
- `reedmuhn-gaming` now depends on `steam-installer` from the official Debian/Devuan repositories (also `steam` on Arch, `games-util/steam-launcher` on Gentoo).
- New `scripts/enable-steam-prereqs.sh` (i386 + contrib/non-free) and `scripts/setup-apt-repo.sh` (adds the ReedMuhn repo and key).
- CI builds Equibop and resolves both new dependencies on Debian 13 and Devuan 6.

## 1.0.2
- Focus: Debian and Devuan are the supported, tested-first targets. Other families are experimental and untested.
- Equibop 3.3.4 SHA-256 is now pinned (`EQUIBOP_SHA256`); `build-deb.sh` refuses to build Equibop without a pin.
- Added `scripts/check-deps.sh` to verify every dependency exists on a given Debian/Devuan release.
- `scripts/update-equibop.sh` with no argument pins the newest upstream Equibop release.

## 1.0.1 (2026-11-15)

- Made Debian 13 and Devuan 6 the only primary release targets and added APT dependency-resolution CI for both.
- Corrected Debian's Window Maker package name to `wmaker` and selected `opendoas` instead of the transitional `doas` package.
- Removed Minecraft Launcher from the gaming metapackage; it is now selected as a standalone application.
- Removed unmapped browser packages from the desktop metapackage and documented unavailable Tailscale integration.
- Made Cider and downloaded standalone binary builds opt-in, and added separate `trixie` / `excalibur` APT repository suites.
- Added a local DEB build/metadata test and clarified the Devuan repository rules.

## 1.0.0 (2026-11-15)

- Added dedicated package mappings and native RPM specs for openSUSE Tumbleweed.
- Added XBPS metapackage templates and build workflow for Void Linux.
- Added Devuan detection to the Debian-family installer path without adding Debian repositories.
- Added Equibop 3.3.4 as a separately packaged amd64 application for Debian-family, RPM, Arch, Gentoo and Void systems.
- Added Void packaging templates for wm-desktop, Cider and Minecraft Launcher.
- Added static repository metadata generation for APT, RPM, pacman and XBPS repositories.
- Added an Equibop version/checksum refresh helper.
- Documented glibc/musl limitations and marked package mappings/builds that still require native validation.

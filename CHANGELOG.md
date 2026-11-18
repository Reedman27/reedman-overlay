# Changelog

## Unreleased
- New Forgejo workflow `update-equibop.yml` (every 4 hours and on demand): checks for a newer Equibop release, publishes the amd64 `.deb` to the registry, and commits the new pin. Needs the `FORGEJO_TOKEN` repository secret (`write:package`).
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

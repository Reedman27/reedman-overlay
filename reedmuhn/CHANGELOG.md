# Changelog

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

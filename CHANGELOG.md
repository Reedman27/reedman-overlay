# Changelog

## Unreleased
- Debian: the default `scripts/build-deb.sh` now builds everything a metapackage depends on, Equibop included (`BUILD_EQUIBOP=0` opts out); a metapackage whose repo-provided dependency is opted out is skipped loudly instead of being built uninstallable.
- Debian: Equibop is downloaded outside `out/` and copied in only after SHA-256 and control-data verification (`verify_equibop` in `scripts/deb-common.sh`); a mismatch no longer leaves the file in `out/`. `update-equibop.sh` also refuses to re-pin a changed release.
- Debian: new `deb/package-sources.conf` (single list of repo-built, upstream-mirrored and `contrib` packages) read by `gen.py`, build, check and publish. Metapackage descriptions now say where non-default dependencies come from. Dependencies themselves are unchanged (all hard `Depends`).
- `scripts/enable-steam-prereqs.sh` rewritten: edits only entries APT reports as the Debian/Devuan archive (it used to append components to every `.sources` file and every `main` line, third-party repositories included), handles one-line and deb822 formats in any file, backs up, shows a diff, `--dry-run`, verifies candidates. `contrib` + i386 by default; `non-free` only with `--non-free`.
- `scripts/check-deps.sh` rewritten: classifies every dependency (Debian main/contrib, ReedMuhn repo, local `out/`, virtual), handles alternatives and `Provides`, checks standalone package dependencies, and finishes with `apt-get -s install` of everything in `out/`. Nothing is skipped.
- `scripts/setup-apt-repo.sh`: validates the key, optional `REEDMUHN_KEY_FPR` pin, post-update check that packages are visible. `scripts/publish-forgejo.sh`: credential help, `--dry-run`, preflight (arch, Equibop pin, metapackage completeness), token kept off the command line, index verification afterwards.
- CI: validation uses the real `enable-steam-prereqs.sh` and `check-deps.sh`, lints the Debian scripts; new automatic `publish-deb.yml` (push, weekly, manual).
- `scripts/test-deb.sh` now tests the build opt-outs, Equibop verification, the Steam helper and publishing (mock Forgejo) offline.
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

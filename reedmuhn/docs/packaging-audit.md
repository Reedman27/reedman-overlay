# Packaging audit: Debian and Devuan first

Audit date: 2026-11-15  
Repository version: 1.0.1

## Changes made

- Corrected the Debian Window Maker dependency from the nonexistent `windowmaker` package name to `wmaker`.
- Corrected Debian's doas dependency to `opendoas` (the `doas` package is transitional in Debian 13).
- Removed Minecraft Launcher from `reedmuhn-gaming`; it is now an explicitly selected standalone package.
- Removed browser entries with no Debian/Devuan package mapping from the desktop metapackage.
- Kept Tailscale out of the Debian/Devuan networking dependency list because it is not in the default APT archive.
- Made Cider integration optional rather than requiring an upstream signing key and repository package for every build.
- Added separate APT suites for Debian Trixie and Devuan Excalibur. Devuan's documentation recommends release codenames and warns against using Debian/Ubuntu repositories directly.
- Added a local DEB structural test and a CI matrix intended to build the standalone `wm-desktop` package and resolve all core metapackages inside Debian and Devuan containers.
- Bumped package metadata to 1.0.1 so existing 1.0.0 metapackages can be upgraded.

## Tests completed in this workspace

- JSON metadata parses.
- Bash syntax checks pass for the installer and packaging scripts.
- `scripts/test-deb.sh` builds and inspects all six core DEB metapackages.
- Generator output is deterministic across repeated runs.
- `bootstrap.sh --dry-run` correctly selects the base and gaming metapackages plus Minecraft as a standalone application.
- Repository-index generation was exercised with a mocked `apt-ftparchive`; both `trixie` and `excalibur` directory trees were created.

## Tests still requiring GitHub Actions / target systems

- The full `wm-desktop` source build.
- APT dependency resolution against live Debian Trixie repositories.
- APT dependency resolution against live Devuan Excalibur repositories.
- Installation and runtime behavior on actual Debian and Devuan machines.

The workflow is configured to run those APT tests, but a workflow run has not yet occurred from this archive. Do not call the packages fully release-verified until both matrix jobs pass.

## Release blockers

- Replace `packages@reedmuhn.invalid` in `meta.json` and the standalone `wm-desktop` Debian metadata with a real maintainer contact.
- Generate and publish a real APT signing key, then run `scripts/index-repositories.sh` with `GPG_KEY_ID` set. Unsigned repository metadata must not be published as trusted.
- Equibop and Minecraft downloads are opt-in; independently verify upstream checksums before publishing those binary artifacts.

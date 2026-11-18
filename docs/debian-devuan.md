# Debian and Devuan release notes

The first supported targets are Debian 13 (Trixie) and Devuan 6 (Excalibur). The current hosted APT index is for `amd64`; other architectures are not release-tested.

## Build

Build on either target using its own package repositories:

```sh
sudo apt install build-essential dpkg-dev debhelper git pkgconf python3 curl libx11-dev libxext-dev libxft-dev \
  libfontconfig-dev libdbus-1-dev libwraster-dev
scripts/build-deb.sh
scripts/test-deb.sh
```

Enable the `contrib` component in APT sources to make `winetricks` available. The default build creates the core metapackages and builds the standalone `wm-desktop` application. Minecraft Launcher is a separate optional build. Equibop is a dependency of `reedmuhn-desktop` (build it with `BUILD_EQUIBOP=1` and serve it from the ReedMuhn APT repository), and Steam comes from the official repositories via `reedmuhn-gaming`. `wmvol` and `wmmedia` are built alongside `wm-desktop`. Cider is kept opt-in because its upstream APT package index has not been dependable.

## APT repository suites

After publishing `repo/deb` and its signed `InRelease` metadata, configure the matching suite.

Debian 13:

```text
deb [arch=amd64 signed-by=/usr/share/keyrings/reedmuhn-archive-keyring.gpg] https://YOUR-HOST/deb trixie main
```

Devuan 6:

```text
deb [arch=amd64 signed-by=/usr/share/keyrings/reedmuhn-archive-keyring.gpg] https://YOUR-HOST/deb excalibur main
```

Replace `YOUR-HOST` with the actual static host. Install the public signing key at the referenced keyring path before running `apt update`.

**Devuan must use Devuan's own system repositories.** Do not add Debian's `deb.debian.org` sources to Devuan. The ReedMuhn repository has a separate `excalibur` suite for Devuan clients.

## Current limitations

- `reedmuhn-wmaker` requires the separately built `wm-desktop` package.
- `reedmuhn-cider` requires the optional Cider repository package and is not part of the default build.
- Tailscale is not included as a Debian/Devuan dependency because it is not in the default APT package set; users can install it using Tailscale's official instructions separately.
- Firefox-family browser packages are not part of the desktop metapackage until the repository maintains compatible native packages for both targets.

# Hosting the native package repositories

Build artifacts are deliberately not committed to Git. Build them on their native distro/build environment, then create the package indexes. APT indexing requires `apt-utils` (`apt-ftparchive`):

```sh
scripts/index-repositories.sh
```

The current APT repository index is `amd64` only. The script creates `repo/` with these subrepositories:

- `repo/deb/` — APT pool and `Packages`/`Release` metadata.
- `repo/rpm/` — RPM files plus `repodata/` for Fedora and openSUSE Tumbleweed.
- `repo/arch/` — pacman packages plus `reedmuhn.db`.
- `repo/void/` — XBPS packages plus repository indexes.

For APT, set `DEB_SUITES="trixie excalibur"` (the default) and `GPG_KEY_ID` to the ID of the key whose public key you distribute to users. Use codenames, not the moving `stable` alias. Do not publish an unsigned APT repository as trusted. For RPM, sign packages with your RPM signing key before publishing. For Arch, sign packages and configure `SigLevel` appropriately. For Void, sign the repository index/packages with your XBPS key before asking users to trust it.

## Static hosting

`repo/` is a static directory tree and can be published with GitHub Pages or another static web host. Keep the directory structure unchanged. After publishing, configure each package manager to use the matching subdirectory:

- APT Debian 13: `https://YOUR-ACCOUNT.github.io/YOUR-REPO/deb` with suite `trixie`
- APT Devuan 6: `https://YOUR-ACCOUNT.github.io/YOUR-REPO/deb` with suite `excalibur`
- DNF/zypper: `https://YOUR-ACCOUNT.github.io/YOUR-REPO/rpm/`
- pacman: `https://YOUR-ACCOUNT.github.io/YOUR-REPO/arch/`
- XBPS: `https://YOUR-ACCOUNT.github.io/YOUR-REPO/void/`

The Gentoo overlay is the Git repository itself: users add the Git repository as a Portage overlay or clone it into `/var/db/repos/reedmuhn`. Gentoo does not use the static RPM/DEB package indexes.

Do not put private signing keys in the repository or GitHub Pages. Store signing keys in a local keyring or CI secrets, and publish only public keys.

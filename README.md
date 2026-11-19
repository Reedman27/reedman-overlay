# reedman overlay
Local Gentoo overlay. `media-sound/cider-bin` repackages the Cider .deb (fetch-restricted: the .deb is never stored in git).

Drop the .deb into /var/cache/distfiles, then:
    emerge -av media-sound/cider-bin

## x11-misc/wm-desktop

Live (9999) ebuild for [wm-desktop](https://github.com/Reedman27/wm-desktop): notification daemon,
file browser and menu tools for Window Maker. USE flags: `files notify wraster test`.

    echo "x11-misc/wm-desktop **" > /etc/portage/package.accept_keywords/wm-desktop
    emerge -aq x11-misc/wm-desktop

## games-action/minecraft-launcher-bin
Repackages Mojang's official launcher .deb (downloaded from launcher.mojang.com, never stored in git).
Installs to `/opt/minecraft-launcher` with a `minecraft-launcher` symlink in `/usr/bin`.

    scripts/bump-minecraft.sh --commit      # fetch the newest .deb, make ebuild + Manifest
    echo "games-action/minecraft-launcher-bin ~amd64" >> /etc/portage/package.accept_keywords/minecraft
    emerge -aq games-action/minecraft-launcher-bin

Mojang's URL is unversioned, so when they ship an update emerge fails the checksum until you run
`scripts/bump-minecraft.sh` again and push. The game files are downloaded by the launcher into
`~/.minecraft` on first launch of a version.

## x11-plugins (Window Maker dockapps)

Live (9999) ebuilds for the dockapps in [dockapps-collection](https://github.com/Reedman27/dockapps-collection):
`x11-plugins/wmvol` (PipeWire volume) and `x11-plugins/wmmedia` (MPRIS/MPD media controls).

    echo "x11-plugins/wmvol **"   >> /etc/portage/package.accept_keywords/dockapps
    echo "x11-plugins/wmmedia **" >> /etc/portage/package.accept_keywords/dockapps
    emerge -aq x11-plugins/wmvol x11-plugins/wmmedia

## Debian, Devuan and other distro packaging

The same repository holds the ReedMuhn packaging for other distributions (`deb/`, `arch/`, `rpm/`, `void/`, ...).
Debian and Devuan are the supported targets. To install: `./bootstrap.sh base wmaker gaming` (adds the repo once, then a normal `apt install`). See [docs/reedmuhn.md](docs/reedmuhn.md).
CI runs on Forgejo Actions (`.forgejo/workflows/validate.yml`).

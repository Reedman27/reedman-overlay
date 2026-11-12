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
Repackages Mojang's `Minecraft.deb` (fetch-restricted, the .deb is never stored in git). Installs to `/opt/minecraft-launcher` with a `minecraft-launcher` symlink in `/usr/bin`.

    cp Minecraft.deb /var/cache/distfiles/minecraft-launcher-bin-1.deb
    ebuild /var/db/repos/reedman/games-action/minecraft-launcher-bin/minecraft-launcher-bin-1.ebuild manifest
    echo "games-action/minecraft-launcher-bin ~amd64" >> /etc/portage/package.accept_keywords/minecraft
    emerge -aq games-action/minecraft-launcher-bin

The game files themselves are downloaded by the launcher into `~/.minecraft` on first launch of a version.

## games-action/minecraft-launcher-bin
Repackages Mojang's `Minecraft.deb` (fetch-restricted, the .deb is never stored in git). Installs to `/opt/minecraft-launcher` with a `minecraft-launcher` symlink in `/usr/bin`.

    cp Minecraft.deb /var/cache/distfiles/minecraft-launcher-bin-1.deb
    ebuild /var/db/repos/reedman/games-action/minecraft-launcher-bin/minecraft-launcher-bin-1.ebuild manifest
    echo "games-action/minecraft-launcher-bin ~amd64" >> /etc/portage/package.accept_keywords/minecraft
    emerge -aq games-action/minecraft-launcher-bin

The game files themselves are downloaded by the launcher into `~/.minecraft` on first launch of a version.

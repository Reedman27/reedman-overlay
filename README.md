# reedman overlay
Local Gentoo overlay. `media-sound/cider-bin` repackages the Cider .deb (fetch-restricted: the .deb is never stored in git).

Drop the .deb into /var/cache/distfiles, then:
    emerge -av media-sound/cider-bin

## x11-misc/wm-desktop

Live (9999) ebuild for [wm-desktop](https://github.com/Reedman27/wm-desktop): notification daemon,
file browser and menu tools for Window Maker. USE flags: `files notify wraster test`.

    echo "x11-misc/wm-desktop **" > /etc/portage/package.accept_keywords/wm-desktop
    emerge -aq x11-misc/wm-desktop

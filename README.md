# reedman overlay
Local Gentoo overlay. `media-sound/cider-bin` repackages the Cider .deb (fetch-restricted: the .deb is never stored in git).

Drop the .deb into /var/cache/distfiles, then:
    emerge -av media-sound/cider-bin

# Runtime libraries for prebuilt Chromium-based apps (Electron: Cider; CEF: Rustcord).
# Included by the specs with:  %%include %%{_sourcedir}/chromium-runtime.inc
# Package names differ between openSUSE and Fedora/RHEL, hence the split.
%if 0%{?suse_version}
Requires:       libgtk-3-0
Requires:       mozilla-nss
Requires:       libXss1
Requires:       libnotify4
Requires:       xdg-utils
Requires:       libxcb1
Requires:       libXtst6
Requires:       at-spi2-core
Requires:       libasound2
Requires:       libgbm1
Requires:       libdrm2
Requires:       libxkbcommon0
Requires:       libcups2
Requires:       libXcomposite1
Requires:       libXdamage1
Requires:       libXfixes3
Requires:       libXrandr2
Requires:       libpango-1.0-0
Requires:       libcairo2
%else
Requires:       gtk3
Requires:       nss
Requires:       libXScrnSaver
Requires:       libnotify
Requires:       xdg-utils
Requires:       libxcb
Requires:       libXtst
Requires:       at-spi2-core
Requires:       alsa-lib
Requires:       mesa-libgbm
Requires:       libdrm
Requires:       libxkbcommon
Requires:       cups-libs
Requires:       libXcomposite
Requires:       libXdamage
Requires:       libXfixes
Requires:       libXrandr
Requires:       pango
Requires:       cairo
%endif

# Repackages Mojang's official Minecraft Launcher.
# Mojang only publishes a .deb and a tarball. The .deb is used here purely as an archive
# (ar + tar, no dpkg needed): it is the one that carries the .desktop file and icons.
#
# Mojang's URL is unversioned: it always serves the newest launcher, so build.sh records the
# version it finds and pins the download's sha256 in SHA256SUMS.
#
# Build with:  opensuse/build.sh minecraft-launcher-bin
%{!?mcver:%global mcver 2.1.3}

%global debug_package %{nil}
%global __strip /bin/true
%global __os_install_post %{nil}
AutoReqProv:    no

Name:           minecraft-launcher-bin
Version:        %{mcver}
Release:        0
Summary:        Official Minecraft Launcher (repackaged from Mojang's download)
License:        LicenseRef-Mojang-EULA
URL:            https://www.minecraft.net
Source0:        Minecraft.deb
ExclusiveArch:  x86_64
BuildRequires:  binutils
BuildRequires:  tar
BuildRequires:  xz
BuildRequires:  zstd
%if 0%{?suse_version}
Requires:       libsecret-1-0
Requires:       libbsd0
Requires:       mozilla-nss
Requires:       libasound2
Requires:       libopenal1
Requires:       libcurl4
Requires:       libcups2
Requires:       dbus-1
Requires:       Mesa-libGL1
Requires:       xrandr
Requires:       libgtk-3-0
Requires:       libXss1
Requires:       libXcomposite1
Requires:       libXcursor1
Requires:       libXdamage1
Requires:       libXext6
Requires:       libXfixes3
Requires:       libXi6
Requires:       libXrender1
Requires:       libXtst6
Requires:       libxcb-util1
%else
Requires:       libsecret
Requires:       libbsd
Requires:       nss
Requires:       alsa-lib
Requires:       openal-soft
Requires:       libcurl
Requires:       cups-libs
Requires:       dbus-libs
Requires:       mesa-libGL
Requires:       xrandr
Requires:       gtk3
Requires:       libXScrnSaver
Requires:       libXcomposite
Requires:       libXcursor
Requires:       libXdamage
Requires:       libXext
Requires:       libXfixes
Requires:       libXi
Requires:       libXrender
Requires:       libXtst
Requires:       xcb-util
%endif
Provides:       minecraft-launcher = %{version}

%description
The official Minecraft Launcher from Mojang. The game files themselves are downloaded by the
launcher into ~/.minecraft the first time you start a version. Use is subject to the Minecraft EULA.

%prep
%setup -q -c -T
ar x %{SOURCE0}
tar -xf data.tar.*

%build
# nothing to build

%install
install -D -m 755 usr/bin/minecraft-launcher %{buildroot}%{_bindir}/minecraft-launcher
install -d %{buildroot}%{_datadir}
cp -a usr/share/applications usr/share/icons %{buildroot}%{_datadir}/

%files
%{_bindir}/minecraft-launcher
%{_datadir}/applications/*.desktop
%{_datadir}/icons/hicolor

%changelog
* Thu Nov 19 2026 Reedman27 - 0
- Initial spec

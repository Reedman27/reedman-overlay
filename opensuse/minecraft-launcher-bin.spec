Name:           minecraft-launcher-bin
Version:        %{?mcver}%{!?mcver:0}
Release:        1%{?dist}
Summary:        Official Minecraft Launcher (repackaged from Mojang's .deb)
License:        Mojang-EULA
URL:            https://www.minecraft.net
ExclusiveArch:  x86_64
Source0:        Minecraft.deb
BuildRequires:  binutils, tar
# prebuilt binary; the .deb's own dependencies are mapped by hand (UNVERIFIED Fedora names)
AutoReqProv:    no
Requires:       gtk3, nss, alsa-lib, openal-soft, libcurl, cups-libs, libsecret, libbsd, libXScrnSaver, libXtst, xrandr

%description
Official Minecraft Launcher, unpacked from Mojang's Debian package and managed by rpm.
Mojang's download URL is unversioned: rebuild when Mojang ships an update.

%prep
%build
%install
cd %{_builddir}
ar x %{SOURCE0}
tar -xf data.tar.* -C %{buildroot}

%files
%{_bindir}/minecraft-launcher
%{_datadir}/applications/*
%{_datadir}/icons/*

%changelog
* Sun Nov 15 2026 Reedman27 <packages@reedmuhn.invalid> - %{version}-1
- Repackaged from Mojang's .deb

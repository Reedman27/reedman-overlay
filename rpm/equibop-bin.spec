Name:           equibop-bin
Version:        3.3.4
Release:        1%{?dist}
Summary:        Custom Discord client with Equicord preinstalled
License:        GPL-3.0-only
BuildArch:      x86_64
Source0:        https://github.com/Equicord/Equibop/releases/download/v%{version}/equibop_%{version}_amd64.deb
BuildRequires:  binutils
BuildRequires:  tar
BuildRequires:  xz
Requires:       alsa-lib
Requires:       at-spi2-core
Requires:       cairo
Requires:       cups-libs
Requires:       expat
Requires:       libdrm
Requires:       libXext
Requires:       libXss
Requires:       libxshmfence
Requires:       libsecret
Requires:       dbus-libs
Requires:       glib2
Requires:       gtk3
Requires:       nss
Requires:       pango
Requires:       libX11
Requires:       libxcb
Requires:       libXcomposite
Requires:       libXdamage
Requires:       libXfixes
Requires:       libXrandr
Requires:       libXScrnSaver
Requires:       libXtst
Requires:       libxkbcommon
Requires:       mesa-libgbm
Requires:       xdg-utils

%description
Unofficial native RPM repackaging of the upstream Equibop amd64 Debian binary.

%prep
mkdir payload
cd payload
ar x %{SOURCE0}
data_archive=$(find . -maxdepth 1 -type f -name 'data.tar.*' -print -quit)
tar -xf "$data_archive"

%build

%install
mkdir -p %{buildroot}
cp -a %{_builddir}/%{name}-%{version}/payload/. %{buildroot}/
find %{buildroot} -mindepth 1 -printf "/%P\n" > %{_builddir}/%{name}.files

%files -f %{_builddir}/%{name}.files

%changelog
* Sun Nov 15 2026 Reedman27 - 3.3.4-1
- Initial third-party repackaging of Equibop 3.3.4

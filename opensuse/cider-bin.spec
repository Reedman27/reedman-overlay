Name:           cider-bin
Version:        4.0.17
Release:        1%{?dist}
Summary:        Cider Apple Music client (upstream Debian binary repackaged)
License:        LicenseRef-Proprietary
BuildArch:      x86_64
Source0:        https://repo.cider.sh/apt/pool/main/cider-v%{version}-linux-x64.deb
BuildRequires:  binutils
BuildRequires:  tar
BuildRequires:  xz
Requires:       alsa-lib
Requires:       at-spi2-core
Requires:       cairo
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
Unofficial native RPM repackaging of the upstream Cider amd64 Debian binary.
A valid Cider licence is required to use the application.

%prep
mkdir payload
cd payload
ar x %{SOURCE0}
data_archive=$(find . -maxdepth 1 -type f -name 'data.tar.*' -print -quit)
tar -xf "$data_archive"

%build

%install
cp -a %{_builddir}/%{name}-%{version}/payload/. %{buildroot}/
find %{buildroot} -mindepth 1 -printf "/%P\n" > %{_builddir}/%{name}.files

%files -f %{_builddir}/%{name}.files

%changelog
* Sun Nov 15 2026 Reedman27 - 4.0.17-1
- Initial third-party repackaging

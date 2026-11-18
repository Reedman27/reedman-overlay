Name:           reedmuhn-wmaker
Version:        1.0.4
Release:        1%{?dist}
Summary:        ReedMuhn Window Maker environment
License:        MIT
BuildArch:      noarch
Requires:       WindowMaker
Requires:       wm-desktop
Requires:       picom
Requires:       sxhkd
Requires:       wmclock
Requires:       wmmon
Requires:       wmsystemtray
Requires:       xorg-x11-server
Requires:       xinit

%description
Metapackage: contains no applications, only dependencies.

%prep
%build
%install
mkdir -p %{buildroot}%{_docdir}/reedmuhn-wmaker
echo "reedmuhn-wmaker 1.0.4" > %{buildroot}%{_docdir}/reedmuhn-wmaker/VERSION

%files
%{_docdir}/reedmuhn-wmaker/VERSION

%changelog
* Sun Nov 15 2026 Reedman27 <packages@reedmuhn.invalid> - 1.0.4-1
- Metapackage generated from meta.json

Name:           reedmuhn-gaming
Version:        1.0.3
Release:        1%{?dist}
Summary:        ReedMuhn gaming and Windows compatibility
License:        MIT
BuildArch:      noarch
Requires:       wine
Requires:       winetricks

%description
Metapackage: contains no applications, only dependencies.

%prep
%build
%install
mkdir -p %{buildroot}%{_docdir}/reedmuhn-gaming
echo "reedmuhn-gaming 1.0.3" > %{buildroot}%{_docdir}/reedmuhn-gaming/VERSION

%files
%{_docdir}/reedmuhn-gaming/VERSION

%changelog
* Sun Nov 15 2026 Reedman27 <packages@reedmuhn.invalid> - 1.0.3-1
- Metapackage generated from meta.json

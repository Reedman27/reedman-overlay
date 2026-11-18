Name:           reedmuhn-cider
Version:        1.0.4
Release:        1%{?dist}
Summary:        ReedMuhn Cider: Apple Music client
License:        MIT
BuildArch:      noarch
Requires:       reedmuhn-cider-repo
Requires:       Cider

%description
Metapackage: contains no applications, only dependencies.

%prep
%build
%install
mkdir -p %{buildroot}%{_docdir}/reedmuhn-cider
echo "reedmuhn-cider 1.0.4" > %{buildroot}%{_docdir}/reedmuhn-cider/VERSION

%files
%{_docdir}/reedmuhn-cider/VERSION

%changelog
* Sun Nov 15 2026 Reedman27 <packages@reedmuhn.invalid> - 1.0.4-1
- Metapackage generated from meta.json

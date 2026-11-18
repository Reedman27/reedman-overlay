Name:           reedmuhn-development
Version:        1.0.4
Release:        1%{?dist}
Summary:        ReedMuhn development environment
License:        MIT
BuildArch:      noarch
Requires:       neovim
Requires:       git
Requires:       java-21-openjdk-devel
Requires:       ImageMagick
Requires:       gcc
Requires:       gcc-c++
Requires:       make

%description
Metapackage: contains no applications, only dependencies.

%prep
%build
%install
mkdir -p %{buildroot}%{_docdir}/reedmuhn-development
echo "reedmuhn-development 1.0.4" > %{buildroot}%{_docdir}/reedmuhn-development/VERSION

%files
%{_docdir}/reedmuhn-development/VERSION

%changelog
* Sun Nov 15 2026 Reedman27 <packages@reedmuhn.invalid> - 1.0.4-1
- Metapackage generated from meta.json

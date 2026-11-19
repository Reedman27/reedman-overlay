Name:           reedmuhn-base
Version:        1.0.4
Release:        1%{?dist}
Summary:        ReedMuhn base: command-line environment
License:        MIT
BuildArch:      noarch
Requires:       zsh
Requires:       fastfetch
Requires:       tmux
Requires:       opendoas
Requires:       btop
Requires:       git

%description
Metapackage: contains no applications, only dependencies.

%prep
%build
%install
mkdir -p %{buildroot}%{_docdir}/reedmuhn-base
echo "reedmuhn-base 1.0.4" > %{buildroot}%{_docdir}/reedmuhn-base/VERSION

%files
%{_docdir}/reedmuhn-base/VERSION

%changelog
* Sun Nov 15 2026 Reedman27 <213130028+Reedman27@users.noreply.github.com> - 1.0.4-1
- Metapackage generated from meta.json

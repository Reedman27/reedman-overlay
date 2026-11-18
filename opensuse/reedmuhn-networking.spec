Name:           reedmuhn-networking
Version:        1.0.4
Release:        1%{?dist}
Summary:        ReedMuhn networking and self-hosting
License:        MIT
BuildArch:      noarch
Requires:       NetworkManager
Requires:       tailscale
Requires:       samba
Requires:       podman
Requires:       chrony

%description
Metapackage: contains no applications, only dependencies.

%prep
%build
%install
mkdir -p %{buildroot}%{_docdir}/reedmuhn-networking
echo "reedmuhn-networking 1.0.4" > %{buildroot}%{_docdir}/reedmuhn-networking/VERSION

%files
%{_docdir}/reedmuhn-networking/VERSION

%changelog
* Sun Nov 15 2026 Reedman27 <packages@reedmuhn.invalid> - 1.0.4-1
- Metapackage generated from meta.json

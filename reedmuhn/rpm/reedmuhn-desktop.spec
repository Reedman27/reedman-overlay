Name:           reedmuhn-desktop
Version:        1.0.2
Release:        1%{?dist}
Summary:        ReedMuhn desktop: general graphical applications
License:        MIT
BuildArch:      noarch
Requires:       Thunar
Requires:       file-roller
Requires:       alacritty
Requires:       vlc
Requires:       pipewire
Requires:       pipewire-pulseaudio
Requires:       wireplumber
Requires:       pavucontrol
Requires:       playerctl

%description
Metapackage: contains no applications, only dependencies.

%prep
%build
%install
mkdir -p %{buildroot}%{_docdir}/reedmuhn-desktop
echo "reedmuhn-desktop 1.0.2" > %{buildroot}%{_docdir}/reedmuhn-desktop/VERSION

%files
%{_docdir}/reedmuhn-desktop/VERSION

%changelog
* Sun Nov 15 2026 Reedman27 <packages@reedmuhn.invalid> - 1.0.2-1
- Metapackage generated from meta.json

Name:           reedmuhn-desktop
Version:        1.0.4
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
Requires:       equibop-bin

%description
Metapackage: contains no applications, only dependencies.

%prep
%build
%install
mkdir -p %{buildroot}%{_docdir}/reedmuhn-desktop
echo "reedmuhn-desktop 1.0.4" > %{buildroot}%{_docdir}/reedmuhn-desktop/VERSION

%files
%{_docdir}/reedmuhn-desktop/VERSION

%changelog
* Sun Nov 15 2026 Reedman27 <213130028+Reedman27@users.noreply.github.com> - 1.0.4-1
- Metapackage generated from meta.json

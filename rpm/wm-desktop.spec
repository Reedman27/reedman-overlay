Name:           wm-desktop
Version:        0.1.0
Release:        1%{?dist}
Summary:        Add-ons for Window Maker: notifications, file browser, media keys, menus
License:        MIT
URL:            https://github.com/Reedman27/wm-desktop
Source0:        wm-desktop-%{version}.tar.gz
# UNVERIFIED names: pkgconfig() BuildRequires so the exact -devel package names don't matter
BuildRequires:  gcc, make, pkgconfig(x11), pkgconfig(xft), pkgconfig(fontconfig), pkgconfig(dbus-1), pkgconfig(wrlib), pkgconfig(xinerama)
# wmmediakeys calls these at run time (wpctl comes with Fedora's default PipeWire)
Recommends:     playerctl, brightnessctl, xdg-utils
Suggests:       mpc

%description
Notification daemon, file browser and menu tools for Window Maker, themed from
your Window Maker theme. Stop dunst/mako first: only one daemon can own
org.freedesktop.Notifications. wmmediakeys handles the volume, media, brightness
and launcher keys. Run wm-autostart install to start wmmenud, wmnotify and wmmediakeys.

%prep
%autosetup -n wm-desktop-%{version}

%build
%make_build PREFIX=%{_prefix} WITH_FILES=yes WITH_NOTIFY=yes WITH_MEDIAKEYS=yes WITH_XINERAMA=yes WITH_WRASTER=yes

%install
%make_install PREFIX=%{_prefix} WITH_FILES=yes WITH_NOTIFY=yes WITH_MEDIAKEYS=yes WITH_XINERAMA=yes WITH_WRASTER=yes

%files
%{_prefix}/*

%changelog
* Sun Nov 15 2026 Reedman27 <213130028+Reedman27@users.noreply.github.com> - 0.1.0-1
- Initial package

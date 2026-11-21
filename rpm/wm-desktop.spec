Name:           wm-desktop
Version:        0.1.0
Release:        1%{?dist}
Summary:        Add-ons for Window Maker: notifications, file browser, menus
License:        MIT
URL:            https://github.com/Reedman27/wm-desktop
Source0:        wm-desktop-%{version}.tar.gz
# UNVERIFIED names: pkgconfig() BuildRequires so the exact -devel package names don't matter
BuildRequires:  gcc, make, pkgconfig(x11), pkgconfig(xft), pkgconfig(fontconfig), pkgconfig(dbus-1), pkgconfig(wrlib)

%description
Notification daemon, file browser and menu tools for Window Maker, themed from
your Window Maker theme. Stop dunst/mako first: only one daemon can own
org.freedesktop.Notifications. Run wm-autostart install to start wmmenud and wmnotify.

%prep
%autosetup -n wm-desktop-%{version}

%build
%make_build PREFIX=%{_prefix} WITH_FILES=yes WITH_NOTIFY=yes WITH_WRASTER=yes

%install
%make_install PREFIX=%{_prefix} WITH_FILES=yes WITH_NOTIFY=yes WITH_WRASTER=yes

%files
%{_prefix}/*

%changelog
* Sun Nov 15 2026 Reedman27 <213130028+Reedman27@users.noreply.github.com> - 0.1.0-1
- Initial package

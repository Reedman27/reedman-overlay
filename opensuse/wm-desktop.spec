# wm-desktop: notification daemon, file browser, menu tools and helpers for Window Maker.
# Plain C, no autotools. Builds on openSUSE (Tumbleweed, Leap) and Fedora.
#
# Build with:  opensuse/build.sh wm-desktop
# build.sh clones the repository, so it also works with a private fork, and passes
# `commit` and `snapdate` below. Without them the pinned snapshot here is used.
%{!?commit:%global commit 097f77e97086b9383b7c70ae2c7dd5f8fed9bb92}
%{!?snapdate:%global snapdate 20261118}
%global shortcommit %(echo %{commit} | cut -c1-7)

# libwraster (shipped by Window Maker): exact gradients and PNG/XPM notification icons.
# Disable with:  rpmbuild --without wraster
%bcond_without wraster
# the upstream test suite needs Xvfb, xdotool and a private D-Bus
%bcond_with check

Name:           wm-desktop
Version:        0+git%{snapdate}.%{shortcommit}
Release:        0
Summary:        Add-ons for Window Maker: notifications, file browser, menus
License:        MIT
URL:            https://github.com/Reedman27/wm-desktop
Source0:        wm-desktop-%{commit}.tar.gz
BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  pkgconfig
BuildRequires:  pkgconfig(x11)
BuildRequires:  pkgconfig(xft)
BuildRequires:  pkgconfig(fontconfig)
BuildRequires:  pkgconfig(dbus-1)
%if %{with wraster}
BuildRequires:  pkgconfig(wrlib)
%endif
%if %{with check}
BuildRequires:  dbus-1-x11
BuildRequires:  xdotool
BuildRequires:  xorg-x11-server-Xvfb
%endif
Requires:       hicolor-icon-theme
Recommends:     WindowMaker

%description
Small programs that run beside stock Window Maker and add what it lacks: an application menu
that knows Flatpak, safe launching, a freedesktop notification daemon (wmnotify), a column
file browser (wmfiles), dock helpers and settings. Everything takes its colours, textures and
fonts from the active Window Maker theme. Nothing here patches or replaces Window Maker.

%prep
%autosetup -n wm-desktop-%{commit}

%build
make %{?_smp_mflags} \
    PREFIX=%{_prefix} \
    CFLAGS="%{optflags}" \
    LDFLAGS="%{?build_ldflags}" \
    WITH_FILES=yes WITH_NOTIFY=yes WITH_WRASTER=%{?with_wraster:yes}%{!?with_wraster:no}

%install
make install \
    PREFIX=%{_prefix} DESTDIR=%{buildroot} \
    CFLAGS="%{optflags}" \
    LDFLAGS="%{?build_ldflags}" \
    WITH_FILES=yes WITH_NOTIFY=yes WITH_WRASTER=%{?with_wraster:yes}%{!?with_wraster:no}

%check
%if %{with check}
make check PREFIX=%{_prefix} WITH_FILES=yes WITH_NOTIFY=yes WITH_WRASTER=%{?with_wraster:yes}%{!?with_wraster:no}
%endif

%files
%license LICENSE
%doc README.md
%{_bindir}/wm-autostart
%{_bindir}/wmapps
%{_bindir}/wmdock
%{_bindir}/wmfiles
%{_bindir}/wmgfx
%{_bindir}/wmmenud
%{_bindir}/wmnotify
%{_bindir}/wmnotify-send
%{_bindir}/wmnotifyctl
%{_bindir}/wmsettings
%{_bindir}/wmtheme
%{_datadir}/applications/wmfiles.desktop
%{_datadir}/icons/hicolor/*/apps/wmfiles.*
%{_mandir}/man1/wm*.1*

%changelog
* Thu Nov 19 2026 Reedman27 - 0
- Initial spec

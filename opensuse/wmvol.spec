# PipeWire volume dockapp for Window Maker (from Reedman27/dockapps-collection).
# Plain C. Builds on openSUSE (Tumbleweed, Leap) and Fedora.
# Build with:  opensuse/build.sh wmvol   (build.sh clones the repo and passes `commit`)
%{!?commit:%global commit c8d9cb8f91c1e88515bf36839057c5d5a4fc23b7}
%{!?snapdate:%global snapdate 20261115}
%global shortcommit %(echo %{commit} | cut -c1-7)

Name:           wmvol
Version:        0+git%{snapdate}.%{shortcommit}
Release:        0
Summary:        PipeWire volume dockapp for Window Maker
License:        MIT
URL:            https://github.com/Reedman27/dockapps-collection
Source0:        dockapps-collection-%{commit}.tar.gz
BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  pkgconfig
BuildRequires:  pkgconfig(x11)
BuildRequires:  pkgconfig(xext)
BuildRequires:  pkgconfig(xft)
Requires:       wireplumber

%description
PipeWire volume dockapp for Window Maker. Part of the ReedMuhn Window Maker environment; runs in the dock.

%prep
%autosetup -n dockapps-collection-%{commit}

%build
# flags go through the environment: on the command line they would replace the Makefile's pkg-config flags
export CFLAGS="%{optflags}" LDFLAGS="%{?build_ldflags}"
make -C wmvol %{?_smp_mflags} PREFIX=%{_prefix}

%install
export CFLAGS="%{optflags}" LDFLAGS="%{?build_ldflags}"
make -C wmvol install PREFIX=%{_prefix} DESTDIR=%{buildroot}

%files
%license wmvol/LICENSE
%doc wmvol/README.md
%{_bindir}/wmvol
%{_mandir}/man1/wmvol.1*

%changelog
* Fri Nov 20 2026 Reedman27 - 0
- Initial spec

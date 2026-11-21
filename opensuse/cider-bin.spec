# Repackages Cider Collective's official RPM so it installs cleanly on openSUSE.
# Upstream's RPM is built for Fedora/RHEL: its dependency names do not exist on openSUSE, so
# `zypper in cider-*.rpm` fails. This spec unpacks the same payload and declares openSUSE names.
#
# Build with:  opensuse/build.sh cider-bin
%global cider_arch x64
%{!?cider_version:%global cider_version 4.0.17}

# prebuilt Electron app: nothing to strip, nothing to derive requirements from
%global debug_package %{nil}
%global __strip /bin/true
%global __os_install_post %{nil}
AutoReqProv:    no

Name:           cider-bin
Version:        %{cider_version}
Release:        0
Summary:        Cider - Apple Music client (prebuilt, from Cider Collective)
License:        LicenseRef-Proprietary
URL:            https://cider.sh
Source0:        https://repo.cider.sh/rpm/RPMS/cider-v%{version}-linux-%{cider_arch}.rpm
Source1:        chromium-runtime.inc
ExclusiveArch:  x86_64
BuildRequires:  cpio
BuildRequires:  rpm
%include %{_sourcedir}/chromium-runtime.inc
Provides:       cider = %{version}
Conflicts:      Cider

%description
Cider is an Apple Music client by Cider Collective. This package repackages upstream's
official RPM for openSUSE; a paid Cider licence is needed to actually use the app.
Fedora, RHEL and Arch users can use Cider's own repositories (https://repo.cider.sh) instead.

%prep
%setup -q -c -T
rpm2cpio %{SOURCE0} | cpio -idm --quiet

%build
# nothing to build

%install
# find the payload instead of trusting a hard-coded path: it is the directory with the Cider binary
bin=$(find . -type f -name Cider -perm -u+x | head -n1)
[ -n "$bin" ] || { echo "no Cider binary in the upstream rpm" >&2; exit 1; }
payload=$(dirname "$bin")
# same place as upstream (/usr/lib/cider), so upstream's .desktop file works unchanged
install -d %{buildroot}/usr/lib/cider
cp -a "$payload"/. %{buildroot}/usr/lib/cider/
[ -e %{buildroot}/usr/lib/cider/chrome-sandbox ] || { echo "no chrome-sandbox in payload" >&2; exit 1; }

install -d %{buildroot}%{_bindir}
ln -s /usr/lib/cider/Cider %{buildroot}%{_bindir}/cider

desktop=$(find . -path '*/applications/*.desktop' | head -n1)
[ -n "$desktop" ] || { echo "no .desktop file in the upstream rpm" >&2; exit 1; }
install -D -m 644 "$desktop" %{buildroot}%{_datadir}/applications/cider.desktop
icon=$(find . -path '*/pixmaps/cider.png' | head -n1)
[ -n "$icon" ] || { echo "no icon in the upstream rpm" >&2; exit 1; }
install -D -m 644 "$icon" %{buildroot}%{_datadir}/pixmaps/cider.png

%files
%dir /usr/lib/cider
/usr/lib/cider/*
%exclude /usr/lib/cider/chrome-sandbox
# Chromium's setuid sandbox helper
%attr(4755,root,root) /usr/lib/cider/chrome-sandbox
%{_bindir}/cider
%{_datadir}/applications/cider.desktop
%{_datadir}/pixmaps/cider.png

%changelog
* Thu Nov 19 2026 Reedman27 - 0
- Initial spec: repackage upstream's RPM with openSUSE dependency names

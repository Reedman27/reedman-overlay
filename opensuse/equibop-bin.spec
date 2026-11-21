# Equibop (Equicord's Discord client), repackaged from upstream's .deb for openSUSE.
# The .deb is used only as an archive (ar + tar); nothing here needs dpkg or Debian.
%{!?eqver:%global eqver 3.3.4}
%global debug_package %{nil}
%global __strip /bin/true
%global __os_install_post %{nil}
AutoReqProv:    no

Name:           equibop-bin
Version:        %{eqver}
Release:        0
Summary:        Custom Discord client with Equicord preinstalled
License:        GPL-3.0-only
URL:            https://github.com/Equicord/Equibop
Source0:        equibop_%{version}_amd64.deb
Source1:        chromium-runtime.inc
ExclusiveArch:  x86_64
BuildRequires:  binutils
BuildRequires:  tar
BuildRequires:  xz
BuildRequires:  zstd
%include %{_sourcedir}/chromium-runtime.inc
%if 0%{?suse_version}
Requires:       libsecret-1-0
Requires:       libxshmfence1
%else
Requires:       libsecret
Requires:       libxshmfence
%endif
Requires:       hicolor-icon-theme
Provides:       equibop = %{version}

%description
Unofficial native RPM repackaging of the upstream Equibop amd64 build.

%prep
%setup -q -c -T
ar x %{SOURCE0}
tar -xf data.tar.*

%build
# nothing to build

%install
install -d %{buildroot}
cp -a opt usr %{buildroot}/ 2>/dev/null || true
[ -d %{buildroot}/opt ] || { echo "no /opt payload in the upstream deb" >&2; exit 1; }
# files and symlinks only; directories below /opt are owned explicitly (never /usr or /opt itself)
( cd %{buildroot}
  find opt usr \( -type f -o -type l \) -printf '/%p\n' | sed 's|^\(.*/chrome-sandbox\)$|%attr(4755,root,root) \1|'
  find opt -mindepth 1 -type d -printf 'DIR /%p\n' ) > %{_builddir}/%{name}.files
sed -i 's|^DIR |%%dir |' %{_builddir}/%{name}.files

%files -f %{_builddir}/%{name}.files

%changelog
* Fri Nov 20 2026 Reedman27 - 0
- Rewritten for openSUSE: payload only (no deb control files in /), proper directory ownership, setuid sandbox

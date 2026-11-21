Name:           reedmuhn-cider-repo
Version:        %{?pkgver}%{!?pkgver:1.0.0}
Release:        1%{?dist}
Summary:        Cider Collective RPM repository (repo file and signing key)
License:        MIT
URL:            https://cider.sh
BuildArch:      noarch
Source0:        cider.repo
Source1:        RPM-GPG-KEY

%description
Installs the official Cider Collective yum/dnf repository definition and imports
its GPG key. A valid Cider licence is still needed to use the app.

%prep
%build
%install
install -Dm644 %{SOURCE0} %{buildroot}%{_sysconfdir}/yum.repos.d/cider.repo
install -Dm644 %{SOURCE1} %{buildroot}%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-cider

%post
rpm --import %{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-cider || :

%files
%config(noreplace) %{_sysconfdir}/yum.repos.d/cider.repo
%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-cider

%changelog
* Sun Nov 15 2026 Reedman27 <213130028+Reedman27@users.noreply.github.com> - 1.0.0-1
- Initial repo package

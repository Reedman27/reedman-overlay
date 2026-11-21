# Rustcord: Rust desktop client that hosts the official Discord web app.
# This packages the Qt WebEngine frontend (rustcord-qt): it builds against your distro's own
# Qt6 WebEngine, so there is no bundled Chromium and nothing to download except cargo crates.
# (The CEF frontend, `rustcord`, needs a ~400 MB CEF download: build it from upstream with
# scripts/build.sh if you want it.)
#
# The cargo crates are fetched during %build, so this is a LOCAL build (rpmbuild, or a mock
# chroot with network); OBS needs a vendored source tarball instead.
# Builds on openSUSE (Tumbleweed, Leap) and Fedora.
#
# Build with:  opensuse/build.sh rustcord
# build.sh clones the repository with your own git credentials (works while it is private)
# and passes `commit` and `snapdate`. Without them the pinned snapshot below is used.
%{!?commit:%global commit 820a799ab12edfdd5e20124926d3086262a3bdce}
%{!?snapdate:%global snapdate 20261120}
%global shortcommit %(echo %{commit} | cut -c1-7)

# Rust binaries: no separate debuginfo
%global debug_package %{nil}

Name:           rustcord
Version:        0.1.0+git%{snapdate}.%{shortcommit}
Release:        0
Summary:        Rust desktop client for the official Discord web app
License:        LGPL-3.0-or-later
URL:            https://github.com/Reedman27/rustcord
Source0:        rustcord-%{commit}.tar.gz
BuildRequires:  cargo
BuildRequires:  rust
BuildRequires:  gcc-c++
BuildRequires:  pkgconfig
BuildRequires:  pkgconfig(Qt6Core)
BuildRequires:  pkgconfig(Qt6Gui)
BuildRequires:  pkgconfig(Qt6Widgets)
BuildRequires:  pkgconfig(Qt6DBus)
BuildRequires:  pkgconfig(Qt6WebEngineWidgets)
Requires:       hicolor-icon-theme
Provides:       rustcord-qt = %{version}

%description
Rustcord is a Discord client built from a small Rust shell around Qt WebEngine (Chromium),
loading the official Discord web app. It does not use Electron. Settings live in
~/.config/rustcord/settings.json; themes in ~/.config/rustcord/themes/. Vencord and Equicord
support is opt-in: `rustcord mods install equicord`.

%prep
%autosetup -n rustcord-%{commit}

%build
export CARGO_HOME=%{_builddir}/cargo-home
cargo build --release --locked -p rustcord-qt
# the 256 px icon is generated from the same code that draws the tray icon
cargo run --release --locked -q -p rustcord-core --example dump -- png 256 > rustcord.png

%install
install -Dm755 target/release/rustcord-qt %{buildroot}%{_bindir}/rustcord-qt
ln -s rustcord-qt %{buildroot}%{_bindir}/rustcord
install -Dm644 packaging/rustcord.desktop %{buildroot}%{_datadir}/applications/rustcord.desktop
install -Dm644 rustcord.png %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/rustcord.png

%files
%license COPYING.LESSER
%doc README.md
%{_bindir}/rustcord-qt
%{_bindir}/rustcord
%{_datadir}/applications/rustcord.desktop
%{_datadir}/icons/hicolor/256x256/apps/rustcord.png

%changelog
* Fri Nov 20 2026 Reedman27 - 0
- Initial spec (Qt WebEngine frontend)

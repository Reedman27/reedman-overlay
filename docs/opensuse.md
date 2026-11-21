# openSUSE (Tumbleweed, Leap) and Fedora

The RPM specs in `opensuse/` build on openSUSE and Fedora (the dependency lists switch on `%suse_version`).

```sh
./bootstrap.sh base wmaker            # builds, then installs with zypper --allow-unsigned-rpm
./bootstrap.sh rustcord equibop       # standalone apps
opensuse/build.sh --no-deps cider-bin # build only; output goes to out/
```

`opensuse/build.sh [--no-deps] [--trust-new] [PKG...]` installs BuildRequires with zypper (or dnf), fetches sources,
builds into `out/`. Packages: metas `base desktop wmaker gaming networking development cider`, and
`cider-bin`, `minecraft-launcher-bin`, `equibop-bin`, `wm-desktop`, `wmvol`, `wmmedia`, `rustcord`.

- Prebuilt downloads (Cider, Minecraft) are pinned in `opensuse/SHA256SUMS` the first time you build them; a
  changed file is refused unless you pass `--trust-new`. Equibop is pinned by `EQUIBOP_SHA256`.
- Git sources use your own git credentials, so a private repository works. Commits come from `WM_DESKTOP_REF` and
  `DOCKAPPS_REF`; rustcord uses its current HEAD unless `RUSTCORD_REF` is set.
- Window Maker is `WindowMaker` on openSUSE. wmclock, wmmon and wmsystemtray are not packaged there and are left out.
- Upstream's Cider RPM lists Fedora package names that do not exist on openSUSE; `cider-bin` repackages it with the right ones.

The specs build with `rpmbuild` on Ubuntu with `--nodeps`; they have not been run on a real Tumbleweed install.

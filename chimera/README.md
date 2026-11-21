# Chimera Linux port (cports)

This directory is a cports overlay for Chimera Linux. It is **not** an APKBUILD repository. Chimera's package build system is `cbuild`, and templates belong under a category directory such as `user/<package>/template.py`.

## Quick start: a usable Window Maker desktop

```sh
chimera/setup.sh            # builds Window Maker, wm-desktop, dockapps (needs a few GB and some time)
chimera/desktop-setup.sh    # Xorg + input driver, elogind/turnstile, sound, fonts, terminal, ~/.xinitrc, menu
# log out and back in, then on a text console:
startx
```

`desktop-setup.sh --check` lists what is missing. The usual causes of an unusable bare Chimera X11 setup:
`xserver-xorg-minimal` ships *no input driver* (add `xserver-xorg-input-libinput`), Xorg is in the `user`
repository (`apk add chimera-repo-user`), no xterm exists (urxvt/alacritty are used), and you need to be in the
`video`/`input` groups with elogind and turnstile running.

## Current port status

- `user/windowmaker` (+ `windowmaker-devel`): Window Maker 0.96.0, native musl build, X session entry.
- `user/wm-desktop`, `user/wmvol`, `user/wmmedia`: pinned commits of Reedman27's repositories.
- `user/rustcord`: the Qt WebEngine frontend of Rustcord (pinned commit).
- `user/sxhkd`: Simple X hotkey daemon 0.6.2.
- `user/reedmuhn-*`: generated metapackages (`build_style = "meta"`).
- `user/cider`: marked broken (glibc Electron).

See [INDEX.md](INDEX.md) for the generated inventory and [docs/chimera.md](../docs/chimera.md) for details.

## Build on Chimera

```sh
apk add base-cbuild-host git
chimera/setup.sh                  # or: ./bootstrap.sh base wmaker
chimera/setup.sh --with-rustcord  # also rustcord (slow: Qt WebEngine)
```

`chimera/setup.sh` pins the source checksums, copies these templates into a cports checkout
(`CPORTS`, default `~/cports`), builds them with cbuild, and prints the `apk add` command.
Run it as a normal user, outside a chroot; cbuild needs user namespaces.

Manual route:

```sh
git clone https://github.com/chimera-linux/cports.git && cd cports
cp -a ../reedmuhn-overlay/chimera/user/. user/
./cbuild keygen && ./cbuild binary-bootstrap
./cbuild pkg user/windowmaker user/wm-desktop
```

After building, cbuild creates a local APK repository signed with your key. Copy your public key
(`etc/keys/*.pub`) to `/etc/apk/keys/` rather than using `--allow-untrusted`, and keep the private key private.

## Install and start Window Maker

Once the package has been built and installed from a trusted local repository:

```sh
apk add windowmaker sxhkd picom xserver-xorg-minimal
```

Create `~/.xinitrc` containing:

```sh
exec wmaker
```

Then start the X11 session with:

```sh
startx
```

Chimera's Xorg is normally unprivileged and uses `libseat`; configure a supported seat manager such as the already-installed `elogind` before launching Xorg. Do not install `seatd` alongside `elogind`.

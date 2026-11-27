# ReedMuhn Chimera cports package index

This inventory describes the cports templates in this repository's `chimera/user/` tree. It is not the official Chimera APK index; packages enter the official index only after cports review, merge, and successful project builds.

| Package | Version | Status | Description |
|---|---:|---|---|
| [`cider`](chimera/user/cider/template.py) | `4.0.17` | blocked | Apple Music client by Cider Collective (prebuilt binary) |
| [`reedmuhn-base`](chimera/user/reedmuhn-base/template.py) | `1.0.4` | template | ReedMuhn base: command-line environment |
| [`reedmuhn-cider`](chimera/user/reedmuhn-cider/template.py) | `1.0.4` | template | ReedMuhn Cider: Apple Music client |
| [`reedmuhn-desktop`](chimera/user/reedmuhn-desktop/template.py) | `1.0.4` | template | ReedMuhn desktop: general graphical applications |
| [`reedmuhn-development`](chimera/user/reedmuhn-development/template.py) | `1.0.4` | template | ReedMuhn development environment |
| [`reedmuhn-gaming`](chimera/user/reedmuhn-gaming/template.py) | `1.0.4` | template | ReedMuhn gaming and Windows compatibility |
| [`reedmuhn-networking`](chimera/user/reedmuhn-networking/template.py) | `1.0.4` | template | ReedMuhn networking and self-hosting |
| [`reedmuhn-wmaker`](chimera/user/reedmuhn-wmaker/template.py) | `1.0.4` | template | ReedMuhn Window Maker environment |
| [`rustcord`](chimera/user/rustcord/template.py) | `0.1.0.20261120` | template | Rust desktop client for the official Discord web app |
| [`sxhkd`](chimera/user/sxhkd/template.py) | `0.6.2` | template | Simple X hotkey daemon |
| [`windowmaker`](chimera/user/windowmaker/template.py) | `0.96.0` | template | NeXTSTEP-inspired window manager for X11 |
| [`windowmaker`](chimera/user/windowmaker-devel/template.py) | `0.96.0` | template | NeXTSTEP-inspired window manager for X11 |
| [`wm-desktop`](chimera/user/wm-desktop/template.py) | `0.0.20261127` | template | Add-ons for Window Maker: notifications, file browser, media keys, menus |
| [`wmmedia`](chimera/user/wmmedia/template.py) | `0.0.20261121` | template | Media-control dockapp for Window Maker |
| [`wmvol`](chimera/user/wmvol/template.py) | `0.0.20261121` | template | PipeWire volume dockapp for Window Maker |

## Window Maker meta-package

`reedmuhn-wmaker` currently resolves to the following Chimera packages:

- `windowmaker`
- `wm-desktop`
- `picom`
- `sxhkd`
- `wmmedia`
- `wmvol`
- `xserver-xorg-minimal`
- `xserver-xorg-input-libinput`
- `xinit`
- `mesa-dri`

## Not yet in the Chimera meta-package

`wmclock`, `wmmon` and `wmsystemtray` are not in cports yet and are left out of the Chimera meta-package. The hosted templates (`windowmaker`, `wm-desktop`, `wmvol`, `wmmedia`, `rustcord`) are separate packages: build them with `chimera/setup.sh` and install them next to the meta-package.

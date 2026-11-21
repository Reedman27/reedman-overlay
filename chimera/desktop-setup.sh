#!/bin/sh
# Make a fresh Chimera Linux install boot into a working Window Maker desktop.
#
#   chimera/desktop-setup.sh            install packages, enable services, write ~/.xinitrc and a menu
#   chimera/desktop-setup.sh --check    only report what is missing
#
# Run as your normal user: it uses doas/sudo for the root parts. Log out and back in once
# (so turnstile/elogind create your session), then run `startx` on a text console.
#
# Why each piece is here (these are the usual reasons a bare Chimera X11 setup is unusable):
#   chimera-repo-user          Xorg lives in the "user" repository
#   xserver-xorg-minimal       installs the X server with *no input driver*: no keyboard/mouse
#   xserver-xorg-input-libinput  ...so add the input driver explicitly
#   elogind + turnstile        seat and session; Xorg runs unprivileged through libseat
#   dbus, pipewire, wireplumber  session bus and sound
#   rxvt-unicode               Window Maker's stock menu wants xterm, which Chimera does not ship
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHECK=0; [ "${1:-}" = "--check" ] && CHECK=1
[ "$(id -u)" -ne 0 ] || { echo "run as your normal user, not root" >&2; exit 1; }
if command -v doas >/dev/null; then SU=doas; elif command -v sudo >/dev/null; then SU=sudo
else echo "need doas or sudo" >&2; exit 1; fi

PKGS="xserver-xorg-minimal xserver-xorg-input-libinput xinit xauth mesa-dri \
dbus dbus-x11 elogind turnstile polkit \
pipewire wireplumber alsa-utils \
fonts-dejavu fonts-xorg xrdb xsetroot setxkbmap xrandr xset \
rxvt-unicode dmenu feh picom xdg-utils xdg-user-dirs"
missing=""
for p in $PKGS; do apk info -e "$p" >/dev/null 2>&1 || missing="$missing $p"; done
command -v wmaker >/dev/null || missing="$missing windowmaker(build it: chimera/setup.sh)"
if [ "$CHECK" -eq 1 ]; then
  echo "missing:${missing:- nothing}"
  for g in video input audio; do id -nG | tr ' ' '\n' | grep -qx "$g" || echo "not in group: $g"; done
  exit 0
fi

# 1. packages
apk info -e chimera-repo-user >/dev/null 2>&1 || { $SU apk add chimera-repo-user; $SU apk update; }
# shellcheck disable=SC2086
$SU apk add $PKGS
if ! command -v wmaker >/dev/null; then
  echo "Window Maker is not installed. Build it first (it is not in Chimera's repositories):" >&2
  echo "  $HERE/setup.sh" >&2
  echo "then run this script again." >&2
fi

# 2. services (dinit) and groups: seat management, session bus, user services
for s in elogind turnstiled; do
  $SU dinitctl enable "$s" 2>/dev/null || $SU dinitctl -q enable "$s" 2>/dev/null || echo "note: could not enable $s (maybe already enabled or named differently)" >&2
done
for g in video input audio; do getent group "$g" >/dev/null && $SU usermod -aG "$g" "$USER" 2>/dev/null || true; done

# 3. ~/.xinitrc: one session bus, keyboard layout, pipewire from turnstile, then the window manager
if [ -e "$HOME/.xinitrc" ] && ! grep -q 'reedmuhn' "$HOME/.xinitrc"; then
  cp "$HOME/.xinitrc" "$HOME/.xinitrc.bak"; echo "backed up your old ~/.xinitrc to ~/.xinitrc.bak"
fi
cat > "$HOME/.xinitrc" <<'XINIT'
#!/bin/sh
# reedmuhn: Window Maker session for startx
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
xsetroot -solid '#2b2b3a' -cursor_name left_ptr
command -v picom >/dev/null && [ -z "${REEDMUHN_NO_COMPOSITOR:-}" ] && picom -b 2>/dev/null
[ -x "$HOME/.config/reedmuhn/autostart" ] && "$HOME/.config/reedmuhn/autostart" &
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  exec dbus-run-session wmaker
else
  exec wmaker
fi
XINIT
chmod +x "$HOME/.xinitrc"

# 4. a root menu that works without xterm (right-click the desktop)
mkdir -p "$HOME/GNUstep/Defaults" "$HOME/.config/reedmuhn"
if [ ! -e "$HOME/GNUstep/Defaults/WMRootMenu" ]; then
cat > "$HOME/GNUstep/Defaults/WMRootMenu" <<'MENU'
(
  "Applications",
  ("Terminal", SHEXEC, "urxvt || alacritty"),
  ("Run...", SHEXEC, "dmenu_run"),
  ("Web browser", SHEXEC, "firefox"),
  ("Files", SHEXEC, "thunar"),
  (
    "Window Maker",
    ("Restart", RESTART),
    ("Exit", EXIT)
  )
)
MENU
fi
# wm-desktop and the dockapps, if installed, start with the session
cat > "$HOME/.config/reedmuhn/autostart" <<'AUTO'
#!/bin/sh
for p in wmnotify wmmenud; do command -v "$p" >/dev/null && "$p" & done
exit 0
AUTO
chmod +x "$HOME/.config/reedmuhn/autostart"

cat <<'DONE'

Done. Next:
  1. Log out and back in (or reboot) so the groups and elogind/turnstile apply.
  2. On a text console (not over ssh) run:  startx
  3. Right-click the desktop for the menu; Ctrl-Alt-F2 reaches a console if something fails.
If X fails, read ~/.local/share/xorg/Xorg.0.log (or /var/log/Xorg.0.log) and run:  chimera/desktop-setup.sh --check
DONE

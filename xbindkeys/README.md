# xbindkeys Legacy Files

This directory now holds only the legacy X11 `xbindkeys` configuration and helpers that predate the current Wayland stack.

## Files

- `legacy/.xbindkeysrc`: old X11 `xbindkeys` config.
- `legacy/meta-wheel-minimize`: X11 helper using `xdotool`.
- `legacy/meta-wheel-restore`: X11 helper using `wmctrl`.

## Current Stack

The active Wayland mouse and window-management code lives in `~/Dev/config/wayland/`.

The shared taskbar launcher script now lives in `~/Dev/config/bin/launch-taskbar-app.sh`.

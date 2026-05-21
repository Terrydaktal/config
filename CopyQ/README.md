# CopyQ

This directory contains the CopyQ configuration used for Wayland paste support.

## Files

- `copyq.conf`: main CopyQ preferences, symlinked from `~/.config/copyq/copyq.conf`.
- `copyq-commands.ini`: CopyQ command list, including the Enter/paste override, symlinked from `~/.config/copyq/copyq-commands.ini`.
- `copyq-wayland-paste.sh`: helper used by the command override to paste with `ydotool`.
- `copyq_script_override.js`: standalone copy of the JavaScript override used inside `copyq-commands.ini`.

## Paste Flow

Pressing Enter on a selected CopyQ item calls the `global.paste()` override in `copyq-commands.ini`. The override hides CopyQ, then runs `copyq-wayland-paste.sh` with `YDOTOOL_SOCKET` set to the user runtime socket.

The helper uses `flock` so repeated Enter presses do not overlap. It releases common stuck modifier keys, ensures `ydotoold` is reachable, starts either `ydotool.service` or `ydotoold.service` if needed, waits briefly for CopyQ to return focus to the previous window, then sends `Shift+Insert`.

## Requirements

- `ydotool` installed.
- A working user service named `ydotool.service` or `ydotoold.service`.
- The user must have permission to use uinput/input devices.

## Troubleshooting

- `copyq-wayland-paste failed`: check that `ydotoold` is running and that `$XDG_RUNTIME_DIR/.ydotool_socket` accepts connections.
- Stale socket after killing services: restart the ydotool user service.
- Paste arrives too early: increase the `sleep 0.03` delay in `copyq-wayland-paste.sh`.

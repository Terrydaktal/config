# CopyQ

This directory contains the CopyQ configuration used for Wayland paste support.

## Files

- `copyq.conf`: main CopyQ preferences, symlinked from `~/.config/copyq/copyq.conf`.
- `copyq-commands.ini`: CopyQ command list, including the Enter/paste override, symlinked from `~/.config/copyq/copyq-commands.ini`.
- `copyq-wayland-paste.sh`: helper used by the command override to paste with `ydotool`.
- `copyq_script_override.js`: source for the JavaScript override embedded in `copyq-commands.ini`.
- `test_wayland_paste.sh` and `test-tools/`: regression test and mock input recorder; never send real keyboard events.
- `test-tools/paste-focus-cases.json`: behavior inventory and expected results for delayed, stuck, absent and unavailable target focus.

## Paste Flow

Single-clicking an item or pressing Enter on a selected CopyQ item calls the `global.paste()` override in `copyq-commands.ini`. The override hides CopyQ, then runs `copyq-wayland-paste.sh` with `YDOTOOL_SOCKET` set to the user runtime socket.

The helper uses `flock` so repeated activations do not overlap. It releases common stuck modifier keys, ensures `ydotoold` is reachable and starts either `ydotool.service` or `ydotoold.service` if needed. Instead of assuming a 30 ms sleep is long enough to restore focus, it asks KWin through `kdotool` until a non-CopyQ application is active. Empty focus and the Plasma desktop are not accepted as paste targets. Focus queries have a 200 ms timeout and the readiness loop has a two-second deadline; failure cancels the paste with exit code 6 rather than sending input to the wrong window. Held modifiers are checked again after the wait.

Once target focus is confirmed, the helper sends exactly one `Ctrl+V`. This matches an ordinary clipboard paste, including XFCE Terminal's image-only fallback for Codex. `Shift+Insert` can select PRIMARY instead, so it is not used. The focus guard does not identify a particular text field or prove that the receiving application accepted the paste.

This Wayland override bypasses CopyQ's native `window_paste_with_ctrl_v_regex` setting. The helper is executed on each paste, so editing it takes effect without restarting CopyQ. Run `bash CopyQ/test_wayland_paste.sh` from the config repository root to verify the shortcut and held-modifier guard with a mock `ydotool`.

## Clipboard Persistence

The script override makes CopyQ the Wayland clipboard provider after every valid external copy. It preserves all captured non-internal MIME formats, including images, so clipboard contents remain pasteable after the source application exits.

This persistence handling applies only to explicit clipboard copies. Mouse selections use CopyQ's original callback, so highlighting text in an X11 application such as Mousepad cannot replace the copied clipboard contents, even briefly.

If another application publishes a genuinely zero-byte clipboard offer, the override republishes the latest stored CopyQ item. This also means that applications cannot intentionally clear the clipboard to remove sensitive data; copy different content or clear CopyQ history before clearing the clipboard when that behavior is required.

## Requirements

- `ydotool`, `kdotool`, `timeout` and `flock` installed; `jq` and `rg` are also required for the mock regression tests.
- The helper resolves `kdotool` from PATH or `~/.cargo/bin/kdotool`, since Plasma autostart does not necessarily inherit the interactive shell's Cargo PATH. The mock tests cover this desktop-service environment as well as a genuinely missing tool.
- A working user service named `ydotool.service` or `ydotoold.service`.
- The user must have permission to use uinput/input devices.

## Troubleshooting

- `copyq-wayland-paste failed`: check that `ydotoold` is running and that `$XDG_RUNTIME_DIR/.ydotool_socket` accepts connections.
- Stale socket after killing services: restart the ydotool user service.
- `target focus was not confirmed`: KWin did not report a usable non-CopyQ target before the deadline, or `kdotool` was unavailable or unresponsive. No Ctrl+V was sent; check `kdotool getactivewindow getwindowclassname` rather than increasing an arbitrary sleep.

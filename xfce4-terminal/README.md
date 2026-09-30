# xfce4-terminal Configuration

This directory contains Xfce Terminal configuration files and key/mouse behavior customizations.

## Files

- `accels.scm`: GTK accelerator map for terminal actions.
- `terminalrc`: terminal UI and word-character settings.
- `xfce4-terminal.xml`: xfconf channel data for terminal behavior, appearance, and hyperlink handling.

## `accels.scm`

- `copy` is bound to `Ctrl+C`.
- `paste` is bound to `Ctrl+V`.
- `zoom-in` and `zoom-out` are explicitly unbound.
- Many other actions remain at defaults or commented.
- With the patched terminal, `Ctrl+C` copies a native selection or the attached local tmux history selection without clearing it or scrolling to the bottom. Otherwise it reaches the foreground application, so application-owned selections such as Codex's can use their own copy handler.
- With no selection, `Ctrl+C` can interrupt the foreground application. `Ctrl+Shift+C` remains available for SIGINT.

## `terminalrc`

- `MiscShowMenubar=FALSE`.
- `WordChars=-A-Za-z0-9_./?%&#+_~`.

## `xfce4-terminal.xml`

### Command and Session

- Runs custom command `/home/lewis/.local/bin/fish`.
- `command-login-shell=false`.
- `run-custom-command=true`.

### Appearance and Behavior

- Font: `Hack Tight 11`.
- Background: solid black (`#000000000000`), darkness `1`.
- Cursor shape: I-beam.
- Scrollbar: none.
- Scrollback lines: `50000`.
- Menubar default: hidden.
- Always-show-tabs: disabled.
- Tab style: slim tabs enabled.
- Bell: disabled.
- Close confirmation: disabled.
- Unsafe paste dialog: disabled.

### Colors

- Uses explicit 16-color palette.
- Foreground: white.
- Theme colors are not used (`color-use-theme=false`).
- Bold-is-bright: enabled.

### Hyperlink and Mouse Handling

- Hyperlinks enabled.
- Open hyperlink trigger:
  - button `1` (left click)
  - modifier `4`
- Insert hyperlink trigger:
  - button `1`
  - modifier `5`
  - `misc-hyperlink-insert-middle-click=true`
- `misc-middle-click-opens-uri=false`.
- Directory click payload wrappers:
  - prefix: `__XFCE_CLICK__:`
  - suffix: `\x1f`
- `misc-prefer-mouse-selection=false`: ordinary clicks reach applications such as htop and netmgr. Shift+drag makes a native terminal selection when an application captures the mouse.

`bootstrap.sh` links `~/.tmux.conf` and `~/.config/tmux-simple/tmux.conf` (or the
equivalent under `XDG_CONFIG_HOME`) to `../tmux-simple/tmux.conf`. The installed
`tmux` command is the patched native binary, not a Python launcher. A small Fish
function selects the existing private session socket unless `-S`, `-L`, or an
inherited `TMUX` selects another server. Attachment hooks preserve desktop
clipboard access and automatically start the standalone `tmux-mosh` sizing
helper when Mosh is detected. The previous configuration remains in
`../legacy/tmux/tmux.conf`; foreign config files and links are not removed.

The active configuration enables application mouse forwarding and history
browsing without a prefix or status bar. Mouse selection copies without
jumping to the bottom; typing returns to live input. Wheel scrolling and
Shift+PageUp/Down browse retained history. Keep
`misc-prefer-mouse-selection=false` so ordinary clicks reach mouse-aware
applications. Shift+drag remains available for native terminal selection.
These settings require the patched backend; do not load them into vanilla tmux.
The config migration does not restart existing sessions or modify pi-opsec.

The terminal selection preference is stored in Xfconf; apply it in a running desktop session with `xfconf-query -c xfce4-terminal -p /misc-prefer-mouse-selection -n -t bool -s false`.

## Mouse Behavior Notes

- Normal xfce4-terminal behavior:
  - Double-click to highlight text, then middle-click to paste.
  - Ctrl+click hyperlink to open in associated program.
- Behavior added by the modified xfce4-terminal build:
  - Middle-click hyperlink paste into terminal input.
  - Double-click highlight, then Ctrl+click to open in associated program.

## Additional Patched Behavior (Not Previously Documented)

- Window resize hints were patched to remove `GDK_HINT_RESIZE_INC`, keeping only `GDK_HINT_MIN_SIZE | GDK_HINT_BASE_SIZE` (pixel-smooth resize behavior).
- `Ctrl+Backspace` is intercepted for Codex/Gemini foreground sessions and sends `Ctrl+W` (`\x17`).
- `Shift+Enter`, `Ctrl+Enter`, and `Alt+Enter` are intercepted for Codex/Gemini foreground sessions and send `Ctrl+J` (LF / `\n`).
- Ctrl+click open fallback was added for selected text when no hyperlink is detected:
  - opens only if the selected text resolves to an existing local path.
  - supports `file://`, absolute paths, `~/...`, and relative paths resolved against terminal CWD.
  - does nothing if the selected text is not an existing path.
- Click-driven URI opens now pass the actual click event timestamp (`event->time`) into `gtk_show_uri_on_window(...)` (with fallback only when timestamp is `0`), instead of always relying on `gtk_get_current_event_time()`.
- Middle-click selection paste fallback now requires an active selection; middle-click on blank terminal area no longer pastes by default.

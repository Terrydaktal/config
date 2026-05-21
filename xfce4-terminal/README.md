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
- Because `Ctrl+C` is mapped to copy in terminal UI, SIGINT is available on `Ctrl+Shift+C`.

## `terminalrc`

- `MiscShowMenubar=FALSE`.
- `WordChars=-A-Za-z0-9_./?%&#+_~`.

## `xfce4-terminal.xml`

### Command and Session

- Runs custom command `fish`.
- `command-login-shell=false`.
- `run-custom-command=true`.

### Appearance and Behavior

- Font: `Hack Tight 12`.
- Background: solid black (`#000000000000`), darkness `1`.
- Cursor shape: block.
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

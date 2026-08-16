# fish Configuration

This directory contains the active Fish shell configuration and related color tooling.

## Files

- `config.fish`: main shell configuration.
- `fish_frozen_theme.fish`: theme file used by Fish.
- `ls_colours.dircolors`: dircolors source used to populate `LS_COLORS` and `EZA_COLORS`.
- `print_extension_groups.sh`: helper script that prints grouped extension color mappings from `ls_colours.dircolors`.
- `fonts/`: local font assets used by shell/UI tooling.

## `config.fish` Behavior

### Environment Variables

- `PASSGEN_PEPPER`: exported only if unset; value is redacted in this repo.
- `JAVA_HOME`: `/usr/lib/jvm/java-21-openjdk-amd64`.
- `LS_COLORS`: generated from `~/.config/fish/ls_colours.dircolors` using `dircolors -b` when absent or when the source mtime changes.
- `EZA_COLORS`: set to `$LS_COLORS`.

### Interactive-Only Setup (`if status is-interactive`)

- Initializes zoxide: `zoxide init fish | source`.
- Adds abbreviation `*` -> `{.,}*`.
- De-duplicates inherited `PATH` entries, keeps `~/.local/bin` first when present, then retains the remaining paths and adds missing configured paths.

### Aliases

| Alias | Expansion |
|---|---|
| `mv` | `~/.local/bin/copy --move` |
| `rm` | `~/.local/bin/trash` |
| `cp` | `~/.local/bin/copy` |
| `tree` | `~/.local/bin/tree -FaG -L 2 -T 10 --hyperlink=auto --color=auto` |
| `mkdir` | `mkdir -p` |
| `ls` | `twig -AFU` |
| `la` | `ls -l` |
| `which` | `command twig --which --color always --hyperlink=auto` |
| `pwd` | `ls -ldX` |
| `dust` | `ls -Sa --sort size --reverse` |
| `tile` | `tile_windows 3` |
| `lt` | `tree` |
| `pcmanfm` | `env GDK_DPI_SCALE=1.5 pcmanfm` |

### Functions

| Function | Current behavior |
|---|---|
| `f` | Runs `unearth -CH -F --color=always --hyperlink` with passed args. |
| `cd` | Uses `__zoxide_z` for explicit args. With no args, picks from `/tmp/fzf-history-$USER/universal-last-dirs-$fish_pid` via `friz`; falls back to generic `friz` picker. |
| `cdi` | Runs `__zoxide_zi` with passed args. |
| `mkcd` | Runs `mkdir -p` on the provided path and then `cd`s into the first argument. |
| `nano` | Runs `command nano` for explicit args. With no args, picks from `/tmp/fzf-history-$USER/universal-last-files-$fish_pid` via `friz`; falls back to generic `friz` picker. |
| `expose` | Symlinks a resolved path into `~/.local/bin`; optional second arg overrides symlink name. |
| `unexpose` | Removes a symlink from `~/.local/bin` if the target exists and is a symlink. |
| `sudo` | Rewrites `sudo rm ...` to `sudo ~/.local/bin/trash ...`; otherwise runs normal `sudo`. A failed trash operation is not retried as permanent `rm`. |
| `show_timestamp_after_command` | `fish_postexec` hook that prints `[DD/MM/YY HH:MM:SS] <ms>.<us> ms elapsed` using `CMD_DURATION_NS`. |
| `clipboard` | Copies stdin or file content to clipboard via `fish_clipboard_copy`. |
| `smart_ctrl_backspace` | If command line is non-empty, runs `commandline -f backward-kill-word`. |
| `smart_ctrl_up` | Context-aware `unearth` + `friz` path picker; chooses search mode by command prefix (`cd*`, `nano*`/`cat*`, default). Replaces current token when present; otherwise inserts selection. |
| `__zoxide_auto_report` | `fish_postexec` hook: resolves command-path directories/parents and batches them into one zoxide update. |
| `smart_enter` | Executes current command line (`commandline -f execute`). |
| `xfce_click_handler` | Handles `__XFCE_CLICK__:` payloads. If buffer contains only click payload and it is a directory, changes directory via `__zoxide_cd`; otherwise cleans markers/control chars and pastes cleaned path into command line. |

### Key Bindings

- Enter (`\r`) is rebound in insert/default modes to `smart_enter`.
- `\x1f` is bound in insert/default modes to `xfce_click_handler`.
- `\e[1;5A` is bound to `smart_ctrl_up` (Ctrl+Up sequence).
- `\b` is bound to `smart_ctrl_backspace`.

### Post-interactive setup

- If `nvidia-settings` is available, the setting is launched once per graphical session in the background, guarded by `$XDG_RUNTIME_DIR/fsx-nvidia-powermizer` so shell startup is not blocked. Failed launches remove the marker and can be retried.

## `print_extension_groups.sh`

- Uses `LS_COLOURS_FILE` if set, else probes:
  - `~/.config/fish/ls_colours.dircolors`
  - `<script_dir>/fish/ls_colours.dircolors`
  - `<script_dir>/ls_colours.dircolors`
- Parses dircolors entries into extension/core/name style maps.
- Prints grouped extension categories and core file type styles with truecolor descriptions.

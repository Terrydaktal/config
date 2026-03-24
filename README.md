config.fish
-----

- **Interactive Shell Detection**: The configuration inside `if status is-interactive` only applies when the shell is in interactive mode (not for scripts).  

- **Environment Variables**:  
  - `JAVA_HOME` set to `/usr/lib/jvm/java-21-openjdk-amd64`  
  - `PASSGEN_PEPPER` set to a redacted value (likely for a password generator)  
  - `fish_history_limit` set to `256000` (increases the number of previous commands Fish remembers in its history file)  
  - `LS_COLORS` and `EZA_COLORS` loaded from `~/.config/fish/ls_colours.dircolors` (defines color schemes for `ls`/`eza`/`f`/`tree`). Comprehensive colour coding of ~700 file extensions and types into different colour groups and typeface styles.  

- **Abbreviations**:  
  - **`*`** expands to `{.,}*` (matches both visible and hidden files when using wildcards, e.g., `ls *` shows dotfiles as well).  

- **PATH Modifications**:  
  - Adds `~/.local/bin` to PATH (user local binaries)  
  - Adds `~/.cargo/bin` to PATH (Rust Cargo binaries)  
  - Conditionally adds `$JAVA_HOME/bin` if the directory exists  

- **Aliases**:  
  - `cp` → `/home/lewis/.local/bin/copy` (custom copy script with rsync)
  - `mv` → `/home/lewis/.local/bin/copy --move` (custom move script with rsync)
  - `dust` → `dust -d 1` (disk usage tool with depth 1; counts multiple hardlinks as one unless `-s`)  
  - `rm` → `/home/lewis/.local/bin/trash` (moves files to trash instead of permanent deletion)  
  - `tree` → `/home/lewis/.local/bin/tree -F -a -G -L 3 -T 10 --cache-raw --hyperlinks` (custom tree script with file type indicators, all files, grid layout, max depth 3, limit 10 entries per dir, cache-raw enabled, and hyperlinks)  
  - `mkdir` → `mkdir -p` (create parent directories as needed)  
  - `pwd` outputs a hyperlink (clickable path in supported terminals)  

- **Custom Functions & Abbreviations**:  
  - **`ls` function**: Replaces the traditional `ls` with `eza`. Calls `eza_wrapper` with `-a` (show all), `--sort=type`, `--group-directories-first`, `-F` (indicators), and `--hyperlink`.  
  - **`ll` function**: Long listing with human‑readable sizes, git status, and file indicators. If fewer than 1000 files exist and inside a git repo, adds `--git-repos` for better repository grouping. Uses `eza_wrapper`.  
  - **`la` function**: Like `ll` but also shows hidden files (`-A`). Also conditionally adds `--git-repos` for git repos with <1000 files.  
  - **`eza_wrapper` function**: A helper that processes `--sort` arguments to handle `asc`/`desc` modifiers (e.g., `--sort size desc`). It passes the transformed flags to `eza`.  
  - **`f` function**: Wraps the `f` command with `--cache-raw` enabled.
  - **`cd` function**: Replaces the default `cd`. If no argument is provided, it attempts to use `fzf` to pick a directory from `/tmp/fzf-history-$USER/universal-last-dirs-<pid>`. If that history file is empty, it opens a general `fzf` directory picker. Otherwise, it uses `zoxide`.  
  - **`nano` function**: Replaces the default `nano`. If no argument is provided, it attempts to use `fzf` to pick a file from `/tmp/fzf-history-$USER/universal-last-files-<pid>`. If that history file is empty, it opens a general `fzf` file picker.  
  - **`expose` function + abbreviation**: Creates a symlink in `~/.local/bin` pointing to the real path of a given file, making it accessible from anywhere. Second parameter can rename the link.  
  - **`unexpose` function + abbreviation**: Removes the symlink from `~/.local/bin` (with safety check).  
  - **`sudo` wrapper**: If `sudo rm` is used, it runs the trash script as root instead of plain `rm`; otherwise passes through to normal `sudo`.  
  - **`show_timestamp_after_command`** (event: `fish_postexec`): After each command, prints a timestamp (`[DD/MM/YY HH:MM:SS]`) and the command duration in milliseconds, in grey color.  
  - **`clipboard` function**: Copies content to the system clipboard. Works as `cat file | clipboard` (stdin) or `clipboard filename` (reads file). Uses `fish_clipboard_copy` internally.  
  - **`smart_ctrl_backspace` function**: Deletes the word to the left of the cursor (`backward-kill-word`) if the command line is not empty. Used by the Ctrl+Backspace binding.  
  - **`smart_enter` function**: Bound to Enter. If the command line is empty, it clears the `cd` and `nano` history files in `/tmp`. If not empty, it executes the command as usual.
  - **`__zoxide_auto_report` function** (event: `fish_postexec`): Automatically adds directories to the zoxide database. First adds the current working directory. Then expands the last executed command line into tokens, resolves paths, and adds any existing directories (or parent directories of files) to zoxide, keeping the ranking current.  

- **Key Bindings**:  
  - **Enter**: If the command line is empty, clears history files for `cd` and `nano` (via `smart_enter`).
  - **Ctrl+Backspace**: If the command line is not empty, deletes the word to the left of the cursor (`backward-kill-word`).  
  - **Ctrl+Up Arrow**: Opens zoxide’s interactive directory picker (fzf‑like). The selected directory is inserted into the command line (quoted if it contains spaces).  

- **zoxide Integration**: Replaces `cd` with `zoxide z` (smart directory jumping). Also provides `cdi` for `zi` (fuzzy interactive selection).  

- **GPU Power Management**: Runs `nvidia-settings` to set GPU power mode to “Prefer Maximum Performance” (if NVIDIA drivers are present). Output is silenced.  

- **pcmanfm Scaling**: Alias `pcmanfm` to launch with `GDK_DPI_SCALE=1.5`, ensuring proper UI scaling for high‑DPI displays.

.xbindkeys
----

This configuration file defines custom keyboard and mouse shortcuts using `xbindkeys`, a daemon that binds commands to input events. The settings are designed to enhance window management, application launching, and navigation.

## Key Bindings

### Screenshot
- **Print Screen** → `flameshot gui`  
  Launches Flameshot’s GUI for taking and annotating screenshots.

### Clipboard Manager
- **Ctrl + Shift + Super (Mod4) + Up** → `copyq show`  
  Shows the CopyQ clipboard manager window.

### Window Management

- **Ctrl + Mod4 + Middle Click** → Kill window under mouse  
  - Command: `bash -c 'wid=$(xdotool getmouselocation --shell | grep WINDOW | cut -d= -f2); if [ -n "$wid" ]; then wmctrl -i -c "$wid"; fi'`  
  Closes the window currently under the mouse cursor.

- **Mod4 + Wheel Down** → Debounced minimize  
  - Command: `bash -c 'mkdir /tmp/xbind_lock 2>/dev/null || exit 0; wid=$(xdotool getmouselocation --shell | grep WINDOW | cut -d= -f2); echo $wid >> /tmp/min_stack; xdotool windowminimize $wid; sleep 0.3; rmdir /tmp/xbind_lock'`  
  Minimizes the window under the mouse. Uses a lock file to debounce rapid wheel scrolling.

- **Mod4 + Wheel Up** → Restore last minimized window  
  - Command: `bash -c 'mkdir /tmp/xbind_lock 2>/dev/null || exit 0; wid=$(tail -n 1 /tmp/min_stack); if [ -n \"$wid\" ]; then wmctrl -i -R $wid; sed -i \"\$d\" /tmp/min_stack; fi; sleep 0.3; rmdir /tmp/xbind_lock'`  
  Restores the most recently minimized window from the stack. Also debounced.

- **Alt + Tab** → Cycle windows forward  
  - Command: `cycle-windows forward`  
  Cycles through open windows in forward direction (custom script).

- **Alt + Shift + Tab** → Cycle windows backward  
  - Command: `cycle-windows backward`  
  Cycles through open windows in reverse direction.

### Mouse Navigation (Back/Forward Buttons)

- **Mouse Back Button (Button 8)**  
  - If the active window is a terminal (name contains “terminal”): sends **Alt + Left** (`xte 'keydown Alt_L' 'key Left' 'keyup Alt_L'`) – equivalent to `prevd` in Fish.  
  - Otherwise: sends a normal **back click** (`xdotool click 8`).

- **Mouse Forward Button (Button 9)**  
  - If the active window is a terminal: sends **Alt + Right** – equivalent to `nextd` in Fish.  
  - Otherwise: sends a normal **forward click** (`xdotool click 9`).

### Application Launcher Slots

The script `/home/lewis/.local/bin/launch-slot` is used to launch a fresh new application in the specified taskbar slot. Each slot can be triggered by one or two key combinations. For slot 1 it is `Ctrl + Mod4 + 1`

*Note: Multiple number keys are bound to Slot 5; this may be intentional or a placeholder for additional slots.*

### Speech-to-Text Trigger
- **Keycode 82** (often the “Menu” key or a special key) → `~/Dev/faster-whisperer/trigger.sh`  
  Executes the Faster Whisperer trigger script (voice transcription).

xfce4-terminal
----
- **accels.scm**:
  xfce4-terminal handles sending the SIGINT. When Ctrl+C is bound to copy it sends SIGINT on Ctrl+Shift+C instead (even though this isn't made clear on the preferences)
  
- **~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml**:
This configuration defines a highly customised Xfce Terminal that uses the fish shell as a custom command (not a login shell) with a block cursor shape, a hidden menubar, and no scrollbar or window borders. Visually, it features the Hack 14 font on a transparent background (95% opacity) with a custom dark background hex color, a purple cursor, and a specific 16-color ANSI palette. Functional tweaks include a massive 50,000-line scrollback buffer, while various alerts and interface elements like the system bell, unsafe paste dialog, close confirmation, and permanent tab bar are all disabled.

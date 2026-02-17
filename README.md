# Fish Shell Configuration Summary

* **Smart Navigation:** Replaces standard `cd` with **Zoxide** (smart jump) for faster directory traversal.
* **Consistent Java:** Sets `JAVA_HOME` to OpenJDK 21 and adds the binaries to `PATH`.
* **Secret Management:** Exports `PASSGEN_PEPPER` for password generation tooling.
* **Extended History:** Increases capacity to **50,000** commands.
* **Visuals:** Custom `LS_COLORS` for distinct file types and symlinks.
* **Path Priority:** Prioritizes `~/.local/bin` and `~/.cargo/bin`.
* **Safety & Convenience Aliases:**
   * `cp -i` / `mv -i`: Prompts before overwriting.
   * `mkdir`: Defaults to `mkdir -p` (creates parent directories automatically).
   * `rm`: Routes to a local `trash` script (safe delete).
   * `sudo rm`: Intercepted to run `sudo trash` (prevents root-level permanent deletion).


* **Inspection Tools:**
   * `dust`: Shallow recursion (`-d 1`) for quick disk usage checks.
   * `tree`: Limits depth (`-L 2`) and file count, and groups directories first (`--dirsfirst`).


* **Command Telemetry:** Prints the **timestamp** and **execution duration (ms)** after every command.
* **Keybindings:**
   * Smart Ctrl+Backspace: Deletes words in the prompt but passes through to apps if the line is empty.
   * Ctrl+C (mapped via comment as Ctrl+Shift+C): Cancels the current command line input.


* **System:** Applies NVIDIA GPU power settings and scales PCManFM UI (DPI 1.5).

---

## Scope and Execution Model

### Interactive-only block

Everything inside `if status is-interactive ... end` runs **only when Fish is attached to an interactive terminal**. This prevents your formatting and aliases from breaking non-interactive scripts or cron jobs.

### Global settings (Outside the guard)

The NVIDIA settings and `pcmanfm` alias are applied whenever the file is sourced, ensuring those environment tweaks persist regardless of shell interactivity level.

---

## Environment Variables

### `JAVA_HOME`

```fish
set -gx JAVA_HOME /usr/lib/jvm/java-21-openjdk-amd64

```

* Sets a globally-exported Java home for OpenJDK 21.
* Ensures tools like Gradle, Maven, and IDEs find the correct JVM.

### `PASSGEN_PEPPER`

```fish
set -gx PASSGEN_PEPPER "REDACTED"

```

* Exports a secret "pepper" for `passgen` tooling.
* Inherited by child processes, treating it as a session credential.

### Fish History

```fish
set -gx fish_history_limit 50000

```

* Significantly increases history recall to 50,000 entries.

### `LS_COLORS`

* Customizes ANSI colors for `ls` and compatible tools:
* **Symlinks:** Cyan (`ln`), Red if broken (`or`/`mi`).
* **Extensions:** `.py` (green), `.js` (yellow), `.cpp` (red), `.sh` (magenta), `.txt` (cyan).



---

## PATH Management

```fish
fish_add_path ~/.local/bin
fish_add_path ~/.cargo/bin
test -d "$JAVA_HOME/bin"; and fish_add_path "$JAVA_HOME/bin"

```

* Adds user scripts (`~/.local/bin`) and Rust binaries (`~/.cargo/bin`) to the path.
* Conditionally adds Java binaries if the directory exists.

---

## Navigation: Zoxide

```fish
zoxide init fish --cmd cd | source

```

* Initializes **zoxide**, a smarter `cd` command.
* `--cmd cd`: Replaces the standard `cd` command with zoxide's logic (jumping to directories based on frequency and recency).

---

## Aliases

### File Operations

```fish
alias cp 'cp -i'
alias mv 'mv -i'
alias mkdir 'mkdir -p'

```

* **`cp`/`mv**`: Interactive mode (`-i`) to prevent accidental overwrites.
* **`mkdir`**: Parent mode (`-p`) creates intermediate directories automatically (e.g., `mkdir a/b/c` works even if `a` doesn't exist).

### Inspection Defaults

```fish
alias dust 'dust -r -d 1'
alias tree 'tree -F -L 2 --dirsfirst --filelimit 20'

```

* **`dust`**: Quick summary of the current directory (depth 1).
* **`tree`**:
* `-F`: Appends file type indicators.
* `-L 2`: Limits depth to 2 levels.
* `--dirsfirst`: Lists directories before files (easier scanning).
* `--filelimit 20`: Prevents screen flooding in large folders.



### Safe Delete (`rm` & `sudo`)

```fish
alias rm '/home/lewis/.local/bin/trash'

function sudo
    if test (count $argv) -ge 1; and test "$argv[1]" = "rm"
        command sudo /home/lewis/.local/bin/trash $argv[2..-1]
    else
        command sudo $argv
    end
end

```

* **`rm`**: Redirects to a custom `trash` script to prevent permanent data loss.
* **`sudo rm` wrapper**: Detects if you are running `sudo rm` and swaps it for `sudo trash`.

---

## Post-command Telemetry

```fish
function show_timestamp_after_command --on-event fish_postexec
    # ...
    echo (date "+[%d/%m/%y %H:%M:%S]") "$CMD_DURATION ms elapsed"
    # ...
end

```

* Runs after every interactive command.
* Prints the **date/time** AND the **execution duration** (in milliseconds).
* Useful for benchmarking scripts or auditing long-running processes.

---

## Keybindings

### Smart Ctrl+Backspace

```fish
bind \b smart_ctrl_backspace

```

* **Editing text:** Performs `backward-kill-word`.
* **Empty line:** Sends `\x17` (Ctrl+W) to the underlying application. This ensures full-screen apps (like `vim` or `fzf`) still receive the keystroke they expect when you aren't editing a shell prompt.

### Cancel Command

```fish
bind \cC 'commandline -f cancel'

```

* Maps the interrupt key (Ctrl+C, or Ctrl+Shift+C per your comment config) to cancel the current command line input specifically.

---

## System Tweaks

### GPU Power

```fish
nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" > /dev/null 2>&1

```

* Forces NVIDIA PowerMizer to mode 1 (typically "Preferred Performance" or a specific power state) on shell load.

### PCManFM Scaling

```fish
alias pcmanfm='env GDK_DPI_SCALE=1.5 pcmanfm'

```

* Launches the file manager with 1.5x UI scaling for HiDPI displays.

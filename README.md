- **Interactive Shell Detection**: The configuration inside `if status is-interactive` only applies when the shell is in interactive mode (not for scripts).  
- **Environment Variables**:  
  - `JAVA_HOME` set to `/usr/lib/jvm/java-21-openjdk-amd64`  
  - `PASSGEN_PEPPER` set to a redacted value (likely for a password generator)  
  - `fish_history_limit` set to `256000` (increases the number of previous commands Fish remembers in its history file)  

- **PATH Modifications**:  
  - Adds `~/.local/bin` to PATH (user local binaries)  
  - Adds `~/.cargo/bin` to PATH (Rust Cargo binaries)  
  - Conditionally adds `$JAVA_HOME/bin` if the directory exists  

- **Aliases**:  
  - `cp` → `/home/lewis/.local/bin/copy` (custom copy script, presumably with safety features)  
  - `mv` → `/home/lewis/.local/bin/move` (custom move script, presumably with safety features)  
  - `dust` → `dust -r -d 1` (disk usage tool with reverse sort and depth 1, counting hardlinks once)  
  - `rm` → `/home/lewis/.local/bin/trash` (moves files to trash instead of permanent deletion)  
  - `tree` → `tree -F -L 2 --dirsfirst --filelimit 20` (show file type indicators, max depth 2, directories first, limit entries per dir to 20)  
  - `mkdir` → `mkdir -p` (create parent directories as needed)  
  - `ls` → `eza --group-directories-first --hyperlink` (modern `ls` replacement with directories first)  
  - `ll` → `eza -lgh --git --group-directories-first --hyperlink` (long format, human readable, git status, hyperlink)  
  - `la` → `eza -lgAh --git --group-directories-first --hyperlink` (all files, long format, git status)
  - `pwd` outputs a hyperlink

- **Custom Functions & Abbreviations**:  
  - **`expose` function + abbreviation**: Creates a symlink in `~/.local/bin` pointing to the real path of a given file, making it accessible from anywhere. Second parameter can be provided to give the link a name other than the current binary name.  
  - **`unexpose` function + abbreviation**: Removes the symlink for a given file from `~/.local/bin` (with safety check).  
  - **`sudo` wrapper**: If `sudo rm` is used, it runs the trash script as root instead of plain `rm`; otherwise passes through to normal `sudo`.  
  - **`show_timestamp_after_command`** (event: `fish_postexec`): After each command, prints a timestamp (`[DD/MM/YY HH:MM:SS]`) and the command duration in milliseconds, in grey color.  
  - **`clipboard` function**: Copies content to the system clipboard. Works either as `cat file | clipboard` (stdin) or `clipboard filename` (reads file). Uses `fish_clipboard_copy` internally.  
  - **`smart_ctrl_backspace` function**: Deletes the word to the left of the cursor (`backward-kill-word`) if the command line is not empty. Used by the Ctrl+Backspace binding.  
  - **`__zoxide_auto_report` function** (event: `fish_postexec`): Automatically adds directories visited via commands to the zoxide database. After each command, it examines the arguments; if an argument is an existing directory (or a file, then its parent directory), it adds that directory to zoxide, helping the ranking stay up‑to‑date.

- **Key Bindings**:  
  - **Ctrl+Backspace**: If the command line is not empty, deletes the word to the left of the cursor (`backward-kill-word`). Does nothing when the command line is empty.  
  - **Ctrl+Up Arrow**: Opens zoxide’s interactive directory picker (fzf‑like). Once a directory is selected, it is inserted into the command line. If the path contains spaces, it is automatically quoted. This makes it easy to jump to frequently used directories.

- **zoxide Integration**: Replaces `cd` command with `zoxide z` enabling smart directory jumping, and `cdi` for `zi` allowing fuzzy lookup.  

- **GPU Power Management**: Runs `nvidia-settings` to set GPU power mode to “Prefer Maximum Performance” (if NVIDIA drivers are present). Output is silenced.  

- **pcmanfm Scaling**: Alias `pcmanfm` to launch with `GDK_DPI_SCALE=1.5`, ensuring proper UI scaling for high‑DPI displays.

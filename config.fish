if status is-interactive

    # Environment Variables
    set -gx JAVA_HOME /usr/lib/jvm/java-21-openjdk-amd64
    set -gx PASSGEN_PEPPER "REDACTED"
    set -gx fish_history_limit 256000 
    
    # Path
    fish_add_path ~/.local/bin
    fish_add_path ~/.cargo/bin
    test -d "$JAVA_HOME/bin"; and fish_add_path "$JAVA_HOME/bin"

    # Aliases
    alias mv '/home/lewis/.local/bin/move'
    alias dust 'dust -r -d 1' #counts multiple hardlinks as one unless -s
    alias rm '/home/lewis/.local/bin/trash'
    alias cp '/home/lewis/.local/bin/copy'
    alias tree 'tree -F -L 2 --dirsfirst --filelimit 20'
    alias mkdir 'mkdir -p'
    alias ls 'eza --group-directories-first --hyperlink'
    alias ll 'eza -lgh --git --group-directories-first --hyperlink'
    alias la 'eza -lgAh --git --group-directories-first --hyperlink'
    alias pwd='printf "\e]8;;file://%s%s\a%s\e]8;;\a\n" (hostname) (string escape --style=url -- $PWD) "$PWD"'    

    # Functions
    function expose; set -l target (realpath $argv[1]); set -l name (test (count $argv) -gt 1; and echo $argv[2]; or basename $argv[1]); ln -sf $target ~/.local/bin/$name; echo "Exposed $target as $name"; end; abbr -a expose expose
    function unexpose; set -l target "$HOME/.local/bin/"(basename $argv); if test -L $target; rm $target; echo "Unexposed $target"; else; echo "Error: $target is not a symlink in local bin"; end; end; abbr -a unexpose unexpose
    function sudo; test (count $argv) -ge 1; and test "$argv[1]" = "rm"; and command sudo /home/lewis/.local/bin/trash $argv[2..-1]; or command sudo $argv; end
    function show_timestamp_after_command --on-event fish_postexec; set_color grey; echo (date "+[%d/%m/%y %H:%M:%S]") "$CMD_DURATION ms elapsed"; set_color normal; end
    function clipboard; if not isatty stdin; fish_clipboard_copy; else if count $argv > /dev/null; fish_clipboard_copy < $argv[1]; else; echo "Usage: cat file | clipboard  OR  clipboard filename"; end; end
    function smart_ctrl_backspace; set -l c (commandline); if test -n "$c"; commandline -f backward-kill-word; end; end
    function __zoxide_auto_report --on-event fish_postexec; for a in (string split -n " " -- $argv); if test -d "$a"; zoxide add "$a"; else if test -e "$a"; zoxide add (path dirname -- "$a"); end; end; end

    # Binds
    bind \e\[1\;5A "set -l r (zoxide query -i); if test -n \"\$r\"; if string match -q '* *' \"\$r\"; commandline -i \"'\$r'\"; else; commandline -i \"\$r\"; end; end; commandline -f repaint"
    bind \b smart_ctrl_backspace
   
    zoxide init fish --cmd cd | source
end

nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" > /dev/null 2>&1

# PCman scale fix
alias pcmanfm='env GDK_DPI_SCALE=1.5 pcmanfm'

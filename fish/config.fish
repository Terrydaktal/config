# Environment Variables
if not set -q PASSGEN_PEPPER
    set -gx PASSGEN_PEPPER "REDACTED"
end

set -gx JAVA_HOME /usr/lib/jvm/java-21-openjdk-amd64
set -gx LS_COLORS (dircolors -b ~/.config/fish/ls_colours.dircolors | string replace -r "^LS_COLORS='(.*)';\$" '$1')
set -gx EZA_COLORS $LS_COLORS
    
if status is-interactive
    
    zoxide init fish | source
    
    # Interactive Session Environment Variables
    set -gx fish_history_limit 256000 

    #Abbreviations
    abbr --add --position anywhere -- '*' '{.,}*'

    # Path
    fish_add_path ~/.local/bin
    fish_add_path ~/.cargo/bin
    test -d "$JAVA_HOME/bin"; and fish_add_path "$JAVA_HOME/bin"

    # Aliases
    alias mv '/home/lewis/.local/bin/copy --move'
    alias rm '/home/lewis/.local/bin/trash'
    alias cp '/home/lewis/.local/bin/copy'
    alias tree '/home/lewis/.local/bin/tree -FaG -L 3 -T 10 --cache-raw --hyperlink'
    alias mkdir 'mkdir -p'   
    alias ls 'twig -AFU --cache-raw'
    alias la 'ls -l'
    alias pwd 'ls -ld'
    alias dust 'ls -Sa --sort size --reverse'
    alias tile 'tile_windows 3' 

    # Functions
    function f; unearth -CH --color=always --hyperlink --cache-raw $argv; end    
    function cd; if set -q argv[1]; __zoxide_z $argv; else; set -l file /tmp/fzf-history-$USER/universal-last-dirs-$fish_pid; if test -s $file; set -l t (cat $file | friz --height 40% --reverse --header="Select path"); if test -n "$t"; if test -d "$t"; __zoxide_z "$t"; else; __zoxide_z (dirname -- "$t"); end; end; else; set -l t (friz --height 40% --reverse --header="Select path"); test -n "$t"; and if test -d "$t"; __zoxide_z "$t"; else; __zoxide_z (dirname -- "$t"); end; end; end; end
    function cdi; __zoxide_zi $argv; end
    function nano; if set -q argv[1]; command nano $argv; else; set -l file /tmp/fzf-history-$USER/universal-last-files-$fish_pid; if test -s $file; set -l t (cat $file | friz --height 40% --reverse --header="Select file"); test -n "$t"; and command nano "$t"; else; set -l t (friz --height 40% --reverse --header="Select file"); test -n "$t"; and command nano "$t"; end; end; end
    function which; for p in (command -s $argv); if test -L $p; set -l t (realpath $p); twig --color always -LxXUF $p; set -l l_meta (script -qfc "twig -psot -L '$p'" /dev/null | tr -d '\r' | awk '{$NF=""; sub(/[[:space:]]+$/, ""); print}'); set -l t_meta (script -qfc "twig -psot -L '$t'" /dev/null | tr -d '\r' | awk '{$NF=""; sub(/[[:space:]]+$/, ""); print}'); echo "$l_meta -> $t_meta"; else; twig --color always -psot -XUF -L $p; end; end; end
    function expose; set -l target (realpath $argv[1]); set -l name (test (count $argv) -gt 1; and echo $argv[2]; or basename $argv[1]); ln -sf $target ~/.local/bin/$name; echo "Exposed $target as $name"; end; abbr -a expose expose
    function unexpose; set -l target "$HOME/.local/bin/"(basename $argv); if test -L $target; rm $target; echo "Unexposed $target"; else; echo "Error: $target is not a symlink in local bin"; end; end; abbr -a unexpose unexpose
    function sudo; test (count $argv) -ge 1; and test "$argv[1]" = "rm"; and command sudo /home/lewis/.local/bin/trash $argv[2..-1]; or command sudo $argv; end
    function show_timestamp_after_command --on-event fish_postexec; set_color grey; echo (date "+[%d/%m/%y %H:%M:%S]") "$CMD_DURATION ms elapsed"; set_color normal; end
    function clipboard; if not isatty stdin; fish_clipboard_copy; else if count $argv > /dev/null; fish_clipboard_copy < $argv[1]; else; echo "Usage: cat file | clipboard  OR  clipboard filename"; end; end
    function smart_ctrl_backspace; set -l c (commandline); if test -n "$c"; commandline -f backward-kill-word; end; end
    function smart_ctrl_up; set -l c (commandline); set -l search_dir ~; set -l picker friz; set -l parts (string split ' ' -- "$c"); if set -q parts[2]; if test -d "$parts[-1]"; set search_dir "$parts[-1]"; end; end; switch "$c"; case 'cd*'; set files /tmp/fzf-history-$USER/universal-last-dirs-$fish_pid; set search_cmd unearth "*" -d -H --color=never "$search_dir"; case 'nano*' 'cat*'; set files /tmp/fzf-history-$USER/universal-last-files-$fish_pid; set search_cmd unearth "*" -f -H --color=never "$search_dir"; case '*'; set files /tmp/fzf-history-$USER/universal-last-dirs-$fish_pid /tmp/fzf-history-$USER/universal-last-files-$fish_pid; set search_cmd unearth "*" -H --color=never "$search_dir"; end; set -l r; if test -s "$files[1]"; or test -s "$files[2]"; set r (cat $files 2>/dev/null | $picker --height 40% --reverse --header="Select path"); else; set r ($search_cmd | $picker --height 40% --reverse --header="Select path"); end; if test -n "$r"; commandline -i (string escape -- "$r"); end; commandline -f repaint; end
    functions -e __zoxide_auto_report 2>/dev/null; function __zoxide_auto_report --on-event fish_postexec; zoxide add "$PWD"; for a in (commandline --input="$argv[1]" --tokens-expanded 2>/dev/null); set -l p (path resolve -- "$a" 2>/dev/null); if test -n "$p"; and test -d "$p"; zoxide add "$p"; else if test -n "$p"; and test -e "$p"; zoxide add (path dirname -- "$p"); end; end; end
    function smart_enter; set -l buf (string trim -- (commandline -b)); if test -z "$buf"; echo -n > /tmp/fzf-history-$USER/universal-last-dirs-$fish_pid; echo -n > /tmp/fzf-history-$USER/universal-last-files-$fish_pid; echo; commandline -f repaint; return; end; commandline -f execute; end
    function xfce_click_handler; set -l marker "__XFCE_CLICK__:"; set -l buf (string trim -- (commandline -b)); if not string match -q "*$marker*" -- "$buf"; commandline -f repaint; return; end; set -l clicked (string replace -r "^.*$marker" "" "$buf"); set clicked (string trim -- "$clicked"); set clicked (string replace -a '\x1f' '' "$clicked"); set clicked (string replace -r '[[:cntrl:]]+' '' "$clicked"); set clicked (string replace -r '^--[[:space:]]+' "" "$clicked"); if test -d "$clicked"; __zoxide_cd -- "$clicked"; commandline -r -- ""; commandline -f repaint; return; end; set -l cleaned (string replace -a $marker "" "$buf"); set cleaned (string replace -a '\x1f' '' "$cleaned"); set cleaned (string replace -r '[[:cntrl:]]+' '' "$cleaned"); set cleaned (string replace -r '^--[[:space:]]+' "" "$cleaned"); commandline -r -- (string trim -- "$cleaned"); commandline -f repaint; end

    # Binds
    bind --erase \r
    bind -M insert \r smart_enter
    bind -M default \r smart_enter
    bind -M insert \x1f xfce_click_handler
    bind -M default \x1f xfce_click_handler
    bind \e\[1\;5A smart_ctrl_up
    bind \b smart_ctrl_backspace

end

nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" > /dev/null 2>&1

# PCman scale fix
alias pcmanfm='env GDK_DPI_SCALE=1.5 pcmanfm'

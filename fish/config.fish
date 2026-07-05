# Environment Variables
if not set -q PASSGEN_PEPPER
    set -gx PASSGEN_PEPPER "REDACTED"
end

set -gx JAVA_HOME /usr/lib/jvm/java-17-openjdk
set -gx LS_COLORS (dircolors -b ~/.config/fish/ls_colours.dircolors | string match -r "^LS_COLORS='.*';\$" | string replace -r "^LS_COLORS='(.*)';\$" '$1')
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
    alias mv '~/.local/bin/copy --move'
    alias cp '~/.local/bin/copy'
    alias tree '~/.local/bin/tree -FaG -L 2 -T 10 --hyperlink=auto --color=auto'
    alias mkdir 'mkdir -p'   
    alias ls 'twig -FU --almost-all'
    alias la 'ls -la'
    alias pwd 'ls -lnX'
    alias dust 'ls -Sa --sort size --reverse'
    alias tile 'tile_windows 3' 
    alias lt 'tree 3'
    alias t 'lt'
    alias l 'la'

    # Functions
    function f; unearth -CH -F --color=always --hyperlink $argv; end    
    function cd; if set -q argv[1]; __zoxide_z $argv; else; set -l t (friz --height 40% --reverse --refresh-source-once --header="Select path" --source unearth --index "*" -d -H --color=never .); test -n "$t"; and if test -d "$t"; __zoxide_z "$t"; else; __zoxide_z (dirname -- "$t"); end; end; end
    function cdi; __zoxide_zi $argv; end
    function mkcd; command mkdir -p -- $argv; and cd -- $argv[1]; end
    function nano; if set -q argv[1]; command nano $argv; else; set -l file /tmp/fzf-history-$USER/universal-last-files-$fish_pid; if test -s $file; set -l t (cat $file | friz --height 40% --reverse --header="Select file"); test -n "$t"; and command nano "$t"; else; set -l t (friz --height 40% --reverse --header="Select file"); test -n "$t"; and command nano "$t"; end; end; end
    function which; for p in (command -s $argv); if test -L $p; set -l t (realpath $p); twig --color always -LxXUF $p; set -l l_meta (script -qfc "twig -psot -L '$p'" /dev/null | tr -d '\r' | awk '{$NF=""; sub(/[[:space:]]+$/, ""); print}'); set -l t_meta (script -qfc "twig -psot -L '$t'" /dev/null | tr -d '\r' | awk '{$NF=""; sub(/[[:space:]]+$/, ""); print}'); echo "$l_meta -> $t_meta"; else; twig --color always -psot -XUF -L $p; end; end; end
    function expose; set -l target (realpath $argv[1]); set -l name (test (count $argv) -gt 1; and echo $argv[2]; or basename $argv[1]); ln -sf $target ~/.local/bin/$name; echo "Exposed $target as $name"; end; abbr -a expose expose
    function unexpose; set -l target "$HOME/.local/bin/"(basename $argv); if test -L $target; rm $target; echo "Unexposed $target"; else; echo "Error: $target is not a symlink in local bin"; end; end; abbr -a unexpose unexpose
    function sudo; test (count $argv) -ge 1; and test "$argv[1]" = "rm"; and command sudo ~/.local/bin/trash $argv[2..-1]; or command sudo $argv; end
    functions -e show_timestamp_after_command 2>/dev/null
    function show_timestamp_after_command --on-event fish_postexec; set -l _cmd (string trim -- "$argv[1]"); test -n "$_cmd"; or return; set -l _ms (math -s0 "$CMD_DURATION_NS / 1000000"); set -l _ns (math "$CMD_DURATION_NS % 1000000"); set_color grey; printf "[%s] %d.%06d ms elapsed\n" (date "+%d/%m/%y %H:%M:%S") $_ms $_ns; set_color normal; end
    functions -e __restore_ibeam_cursor 2>/dev/null
    function __restore_ibeam_cursor --on-event fish_prompt; test -t 1; and builtin printf '\e[6 q'; end
    function clipboard; if not isatty stdin; fish_clipboard_copy; else if count $argv > /dev/null; fish_clipboard_copy < $argv[1]; else; echo "Usage: cat file | clipboard  OR  clipboard filename"; end; end
    function smart_ctrl_backspace; set -l c (commandline); if test -n "$c"; commandline -f backward-kill-word; end; end
	    function smart_ctrl_up; set -l c (commandline); set -l current_token (commandline -t); set -l search_dir "$PWD"; set -l token_path "$current_token"; if string match -rq '^~($|/)' -- "$token_path"; set token_path (string replace -r '^~' "$HOME" -- "$token_path"); end; if test -n "$current_token"; if test -d "$token_path"; set search_dir "$token_path"; else; set -l parent (path dirname -- "$token_path" 2>/dev/null); if test -d "$parent"; set search_dir "$parent"; end; end; end; set -l r; switch "$c"; case 'cd*'; set r (friz --height 40% --reverse --refresh-source-once --header="Select path" --source unearth --index "*" -d -H --color=never "$search_dir"); case 'nano*' 'cat*'; set r (friz --height 40% --reverse --refresh-source-once --header="Select path" --source unearth --index "*" -f -H --color=never "$search_dir"); case '*'; set r (friz --height 40% --reverse --refresh-source-once --header="Select path" --source unearth --index "*" -H --color=never "$search_dir"); end; if test -n "$r"; if test -n "$current_token"; commandline -t -- (string escape -- "$r"); else; commandline -i (string escape -- "$r"); end; end; commandline -f repaint; end
	    function smart_prevd; prevd; commandline -f repaint; end
	    function smart_nextd; nextd; commandline -f repaint; end
	    functions -e __zoxide_auto_report 2>/dev/null; function __zoxide_auto_report --on-event fish_postexec; zoxide add "$PWD"; for a in (commandline --input="$argv[1]" --tokens-expanded 2>/dev/null); set -l p (path resolve -- "$a" 2>/dev/null); if test -n "$p"; and test -d "$p"; zoxide add "$p"; else if test -n "$p"; and test -e "$p"; zoxide add (path dirname -- "$p"); end; end; end
	    function smart_enter; commandline -f execute; end
    function codex; command codex $argv; end
    function xfce_click_handler; set -l marker "__XFCE_CLICK__:"; set -l buf (commandline -b); set -l trimmed (string trim -- "$buf"); if not string match -q "*$marker*" -- "$trimmed"; commandline -f repaint; return; end; set -l clicked (string replace -r "^.*$marker" "" "$trimmed"); set clicked (string trim -- "$clicked"); set clicked (string replace -a '\x1f' '' "$clicked"); set clicked (string replace -r '[[:cntrl:]]+' '' "$clicked"); set clicked (string replace -r '^--[[:space:]]+' "" "$clicked"); set -l before_marker (string replace -r "$marker.*\$" "" "$trimmed"); set before_marker (string replace -r '^--[[:space:]]+' "" -- (string trim -- "$before_marker")); if test -d "$clicked"; and test -z "$before_marker"; __zoxide_cd -- "$clicked"; commandline -r -- ""; commandline -f repaint; return; end; set -l cleaned (string replace -a $marker "" "$trimmed"); set cleaned (string replace -a '\x1f' '' "$cleaned"); set cleaned (string replace -r '[[:cntrl:]]+' '' "$cleaned"); set cleaned (string replace -r '^--[[:space:]]+' "" "$cleaned"); commandline -r -- "$cleaned"; commandline -f repaint; end

    # Binds
    bind --erase \r
	    bind -M insert \r smart_enter
	    bind -M default \r smart_enter
	    bind -M insert \x1f xfce_click_handler
	    bind -M default \x1f xfce_click_handler
	    bind \e\[1\;5A smart_ctrl_up
    bind -M insert \e\[1\;3D smart_prevd
    bind -M insert \e\[1\;3C smart_nextd
    bind -M default \e\[1\;3D smart_prevd
    bind -M default \e\[1\;3C smart_nextd
    bind -M insert alt-left smart_prevd
    bind -M insert alt-right smart_nextd
    bind -M default alt-left smart_prevd
    bind -M default alt-right smart_nextd
    bind \b smart_ctrl_backspace

end

if command -q nvidia-settings
    nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" > /dev/null 2>&1
end

# PCman scale fix
alias pcmanfm='env GDK_DPI_SCALE=1.5 pcmanfm'


# Added by Antigravity CLI installer
set -gx PATH "/home/lewis/.local/bin" $PATH

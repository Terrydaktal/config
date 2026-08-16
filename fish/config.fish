# Environment Variables
if not set -q PASSGEN_PEPPER
    set -gx PASSGEN_PEPPER "REDACTED"
end

set -gx TRASH_EXCEPTIONS "paru makepkg yay trigger.sh"

set -gx HF_HOME /data/.cache/huggingface

set -gx JAVA_HOME /usr/lib/jvm/java-17-openjdk
set -l _unique_path
for _path_entry in $PATH
    if not contains -- "$_path_entry" $_unique_path
        set -a _unique_path "$_path_entry"
    end
end
set -l _ordered_path
if contains -- "$HOME/.local/bin" $_unique_path
    set -a _ordered_path "$HOME/.local/bin"
end
for _path_entry in $_unique_path
    if not contains -- "$_path_entry" $_ordered_path
        set -a _ordered_path "$_path_entry"
    end
end
set -gx PATH $_ordered_path

set -l _ls_colors_file "$HOME/.config/fish/ls_colours.dircolors"
set -l _ls_colors_mtime
if test -f "$_ls_colors_file"
    set _ls_colors_mtime (command stat -c %y -- "$_ls_colors_file" 2>/dev/null)
end
set -l _refresh_ls_colors 0
if not set -q LS_COLORS; or test -z "$LS_COLORS"
    set _refresh_ls_colors 1
else if test -n "$_ls_colors_mtime"; and set -q FSX_LS_COLORS_MTIME; and test "$FSX_LS_COLORS_MTIME" != "$_ls_colors_mtime"
    set _refresh_ls_colors 1
end
if test $_refresh_ls_colors -eq 1
    set -gx LS_COLORS (dircolors -b "$_ls_colors_file" | string match -r "^LS_COLORS='.*';\$" | string replace -r "^LS_COLORS='(.*)';\$" '$1')
end
if test -n "$_ls_colors_mtime"
    set -gx FSX_LS_COLORS_MTIME "$_ls_colors_mtime"
end
set -gx EZA_COLORS $LS_COLORS
    
if status is-interactive
    
    if not functions -q __zoxide_z
        zoxide init fish | source
    end
    
    # Interactive Session Environment Variables

    #Abbreviations
    abbr --add --position anywhere -- '*' '{.,}*'

    # Path
    contains -- "$HOME/.local/bin" $PATH; or fish_add_path "$HOME/.local/bin"
    contains -- "$HOME/.cargo/bin" $PATH; or fish_add_path "$HOME/.cargo/bin"
    if test -d "$JAVA_HOME/bin"
        contains -- "$JAVA_HOME/bin" $PATH; or fish_add_path "$JAVA_HOME/bin"
    end

    # Aliases
    alias mv '~/.local/bin/copy --move'
    alias cp '~/.local/bin/copy'
    alias tree '~/.local/bin/tree -FaG -L 3 -T 10 --hyperlink=auto --color=auto'
    alias mkdir 'mkdir -p'   
    alias ls 'twig -FU --almost-all'
    alias la 'ls -la'
    alias which 'command twig --which --color always --hyperlink=auto'
    alias pwd 'ls -lnX'
    alias dust 'ls -Sa --sort size --reverse'
    alias tile 'tile_windows 3' 
    alias lt 'tree'
    alias t 'lt'
    alias l 'la'
    alias codex 'codex --dangerously-bypass-approvals-and-sandbox'

    # Functions
    function f; unearth --index-if-watched -CH -F --color=always --hyperlink $argv; end
    function ff; unearth --index-if-watched "*" -CHl -F --color=always --hyperlink --sort date desc --reverse $argv; end
    function cd; if set -q argv[1]; __zoxide_z $argv; else; set -l t (friz --height 40% --reverse --refresh-source-once --header="Select path" --source unearth --index "*" -d -H --color=never .); test -n "$t"; and if test -d "$t"; __zoxide_z "$t"; else; __zoxide_z (dirname -- "$t"); end; end; end
    function cdi; __zoxide_zi $argv; end
    function mkcd; command mkdir -p -- $argv; and cd -- $argv[1]; end
    function nano
        if set -q argv[1]
            command nano $argv
            return
        end
        set -l file /tmp/fzf-history-$USER/universal-last-files-$fish_pid
        if test -s "$file"
            set -l t (friz --height 40% --reverse --header="Select file" < "$file")
        else
            set -l t (friz --height 40% --reverse --header="Select file")
        end
        test -n "$t"; and command nano "$t"
    end
    function expose; set -l target (realpath $argv[1]); set -l name (test (count $argv) -gt 1; and echo $argv[2]; or basename $argv[1]); ln -sf $target ~/.local/bin/$name; echo "Exposed $target as $name"; end; abbr -a expose expose
    function unexpose; set -l target "$HOME/.local/bin/"(basename $argv); if test -L $target; rm $target; echo "Unexposed $target"; else; echo "Error: $target is not a symlink in local bin"; end; end; abbr -a unexpose unexpose
    function sudo
        if test (count $argv) -ge 1; and test "$argv[1]" = "rm"
            command sudo ~/.local/bin/trash $argv[2..-1]
        else
            command sudo $argv
        end
    end
    functions -e show_timestamp_after_command 2>/dev/null
    function show_timestamp_after_command --on-event fish_postexec
        set -l _cmd (string trim -- "$argv[1]")
        test -n "$_cmd"; or return
        set -l _duration_ns "$CMD_DURATION_NS"
        if not string match -rq '^[0-9]+$' -- "$_duration_ns"
            set _duration_ns 0
        end
        set -l _ms (math -s0 "$_duration_ns / 1000000")
        set -l _ns (math "$_duration_ns % 1000000")
        set_color grey
        printf "[%s] %d.%06d ms elapsed\n" (date "+%d/%m/%y %H:%M:%S") $_ms $_ns
        set_color normal
    end
    functions -e __restore_ibeam_cursor 2>/dev/null
    function __restore_ibeam_cursor --on-event fish_prompt; test -t 1; and builtin printf '\e[6 q'; end
    function clipboard; if not isatty stdin; fish_clipboard_copy; else if count $argv > /dev/null; fish_clipboard_copy < $argv[1]; else; echo "Usage: cat file | clipboard  OR  clipboard filename"; end; end
	    function smart_ctrl_up; set -l c (commandline); set -l c_trimmed (string trim -- "$c"); set -l current_token (commandline -t); set -l search_dir "$PWD"; set -l token_path "$current_token"; if string match -rq '^~($|/)' -- "$token_path"; set token_path (string replace -r '^~' "$HOME" -- "$token_path"); end; if test -n "$current_token"; if test -d "$token_path"; set search_dir "$token_path"; else; set -l parent (path dirname -- "$token_path" 2>/dev/null); if test -d "$parent"; set search_dir "$parent"; end; end; end; set -l r; if test -z "$c_trimmed"; set r (friz --height 40% --reverse --refresh-source-once --header="Select path" --source unearth --index "*" -H --color=never "$search_dir"); set r (string trim -- "$r"); set -l resolved (path resolve -- "$r" 2>/dev/null); if test -n "$resolved"; set r "$resolved"; end; if test -n "$r"; if test -d "$r"; __zoxide_cd -- "$r"; commandline -r -- ""; else if test -e "$r"; command xdg-open "$r" >/dev/null 2>&1 &; commandline -r -- ""; else; commandline -i (string escape -- "$r"); end; end; commandline -f repaint; return; end; switch "$c"; case 'cd*'; set r (friz --height 40% --reverse --refresh-source-once --header="Select path" --source unearth --index "*" -d -H --color=never "$search_dir"); case 'nano*' 'cat*'; set r (friz --height 40% --reverse --refresh-source-once --header="Select path" --source unearth --index "*" -f -H --color=never "$search_dir"); case '*'; set r (friz --height 40% --reverse --refresh-source-once --header="Select path" --source unearth --index "*" -H --color=never "$search_dir"); end; if test -n "$r"; if test -n "$current_token"; commandline -t -- (string escape -- "$r"); else; commandline -i (string escape -- "$r"); end; end; commandline -f repaint; end
	    function smart_prevd; prevd; commandline -f repaint; end
	    function smart_nextd; nextd; commandline -f repaint; end
	    functions -e __zoxide_auto_report 2>/dev/null
	    function __zoxide_auto_report --on-event fish_postexec
	        set -l tokens (commandline --input="$argv[1]" --tokens-expanded 2>/dev/null)
	        set -l paths
	        for a in $tokens
	            set -l p (path resolve -- "$a" 2>/dev/null)
	            if test -n "$p"
	                if test -d "$p"
	                    set -a paths "$p"
	                else if test -e "$p"
	                    set -a paths (path dirname -- "$p")
	                end
	            end
	        end
	        if test (count $paths) -gt 0
	            command zoxide add -- $paths
	        end
	    end
	    function smart_enter; commandline -f execute; end
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
    bind -M insert alt-backspace backward-kill-word
    bind -M default alt-backspace backward-kill-word
    bind -M insert \e\177 backward-kill-word
    bind -M default \e\177 backward-kill-word

end

if status is-interactive; and command -q nvidia-settings; and set -q XDG_RUNTIME_DIR; and test -d "$XDG_RUNTIME_DIR"
    set -l nvidia_marker "$XDG_RUNTIME_DIR/fsx-nvidia-powermizer"
    if command mkdir "$nvidia_marker" >/dev/null 2>&1
        begin
            command nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" >/dev/null 2>&1
            or command rmdir "$nvidia_marker" >/dev/null 2>&1
        end &
    end
end

# PCman scale fix
alias pcmanfm='env GDK_DPI_SCALE=1.5 pcmanfm'

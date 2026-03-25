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
    alias dust 'dust -d 1' #counts multiple hardlinks as one unless -s
    alias rm '/home/lewis/.local/bin/trash'
    alias cp '/home/lewis/.local/bin/copy'
    alias tree '/home/lewis/.local/bin/tree -F -a -G -L 3 -T 10 --cache-raw --hyperlink'
    alias mkdir 'mkdir -p'
    alias pwd='printf "\e]8;;file://%s%s\a%s\e]8;;\a\n" (hostname) (string escape --style=url -- $PWD) "$PWD"'    
    alias ls 'twig -AF --hyperlink --cache-raw'

    # Functions
    function ll; set -l g --git; if test (count *) -lt 1000; and git rev-parse --is-inside-work-tree >/dev/null 2>&1; set -a g --git-repos; end; eza_wrapper eza -lghF $g --group-directories-first --sort=type --hyperlink -- $argv; end
    function la; set -l g --git; if test (count -A *) -lt 1000; and git rev-parse --is-inside-work-tree >/dev/null 2>&1; set -a g --git-repos; end; eza_wrapper eza -lgAhF $g --group-directories-first --sort=type --hyperlink -- $argv; end
    function eza_wrapper; set -l cmd $argv[1]; set -e argv[1]; set -l f; set -l i 1; while test $i -le (count $argv); if test "$argv[$i]" = "--sort"; set -l fd $argv[(math $i + 1)]; set -l or $argv[(math $i + 2)]; if test "$or" = asc; set -a f --sort=$fd; set i (math $i + 3); else if test "$or" = desc; set -a f --sort=$fd -r; set i (math $i + 3); else; set -a f --sort=$fd; set i (math $i + 2); end; else; set -a f "$argv[$i]"; set i (math $i + 1); end; end; command $cmd $f; end
    function f; command f --cache-raw $argv; end    
    function cd; if set -q argv[1]; __zoxide_z $argv; else; set -l file /tmp/fzf-history-$USER/universal-last-dirs-$fish_pid; if test -s $file; set -l t (cat $file | fzf --height 40% --reverse --header="Select path"); if test -n "$t"; if test -d "$t"; __zoxide_z "$t"; else; __zoxide_z (dirname -- "$t"); end; end; else; set -l t (fzf --height 40% --reverse --header="Select path"); test -n "$t"; and if test -d "$t"; __zoxide_z "$t"; else; __zoxide_z (dirname -- "$t"); end; end; end; end
    function cdi; __zoxide_zi $argv; end
    function nano; if set -q argv[1]; command nano $argv; else; set -l file /tmp/fzf-history-$USER/universal-last-files-$fish_pid; if test -s $file; set -l t (cat $file | fzf --height 40% --reverse --header="Select file"); test -n "$t"; and command nano "$t"; else; set -l t (fzf --height 40% --reverse --header="Select file"); test -n "$t"; and command nano "$t"; end; end; end
    function which; for p in (command -s $argv); printf "\e]8;;file://%s%s\a%s/\e]8;;\a\e]8;;file://%s%s\a%s\e]8;;\a\n" (hostname) (string escape --style=url -- (path dirname $p)) (path dirname $p) (hostname) (string escape --style=url -- $p) (eza --color=always -d $p | string replace -- (path dirname $p)/ "" | string collect); end; end
    function expose; set -l target (realpath $argv[1]); set -l name (test (count $argv) -gt 1; and echo $argv[2]; or basename $argv[1]); ln -sf $target ~/.local/bin/$name; echo "Exposed $target as $name"; end; abbr -a expose expose
    function unexpose; set -l target "$HOME/.local/bin/"(basename $argv); if test -L $target; rm $target; echo "Unexposed $target"; else; echo "Error: $target is not a symlink in local bin"; end; end; abbr -a unexpose unexpose
    function sudo; test (count $argv) -ge 1; and test "$argv[1]" = "rm"; and command sudo /home/lewis/.local/bin/trash $argv[2..-1]; or command sudo $argv; end
    function show_timestamp_after_command --on-event fish_postexec; set_color grey; echo (date "+[%d/%m/%y %H:%M:%S]") "$CMD_DURATION ms elapsed"; set_color normal; end
    function clipboard; if not isatty stdin; fish_clipboard_copy; else if count $argv > /dev/null; fish_clipboard_copy < $argv[1]; else; echo "Usage: cat file | clipboard  OR  clipboard filename"; end; end
    function smart_ctrl_backspace; set -l c (commandline); if test -n "$c"; commandline -f backward-kill-word; end; end
    function smart_enter; set -l c (commandline); if test -z "$c"; echo -n > /tmp/fzf-history-$USER/universal-last-dirs-$fish_pid; echo -n > /tmp/fzf-history-$USER/universal-last-files-$fish_pid; echo; commandline -f repaint; else; commandline -f execute; end; end
    functions -e __zoxide_auto_report 2>/dev/null; function __zoxide_auto_report --on-event fish_postexec; zoxide add "$PWD"; for a in (commandline --input="$argv[1]" --tokens-expanded 2>/dev/null); set -l p (path resolve -- "$a" 2>/dev/null); if test -n "$p"; and test -d "$p"; zoxide add "$p"; else if test -n "$p"; and test -e "$p"; zoxide add (path dirname -- "$p"); end; end; end

    # Binds
    bind \e\[1\;5A "set -l r (zoxide query -i); if test -n \"\$r\"; if string match -q '* *' \"\$r\"; commandline -i \"'\$r'\"; else; commandline -i \"\$r\"; end; end; commandline -f repaint"
    bind \b smart_ctrl_backspace
    bind \r smart_enter
   
end

nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" > /dev/null 2>&1

# PCman scale fix
alias pcmanfm='env GDK_DPI_SCALE=1.5 pcmanfm'

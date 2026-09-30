function tmux --wraps tmux --description 'Native tmux using the existing session socket'
    set -l original_argv $argv
    if set -q TMUX
        command tmux $original_argv
        return $status
    end
    # Inspect only global options; the command and its arguments pass through intact.
    if not argparse --stop-nonopt --ignore-unknown 'S=' 'L=' 'f=' 'c=' 'T=' 2 C D d h l N q u U v V -- $argv 2>/dev/null
        command tmux $original_argv
        return $status
    end
    if set -q _flag_S; or set -q _flag_L
        command tmux $original_argv
        return $status
    end
    set -l socket_base /tmp
    if set -q XDG_RUNTIME_DIR; and string match -q '/*' -- "$XDG_RUNTIME_DIR"
        set socket_base "$XDG_RUNTIME_DIR"
    end
    set -l socket_dir "$socket_base/tmux-simple-$(id -u)"
    if not test -d "$socket_dir"
        command mkdir -m 700 -p -- "$socket_dir"; or return $status
    end
    if test -L "$socket_dir"; or not test -O "$socket_dir"; or test (command stat -c '%a' -- "$socket_dir") != 700
        printf 'tmux: unsafe private socket directory: %s\n' "$socket_dir" >&2
        return 1
    end
    command tmux -S "$socket_dir/server.sock" $original_argv
end

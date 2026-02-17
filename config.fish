if status is-interactive

    # Environment Variables
    set -gx JAVA_HOME /usr/lib/jvm/java-21-openjdk-amd64
    set -gx PASSGEN_PEPPER "REDACTED"
    set -gx fish_history_limit 50000
    set -gx LS_COLORS "$LS_COLORS:ln=01;36:or=01;31:mi=01;31:*.txt=01;36:*.py=01;32:*.js=01;33:*.cpp=01;31:*.sh=01;35:"

    # Path
    fish_add_path ~/.local/bin
    fish_add_path ~/.cargo/bin
    test -d "$JAVA_HOME/bin"; and fish_add_path "$JAVA_HOME/bin"

    # Aliases
    alias cp 'cp -i'
    alias mv 'mv -i'
    alias dust 'dust -r -d 1'
    alias rm '/home/lewis/.local/bin/trash'
    alias tree 'tree -F -L 2 --dirsfirst --filelimit 20'
    alias mkdir 'mkdir -p'

    # sudo wrapper: if "sudo rm ..." then use trash as root
    function sudo
        if test (count $argv) -ge 1; and test "$argv[1]" = "rm"
            command sudo /home/lewis/.local/bin/trash $argv[2..-1]
        else
            command sudo $argv
        end
    end

    function show_timestamp_after_command --on-event fish_postexec
    	set_color grey
    	# Display the current date/time and the duration in ms
    	echo (date "+[%d/%m/%y %H:%M:%S]") "$CMD_DURATION ms elapsed"
    	set_color normal
    end    


    # Only bind Ctrl+Backspace in Fish, pass through to applications otherwise
    function smart_ctrl_backspace
        set cmd (commandline)

        if string match -qr '.*\n.*' -- "$cmd"
            commandline -f backward-kill-word
        else if test -n "$cmd"
            commandline -f backward-kill-word
        else
            commandline -i -- "\x17"
        end
    end

    bind \b smart_ctrl_backspace

    # Map Ctrl+Shift+C to send SIGINT
    bind \cC 'commandline -f cancel'
    zoxide init fish --cmd cd | source
end

nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" > /dev/null 2>&1

# PCman scale fix
alias pcmanfm='env GDK_DPI_SCALE=1.5 pcmanfm'

function runPasteWithYdotool() {
    var runtime = str(env('XDG_RUNTIME_DIR'));
    if (!runtime)
        runtime = '/run/user/1000';

    var socket = str(env('YDOTOOL_SOCKET'));
    if (!socket)
        socket = runtime + '/.ydotool_socket';

    // Update this path to point to where you moved the bash script
    var helper = Dir().homePath() + '/Dev/config/copyQ/scripts/copyq-wayland-paste.sh';

    var p = execute(
        'env',
        'YDOTOOL_SOCKET=' + socket,
        helper
    );

    if (!p)
        throw 'Failed to start copyq-wayland-paste';

    if (p.exit_code !== 0)
        throw 'copyq-wayland-paste failed: ' + str(p.stderr);
}

global.paste = function() {
    hide();
    runPasteWithYdotool();
};

global.focusPrevious = function() {
    hide();
};

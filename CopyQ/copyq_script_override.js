function copyqClipboardPayloadFromCurrentData() {
    var item = {};
    var formats = dataFormats();

    for (var i = 0; i < formats.length; ++i) {
        var format = str(formats[i]);
        if (!format.startsWith('application/x-copyq-'))
            item[format] = data(format);
    }

    return item;
}

function copyqClipboardPayloadFromItem(item) {
    var payload = {};

    for (var format in item) {
        if (!format.startsWith('application/x-copyq-'))
            payload[format] = item[format];
    }

    return payload;
}

function copyqClipboardPayloadHasBytes(item) {
    for (var format in item) {
        if (item[format].length > 0)
            return true;
    }

    return false;
}

function copyqRestoreLastStoredClipboardItem() {
    if (size() === 0)
        return false;

    var item = copyqClipboardPayloadFromItem(getItem(0));
    if (!copyqClipboardPayloadHasBytes(item))
        return false;

    serverLog('Ignoring empty clipboard update and restoring the latest item');
    copy(item);
    return true;
}

global.onClipboardChanged = function() {
    var item = copyqClipboardPayloadFromCurrentData();

    if (!copyqClipboardPayloadHasBytes(item)) {
        if (!copyqRestoreLastStoredClipboardItem())
            updateClipboardData();
        return;
    }

    if (!hasData()) {
        // Preserve non-empty whitespace and binary data that hasData() ignores.
        updateClipboardData();
        copy(item);
        return;
    }

    if (runAutomaticCommands()) {
        saveData();
        updateClipboardData();

        // Automatic commands can transform clipboard data before it is saved.
        item = copyqClipboardPayloadFromCurrentData();
        if (copyqClipboardPayloadHasBytes(item))
            copy(item);
    } else {
        clearClipboardData();
    }
};

function runPasteWithYdotool() {
    var runtime = str(env('XDG_RUNTIME_DIR'));
    if (!runtime)
        runtime = '/run/user/1000';

    var socket = str(env('YDOTOOL_SOCKET'));
    if (!socket)
        socket = runtime + '/.ydotool_socket';

    var helper = Dir().homePath() + '/Dev/config/CopyQ/copyq-wayland-paste.sh';

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

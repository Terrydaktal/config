function windowIdentity(window) {
    return [
        window.windowClass,
        window.resourceClass,
        window.desktopFileName
    ].filter(Boolean).join(" ").toLowerCase();
}

function findCopyQWindow() {
    for (var i = workspace.stackingOrder.length - 1; i >= 0; --i) {
        var window = workspace.stackingOrder[i];
        if (windowIdentity(window).indexOf("copyq") !== -1) {
            return window;
        }
    }
    return null;
}

function requestCopyQWindow() {
    callDBus(
        "org.freedesktop.systemd1",
        "/org/freedesktop/systemd1",
        "org.freedesktop.systemd1.Manager",
        "StartUnit",
        "copyq-show-window.service",
        "replace",
        function() {}
    );
}

function toggleCopyQWindow() {
    var window = findCopyQWindow();
    if (!window) {
        requestCopyQWindow();
        return;
    }

    if (workspace.activeWindow === window && !window.minimized) {
        if (window.minimizable) {
            window.minimized = true;
        }
        return;
    }

    window.minimized = false;
    workspace.activeWindow = window;
}

registerShortcut(
    "copyq-window-toggle",
    "Toggle existing CopyQ window",
    "F24",
    toggleCopyQWindow
);

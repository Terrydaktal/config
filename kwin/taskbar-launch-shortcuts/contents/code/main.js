function launchTaskbarApp(index) {
    callDBus(
        "org.freedesktop.systemd1",
        "/org/freedesktop/systemd1",
        "org.freedesktop.systemd1.Manager",
        "StartUnit",
        "launch-taskbar-app@" + index + ".service",
        "replace"
    );
}

for (var i = 1; i <= 9; i++) {
    (function(index) {
        registerShortcut(
            "Launch Taskbar App " + index,
            "Launch a fresh instance of taskbar app " + index,
            "Ctrl+Meta+" + index,
            function() { launchTaskbarApp(index); }
        );
    })(i);
}

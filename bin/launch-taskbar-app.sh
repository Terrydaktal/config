#!/usr/bin/env bash
log="${XDG_RUNTIME_DIR:-/tmp}/launch-taskbar-app.log"
INDEX=$1
let INDEX=INDEX-1
LAUNCHERS=$(grep "^launchers=" ~/.config/plasma-org.kde.plasma.desktop-appletsrc | head -n 1 | cut -d= -f2-)
IFS=',' read -ra APP_ARRAY <<< "$LAUNCHERS"
APP_ENTRY="${APP_ARRAY[$INDEX]}"
printf '%s index=%s entry=%s\n' "$(date --iso-8601=seconds)" "$((INDEX + 1))" "$APP_ENTRY" >> "$log"
if [[ "$APP_ENTRY" == applications:* ]]; then
    DESKTOP_FILE="${APP_ENTRY#applications:}"
    if command -v gtk-launch >/dev/null 2>&1; then
        gtk-launch "$DESKTOP_FILE" >/dev/null 2>&1 &
    else
        kioclient exec "$DESKTOP_FILE" >/dev/null 2>&1 &
    fi
fi

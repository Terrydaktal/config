#!/usr/bin/env bash
set -euo pipefail

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-$runtime/.ydotool_socket}"
modifier_state_file="${WAYLAND_MODIFIER_STATE_FILE:-$runtime/wayland_modifier_state.env}"

lock="$runtime/copyq-ydotool-paste.lock"
exec 9>"$lock"

flock -n 9 || exit 0

release_keys() {
    ydotool key --key-delay 0 110:0 42:0 54:0 29:0 97:0 56:0 100:0 125:0 126:0 47:0 >/dev/null 2>&1 || true
}

ydotool_ready() {
    ydotool key --key-delay 0 29:0 >/dev/null 2>&1
}

ensure_ydotoold() {
    ydotool_ready && return 0

    systemctl --user start ydotool.service >/dev/null 2>&1 \
        || systemctl --user start ydotoold.service >/dev/null 2>&1 \
        || true

    for _ in 1 2 3 4 5; do
        ydotool_ready && return 0
        sleep 0.05
    done

    printf 'copyq-wayland-paste: ydotoold is not reachable at %s\n' "$YDOTOOL_SOCKET" >&2
    return 4
}

modifier_held() {
    [[ -f "$modifier_state_file" ]] || return 1
    # shellcheck disable=SC1090
    source "$modifier_state_file"
    [[ "${META:-0}" == "1" || "${SHIFT:-0}" == "1" || "${CTRL:-0}" == "1" || "${ALT:-0}" == "1" ]]
}

trap release_keys EXIT

ensure_ydotoold
if modifier_held; then
    printf 'copyq-wayland-paste: refusing to paste because a modifier key is currently held\n' >&2
    exit 5
fi
release_keys

# Give CopyQ a moment to hide and return focus to the previous window.
sleep 0.03

ydotool key --key-delay 0 42:1 110:1 110:0 42:0

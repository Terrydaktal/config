#!/usr/bin/env bash
set -euo pipefail

log="${XDG_RUNTIME_DIR:-/tmp}/launch-taskbar-app.log"
index="${1:?missing taskbar index}"
slot=$((index - 1))

desktop_id_from_entry() {
    case "$1" in
        applications:*)
            printf '%s\n' "${1#applications:}"
            ;;
        preferred://filemanager)
            xdg-mime query default inode/directory 2>/dev/null || printf 'pcmanfm.desktop\n'
            ;;
        preferred://browser)
            xdg-settings get default-web-browser 2>/dev/null \
                || xdg-mime query default x-scheme-handler/https 2>/dev/null \
                || printf 'firefox.desktop\n'
            ;;
        *)
            return 1
            ;;
    esac
}

desktop_path_for_id() {
    local desktop_id="$1"
    local candidate

    for candidate in \
        "$HOME/.local/share/applications/$desktop_id" \
        "/usr/local/share/applications/$desktop_id" \
        "/usr/share/applications/$desktop_id"
    do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

exec_line_from_desktop() {
    local desktop_path="$1"
    local action_name="${2:-}"
    local target_section='[Desktop Entry]'

    if [[ -n "$action_name" ]]; then
        target_section="[Desktop Action $action_name]"
    fi

    awk -v target="$target_section" '
        /^\[/ { section = $0 }
        section == target && /^Exec=/ {
            sub(/^Exec=/, "")
            print
            exit
        }
    ' "$desktop_path"
}

sanitize_exec() {
    sed -E 's/%[fFuUdDnNickvm]//g; s/%%/%/g; s/[[:space:]]+/ /g; s/^ //; s/ $//'
}

launch_desktop_id() {
    local desktop_id="$1"
    local desktop_path exec_line

    if ! desktop_path="$(desktop_path_for_id "$desktop_id")"; then
        printf '%s unresolved desktop id=%s\n' "$(date --iso-8601=seconds)" "$desktop_id" >> "$log"
        return 1
    fi

    exec_line="$(exec_line_from_desktop "$desktop_path" new-window || true)"
    if [[ -z "$exec_line" ]]; then
        exec_line="$(exec_line_from_desktop "$desktop_path")"
    fi

    exec_line="$(printf '%s\n' "$exec_line" | sanitize_exec)"
    printf '%s desktop=%s exec=%s\n' "$(date --iso-8601=seconds)" "$desktop_id" "$exec_line" >> "$log"
    [[ -n "$exec_line" ]] || return 1

    nohup sh -c "$exec_line" >/dev/null 2>&1 &
}

launchers="$(grep '^launchers=' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" | head -n 1 | cut -d= -f2-)"
IFS=',' read -ra app_array <<< "$launchers"
app_entry="${app_array[$slot]:-}"

printf '%s index=%s entry=%s\n' "$(date --iso-8601=seconds)" "$index" "$app_entry" >> "$log"
[[ -n "$app_entry" ]] || exit 1

desktop_id="$(desktop_id_from_entry "$app_entry")"
launch_desktop_id "$desktop_id"

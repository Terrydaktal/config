#!/usr/bin/env bash
set -euo pipefail

runtime="/run/user/1000"
export YDOTOOL_SOCKET="$runtime/.ydotool_socket"

lock="$runtime/copyq-ydotool-paste.lock"
exec 9>"$lock"

flock -n 9 || exit 0

# Cleanup any left-over keys instantly (key delay 0)
ydotool key --key-delay 0 29:0 97:0 42:0 54:0 56:0 100:0 125:0 126:0 110:0 47:0 || true

# Just a tiny 10ms breath to ensure the OS has hidden the CopyQ menu
sleep 0.01

# Fast Shift+Insert
ydotool key --key-delay 0 42:1 110:1 110:0 42:0

# Cleanup instantly
ydotool key --key-delay 0 110:0 42:0 54:0 29:0 97:0 56:0 100:0 125:0 126:0 47:0 || true

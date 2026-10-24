#!/usr/bin/env bash
# Verify paste routing without sending real keyboard events or starting services.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/bin" "$temporary/runtime"
ln -s "$here/test-tools/ydotool" "$temporary/bin/ydotool"
export PATH="$temporary/bin:$PATH" XDG_RUNTIME_DIR="$temporary/runtime"
export PASTE_TEST_RECORD="$temporary/keys"
export WAYLAND_MODIFIER_STATE_FILE="$temporary/absent"
bash "$here/copyq-wayland-paste.sh"
if ! rg -qx -- 'key --key-delay 0 29:1 47:1 47:0 29:0' "$PASTE_TEST_RECORD"; then
    printf 'FAIL: activation must send Ctrl+V, not Shift+Insert\n' >&2
    exit 1
fi
if rg -q -- '110:1|42:1|54:1' "$PASTE_TEST_RECORD"; then
    printf 'FAIL: paste must not press Insert or Shift\n' >&2
    exit 1
fi
export WAYLAND_MODIFIER_STATE_FILE="$here/test-tools/held-modifier.env"
set +e
bash "$here/copyq-wayland-paste.sh" 2>"$temporary/held-error"
status=$?
set -e
[[ $status -eq 5 ]]
[[ $(rg -c -- '29:1 47:1' "$PASTE_TEST_RECORD") -eq 1 ]]
printf 'PASS: Ctrl+V routing and held-modifier refusal (mock input only)\n'

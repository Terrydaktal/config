#!/usr/bin/env bash
# Verify paste routing without sending real keyboard events or starting services.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/bin" "$temporary/runtime"
ln -s "$here/test-tools/ydotool" "$temporary/bin/ydotool"
ln -s "$here/test-tools/kdotool" "$temporary/bin/kdotool"
export PATH="$temporary/bin:$PATH" XDG_RUNTIME_DIR="$temporary/runtime"
export PASTE_TEST_RECORD="$temporary/keys"
export PASTE_FOCUS_RECORD="$temporary/focus"
export PASTE_FOCUS_MODE=ready
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

export WAYLAND_MODIFIER_STATE_FILE="$temporary/absent"
mkdir -p "$temporary/service-bin" "$temporary/cargo-home/.cargo/bin" "$temporary/empty-home"
for tool in bash id flock timeout sleep wc; do
	ln -s "$(command -v "$tool")" "$temporary/service-bin/$tool"
done
ln -s "$here/test-tools/ydotool" "$temporary/service-bin/ydotool"
ln -s "$here/test-tools/kdotool" "$temporary/cargo-home/.cargo/bin/kdotool"
jq -er '
  if type == "array" and length > 0
     and all(.[]; (.id | type == "string") and (.mode | type == "string")
       and (.exit_code | type == "number") and (.pastes | type == "number")
       and (.focus_queries | type == "number"))
  then .[] | [.id, .mode, .exit_code, .pastes, .focus_queries] | @tsv
  else error("Invalid or empty paste-focus behavior inventory") end
' "$here/test-tools/paste-focus-cases.json" >"$temporary/cases.tsv"
while IFS=$'\t' read -r case_id mode expected_status expected_pastes expected_queries; do
	export PASTE_FOCUS_MODE="$mode"
	export WAYLAND_MODIFIER_STATE_FILE="$temporary/$mode-modifiers"
	: >"$PASTE_TEST_RECORD"
	: >"$PASTE_FOCUS_RECORD"
	paste_command=(timeout 4s bash "$here/copyq-wayland-paste.sh")
	case "$mode" in
	desktop-path)
		paste_command=(env "PATH=$temporary/service-bin" "HOME=$temporary/cargo-home" PASTE_FOCUS_MODE=ready "${paste_command[@]}")
		;;
	missing-tool)
		paste_command=(env "PATH=$temporary/service-bin" "HOME=$temporary/empty-home" PASTE_FOCUS_MODE=ready "${paste_command[@]}")
		;;
	esac
	set +e
	"${paste_command[@]}" 2>"$temporary/$mode-error"
	status=$?
	set -e
	pastes=$(rg -c -- '^key --key-delay 0 29:1 47:1 47:0 29:0$' "$PASTE_TEST_RECORD" || true)
	if [[ $status -ne $expected_status || ${pastes:-0} -ne $expected_pastes ]]; then
		printf 'FAIL: %s: expected status=%s/pastes=%s, got status=%s/pastes=%s\n' \
			"$case_id" "$expected_status" "$expected_pastes" "$status" "${pastes:-0}" >&2
		exit 1
	fi
	if ((expected_pastes > 0)) && ! rg -qx "focus-before-paste $expected_queries" "$PASTE_TEST_RECORD"; then
		printf 'FAIL: %s: Ctrl+V must wait until focus leaves CopyQ\n' "$case_id" >&2
		exit 1
	fi
	printf 'PASS: %s\n' "$case_id"
done <"$temporary/cases.tsv"

export PASTE_FOCUS_MODE=ready
: >"$PASTE_TEST_RECORD"
: >"$PASTE_FOCUS_RECORD"
(
	exec 8>"$XDG_RUNTIME_DIR/copyq-ydotool-paste.lock"
	flock 8
	bash "$here/copyq-wayland-paste.sh"
)
[[ ! -s "$PASTE_TEST_RECORD" && ! -s "$PASTE_FOCUS_RECORD" ]]
printf 'PASS: overlapping paste is ignored without sending input\n'

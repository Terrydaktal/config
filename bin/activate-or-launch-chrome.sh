#!/usr/bin/env bash
set -euo pipefail

kdotool=/home/lewis/.cargo/bin/kdotool
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

exec 9>"$runtime_dir/activate-or-launch-chrome.lock"
flock -n 9 || exit 0

chrome_windows=()

while IFS= read -r chrome_window; do
	[[ -n "$chrome_window" ]] || continue
	chrome_class="$(
		"$kdotool" getwindowclassname "$chrome_window" 2>/dev/null || true
	)"
	[[ "${chrome_class,,}" == google-chrome ]] || continue

	chrome_pid="$("$kdotool" getwindowpid "$chrome_window" 2>/dev/null || true)"
	[[ "$chrome_pid" =~ ^[0-9]+$ ]] || continue
	[[ -r "/proc/$chrome_pid/cmdline" ]] || continue
	if ! chrome_cmdline="$(tr '\0' ' ' <"/proc/$chrome_pid/cmdline" 2>/dev/null)"; then
		continue
	fi

	[[ "$chrome_cmdline" == /opt/google/chrome/chrome* ]] || continue
	[[ "$chrome_cmdline" != *" --type="* ]] || continue
	[[ "$chrome_cmdline" != *" --user-data-dir="* ]] || continue

	chrome_windows+=("$chrome_window")
done < <("$kdotool" search --classname chrome 2>/dev/null || true)

if ((${#chrome_windows[@]} > 0)); then
	active_window="$("$kdotool" getactivewindow 2>/dev/null || true)"
	target_window="${chrome_windows[-1]}"

	for chrome_index in "${!chrome_windows[@]}"; do
		[[ "${chrome_windows[$chrome_index]}" == "$active_window" ]] || continue
		next_index=$(((chrome_index + 1) % ${#chrome_windows[@]}))
		target_window="${chrome_windows[$next_index]}"
		break
	done

	flock -u 9
	exec "$kdotool" windowactivate "$target_window"
fi

flock -u 9
exec /home/lewis/.local/bin/google-chrome-fast

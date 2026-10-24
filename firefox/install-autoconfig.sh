#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
firefox_dir=${1:-/usr/lib/firefox}
pref_dir="$firefox_dir/defaults/pref"
files=(
	autoconfig/british-dictionary.js
	autoconfig/reverse-autoscroll.js
	autoscroll/ReverseAutoScrollChild.sys.mjs
	autoscroll/scroll-range.sys.mjs
	firefox-autoconfig.cfg
)

if [[ ! -f "$firefox_dir/application.ini" || ! -d "$pref_dir" ]]; then
	printf 'Not a Firefox installation: %s\n' "$firefox_dir" >&2
	exit 1
fi
for file in "${files[@]}" 99-firefox-autoconfig.js; do
	if [[ ! -r "$source_dir/$file" ]]; then
		printf 'Missing AutoConfig source: %s\n' "$source_dir/$file" >&2
		exit 1
	fi
done
for directory in "$firefox_dir/autoconfig" "$firefox_dir/autoscroll"; do
	if [[ -L "$directory" || (-e "$directory" && ! -d "$directory") ]]; then
		printf 'Refusing non-directory destination: %s\n' "$directory" >&2
		exit 1
	fi
done
for destination in "${files[@]/#/$firefox_dir/}" \
	"$pref_dir/99-firefox-autoconfig.js" \
	"$pref_dir/99-british-dictionary-autoconfig.js" \
	"$pref_dir/zz-applicationlauncher-audio-bridge.js" \
	"$firefox_dir/british-dictionary.cfg" \
	"$firefox_dir/british-dictionary.cfg.before-firefox-autoconfig"; do
	if [[ -L "$destination" || (-e "$destination" && ! -f "$destination") ]]; then
		printf 'Refusing non-regular destination: %s\n' "$destination" >&2
		exit 1
	fi
done

temporary=''
trap '[[ -z $temporary ]] || unlink "$temporary"' EXIT
atomic_install() {
	local source=$1 destination=$2 mode=${3:-644}
	temporary=$(mktemp "$destination.XXXXXXXX")
	install -m "$mode" "$source" "$temporary"
	mv -T "$temporary" "$destination"
	temporary=''
}

legacy_config="$firefox_dir/british-dictionary.cfg"
backup="$legacy_config.before-firefox-autoconfig"
if [[ -f "$legacy_config" && ! -e "$backup" ]]; then
	atomic_install "$legacy_config" "$backup" 600
fi
install -d -m755 "$firefox_dir/autoconfig" "$firefox_dir/autoscroll"
# Dependencies and the new entry point must exist before changing either selector.
for file in "${files[@]}"; do
	atomic_install "$source_dir/$file" "$firefox_dir/$file"
done
if [[ -f "$pref_dir/zz-applicationlauncher-audio-bridge.js" ]]; then
	atomic_install "$source_dir/99-firefox-autoconfig.js" \
		"$pref_dir/zz-applicationlauncher-audio-bridge.js"
fi
atomic_install "$source_dir/99-firefox-autoconfig.js" "$pref_dir/99-firefox-autoconfig.js"
for legacy in "$pref_dir/99-british-dictionary-autoconfig.js" "$legacy_config"; do
	if [[ -f "$legacy" ]]; then
		unlink "$legacy"
	fi
done
printf 'Installed shared Firefox AutoConfig in %s\n' "$firefox_dir"

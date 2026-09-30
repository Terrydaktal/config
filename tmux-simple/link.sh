#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
canonical="$repo_dir/tmux-simple/tmux.conf"
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
[[ $config_home == /* ]] || config_home="$HOME/.config"
sources=("$canonical" "$canonical" "$repo_dir/tmux-simple/tmux.fish")
targets=("$HOME/.tmux.conf" "$config_home/tmux-simple/tmux.conf" "$config_home/fish/functions/tmux.fish")

for index in "${!targets[@]}"; do
    source_path=${sources[index]}
    target=${targets[index]}
    [[ -f $source_path && ! -L $source_path ]] || {
        echo "Missing or unsafe configuration: $source_path" >&2
        exit 1
    }
    if [[ -e $target || -L $target ]]; then
        existing=$(readlink -m -- "$target")
        if [[ ! -L $target ]] || {
            [[ $existing != "$source_path" ]] &&
                [[ $target != "$HOME/.tmux.conf" ||
                    ($existing != "$repo_dir/tmux/tmux.conf" && $existing != "$repo_dir/legacy/tmux/tmux.conf") ]]
        }; then
            echo "Refusing to replace existing configuration: $target" >&2
            exit 1
        fi
    fi
done
for index in "${!targets[@]}"; do
    target=${targets[index]}
    mkdir -p -- "$(dirname -- "$target")"
    ln -sfn -- "${sources[index]}" "$target"
    echo "Linked: $target"
done

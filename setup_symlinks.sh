#!/usr/bin/env bash
set -euo pipefail

# Script to set up symlinks for configuration files tracked in ~/Dev/config

REPO_DIR="$HOME/Dev/config"

migrate_and_link() {
    local src="$1"
    local dest="$2"

    # Expand tilde
    src="${src/#\~/$HOME}"
    dest="${dest/#\~/$HOME}"

    # Ensure dest parent dir exists
    mkdir -p "$(dirname "$dest")"

    if [ -L "$src" ]; then
        local current_link
        current_link="$(readlink -f "$src")"
        if [ "$current_link" = "$dest" ]; then
            echo "✔ $src is already correctly symlinked to $dest"
            return 0
        else
            echo "⚠ $src is a symlink but points to $current_link instead of $dest"
            return 1
        fi
    fi

    if [ -f "$src" ]; then
        if [ -f "$dest" ]; then
            if cmp -s "$src" "$dest"; then
                echo "ℹ $src and $dest are identical. Symlinking..."
            else
                echo "⚠ $src and $dest differ. Updating repo version (git tracked)..."
                cp "$src" "$dest"
            fi
        else
            echo "➜ Moving $src to repo at $dest..."
            cp "$src" "$dest"
        fi
        
        # Backup original file
        mv "$src" "$src.bak"
        # Create symlink
        ln -s "$dest" "$src"
        echo "✔ Linked $src -> $dest"
    elif [ -f "$dest" ]; then
        # Restore mode: dest exists but src doesn't
        echo "➜ Restoring symlink for $src -> $dest"
        mkdir -p "$(dirname "$src")"
        ln -s "$dest" "$src"
        echo "✔ Linked $src -> $dest"
    else
        echo "✗ Neither $src nor $dest exists"
    fi
}

echo "=== 1. Disabling and removing redundant xremap configs/services ==="
redundant_services=(
    "xremap-keyboard.service"
    "xremap-wheel.service"
)
for svc in "${redundant_services[@]}"; do
    if systemctl --user is-enabled "$svc" &>/dev/null; then
        echo "Stopping and disabling $svc..."
        systemctl --user stop "$svc" || true
        systemctl --user disable "$svc" || true
    fi
done

redundant_files=(
    "~/.config/systemd/user/xremap-keyboard.service"
    "~/.config/systemd/user/xremap-wheel.service"
    "~/.config/systemd/user/launch-taskbar-app@.service"
    "~/.config/xremap/keyboard.yml"
    "~/.config/xremap/config.yml"
    "~/.config/xremap/test_config.yml"
)
for f in "${redundant_files[@]}"; do
    f_expanded="${f/#\~/$HOME}"
    if [ -f "$f_expanded" ] || [ -L "$f_expanded" ]; then
        echo "Deleting redundant file/symlink: $f"
        rm -f "$f_expanded"
    fi
done

echo -e "\n=== 2. Migrating and symlinking configuration files ==="

# KDE configs
migrate_and_link "~/.config/kglobalshortcutsrc" "$REPO_DIR/kde/kglobalshortcutsrc"
migrate_and_link "~/.config/kdeglobals" "$REPO_DIR/kde/kdeglobals"
migrate_and_link "~/.config/kwinrc" "$REPO_DIR/kde/kwinrc"
migrate_and_link "~/.config/kwinrulesrc" "$REPO_DIR/kde/kwinrulesrc"
migrate_and_link "~/.config/kcminputrc" "$REPO_DIR/kde/kcminputrc"
migrate_and_link "~/.config/plasma-localerc" "$REPO_DIR/kde/plasma-localerc"
migrate_and_link "~/.config/kxkbrc" "$REPO_DIR/kde/kxkbrc"
migrate_and_link "~/.config/powerdevilrc" "$REPO_DIR/kde/powerdevilrc"
migrate_and_link "~/.config/powermanagementprofilesrc" "$REPO_DIR/kde/powermanagementprofilesrc"
migrate_and_link "~/.config/plasmashellrc" "$REPO_DIR/kde/plasmashellrc"
migrate_and_link "~/.config/plasma-org.kde.plasma.desktop-appletsrc" "$REPO_DIR/kde/plasma-org.kde.plasma.desktop-appletsrc"
migrate_and_link "~/.config/baloofilerc" "$REPO_DIR/kde/baloofilerc"
migrate_and_link "~/.config/mimeapps.list" "$REPO_DIR/kde/mimeapps.list"

# PCManFM and LibFM configs
migrate_and_link "~/.config/pcmanfm/default/pcmanfm.conf" "$REPO_DIR/pcmanfm/pcmanfm.conf"
migrate_and_link "~/.config/libfm/libfm.conf" "$REPO_DIR/pcmanfm/libfm.conf"

# Application Launcher configs
migrate_and_link "~/.config/applicationlauncher/pinned_apps.txt" "$REPO_DIR/applicationlauncher/pinned_apps.txt"
migrate_and_link "~/.config/applicationlauncher/settings.txt" "$REPO_DIR/applicationlauncher/settings.txt"
migrate_and_link "~/.config/applicationlauncher/window_size.txt" "$REPO_DIR/applicationlauncher/window_size.txt"

# Git config
migrate_and_link "~/.gitconfig" "$REPO_DIR/git/gitconfig"

# CopyQ autostart
migrate_and_link "~/.config/autostart/com.github.hluk.copyq.desktop" "$REPO_DIR/autostart/com.github.hluk.copyq.desktop"

# Systemd user units (already in repo)
migrate_and_link "~/.config/systemd/user/wayland-scroll-daemon.service" "$REPO_DIR/systemd/user/wayland-scroll-daemon.service"
migrate_and_link "~/.config/systemd/user/xremap-meta-keyboard.service" "$REPO_DIR/systemd/user/xremap-meta-keyboard.service"

# New systemd user unit & helper script
migrate_and_link "~/.config/systemd/user/kde-refresh-powerdevil-after-lock.service" "$REPO_DIR/systemd/user/kde-refresh-powerdevil-after-lock.service"
migrate_and_link "~/.local/bin/kde-refresh-powerdevil-after-lock" "$REPO_DIR/systemd/user/kde-refresh-powerdevil-after-lock"

echo -e "\n=== 3. Tracking system files (Copy Only) ==="
# Track NetworkManager connectivity check config
mkdir -p "$REPO_DIR/etc/NetworkManager/conf.d"
if [ -f "/etc/NetworkManager/conf.d/20-connectivity.conf" ]; then
    cp "/etc/NetworkManager/conf.d/20-connectivity.conf" "$REPO_DIR/etc/NetworkManager/conf.d/20-connectivity.conf"
    echo "✔ Copied /etc/NetworkManager/conf.d/20-connectivity.conf to repo"
else
    echo "⚠ /etc/NetworkManager/conf.d/20-connectivity.conf not found"
fi

# Track custom modprobe configs (like sensor aliases)
mkdir -p "$REPO_DIR/etc/modprobe.d"
if [ -f "/etc/modprobe.d/nct6687-alias.conf" ]; then
    cp "/etc/modprobe.d/nct6687-alias.conf" "$REPO_DIR/etc/modprobe.d/nct6687-alias.conf"
    echo "✔ Copied /etc/modprobe.d/nct6687-alias.conf to repo"
else
    echo "⚠ /etc/modprobe.d/nct6687-alias.conf not found"
fi

# Track custom udev rules
mkdir -p "$REPO_DIR/etc/udev/rules.d"
udev_rules=(
    "99-hdd-scheduler.rules"
    "99-xremap.rules"
)
for rule in "${udev_rules[@]}"; do
    if [ -f "/etc/udev/rules.d/$rule" ]; then
        cp "/etc/udev/rules.d/$rule" "$REPO_DIR/etc/udev/rules.d/$rule"
        echo "✔ Copied udev rule $rule to repo"
    else
        echo "⚠ udev rule $rule not found"
    fi
done

# Track custom systemd system services
mkdir -p "$REPO_DIR/etc/systemd/system"
if [ -f "/etc/systemd/system/nvidia-power-limit.service" ]; then
    cp "/etc/systemd/system/nvidia-power-limit.service" "$REPO_DIR/etc/systemd/system/nvidia-power-limit.service"
    echo "✔ Copied /etc/systemd/system/nvidia-power-limit.service to repo"
else
    echo "⚠ /etc/systemd/system/nvidia-power-limit.service not found"
fi

echo -e "\n=== 4. Reloading systemd user manager ==="
systemctl --user daemon-reload
echo "✔ Reloaded systemd user daemon"

echo -e "\n★ Migration complete! Please verify with 'git status' in ~/Dev/config."

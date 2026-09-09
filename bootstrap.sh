#!/usr/bin/env bash
set -euo pipefail

# Quoted ~/ paths are intentional inputs to migrate_and_link(), which expands
# them only after accepting the complete path as one argument.
# shellcheck disable=SC2088

# Bootstrap script to set up symlinks and enable/start systemd services

REPO_DIR="$HOME/Dev/config"
ssh_machine_role=managed-target

usage() {
	cat <<'EOF'
NAME
    bootstrap.sh - restore the tracked CachyOS workstation configuration

SYNOPSIS
    bootstrap.sh [--role managed-target|peer-workstation]
    bootstrap.sh --help

DESCRIPTION
    Restores the repository-owned user and system configuration. Every role
    installs the same key-only SSH daemon policy and authorized management keys.
    The role controls only whether this machine receives an outgoing SSH client
    identity.

OPTIONS
    --role ROLE
        managed-target is the default and creates no outgoing private key.
        peer-workstation generates ~/.ssh/id_ed25519 when no client key exists.
    -h, --help
        Display this help text.

OPERATION
    managed-target authorizes the repository's management public keys and leaves
    any existing client private key untouched. peer-workstation does the same,
    then creates a unique Ed25519 client key pair if both standard key paths are
    absent. Existing keys are validated and never replaced.

EXAMPLES
    ./bootstrap.sh
    ./bootstrap.sh --role managed-target
    ./bootstrap.sh --role peer-workstation

FILES
    ~/Dev/config/ssh/authorized_keys
        Canonical public keys accepted for incoming administration.
    ~/Dev/config/etc/ssh/sshd_config.d/99-security.conf
        Canonical SSH daemon policy.

PATHS
    ~/.ssh/id_ed25519
        Machine-local outgoing private key used only by peer-workstation.
    ~/.ssh/id_ed25519.pub
        Public enrollment key printed when peer-workstation completes.

SECURITY NOTES
    Private keys are never read into the repository, copied from another machine,
    or overwritten. Newly generated unattended client keys have no passphrase;
    protect the user account and ~/.ssh permissions accordingly.

EXIT STATUS
    0 on success; non-zero for invalid arguments, unsafe key state, failed
    validation, or an incomplete bootstrap operation.

AUTHORS
    Terrydaktal and OpenAI Codex.
EOF
}

fail() {
	printf 'bootstrap: %s\n' "$*" >&2
	exit 1
}

while (($#)); do
	case $1 in
	--role)
		(($# >= 2)) || fail '--role requires managed-target or peer-workstation'
		ssh_machine_role=$2
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*) fail "unknown argument: $1" ;;
	esac
done

case $ssh_machine_role in
managed-target | peer-workstation) ;;
*) fail "invalid role: $ssh_machine_role" ;;
esac
readonly ssh_machine_role

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

link_authorized_keys() {
	local authorized_keys="$HOME/.ssh/authorized_keys"
	local canonical_keys="$REPO_DIR/ssh/authorized_keys"
	local backup

	if [ ! -f "$canonical_keys" ] || [ -L "$canonical_keys" ]; then
		echo "✗ Canonical authorized_keys is missing or unsafe: $canonical_keys" >&2
		return 1
	fi
	if ! ssh-keygen -lf "$canonical_keys" >/dev/null; then
		echo "✗ Canonical authorized_keys is invalid: $canonical_keys" >&2
		return 1
	fi

	mkdir -p "$HOME/.ssh"
	chmod 0700 "$HOME/.ssh"
	chmod 0600 "$canonical_keys"

	if [ -L "$authorized_keys" ]; then
		if [ "$(readlink -f "$authorized_keys")" = "$canonical_keys" ]; then
			echo "✔ $authorized_keys is already linked to the canonical key list"
			return 0
		fi
		echo "✗ $authorized_keys points to an unexpected location" >&2
		return 1
	fi

	if [ -e "$authorized_keys" ]; then
		if [ ! -f "$authorized_keys" ]; then
			echo "✗ $authorized_keys is not a regular file" >&2
			return 1
		fi
		backup="${authorized_keys}.bak.$(date +%Y%m%dT%H%M%S)"
		if [ -e "$backup" ]; then
			echo "✗ Refusing to replace existing backup: $backup" >&2
			return 1
		fi
		mv "$authorized_keys" "$backup"
		echo "✔ Preserved the previous authorized_keys at $backup"
	fi

	ln -s "$canonical_keys" "$authorized_keys"
	echo "✔ Linked $authorized_keys -> $canonical_keys"
}

link_ssh_client_config() {
	local client_config="$HOME/.ssh/config"
	local canonical_config="$REPO_DIR/ssh/config"
	local backup

	if [ ! -f "$canonical_config" ] || [ -L "$canonical_config" ]; then
		echo "✗ Canonical SSH client config is missing or unsafe: $canonical_config" >&2
		return 1
	fi
	if ! ssh -G -F "$canonical_config" ai >/dev/null; then
		echo "✗ Canonical SSH client config is invalid: $canonical_config" >&2
		return 1
	fi

	mkdir -p "$HOME/.ssh"
	chmod 0700 "$HOME/.ssh"
	chmod 0600 "$canonical_config"

	if [ -L "$client_config" ]; then
		if [ "$(readlink -f "$client_config")" = "$canonical_config" ]; then
			echo "✔ $client_config is already linked to the canonical client config"
			return 0
		fi
		echo "✗ $client_config points to an unexpected location" >&2
		return 1
	fi

	if [ -e "$client_config" ]; then
		if [ ! -f "$client_config" ]; then
			echo "✗ $client_config is not a regular file" >&2
			return 1
		fi
		backup="${client_config}.bak.$(date +%Y%m%dT%H%M%S)"
		if [ -e "$backup" ]; then
			echo "✗ Refusing to replace existing backup: $backup" >&2
			return 1
		fi
		mv "$client_config" "$backup"
		echo "✔ Preserved the previous SSH client config at $backup"
	fi

	ln -s "$canonical_config" "$client_config"
	echo "✔ Linked $client_config -> $canonical_config"
}

configure_outgoing_ssh_identity() {
	local role=$1
	local private_key="$HOME/.ssh/id_ed25519"
	local public_key="${private_key}.pub"
	local private_fingerprint
	local public_fingerprint

	mkdir -p "$HOME/.ssh"
	chmod 0700 "$HOME/.ssh"

	if [ "$role" = managed-target ]; then
		if [ -e "$private_key" ] || [ -e "$public_key" ]; then
			echo "ℹ managed-target: preserving the existing outgoing SSH identity"
		else
			echo "✔ managed-target: no outgoing SSH identity was generated"
		fi
		return 0
	fi

	command -v ssh-keygen >/dev/null 2>&1 || {
		echo "✗ ssh-keygen is required for the peer-workstation role" >&2
		return 1
	}

	if [ -L "$private_key" ] || [ -L "$public_key" ]; then
		echo "✗ Refusing to use a symlink as a peer-workstation SSH identity" >&2
		return 1
	fi
	if [ ! -e "$private_key" ] && [ -e "$public_key" ]; then
		echo "✗ $public_key exists without its private key; refusing to overwrite it" >&2
		return 1
	fi
	if [ -e "$private_key" ] && [ ! -e "$public_key" ]; then
		echo "✗ $private_key exists without $public_key; refusing unattended key repair" >&2
		return 1
	fi

	if [ ! -e "$private_key" ]; then
		(
			umask 077
			ssh-keygen -q -t ed25519 -a 100 -N '' \
				-C "$(id -un)@$(hostname)-peer-workstation" -f "$private_key"
		)
		echo "✔ Generated a unique peer-workstation SSH client identity"
	else
		echo "✔ Preserving the existing peer-workstation SSH client identity"
	fi

	[ -f "$private_key" ] && [ -f "$public_key" ] || {
		echo "✗ Peer-workstation SSH identity is incomplete" >&2
		return 1
	}
	chmod 0600 "$private_key"
	chmod 0644 "$public_key"
	private_fingerprint=$(ssh-keygen -lf "$private_key" | awk 'NR == 1 { print $2 }')
	public_fingerprint=$(ssh-keygen -lf "$public_key" | awk 'NR == 1 { print $2 }')
	if [ -z "$private_fingerprint" ] || [ "$private_fingerprint" != "$public_fingerprint" ]; then
		echo "✗ Peer-workstation private and public keys do not match" >&2
		return 1
	fi

	printf '✔ Peer-workstation enrollment fingerprint: %s\n' "$public_fingerprint"
	printf 'PEER_WORKSTATION_SSH_PUBLIC_KEY='
	cat "$public_key"
}

configure_system() {
	local bootstrap_user
	local required_source
	local -a required_sources=(
		"$REPO_DIR/etc/iw-regdomain"
		"$REPO_DIR/etc/modprobe.d/cfg80211-regdom.conf"
		"$REPO_DIR/etc/mkinitcpio.conf.d/20-wireless-regdb.conf"
		"$REPO_DIR/etc/ssh/sshd_config.d/99-security.conf"
		"$REPO_DIR/firefox/99-british-dictionary-autoconfig.js"
		"$REPO_DIR/firefox/british-dictionary.cfg"
		"$REPO_DIR/packages/asrock-nct6683-dkms-git/PKGBUILD"
		"$REPO_DIR/packages/asrock-nct6683-dkms-git/verify-dkms"
		"$REPO_DIR/packages/asrock-nct6683-dkms-git/75-asrock-nct6683-dkms.hook"
		"$REPO_DIR/packages/asrock-nct6683-dkms-git/asrock-nct6683.modules-load"
		"$REPO_DIR/packages/asrock-nct6683-dkms-git/asrock-nct6683.modprobe"
	)

	command -v pkexec >/dev/null 2>&1 || {
		echo "✗ pkexec is required for system configuration" >&2
		return 1
	}

	for required_source in "${required_sources[@]}"; do
		if [ ! -r "$required_source" ]; then
			echo "✗ Required repository source is missing: $required_source" >&2
			return 1
		fi
	done

	bootstrap_user="$(id -un)"
	pkexec bash -c '
set -euo pipefail

repo_dir=$1
bootstrap_user=$2
package_dir="$repo_dir/packages/asrock-nct6683-dkms-git"
sshd_policy_source="$repo_dir/etc/ssh/sshd_config.d/99-security.conf"
sshd_policy_target=/etc/ssh/sshd_config.d/99-security.conf
legacy_installer_policy=/etc/ssh/sshd_config.d/20-cachyos-remote-admin.conf

command -v sshd >/dev/null 2>&1 || {
    echo "OpenSSH server is required before applying the SSH policy" >&2
    exit 1
}
sshd -t -f "$sshd_policy_source"
install -Dm644 "$sshd_policy_source" "$sshd_policy_target"
if [[ -f $legacy_installer_policy ]] && cmp -s "$legacy_installer_policy" <(
    printf "%s\n" \
        "PermitRootLogin prohibit-password" \
        "PasswordAuthentication no" \
        "KbdInteractiveAuthentication no" \
        "PubkeyAuthentication yes"
); then
    rm -f "$legacy_installer_policy"
fi
sshd -t

install -Dm644 "$repo_dir/etc/iw-regdomain" /etc/iw-regdomain
install -Dm644 "$repo_dir/etc/modprobe.d/cfg80211-regdom.conf" \
    /etc/modprobe.d/cfg80211-regdom.conf
install -Dm644 "$repo_dir/etc/mkinitcpio.conf.d/20-wireless-regdb.conf" \
    /etc/mkinitcpio.conf.d/20-wireless-regdb.conf
rm -f /etc/modprobe.d/nct6687-alias.conf
pacman -S --needed --noconfirm wireless-regdb hunspell-en_gb

install -Dm644 "$repo_dir/firefox/99-british-dictionary-autoconfig.js" \
    /usr/lib/firefox/defaults/pref/99-british-dictionary-autoconfig.js
install -Dm644 "$repo_dir/firefox/british-dictionary.cfg" \
    /usr/lib/firefox/british-dictionary.cfg

# Firefox gives a page language an exact-match priority over the preferred
# dictionary. AutoConfig removes the bundled en-US entry, while this directory
# exposes only en-GB-large for all page editors.
firefox_dictionary_dir=/usr/local/share/firefox-dictionaries
install -d -m 0755 "$firefox_dictionary_dir"
find "$firefox_dictionary_dir" -mindepth 1 -maxdepth 1 -delete
ln -s /usr/share/hunspell/en_GB-large.aff "$firefox_dictionary_dir/en_GB-large.aff"
ln -s /usr/share/hunspell/en_GB-large.dic "$firefox_dictionary_dir/en_GB-large.dic"

# Remove aliases created by the previous workaround without deleting files
# owned by a real en-US dictionary package.
for suffix in aff dic; do
    legacy_hunspell_alias="/usr/share/hunspell/en_US.$suffix"
    if [[ -L $legacy_hunspell_alias &&
          $(readlink -f "$legacy_hunspell_alias") == "/usr/share/hunspell/en_GB-large.$suffix" ]]; then
        rm -f "$legacy_hunspell_alias"
    fi

    legacy_myspell_alias="/usr/share/myspell/dicts/en_US.$suffix"
    if [[ -L $legacy_myspell_alias ]]; then
        legacy_target=$(readlink "$legacy_myspell_alias")
        if [[ $legacy_target == "/usr/share/hunspell/en_US.$suffix" ||
              $legacy_target == "/usr/share/hunspell/en_GB-large.$suffix" ]]; then
            rm -f "$legacy_myspell_alias"
        fi
    fi
done

nct_package=asrock-nct6683-dkms-git
nct_install_required=0
if ! pacman -Qq "$nct_package" >/dev/null 2>&1; then
    nct_install_required=1
else
    for package_file in \
        /usr/lib/modules-load.d/asrock-nct6683.conf \
        /usr/lib/modprobe.d/asrock-nct6683.conf \
        /usr/lib/asrock-nct6683/verify-dkms; do
        if [[ $(pacman -Qqo "$package_file" 2>/dev/null || true) != "$nct_package" ]]; then
            nct_install_required=1
        fi
    done
fi

if ((nct_install_required)); then
    build_dependencies=(base-devel git dkms linux-cachyos-headers wireless-regdb)
    if pacman -Qq linux-cachyos-lts >/dev/null 2>&1; then
        build_dependencies+=(linux-cachyos-lts-headers)
    fi
    pacman -S --needed --noconfirm "${build_dependencies[@]}"

    bootstrap_home=$(getent passwd "$bootstrap_user" | cut -d: -f6)
    [[ -n $bootstrap_home ]] || {
        echo "Could not determine home directory for $bootstrap_user" >&2
        exit 1
    }
    runuser -u "$bootstrap_user" -- env HOME="$bootstrap_home" \
        bash -c '\''
set -euo pipefail
cd "$1"
makepkg --cleanbuild --clean --force --noconfirm
'\'' bash "$package_dir"
    package_path=$(runuser -u "$bootstrap_user" -- env HOME="$bootstrap_home" \
        bash -c '\''cd "$1" && makepkg --packagelist | tail -n 1'\'' bash "$package_dir")
    [[ -r $package_path ]] || {
        echo "Built NCT6683 package was not found: $package_path" >&2
        exit 1
    }
    pacman -U --noconfirm "$package_path"
fi

/usr/lib/asrock-nct6683/verify-dkms
mkinitcpio -P

enable_system_unit() {
    local unit=$1 mode=$2
    systemctl cat "$unit" >/dev/null 2>&1 || return 0
    if [[ $mode == now ]]; then
        systemctl enable --now "$unit"
    else
        systemctl enable "$unit"
    fi
}

enable_system_unit systemd-timesyncd.service now
enable_system_unit nvidia-power-limit.service enable
enable_system_unit ufw.service now
enable_system_unit sshd.service now
systemctl reload sshd.service
' bash "$REPO_DIR" "$bootstrap_user"
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

# Import environment autostart
migrate_and_link "~/.config/autostart/import-environment.desktop" "$REPO_DIR/autostart/import-environment.desktop"

# Session environment
migrate_and_link "~/.config/environment.d/90-nvidia-vaapi.conf" "$REPO_DIR/environment.d/90-nvidia-vaapi.conf"

# Mousepad desktop override launcher
migrate_and_link "~/.local/share/applications/org.xfce.mousepad.desktop" "$REPO_DIR/applications/org.xfce.mousepad.desktop"

# Chrome launcher wrapper
migrate_and_link "~/.local/bin/google-chrome-fast" "$REPO_DIR/bin/google-chrome-fast"
migrate_and_link "~/.config/chrome-flags.conf" "$REPO_DIR/chrome/chrome-flags.conf"

# Systemd user units (already in repo)
migrate_and_link "~/.config/systemd/user/wayland-scroll-daemon.service" "$REPO_DIR/systemd/user/wayland-scroll-daemon.service"
migrate_and_link "~/.config/systemd/user/xremap-meta-keyboard.service" "$REPO_DIR/systemd/user/xremap-meta-keyboard.service"
migrate_and_link "~/.config/systemd/user/krfb-tunnel.service" "$REPO_DIR/systemd/user/krfb-tunnel.service"
migrate_and_link "~/.config/systemd/user/copyq-window-toggle-loader.service" "$REPO_DIR/systemd/user/copyq-window-toggle-loader.service"
migrate_and_link "~/.config/systemd/user/copyq-show-window.service" "$REPO_DIR/systemd/user/copyq-show-window.service"

# New systemd user unit & helper script
migrate_and_link "~/.config/systemd/user/kde-refresh-powerdevil-after-lock.service" "$REPO_DIR/systemd/user/kde-refresh-powerdevil-after-lock.service"
migrate_and_link "~/.local/bin/kde-refresh-powerdevil-after-lock" "$REPO_DIR/systemd/user/kde-refresh-powerdevil-after-lock"

# SSH user configs
link_ssh_client_config
link_authorized_keys
configure_outgoing_ssh_identity "$ssh_machine_role"

# Firefox user.js
# profiles.ini has a random prefix per installation (e.g. nbw40052.default-release).
# We read the Default= key from the [Install*] section (set when Firefox first runs)
# and fall back to Path= from [Profile0] for fresh installs that lack [Install*].
FIREFOX_PROFILES_DIR="$HOME/.config/mozilla/firefox"
if [ -f "$FIREFOX_PROFILES_DIR/profiles.ini" ]; then
	FF_PROFILE=$(awk -F= '
        /^\[Install/       { in_install=1 }
        /^\[/              { if (!in_install) in_install=0 }
        in_install && /^Default=/ { print $2; found=1; exit }
        END { if (!found) { } }
    ' "$FIREFOX_PROFILES_DIR/profiles.ini")
	# Fallback: read Path= from [Profile0] for fresh installs
	if [ -z "$FF_PROFILE" ]; then
		FF_PROFILE=$(awk -F= '/^Path=/ { print $2; exit }' "$FIREFOX_PROFILES_DIR/profiles.ini")
	fi
	if [ -n "$FF_PROFILE" ]; then
		migrate_and_link "$FIREFOX_PROFILES_DIR/$FF_PROFILE/user.js" "$REPO_DIR/firefox/user.js"

		# Remove profile dictionary copies created by the superseded workaround.
		# Firefox now reads the dedicated system directory configured in user.js.
		legacy_dictionary_dir="$FIREFOX_PROFILES_DIR/$FF_PROFILE/dictionaries"
		for dict in en-GB en_GB en-GB-large en_GB-large en-US en_US; do
			for suffix in aff dic; do
				legacy_dictionary="$legacy_dictionary_dir/$dict.$suffix"
				system_dictionary="/usr/share/hunspell/en_GB-large.$suffix"
				if [ -f "$legacy_dictionary" ] && [ -f "$system_dictionary" ] && cmp -s "$legacy_dictionary" "$system_dictionary"; then
					rm -f "$legacy_dictionary"
				fi
			done
		done
		rmdir "$legacy_dictionary_dir" 2>/dev/null || true
	else
		echo "⚠ Could not determine Firefox default profile from profiles.ini"
	fi
else
	echo "⚠ Firefox profiles.ini not found, skipping user.js symlink"
fi

echo -e "\n=== 3. Tracking system files (Copy Only) ==="
# Track NetworkManager connectivity check config
mkdir -p "$REPO_DIR/etc/NetworkManager/conf.d"
if [ -f "/etc/NetworkManager/conf.d/20-connectivity.conf" ]; then
	cp "/etc/NetworkManager/conf.d/20-connectivity.conf" "$REPO_DIR/etc/NetworkManager/conf.d/20-connectivity.conf"
	echo "✔ Copied /etc/NetworkManager/conf.d/20-connectivity.conf to repo"
else
	echo "⚠ /etc/NetworkManager/conf.d/20-connectivity.conf not found"
fi

# Track early wireless regulatory configuration. On a fresh installation the
# repository copies are preserved here and restored by configure_system().
system_config_files=(
	"/etc/iw-regdomain:etc/iw-regdomain"
	"/etc/modprobe.d/cfg80211-regdom.conf:etc/modprobe.d/cfg80211-regdom.conf"
	"/etc/mkinitcpio.conf.d/20-wireless-regdb.conf:etc/mkinitcpio.conf.d/20-wireless-regdb.conf"
)
for system_config in "${system_config_files[@]}"; do
	IFS=: read -r system_path repo_path <<<"$system_config"
	if [ -f "$REPO_DIR/$repo_path" ]; then
		if [ -f "$system_path" ] && cmp -s "$system_path" "$REPO_DIR/$repo_path"; then
			echo "✔ $system_path matches the repository"
		else
			echo "ℹ $system_path will be restored from the repository"
		fi
	elif [ -f "$system_path" ]; then
		mkdir -p "$(dirname "$REPO_DIR/$repo_path")"
		cp "$system_path" "$REPO_DIR/$repo_path"
		echo "✔ Copied $system_path to repo"
	else
		echo "✗ Neither $system_path nor $REPO_DIR/$repo_path exists" >&2
		exit 1
	fi
done

# Track custom udev rules
mkdir -p "$REPO_DIR/etc/udev/rules.d"
udev_rules=(
	"99-hdd-scheduler.rules"
	"99-xremap.rules"
	"99-kwin-reinit-on-hotplug.rules"
	"99-rapl.rules"
)
for rule in "${udev_rules[@]}"; do
	if [ -f "/etc/udev/rules.d/$rule" ]; then
		cp "/etc/udev/rules.d/$rule" "$REPO_DIR/etc/udev/rules.d/$rule"
		echo "✔ Copied udev rule $rule to repo"
	else
		echo "⚠ udev rule $rule not found"
	fi
done

# Track the helper used by the identity-aware KWin hotplug rule
if [ -f "/usr/local/bin/kwin-monitor-change-reinit" ]; then
	cp "/usr/local/bin/kwin-monitor-change-reinit" "$REPO_DIR/etc/udev/kwin-monitor-change-reinit"
	chmod 0755 "$REPO_DIR/etc/udev/kwin-monitor-change-reinit"
	echo "✔ Copied KWin monitor-change helper to repo"
else
	echo "⚠ /usr/local/bin/kwin-monitor-change-reinit not found"
fi

# Track custom systemd system services
mkdir -p "$REPO_DIR/etc/systemd/system"
if [ -f "/etc/systemd/system/nvidia-power-limit.service" ]; then
	cp "/etc/systemd/system/nvidia-power-limit.service" "$REPO_DIR/etc/systemd/system/nvidia-power-limit.service"
	echo "✔ Copied /etc/systemd/system/nvidia-power-limit.service to repo"
else
	echo "⚠ /etc/systemd/system/nvidia-power-limit.service not found"
fi

# Track custom UFW configuration
mkdir -p "$REPO_DIR/etc/ufw"
ufw_files=(
	"ufw.conf"
	"user.rules"
	"user6.rules"
)
for f in "${ufw_files[@]}"; do
	if [ -f "/etc/ufw/$f" ]; then
		cp "/etc/ufw/$f" "$REPO_DIR/etc/ufw/$f"
		echo "✔ Copied /etc/ufw/$f to repo"
	else
		echo "⚠ /etc/ufw/$f not found"
	fi
done

# Verify the repository-owned SSH daemon configuration. configure_system()
# restores this file after the non-privileged tracking phase.
sshd_policy=/etc/ssh/sshd_config.d/99-security.conf
if [ -f "$sshd_policy" ] && cmp -s "$sshd_policy" "$REPO_DIR/etc/ssh/sshd_config.d/99-security.conf"; then
	echo "✔ $sshd_policy matches the repository"
else
	echo "ℹ $sshd_policy will be restored from the repository"
fi

echo -e "\n=== 4. Reloading systemd user manager ==="
systemctl --user daemon-reload
echo "✔ Reloaded systemd user daemon"

echo -e "\n=== 5. Enabling systemd user services ==="
for svc in wayland-scroll-daemon.service xremap-meta-keyboard.service copyq-window-toggle-loader.service kde-refresh-powerdevil-after-lock.service krfb-tunnel.service ydotool.service; do
	if systemctl --user is-enabled "$svc" &>/dev/null; then
		echo "✔ User service is already enabled: $svc"
	elif systemctl --user list-unit-files "$svc" &>/dev/null; then
		echo "Enabling user service: $svc"
		systemctl --user enable "$svc"
	else
		echo "⚠ User service not found, skipping: $svc"
	fi
done

echo -e "\n=== 6. Enabling systemd system services ==="
echo "Administrator authentication will restore system configuration, verify fan-control DKMS, rebuild initramfs images, and enable available system services."
configure_system
echo "✔ System configuration restored and verified"

echo -e "\n★ Bootstrap complete (SSH role: $ssh_machine_role)! Please verify with 'git status' in ~/Dev/config."

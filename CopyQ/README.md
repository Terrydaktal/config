# CopyQ Wayland Paste Configuration

This directory contains the configuration and scripts to enable reliable, fast pasting for CopyQ on KDE Plasma Wayland (tested on CachyOS).

## Prerequisites

1. **ydotool**: Install it and ensure the user service is running.
   ```bash
   sudo pacman -S ydotool
   systemctl --user enable --now ydotool
   ```
2. **User Groups**: Your user must be in the "input" group.
   ```bash
   sudo usermod -aG input YOUR_USERNAME
   ```
   *(Requires logout/login to take effect)*

## Structure

- scripts/copyq-wayland-paste.sh: A bash helper that uses ydotool to simulate Shift+Insert. It uses flock to prevent multiple pastes/loops and has minimal delays for high performance.
- copyq_script_override.js: The JavaScript code to be added to CopyQ's command list.

## Setup Instructions

1. **Enable Native Paste in CopyQ**:
   - Open CopyQ Preferences.
   - Go to History tab.
   - Check "Paste to current window".

2. **Add the Script Override**:
   - Open CopyQ and press F6 to open Commands.
   - Click "Add" -> "New Command".
   - Set Name to "Wayland Paste Hijack".
   - Set Type of Action to "Script".
   - Copy the contents of copyq_script_override.js into the script box.
   - Ensure the "helper" variable in the script points to the absolute path of copyq-wayland-paste.sh.

3. **Verify**:
   - Highlight an item in CopyQ.
   - Press Enter.
   - It should paste instantly into your focused window.

## Troubleshooting

- **Delay too fast?**: If it pastes before the window focuses, add a small sleep(20) or sleep(50) to the global.paste function in copyq_script_override.js before runPasteWithYdotool().
- **Permission Denied?**: Ensure ydotoold is running and you are in the input group.

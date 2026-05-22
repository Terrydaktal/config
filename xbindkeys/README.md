# Wayland Window Management (KDE Plasma 6)

This directory contains a suite of scripts designed to replicate and extend the functionality of `xbindkeys` on Wayland. Since Wayland (and specifically KWin) restricts global input capture for security, these scripts operate at the kernel level (`evdev`) to provide a zero-lag, stutter-free experience even with high-performance gaming mice.

## The Architecture

The system consists of a single **Unified Python Daemon** that acts as the "brain," and several specialized **Action Scripts** that perform the actual window manipulations.

### 1. The Daemon (`wayland_scroll_daemon.py`)
This is the core background process. It performs the following roles:
*   **Keyboard Tracking**: Waits for `xremap normalized keyboard` and watches it for shortcut modifiers (`Ctrl`, `Meta`, `Shift`). The raw `Meta` endpoint can move between `/dev/input/event*` numbers after hotplug, but xremap opens it through the stable `/dev/input/by-id/usb-04d9_USB_Gaming_Mouse-if01-event-kbd` symlink.
*   **Dynamic Mouse Grab**: To preserve 1000Hz gaming mouse performance, it only "grabs" the mouse when a modifier key (`Meta` or `Shift`) is held down and no physical mouse button is already pressed. Clicks that start before the modifier are left on the normal compositor path.
*   **Stable Mouse Selection**: Opens the real wheel/button endpoint through `/dev/input/by-id/usb-04d9_USB_Gaming_Mouse-event-mouse`, so it does not matter whether the kernel assigns the mouse endpoint to `event3`, `event4`, or another number.
*   **Input Swallowing**: It prevents grabbed mouse events such as modifier scroll and `Ctrl+Meta+Middle Click` from reaching the active application. `Ctrl+Meta+1-9` is handled by the separate `xremap-meta-keyboard` service, which normalizes the split keyboard endpoints and launches the numbered taskbar app directly.
*   **Cleanup Logic**: Releases tracked virtual mouse buttons when modifier-driven mouse grabbing is dropped, and force-releases common modifiers/buttons on daemon shutdown so the desktop does not stay stuck in a grabbed state.

### 2. The Action Scripts
These scripts are triggered by the daemon and use `kdotool` to interact with KWin's internal window IDs.

*   **`meta-wheel-minimize-wayland`**: Finds the window exactly under the cursor and adds its ID to a stack file before minimizing.
*   **`meta-wheel-restore-wayland`**: Pops the last ID from the stack file and activates (un-minimizes) that specific window.
*   **`meta-wheel-close-wayland`**: Instantly closes the window under the mouse cursor.
*   **`launch-taskbar-app.sh`**: Parses your KDE task manager configuration and launches a **fresh instance** of the application at the specified position.

## Configured Shortcuts

| Shortcut | Action | Logic |
| :--- | :--- | :--- |
| **Meta + Scroll Down** | Minimize Window | Targets window under cursor; uses 200ms throttle. |
| **Meta + Scroll Up** | Restore Window | Un-minimizes the last window in our stack. |
| **Ctrl + Meta + Middle Click** | Close Window | Instantly kills the window under the cursor. |
| **Ctrl + Meta + [1-9]** | Launch New App | Handled by `xremap-meta-keyboard.service`, which runs `launch-taskbar-app.sh N` to open a fresh instance of the Nth pinned app. |
| **Shift + Scroll** | Desktop Zoom | Triggers KWin Desktop Zoom via DBus; zero throttle (smooth). |

## Management

The system is managed as a standard **systemd user service**.

*   **Restart Service**: `systemctl --user restart wayland-scroll-daemon.service`
*   **Check Status**: `systemctl --user status wayland-scroll-daemon.service`
*   **View Logs**: `journalctl --user -u wayland-scroll-daemon.service -f`
*   **Reload xremap Keyboard Normalizer**: `systemctl --user restart xremap-meta-keyboard.service`
*   **Boot Ordering**: `wayland-scroll-daemon.service` has `Requires=` and `After=` on `xremap-meta-keyboard.service`, so the scroll daemon waits for the normalized keyboard before selecting devices.

## File Locations
*   **Scripts**: `~/Dev/config/xbindkeys/`
*   **Service File**: `~/Dev/config/systemd/user/wayland-scroll-daemon.service`, installed to `~/.config/systemd/user/wayland-scroll-daemon.service`.
*   **xremap Keyboard Normalizer**: `~/Dev/config/xremap/meta-keyboard.yml`, installed via `~/.config/systemd/user/xremap-meta-keyboard.service`.
*   **Launch Template Service**: `~/Dev/config/systemd/user/launch-taskbar-app@.service`, installed to `~/.config/systemd/user/launch-taskbar-app@.service` for manual or alternate launch paths.

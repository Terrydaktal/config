# Wayland Window Management (KDE Plasma 6)

This directory contains a suite of scripts designed to replicate and extend the functionality of `xbindkeys` on Wayland. Since Wayland (and specifically KWin) restricts global input capture for security, these scripts operate at the kernel level (`evdev`) to provide a zero-lag, stutter-free experience even with high-performance gaming mice.

## The Architecture

The system consists of a single **Unified Python Daemon** that acts as the "brain," and several specialized **Action Scripts** that perform the actual window manipulations.

### 1. The Daemon (`wayland_scroll_daemon.py`)
This is the core background process. It performs the following roles:
*   **Keyboard Interception**: Fully grabs the keyboard to catch shortcut modifiers (`Ctrl`, `Meta`, `Shift`) and number keys. It re-broadcasts non-intercepted keys to a "Virtual Keyboard."
*   **Dynamic Mouse Grab**: To preserve 1000Hz gaming mouse performance, it only "grabs" the mouse when a modifier key (`Meta` or `Shift`) is held down. 
*   **Input Swallowing**: It prevents remapped events (like the number '1' or a scroll wheel movement) from reaching the active application.
*   **Anti-Stick Logic**: Automatically synthesizes "Release" events if modifiers are let go while a mouse button is held, preventing stuck clicks.

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
| **Ctrl + Meta + [1-9]** | Launch New App | Opens a fresh instance of the Nth pinned app. |
| **Shift + Scroll** | Desktop Zoom | Triggers KWin Desktop Zoom via DBus; zero throttle (smooth). |

## Management

The system is managed as a standard **systemd user service**.

*   **Restart Service**: `systemctl --user restart wayland-scroll-daemon.service`
*   **Check Status**: `systemctl --user status wayland-scroll-daemon.service`
*   **View Logs**: `journalctl --user -u wayland-scroll-daemon.service -f`

## File Locations
*   **Scripts**: `~/Dev/config/xbindkeys/`
*   **Service File**: `~/.config/systemd/user/wayland-scroll-daemon.service`

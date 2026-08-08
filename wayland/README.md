# Wayland Window Management (KDE Plasma 6)

This directory contains the current Wayland input and window-management helpers. Since Wayland (and specifically KWin) restricts global input capture for security, these scripts operate at the kernel level (`evdev`) to provide a zero-lag, stutter-free experience even with high-performance gaming mice.

## The Architecture

The system consists of a single **Unified Python Daemon** that acts as the "brain," and several specialized **Action Scripts** that perform the actual window manipulations.

### 1. The Daemon (`wayland_scroll_daemon.py`)
This is the core background process. It performs the following roles:
*   **Keyboard Tracking**: Waits for `xremap normalized keyboard` and watches it for shortcut modifiers (`Ctrl`, `Meta`, `Shift`). At mouse-action time it also reads the physical modifier state directly, avoiding ordering races between xremap's virtual keyboard and the mouse endpoint.
*   **Hotplug Recovery**: Tracks the current `/dev/input/event*` topology, rediscovers physical modifier devices after keyboard or mouse hotplug, and force-reopens any descriptor that reports an input error. Changed event numbers therefore do not require hard-coded updates.
*   **Dynamic Mouse Grab**: To preserve 1000Hz gaming mouse performance, it only "grabs" the mouse when a modifier key (`Meta` or `Shift`) is held down and no physical mouse button is already pressed. Clicks that start before the modifier are left on the normal compositor path.
*   **Stable Mouse Selection**: Opens the real wheel/button endpoint through `/dev/input/by-id/usb-04d9_USB_Gaming_Mouse-event-mouse`, so it does not matter whether the kernel assigns the mouse endpoint to `event3`, `event4`, or another number.
*   **Wheel Normalization**: Resolves wheel data at each input report boundary, prefers ordinary `REL_WHEEL` steps when both formats are present, and accumulates `REL_WHEEL_HI_RES` units as a fallback for high-resolution-only devices.
*   **Input Swallowing**: It prevents grabbed mouse events such as modifier scroll and `Ctrl+Meta+Middle Click` from reaching the active application. `Ctrl+Meta+1-9` is handled by the separate `xremap-meta-keyboard` service, which normalizes the split keyboard endpoints and launches the numbered taskbar app directly.
*   **Cleanup Logic**: Releases tracked virtual mouse buttons when modifier-driven mouse grabbing is dropped, and force-releases common modifiers/buttons on daemon shutdown so the desktop does not stay stuck in a grabbed state.

### 2. The Action Scripts
These scripts are triggered by the daemon and use `kdotool` to interact with KWin's internal window IDs.

*   **`meta-wheel-minimize-wayland`**: Finds and minimizes the window exactly under the cursor, then records its validated ID in a locked, deduplicated stack.
*   **`meta-wheel-restore-wayland`**: Validates the newest stacked ID, un-minimizes that specific window, and removes the entry only after restoration succeeds.
*   **`meta-wheel-close-wayland`**: Instantly closes the window under the mouse cursor.
*   **`~/Dev/config/bin/launch-taskbar-app.sh`**: Parses your KDE task manager configuration and launches a **fresh instance** of the application at the specified position.

## KWin Monitor Change Recovery

`etc/udev/kwin-monitor-change-reinit` handles stale KWin compositor state after a monitor wake-up, reboot, or monitor swap. KWin's DRM backend can retain output and framebuffer state from a previous monitor long enough for stale VRAM buffers to be allocated or left attached to the current session.

The udev rule `etc/udev/rules.d/99-kwin-reinit-on-hotplug.rules` starts the helper for DRM hotplug events. The helper:

1. Waits for the hotplug burst to settle and queries `kscreen-doctor --outputs`.
2. Builds a fingerprint from the connected output connector and KScreen hardware UUID.
3. Compares that fingerprint with `~/.cache/kwin-monitor-reinit/connected-displays`.
4. Does nothing when the connected monitor identity is unchanged. On the first observation, it records the fingerprint without restarting KWin.
5. When the identity changes, asks KWin to tear down and recreate its compositor pipeline with:

   `qdbus6 org.kde.KWin /Compositor org.kde.kwin.Compositing.reinitialize`

This flushes stale display buffers and makes KWin initialize only the monitor that is actually connected. It therefore covers both single-monitor sleep or lock wake-up events and the case where the machine was rebooted with Monitor A connected and then started with Monitor B, or the display input was switched.

## PowerDevil Lock Recovery

`systemd/user/kde-refresh-powerdevil-after-lock` is the helper launched by `kde-refresh-powerdevil-after-lock.service`. It watches KDE's `org.freedesktop.ScreenSaver` D-Bus `ActiveChanged` signal so it can repair PowerDevil state after the display locks and wakes.

On lock, it records the current brightness. On unlock, it applies a ten-second cooldown, reparses PowerDevil's configuration, restarts `plasma-powerdevil.service`, waits for it to settle, and restores the recorded brightness. This prevents a lock or display wake from leaving brightness controls stale or restoring the wrong brightness level. The last saved value is kept in `$XDG_RUNTIME_DIR/kde-refresh-powerdevil-after-lock.brightness`.

## Configured Shortcuts

| Shortcut | Action | Logic |
| :--- | :--- | :--- |
| **Meta + Scroll Down** | Minimize Window | Targets the window under the cursor and coalesces same-direction events within one 200ms wheel burst. |
| **Meta + Scroll Up** | Restore Window | Un-minimizes the last window in our stack. |
| **Ctrl + Meta + Middle Click** | Close Window | Instantly kills the window under the cursor. |
| **Mouse Back/Forward in `xfce4-terminal`** | Directory History | Emits `Alt+Left` / `Alt+Right`, which fish binds to `prevd` / `nextd`. |
| **Ctrl + Meta + [1-9]** | Launch New App | Handled directly by `xremap-meta-keyboard.service`, which runs `launch-taskbar-app.sh N` from `~/Dev/config/bin/` to open a fresh instance of the Nth pinned app. |
| **Shift + Scroll** | Desktop Zoom | Triggers KWin Desktop Zoom via DBus; zero throttle (smooth). |

## Management

The system is managed as a standard **systemd user service**.

*   **Restart Service**: `systemctl --user restart wayland-scroll-daemon.service`
*   **Restore Full Shortcut Stack**: If shortcut handling stops working after stopping services or probing input devices, restart the whole user-service chain with `systemctl --user restart xremap-meta-keyboard.service wayland-scroll-daemon.service ydotool.service`
*   **Check Status**: `systemctl --user status wayland-scroll-daemon.service`
*   **View Logs**: `journalctl --user -u wayland-scroll-daemon.service -f`
*   **Reload xremap Keyboard Normalizer**: `systemctl --user restart xremap-meta-keyboard.service`
*   **Boot Ordering**: `wayland-scroll-daemon.service` has `Requires=` and `After=` on `xremap-meta-keyboard.service`, so the scroll daemon waits for the normalized keyboard before selecting devices. Both units disable systemd's start-rate limit and continue retrying when the configured keyboard or mouse is absent during boot.

## File Locations
*   **Wayland Scripts**: `~/Dev/config/wayland/`
*   **Shared Launcher Script**: `~/Dev/config/bin/launch-taskbar-app.sh`
*   **Service File**: `~/Dev/config/systemd/user/wayland-scroll-daemon.service`, installed to `~/.config/systemd/user/wayland-scroll-daemon.service`.
*   **xremap Keyboard Normalizer Config**: `~/Dev/config/xremap/meta-keyboard.yml`
*   **xremap Keyboard Normalizer Service**: `~/Dev/config/systemd/user/xremap-meta-keyboard.service`, installed to `~/.config/systemd/user/xremap-meta-keyboard.service`.

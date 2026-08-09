#!/usr/bin/env python3
import evdev
from evdev import ecodes
import subprocess
import threading
import time
import sys
import signal
import os

# Paths to scripts
MINIMIZE_SCRIPT = '/home/lewis/Dev/config/wayland/meta-wheel-minimize-wayland'
RESTORE_SCRIPT = '/home/lewis/Dev/config/wayland/meta-wheel-restore-wayland'
CLOSE_SCRIPT = '/home/lewis/Dev/config/wayland/meta-wheel-close-wayland'
KDTOOL = os.path.expanduser('~/.cargo/bin/kdotool')
TERMINAL_CLASS = 'xfce4-terminal'
RUNTIME_DIR = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
MODIFIER_STATE_FILE = os.path.join(RUNTIME_DIR, 'wayland_modifier_state.env')

# Global state
state_lock = threading.RLock()
grab_transition_lock = threading.Lock()
mouse_io_lock = threading.RLock()
state = {
    'meta': False,
    'shift': False,
    'ctrl': False,
    'alt': False,
    'modifier_keys': {
        'meta': set(),
        'shift': set(),
        'ctrl': set(),
        'alt': set(),
    },
    'mouse_grabbed': False,
    'last_meta_wheel_event': 0.0,
    'last_meta_wheel_direction': 0,
    'vm_pressed': set(),      # Buttons currently down on virtual mouse
    'physical_buttons': set(), # Buttons already down on the real mouse
    'swallow_middle': False,
    'swallow_terminal_nav': set(),
}
META_WHEEL_BURST_GAP = 0.20
DEVICE_WAIT_SECONDS = 15
NORMALIZED_KEYBOARD_NAME = 'xremap normalized keyboard'
TERMINAL_NAV_KEYBOARD_NAME = 'wayland terminal nav keyboard'
MOUSE_BY_ID = '/dev/input/by-id/usb-04d9_USB_Gaming_Mouse-event-mouse'
HI_RES_WHEEL_UNITS = 120
MODIFIER_KEY_CODES = {
    'meta': {ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA},
    'shift': {ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT},
    'ctrl': {ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL},
    'alt': {ecodes.KEY_LEFTALT, ecodes.KEY_RIGHTALT},
}
TERMINAL_NAV_BUTTONS = {
    ecodes.BTN_SIDE: ecodes.KEY_LEFT,
    ecodes.BTN_BACK: ecodes.KEY_LEFT,
    ecodes.BTN_EXTRA: ecodes.KEY_RIGHT,
    ecodes.BTN_FORWARD: ecodes.KEY_RIGHT,
}

FORCED_BUTTON_RELEASES = {
    ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE,
    ecodes.BTN_SIDE, ecodes.BTN_EXTRA,
    ecodes.BTN_FORWARD, ecodes.BTN_BACK, ecodes.BTN_TASK,
}

def is_modifier_keyboard(dev):
    caps = dev.capabilities()
    keys = set(caps.get(ecodes.EV_KEY, []))
    return any(keys & codes for codes in MODIFIER_KEY_CODES.values())

def is_wheel_mouse(dev):
    caps = dev.capabilities()
    keys = caps.get(ecodes.EV_KEY, [])
    rel = caps.get(ecodes.EV_REL, [])
    has_vertical_wheel = ecodes.REL_WHEEL in rel or ecodes.REL_WHEEL_HI_RES in rel
    return has_vertical_wheel and any(k in keys for k in [
        ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE,
    ])

class ModifierDeviceRegistry:
    """Keep physical modifier handles synchronized with input hot-plugs."""

    def __init__(self):
        self._lock = threading.Lock()
        self._known_input_paths = frozenset()
        self._devices = {}

    @staticmethod
    def _is_physical_modifier_device(dev):
        name = dev.name or ''
        if name in {NORMALIZED_KEYBOARD_NAME, TERMINAL_NAV_KEYBOARD_NAME}:
            return False
        if 'ydotool' in name or 'Virtual Mouse' in name:
            return False
        return is_modifier_keyboard(dev)

    def refresh(self, force=False):
        current_paths = frozenset(evdev.list_devices())
        with self._lock:
            if not force and current_paths == self._known_input_paths:
                return

            replacements = {}
            for path in sorted(current_paths):
                try:
                    dev = evdev.InputDevice(path)
                    if not self._is_physical_modifier_device(dev):
                        dev.close()
                        continue
                    keys = set(dev.capabilities().get(ecodes.EV_KEY, []))
                    supported = {
                        modifier for modifier, codes in MODIFIER_KEY_CODES.items()
                        if keys & codes
                    }
                    replacements[path] = (dev, supported)
                except OSError:
                    continue

            old_devices = self._devices
            self._devices = replacements
            self._known_input_paths = current_paths
            for dev, _ in old_devices.values():
                try:
                    dev.close()
                except OSError:
                    pass

    def read(self, retry=True):
        self.refresh()
        live = {modifier: False for modifier in MODIFIER_KEY_CODES}
        available = {modifier: False for modifier in MODIFIER_KEY_CODES}
        failed = False

        with self._lock:
            for dev, supported in self._devices.values():
                try:
                    active_keys = set(dev.active_keys())
                except OSError:
                    failed = True
                    continue
                for modifier in supported:
                    available[modifier] = True
                    live[modifier] |= bool(active_keys & MODIFIER_KEY_CODES[modifier])

        if failed and retry:
            self.refresh(force=True)
            return self.read(retry=False)

        with state_lock:
            fallback = {
                modifier: state[modifier]
                for modifier in MODIFIER_KEY_CODES
            }
        return {
            modifier: live[modifier] if available[modifier] else fallback[modifier]
            for modifier in MODIFIER_KEY_CODES
        }

class VerticalWheelNormalizer:
    """Resolve one packet to coarse wheel steps or high-resolution fallback."""

    def __init__(self):
        self.coarse_delta = 0
        self.hi_res_delta = 0
        self.hi_res_remainder = 0

    def add(self, code, value):
        if code == ecodes.REL_WHEEL:
            self.coarse_delta += value
        elif code == ecodes.REL_WHEEL_HI_RES:
            self.hi_res_delta += value

    def flush(self):
        if self.coarse_delta:
            direction = -1 if self.coarse_delta < 0 else 1
            steps = [direction] * abs(self.coarse_delta)
            self.hi_res_remainder = 0
        else:
            if self.hi_res_delta and self.hi_res_remainder:
                direction_changed = (self.hi_res_delta < 0) != (self.hi_res_remainder < 0)
                if direction_changed:
                    self.hi_res_remainder = 0
            self.hi_res_remainder += self.hi_res_delta
            direction = -1 if self.hi_res_remainder < 0 else 1
            step_count = abs(self.hi_res_remainder) // HI_RES_WHEEL_UNITS
            steps = [direction] * step_count
            self.hi_res_remainder -= direction * step_count * HI_RES_WHEEL_UNITS

        self.coarse_delta = 0
        self.hi_res_delta = 0
        return steps

def open_stable_mouse():
    try:
        dev = evdev.InputDevice(MOUSE_BY_ID)
        if is_wheel_mouse(dev):
            return dev
    except:
        pass
    return None

def active_window_class():
    try:
        result = subprocess.run(
            [KDTOOL, 'getactivewindow', 'getwindowclassname'],
            check=False,
            capture_output=True,
            text=True,
            timeout=1,
        )
        if result.returncode == 0:
            lines = (result.stdout or '').strip().splitlines()
            if lines:
                return lines[-1]
    except:
        pass
    return ''

def write_modifier_state():
    tmp_path = MODIFIER_STATE_FILE + '.tmp'
    try:
        with state_lock:
            values = {
                modifier: state[modifier]
                for modifier in MODIFIER_KEY_CODES
            }
        with open(tmp_path, 'w', encoding='utf-8') as handle:
            handle.write(f"META={'1' if values['meta'] else '0'}\n")
            handle.write(f"SHIFT={'1' if values['shift'] else '0'}\n")
            handle.write(f"CTRL={'1' if values['ctrl'] else '0'}\n")
            handle.write(f"ALT={'1' if values['alt'] else '0'}\n")
        os.replace(tmp_path, MODIFIER_STATE_FILE)
    except Exception:
        try:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
        except Exception:
            pass

def tap_alt_arrow(keyboard_ui, arrow_code):
    if keyboard_ui is None:
        return
    try:
        keyboard_ui.write(ecodes.EV_KEY, ecodes.KEY_LEFTALT, 1)
        keyboard_ui.write(ecodes.EV_KEY, arrow_code, 1)
        keyboard_ui.syn()
        keyboard_ui.write(ecodes.EV_KEY, arrow_code, 0)
        keyboard_ui.write(ecodes.EV_KEY, ecodes.KEY_LEFTALT, 0)
        keyboard_ui.syn()
    except Exception:
        # If injection fails after a key-down, release both keys before the
        # worker continues so a transient uinput error cannot stick Alt.
        try:
            keyboard_ui.write(ecodes.EV_KEY, arrow_code, 0)
            keyboard_ui.write(ecodes.EV_KEY, ecodes.KEY_LEFTALT, 0)
            keyboard_ui.syn()
        except Exception:
            pass

def safe_keyboard_release(keyboard_ui):
    if keyboard_ui is None:
        return
    try:
        for code in (ecodes.KEY_LEFTALT, ecodes.KEY_LEFT, ecodes.KEY_RIGHT):
            keyboard_ui.write(ecodes.EV_KEY, code, 0)
        keyboard_ui.syn()
    except Exception:
        pass

def create_terminal_nav_keyboard():
    return evdev.UInput({
        ecodes.EV_KEY: [
            ecodes.KEY_LEFTALT,
            ecodes.KEY_LEFT,
            ecodes.KEY_RIGHT,
        ],
    }, name=TERMINAL_NAV_KEYBOARD_NAME)

def get_devices(require_normalized_keyboard=False):
    normalized_keyboard = None
    stable_mouse = open_stable_mouse()
    mice = [stable_mouse] if stable_mouse else []
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
            name = dev.name or ''
            if 'ydotool' in name or 'Virtual Mouse' in name:
                continue
            if is_modifier_keyboard(dev):
                if name == NORMALIZED_KEYBOARD_NAME:
                    normalized_keyboard = dev
            if not stable_mouse and 'Mouse' in name and is_wheel_mouse(dev):
                mice.append(dev)
        except:
            pass
    if normalized_keyboard:
        return [normalized_keyboard], mice
    if require_normalized_keyboard:
        return [], mice
    return [], mice

def wait_for_devices():
    deadline = time.monotonic() + DEVICE_WAIT_SECONDS
    while True:
        keyboards, mice = get_devices(require_normalized_keyboard=True)
        if keyboards and mice:
            return keyboards, mice
        if time.monotonic() >= deadline:
            print(f"Timed out waiting for {NORMALIZED_KEYBOARD_NAME!r} and {MOUSE_BY_ID}", file=sys.stderr)
            sys.exit(75)
        time.sleep(0.25)

def should_trigger_meta_wheel(direction, now=None):
    """Trigger once at the leading edge of each same-direction wheel burst."""
    if now is None:
        now = time.monotonic()
    with state_lock:
        same_burst = (
            direction == state['last_meta_wheel_direction']
            and now - state['last_meta_wheel_event'] <= META_WHEEL_BURST_GAP
        )
        state['last_meta_wheel_direction'] = direction
        state['last_meta_wheel_event'] = now
    return not same_burst

def window_under_cursor_id():
    for attempt in range(2):
        try:
            result = subprocess.run(
                [KDTOOL, 'getmouselocation', 'getwindowid'],
                check=False,
                capture_output=True,
                text=True,
                timeout=0.25,
            )
            if result.returncode == 0:
                window_id = (result.stdout or '').strip().splitlines()
                if window_id and window_id[-1] not in {'', '0'}:
                    return window_id[-1]
        except (OSError, subprocess.SubprocessError):
            pass
        if attempt == 0:
            time.sleep(0.01)
    return None

def dispatch_wheel(direction, is_grabbed, modifier_devices):
    modifiers = modifier_devices.read()
    if not (is_grabbed or modifiers['meta'] or modifiers['shift']):
        return

    if modifiers['meta'] and modifiers['ctrl']:
        return
    if modifiers['meta']:
        if not should_trigger_meta_wheel(direction):
            return
        if direction < 0:
            window_id = window_under_cursor_id()
            if window_id is None:
                return
            command = [MINIMIZE_SCRIPT, window_id]
        else:
            command = [RESTORE_SCRIPT]
    elif modifiers['shift']:
        shortcut = 'view_zoom_out' if direction < 0 else 'view_zoom_in'
        command = [
            'qdbus6', 'org.kde.kglobalaccel', '/component/kwin',
            'invokeShortcut', shortcut,
        ]
    else:
        return

    subprocess.Popen(command, start_new_session=True)

def safe_vm_release(mice_with_uis):
    """Release virtual buttons while the physical mouse is still grabbed."""
    with mouse_io_lock:
        with state_lock:
            # Also release common pointer buttons not present in our state.
            # This is harmless for an up button and clears a missed release.
            codes = set(state['vm_pressed']) | FORCED_BUTTON_RELEASES
        for _, ui in mice_with_uis:
                for code in sorted(codes):
                    try:
                        ui.write(ecodes.EV_KEY, code, 0)
                    except Exception:
                        pass
        with state_lock:
            state['vm_pressed'].clear()
        for _, ui in mice_with_uis:
            try:
                ui.syn()
            except Exception:
                pass


def mouse_is_grabbed():
    with state_lock:
        return state['mouse_grabbed']


def set_physical_button(code, pressed):
    with state_lock:
        if pressed:
            state['physical_buttons'].add(code)
        else:
            state['physical_buttons'].discard(code)


def set_virtual_button(code, pressed):
    with state_lock:
        if pressed:
            state['vm_pressed'].add(code)
        else:
            state['vm_pressed'].discard(code)


def write_virtual_event(ui, event):
    with mouse_io_lock:
        if not mouse_is_grabbed():
            return False
        ui.write_event(event)
        return True


def syn_virtual(ui):
    with mouse_io_lock:
        if not mouse_is_grabbed():
            return False
        ui.syn()
        return True


def update_modifier_state(code, value, mice_with_uis):
    for modifier, codes in MODIFIER_KEY_CODES.items():
        if code not in codes:
            continue
        with state_lock:
            keys = state['modifier_keys'][modifier]
            if value == 0:
                keys.discard(code)
            else:
                keys.add(code)
            new_value = bool(keys)
            changed = state[modifier] != new_value
            state[modifier] = new_value
        if changed:
            update_mouse_grab_state(mice_with_uis)
            write_modifier_state()
        return True
    return False


def update_mouse_grab_state(mice_with_uis):
    """Synchronize the physical grab with modifiers and held buttons."""
    with grab_transition_lock:
        with state_lock:
            current = state['mouse_grabbed']
            modifier_held = state['meta'] or state['shift']
            physical_buttons = bool(state['physical_buttons'])
            should_grab = (
                modifier_held and not physical_buttons
                if not current else modifier_held or physical_buttons
            )
        if should_grab == current:
            return

        with mouse_io_lock:
            if should_grab:
                grabbed = []
                try:
                    for mouse, _ in mice_with_uis:
                        mouse.grab()
                        grabbed.append(mouse)
                except Exception as error:
                    print(f"Mouse grab failed: {error}", file=sys.stderr)
                    for mouse in reversed(grabbed):
                        try:
                            mouse.ungrab()
                        except Exception:
                            pass
                    return

                with state_lock:
                    # A button may have gone down while EVIOCGRAB was running.
                    if state['physical_buttons']:
                        should_grab = False
                    else:
                        state['mouse_grabbed'] = True
                if not should_grab:
                    for mouse in reversed(grabbed):
                        try:
                            mouse.ungrab()
                        except Exception:
                            pass
                return

            # Do not sleep while holding the physical grab. The mouse worker
            # queues events in the kernel and resumes immediately after ungrab.
            safe_vm_release(mice_with_uis)
            for mouse, _ in mice_with_uis:
                try:
                    mouse.ungrab()
                except Exception as error:
                    print(f"Mouse ungrab failed: {error}", file=sys.stderr)
            with state_lock:
                state['mouse_grabbed'] = False

def keyboard_worker(kb, mice_with_uis):
    try:
        for event in kb.read_loop():
            if event.type == ecodes.EV_KEY:
                update_modifier_state(event.code, event.value, mice_with_uis)
    except Exception as e:
        print(f"Keyboard worker error: {e}", file=sys.stderr)
        os.kill(os.getpid(), signal.SIGTERM)

def mouse_worker(mouse, ui, keyboard_ui, mice_with_uis, modifier_devices):
    wheel = VerticalWheelNormalizer()
    try:
        for event in mouse.read_loop():
            is_grabbed = mouse_is_grabbed()
            is_pointer_button = event.type == ecodes.EV_KEY and event.code in FORCED_BUTTON_RELEASES
            is_terminal_nav_button = event.type == ecodes.EV_KEY and event.code in TERMINAL_NAV_BUTTONS
            if is_pointer_button:
                if event.value == 1:
                    set_physical_button(event.code, True)
                elif event.value == 0:
                    set_physical_button(event.code, False)

            if is_terminal_nav_button:
                if event.value == 1:
                    set_physical_button(event.code, True)
                    if active_window_class() == TERMINAL_CLASS and keyboard_ui is not None:
                        with state_lock:
                            state['swallow_terminal_nav'].add(event.code)
                        tap_alt_arrow(keyboard_ui, TERMINAL_NAV_BUTTONS[event.code])
                    elif is_grabbed and write_virtual_event(ui, event):
                        set_virtual_button(event.code, True)
                elif event.value == 0:
                    set_physical_button(event.code, False)
                    with state_lock:
                        swallowed = event.code in state['swallow_terminal_nav']
                        state['swallow_terminal_nav'].discard(event.code)
                    if not swallowed and is_grabbed and write_virtual_event(ui, event):
                        set_virtual_button(event.code, False)

                if is_pointer_button or is_terminal_nav_button:
                    update_mouse_grab_state(mice_with_uis)
                continue

            if event.type == ecodes.EV_REL and event.code in {
                ecodes.REL_WHEEL, ecodes.REL_WHEEL_HI_RES,
            }:
                wheel.add(event.code, event.value)
                continue
            elif event.type == ecodes.EV_SYN and event.code == ecodes.SYN_REPORT:
                for direction in wheel.flush():
                    dispatch_wheel(direction, is_grabbed, modifier_devices)
                if is_grabbed:
                    syn_virtual(ui)
            elif event.type == ecodes.EV_KEY and event.code == ecodes.BTN_MIDDLE:
                if event.value == 1:
                    modifiers = modifier_devices.read()
                    # Modifier state is sampled directly from the input devices.
                    # Do not reject the chord because the asynchronous grab worker
                    # has not yet published its state; that loses the first click.
                    if modifiers['meta'] and modifiers['ctrl']:
                        window_id = window_under_cursor_id()
                        with state_lock:
                            state['swallow_middle'] = True
                        if window_id is not None:
                            subprocess.Popen(
                                [CLOSE_SCRIPT, window_id],
                                start_new_session=True,
                            )
                    elif is_grabbed:
                        with state_lock:
                            state['swallow_middle'] = False
                        if write_virtual_event(ui, event):
                            set_virtual_button(event.code, True)
                elif event.value == 0:
                    with state_lock:
                        swallowed = state['swallow_middle']
                        state['swallow_middle'] = False
                    if not swallowed and is_grabbed:
                        if write_virtual_event(ui, event):
                            set_virtual_button(event.code, False)
            else:
                if is_grabbed:
                    if event.type == ecodes.EV_SYN:
                        syn_virtual(ui)
                    elif write_virtual_event(ui, event):
                        if event.type == ecodes.EV_KEY:
                            if event.value == 1:
                                set_virtual_button(event.code, True)
                            elif event.value == 0:
                                set_virtual_button(event.code, False)

            if is_pointer_button:
                update_mouse_grab_state(mice_with_uis)
    except Exception as e:
        print(f"Mouse worker error: {e}", file=sys.stderr)
        os.kill(os.getpid(), signal.SIGTERM)

def main():
    write_modifier_state()
    keyboards, mice = wait_for_devices()
    modifier_devices = ModifierDeviceRegistry()
    modifier_devices.refresh()
    keyboard_ui = None
    mice_with_uis = []
    threads = []
    try:
        keyboard_ui = create_terminal_nav_keyboard()
    except:
        pass
    def signal_handler(sig, frame):
        safe_vm_release(mice_with_uis)
        safe_keyboard_release(keyboard_ui)
        for mouse, _ in mice_with_uis:
            try:
                mouse.ungrab()
            except Exception:
                pass
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    for m in mice:
        try:
            ui = evdev.UInput.from_device(m, name=m.name + " (Virtual Mouse)")
            mice_with_uis.append((m, ui))
            t = threading.Thread(
                target=mouse_worker,
                args=(m, ui, keyboard_ui, mice_with_uis, modifier_devices),
                daemon=True,
            )
            t.start()
            threads.append(t)
        except: pass
    for kb in keyboards:
        try:
            t = threading.Thread(target=keyboard_worker, args=(kb, mice_with_uis), daemon=True)
            t.start()
            threads.append(t)
        except: pass
    while True: time.sleep(10)

if __name__ == '__main__':
    main()

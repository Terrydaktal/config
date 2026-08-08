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
state = {
    'meta': False, 
    'shift': False, 
    'ctrl': False,
    'alt': False,
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

        return {
            modifier: live[modifier] if available[modifier] else state[modifier]
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
        with open(tmp_path, 'w', encoding='utf-8') as handle:
            handle.write(f"META={'1' if state['meta'] else '0'}\n")
            handle.write(f"SHIFT={'1' if state['shift'] else '0'}\n")
            handle.write(f"CTRL={'1' if state['ctrl'] else '0'}\n")
            handle.write(f"ALT={'1' if state['alt'] else '0'}\n")
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
    except:
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
    same_burst = (
        direction == state['last_meta_wheel_direction']
        and now - state['last_meta_wheel_event'] <= META_WHEEL_BURST_GAP
    )
    state['last_meta_wheel_direction'] = direction
    state['last_meta_wheel_event'] = now
    return not same_burst

def dispatch_wheel(direction, is_grabbed, modifier_devices):
    modifiers = modifier_devices.read()
    if not (is_grabbed or modifiers['meta'] or modifiers['shift']):
        return

    if modifiers['meta'] and not modifiers['ctrl']:
        if not should_trigger_meta_wheel(direction):
            return
        command = [MINIMIZE_SCRIPT] if direction < 0 else [RESTORE_SCRIPT]
    elif modifiers['shift']:
        shortcut = 'view_zoom_out' if direction < 0 else 'view_zoom_in'
        command = [
            'qdbus6', 'org.kde.kglobalaccel', '/component/kwin',
            'invokeShortcut', shortcut,
        ]
    else:
        return

    subprocess.Popen(command)

def safe_vm_release(mice_with_uis):
    """Release tracked buttons and common pointer buttons on virtual mice."""
    for m, ui in mice_with_uis:
        for code in sorted(state['vm_pressed'] | FORCED_BUTTON_RELEASES):
            try:
                ui.write(ecodes.EV_KEY, code, 0)
            except: pass
    state['vm_pressed'].clear()
    for m, ui in mice_with_uis:
        try:
            ui.syn()
        except: pass

def update_mouse_grab_state(mice_with_uis):
    modifier_held = state['meta'] or state['shift']
    # Do not start a grab after a real button-down has already reached the compositor.
    should_grab_mouse = modifier_held and (state['mouse_grabbed'] or not state['physical_buttons'])
    if should_grab_mouse == state['mouse_grabbed']:
        return

    state['mouse_grabbed'] = should_grab_mouse
    if should_grab_mouse:
        for m, ui in mice_with_uis:
            try:
                m.grab()
            except: pass
    else:
        safe_vm_release(mice_with_uis)
        time.sleep(0.01)
        for m, ui in mice_with_uis:
            try:
                m.ungrab()
            except: pass

def keyboard_worker(kb, mice_with_uis):
    try:
        for event in kb.read_loop():
            if event.type == ecodes.EV_KEY:
                if event.code in [ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA]:
                    state['meta'] = (event.value > 0)
                elif event.code in [ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT]:
                    state['shift'] = (event.value > 0)
                elif event.code in [ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL]:
                    state['ctrl'] = (event.value > 0)
                elif event.code in [ecodes.KEY_LEFTALT, ecodes.KEY_RIGHTALT]:
                    state['alt'] = (event.value > 0)

                write_modifier_state()
                update_mouse_grab_state(mice_with_uis)
    except Exception as e:
        print(f"Keyboard worker error: {e}", file=sys.stderr)
        os._exit(75)

def mouse_worker(mouse, ui, keyboard_ui, mice_with_uis, modifier_devices):
    wheel = VerticalWheelNormalizer()
    try:
        for event in mouse.read_loop():
            is_grabbed = state['mouse_grabbed']
            is_pointer_button = event.type == ecodes.EV_KEY and event.code in FORCED_BUTTON_RELEASES
            is_terminal_nav_button = event.type == ecodes.EV_KEY and event.code in TERMINAL_NAV_BUTTONS
            if is_pointer_button:
                if event.value == 1:
                    state['physical_buttons'].add(event.code)
                elif event.value == 0:
                    state['physical_buttons'].discard(event.code)

            if is_terminal_nav_button:
                if event.value == 1:
                    state['physical_buttons'].add(event.code)
                    if active_window_class() == TERMINAL_CLASS and keyboard_ui is not None:
                        state['swallow_terminal_nav'].add(event.code)
                        tap_alt_arrow(keyboard_ui, TERMINAL_NAV_BUTTONS[event.code])
                    else:
                        ui.write_event(event)
                        if is_grabbed:
                            state['vm_pressed'].add(event.code)
                elif event.value == 0:
                    state['physical_buttons'].discard(event.code)
                    if event.code in state['swallow_terminal_nav']:
                        state['swallow_terminal_nav'].discard(event.code)
                    else:
                        ui.write_event(event)
                        if is_grabbed:
                            state['vm_pressed'].discard(event.code)

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
                    ui.syn()
            elif event.type == ecodes.EV_KEY and event.code == ecodes.BTN_MIDDLE:
                if event.value == 1:
                    modifiers = modifier_devices.read()
                    if modifiers['meta'] and modifiers['ctrl']:
                        state['swallow_middle'] = True
                        subprocess.Popen([CLOSE_SCRIPT])
                    elif is_grabbed:
                        state['swallow_middle'] = False
                        ui.write_event(event)
                        state['vm_pressed'].add(event.code)
                elif event.value == 0:
                    if state['swallow_middle']:
                        state['swallow_middle'] = False
                    elif is_grabbed:
                        ui.write_event(event)
                        state['vm_pressed'].discard(event.code)
            else:
                if is_grabbed:
                    ui.write_event(event)
                    if event.type == ecodes.EV_KEY:
                        if event.value == 1: state['vm_pressed'].add(event.code)
                        else: state['vm_pressed'].discard(event.code)
                    if event.type == ecodes.EV_SYN:
                        ui.syn()

            if is_pointer_button:
                update_mouse_grab_state(mice_with_uis)
    except Exception as e:
        print(f"Mouse worker error: {e}", file=sys.stderr)
        os._exit(75)

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
    def signal_handler(sig, frame):
        safe_vm_release(mice_with_uis)
        sys.exit(0)
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    while True: time.sleep(10)

if __name__ == '__main__':
    main()

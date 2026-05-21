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
MINIMIZE_SCRIPT = '/home/lewis/Dev/config/xbindkeys/meta-wheel-minimize-wayland'
RESTORE_SCRIPT = '/home/lewis/Dev/config/xbindkeys/meta-wheel-restore-wayland'
CLOSE_SCRIPT = '/home/lewis/Dev/config/xbindkeys/meta-wheel-close-wayland'

# Global state
state = {
    'meta': False, 
    'shift': False, 
    'ctrl': False,
    'mouse_grabbed': False,
    'last_trigger': 0,
    'vm_pressed': set(),      # Buttons currently down on virtual mouse
    'physical_buttons': set(), # Buttons already down on the real mouse
    'swallow_middle': False
}
THROTTLE = 0.20

FORCED_BUTTON_RELEASES = {
    ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE,
    ecodes.BTN_SIDE, ecodes.BTN_EXTRA,
    ecodes.BTN_FORWARD, ecodes.BTN_BACK, ecodes.BTN_TASK,
}

def get_devices():
    physical_keyboards = []
    normalized_keyboard = None
    mice = []
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
            name = dev.name or ''
            if 'ydotool' in name or 'Virtual Mouse' in name:
                continue
            caps = dev.capabilities()
            if ecodes.EV_KEY in caps:
                keys = caps[ecodes.EV_KEY]
                if any(k in keys for k in [
                    ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA,
                    ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
                    ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
                ]):
                    if name == 'xremap normalized keyboard':
                        normalized_keyboard = dev
                    else:
                        physical_keyboards.append(dev)
            if ecodes.EV_REL in caps:
                if 'Mouse' in name and ecodes.REL_WHEEL in caps[ecodes.EV_REL]:
                    mice.append(dev)
        except:
            pass
    return ([normalized_keyboard] if normalized_keyboard else physical_keyboards), mice

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

                update_mouse_grab_state(mice_with_uis)
    except Exception as e:
        print(f"Keyboard worker error: {e}", file=sys.stderr)
        os._exit(75)

def mouse_worker(mouse, ui, mice_with_uis):
    try:
        for event in mouse.read_loop():
            is_grabbed = state['mouse_grabbed']
            is_pointer_button = event.type == ecodes.EV_KEY and event.code in FORCED_BUTTON_RELEASES
            if is_pointer_button:
                if event.value == 1:
                    state['physical_buttons'].add(event.code)
                elif event.value == 0:
                    state['physical_buttons'].discard(event.code)

            if event.type == ecodes.EV_REL and event.code in [ecodes.REL_WHEEL, 11, 120, 121]:
                if is_grabbed:
                    if event.code == ecodes.REL_WHEEL:
                        now = time.time()
                        if state['shift'] or (now - state['last_trigger'] > THROTTLE):
                            if state['meta']:
                                if event.value < 0: subprocess.Popen([MINIMIZE_SCRIPT])
                                elif event.value > 0: subprocess.Popen([RESTORE_SCRIPT])
                            elif state['shift']:
                                if event.value < 0: subprocess.Popen(['qdbus6', 'org.kde.kglobalaccel', '/component/kwin', 'invokeShortcut', 'view_zoom_out'])
                                elif event.value > 0: subprocess.Popen(['qdbus6', 'org.kde.kglobalaccel', '/component/kwin', 'invokeShortcut', 'view_zoom_in'])
                            state['last_trigger'] = now
            elif event.type == ecodes.EV_KEY and event.code == ecodes.BTN_MIDDLE:
                if event.value == 1:
                    if state['meta'] and state['ctrl']:
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
    keyboards, mice = get_devices()
    if not keyboards or not mice: sys.exit(1)
    mice_with_uis = []
    threads = []
    for m in mice:
        try:
            ui = evdev.UInput.from_device(m, name=m.name + " (Virtual Mouse)")
            mice_with_uis.append((m, ui))
            t = threading.Thread(target=mouse_worker, args=(m, ui, mice_with_uis), daemon=True)
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

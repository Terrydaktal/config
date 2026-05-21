#!/usr/bin/env python3
import evdev
from evdev import ecodes
import subprocess
import threading
import time
import sys
import signal

# Paths to scripts
MINIMIZE_SCRIPT = '/home/lewis/Dev/config/xbindkeys/meta-wheel-minimize-wayland'
RESTORE_SCRIPT = '/home/lewis/Dev/config/xbindkeys/meta-wheel-restore-wayland'
CLOSE_SCRIPT = '/home/lewis/Dev/config/xbindkeys/meta-wheel-close-wayland'
LAUNCH_SCRIPT = '/home/lewis/Dev/config/xbindkeys/launch-taskbar-app.sh'

# Global state
state = {
    'meta': False, 
    'shift': False, 
    'ctrl': False,
    'mouse_grabbed': False,
    'last_trigger': 0,
    'vk_pressed': set(),      # Keys currently down on virtual keyboard
    'vm_pressed': set(),      # Buttons currently down on virtual mouse
    'swallow_middle': False
}
THROTTLE = 0.20

FORCED_KEY_RELEASES = {
    ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
    ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
    ecodes.KEY_LEFTALT, ecodes.KEY_RIGHTALT,
    ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA,
}

FORCED_BUTTON_RELEASES = {
    ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE,
    ecodes.BTN_SIDE, ecodes.BTN_EXTRA,
    ecodes.BTN_FORWARD, ecodes.BTN_BACK, ecodes.BTN_TASK,
}

NUMBER_KEYS = {
    ecodes.KEY_1: '1', ecodes.KEY_2: '2', ecodes.KEY_3: '3',
    ecodes.KEY_4: '4', ecodes.KEY_5: '5', ecodes.KEY_6: '6',
    ecodes.KEY_7: '7', ecodes.KEY_8: '8', ecodes.KEY_9: '9'
}

def get_devices():
    keyboards = []
    mice = []
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
            caps = dev.capabilities()
            if ecodes.EV_KEY in caps:
                if ecodes.KEY_LEFTMETA in caps[ecodes.EV_KEY] or ecodes.KEY_RIGHTMETA in caps[ecodes.EV_KEY]:
                    keyboards.append(dev)
            if ecodes.EV_REL in caps:
                if ecodes.REL_WHEEL in caps[ecodes.EV_REL]:
                    mice.append(dev)
        except:
            pass
    return keyboards, mice

def safe_vk_release(vk):
    """Release tracked keys and common modifiers on a virtual keyboard."""
    if not vk: return
    for code in sorted(state['vk_pressed'] | FORCED_KEY_RELEASES):
        try:
            vk.write(ecodes.EV_KEY, code, 0)
        except: pass
    state['vk_pressed'].clear()
    try: vk.syn()
    except: pass

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

def keyboard_worker(kb, vk, mice_with_uis):
    try:
        kb.grab()
        for event in kb.read_loop():
            if event.type == ecodes.EV_KEY:
                if event.code in [ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA]:
                    state['meta'] = (event.value > 0)
                elif event.code in [ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT]:
                    state['shift'] = (event.value > 0)
                elif event.code in [ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL]:
                    state['ctrl'] = (event.value > 0)

                should_grab_mouse = state['meta'] or state['shift']
                if should_grab_mouse != state['mouse_grabbed']:
                    state['mouse_grabbed'] = should_grab_mouse
                    for m, ui in mice_with_uis:
                        try:
                            if should_grab_mouse:
                                m.grab()
                            else:
                                safe_vm_release(mice_with_uis)
                                time.sleep(0.01)
                                m.ungrab()
                        except: pass

                if state['meta'] and state['ctrl'] and event.code in NUMBER_KEYS:
                    if event.value == 1:
                        subprocess.Popen([LAUNCH_SCRIPT, NUMBER_KEYS[event.code]])
                    continue

                if event.value == 1: state['vk_pressed'].add(event.code)
                elif event.value == 0: state['vk_pressed'].discard(event.code)
                vk.write_event(event)
            elif event.type == ecodes.EV_SYN:
                vk.syn()
            else:
                vk.write_event(event)
    except Exception as e:
        print(f"Keyboard worker error: {e}", file=sys.stderr)
    finally:
        safe_vk_release(vk)
        try: kb.ungrab()
        except: pass

def mouse_worker(mouse, ui):
    try:
        for event in mouse.read_loop():
            is_grabbed = state['mouse_grabbed']
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
    except Exception as e:
        print(f"Mouse worker error: {e}", file=sys.stderr)

def main():
    keyboards, mice = get_devices()
    if not keyboards or not mice: sys.exit(1)
    mice_with_uis = []
    virtual_keyboards = []
    threads = []
    for m in mice:
        try:
            ui = evdev.UInput.from_device(m, name=m.name + " (Virtual Mouse)")
            mice_with_uis.append((m, ui))
            t = threading.Thread(target=mouse_worker, args=(m, ui), daemon=True)
            t.start()
            threads.append(t)
        except: pass
    for kb in keyboards:
        try:
            vk = evdev.UInput.from_device(kb, name=kb.name + " (Virtual Keyboard)")
            virtual_keyboards.append(vk)
            t = threading.Thread(target=keyboard_worker, args=(kb, vk, mice_with_uis), daemon=True)
            t.start()
            threads.append(t)
        except: pass
    def signal_handler(sig, frame):
        safe_vm_release(mice_with_uis)
        for vk in virtual_keyboards:
            safe_vk_release(vk)
        sys.exit(0)
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    while True: time.sleep(10)

if __name__ == '__main__':
    main()

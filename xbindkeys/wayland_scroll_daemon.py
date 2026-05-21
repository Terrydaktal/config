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
    'kb_pressed': set(),      # Keys currently down on physical keyboard
    'vk_pressed': set(),      # Keys currently down on virtual keyboard
    'vm_pressed': set(),      # Buttons currently down on virtual mouse
    'swallow_middle': False
}
THROTTLE = 0.20

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
                # Check for Meta key to identify main keyboard
                if ecodes.KEY_LEFTMETA in caps[ecodes.EV_KEY] or ecodes.KEY_RIGHTMETA in caps[ecodes.EV_KEY]:
                    keyboards.append(dev)
            if ecodes.EV_REL in caps:
                if ecodes.REL_WHEEL in caps[ecodes.EV_REL]:
                    mice.append(dev)
        except:
            pass
    return keyboards, mice

def safe_vk_release(vk):
    """Release all keys currently held on the virtual keyboard."""
    if not vk: return
    for code in list(state['vk_pressed']):
        try:
            vk.write(ecodes.EV_KEY, code, 0)
        except: pass
    state['vk_pressed'].clear()
    try:
        vk.syn()
    except: pass

def safe_vm_release(mice_with_uis):
    """Release all buttons currently held on virtual mice."""
    for m, ui in mice_with_uis:
        for code in list(state['vm_pressed']):
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
                # Update modifier states
                if event.code in [ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA]:
                    state['meta'] = (event.value > 0)
                elif event.code in [ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT]:
                    state['shift'] = (event.value > 0)
                elif event.code in [ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL]:
                    state['ctrl'] = (event.value > 0)

                # Handle Dynamic Mouse Grab (Only call on state CHANGE)
                should_grab_mouse = state['meta'] or state['shift']
                if should_grab_mouse != state['mouse_grabbed']:
                    state['mouse_grabbed'] = should_grab_mouse
                    for m, ui in mice_with_uis:
                        try:
                            if should_grab_mouse:
                                m.grab()
                            else:
                                m.ungrab()
                                # Prevent sticky mouse buttons when releasing modifiers
                                if state['vm_pressed']:
                                    for code in list(state['vm_pressed']):
                                        ui.write(ecodes.EV_KEY, code, 0)
                                        state['vm_pressed'].discard(code)
                                    ui.syn()
                        except: pass

                # Handle App Launching (Ctrl+Meta+Number) - Swallowed
                if state['meta'] and state['ctrl'] and event.code in NUMBER_KEYS:
                    if event.value == 1:
                        subprocess.Popen([LAUNCH_SCRIPT, NUMBER_KEYS[event.code]])
                    continue

                # Forward event to Virtual Keyboard
                if event.value == 1:
                    state['vk_pressed'].add(event.code)
                elif event.value == 0:
                    state['vk_pressed'].discard(event.code)
                
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
            
            # Handle Scroll Wheel
            if event.type == ecodes.EV_REL and event.code in [ecodes.REL_WHEEL, 11, 120, 121]:
                if is_grabbed:
                    if event.code == ecodes.REL_WHEEL:
                        now = time.time()
                        # Zoom (Shift) - No throttle
                        if state['shift']:
                            if now - state['last_trigger'] > 0.02: # Minimal throttle to avoid overwhelming DBus
                                if event.value < 0:
                                    subprocess.Popen(['qdbus6', 'org.kde.kglobalaccel', '/component/kwin', 'invokeShortcut', 'view_zoom_out'])
                                elif event.value > 0:
                                    subprocess.Popen(['qdbus6', 'org.kde.kglobalaccel', '/component/kwin', 'invokeShortcut', 'view_zoom_in'])
                                state['last_trigger'] = now
                        # Minimize/Restore (Meta) - Throttle applied
                        elif state['meta']:
                            if now - state['last_trigger'] > THROTTLE:
                                if event.value < 0:
                                    subprocess.Popen([MINIMIZE_SCRIPT])
                                elif event.value > 0:
                                    subprocess.Popen([RESTORE_SCRIPT])
                                state['last_trigger'] = now
                # If grabbed, swallow all wheel events
            
            # Handle Middle Click (Ctrl+Meta)
            elif event.type == ecodes.EV_KEY and event.code == ecodes.BTN_MIDDLE:
                if event.value == 1: # Down
                    if state['meta'] and state['ctrl']:
                        state['swallow_middle'] = True
                        subprocess.Popen([CLOSE_SCRIPT])
                    else:
                        state['swallow_middle'] = False
                        if is_grabbed:
                            ui.write_event(event)
                            state['vm_pressed'].add(event.code)
                elif event.value == 0: # Up
                    if state['swallow_middle']:
                        state['swallow_middle'] = False
                    elif is_grabbed:
                        ui.write_event(event)
                        state['vm_pressed'].discard(event.code)
            
            # Forward all other mouse events
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
    if not keyboards or not mice:
        print("Required devices not found.", file=sys.stderr)
        sys.exit(1)

    mice_with_uis = []
    threads = []

    # Setup Mice
    for m in mice:
        try:
            ui = evdev.UInput.from_device(m, name=m.name + " (Virtual Mouse)")
            mice_with_uis.append((m, ui))
            t = threading.Thread(target=mouse_worker, args=(m, ui), daemon=True)
            t.start()
            threads.append(t)
        except Exception as e:
            print(f"Mouse UI setup failed: {e}", file=sys.stderr)

    # Setup Keyboard
    for kb in keyboards:
        try:
            vk = evdev.UInput.from_device(kb, name=kb.name + " (Virtual Keyboard)")
            t = threading.Thread(target=keyboard_worker, args=(kb, vk, mice_with_uis), daemon=True)
            t.start()
            threads.append(t)
        except Exception as e:
            print(f"Keyboard UI setup failed: {e}", file=sys.stderr)

    # Global signal handling for clean exit
    def signal_handler(sig, frame):
        print("\nShutdown requested...", file=sys.stderr)
        safe_vm_release(mice_with_uis)
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    print("Wayland Unified Daemon running (Anti-Stick 2.0).")
    while True:
        time.sleep(10)

if __name__ == '__main__':
    main()

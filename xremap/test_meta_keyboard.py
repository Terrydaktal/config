"""Check shortcut isolation without reading input devices or invoking actions."""

import sys
import unittest
from pathlib import Path

import yaml


MOUSE = "/dev/input/by-id/usb-04d9_USB_Gaming_Mouse-if01-event-kbd"
LAUNCHER_KEYS = {"Super-grave", "C-grave", "C-Super-grave"}
SCOPED_LAUNCH = "/home/lewis/Dev/config/bin/xremap-launch-scoped"
LAUNCHER = {"launch": [SCOPED_LAUNCH, "/home/lewis/.local/bin/applicationlauncher"]}
DEPTH_PREVIEW = {
    "launch": [
        "/usr/bin/qdbus6",
        "org.kde.kglobalaccel",
        "/component/kwin",
        "org.kde.kglobalaccel.Component.invokeShortcut",
        "ToggleDesktopDepthPreview",
    ]
}
CONFIG_PATHS = [Path(path) for path in sys.argv[1:]] or [
    Path(__file__).with_name("meta-keyboard.yml")
]


class MouseShortcutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.configs = [yaml.safe_load(path.read_text()) for path in CONFIG_PATHS]
        cls.maps = [mapping for config in cls.configs for mapping in config["keymap"]]

    def test_only_one_override_before_shared_map(self):
        self.assertEqual(len(self.maps), 2)
        self.assertEqual(self.maps[0]["device"], {"only": MOUSE})
        self.assertNotIn("device", self.maps[1])

    def test_override_is_limited_to_exact_launcher_combinations(self):
        self.assertTrue(self.maps[0].get("exact_match"))
        self.assertEqual(set(self.maps[0]["remap"]), LAUNCHER_KEYS)

    def test_mouse_calls_existing_depth_action_without_synthetic_keys(self):
        for key in LAUNCHER_KEYS:
            with self.subTest(key=key):
                self.assertEqual(self.maps[0]["remap"][key], DEPTH_PREVIEW)

    def test_keyboard_launcher_shortcuts_still_launch_applicationlauncher(self):
        for key in LAUNCHER_KEYS:
            with self.subTest(key=key):
                self.assertEqual(self.maps[-1]["remap"][key], LAUNCHER)

    def test_other_shared_shortcuts_are_unchanged(self):
        expected = {key: LAUNCHER for key in LAUNCHER_KEYS}
        expected.update({
            "KEY_KPENTER": None,
            "C-w": None,
            "C-Shift-Up": "F24",
            "C-Shift-Super-Up": "F24",
            "Super-5": {
                "launch": [SCOPED_LAUNCH, "/home/lewis/Dev/config/bin/activate-or-launch-chrome.sh"]
            },
        })
        for prefix in ("C-", "C-Super-"):
            for slot in range(1, 10):
                command = ["/home/lewis/Dev/config/bin/launch-taskbar-app.sh", str(slot)]
                if prefix == "C-Super-" and slot == 4:
                    command = ["/home/lewis/Dev/config/bin/firefox-new-window-fast"]
                expected[f"{prefix}{slot}"] = {"launch": [SCOPED_LAUNCH, *command]}
        self.assertEqual(self.maps[-1]["remap"], expected)
        self.assertTrue(self.maps[-1].get("exact_match"))

    def test_no_modifiers_or_other_input_options_are_remapped(self):
        for config in self.configs:
            self.assertEqual(set(config), {"keymap"})
        self.assertEqual(set(self.maps[0]), {"name", "device", "exact_match", "remap"})
        self.assertEqual(set(self.maps[-1]), {"name", "exact_match", "remap"})


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])

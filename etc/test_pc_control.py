"""Unit tests for pc-control (stdlib unittest, no desktop required)."""

from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "pc-control"

_loader = SourceFileLoader("pc_control", str(CLI))
_spec = importlib.util.spec_from_loader(_loader.name, _loader)
pc = importlib.util.module_from_spec(_spec)
_loader.exec_module(pc)


class TmpState(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self._old = os.environ.get("PC_STATE_DIR")
        os.environ["PC_STATE_DIR"] = self._tmp.name
        pc._STATE = None

    def tearDown(self):
        if self._old is None:
            os.environ.pop("PC_STATE_DIR", None)
        else:
            os.environ["PC_STATE_DIR"] = self._old
        pc._STATE = None

    def write_shot(self, **meta):
        base = {
            "path": "/tmp/x.jpg", "width": 1280, "height": 720,
            "native_width": 1920, "native_height": 1080,
            "scale_x": 1.5, "scale_y": 1.5, "offset_x": 0, "offset_y": 0,
            "mappable": True,
        }
        base.update(meta)
        (Path(self._tmp.name) / "last-shot.json").write_text(json.dumps(base), encoding="utf-8")


class KeyMapTests(unittest.TestCase):
    def test_modifier_combo(self):
        self.assertEqual(pc.parse_keys("ctrl+shift+s"), [29, 42, 31])

    def test_function_and_named(self):
        self.assertEqual(pc.parse_keys("f11"), [87])
        self.assertEqual(pc.parse_keys("space"), [57])

    def test_unknown_key_raises(self):
        with self.assertRaises(pc.PcError):
            pc.parse_keys("nope")

    def test_empty_raises(self):
        with self.assertRaises(pc.PcError):
            pc.parse_keys("+")

    def test_digit_codes(self):
        self.assertEqual(pc.parse_keys("1"), [2])
        self.assertEqual(pc.parse_keys("0"), [11])


class ButtonTests(unittest.TestCase):
    def test_left(self):
        self.assertEqual(pc.BUTTONS["left"], (0xC0, 0x110))

    def test_right_middle(self):
        self.assertEqual(pc.BUTTONS["right"][1], 0x111)
        self.assertEqual(pc.BUTTONS["middle"][1], 0x112)


class MappingTests(TmpState):
    def test_compact_maps_to_native(self):
        self.write_shot()
        self.assertEqual(pc.map_shot_point(640, 360), (960.0, 540.0))

    def test_region_offset(self):
        self.write_shot(scale_x=1.0, scale_y=1.0, offset_x=100, offset_y=100,
                        native_width=400, native_height=300)
        self.assertEqual(pc.map_shot_point(50, 50), (150.0, 150.0))

    def test_native_bypass(self):
        self.write_shot()
        self.assertEqual(pc.map_shot_point(640, 360, native=True), (640, 360))

    def test_no_shot_is_identity(self):
        self.assertEqual(pc.map_shot_point(12, 34), (12, 34))

    def test_window_shot_refuses(self):
        self.write_shot(mappable=False)
        with self.assertRaises(pc.PcError) as ctx:
            pc.map_shot_point(1, 2)
        self.assertIn("window-only", str(ctx.exception))


class StateTests(TmpState):
    def test_env_override(self):
        self.assertEqual(str(pc.state_dir()), self._tmp.name)

    def test_shots_dir_created(self):
        path = pc.shots_dir()
        self.assertTrue(path.is_dir())


class OcrLangTests(unittest.TestCase):
    def test_prefers_locale(self):
        with mock.patch.object(pc, "ocr_languages", return_value=["rus", "osd"]), \
             mock.patch.dict(os.environ, {"LANG": "ru_RU.UTF-8"}, clear=False):
            self.assertEqual(pc.pick_ocr_lang(None), "rus")

    def test_falls_back_to_eng(self):
        with mock.patch.object(pc, "ocr_languages", return_value=["eng", "rus"]), \
             mock.patch.dict(os.environ, {"LANG": "de_DE.UTF-8"}, clear=False):
            self.assertEqual(pc.pick_ocr_lang(None), "eng")

    def test_missing_requested_raises(self):
        with mock.patch.object(pc, "ocr_languages", return_value=["rus"]):
            with self.assertRaises(pc.PcError):
                pc.pick_ocr_lang("eng")


class CliTests(unittest.TestCase):
    def test_version(self):
        out = subprocess.run([sys.executable, str(CLI), "--version"],
                             capture_output=True, text=True, check=True)
        self.assertIn(pc.VERSION, out.stdout)

    def test_help(self):
        out = subprocess.run([sys.executable, str(CLI), "--help"],
                             capture_output=True, text=True, check=True)
        self.assertIn("shot", out.stdout)

    def test_tf2_launcher_removed(self):
        out = subprocess.run([sys.executable, str(CLI), "--help"],
                             capture_output=True, text=True, check=True)
        self.assertNotIn("launch", out.stdout)
        self.assertNotIn("tf2", out.stdout.lower())


if __name__ == "__main__":
    unittest.main()

# Contributing to pc-control

Thanks for helping. The project is intentionally small: one Python CLI, one
setup script, docs, and tests.

## Layout

```
pc-control       single-file CLI (stdlib; Pillow for compact shots)
setup-uinput.sh  one-time root setup for uinput + ydotool
install.sh       user-level installer (CLI + skill)
setup-humanwatch.sh  optional root service: physical input timestamps
scripts/humanwatch.py  the evdev watcher
etc/SKILL.md     DeepSeek Harness skill
etc/USAGE.md     generic agent instructions
etc/test_pc_control.py
pyproject.toml   pip/pipx packaging (script-files)
```

## Run it locally

```bash
./install.sh --local
./.pc-control/bin/pc-control doctor
./.pc-control/bin/pc-control shot
```

`setup-uinput.sh` needs sudo once; don't run it in CI.

## Tests

```bash
python3 -m unittest discover -s etc -v
```

The suite is host-independent: no desktop, screenshots, or daemon required.
Please add a test for any pure logic you change (key mapping, coordinate
mapping, OCR language selection, CLI surface).

## Style

- Keep the CLI a single file with stdlib imports; Pillow is the only optional
  runtime dependency and must degrade gracefully.
- One JSON object per invocation; failures exit non-zero with `error` and
  `hint`.
- Don't hardcode personal paths, usernames, monitors, or games.
- Keep `README.md`, `etc/SKILL.md`, and `etc/USAGE.md` in sync when commands
  change.

## Smoke test

Spawn a fresh agent (no conversation history) with the `pc-control` skill and a
read-only task: `doctor`, `shot --ocr`, move to the center of the image,
`cursor`, `active`. Check that it does not pre-scale coordinates, guesses the
helper path correctly, and reports the JSON shape without hints. Rerun after
changing the skill or the JSON contract.

## Debugging ignored clicks

Take a fresh screenshot before concluding that a click was swallowed. Collapsed
sidebars, hidden panels, and moved windows change the layout, so coordinates
from an older shot can land on empty space. `pc-control` clicks in the pixel
space of the latest shot; it has no semantic model of the UI.

## Screenshot backends

Add a branch in `capture()` and to `SCREENSHOT_BACKENDS`. Full-screen capture is
required; window/region may fall back with a `warning`. Test at least the
full-screen path.

## Pull requests

- Describe the user-visible change and the test you ran.
- Keep commits focused; update `etc/CHANGELOG.md`.
- CI must pass on Python 3.10 and 3.12.
- For behavior that needs a desktop, say what you tested and what you couldn't
  (GNOME, multi-monitor, etc. are known gaps).

## Packaging

```bash
python3 -m pip wheel . --no-deps -w dist
```

The console script is installed from `pc-control` via
`[tool.setuptools] script-files`.

## License

By contributing you agree your changes are licensed under MIT.

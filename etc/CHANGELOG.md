# Changelog

## 0.3.1

- Added `pyproject.toml` packaging (`pip install .` / `pipx install .`).
- Clarified that the CLI is harness-agnostic; added contribution and issue
  templates, plus a demo GIF.
- Removed the TF2-specific launcher (0.3.0).

## 0.3.0

- Removed the TF2-specific `launch` command; start games yourself and use the
  desktop launcher (`key meta`, `type "name"`, `key enter`) for apps.
- Moved docs, tests, and the skill under `etc/`.

## 0.2.0

- Compact screenshots by default (1280 px wide, JPEG) with automatic mapping
  from image coordinates back to native pixels.
- `shot --region`, `--ocr`, `--window`, `--grid`, `--full`, `--max-width`.
- KWin-backed `focus`, `active`, and live cursor feedback with adaptive
  acceleration compensation.
- Portable state directory (`PC_STATE_DIR`, default `./.pc-control`).
- Screenshot backend detection: spectacle, grim, gnome-screenshot, wayshot,
  scrot, ImageMagick import.
- `install.sh` (CLI + skill), distro-agnostic `setup-uinput.sh`, unit tests,
  GitHub Actions, LLM docs.

## 0.1.0

- Initial single-file CLI: screenshots, absolute/relative mouse, clicks,
  keyboard, typing, scrolling, batching, TF2 launch.

# Changelog

## 0.4.0

- Human takeover: `pause`/`resume`/`status` use a cwd-independent control file;
  every mutating call refuses to run while paused.
- `click --at` re-reads the cursor before pressing and cancels with
  `human_override` if it moved more than 3 px; it reports `verified`.
- 29 unit tests.

## 0.3.3

- Fixed OCR language selection: locale aliases (`ru`→`rus`, `en`→`eng`) and no
  silent fallback to an unrelated installed language; `shot` now reports
  `ocr_lang` and returns `ocr_error` when nothing matches.
- `doctor` returns structured `display` and `ocr_languages` fields.
- Fixed the README checkout command and documented response field names.

## 0.3.2

- Clarified the helper path (`./pc-control` in a checkout, `pc-control` when
  installed) and the difference between display scale and shot downscale.
- `doctor` now lists installed Tesseract languages and labels display/sandbox
  details more clearly.
- Documented OCR language limits and mixed-script behavior.

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

# Changelog

## 0.8.1

- Removed the `.desktop` menu-entry creation; screenshots remain a CLI command.
- Human screenshots now follow the XDG Pictures setting from
  `~/.config/user-dirs.dirs` / `xdg-user-dir`, so `~/Изображения` works.
- Added tests for XDG Pictures resolution.

## 0.8.0

- Human mode: `pc-control screenshot` saves a full-resolution PNG to
  `~/Pictures/pc-control/`, opens it, and prints one sentence.
- `shot` switches to the same human behavior on a TTY; `--json` forces JSON.
- `doctor` prints a plain summary on a TTY; `--json` forces the structured form.
- Friendly plain-text errors in human mode.
- 49 unit tests.

## 0.7.0

- Clicks without KWin cursor feedback now refuse with `no_feedback` unless
  `--allow-approximate` is explicitly passed.
- Temporary `/tmp` state now fails loudly (`state_temporary`); `doctor` marks it.
- Lease `status` exposes `valid`/`expired`; `claim --wait` queues for the lease.
- OCR is capped (`PC_OCR_MAX_CHARS`, default 4000) with `ocr_chars`/
  `ocr_truncated`.
- `run` holds a lease and renews it around `wait`.
- `doctor` checks a running KWin session and reports watcher input age.
- `install.sh --socket` is honored through `/etc/pc-control/socket`.
- 43 unit tests.

## 0.6.1

- `install.sh --system` now installs `pc-control` to `/usr/local/bin` and the
  skill for the target user, so one sudo command covers PATH, skill, and host
  services. `--no-cli` keeps the CLI where it is.
- `--system --uninstall` removes the system CLI and the target user's skill.

## 0.6.0

- Unified `install.sh`: user install by default, `--system` for uinput +
  ydotool + ydotoold + humanwatch; `--uninstall` for either. Removed the two
  setup scripts.
- Lease coordination: `claim`/`renew`/`release`; every mutating call takes or
  renews a 15 s lease; a second owner gets `lease_busy`.
- Lease identity from `PC_AGENT_ID`, `DSH_SESSION_ID`, or the parent PID; the
  lease file lives in the shared state dir.
- 36 unit tests.

## 0.5.0

- Optional `setup-humanwatch.sh` root service: physical mouse/keyboard activity
  is timestamped (never key contents) and mutating calls yield with
  `human_active` until `PC_HUMAN_IDLE_MS` (default 800 ms).
- `status` reports `human_active`/`human_idle_ms`; `doctor` reports the watcher.
- Documented that pause/human_active do not coordinate two agents; a lease is
  the next stage.
- 32 unit tests.

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

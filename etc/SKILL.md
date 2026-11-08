---
name: pc-control
description: Use when the user asks to see, click, type in, or otherwise operate the local Linux desktop or a native app/game on it (screenshots, mouse, keyboard, app switching). Works on KDE/GNOME/wlroots under Wayland or X11; not for browser pages, files, or shell-only work.
---

# PC control

Human guide: `etc/HUMAN.md`. For a human, `pc-control screenshot` saves a PNG to Pictures, opens it, and
prints one sentence. The agent contract below uses `shot`/`--json`; on a TTY
`shot` switches to human output, so pass `--json` if you need JSON from an
interactive terminal.

Helper: `pc-control` if it is on PATH (`sudo ./install.sh --system` puts it in `/usr/local/bin`); otherwise `~/.local/bin/pc-control`. In a source checkout `./pc-control` also works. Examples below use `pc-control`; substitute the full path if needed. Every call prints **one JSON object**; non-zero exit means failure. Screenshots come from the compositor; mouse/keyboard come from `ydotool` (uinput), which games see as a real device.

## Before acting

```bash
pc-control doctor
```

- `ready: true` → go ahead.
- `ydotool` / `ydotoold` false → ask the user to run once: `sudo ./install.sh --system` (needs sudo; never run sudo yourself).
- `screenshot` false → ask the user to install a backend (`spectacle`, `grim`, `gnome-screenshot`, `wayshot`, or `scrot`).
- `kwin` false → cursor/focus feedback is unavailable; `move` becomes approximate and `click` refuses unless `--allow-approximate`.
- `state_temporary` → state fell back to `/tmp` (not host-visible); set `PC_STATE_DIR` to a workspace path.

## Screenshots and tokens (important)

The default shot is **downscaled to 1280 px wide and JPEG-encoded** to save vision tokens. Coordinates are always in the **returned image's pixel space**; `move`/`click` map them back to native pixels automatically. **Never scale coordinates yourself.**

```bash
pc-control shot                  # compact 1280×720 JPEG (default)
pc-control shot --grid           # same size + 100 px grid, labels in image px
pc-control shot --region X Y W H # crop a native-pixel region (great for detail)
pc-control shot --window         # active window only — reading only, not clickable
pc-control shot --ocr            # add OCR text to JSON; no need to read the image
pc-control shot --ocr --ocr-max-chars 2000  # cap OCR text (default 4000)
pc-control shot --full           # native PNG when quality matters
pc-control shot --out path.jpg
```

Token strategy:
1. Prefer `--ocr` for text-heavy screens (terminals, logs, settings) — read `ocr` instead of the image.
2. Prefer `--region` around the control you need instead of the whole screen.
3. Use the default compact shot for layout; request `--grid` only when picking coordinates precisely.
4. `--window` is for reading an app; take a full shot before clicking because window pixels cannot be mapped to the screen.
5. OCR is best-effort and depends on installed Tesseract languages. Set `--ocr-lang` or `PC_OCR_LANG`; the helper maps `ru`→`rus`, `en`→`eng`, and returns `ocr_error` instead of guessing a wrong language. Mixed or Cyrillic UI can still transliterate.

## Coordinates

- Pass pixels from the latest screenshot **unchanged**. The helper maps shot pixels → native pixels → the compositor's **logical** input coordinates. Never scale manually.
- Two scales exist: **shot `scale_x`** (e.g. 1.5) is the downscale factor, and **display scale** (e.g. 1.25) converts native to logical input. The helper applies both.
- If `mappable` is `false` (window shot), take a full shot or pass `--native`.
- `cursor` reports `logical`, `native`, and `shot` coordinates.
- `move` is closed-loop (measure → step → re-measure); it lands within ~2 px in ~1–3 s. A `warning` means it did not converge — take a shot and verify before clicking.
- `move-rel DX DY` is raw relative motion (no mapping); use it for game mouse-look.
- JSON fields: `move` → `screenshot_xy`, `target` (logical), `target_native`, `cursor` (logical), `cursor_native`, `error`, `attempts`; `cursor` → `logical`, `native`, `shot`, `scale`, `offset`, `display_scale`; `shot` → `path`, `width`, `height`, `scale_x`, `ocr_lang`; `click --at` → `verified`.

## Safety

- **Never click the top ~50 px of a window** (title bar / minimize / maximize / close). A stray click there hides the app. Use `focus PATTERN` to restore or switch windows.
- Do not click a target you have not seen in the latest screenshot.
- Settings/plugin pages can swallow sidebar clicks; prefer `focus`, keyboard shortcuts, or ask the user.
- Never touch password fields, payment dialogs, or destructive buttons. After 3 failed attempts at one target, stop and report.

## Human takeover

The human can pause all mutating actions at any time. This is intentional;
never work around it.

```bash
pc-control pause --reason "user took over"   # human, on the host
pc-control status
pc-control resume                            # human only
```

- While paused, `move`, `move-rel`, `click`, `down`/`up`, `key`, `type`, `scroll`
  and `focus` return `{"ok":false,"error":"human_paused"}`. Read-only calls
  (`shot`, `cursor`, `active`, `screen`, `doctor`, `status`) still work.
- `click --at` re-reads the cursor immediately before pressing. If it moved
  more than 3 px, it returns `error:"human_override"` and does **not** click.
  Without KWin feedback it returns `error:"no_feedback"` unless
  `--allow-approximate` is passed.
- On `human_paused` or `human_override`: stop immediately, do not retry, tell
  the human, and wait for an explicit `resume`.
- Do not run `pause`/`resume` yourself; the human owns that channel.
- The system install includes a humanwatch service. If **physical** mouse/keyboard
  input is within `PC_HUMAN_IDLE_MS` (default 800 ms), the first mutating call
  sends a desktop notification and waits `PC_TAKEOVER_GRACE_MS` (default 8000)
  before acting. `pc-control pause` during that countdown cancels the action.
  No notification or delay occurs when the human is idle. After the warning the
  action proceeds; pause still wins. `error:"human_active"` only appears when
  the grace is disabled (`PC_TAKEOVER_GRACE_MS=0`). The watcher stores only
  timestamps, never key contents.
- Pause and `human_active` are global. A **lease** coordinates agents: mutating
  calls auto-acquire a 15 s lease (`PC_LEASE_TTL_MS`), and a second owner gets
  `error:"lease_busy"`. Use `claim --ttl 60 --wait` for a long task, `renew`,
  and `release` when done. `status` reports `lease.valid`/`expired`; an expired
  lease is not ownership. The lease lives in the shared state dir (`PC_STATE_DIR`).

## The loop

```bash
pc-control shot --grid                                   # 1. see
pc-control click left --at 640 360                       # 2. act (image px)
pc-control key ctrl+s                                     #    keyboard
pc-control type "hello"                                   #    ASCII / US layout
pc-control scroll -3
pc-control wait 500
pc-control shot                                           # 3. verify
```

Batch predictable actions into one call:

```bash
pc-control run '[{"action":"shot","ocr":true},
  {"action":"move","x":640,"y":360},{"action":"click"},
  {"action":"wait","ms":300},{"action":"shot"}]'
```

`run` accepts `shot`, `move`, `move-rel`, `click`, `down`, `up`, `key`, `type`, `scroll`, `wait`, `focus`, `active`, `cursor`, `screen`, `status`.

## Windows and apps

```bash
pc-control active                 # caption + class of the focused window
pc-control focus konsole          # unminimize + activate by caption/class (KDE)
```

Launch an app through the desktop launcher:

```bash
pc-control key meta
pc-control type "konsole"
pc-control key enter
```

## Games

- Start the game yourself on the host.
- Look: `move-rel 120 0` (raw relative; games read it as mouse motion).
- Move: `key w --hold 1000`; jump `key space`; crouch `key ctrl --hold 500`.
- Fire: `down left` … `up left`; scope `down right`; tap `click left`.
- Menus: `key escape`, `key tab`, arrows; `key alt+tab`.
- Each observe→act cycle is ~1–3 s: suited to walking, menus, chat — not live aiming.
- Anti-cheat/ToS rules apply; prefer offline/private servers.

## Commands

```text
doctor [--json] | screenshot [...] | screen
shot [--window|--screen] [--region X Y W H] [--grid] [--ocr] [--ocr-max-chars N]
       | [--full] [--max-width N] [--out PATH]
move X Y [--native] [--scaled] [--dry-run]
move-rel DX DY [--dry-run]
click [left|right|middle|side|extra] [--double] [--at X Y] [--native]
      [--allow-approximate] [--dry-run]
down|up [button]
key KEYS [--hold MS] [--dry-run]      # ctrl+s, space, alt+F4, f1...
type TEXT                             # US layout / ASCII
scroll N [--horizontal]               # negative = down
wait MS
run JSON [--continue-on-error]
active | cursor | focus PATTERN
pause [--reason TEXT] | resume | status
claim [--ttl SECONDS] [--force] [--wait] [--timeout SECONDS]
renew [--ttl SECONDS] | release [--force]
```

## Failure handling

- `ydotool failed` → run `doctor`, read `hint`, report; do not retry blindly.
- `no screenshot backend` → ask the user to install one.
- `move` warning → take a fresh shot and verify the pointer's effect.
- `focus` `NOTFOUND` → try a shorter caption fragment or the resource class.
- OCR errors are non-fatal: the image path is still returned in `path`.

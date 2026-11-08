---
name: pc-control
description: Use when the user asks to see, click, type in, or otherwise operate the local Linux desktop or a native app/game on it (screenshots, mouse, keyboard, app switching). Works on KDE/GNOME/wlroots under Wayland or X11; not for browser pages, files, or shell-only work.
---

# PC control

Helper: `pc-control` (or `./pc-control/pc-control` in a checkout). Every call prints **one JSON object**; non-zero exit means failure. Screenshots come from the compositor; mouse/keyboard come from `ydotool` (uinput), which games see as a real device.

## Before acting

```bash
pc-control doctor
```

- `ready: true` → go ahead.
- `ydotool` / `ydotoold` false → ask the user to run once: `sudo ./setup-uinput.sh` (needs sudo; never run sudo yourself).
- `screenshot` false → ask the user to install a backend (`spectacle`, `grim`, `gnome-screenshot`, `wayshot`, or `scrot`).
- `kwin` false → cursor/focus feedback is unavailable; `move` becomes approximate. Basic input still works.

## Screenshots and tokens (important)

The default shot is **downscaled to 1280 px wide and JPEG-encoded** to save vision tokens. Coordinates are always in the **returned image's pixel space**; `move`/`click` map them back to native pixels automatically. **Never scale coordinates yourself.**

```bash
pc-control shot                  # compact 1280×720 JPEG (default)
pc-control shot --grid           # same size + 100 px grid, labels in image px
pc-control shot --region X Y W H # crop a native-pixel region (great for detail)
pc-control shot --window         # active window only — reading only, not clickable
pc-control shot --ocr            # add OCR text to JSON; no need to read the image
pc-control shot --full           # native PNG when quality matters
pc-control shot --out path.jpg
```

Token strategy:
1. Prefer `--ocr` for text-heavy screens (terminals, logs, settings) — read `ocr` instead of the image.
2. Prefer `--region` around the control you need instead of the whole screen.
3. Use the default compact shot for layout; request `--grid` only when picking coordinates precisely.
4. `--window` is for reading an app; take a full shot before clicking because window pixels cannot be mapped to the screen.

## Coordinates

- Pass pixels from the latest screenshot **unchanged**. The helper stores the shot geometry and converts to native pixels.
- If `mappable` is `false` (window shot), take a full shot or pass `--native`.
- `cursor` reports both `native` and `shot` coordinates in the latest shot's space.
- `move` is closed-loop (measure → step → re-measure); it lands within ~2 px in ~1–3 s. A `warning` means it did not converge — take a shot and verify before clicking.
- `move-rel DX DY` is raw relative motion (no mapping); use it for game mouse-look.

## Safety

- **Never click the top ~50 px of a window** (title bar / minimize / maximize / close). A stray click there hides the app. Use `focus PATTERN` to restore or switch windows.
- Do not click a target you have not seen in the latest screenshot.
- Settings/plugin pages can swallow sidebar clicks; prefer `focus`, keyboard shortcuts, or ask the user.
- Never touch password fields, payment dialogs, or destructive buttons. After 3 failed attempts at one target, stop and report.

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

`run` accepts `shot`, `move`, `move-rel`, `click`, `down`, `up`, `key`, `type`, `scroll`, `wait`, `focus`, `active`, `cursor`, `screen`.

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
doctor | screen | shot [--window|--screen] [--region X Y W H] [--grid] [--ocr]
       | [--full] [--max-width N] [--out PATH]
move X Y [--native] [--scaled] [--dry-run]
move-rel DX DY [--dry-run]
click [left|right|middle|side|extra] [--double] [--at X Y] [--native] [--dry-run]
down|up [button]
key KEYS [--hold MS] [--dry-run]      # ctrl+s, space, alt+F4, f1...
type TEXT                             # US layout / ASCII
scroll N [--horizontal]               # negative = down
wait MS
run JSON [--continue-on-error]
active | cursor | focus PATTERN
```

## Failure handling

- `ydotool failed` → run `doctor`, read `hint`, report; do not retry blindly.
- `no screenshot backend` → ask the user to install one.
- `move` warning → take a fresh shot and verify the pointer's effect.
- `focus` `NOTFOUND` → try a shorter caption fragment or the resource class.
- OCR errors are non-fatal: the image path is still returned in `path`.

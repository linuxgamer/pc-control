# Using pc-control from an LLM agent

Humans should start with [`HUMAN.md`](HUMAN.md).

`pc-control` is a single CLI that prints one JSON object per call. It is
harness-agnostic: any agent with shell access and image reading can drive a
Linux desktop through it. This file is the generic integration guide.

## Readiness

```bash
pc-control doctor
```

Run `pc-control` when it is on PATH (`/usr/local/bin` after `sudo ./install.sh --system`), otherwise `~/.local/bin/pc-control`; in a source checkout `./pc-control` also works.

`ready: true` means screenshots and input are available. If `ydotool` /
`ydotoold` fail, a human must run `sudo ./install.sh --system` once. Never run sudo
from the agent.

## System-prompt snippet

> You can operate the local desktop with `pc-control`. Call `pc-control doctor`
> first. Use `shot` to see the screen (it returns a compact JPEG plus its path;
> read the image only when `--ocr` text is not enough). Coordinates are pixels
> in the returned image; pass them unchanged to `move` / `click --at` — the tool
> maps them to native pixels. Act in small verified steps: shot → act → shot.
> Never click the top 50 px of a window (title bar), never type into password
> fields, and stop after three failed attempts at one target.

## Token strategy

| Need | Call | Why |
|---|---|---|
| Text-heavy screen | `shot --ocr` | Returns `ocr` text; read it instead of the image |
| One control | `shot --region X Y W H` | Small crop, fewer image tokens |
| Layout overview | `shot` | 1280-wide JPEG by default |
| Precise coordinates | `shot --grid` | 100 px grid, labels in image pixels |
| Read an app window | `shot --window` | Smaller, but **not clickable** |
| Native quality | `shot --full` | 1920×1080 PNG, more tokens |

The default is already compact (max width 1280, JPEG q72). OCR is capped at
`PC_OCR_MAX_CHARS` (default 4000; `0` disables) and reports `ocr_chars` /
`ocr_truncated`. Do not upscale or re-encode the returned image; pass its pixels
directly.

## JSON contract

Success:

```json
{"ok":true,"path":"...jpg","width":1280,"height":720,
 "native_width":1920,"native_height":1080,
 "scale_x":1.5,"scale_y":1.5,"offset_x":0,"offset_y":0,
 "kind":"full","mappable":true,"format":"jpg","bytes":78251}
```

Failure (exit 1):

```json
{"ok":false,"command":"move","error":"...","hint":"..."}
```

OCR is best-effort: it depends on the installed Tesseract languages
(`--ocr-lang` / `PC_OCR_LANG`), and mixed or Cyrillic UI can transliterate.
Locale codes are mapped (`ru`→`rus`, `en`→`eng`); if no language matches,
the shot returns `ocr_error` instead of silently using an unrelated language.

`shot --ocr` adds `ocr` (string), `ocr_lang` (the language actually used), or
`ocr_error`. A window shot has `"mappable":false` and cannot be used for
coordinates.

Response fields:

| Call | Fields |
|---|---|
| `shot` | `path`, `width`, `height`, `native_width`, `native_height`, `scale_x`, `scale_y`, `offset_x`, `offset_y`, `mappable`, `ocr`, `ocr_lang`, `ocr_error` |
| `move` | `screenshot_xy` (input), `target` (logical), `target_native`, `cursor` (logical), `cursor_native`, `error`, `attempts` |
| `cursor` | `logical`, `native`, `shot`, `scale`, `offset`, `display_scale` (no `error`; it has no target) |

## Coordinate rule

Never scale manually. `move` / `click --at` read the last shot's
`scale_x`, `scale_y`, `offset_x`, `offset_y`, map to native pixels, then convert
native → logical for the compositor. `--scaled` instead takes logical (window
decoration) coordinates. If the last shot was `--window`, either take a full shot
or pass `--native`.

## Human control

The human can pause all mutating actions from a host terminal:

```bash
pc-control pause --reason "user took over"
pc-control status
pc-control resume
```

Pause lives in `$XDG_RUNTIME_DIR/pc-control/pause.json` (fallback
`~/.cache/pc-control/`), so it is independent of the agent's cwd. While paused,
mutating calls return `error:"human_paused"`; read-only calls still work. The
agent must stop and ask, never retry or resume on its own.

`click --at` re-reads the cursor right before pressing. If it moved more than
3 px, the click is cancelled with `error:"human_override"`. Without KWin feedback
the click is refused with `error:"no_feedback"` unless `--allow-approximate` is
passed; then `verified` is `false`.

The system install includes a humanwatch service; physical
input is detected through evdev. Mutating calls then fail with
`error:"human_active"` while the last physical event is younger than
`PC_HUMAN_IDLE_MS` (default 800). `status` reports `human_idle_ms`. The watcher
writes only a timestamp to `/run/pc-control/human-UID` — never key codes or
text.

Error codes: `human_paused`, `human_override`, `human_active`, `lease_busy`,
`state_temporary`, `no_feedback`.

### Concurrency

Pause and `human_active` are global. For two automation clients, use the lease:

```bash
pc-control claim --ttl 60 --wait   # owner, expiry, heartbeat via renew
pc-control status             # {"lease": {...}}
pc-control renew --ttl 60
pc-control release
```

Every mutating call automatically takes/renews a 15 s lease
(`PC_LEASE_TTL_MS`). A second owner gets `error:"lease_busy"` until the holder
releases or the lease expires; `claim --wait` queues instead of failing.
`status` exposes `lease.valid`/`lease.expired` so an expired lease is never
mistaken for ownership. `--force` steals it. Identity comes from
`PC_AGENT_ID`, then `DSH_SESSION_ID`, then the parent PID; the lease file lives
in the shared `PC_STATE_DIR`.

## Batch format

```json
[
  {"action":"shot","ocr":true},
  {"action":"move","x":640,"y":360},
  {"action":"click"},
  {"action":"wait","ms":300},
  {"action":"shot","grid":true}
]
```

```bash
pc-control run "$(cat actions.json)"
pc-control run - < actions.json
```

Actions: `shot`, `move`, `move-rel`, `click`, `down`, `up`, `key`, `type`,
`scroll`, `wait`, `focus`, `active`, `cursor`, `screen`, `status`.
`run` stops at the first failure unless `--continue-on-error`.

## Environment

| Variable | Meaning |
|---|---|
| `PC_STATE_DIR` | Runtime dir (default `./.pc-control`) |
| `PC_SCREENSHOT_BACKEND` | Force `spectacle`, `grim`, `gnome-screenshot`, `wayshot`, `scrot`, `import` |
| `PC_OCR_LANG` | Default OCR language (auto-detected from `LANG`, then `eng`) |
| `YDOTOOL_SOCKET` | Daemon socket (default `/run/ydotool.sock`) |

## Limits

- Vision-only unless `--ocr`: there is no accessibility tree.
- Each observe→act cycle is ~1–3 s; not real-time.
- KDE gets cursor/focus feedback via KWin scripting; other desktops fall back
  to approximate absolute moves.
- `focus` / `active` are KDE-only for now.

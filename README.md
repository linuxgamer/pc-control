# pc-control

[![test](https://github.com/linuxgamer/pc-control/actions/workflows/test.yml/badge.svg)](https://github.com/linuxgamer/pc-control/actions/workflows/test.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`pc-control` is a small, dependency-light CLI that gives an llm screenshots,
mouse, keyboard, window focus, and app switching on Wayland or X11. Every call
prints one JSON object, so it composes cleanly with tool-using models.

![pc-control demo](.github/assets/demo.gif)

It can work with any llm(**multimodality recommended**) that can run python. The skill is in [`etc/SKILL.md`](etc/SKILL.md), generic instructions are in [`etc/USAGE.md`](etc/USAGE.md).

```
agent ── shell ──► pc-control ──► spectacle / grim / gnome-screenshot ──► compact JPEG
                      └────────► ydotool ──► ydotoold ──► /dev/uinput ──► apps & games
```

## Harness support

`pc-control` is **harness-agnostic**: one Python file, no imports from DeepSeek
Harness, one JSON object per call. Any runtime that can run shell commands and
read an image can drive it.

- [`etc/USAGE.md`](etc/USAGE.md) — generic system-prompt snippet, JSON contract,
  token strategy, batch format.
- [`etc/SKILL.md`](etc/SKILL.md) — the same guidance in DeepSeek Harness skill
  format (works as a plain instruction document too).
- `install.sh` installs the skill into `~/.dsh/skills` by default; use
  `--skill-dir DIR` for another harness, or `--no-skill` for the CLI only.

## Features

- **Simulates real input** — `ydotool` creates a kernel virtual device, so
  native Wayland apps *and games* receive mouse/keyboard, including relative
  look.
- **Saves tokens** — compacts screenshots (1280 px) by default, `--region`
  crops, `--ocr` returns text, `--grid` for precise coordinates, `--full` when
  quality matters.
- **Automatic coordinate mapping** — coordinates from a downscaled or cropped
  shot are mapped back to native pixels; no manual scale math.
- **Closed-loop mouse movement** — reads the real cursor via KWin, learns
  pointer acceleration, and lands within ~2 px.
- **Window focus** — `focus` unminimizes and activates by title/class, so you
  never have to click a title bar.
- **Batch actions** — `run` chains shot → move → click → verify in one call.
- **Portable** — KDE, GNOME, and wlroots capture backends; distro-agnostic
  setup for `uinput` + `ydotool`; single-file Python CLI.

## Install

```bash
git clone https://github.com/linuxgamer/pc-control.git
cd pc-control
sudo ./install.sh --system   # /usr/local/bin + skill + uinput + ydotoold + humanwatch
pc-control doctor
```

`--system` installs the CLI to `/usr/local/bin`, the skill for the target user,
and both host services. It needs root. Without root, `./install.sh` installs to
`~/.local/bin` and `~/.dsh/skills`.

If `pc-control` is not found afterwards, add `~/.local/bin` to PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

`sudo ./install.sh --system` installs `ydotool` with your package manager
(pacman/apt/dnf/zypper), loads `uinput`, adds the udev rule, and runs `ydotoold`
plus the humanwatch service (opt out with `--no-humanwatch`). The socket is
`/run/ydotool.sock`, owned by your user, mode 0600. `--no-cli` keeps the CLI
where it is and only installs the services.

From a checkout with pip or pipx:

```bash
pipx install .          # isolated, puts pc-control on PATH
# or
python3 -m pip install --user .
```

For development inside a checkout (not the normal install):

```bash
./install.sh --local         # ./.pc-control/bin + ./.dsh/skills
./.pc-control/bin/pc-control doctor
```

Requirements: Python 3.9+, Pillow (compact/grid/region), one screenshot backend,
`ydotool` + root `ydotoold`. Optional: `tesseract` for OCR, KDE Plasma for
cursor/focus feedback.

## Quick start

```bash
pc-control shot                  # compact screenshot, prints JSON with path
pc-control shot --grid           # + 100 px grid for picking coordinates
pc-control click left --at 640 360
pc-control type "hello"
pc-control key ctrl+s
pc-control shot --ocr            # text instead of pixels
pc-control focus konsole
pc-control run '[{"action":"shot"},{"action":"click","at":[640,360]},{"action":"shot"}]'
```

Read the image at the returned `path` with your agent's image tool, or use
`--ocr` for text-only mode.

## More commands

```text
doctor | screen
shot [--window|--screen] [--region X Y W H] [--grid] [--ocr] [--ocr-lang L]
     [--ocr-max-chars N] [--full] [--max-width N] [--out PATH]
move X Y [--native] [--scaled] [--dry-run]
move-rel DX DY [--dry-run]
click [left|right|middle|side|extra] [--double] [--at X Y] [--native]
      [--allow-approximate] [--dry-run]
down|up [button]
key KEYS [--hold MS] [--dry-run]        # ctrl+s, space, alt+F4, f1...
type TEXT                               # US layout / ASCII
scroll N [--horizontal]                 # negative = down
wait MS
run JSON [--continue-on-error]
active | cursor | focus PATTERN
pause [--reason TEXT] | resume | status
claim [--ttl SECONDS] [--force] [--wait] [--timeout SECONDS]
renew [--ttl SECONDS] | release [--force]
```

`run` actions: `shot`, `move`, `move-rel`, `click`, `down`, `up`, `key`, `type`,
`scroll`, `wait`, `focus`, `active`, `cursor`, `screen`, `status`.

## Apps and games

Launch an app through the desktop launcher (works on any desktop):

```bash
pc-control key meta
pc-control type "konsole"
pc-control key enter
```

For games, start the game on the host first, then drive it:

```bash
pc-control move-rel 120 0        # turn right
pc-control key w --hold 1000     # walk forward
pc-control down left             # fire
pc-control up left
```

Each observe→act cycle is ~1–3 s: fine for menus, walking, and chat, not for
live aiming.

## Troubleshooting

| Symptom | Check |
|---|---|
| A click seems ignored | Take a fresh `shot` first. A collapsed sidebar, hidden panel, or moved window changes the layout, so an old coordinate now hits empty space. |
| A window disappeared | You clicked its title bar; `focus PATTERN` restores it. |
| `move` reports a warning | Retry once; if it persists, take a shot and verify the pointer's effect. |
| `no screenshot backend` | Install `spectacle`, `grim`, `gnome-screenshot`, `wayshot`, or `scrot`. |
| `ydotool failed` | `pc-control doctor`; check `ydotoold` and the socket. |
| `error:"human_paused"` | The human paused control; stop and ask them to `pc-control resume`. |
| `error:"human_override"` | The cursor moved before the click; do not retry blindly — take a fresh shot. |
| `error:"human_active"` | Physical input was detected; wait for `PC_HUMAN_IDLE_MS` and retry once. |
| `error:"lease_busy"` | Another agent holds the lease; `claim --wait` or coordinate. |
| `error:"state_temporary"` | State fell back to `/tmp`; set `PC_STATE_DIR` to a host-visible path. |
| `error:"no_feedback"` | No KWin cursor feedback; pass `--allow-approximate` only if you accept blind clicking. |
| OCR text looks wrong | Check `ocr_lang` in the shot JSON; install the matching Tesseract language and pass `--ocr-lang` (e.g. `rus`). Mixed/Cyrillic UI can still transliterate. |

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `PC_STATE_DIR` | `./.pc-control` | Shots, last-shot geometry, KWin helpers |
| `PC_SCREENSHOT_BACKEND` | auto | `spectacle`, `grim`, `gnome-screenshot`, `wayshot`, `scrot`, `import` |
| `PC_OCR_LANG` | from `LANG`, then `eng` | Tesseract language |
| `PC_HUMAN_IDLE_MS` | `800` | Ignore mutating calls this long after physical input |
| `PC_LEASE_TTL_MS` | `15000` | Auto-lease lifetime; renewed on every mutating call |
| `PC_OCR_MAX_CHARS` | `4000` | OCR text cap; `0` disables truncation |
| `PC_AGENT_ID` | session/parent | Lease owner identity |
| `PC_LEASE_DISABLED` | unset | `1` bypasses leases (single-agent debugging) |
| `YDOTOOL_SOCKET` | `/run/ydotool.sock` | Daemon socket |

## Development

```bash
python3 -m unittest discover -s etc -v
./pc-control --help
```

Layout:

```
pc-control       single-file CLI (stdlib; Pillow optional)
install.sh       user installer + --system host setup
scripts/humanwatch.py  evdev input watcher (timestamp only)
etc/SKILL.md     skill for any harness
etc/USAGE.md     generic agent instructions
```

## License

MIT — see [LICENSE](LICENSE).

# pc-control

[![test](https://github.com/linuxgamer/pc-control/actions/workflows/test.yml/badge.svg)](https://github.com/linuxgamer/pc-control/actions/workflows/test.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Desktop control for agents on Linux: screenshots for observation, mouse,
keyboard, window focus, and app switching.

This is not a screenshot app. For ordinary human screenshots use **Spectacle**;
`pc-control` is for letting an agent operate the desktop.


## What is this?

- **For humans:** a way to pause an agent, or to script a click/keystroke.
- **For agents:** one JSON object per call, with compact screenshots, automatic
  coordinate mapping, OCR, batch actions, a human-takeover pause, and a lease
  so two agents do not fight over the mouse.
- **Not:** a remote-desktop server, a GUI automation recorder, or a cloud
  service. Nothing leaves your machine.

The full human guide is in [`etc/HUMAN.md`](etc/HUMAN.md). Agent integration is
in [`etc/USAGE.md`](etc/USAGE.md) and [`etc/SKILL.md`](etc/SKILL.md).

## Install

### Recommended (any distro)

```bash
git clone https://github.com/linuxgamer/pc-control.git
cd pc-control
sudo ./install.sh --system
pc-control doctor
```

Requirements: Python 3.9+, Pillow, one screenshot backend, and `ydotool` +
`ydotoold` for input. `--system` requires **sudo** and installs:

- `pc-control` to `/usr/local/bin`
- the skill for your user under `~/.dsh/skills`
- `uinput`, the udev rule, `ydotoold`, and the humanwatch service

The humanwatch service is optional (`--no-humanwatch`) and writes only a
timestamp — never key contents.

Without root, `./install.sh` installs the CLI to `~/.local/bin` and the skill to
`~/.dsh/skills`. The CLI works; clicking/typing need the system step.

If `pc-control` is not found afterwards, add `~/.local/bin` to PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Package-manager options

| Method | Command | What you get |
|---|---|---|
| Script | `sudo ./install.sh --system` | Everything, any distro |
| Arch package | `cd packaging && makepkg -si` | AUR-ready PKGBUILD (not published yet); one-time service setup |
| pipx | `pipx install .` | CLI only, isolated; no services |
| Released wheel | `pipx install <wheel-url>` | CLI only; no services |

The `packaging/` directory has an AUR-ready `PKGBUILD` and notes. PyPI publishing
is prepared but not live yet; the GitHub release wheel is installable with
pipx today.

### Update and uninstall

```bash
git pull
./install.sh
sudo ./install.sh --system

./install.sh --uninstall
sudo ./install.sh --system --uninstall
```

## Use it yourself

### Click and type

Coordinates are pixels from a `pc-control shot` image (or from the
`screenshot` screen size). Use `pc-control shot --grid` to see coordinates.

```bash
pc-control shot                          # compact screenshot with a path
pc-control click left --at 640 360
pc-control type "hello"
pc-control key ctrl+s
pc-control scroll -3
```

### Pause an agent

```bash
pc-control pause --reason "I need the mouse"
pc-control status
pc-control resume
```

The pause command is meant to be run by a human. An agent can read `status` but
cannot un-pause itself.

### Where are my files?

Agent screenshots and state live in `./.pc-control/` (the current directory).

### Check it

```bash
pc-control doctor
```

On a terminal this prints a short plain-English summary. `pc-control doctor
--json` is available for scripts.

## For agents

`pc-control` is harness-agnostic: one Python file, no imports from a particular
agent runtime, one JSON object per agent call. Any runtime that can run shell
commands and read an image can drive it.

- [`etc/USAGE.md`](etc/USAGE.md) — generic system prompt, JSON contract, token
  strategy, batch format.
- [`etc/SKILL.md`](etc/SKILL.md) — the same guidance in DeepSeek Harness skill
  format.
- `install.sh` installs the skill into `~/.dsh/skills` by default; use
  `--skill-dir DIR` for another harness, or `--no-skill` for the CLI only.

### Agent quick start

```bash
pc-control doctor
pc-control shot --json                  # compact JPEG + coordinates
pc-control move 640 360                 # image pixels; auto-mapped
pc-control click left --at 640 360
pc-control type "hello"
pc-control key ctrl+s
pc-control shot --ocr                   # text instead of pixels
pc-control focus konsole
pc-control run '[{"action":"shot"},{"action":"click","at":[640,360]},{"action":"shot"}]'
```

Read the image at the returned `path` with your agent's image tool, or use
`--ocr` for text-only mode.

> `shot` switches to human output on a TTY. Agents should call `shot --json`
> (or run with stdout piped) to guarantee JSON. `screenshot` is always human
> unless `--json` is passed.

### How it works

```
agent ── shell ──► pc-control ──► spectacle / grim / gnome-screenshot ──► compact JPEG
                      └────────► ydotool ──► ydotoold ──► /dev/uinput ──► apps & games
```

### Features

- **Real input** — `ydotool` creates a kernel virtual device, so native Wayland
  apps and games receive mouse/keyboard, including relative look.
- **Token-aware screenshots** — 1280 px JPEG by default, `--region`, `--ocr`,
  `--grid`, `--full`.
- **Automatic coordinate mapping** — image pixels map back to native pixels.
- **Closed-loop movement** — reads the KWin cursor and lands within ~2 px.
- **Window focus** — unminimizes and activates by title/class without clicking a
  title bar.
- **Batch actions** — `run` chains shot → move → click → verify in one call.
- **Human takeover** — `pause`, cursor re-verification, physical-input detection.
- **Concurrency lease** — two agents coordinate; the second gets `lease_busy`.
- **Portable** — KDE, GNOME, and wlroots capture backends; Wayland or X11.

## Commands

```text
doctor [--json] | screenshot [...] | screen
shot [--window|--screen] [--region X Y W H] [--grid] [--ocr] [--ocr-lang L]
     [--ocr-max-chars N] [--full] [--max-width N] [--out PATH]
     [--human] [--json] [--no-open]
screenshot [--window|--screen] [--region X Y W H] [--grid] [--ocr]
           [--ocr-lang L] [--ocr-max-chars N] [--max-width N] [--out PATH]
           [--no-open] [--json]
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

### For humans

| Symptom | Fix |
|---|---|
| `pc-control: command not found` | Add `~/.local/bin` to PATH, or open a new terminal. |
| The image viewer did not open | Add `--no-open`; the path is printed. Open it manually. |
| `error:"state_temporary"` | Run from your home/workspace, or set `PC_STATE_DIR=$HOME/.pc-control`. |
| Clicking/typing does nothing | Run `sudo ./install.sh --system`; check `pc-control doctor`. |
| `no screenshot backend` | Install `spectacle`, `grim`, `gnome-screenshot`, `wayshot`, or `scrot`. |
| `error:"no_feedback"` | KDE is required for verified clicks; `--allow-approximate` clicks blind. |
| `sudo` asks for a password | Expected. The system step needs root. |

### For agents

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
| `PC_OCR_MAX_CHARS` | `4000` | OCR text cap; `0` disables truncation |
| `PC_HUMAN_IDLE_MS` | `800` | Ignore mutating calls this long after physical input |
| `PC_LEASE_TTL_MS` | `15000` | Auto-lease lifetime; renewed on every mutating call |
| `PC_AGENT_ID` | session/parent | Lease owner identity |
| `PC_LEASE_DISABLED` | unset | `1` bypasses leases (single-agent debugging) |
| `YDOTOOL_SOCKET` | `/etc/pc-control/socket` or `/run/ydotool.sock` | Daemon socket |

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
etc/HUMAN.md     human guide
etc/SKILL.md     skill for any harness
etc/USAGE.md     generic agent instructions
packaging/       PKGBUILD + packaging notes
```

## License

MIT — see [LICENSE](LICENSE).

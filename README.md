# pc-control

**Let an LLM see and operate your Linux desktop — with tokens in mind.**

`pc-control` is a small, dependency-light CLI that gives an agent screenshots,
mouse, keyboard, window focus, and app launching on Wayland or X11. Every call
prints one JSON object, so it composes cleanly with tool-using models.

It was built for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
but works with any agent that can run shell commands. The companion skill lives
in [`skill/SKILL.md`](skill/SKILL.md); generic instructions are in
[`docs/LLM.md`](docs/LLM.md).

```
agent ──shell──► pc-control ──► spectacle / grim / gnome-screenshot ──► compact JPEG
                      └────────► ydotool ──► ydotoold ──► /dev/uinput ──► apps & games
```

## Features

- **Real input, not X11 events** — `ydotool` creates a kernel virtual device, so
  native Wayland apps *and games* receive mouse/keyboard, including relative
  look.
- **Token-aware screenshots** — compact JPEG (1280 px) by default, `--region`
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
./install.sh                 # ~/.local/bin/pc-control + ~/.dsh/skills/pc-control
sudo ./setup-uinput.sh       # once: uinput module, udev rule, ydotoold
pc-control doctor
```

`install.sh` needs no sudo. `setup-uinput.sh` installs `ydotool` with your
package manager (pacman/apt/dnf/zypper), loads `uinput`, adds one udev rule, and
runs `ydotoold` with a socket owned by your user (`/run/ydotool.sock`, mode
0600).

For a checkout without installing:

```bash
./install.sh --local         # ./.pc-control/bin + ./.dsh/skills
./pc-control/pc-control doctor
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
`--ocr` and skip the image entirely.

## Why it saves tokens

| Mode | Output | Relative image cost |
|---|---|---|
| `shot` (default) | 1280×720 JPEG | ~½ of native |
| `shot --region X Y W H` | exact crop | proportional to area |
| `shot --ocr` | text field | zero image tokens |
| `shot --window` | active window | small, read-only |
| `shot --full` | 1920×1080 PNG | full |

Coordinates are always in the returned image's pixel space; `pc-control` stores
the scale/offset and converts for `move` and `click --at`.

## Commands

```text
doctor | screen
shot [--window|--screen] [--region X Y W H] [--grid] [--ocr] [--ocr-lang L]
     [--full] [--max-width N] [--out PATH]
move X Y [--native] [--scaled] [--dry-run]
move-rel DX DY [--dry-run]
click [left|right|middle|side|extra] [--double] [--at X Y] [--native] [--dry-run]
down|up [button]
key KEYS [--hold MS] [--dry-run]        # ctrl+s, space, alt+F4, f1...
type TEXT                               # US layout / ASCII
scroll N [--horizontal]                 # negative = down
wait MS
run JSON [--continue-on-error]
active | cursor | focus PATTERN
launch tf2|steam
```

`run` actions: `shot`, `move`, `move-rel`, `click`, `down`, `up`, `key`, `type`,
`scroll`, `wait`, `launch`, `focus`, `active`, `cursor`, `screen`.

## How movement works

`ydotool --absolute` is really “jump to 0,0, then move relatively”, and desktop
pointer acceleration distorts it. `pc-control` instead reads the real cursor
position through a one-shot KWin script, steps in bounded increments, learns the
acceleration gain per axis, and corrects until it is within 2 px. On non-KDE
desktops it falls back to approximate absolute movement (`feedback: false`).

`move-rel` sends raw relative motion — the right primitive for game look.

## Games

```bash
# Steam must already be running on the host (the sandbox has no GPU)
pc-control launch tf2
pc-control move-rel 120 0        # turn right
pc-control key w --hold 1000     # walk forward
pc-control down left             # fire
pc-control up left
```

Each observe→act cycle is ~1–3 s: fine for menus, walking, and chat, not for
live aiming. Automating competitive play violates VAC/Steam ToS — prefer
offline or private servers.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `PC_STATE_DIR` | `./.pc-control` | Shots, last-shot geometry, KWin helpers |
| `PC_SCREENSHOT_BACKEND` | auto | `spectacle`, `grim`, `gnome-screenshot`, `wayshot`, `scrot`, `import` |
| `PC_OCR_LANG` | from `LANG`, then `eng` | Tesseract language |
| `YDOTOOL_SOCKET` | `/run/ydotool.sock` | Daemon socket |

## Safety

`ydotoold` runs as root and can synthesize any input; the socket is mode 0600
and owned by your desktop user. The agent still needs approval for each shell
call. Don’t leave the daemon enabled on a shared machine, and never click window
title-bar controls — use `focus`.

## Development

```bash
python3 -m unittest discover -s tests -v
./pc-control --help
```

Layout:

```
pc-control       single-file CLI (stdlib; Pillow optional)
setup-uinput.sh  one-time root setup
install.sh       user-level installer (CLI + skill)
skill/SKILL.md   DeepSeek Harness skill
docs/LLM.md      generic agent instructions
tests/           unit tests
```

## License

MIT — see [LICENSE](LICENSE).

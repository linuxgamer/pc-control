# pc-control for humans

A command-line tool for taking screenshots and (optionally) letting an AI use
your desktop. You do not need to know JSON to take a screenshot.

## Install

### Any distro, with root

```bash
git clone https://github.com/linuxgamer/pc-control.git
cd pc-control
sudo ./install.sh --system
```

This installs `pc-control` and the host services needed for mouse/keyboard
control. If you only want screenshots, the
screenshot part works with the user-level install too:

```bash
./install.sh          # ~/.local/bin + ~/.dsh/skills, no root
```

### Arch Linux

```bash
cd packaging
makepkg -si
sudo /usr/share/pc-control/install.sh --system --no-cli
```

The second command is the one-time host setup; the package itself is a normal
Arch package. The PKGBUILD is AUR-ready but not submitted yet.

### Python / pipx (CLI only)

```bash
pipx install .        # from a checkout
# or, after a release:
pipx install https://github.com/linuxgamer/pc-control/releases/download/v0.8.1/pc_control-0.8.1-py3-none-any.whl
```

This gives you the `pc-control` command. It does **not** install the root
services; run `sudo ./install.sh --system` from a checkout for those.

## First screenshot

```bash
pc-control screenshot
```

It saves to your XDG Pictures folder (for example
`~/Изображения/pc-control/Screenshot-….png` or
`~/Pictures/pc-control/Screenshot-….png`), opens it, and prints one line. `--no-open` skips the viewer; `--out PATH` saves elsewhere; `--region X Y
W H` crops.


## Click and type

```bash
pc-control shot                      # prints a path + coordinates
pc-control click left --at 640 360
pc-control type "hello"
pc-control key ctrl+s
```

Coordinates are pixels in the image returned by `shot`. Take a fresh `shot`
before clicking if the screen changed.

## Pause an AI

```bash
pc-control pause --reason "I need the mouse"
pc-control resume
pc-control status
```

`pause` is for humans; an agent can read `status` but cannot resume itself.
Physical mouse/keyboard use also makes the agent wait briefly.

## Files

- Screenshots: your XDG Pictures folder + `/pc-control/`
- Agent state: `./.pc-control/` in the directory where the agent runs

## Check and fix

```bash
pc-control doctor
```

Plain English on a terminal. Common fixes:

| Problem | Fix |
|---|---|
| `command not found` | Add `~/.local/bin` to PATH, or open a new terminal. |
| `cannot write to the Pictures folder` | Use `--out ~/Desktop/shot.png` or set `PC_PICTURES_DIR`. |
| Viewer did not open | Add `--no-open`; the path is printed. |
| `state_temporary` | Run from home/workspace, or set `PC_STATE_DIR=$HOME/.pc-control`. |
| Clicking/typing does nothing | `sudo ./install.sh --system`, then `pc-control doctor`. |
| No screenshot backend | Install `spectacle`, `grim`, or `gnome-screenshot`. |

## Update / uninstall

```bash
git pull
./install.sh
sudo ./install.sh --system

./install.sh --uninstall
sudo ./install.sh --system --uninstall
```

## Privacy

`pc-control` sends nothing to the cloud. The optional humanwatch service reads
`/dev/input` only to record *when* you last touched the mouse/keyboard; it never
stores key codes or text.

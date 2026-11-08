# pc-control for humans

`pc-control` is a desktop-control tool for AI agents. For ordinary screenshots,
use **Spectacle** — that is what it is for. `pc-control` is for automating
clicks, typing, and window focus, and for pausing an agent that is doing so.

## Install

### Any distro, with root

```bash
git clone https://github.com/linuxgamer/pc-control.git
cd pc-control
sudo ./install.sh --system
```

This installs `pc-control` and the host services needed for mouse/keyboard
control. Pick this **or** the no-root user install, not both: `./install.sh`
creates a second copy in `~/.local/bin`, which can shadow the system one.
Without root, use `./install.sh`; the input services still need the system step.

### Arch Linux

```bash
cd packaging
makepkg -si
sudo /usr/share/pc-control/install.sh --system --no-cli
```

The second command is the one-time host setup; the PKGBUILD is AUR-ready but not
submitted yet.

### Python / pipx (CLI only)

```bash
pipx install .
# or, after a release:
pipx install https://github.com/linuxgamer/pc-control/releases/download/v0.9.3/pc_control-0.9.3-py3-none-any.whl
```

This gives you the `pc-control` command, but not the root services.

## Check

```bash
pc-control doctor
```

Plain English on a terminal.

## Click and type

```bash
pc-control shot                      # agent observation: path + coordinates
pc-control click left --at 640 360
pc-control type "hello"
pc-control key ctrl+s
```

Coordinates are pixels in the image returned by `shot`.

## Pause an AI

```bash
pc-control pause --reason "I need the mouse"
pc-control resume
pc-control status
```

`pause` is for humans; an agent can read `status` but cannot resume itself.

If an agent tries to act while you are using the mouse/keyboard, it shows a
desktop notification and waits 8 seconds before continuing. Run `pc-control
pause` during that countdown to cancel.

## Files

Agent state lives in `./.pc-control/` in the directory where the agent runs.
Screenshots for humans belong in Spectacle, not here.

## Fix

| Problem | Fix |
|---|---|
| `command not found` | Add `~/.local/bin` to PATH, or open a new terminal. |
| `state_temporary` | Run from home/workspace, or set `PC_STATE_DIR=$HOME/.pc-control`. |
| Clicking/typing does nothing | `sudo ./install.sh --system`, then `pc-control doctor`. |
| `no screenshot backend` | Install `spectacle` or `grim` for the agent's observations. |

## Privacy

`pc-control` sends nothing to the cloud. The optional humanwatch service reads
`/dev/input` only to record *when* you last touched the mouse/keyboard; it never
stores key codes or text.

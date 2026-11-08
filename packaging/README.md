# Packaging

`pc-control` is a Python CLI plus a small privileged host setup. There is no way
around a root step for `/dev/uinput` + `ydotoold` + the input watcher; the
question is only who runs it.

| Method | Command | Scope |
|---|---|---|
| Script (any distro) | `sudo ./install.sh --system` | CLI + skill + menu + services |
| Arch PKGBUILD | `makepkg -si` then `sudo /usr/share/pc-control/install.sh --system --no-cli` | Package-managed files + one-time setup |
| pipx / PyPI | `pipx install .` | CLI only |
| Flatpak / AppImage | not recommended | Needs `/dev/uinput` and a root daemon |

## Arch (AUR-ready PKGBUILD)

```bash
cd packaging
makepkg -si
sudo /usr/share/pc-control/install.sh --system --no-cli
pc-control screenshot
```

The package installs `/usr/bin/pc-control`, the human/agent docs, the menu entry,
and `install.sh` under `/usr/share/pc-control`. The second command is the
one-time privileged setup; it installs the skill, `ydotoold`, and `humanwatch`.

`sha256sums` is `SKIP` in the repo template. Before uploading to the AUR, run
`updpkgsums`, then `makepkg --printsrcinfo > .SRCINFO`.

## PyPI / pipx

The `pc-control` name is currently unused on PyPI. To publish:

```bash
python3 -m build
twine upload dist/*
```

Then:

```bash
pipx install pc-control
```

Until it is published, the release wheel works:

```bash
pipx install https://github.com/linuxgamer/pc-control/releases/download/v0.8.0/pc_control-0.8.0-py3-none-any.whl
```

The wheel contains the CLI only. The skill, menu entry, and services still need
the checkout/installer. Do not publish a wheel that silently omits the root
setup without saying so.

## Debian / RPM

No package is built yet. The same split applies: the package should install the
CLI, docs, and unit/udev files; enabling a root input daemon is a post-install
step.

## Why not Flatpak / AppImage?

Both sandbox the filesystem and cannot reliably access `/dev/uinput` or manage
the root `ydotoold`/humanwatch services. They are the wrong tool for a
system-input daemon.

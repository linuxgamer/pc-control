#!/usr/bin/env bash
# pc-control installer.
#
#   ./install.sh                    # user: CLI + skill
#   ./install.sh --local            # user: ./.pc-control/bin + ./.dsh/skills
#   ./install.sh --no-skill         # user: CLI only
#   sudo ./install.sh --system      # root: /usr/local/bin + skill + uinput + ydotool + ydotoold + humanwatch
#   sudo ./install.sh --system --no-humanwatch
#   sudo ./install.sh --system --no-cli
#   ./install.sh --uninstall        # remove the user install
#   sudo ./install.sh --system --uninstall
#
# --system installs both host services; they are the supported setup. The
# humanwatch service is opt-out (privacy: timestamps only, never key contents).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="${PREFIX}/bin"
SKILL_DIR="${DSH_HOME:-$HOME/.dsh}/skills"
INSTALL_SKILL=1
LOCAL=0
SYSTEM=0
UNINSTALL=0
WATCH_HUMAN=1
CLI_SYSTEM=1
SOCKET="/run/ydotool.sock"
TARGET_UID=""

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="${2:?--prefix needs a path}"; BIN_DIR="${PREFIX}/bin"; shift 2 ;;
    --bin-dir) BIN_DIR="${2:?--bin-dir needs a path}"; shift 2 ;;
    --skill-dir) SKILL_DIR="${2:?--skill-dir needs a path}"; shift 2 ;;
    --no-skill) INSTALL_SKILL=0; shift ;;
    --local) LOCAL=1; BIN_DIR="$PWD/.pc-control/bin"; SKILL_DIR="$PWD/.dsh/skills"; shift ;;
    --system) SYSTEM=1; shift ;;
    --no-humanwatch) WATCH_HUMAN=0; shift ;;
    --no-cli) CLI_SYSTEM=0; shift ;;
    --socket) SOCKET="${2:?--socket needs a path}"; shift 2 ;;
    --uid) TARGET_UID="${2:?--uid needs a number}"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

if [[ ${SYSTEM} -eq 1 && ${LOCAL} -eq 1 ]]; then
  echo "error: --system and --local are mutually exclusive." >&2
  exit 1
fi

# --------------------------------------------------------------------------- #
# user install
# --------------------------------------------------------------------------- #
if [[ ${SYSTEM} -eq 0 ]]; then
  if [[ ${UNINSTALL} -eq 1 ]]; then
    rm -f "${BIN_DIR}/pc-control"
    rm -f "${SKILL_DIR}/pc-control/SKILL.md"
    rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/pc-control.desktop"
    rmdir "${SKILL_DIR}/pc-control" 2>/dev/null || true
    echo "removed ${BIN_DIR}/pc-control and the skill"
    exit 0
  fi
  command -v python3 >/dev/null 2>&1 || {
    echo "error: python3 is required" >&2
    exit 1
  }
  if [[ -x /usr/local/bin/pc-control && "${BIN_DIR}/pc-control" != "/usr/local/bin/pc-control" ]]; then
    echo "note: /usr/local/bin/pc-control is already installed; this creates a second copy." >&2
    echo "      update the system copy instead: sudo ${HERE}/install.sh --system" >&2
  fi
  install -Dm755 "${HERE}/pc-control" "${BIN_DIR}/pc-control"
  rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/pc-control.desktop"
  if [[ ${INSTALL_SKILL} -eq 1 ]]; then
    install -Dm644 "${HERE}/etc/SKILL.md" "${SKILL_DIR}/pc-control/SKILL.md"
  fi
  echo "installed:"
  echo "  ${BIN_DIR}/pc-control"
  [[ ${INSTALL_SKILL} -eq 1 ]] && echo "  ${SKILL_DIR}/pc-control/SKILL.md"
  echo
  echo "checks:"
  command -v ydotool >/dev/null 2>&1 \
    && echo "  ydotool: ok" \
    || echo "  ydotool: MISSING — run: sudo ${HERE}/install.sh --system"
  python3 -c 'import PIL' >/dev/null 2>&1 \
    && echo "  Pillow: ok (compact shots)" \
    || echo "  Pillow: missing — python3 -m pip install --user pillow (compact shots)"
  command -v tesseract >/dev/null 2>&1 \
    && echo "  tesseract: ok (OCR)" \
    || echo "  tesseract: optional (OCR)"
  command -v notify-send >/dev/null 2>&1 || command -v kdialog >/dev/null 2>&1 \
    && echo "  notifications: ok (takeover warning)" \
    || echo "  notifications: optional (notify-send/kdialog)"
  for backend in spectacle grim gnome-screenshot wayshot scrot import; do
    if command -v "${backend}" >/dev/null 2>&1; then
      echo "  screenshot: ${backend}"
      break
    fi
  done
  case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *) echo; echo "note: add ${BIN_DIR} to PATH to run 'pc-control' without a path" ;;
  esac
  echo
  echo "try:"
  echo "  pc-control doctor"
  echo
  echo "input (click/type) needs the host services:"
  echo "  sudo ${HERE}/install.sh --system"
  SYSTEM_CLI="$(command -v pc-control 2>/dev/null || true)"
  if [[ -n "${SYSTEM_CLI}" && "${SYSTEM_CLI}" != "${BIN_DIR}/pc-control" ]]; then
    echo
    echo "note: ${SYSTEM_CLI} shadows this install; run the --system command to update it"
  fi
  exit 0
fi

# --------------------------------------------------------------------------- #
# system install (root)
# --------------------------------------------------------------------------- #
if [[ ${EUID} -ne 0 ]]; then
  echo "error: run the system install with sudo: sudo $0 --system" >&2
  exit 1
fi
if ! command -v systemctl >/dev/null 2>&1; then
  echo "error: systemd is required for --system; install units manually." >&2
  exit 1
fi

CLI_DEST=/usr/local/bin/pc-control
SOCKET_CONF=/etc/pc-control/socket
YDOTOOLD_UNIT=/etc/systemd/system/ydotoold.service
WATCH_UNIT=/etc/systemd/system/pc-control-humanwatch.service
WATCH_LIB=/usr/local/lib/pc-control
RULE=/etc/udev/rules.d/60-uinput.rules
MODULE_CONF=/etc/modules-load.d/uinput.conf

if [[ ${UNINSTALL} -eq 1 ]]; then
  systemctl disable --now pc-control-humanwatch.service 2>/dev/null || true
  systemctl disable --now ydotoold.service 2>/dev/null || true
  rm -f "${WATCH_UNIT}" "${YDOTOOLD_UNIT}" "${WATCH_LIB}/humanwatch.py" "${RULE}" "${MODULE_CONF}"
  rmdir "${WATCH_LIB}" 2>/dev/null || true
  rm -f "${CLI_DEST}" "${SOCKET_CONF}" /usr/share/applications/pc-control.desktop
  rmdir /etc/pc-control 2>/dev/null || true
  UNINSTALL_UID="${TARGET_UID:-}"
  if [[ -z "${UNINSTALL_UID}" && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    UNINSTALL_UID="$(id -u "${SUDO_USER}")"
  fi
  if [[ -n "${UNINSTALL_UID}" ]]; then
    UNINSTALL_HOME="$(getent passwd "${UNINSTALL_UID}" 2>/dev/null | cut -d: -f6)"
    if [[ -n "${UNINSTALL_HOME}" ]]; then
      rm -f "${UNINSTALL_HOME}/.dsh/skills/pc-control/SKILL.md"
      rmdir "${UNINSTALL_HOME}/.dsh/skills/pc-control" 2>/dev/null || true
    fi
  fi
  systemctl daemon-reload 2>/dev/null || true
  udevadm control --reload-rules 2>/dev/null || true
  echo "removed pc-control system services, ${CLI_DEST}, and the user skill"
  exit 0
fi

if [[ -z "${TARGET_UID}" ]]; then
  TARGET_USER="${SUDO_USER:-}"
  if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
    echo "error: cannot determine the desktop user; pass --uid N." >&2
    exit 1
  fi
  TARGET_UID="$(id -u "${TARGET_USER}")"
fi
if ! [[ "${TARGET_UID}" =~ ^[0-9]+$ ]] || ! id "${TARGET_UID}" >/dev/null 2>&1; then
  echo "error: --uid ${TARGET_UID} is not a local user." >&2
  exit 1
fi
TARGET_GID="$(id -g "${TARGET_UID}")"
TARGET_HOME="$(getent passwd "${TARGET_UID}" 2>/dev/null | cut -d: -f6)"

if [[ ${CLI_SYSTEM} -eq 1 ]]; then
  echo "==> ${CLI_DEST}"
  install -Dm755 "${HERE}/pc-control" "${CLI_DEST}"
  if [[ -n "${TARGET_HOME}" && -e "${TARGET_HOME}/.local/bin/pc-control" ]]; then
    rm -f "${TARGET_HOME}/.local/bin/pc-control"
    echo "    removed duplicate user copy: ${TARGET_HOME}/.local/bin/pc-control"
  fi
fi
rm -f /usr/share/applications/pc-control.desktop
install -d /etc/pc-control
printf '%s\n' "${SOCKET}" > "${SOCKET_CONF}"
chmod 644 "${SOCKET_CONF}"
if [[ ${INSTALL_SKILL} -eq 1 ]]; then
  if [[ -n "${TARGET_HOME}" ]]; then
    install -Dm644 "${HERE}/etc/SKILL.md" "${TARGET_HOME}/.dsh/skills/pc-control/SKILL.md"
    chown -R "${TARGET_UID}:${TARGET_GID}" "${TARGET_HOME}/.dsh/skills/pc-control" 2>/dev/null || true
  else
    echo "warning: cannot resolve the home directory for uid ${TARGET_UID}; skill not installed." >&2
  fi
fi

echo "==> uinput"
if ! modprobe uinput 2>/dev/null; then
  echo "warning: modprobe uinput failed; load it manually or reboot." >&2
fi
echo "uinput" > "${MODULE_CONF}"
cat > "${RULE}" <<'RULE_EOF'
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
RULE_EOF
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger --subsystem-match=misc --sysname-match=uinput 2>/dev/null || true

if ! command -v ydotool >/dev/null 2>&1 || ! command -v ydotoold >/dev/null 2>&1; then
  echo "==> installing ydotool"
  if command -v pacman >/dev/null 2>&1; then
    pacman -S --needed --noconfirm ydotool
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update && apt-get install -y ydotool
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y ydotool
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install ydotool
  else
    echo "error: install the 'ydotool' package manually, then re-run." >&2
    exit 1
  fi
fi
YDOTOOLD_BIN="$(command -v ydotoold || true)"
if [[ -z "${YDOTOOLD_BIN}" ]]; then
  echo "error: ydotoold was not found after installing ydotool." >&2
  exit 1
fi

echo "==> ydotoold.service (socket ${SOCKET})"
cat > "${YDOTOOLD_UNIT}" <<UNIT_EOF
[Unit]
Description=ydotoold virtual input daemon (pc-control)
After=systemd-udevd.service

[Service]
Type=simple
ExecStart=${YDOTOOLD_BIN} --socket-path=${SOCKET} --socket-perm=0600 --socket-own=${TARGET_UID}:${TARGET_GID}
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
UNIT_EOF

if [[ ${WATCH_HUMAN} -eq 1 ]]; then
  command -v python3 >/dev/null 2>&1 || {
    echo "error: python3 is required for the humanwatch service." >&2
    exit 1
  }
  PYTHON="$(command -v python3)"
  echo "==> pc-control-humanwatch.service"
  install -Dm755 "${HERE}/scripts/humanwatch.py" "${WATCH_LIB}/humanwatch.py"
  cat > "${WATCH_UNIT}" <<UNIT_EOF
[Unit]
Description=pc-control physical input watcher
After=systemd-udevd.service

[Service]
Type=simple
RuntimeDirectory=pc-control
RuntimeDirectoryMode=0755
ExecStart=${PYTHON} ${WATCH_LIB}/humanwatch.py --runtime-dir /run/pc-control --uid ${TARGET_UID}
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT_EOF
  if [[ ! -d /dev/input ]]; then
    echo "warning: /dev/input is not available; the watcher will idle until it appears." >&2
  fi
else
  systemctl disable --now pc-control-humanwatch.service 2>/dev/null || true
  rm -f "${WATCH_UNIT}" "${WATCH_LIB}/humanwatch.py"
  rmdir "${WATCH_LIB}" 2>/dev/null || true
fi

systemctl daemon-reload
systemctl enable --now ydotoold.service
if [[ ${WATCH_HUMAN} -eq 1 ]]; then
  systemctl enable --now pc-control-humanwatch.service
fi
sleep 1

if ! systemctl is-active --quiet ydotoold.service; then
  echo "error: ydotoold failed; inspect: journalctl -u ydotoold -n 40" >&2
  exit 1
fi
if [[ ! -S "${SOCKET}" ]]; then
  echo "error: ${SOCKET} was not created." >&2
  exit 1
fi
if [[ ${WATCH_HUMAN} -eq 1 ]] && ! systemctl is-active --quiet pc-control-humanwatch.service; then
  echo "error: humanwatch failed; inspect: journalctl -u pc-control-humanwatch -n 40" >&2
  exit 1
fi

echo
echo "==> system setup complete"
echo "    socket: $(ls -l "${SOCKET}")"
echo "    ydotoold: $(systemctl is-active ydotoold.service)"
if [[ ${WATCH_HUMAN} -eq 1 ]]; then
  echo "    humanwatch: $(systemctl is-active pc-control-humanwatch.service)"
  echo "    privacy: only a timestamp is written to /run/pc-control/human-${TARGET_UID}"
fi
echo
echo
echo "Try:"
echo "    pc-control doctor"
echo "    pc-control status"

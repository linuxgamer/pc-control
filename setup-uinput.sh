#!/usr/bin/env bash
# One-time host setup for pc-control: uinput, ydotool, and the ydotoold daemon.
#
#   sudo ./setup-uinput.sh [--socket /run/ydotool.sock] [--user NAME]
#   sudo ./setup-uinput.sh --uninstall
#
# Installs the distribution's ydotool package when it is missing, loads the
# uinput module, adds one udev rule, and creates a systemd unit that owns the
# virtual input device and exposes a socket to the desktop user.
set -euo pipefail

SOCKET="/run/ydotool.sock"
TARGET_USER="${SUDO_USER:-}"
UNINSTALL=0

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --socket) SOCKET="${2:?--socket needs a path}"; shift 2 ;;
    --user) TARGET_USER="${2:?--user needs a name}"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

if [[ ${EUID} -ne 0 ]]; then
  echo "error: run this with sudo: sudo $0" >&2
  exit 1
fi

UNIT=/etc/systemd/system/ydotoold.service
RULE=/etc/udev/rules.d/60-uinput.rules
MODULE_CONF=/etc/modules-load.d/uinput.conf

if [[ ${UNINSTALL} -eq 1 ]]; then
  systemctl disable --now ydotoold.service 2>/dev/null || true
  rm -f "${UNIT}" "${RULE}" "${MODULE_CONF}"
  systemctl daemon-reload 2>/dev/null || true
  udevadm control --reload-rules 2>/dev/null || true
  echo "removed pc-control host setup (ydotool package left installed)"
  exit 0
fi

if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
  echo "error: cannot determine the desktop user." >&2
  echo "       run via sudo from your desktop shell, or pass --user NAME." >&2
  exit 1
fi
if ! id "${TARGET_USER}" >/dev/null 2>&1; then
  echo "error: user ${TARGET_USER} does not exist" >&2
  exit 1
fi
TARGET_UID="$(id -u "${TARGET_USER}")"
TARGET_GID="$(id -g "${TARGET_USER}")"

echo "==> enabling the uinput kernel module"
if ! modprobe uinput 2>/dev/null; then
  echo "warning: modprobe uinput failed; load it manually or reboot" >&2
fi
echo "uinput" > "${MODULE_CONF}"

echo "==> adding the udev rule"
cat > "${RULE}" <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
EOF
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

YDOTOOL_BIN="$(command -v ydotoold || true)"
if [[ -z "${YDOTOOL_BIN}" ]]; then
  echo "error: ydotoold was not found after installing ydotool." >&2
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "warning: systemd not found. Start the daemon manually:"
  echo "  sudo ${YDOTOOL_BIN} --socket-path=${SOCKET} --socket-perm=0600 --socket-own=${TARGET_UID}:${TARGET_GID}"
  exit 0
fi

echo "==> installing ydotoold.service (socket ${SOCKET})"
cat > "${UNIT}" <<EOF
[Unit]
Description=ydotoold virtual input daemon (pc-control)
After=systemd-udevd.service

[Service]
Type=simple
ExecStart=${YDOTOOL_BIN} --socket-path=${SOCKET} --socket-perm=0600 --socket-own=${TARGET_UID}:${TARGET_GID}
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ydotoold.service
sleep 1

if ! systemctl is-active --quiet ydotoold.service; then
  echo "error: ydotoold failed to start. Inspect: journalctl -u ydotoold -n 50" >&2
  exit 1
fi
if [[ ! -S "${SOCKET}" ]]; then
  echo "error: ${SOCKET} was not created." >&2
  exit 1
fi

echo
echo "==> done"
echo "    socket: $(ls -l "${SOCKET}")"
echo "    daemon: $(systemctl is-active ydotoold.service)"
echo
echo "Next, as ${TARGET_USER}:"
echo "    pc-control doctor"
echo "    pc-control shot"
echo
echo "Tip: ydotool absolute moves are affected by pointer acceleration."
echo "pc-control measures the real cursor instead, so this mostly matters for"
echo "other tools."

#!/usr/bin/env bash
# Optional: install a root service that records physical input activity.
#
#   sudo ./setup-humanwatch.sh [--uid 1000]
#   sudo ./setup-humanwatch.sh --uninstall
#
# It reads /dev/input and writes ONLY a timestamp to /run/pc-control/human-UID.
# It never stores key codes, button numbers, or text. pc-control uses the
# timestamp to yield when a human is typing or moving the mouse.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-}"
TARGET_UID=""
UNINSTALL=0

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uid) TARGET_UID="${2:?--uid needs a number}"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

if [[ ${EUID} -ne 0 ]]; then
  echo "error: run with sudo: sudo $0" >&2
  exit 1
fi

UNIT=/etc/systemd/system/pc-control-humanwatch.service
LIB=/usr/local/lib/pc-control

if [[ ${UNINSTALL} -eq 1 ]]; then
  systemctl disable --now pc-control-humanwatch.service 2>/dev/null || true
  rm -f "${UNIT}" "${LIB}/humanwatch.py"
  rmdir "${LIB}" 2>/dev/null || true
  systemctl daemon-reload 2>/dev/null || true
  echo "removed pc-control-humanwatch"
  exit 0
fi

if [[ -z "${TARGET_UID}" ]]; then
  if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
    echo "error: cannot determine the desktop user; pass --uid N." >&2
    exit 1
  fi
  TARGET_UID="$(id -u "${TARGET_USER}")"
fi

if [[ ! -d /dev/input ]]; then
  echo "warning: /dev/input is not available; the watcher will idle until it appears." >&2
fi
PYTHON="$(command -v python3 || true)"
if [[ -z "${PYTHON}" ]]; then
  echo "error: python3 is required." >&2
  exit 1
fi

install -Dm755 "${HERE}/scripts/humanwatch.py" "${LIB}/humanwatch.py"

cat > "${UNIT}" <<UNIT_EOF
[Unit]
Description=pc-control physical input watcher
After=systemd-udevd.service

[Service]
Type=simple
RuntimeDirectory=pc-control
RuntimeDirectoryMode=0755
ExecStart=${PYTHON} ${LIB}/humanwatch.py --runtime-dir /run/pc-control --uid ${TARGET_UID}
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT_EOF

systemctl daemon-reload
systemctl enable --now pc-control-humanwatch.service
sleep 1
if ! systemctl is-active --quiet pc-control-humanwatch.service; then
  echo "error: service failed; inspect: journalctl -u pc-control-humanwatch -n 40" >&2
  exit 1
fi

echo "==> installed pc-control-humanwatch for uid ${TARGET_UID}"
echo "    move the mouse or type, then run: pc-control status"
echo "    threshold: PC_HUMAN_IDLE_MS (default 800)"
echo "    privacy: only a timestamp is written to /run/pc-control/human-${TARGET_UID}"

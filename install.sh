#!/usr/bin/env bash
# Install pc-control for the current user: the CLI plus the LLM skill.
#
#   ./install.sh                 # ~/.local/bin + ~/.dsh/skills
#   ./install.sh --local         # ./.pc-control/bin + ./.dsh/skills (repo checkout)
#   ./install.sh --no-skill      # CLI only
#   ./install.sh --uninstall
#
# No sudo is needed. Run ./setup-uinput.sh once with sudo for the input daemon.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="${PREFIX}/bin"
SKILL_DIR="${DSH_HOME:-$HOME/.dsh}/skills"
INSTALL_SKILL=1
LOCAL=0
UNINSTALL=0

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="${2:?--prefix needs a path}"; BIN_DIR="${PREFIX}/bin"; shift 2 ;;
    --bin-dir) BIN_DIR="${2:?--bin-dir needs a path}"; shift 2 ;;
    --skill-dir) SKILL_DIR="${2:?--skill-dir needs a path}"; shift 2 ;;
    --no-skill) INSTALL_SKILL=0; shift ;;
    --local) LOCAL=1; BIN_DIR="$PWD/.pc-control/bin"; SKILL_DIR="$PWD/.dsh/skills"; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

if [[ ${UNINSTALL} -eq 1 ]]; then
  rm -f "${BIN_DIR}/pc-control"
  rm -f "${SKILL_DIR}/pc-control/SKILL.md"
  rmdir "${SKILL_DIR}/pc-control" 2>/dev/null || true
  echo "removed ${BIN_DIR}/pc-control and the pc-control skill"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || {
  echo "error: python3 is required" >&2
  exit 1
}

install -Dm755 "${HERE}/pc-control" "${BIN_DIR}/pc-control"
if [[ ${INSTALL_SKILL} -eq 1 ]]; then
  install -Dm644 "${HERE}/skill/SKILL.md" "${SKILL_DIR}/pc-control/SKILL.md"
fi

echo "installed:"
echo "  ${BIN_DIR}/pc-control"
[[ ${INSTALL_SKILL} -eq 1 ]] && echo "  ${SKILL_DIR}/pc-control/SKILL.md"

echo
echo "checks:"
command -v ydotool >/dev/null 2>&1 \
  && echo "  ydotool: ok" \
  || echo "  ydotool: MISSING — run: sudo ${HERE}/setup-uinput.sh"
python3 -c 'import PIL' >/dev/null 2>&1 \
  && echo "  Pillow: ok (compact shots)" \
  || echo "  Pillow: missing — python3 -m pip install --user pillow (compact shots)"
command -v tesseract >/dev/null 2>&1 \
  && echo "  tesseract: ok (OCR)" \
  || echo "  tesseract: optional (OCR)"
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
echo "next:"
echo "  pc-control doctor"
echo "  pc-control shot"

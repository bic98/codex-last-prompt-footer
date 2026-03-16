#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${STATE_DIR:-$HOME/.codex-last-prompt-footer}"
CONFIG_DIR="$STATE_DIR/config"
FOOTER_STATE_FILE="$CONFIG_DIR/footer-enabled"

log() {
  printf '[codex-last-prompt-footer] %s\n' "$1"
}

usage() {
  cat <<'EOF'
Usage:
  bash ./scripts/control.sh enable
  bash ./scripts/control.sh disable
  bash ./scripts/control.sh status
EOF
}

ensure_state_file() {
  mkdir -p "$CONFIG_DIR"
  if [[ ! -f "$FOOTER_STATE_FILE" ]]; then
    printf '1\n' > "$FOOTER_STATE_FILE"
  fi
}

read_state() {
  ensure_state_file
  tr -d '[:space:]' < "$FOOTER_STATE_FILE"
}

write_state() {
  local value="$1"
  ensure_state_file
  printf '%s\n' "$value" > "$FOOTER_STATE_FILE"
}

command="${1:-status}"

case "$command" in
  enable)
    write_state "1"
    log "Footer preview enabled"
    ;;
  disable)
    write_state "0"
    log "Footer preview disabled"
    ;;
  status)
    current="$(read_state)"
    if [[ "$current" == "0" ]]; then
      log "Footer preview is disabled"
    else
      log "Footer preview is enabled"
    fi
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! pgrep -f "scripts/auto_git_push.sh" >/dev/null 2>&1; then
  nohup "$ROOT_DIR/scripts/auto_git_push.sh" > "$ROOT_DIR/.auto_git_push.log" 2>&1 &
  echo "[start] auto_git_push.sh arkaplanda baslatildi."
else
  echo "[start] auto_git_push.sh zaten calisiyor."
fi

exec "$ROOT_DIR/scripts/live_simulator_auto.sh"


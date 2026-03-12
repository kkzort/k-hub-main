#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v fswatch >/dev/null 2>&1; then
  echo "[sync] fswatch bulunamadi. Kurulum: brew install fswatch"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[sync] Bu klasor bir git deposu degil."
  exit 1
fi

HAS_ORIGIN=1
if ! git remote get-url origin >/dev/null 2>&1; then
  HAS_ORIGIN=0
  echo "[sync] origin remote yok. Simdilik sadece lokal commit atilacak."
fi

echo "[sync] Otomatik commit/push basladi."

while true; do
  fswatch -1 -r \
    --exclude '.*\.git/.*' \
    --exclude '.*/\.dart_tool/.*' \
    --exclude '.*/build/.*' \
    --exclude '.*/ios/Pods/.*' \
    --exclude '.*/\.flutter-sdk/.*' \
    . >/dev/null

  # Kisa debounce
  sleep 1

  git add -A
  if git diff --cached --quiet; then
    continue
  fi

  MSG="chore: auto sync $(date '+%Y-%m-%d %H:%M:%S')"
  git commit -m "$MSG" >/dev/null 2>&1 || true

  if [[ "$HAS_ORIGIN" -eq 1 ]]; then
    git push origin HEAD >/dev/null 2>&1 || echo "[sync] Push basarisiz, sonraki degisiklikte tekrar denenecek."
  fi
done


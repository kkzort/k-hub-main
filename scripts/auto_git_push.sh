#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[sync] Bu klasor bir git deposu degil."
  exit 1
fi

echo "[sync] Otomatik commit/push basladi (polling mode)."

while true; do
  sleep 2

  if [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then
    continue
  fi

  if ! git add -A; then
    echo "[sync] git add hatasi, yeniden denenecek."
    continue
  fi

  if git diff --cached --quiet; then
    continue
  fi

  MSG="chore: auto sync $(date '+%Y-%m-%d %H:%M:%S')"
  if ! git commit -m "$MSG" >/dev/null 2>&1; then
    echo "[sync] commit atilamadi (muhtemelen degisiklik kalmadi), devam ediliyor."
    continue
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    git push origin HEAD >/dev/null 2>&1 || \
      echo "[sync] Push basarisiz, sonraki degisiklikte tekrar denenecek."
  else
    echo "[sync] origin remote yok. Simdilik sadece lokal commit atiliyor."
  fi
done

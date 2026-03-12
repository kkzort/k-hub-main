#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FLUTTER_BIN="${FLUTTER_BIN:-/Users/efekaantedik/flutter-sdk-local/bin/flutter}"
DEVICE_ID="${DEVICE_ID:-64AC636C-FBD5-46D1-AF8B-EFC7C89D6F92}"

if ! command -v fswatch >/dev/null 2>&1; then
  echo "[live] fswatch bulunamadi. Kurulum: brew install fswatch"
  exit 1
fi

echo "[live] Simulator aciliyor ($DEVICE_ID)..."
open -a Simulator >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null 2>&1 || true

echo "[live] Otomatik yenileme basladi."
echo "[live] Degisiklik algilaninca uygulama simulatorde otomatik yeniden baslayacak."

while true; do
  "$FLUTTER_BIN" run -d "$DEVICE_ID" &
  APP_PID=$!

  fswatch -1 -r \
    --exclude '.*\.git/.*' \
    --exclude '.*/\.dart_tool/.*' \
    --exclude '.*/build/.*' \
    --exclude '.*/ios/Pods/.*' \
    --exclude '.*/ios/Flutter/.*' \
    --exclude '.*/\.flutter-sdk/.*' \
    lib assets pubspec.yaml pubspec.lock >/dev/null

  echo "[live] Degisiklik algilandi, uygulama yeniden baslatiliyor..."
  kill -TERM "$APP_PID" >/dev/null 2>&1 || true
  wait "$APP_PID" >/dev/null 2>&1 || true
done

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_ID="${1:-}"
APP_BUNDLE_ID="com.khub.app"
BUILD_APP_PATH="$ROOT_DIR/build/ios/Debug-iphonesimulator/Runner.app"
SIGNED_APP_DIR="/tmp/khub-signed"
SIGNED_APP_PATH="$SIGNED_APP_DIR/Runner.app"
SIM_SIGN_ENTITLEMENTS="$ROOT_DIR/ios/Runner/SimulatorSign.entitlements"

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/{print $2; exit}')"
fi

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun simctl list devices | awk -F '[()]' '/iPhone 16e/{print $2; exit}')"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "Booted simulator bulunamadı. Bir cihaz ID verin:"
  echo "  ./scripts/run_ios_sim_signed.sh <SIMULATOR_UDID>"
  exit 1
fi

cd "$ROOT_DIR"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  echo "[1/5] iOS simulator build alınıyor (codesign kapalı)..."
  flutter build ios --simulator --debug --no-codesign
else
  echo "[1/5] SKIP_BUILD=1, mevcut build kullanılacak."
fi

if [[ ! -d "$BUILD_APP_PATH" ]]; then
  echo "Runner.app bulunamadı: $BUILD_APP_PATH"
  exit 1
fi

echo "[2/5] Uygulama /tmp altına kopyalanıyor..."
rm -rf "$SIGNED_APP_DIR"
mkdir -p "$SIGNED_APP_DIR"
rsync -a "$BUILD_APP_PATH" "$SIGNED_APP_DIR/"

echo "[3/5] Metadata temizlenip ad-hoc imzalanıyor..."
xattr -rc "$SIGNED_APP_PATH"
codesign --force --sign - --entitlements "$SIM_SIGN_ENTITLEMENTS" "$SIGNED_APP_PATH"

echo "[4/5] Simülatöre yükleniyor..."
xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl terminate "$DEVICE_ID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$DEVICE_ID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE_ID" "$SIGNED_APP_PATH"

echo "[5/5] Uygulama başlatılıyor..."
xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID"

echo "Tamamlandı. Cihaz: $DEVICE_ID"

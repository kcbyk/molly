#!/usr/bin/env bash
# Molly APK üretimi (yerel). Kullanım:
#   ./scripts/build_apk.sh https://sunucu-adresin.onrender.com [arm64-v8a]
# Sunucu adresi boş bırakılırsa yalnız evrensel APK üretilir ve uygulama
# localhost:3000'e bakar (telefonda çalışmaz, sadece emülatörde işe yarar).
set -euo pipefail

cd "$(dirname "$0")/.."

API_BASE="${1:-}"
ABI="${2:-}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "✖ flutter bulunamadı. https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

VERSION=$(grep -m1 '^version:' pubspec.yaml | sed 's/version: *//' | tr -d '[:space:]')
NAME="Molly-${VERSION%%+*}"

echo "→ flutter pub get"
flutter pub get

ARGS=(--release "--dart-define=API_BASE=${API_BASE}")
if [ -n "$ABI" ]; then
  ARGS+=(--target-platform "android-${ABI}")
fi

echo "→ flutter build apk ${ARGS[*]}"
flutter build apk "${ARGS[@]}"

mkdir -p dist
OUT="build/app/outputs/flutter-apk/app-release.apk"
SUFFIX="${ABI:-universal}"
cp "$OUT" "dist/${NAME}-${SUFFIX}.apk"
echo ""
echo "✓ dist/${NAME}-${SUFFIX}.apk"
ls -lh "dist/${NAME}-${SUFFIX}.apk"

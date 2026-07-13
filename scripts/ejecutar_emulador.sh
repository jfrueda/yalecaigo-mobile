#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

API_BASE_URL="${API_BASE_URL:-http://10.0.2.2:8088/api}"
API_LOGS="${API_LOGS:-true}"

if [[ ! -d android ]]; then
  echo "ERROR: falta android/. Ejecuta primero scripts/reconstruir_android.sh" >&2
  exit 1
fi

flutter devices
flutter run \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --dart-define="API_LOGS=$API_LOGS"

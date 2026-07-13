#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPLACEMENT_DIR="$SCRIPT_DIR/replacement"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$PROJECT_DIR/backups/analyze_fix_$STAMP"

if [[ ! -f "$PROJECT_DIR/pubspec.yaml" || ! -d "$PROJECT_DIR/lib" ]]; then
  echo "ERROR: $PROJECT_DIR no parece ser la raiz de un proyecto Flutter."
  echo "Uso: ./apply_fix.sh /ruta/al/proyecto/yalecaigo"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

FILES_TO_REPLACE=(
  "lib/core/network/auth_interceptor.dart"
  "lib/features/location/data/location_search_service.dart"
  "lib/features/location/presentation/pick_location_page.dart"
  "lib/features/service_request/presentation/create_request_page.dart"
)

LEGACY_FILES=(
  "lib/features/auth/data/services_service.dart"
  "lib/features/auth/presentation/splash_page.dart"
  "lib/features/home/data/home_service.dart"
  "lib/features/provider/data/provider_offer_service.dart"
  "lib/features/provider/presentation/provider_offer_detail_page.dart"
  "lib/features/provider/presentation/provider_active_service_page.dart"
  "lib/features/provider/presentation/provider_home_page.dart"
)

for rel in "${FILES_TO_REPLACE[@]}"; do
  if [[ -f "$PROJECT_DIR/$rel" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$PROJECT_DIR/$rel" "$BACKUP_DIR/$rel"
  fi
  mkdir -p "$PROJECT_DIR/$(dirname "$rel")"
  cp -a "$REPLACEMENT_DIR/$rel" "$PROJECT_DIR/$rel"
done

for rel in "${LEGACY_FILES[@]}"; do
  if [[ -f "$PROJECT_DIR/$rel" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$PROJECT_DIR/$rel" "$BACKUP_DIR/$rel"
    rm -f "$PROJECT_DIR/$rel"
  fi
done

find "$PROJECT_DIR/lib" -type d -empty -delete 2>/dev/null || true

echo "Correccion aplicada."
echo "Respaldo: $BACKUP_DIR"
echo
echo "Ahora ejecuta:"
echo "  cd \"$PROJECT_DIR\""
echo "  dart format lib test"
echo "  flutter analyze"
echo "  flutter test"

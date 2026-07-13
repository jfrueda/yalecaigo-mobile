#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: Flutter no está disponible en PATH." >&2
  echo "Instala Flutter estable y vuelve a ejecutar este script." >&2
  exit 1
fi

if [[ ! -f pubspec.yaml || ! -d lib ]]; then
  echo "ERROR: el proyecto debe contener pubspec.yaml y lib/." >&2
  exit 1
fi

# MainActivity.kt del archivo recuperado confirma este applicationId:
# opentic.co.yalecaigo
ORG="${FLUTTER_ORG:-opentic.co}"
PROJECT_NAME="${FLUTTER_PROJECT_NAME:-yalecaigo}"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$ROOT_DIR/.recovery_backups/$STAMP"
mkdir -p "$BACKUP_DIR"

cp -a lib "$BACKUP_DIR/lib"
cp -a pubspec.yaml "$BACKUP_DIR/pubspec.yaml"
if [[ -f analysis_options.yaml ]]; then
  cp -a analysis_options.yaml "$BACKUP_DIR/analysis_options.yaml"
fi
if [[ -d test ]]; then
  cp -a test "$BACKUP_DIR/test"
fi

# El ZIP recuperado contiene una carpeta android parcial: varios archivos
# esenciales quedaron en 0 bytes. Flutter no siempre sobrescribe esos archivos,
# por eso la plataforma se elimina y se regenera cuando está incompleta.
ANDROID_INVALID=false
for required in \
  android/app/build.gradle.kts \
  android/gradle.properties \
  android/gradle/wrapper/gradle-wrapper.properties \
  android/gradle/wrapper/gradle-wrapper.jar \
  android/gradlew; do
  if [[ ! -s "$required" ]]; then
    ANDROID_INVALID=true
  fi
done

if [[ -d android && ( "$ANDROID_INVALID" == "true" || "${FORCE_RECREATE_ANDROID:-false}" == "true" ) ]]; then
  echo "==> Respaldando y eliminando la plataforma Android incompleta"
  cp -a android "$BACKUP_DIR/android_recuperado"
  rm -rf android
fi

echo "==> Flutter detectado"
flutter --version

echo "==> Generando Android con applicationId=${ORG}.${PROJECT_NAME}"
flutter create \
  --platforms=android \
  --org "$ORG" \
  --project-name "$PROJECT_NAME" \
  .

# flutter create puede normalizar archivos ya existentes. Restauramos el código
# funcional para que la operación solo repare la plataforma y los metadatos.
rm -rf lib
cp -a "$BACKUP_DIR/lib" lib
cp -a "$BACKUP_DIR/pubspec.yaml" pubspec.yaml
if [[ -f "$BACKUP_DIR/analysis_options.yaml" ]]; then
  cp -a "$BACKUP_DIR/analysis_options.yaml" analysis_options.yaml
fi
if [[ -d "$BACKUP_DIR/test" ]]; then
  rm -rf test
  cp -a "$BACKUP_DIR/test" test
fi

MAIN_MANIFEST="android/app/src/main/AndroidManifest.xml"
if [[ -f "$MAIN_MANIFEST" ]] && ! grep -q 'android.permission.INTERNET' "$MAIN_MANIFEST"; then
  python3 - "$MAIN_MANIFEST" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
needle = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
permission = '    <uses-permission android:name="android.permission.INTERNET" />\n'
if needle in text and 'android.permission.INTERNET' not in text:
    text = text.replace(needle, needle + '\n' + permission, 1)
    path.write_text(text)
PY
fi

# HTTP sin cifrar se habilita solo en debug para conectar con Django local.
mkdir -p android/app/src/debug
cat > android/app/src/debug/AndroidManifest.xml <<'MANIFEST'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:usesCleartextTraffic="true" />
</manifest>
MANIFEST

chmod +x android/gradlew 2>/dev/null || true

echo "==> Descargando dependencias"
flutter pub get

echo "==> Formateando Dart"
if [[ -d test ]]; then
  dart format lib test
else
  dart format lib
fi

echo "==> Análisis estático"
ANALYZE_STATUS=0
flutter analyze || ANALYZE_STATUS=$?

echo "==> Pruebas"
TEST_STATUS=0
if [[ -d test ]]; then
  flutter test || TEST_STATUS=$?
else
  echo "No hay carpeta test/."
fi

cat <<MSG

Android fue reconstruido.

Ejecutar en el emulador:
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8088/api --dart-define=API_LOGS=true

Application ID:
  ${ORG}.${PROJECT_NAME}

Respaldo previo:
  $BACKUP_DIR

Resultado:
  flutter analyze: $ANALYZE_STATUS
  flutter test:    $TEST_STATUS
MSG

if [[ $ANALYZE_STATUS -ne 0 || $TEST_STATUS -ne 0 ]]; then
  echo "AVISO: Android quedó generado, pero hay diagnósticos por revisar." >&2
  if [[ "${STRICT_CHECKS:-false}" == "true" ]]; then
    exit 2
  fi
fi

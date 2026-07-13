#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8088/api}"
BASE_URL="${BASE_URL%/}"
TMP_BODY="$(mktemp)"
trap 'rm -f "$TMP_BODY"' EXIT

URL="$BASE_URL/auth/token/"
printf 'Probando %s\n' "$URL"

set +e
STATUS="$(curl -sS \
  --connect-timeout 5 \
  --max-time 15 \
  -o "$TMP_BODY" \
  -w '%{http_code}' \
  "$URL")"
CURL_EXIT=$?
set -e

if [[ $CURL_EXIT -ne 0 || "$STATUS" == "000" ]]; then
  echo "ERROR: no hay conexión HTTP con el backend." >&2
  echo "Comprueba que Django/Docker publique el puerto 8088 en 0.0.0.0." >&2
  exit 1
fi

echo "Backend accesible. HTTP $STATUS"
echo "Un 401, 403 o 405 en esta prueba también confirma que el servidor responde."
echo "Primeros 400 bytes de la respuesta:"
head -c 400 "$TMP_BODY" || true
printf '\n'

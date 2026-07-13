# Frontend Flutter unificado — YaLeCaigo / Acompañante

Este proyecto Flutter fue alineado con el backend Django incluido en el paquete
unificado. El objetivo actual es volver a tener un flujo local reproducible para
cliente y prestador antes de continuar con GPS real, pagos y publicación.

## Estado validado

El backend fue revisado y corregido junto con este frontend. El contrato que
queda como base del MVP es:

1. JWT y renovación de sesión.
2. Perfil con rol y estado de verificación.
3. Registro de cliente o prestador.
4. Cliente crea y consulta solicitudes.
5. Prestador verificado consulta solicitudes disponibles y acepta una.
6. Cliente y prestador envían ubicaciones simuladas para probar el autoarranque.

El flujo principal del prestador es **aceptación directa de solicitudes**. El
código de ofertas fue retirado del flujo Flutter y quedó documentado como una
posible ampliación experimental del backend.

## Hallazgo importante sobre Android

La carpeta `android/` recibida sí identifica el paquete original como:

```text
opentic.co.yalecaigo
```

pero varios archivos esenciales estaban vacíos, entre ellos Gradle, wrapper,
manifests de debug/profile e iconos. Los archivos recuperables se conservaron en
`docs/android_recuperado_incompleto/`. El script `scripts/reconstruir_android.sh`
genera una plataforma Android limpia y conserva el identificador anterior.

## 1. Preparar el proyecto

Descomprime este frontend en una carpeta nueva, no encima del proyecto antiguo:

```bash
cd ~/StudioProjects
unzip yalecaigo_flutter_unificado.zip
cd yalecaigo_flutter_unificado
```

Protege el punto de partida:

```bash
git init
git add .
git commit -m "Base Flutter unificada con backend"
```

## 2. Verificar Flutter y Android

```bash
flutter --version
dart --version
flutter doctor -v
flutter doctor --android-licenses
flutter devices
```

Abre en Android Studio la carpeta raíz que contiene `pubspec.yaml`, no solamente
la subcarpeta `android/`.

## 3. Regenerar Android

```bash
chmod +x scripts/*.sh
./scripts/reconstruir_android.sh
```

El script:

- detecta si Android falta o está incompleto;
- respalda cualquier fuente existente en `.recovery_backups/`;
- ejecuta `flutter create --platforms=android`;
- usa `opentic.co.yalecaigo` como application ID;
- habilita HTTP local solamente en debug;
- ejecuta `flutter pub get`, formato, análisis y pruebas.

## 4. Levantar el backend

El backend debe responder en el computador en:

```text
http://127.0.0.1:8088/api
```

Desde Android Emulator se accede a la misma API mediante:

```text
http://10.0.2.2:8088/api
```

Comprueba la conexión desde esta carpeta:

```bash
./scripts/probar_backend.sh http://127.0.0.1:8088/api
```

## 5. Ejecutar en el emulador

Inicia el dispositivo desde Android Studio y ejecuta:

```bash
./scripts/ejecutar_emulador.sh
```

Equivale a:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8088/api \
  --dart-define=API_LOGS=true
```

Los logs muestran método, URL y estado HTTP, pero no tokens ni contraseñas.

## 6. Generar un APK debug

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Resultado:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Instalación en el emulador activo:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 7. Cuentas y permisos

La API devuelve estos roles al móvil:

```text
client
provider
admin
```

El modelo Django guarda los roles y estados en mayúscula internamente. Flutter
no necesita conocer esa diferencia porque `/security/me/` los normaliza.

- Un cliente `PENDING` puede usar el MVP.
- Un prestador debe estar `VERIFIED` para ver o aceptar solicitudes.
- Una cuenta `SUSPENDED` queda bloqueada.

El backend incluye el comando:

```bash
python manage.py bootstrap_dev
```

para crear dos usuarios locales y pedir nuevas contraseñas de forma interactiva.

## 8. Ubicación actual

Los botones de ubicación todavía usan las coordenadas del punto de encuentro y
envían `source: simulated`. Sirven para comprobar el contrato y la transición de
`matched` a `started`, pero no representan el GPS real del teléfono.

La siguiente fase debe integrar permisos Android, captura con un paquete de
geolocalización, manejo de precisión y ejecución en primer/segundo plano.

## 9. Documentos útiles

- `docs/API_CONTRACT.md`: contrato exacto entre Django y Flutter.
- `docs/DIAGNOSTICO_CODIGO_RECIBIDO.md`: problemas encontrados.
- `docs/REINICIAR_BACKEND_Y_PASSWORDS.md`: recuperación de usuarios.
- `docs/MATRIZ_ALINEACION.md`: correspondencia pantalla por endpoint.

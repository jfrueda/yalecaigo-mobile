# Diagnóstico de los dos ZIP recibidos

## Backend Django

El backend incluía código suficiente para reconstruir el contrato, pero tenía
inconsistencias que impedían trabajar con el Flutter de forma segura:

- `/security/me/` comprobaba un atributo `is_verified` que no existe en el modelo;
  la verificación real está en `User.status`.
- `/auth/me/` referenciaba un serializer inexistente o con campos incorrectos.
- Flutter llamaba `/auth/register/`, pero la ruta no estaba implementada.
- `/api/services/` estaba incluido dos veces.
- Había una mezcla de estados de solicitudes en mayúscula y minúscula.
- Flutter enviaba `notes`, pero el modelo y serializer no tenían el campo.
- Faltaban detalle y solicitud activa en el contrato usado por la aplicación.
- El ping intentaba guardar un campo de modelo inexistente y restringía mal los
  participantes.
- Los permisos del flujo de ofertas estaban invertidos en varios puntos.
- La aceptación directa no protegía adecuadamente frente a dos prestadores.
- El módulo de matching tenía imports incorrectos y variables no definidas.
- El autoarranque podía fallar cuando no existía un pago asociado.
- La señal del chat no se registraba desde la configuración de la app.
- `requirements.txt` contenía un paquete redundante con nombre incorrecto.

Estos puntos se corrigieron en el backend unificado y se añadieron pruebas de
integración.

## Frontend Flutter

El código Flutter principal estaba presente, pero se encontraron:

- cliente HTTP, endpoints y servicio de consulta reconstruidos en la versión
  anterior;
- dos flujos de prestador: datos simulados, aceptación directa y ofertas;
- registro sin selección de rol;
- bloqueo de todos los usuarios no verificados, aunque el backend solo exige
  verificación al prestador;
- estados activos sin `searching`;
- ping con un campo temporal que el modelo no tenía;
- identificador de paquete escrito de dos formas diferentes.

El Flutter unificado usa una sola ruta de prestador, registro con rol, estado de
cuenta coherente y `source: simulated` para los pings.

## Plataforma Android

El ZIP sí contiene `android/` y permite recuperar el paquete:

```text
opentic.co.yalecaigo
```

Sin embargo, estos archivos esenciales llegaron con tamaño cero:

```text
android/app/build.gradle.kts
android/gradle.properties
android/gradle/wrapper/gradle-wrapper.properties
android/gradle/wrapper/gradle-wrapper.jar
android/gradlew
android/gradlew.bat
android/app/src/debug/AndroidManifest.xml
android/app/src/profile/AndroidManifest.xml
```

También llegaron vacíos varios iconos y metadatos. Android no puede compilarse
directamente con esos archivos. Los pocos fuentes válidos quedaron en
`docs/android_recuperado_incompleto/`; `scripts/reconstruir_android.sh` regenera
la plataforma con Flutter.

## Validación ejecutada sobre el backend unificado

Se ejecutó con un entorno limpio:

```text
ruff check: aprobado
python manage.py check: 0 problemas
makemigrations --check --dry-run: sin cambios pendientes
python manage.py test: 9 pruebas aprobadas
```

La migración nueva también fue aplicada correctamente sobre una base temporal.

## Validación pendiente en Flutter

Este entorno no contiene el SDK completo de Flutter, por lo que la compilación
Android y `flutter analyze` deben ejecutarse en tu equipo. El script de
reconstrucción realiza ambos pasos y conserva los códigos de salida.

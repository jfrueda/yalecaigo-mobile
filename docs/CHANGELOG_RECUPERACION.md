# Cambios aplicados en la recuperación

## Red y autenticación

- Nuevo `core/network/api_client.dart`.
- Nuevo catálogo `core/network/endpoints.dart`.
- URL base configurable mediante `API_BASE_URL`.
- Logs de red optativos y sanitizados mediante `API_LOGS`.
- Renovación JWT con control de reintento y soporte de refresh rotado.
- `/auth/me/` ya recibe token; solo login, refresh y registro se tratan como
  rutas públicas.

## Solicitudes

- Nuevo `ServiceRequestQueryService` con soporte para listas paginadas.
- Fallback cuando el backend no implementa `/services/requests/active/`.
- Se envía `notes` al crear solicitudes.
- Se normalizan estados en minúsculas.
- Se corrigió el retorno del selector de ubicación en mapa: la pantalla devolvía
  `PickedLocation`, pero el formulario esperaba un `Map`.

## Navegación

- El cliente entra a `HomePage`.
- El proveedor entra al listado real de solicitudes disponibles.
- Registro y login pasan por `RoleGatePage`.
- Se agregó cierre de sesión al listado del proveedor.
- Las pantallas simuladas y el flujo alternativo de ofertas se preservaron como
  texto en `docs/legacy_source/`, fuera del análisis del compilador.

## Proyecto

- Restricción Dart estable: `>=3.8.0 <4.0.0`.
- Test de contador reemplazado por una prueba del parser de categorías.
- Scripts para regenerar Android, probar el backend y ejecutar el emulador.
- Documentación de API, recuperación de contraseñas y diagnóstico del ZIP.

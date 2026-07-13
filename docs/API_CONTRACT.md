# Contrato API unificado entre Flutter y Django

## Base URL

Computador:

```text
http://127.0.0.1:8088/api
```

Android Emulator:

```text
http://10.0.2.2:8088/api
```

## Autenticación

### Obtener JWT

```http
POST /auth/token/
Content-Type: application/json
```

```json
{
  "username": "cliente_demo",
  "password": "NUEVA_CONTRASENA"
}
```

Respuesta:

```json
{
  "refresh": "...",
  "access": "...",
  "user": {
    "id": 1,
    "username": "cliente_demo",
    "role": "client",
    "status": "VERIFIED"
  }
}
```

### Renovar JWT

```http
POST /auth/token/refresh/
```

```json
{
  "refresh": "..."
}
```

Con rotación habilitada, la respuesta puede contener tanto `access` como un
nuevo `refresh`. Flutter conserva ambos correctamente.

### Registro

```http
POST /auth/register/
```

```json
{
  "username": "nuevo_usuario",
  "email": "opcional@example.com",
  "password": "ClaveSegura-2026!",
  "role": "client"
}
```

`role` admite:

```text
client
provider
```

Una cuenta nueva se crea con estado `PENDING`. El cliente puede entrar al MVP;
el prestador debe ser verificado antes de aceptar solicitudes.

### Perfil

Ruta principal:

```http
GET /security/me/
Authorization: Bearer ACCESS_TOKEN
```

Ruta equivalente:

```http
GET /auth/me/
```

Respuesta relevante:

```json
{
  "id": 1,
  "username": "prestador_demo",
  "email": "",
  "role": "provider",
  "status": "VERIFIED",
  "is_verified": true,
  "is_staff": false,
  "is_superuser": false,
  "profile": {
    "is_available": true
  }
}
```

## Categorías

```http
GET /services/categories/
```

Solo devuelve categorías activas. Campos:

```text
id, name, description, base_price_per_hour, is_active
```

## Solicitudes del cliente

```http
POST /services/requests/
GET  /services/requests/
GET  /services/requests/{id}/
GET  /services/requests/active/
```

Creación:

```json
{
  "category": 1,
  "location_text": "Lugar de encuentro",
  "location_lat": 4.6767,
  "location_lng": -74.0482,
  "requested_start_time": "2026-07-13T20:00:00.000Z",
  "requested_duration_minutes": 60,
  "notes": "Indicaciones adicionales",
  "preferred_gender": "F",
  "preferred_age_min": 25,
  "preferred_age_max": 35
}
```

El backend asigna el cliente autenticado, el estado inicial y el precio. No se
acepta una segunda solicitud activa para el mismo cliente.

Respuesta relevante:

```json
{
  "id": 10,
  "client": 1,
  "client_username": "cliente_demo",
  "category": 1,
  "category_name": "Acompañamiento general",
  "assigned_provider": null,
  "assigned_provider_username": null,
  "status": "pending",
  "notes": "Indicaciones adicionales",
  "calculated_price": "30000.00"
}
```

Estados canónicos:

```text
pending
searching
matched
started
ended
cancelled
expired
incident
```

Estados tratados como activos por el cliente:

```text
pending, searching, matched, started
```

## Flujo principal del prestador

Solo para un usuario `PROVIDER` con estado `VERIFIED`:

```http
GET  /services/requests/available/
POST /services/requests/{id}/accept/
GET  /services/requests/active/
GET  /services/requests/{id}/
```

La aceptación es transaccional. Si otro prestador tomó la solicitud o el usuario
ya tiene un servicio activo, el backend responde `409`.

## Ofertas experimentales

El backend conserva estas rutas para una fase posterior:

```http
GET  /services/offers/
POST /services/offers/{id}/accept/
POST /services/offers/{id}/reject/
```

El Flutter unificado no las usa. El MVP tiene un solo flujo principal: aceptación
directa de solicitudes disponibles.

## Pings de ubicación

```http
POST /services/location-pings/
```

```json
{
  "service_request": 10,
  "latitude": 4.6767,
  "longitude": -74.0482,
  "accuracy": 10.0,
  "source": "simulated"
}
```

Solo el cliente de la solicitud y su prestador asignado pueden enviar pings.
Los pings se habilitan cuando el estado es `matched` o `started`. Cuando ambos
usuarios están suficientemente cerca, el backend intenta cambiar el servicio a
`started`.

## Respuestas de error que Flutter maneja

- `400`: validación o solicitud activa duplicada.
- `401`: token inválido; Flutter intenta renovar una sola vez.
- `403`: rol, estado o verificación insuficiente.
- `404`: recurso o solicitud activa inexistente.
- `409`: conflicto al aceptar una solicitud ya tomada o teniendo otro servicio.

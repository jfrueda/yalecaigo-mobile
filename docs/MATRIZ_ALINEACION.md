# Matriz de alineación frontend ↔ backend

| Flujo Flutter | Endpoint Django | Permiso | Estado |
|---|---|---|---|
| Inicio de sesión | `POST /api/auth/token/` | Público | Alineado |
| Renovación JWT | `POST /api/auth/token/refresh/` | Público | Alineado |
| Registro | `POST /api/auth/register/` | Público | Alineado |
| Perfil/rol | `GET /api/security/me/` | Autenticado | Alineado |
| Categorías | `GET /api/services/categories/` | Autenticado | Alineado |
| Crear solicitud | `POST /api/services/requests/` | Cliente | Alineado |
| Mis solicitudes | `GET /api/services/requests/` | Cliente | Alineado |
| Detalle | `GET /api/services/requests/{id}/` | Participante | Alineado |
| Solicitud activa | `GET /api/services/requests/active/` | Participante | Alineado |
| Disponibles | `GET /api/services/requests/available/` | Prestador verificado | Alineado |
| Aceptar solicitud | `POST /api/services/requests/{id}/accept/` | Prestador verificado | Alineado |
| Ping de ubicación | `POST /api/services/location-pings/` | Participante | Alineado, simulado |
| Ofertas automáticas | `/api/services/offers/...` | Prestador verificado | Backend experimental; fuera del Flutter |

## Decisiones adoptadas

- Un único flujo principal para el prestador: aceptación directa.
- Estados públicos de solicitud en minúscula.
- Roles públicos en minúscula y estados de cuenta en mayúscula.
- El backend calcula cliente, estado y precio; Flutter no debe confiar en valores
  enviados por el usuario para esos campos.
- La verificación es obligatoria para el prestador, no para el cliente del MVP.
- HTTP local solo se habilita en la variante Android debug.

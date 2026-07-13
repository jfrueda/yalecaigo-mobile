# Reiniciar Django y recuperar acceso a usuarios

## 1. No intentes recuperar la contraseña original

Django guarda un hash. La operación correcta es establecer una contraseña nueva.
Conserva una copia de la base antes de migrar:

```bash
cp -a db.sqlite3 "db.sqlite3.antes_unificacion_$(date +%Y%m%d_%H%M%S).bak"
```

## 2. Preparar el backend unificado

```bash
cd /ruta/al/backend
chmod +x scripts/*.sh
./scripts/preparar_backend_local.sh
```

O manualmente:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python manage.py check
python manage.py migrate
python manage.py test
```

## 3. Listar usuarios, roles y estados

```bash
./scripts/listar_usuarios.sh
```

Equivalente:

```bash
python manage.py shell -c "from django.contrib.auth import get_user_model; U=get_user_model(); print(*U.objects.values_list('username','role','status'), sep='\n')"
```

## 4. Cambiar la contraseña de un usuario

```bash
python manage.py changepassword NOMBRE_USUARIO
```

El comando la solicita de forma interactiva y no la imprime.

## 5. Crear cuentas locales conocidas

```bash
python manage.py bootstrap_dev
```

Crea o actualiza:

```text
cliente_demo    CLIENT / VERIFIED
prestador_demo  PROVIDER / VERIFIED
```

También crea una categoría activa y habilita la capacidad del prestador. Las
contraseñas se solicitan en la terminal.

## 6. Crear un administrador

```bash
python manage.py createsuperuser
```

Después puedes usar:

```text
http://127.0.0.1:8088/admin/
```

para revisar usuarios, roles, estados, categorías y solicitudes.

## 7. Iniciar la API

```bash
./scripts/iniciar_backend.sh
```

Debe escuchar en:

```text
0.0.0.0:8088
```

## 8. Probar inicio de sesión sin exponer la clave en el historial

La forma más simple es usar la aplicación Flutter. Si necesitas `curl`, crea un
archivo temporal con permisos restrictivos o introduce la petición desde una
herramienta local que no guarde la contraseña en texto plano.

## 9. Errores habituales

- `401`: usuario o contraseña incorrectos, o token vencido.
- `403`: rol no permitido, prestador pendiente o cuenta suspendida.
- `404` en `/requests/active/`: el usuario no tiene un servicio activo.
- `409` al aceptar: otro prestador ya la tomó o el prestador tiene otro servicio.
- conexión rechazada desde el emulador: usa `10.0.2.2`, no `127.0.0.1`.

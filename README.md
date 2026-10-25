# MilkData

Monorepo con dos partes independientes:

```text
backend/    API REST en Node + Express + Sequelize + MySQL
frontend/   App móvil en Flutter
```

Cada carpeta tiene su propia documentación y sus propias dependencias. No comparten
`node_modules` ni configuración.

## Backend

La documentación completa está en [`backend/README.md`](backend/README.md).

### Con Docker (lo más simple)

Levanta MySQL y la API sin instalar nada más:

```bash
cd backend
docker compose up -d --build
docker compose exec api node scripts/seed.js
```

- API: <http://localhost:3000>
- Swagger: <http://localhost:3000/api-docs>
- MySQL: `localhost:3307` (3306 lo ocupa Laragon)

```bash
docker compose logs -f api    # ver el arranque
docker compose down           # apagar (conserva los datos)
docker compose down -v        # apagar y borrar la base
```

### ⚠️ La máquina solo tiene 7,9 GB de RAM

Docker, Gradle y el analizador de Dart no caben juntos. **El orden importa:**

```bash
cd backend && docker compose down     # ANTES de flutter build / flutter run
cd frontend && flutter build apk
cd backend && docker compose up -d    # después de compilar
```

Y después de compilar, parada de daemons: en `frontend\android` se ejecuta
`gradlew --stop`, y se matan `dartaotruntime`, `dartvm` y
`dart development-service`. Sin eso la máquina se queda sin memoria y el
siguiente `flutter analyze` falla con errores que no son de código.

### Dónde viven los datos

La base **no** está en el repositorio: está en el volumen de Docker
`milkdata_mysql_data`. `docker compose down` lo conserva; `down -v` lo borra.
Para verlo:

```bash
docker volume inspect milkdata_mysql_data
```

### Conectar el móvil

```powershell
powershell -ExecutionPolicy Bypass -File .\conectar-telefono.ps1
```

Repone `adb reverse tcp:3000 tcp:3000`, que **se cae cada vez** que se desenchufa
el cable, se reinicia el móvil o se lanza `flutter run`. Con `-Vigilar` lo
repone solo cada pocos segundos. No hace falta tocar el cortafuegos mientras se
use USB; por WiFi sí, y el perfil de red de Windows está en **Público**.

### Sin Docker

```bash
cd backend
pnpm install
pnpm run seed       # datos iniciales (admin@milkdata.com / Superadmin123!)
pnpm start          # http://localhost:3000
pnpm test           # 559 tests
```

## Frontend

App móvil en Flutter. Ver [`frontend/README.md`](frontend/README.md).

```bash
cd frontend
flutter pub get
flutter run          # con el celular conectado por USB y depuracion activa
```

## Comandos útiles desde la raiz

```bash
cd backend  && pnpm test     # la API
cd frontend && flutter analyze && flutter test
```

## Estado

Los **13 módulos** del móvil están hechos. La ficha de cada uno, las reglas que
salieron de cada paso y lo que queda por decidir están en
[`ROADMAP.md`](ROADMAP.md).

**Aviso importante:** el frontend **no está versionado en git**. Los commits que
hay son del backend. Si se pierde la carpeta, se pierden las trece pantallas.
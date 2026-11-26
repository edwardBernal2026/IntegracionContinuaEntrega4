# Integración Continua – Entrega proyecto 1 y Entrega proyecto 2

- **Entrega proyecto 1:** dos contenedores comunicados con Docker Compose (`app`: API de notas en Node.js, `db`: PostgreSQL).
- **Entrega proyecto 2:** pipeline en **Jenkins** (Jenkinsfile) que construye y prueba esos dos contenedores, con Jenkins instalado en un contenedor y configurado como código.

```
.
├── app/                         # Contenedor 1: API de notas (Node.js 20 + Express)
├── db/                          # Contenedor 2: PostgreSQL 16 (init.sql crea la tabla notas)
├── scripts/prueba-comunicacion.sh   # ida y vuelta app -> db -> app con curl y nombres de servicio
├── docker-compose.yml           # orquestación de los dos contenedores (Entrega 1)
├── .env.example                 # plantilla de variables (el .env real no se sube)
├── Jenkinsfile                  # pipeline de la Entrega 2
├── jenkins/                     # servidor Jenkins: Dockerfile, plugins, JCasC y compose
├── .github/workflows/docker-ci.yml  # pipeline de GitHub Actions de la Entrega 1
└── ejercicio-escenario4/        # ejercicio práctico de clase (app de inventario), solo referencia
```

## Entrega 1: levantar los dos contenedores

```bash
cp .env.example .env          # cambie la contraseña
docker compose up -d --build
sh scripts/prueba-comunicacion.sh
```

| Servicio | Papel | Imagen base | Puerto |
|----------|-------|-------------|--------|
| `app` | API REST de notas | `node:20.18.1-alpine3.20` | `3000` publicado al host |
| `db` | PostgreSQL con volumen persistente | `postgres:16.6-alpine3.20` | `5432` solo en la red `red_notas` |

La API llega a la base de datos por el **nombre del servicio `db`** (`DB_HOST=db`). Prueba manual de ida y vuelta desde el host:

```bash
curl -X POST http://localhost:3000/notas -H "Content-Type: application/json" -d '{"texto":"Hola desde curl"}'
curl http://localhost:3000/notas/1
```

## Entrega 2: Jenkins

```bash
cd jenkins
cp .env.example .env          # cambie las claves (admin y NOTAS_DB_PASSWORD)
docker compose up -d --build
```

- Interfaz: http://localhost:8081 (usuario `estudiante`). Se publica en el 8081 porque en el equipo de desarrollo el 8080 está ocupado.
- **JCasC** (`jenkins/jenkins.yaml`): usuario administrador, credencial `notas-db-password` y el job `notas-pipeline` creados sin asistente.
- **Plugins** (`jenkins/plugins.txt`): configuration-as-code, job-dsl, workflow-aggregator, git, credentials-binding, docker-workflow, junit, pipeline-graph-view.
- **Volumen persistente:** `jenkins_entrega2_home` guarda jobs, historial y credenciales.
- **Disparo automático:** Poll SCM cada ~2 minutos (`H/2 * * * *`); cada commit en `main` dispara un build.

Etapas del `Jenkinsfile`: **Revisar API** (contenedor efímero `node:20.18.1-alpine3.20`) → **Preparar entorno** (`.env` con la credencial) → **Construir imágenes** (`entrega3-app:N` y `entrega3-db:N`) → **Levantar contenedores** → **Prueba de comunicación**. Al final siempre apaga y borra los contenedores del build.

```bash
cd jenkins && docker compose down      # apaga Jenkins (los datos quedan en el volumen)
```

## Seguridad

- Las contraseñas viven en `.env` y en la credencial de Jenkins; ninguna va en el repositorio.
- Montar `/var/run/docker.sock` en Jenkins da control total del Docker del equipo: solo es aceptable en un laboratorio local.

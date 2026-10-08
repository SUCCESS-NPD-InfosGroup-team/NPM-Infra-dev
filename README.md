# NPD-RP Infra

Global Docker Compose environment for the NPD-RP microservices. Each service is its own repo, included here as a git submodule.

| Service    | Submodule           | Status      | Host port |
|------------|---------------------|-------------|-----------|
| Postgres   | —                   | active      | 5433      |
| Flyway     | — (`db/migration`)  | active      | —         |
| Backend    | `NPD-RP-Backend`    | active      | 8080      |
| Frontend   | `NPD-RP-Frontend`   | not created | 5173      |
| AI Service | `NPD-RP-AI-Service` | not created | 8000      |

## Getting started

```sh
git clone --recurse-submodules <this-repo-url>
cp .env.example .env
docker compose up --build
```

Already cloned without submodules: `git submodule update --init --recursive`.

Health check: `curl localhost:8080/actuator/health`

## Database migrations

The schema is versioned with [Flyway](https://documentation.red-gate.com/flyway). Migrations live in `db/migration` and the `flyway` service applies them on every `docker compose up`, after Postgres is healthy and before the backend starts. Already-applied versions are skipped, so the same files produce the same schema in every environment.

- Add a change: create `db/migration/V<next>__<description>.sql` (e.g. `V3__add_skills.sql`). Never edit a migration that has already been applied; add a new one instead.
- Run only the migrations: `docker compose run --rm flyway` (or `docker compose run --rm flyway info` to see what is applied).
- Start from scratch: `docker compose down -v` drops the `pgdata` volume.

The backend mounts the same folder and points `SPRING_FLYWAY_LOCATIONS` at it, so Spring Boot's Flyway validates the same migrations instead of its empty `classpath:db/migration`.

### Initial data model

Built from the 22 columns of the client's planner (`PLANIFICACION DE RECURSOS NPD`, sheet `PLANIFICADOR`). One `resource` row per employee, as in the planner; repeated values are catalogs.

| Planner column                | Stored in                                          |
|-------------------------------|----------------------------------------------------|
| CLIENTE                       | `resource.client_id` → `client`                    |
| PROYECTO ASIGNADO             | `resource.project_id` → `project` (belongs to a client) |
| LIDER NPD, COD LIDER          | `resource.leader_id` → `npd_leader` (`full_name`, `employee_code`) |
| COD EMPL                      | `resource.employee_code` (unique)                  |
| NOMBRE DE EMPLEADO            | `resource.full_name`                               |
| PUESTO                        | `resource.job_title_id` → `job_title`              |
| POSICIÓN                      | `resource.job_position_id` → `job_position`        |
| ROL ACTUAL EN CLIENTE         | `resource.client_role_id` → `client_role`          |
| NIVEL                         | `resource.level`                                   |
| FECHA DE INICIO               | `resource.start_date`                              |
| UEN                           | `resource.business_unit_id` → `business_unit`      |
| GENERO                        | `resource.gender_id` → `gender`                    |
| EQUIPO / LAPTOP               | `resource.equipment_provider_id` → `equipment_provider` |
| MES DE PROBATORIA             | `resource.probation_month` (1st of the month)      |
| MES DE VACACIONES             | `resource.vacation_month` (1st of the month)       |
| FECHA FINAL PROYECTO          | `resource.project_end_date` (`NULL` = INDEFINIDO)  |
| MES FINAL DE PROYECTO         | `resource.project_end_month` (generated from the end date) |
| ESTADO                        | `resource.status_id` → `resource_status`           |
| CORREO RECURSO                | `resource.email` (unique, case-insensitive)        |
| CONTACTO POR CLIENTE          | `resource.client_contact_email`                    |
| MODALIDAD LABORAL DEL RECURSO | `resource.work_modality_id` → `work_modality`      |

The migrations only create the schema; they load no data. Catalog names are unique case-insensitively, and a resource's project must belong to its client.

Each service's own `compose.yaml` still works standalone, but it uses the same host ports, so don't run both stacks at once.

## Adding the Frontend / AI Service

1. Create the repo on GitHub (`SUCCESS-NPD-InfosGroup-team/NPD-RP-Frontend` or `NPD-RP-AI-Service`).
2. Remove its commented block from `.gitmodules`, then add it:
   ```sh
   git submodule add https://github.com/SUCCESS-NPD-InfosGroup-team/NPD-RP-Frontend.git NPD-RP-Frontend
   ```
3. Uncomment its service in `docker-compose.yaml` and add the expected Dockerfile to the service repo (template in the comment).

## Updating submodules

```sh
git submodule update --remote --merge   # pull latest of each service
git add NPD-RP-Backend && git commit -m "Bump backend"
```

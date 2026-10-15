# NPD-RP Infra

Global Docker Compose environment for the NPD-RP microservices. Each service is its own repo, included here as a git submodule.

| Service    | Submodule           | Status      | Host port |
|------------|---------------------|-------------|-----------|
| Postgres   | —                   | active      | 5433      |
| Flyway     | — (`db/migration`)  | active      | —         |
| Backend    | `NPD-RP-Backend`    | active      | 8080      |
| Keycloak   | — (`keycloak/`)     | active      | 8081      |
| Frontend   | `NPD-RP-Frontend`   | not created | 5173      |
| AI Service | `NPD-RP-AI-Service` | not created | 8000      |

## Getting started

```sh
git clone --recurse-submodules <this-repo-url>
cp .env.example .env
docker compose up --build
```

> **Required file:** Keycloak needs the realm export `keycloak/npd-realm.json` to start with the project's realm, clients and API keys. It is not in git because it holds secrets: ask the team for it and copy it there **before the first `docker compose up`**. Without it Keycloak starts with only the `master` realm and the services that authenticate against it won't work. See [Keycloak](#keycloak).

Already cloned without submodules: `git submodule update --init --recursive`.

Health check: `curl localhost:8080/actuator/health`

## Database migrations

The schema is versioned with [Flyway](https://documentation.red-gate.com/flyway). Migrations live in `db/migration` and the `flyway` service applies them on every `docker compose up`, after Postgres is healthy and before the backend starts. Already-applied versions are skipped, so the same files produce the same schema in every environment.

- Add a change: create `db/migration/V<next>__<description>.sql` (e.g. `V3__add_skills.sql`). Never edit a migration that has already been applied; add a new one instead.
- Run only the migrations: `docker compose run --rm flyway` (or `docker compose run --rm flyway info` to see what is applied).
- Start from scratch: `docker compose down -v` drops the `pgdata` volume.

The backend mounts the same folder and points `SPRING_FLYWAY_LOCATIONS` at it, so Spring Boot's Flyway validates the same migrations instead of its empty `classpath:db/migration`.

### Initial data model

Built from the 22 columns of the client's planner (`PLANIFICACION DE RECURSOS NPD`, sheet `PLANIFICADOR`). A planner row is an employee plus one of their assignments:

- `employee`: the person (code, name, email, HR data, employment status).
- `assignment`: the employee on a project. An employee can have several active assignments at once; closed ones are kept as history.
- `resource_v`: view that rebuilds the planner columns, one row per active assignment (or one row for an employee without any).

| Planner column                | Stored in                                                   |
|-------------------------------|-------------------------------------------------------------|
| CLIENTE                       | `project.client_id` → `client` (through the assignment's project) |
| PROYECTO ASIGNADO             | `assignment.project_id` → `project` (`NULL` = without project) |
| LIDER NPD, COD LIDER          | `assignment.leader_id` → `employee` (the lead is an employee) |
| COD EMPL                      | `employee.code` (text, unique; admits temporary codes such as `T001`) |
| NOMBRE DE EMPLEADO            | `employee.full_name`                                        |
| PUESTO                        | `employee.job_title_id` → `job_title`                       |
| POSICIÓN                      | `employee.job_position_id` → `job_position`                 |
| ROL ACTUAL EN CLIENTE         | `assignment.client_role_id` → `client_role`                 |
| NIVEL                         | `employee.level`                                            |
| FECHA DE INICIO               | `employee.hire_date` (hire date); the start on each project is `assignment.start_date` |
| UEN                           | `employee.business_unit_id` → `business_unit`               |
| GENERO                        | `employee.gender_id` → `gender`                             |
| EQUIPO / LAPTOP               | `assignment.equipment_provider_id` → `equipment_provider`   |
| MES DE PROBATORIA             | `employee.probation_end_date`, calculated: `hire_date` + 90 days |
| MES DE VACACIONES             | `employee.vacation_month`, calculated: month when 11 months since `hire_date` are completed |
| FECHA FINAL PROYECTO          | `assignment.end_date` (`NULL` = INDEFINIDO)                 |
| MES FINAL DE PROYECTO         | `resource_v.project_end_month`, calculated from `end_date`  |
| ESTADO                        | `employee.status_id` → `resource_status` (Activo, Licencia, Baja) + `resource_v.assignment_situation` |
| CORREO RECURSO                | `employee.email` (required, unique, case-insensitive)       |
| CONTACTO POR CLIENTE          | `assignment.client_contact_email`                           |
| MODALIDAD LABORAL DEL RECURSO | `employee.work_modality_id` → `work_modality`               |

`assignment_situation` is derived, never typed: `SIN_PROYECTO` when there is no project, `PENDIENTE_CONFIRMACION` when the end date has passed and the assignment has not been extended or closed yet, and `ASIGNADO` otherwise. An employee is therefore never shown as departed just because a project ended.

V1 seeds only the fixed catalogs the application needs (`resource_status`, `business_unit`, `equipment_provider`, `work_modality`); no client or personal data from the planner is loaded. Catalog names are unique case-insensitively.

Each service's own `compose.yaml` still works standalone, but it uses the same host ports, so don't run both stacks at once.

## Keycloak

Runs `quay.io/keycloak/keycloak:26.7.5` in dev mode (HTTP, embedded H2 database in the `keycloak-data` volume).

- Admin console: http://localhost:8081, user and password from `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` in `.env` (only applied on the very first start).
- From the browser: `http://localhost:8081/realms/<realm>`. Tokens always carry this URL as `iss`.
- From other containers (e.g. the backend): `http://keycloak:8080/realms/<realm>` for the JWKS (`/protocol/openid-connect/certs`) and token endpoints. Validate the issuer against the `localhost:8081` URL, not this one.

### Login theme (`keycloak/themes/npd`)

The login pages use the `npd` theme, built from the Figma mockup (`NPD-InfosGroup`, frame *Login*). It extends Keycloak's `base` theme (templates and scripts only, no PatternFly) and maps Keycloak's `kc*` CSS classes to the NPD atoms in `resources/css/atoms.css`, so every login page (login, forgot password, complete profile, update password, errors) uses the same look. Texts are in `messages/messages_es.properties`; Barlow fonts are served by Keycloak itself.

- The realm must have `"loginTheme": "npd"` and Spanish enabled (`"internationalizationEnabled": true`, `"supportedLocales": ["es"]`, `"defaultLocale": "es"`). Keep them in the realm export; for a realm already imported, set them in *Realm settings → Themes / Localization*.
- `start-dev` disables theme caching: edit the CSS or templates and reload the page.
- `tokens.css` copies the values of `NPD-RP-frontend/src/styles/tokens.css`; keep both in sync.

### Realm export (`keycloak/*.json`)

On start Keycloak imports every `*.json` in `keycloak/` (mounted at `/opt/keycloak/data/import`). Each file must be named `<realm>-realm.json` after the realm it contains (the project realm is `npd`, so `npd-realm.json`); with any other name Keycloak refuses to start. The import only creates realms that don't exist yet: an already imported realm is never overwritten, so after changing the file run `docker compose down` and `docker volume rm <project>_keycloak-data` (or `docker compose down -v`, which also wipes Postgres) and start again.

The file is ignored by git (`keycloak/*.json` and `*realm*.json` in the root) because it contains client secrets, API keys and users. Share it through a secure channel, never in a commit or a chat.

Export the realm after configuring it in the admin console. Use the CLI, not the console's *Partial export*: that one masks client secrets as `**********` and leaves out users.

```sh
docker compose stop keycloak
docker compose run --rm keycloak export --dir /opt/keycloak/data/import --realm <realm> --users realm_file
docker compose start keycloak
```

This writes `keycloak/<realm>-realm.json`. In Git Bash prefix the second command with `MSYS_NO_PATHCONV=1`, otherwise it rewrites `/opt/...` into a Windows path and the export fails.

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

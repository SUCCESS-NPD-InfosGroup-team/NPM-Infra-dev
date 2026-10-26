# NPD-RP Infra

Global Docker Compose environment for the NPD-RP microservices. Each service is its own repo, included here as a git submodule.

| Service    | Submodule           | Status      | Host port |
|------------|---------------------|-------------|-----------|
| Postgres   | —                   | active      | 5433      |
| Backend    | `NPD-RP-Backend`    | active      | 8080      |
| Keycloak   | — (`keycloak/`)     | active      | 8081      |
| Frontend   | `NPD-RP-frontend`   | active      | 5173      |
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

The schema is versioned with [Flyway](https://documentation.red-gate.com/flyway) and owned by the backend: migrations live in `NPD-RP-Backend/src/main/resources/db/migration` and the backend applies the pending ones every time it starts. Already-applied versions are skipped. The data model is documented in [`NPD-RP-Backend/docs/database/README.md`](NPD-RP-Backend/docs/database/README.md).

- Add a change: create the migration in the backend repo (`V<next>__<description>.sql`, never edit one already applied), then bump the submodule here (see [Updating submodules](#updating-submodules)).
- See what is applied:
  ```sh
  docker compose exec postgres psql -U npd_rp -d npd_rp -c "select version, description, success from flyway_schema_history order by installed_rank"
  ```
- Start the database from scratch (deletes its data):
  ```sh
  docker compose stop
  docker volume rm success_pgdata
  ```
  Don't use `docker compose down -v`: it also deletes `keycloak-data`, with Keycloak's users and settings.

> **Old volumes:** a `success_pgdata` created when the migrations lived in this repo (`2 - create employee and assignment` in `flyway_schema_history`) doesn't match the backend's migrations, and the backend won't start. Delete that volume once, as above.

## Planner import

Loads the client's planner Excel into the database with the backend image (no web server). Rebuild the image whenever the backend code changes:

```powershell
docker compose build backend
docker compose run --rm `
  -v C:/Users/<you>/Documents/npd-import:/import `
  -e PLANNER_IMPORT_FILE=/import/planificador.xlsx `
  -e SPRING_MAIN_WEB_APPLICATION_TYPE=none `
  backend
```

It starts only Postgres, applies the migrations and leaves the report next to the Excel. Use a folder without spaces. Details and rules: [`NPD-RP-Backend/docs/planner-import/ejecucion.md`](NPD-RP-Backend/docs/planner-import/ejecucion.md).

Each service's own `compose.yaml` still works standalone, but it uses the same host ports, so don't run both stacks at once.

## Keycloak

Runs `quay.io/keycloak/keycloak:26.7.5` in dev mode (HTTP, embedded H2 database in the `keycloak-data` volume).

- Admin console: http://localhost:8081, user and password from `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` in `.env` (only applied on the very first start).
- From the browser: `http://localhost:8081/realms/<realm>`. Tokens always carry this URL as `iss`.
- From other containers (e.g. the backend): `http://keycloak:8080/realms/<realm>` for the JWKS (`/protocol/openid-connect/certs`) and token endpoints. Validate the issuer against the `localhost:8081` URL, not this one.
- The compose already wires the backend this way: `KEYCLOAK_ISSUER_URI` is the `localhost` URL of the `npd` realm and `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI` points at `keycloak:8080`.

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

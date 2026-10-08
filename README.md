# NPD-RP Infra

Global Docker Compose environment for the NPD-RP microservices. Each service is its own repo, included here as a git submodule.

| Service    | Submodule           | Status      | Host port |
|------------|---------------------|-------------|-----------|
| Postgres   | —                   | active      | 5433      |
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

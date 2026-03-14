# postgres17-postgis

Docker image with PostgreSQL 17/18 and preinstalled extensions:
- PostGIS 3
- pgvector
- TimescaleDB 2

## Local Run

Create `.env` from the example:

```bash
cp .env.example .env
```

Variables in `.env`:
- `POSTGRES_VERSION` - Postgres version to build (`17` or `18`)
- `POSTGRES_USER` - database user
- `POSTGRES_PASSWORD` - database user password
- `POSTGRES_DB` - default database name
- `PGADMIN_DEFAULT_EMAIL` - pgAdmin login email
- `PGADMIN_DEFAULT_PASSWORD` - pgAdmin password

Build from local `Dockerfile`:

```bash
docker compose up -d --build
```

Run published image from registry:

```bash
docker compose -f docker-compose.release.yml up -d
```

It always uses `docker.io/pivotdude/postgres-timescale-postgis-pgvector:latest`.

`docker-compose.release.yml` is intended for running the published image (no local build).

Services from `docker-compose.yml`:
- PostgreSQL: `127.0.0.1:5432`
- pgAdmin: `http://localhost:10001`

## CI/CD

A GitHub Actions workflow is configured in this repository:
- file: `.github/workflows/docker-publish.yml`
- trigger: push to `main` (and manual `workflow_dispatch`)
- actions: build Docker images and publish to:
  - `ghcr.io/<github_owner>/<repo>`
  - `docker.io/<DOCKERHUB_USERNAME>/<repo>`

### Required GitHub Secrets

Add these in Settings -> Secrets and variables -> Actions:
- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token

For `ghcr.io`, the built-in `GITHUB_TOKEN` is used.

## Image Tags

Published tags:
- `17`
- `18`
- `latest` (points to image `18`)

## Pull Images

GHCR:

```bash
docker pull ghcr.io/pivotdude/postgres-timescale-postgis-pgvector:17
docker pull ghcr.io/pivotdude/postgres-timescale-postgis-pgvector:18
docker pull ghcr.io/pivotdude/postgres-timescale-postgis-pgvector:latest
```

Docker Hub:

```bash
docker pull pivotdude/postgres-timescale-postgis-pgvector:17
docker pull pivotdude/postgres-timescale-postgis-pgvector:18
docker pull pivotdude/postgres-timescale-postgis-pgvector:latest
```

## License

MIT, see `LICENSE`.

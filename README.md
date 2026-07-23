# postgres-timescale-postgis-pgvector

Docker images with pinned PostgreSQL 17/18 on **Debian bookworm** and optional extension bundles:
- PostGIS 3 (included in every bundle)
- TimescaleDB 2
- pgvector

## Extension bundles

| Variant | PostGIS | TimescaleDB | pgvector | Example tag |
|---------|---------|-------------|----------|-------------|
| `timescale` | yes | yes | no | `18-timescale` |
| `pgvector` | yes | no | yes | `18-pgvector` |
| `full` | yes | yes | yes | `18-full` |

Switching bundles is just changing the image tag:

```yaml
image: pivotdude/postgres-timescale-postgis-pgvector:18-timescale
# later:
image: pivotdude/postgres-timescale-postgis-pgvector:18-pgvector
```

`18` and `latest` still point to the `full` bundle for backward compatibility.

## Local Run

Create `.env` from the example:

```bash
cp .env.example .env
```

Variables in `.env`:
- `POSTGRES_MAJOR` - Postgres major version to build (`17` or `18`)
- `IMAGE_VARIANT` - extension bundle (`timescale`, `pgvector`, `full`)
- `POSTGRES_TAG` - image tag for release compose (`18-timescale`, `18-pgvector`, `18-full`)
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`

Pinned PostgreSQL and package versions come from `versions/${POSTGRES_MAJOR}.env`.
Bundle flags come from `variants/${IMAGE_VARIANT}.env`.

Build locally:

```bash
./scripts/compose.sh up -d --build
```

Run a published image:

```bash
# pgvector bundle
POSTGRES_TAG=18-pgvector docker compose -f docker-compose.release.yml up -d

# timescale or full bundles need Timescale preload
POSTGRES_TAG=18-timescale docker compose \
  -f docker-compose.release.yml \
  -f docker-compose.release.timescale.yml \
  up -d
```

Services:
- PostgreSQL: `127.0.0.1:5432`
- pgAdmin: `http://localhost:10001`

## Base OS: bookworm only (for now)

Images are based on `postgres:<version>-bookworm` because PostGIS, pgvector, and TimescaleDB are available as pinned Debian packages.

### Why not Alpine yet?

Official `postgres:*-alpine` images ship PostgreSQL built into `/usr/local`, while Alpine `apk` extension packages install into `/usr/lib/postgresql17/`. They do not match out of the box, and Alpine packages also lag behind bookworm versions.

Alpine support would require building extensions from source in CI. That is doable, but it is a separate, heavier pipeline. Bookworm variants already save memory versus installing everything when you only need one bundle.

## Versioning

Pinned versions live in:
- `versions/17.env`
- `versions/18.env`

Each file pins PostgreSQL and all extension packages. Bundles only install the packages they need.

Inspect bundle and versions inside an image:

```bash
docker inspect --format '{{index .Config.Labels "com.pivotdude.variant"}}' <image>
docker run --rm <image> cat /opt/variants/timescale.env
```

### Image tags

- `18-timescale`, `18-pgvector`, `18-full`
- `18.4-timescale`, `18.4-pgvector`, `18.4-full`
- `18`, `18.4` - aliases for `full`
- `latest` - newest major + `full` bundle

### Updating pinned versions

```bash
./scripts/check-versions.sh
./scripts/check-versions.sh --write
```

## CI/CD

### Docker publish

Workflow: `.github/workflows/docker-publish.yml`

Build matrix: PostgreSQL `17/18` x bundles `timescale/pgvector/full`

Triggers:
- push to `main` when `Dockerfile`, `versions/**`, or `variants/**` change
- weekly schedule: Monday 03:00 UTC
- manual `workflow_dispatch`

### Automated version bumps

Workflow: `.github/workflows/update-versions.yml`

Weekly check opens a PR when newer package versions are available.

### Required GitHub Secrets

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## Pull Images

```bash
docker pull pivotdude/postgres-timescale-postgis-pgvector:18-timescale
docker pull pivotdude/postgres-timescale-postgis-pgvector:18-pgvector
docker pull pivotdude/postgres-timescale-postgis-pgvector:18-full
docker pull pivotdude/postgres-timescale-postgis-pgvector:latest
```

## License

MIT, see `LICENSE`.

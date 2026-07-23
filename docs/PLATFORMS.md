# Supported platforms

## CPU architectures

Published images are **multi-arch** manifests:

| Architecture | Docker platform | Typical hardware |
|--------------|-----------------|------------------|
| amd64 | `linux/amd64` | Intel/AMD PCs, most cloud VMs |
| arm64 | `linux/arm64` | Apple Silicon, Raspberry Pi 4+, AWS Graviton, Ampere |

Docker picks the correct layer automatically:

```bash
docker pull pivotdude/postgres-timescale-postgis-pgvector:18-timescale
docker image inspect pivotdude/postgres-timescale-postgis-pgvector:18-timescale --format '{{.Architecture}}'
```

CI builds both architectures with Docker Buildx and pushes a single manifest per tag.

### Why not add ppc64le, s390x, arm/v7, riscv64, …?

The official `postgres` image publishes many architectures, but **this project is limited by extension packages**, not by Docker:

| Architecture | Postgres base image | PostGIS / pgvector (PGDG apt) | TimescaleDB (packagecloud) | Our images |
|--------------|--------------------|------------------------------|---------------------------|------------|
| amd64 | yes | yes | yes | **yes** |
| arm64 | yes | yes | yes | **yes** |
| ppc64le | yes | partial / varies | no official `.deb` | no |
| s390x | yes | partial / varies | no official `.deb` | no |
| arm/v7, 386 | yes | legacy 32-bit | no | no |
| riscv64 | experimental | limited | no | no |

Bundles `timescale` and `full` require TimescaleDB apt packages. Today those are published for **amd64 and arm64 only**. Without TimescaleDB, half of this repo's purpose breaks on other arches.

Adding more platforms would also mean:

- **~2× CI time per architecture** (QEMU builds on GitHub runners)
- **Separate version pins or failing matrix cells** per arch
- **Support burden** for hardware almost nobody uses with this stack

If you run IBM POWER or s390x and only need **pgvector** (no TimescaleDB), open an issue — a separate experimental image line might be possible. For general use, **amd64 + arm64 is the practical ceiling**.

## Base OS: Debian bookworm only

Images use `postgres:<version>-bookworm` and install extensions from Debian/apt repositories (PGDG + TimescaleDB packagecloud).

## Why Alpine is not supported

We intentionally do **not** publish `*-alpine` variants today.

### 1. Official Postgres Alpine images use a different layout

The Docker Library `postgres:*-alpine` image compiles PostgreSQL into `/usr/local/`.

Alpine Linux `apk` packages for extensions install binaries under paths such as `/usr/lib/postgresql17/`, built for Alpine's own PostgreSQL packaging — not for the official image layout.

Installing `postgresql-timescaledb` or `postgresql-pgvector` via `apk` on `postgres:18-alpine` does **not** register extensions in `/usr/local/share/postgresql/extension/`, so PostgreSQL 18 inside the container cannot load them without extra symlinks or hacks.

### 2. Alpine packages lag behind bookworm

Example at the time this was documented:

| Extension | bookworm (apt) | Alpine (apk) |
|-----------|----------------|--------------|
| pgvector | 0.8.5 | 0.6.2 |
| TimescaleDB | 2.28.x | 2.17.x |
| PostGIS | 3.6.x | 3.5.x |

### 3. Building from source on Alpine is a separate project

A proper Alpine pipeline would need to compile PostGIS (GDAL/GEOS/PROJ chain), pgvector, and TimescaleDB from source for each PostgreSQL major, per architecture, on every version bump. That is significantly more CI time and maintenance than pinned apt packages on bookworm.

### What we recommend instead

- Use **`18-timescale`** or **`18-pgvector`** bundles if you want a smaller image — fewer extensions installed
- Use **arm64** bookworm images on Apple Silicon / ARM servers — native performance without Alpine

If Alpine support becomes a hard requirement, open an issue. It would likely be a separate image line with its own Dockerfile and version pinning strategy.

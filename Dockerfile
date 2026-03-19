ARG POSTGRES_VERSION=17
FROM postgres:${POSTGRES_VERSION}

LABEL maintainer="pivotdude" \
      description="PostgreSQL with PostGIS, pgvector, and TimescaleDB"

ARG POSTGRES_VERSION

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg; \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
        | gpg --dearmor -o /usr/share/keyrings/timescale.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/timescale.gpg] https://packagecloud.io/timescale/timescaledb/debian/ bookworm main" \
        > /etc/apt/sources.list.d/timescale.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        postgresql-${POSTGRES_VERSION}-postgis-3 \
        postgresql-${POSTGRES_VERSION}-pgvector \
        timescaledb-2-postgresql-${POSTGRES_VERSION} \
        timescaledb-tools; \
    apt-get purge -y --auto-remove curl gnupg; \
    rm -rf /var/lib/apt/lists/*

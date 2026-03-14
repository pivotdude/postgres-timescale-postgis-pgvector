ARG POSTGRES_VERSION=17
FROM postgres:${POSTGRES_VERSION}

LABEL maintainer="pivotdude"
LABEL description="PostgreSQL with PostGIS, pgvector, and TimescaleDB"

ARG POSTGRES_VERSION

RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
 && curl -s https://packagecloud.io/install/repositories/timescale/timescaledb/script.deb.sh | bash \
 && apt-get update \
 && apt-get install -y \
    postgresql-${POSTGRES_VERSION}-postgis-3 \
    postgresql-${POSTGRES_VERSION}-pgvector \
    timescaledb-2-postgresql-${POSTGRES_VERSION} \
    timescaledb-tools \
 && rm -rf /var/lib/apt/lists/*

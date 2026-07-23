ARG POSTGRES_IMAGE_TAG=18.4-bookworm
FROM postgres:${POSTGRES_IMAGE_TAG}

ARG POSTGRES_MAJOR=18
ARG POSTGRES_VERSION=18.4
ARG VARIANT=full
ARG INSTALL_POSTGIS=true
ARG INSTALL_TIMESCALE=true
ARG INSTALL_PGVECTOR=true
ARG INSTALL_TIMESCALEDB_TOOLS=true
ARG POSTGIS_VERSION=3.6.4
ARG PGVECTOR_VERSION=0.8.5
ARG TIMESCALEDB_VERSION=2.28.3
ARG POSTGIS_APT_VERSION
ARG PGVECTOR_APT_VERSION
ARG TIMESCALEDB_APT_VERSION
ARG TIMESCALEDB_TOOLS_APT_VERSION

LABEL org.opencontainers.image.title="postgres-timescale-postgis-pgvector" \
      org.opencontainers.image.description="PostgreSQL with optional PostGIS, pgvector, and TimescaleDB bundles" \
      org.opencontainers.image.version="${POSTGRES_VERSION}" \
      org.opencontainers.image.vendor="pivotdude" \
      org.opencontainers.image.source="https://github.com/pivotdude/postgres-timescale-postgis-pgvector" \
      org.opencontainers.image.url="https://github.com/pivotdude/postgres-timescale-postgis-pgvector" \
      org.opencontainers.image.licenses="MIT" \
      com.pivotdude.postgres.major="${POSTGRES_MAJOR}" \
      com.pivotdude.postgres.version="${POSTGRES_VERSION}" \
      com.pivotdude.variant="${VARIANT}" \
      com.pivotdude.postgis.version="${POSTGIS_VERSION}" \
      com.pivotdude.pgvector.version="${PGVECTOR_VERSION}" \
      com.pivotdude.timescaledb.version="${TIMESCALEDB_VERSION}"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg; \
    if [ "${INSTALL_TIMESCALE}" = "true" ] || [ "${INSTALL_TIMESCALEDB_TOOLS}" = "true" ]; then \
        curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
            | gpg --dearmor -o /usr/share/keyrings/timescale.gpg; \
        echo "deb [signed-by=/usr/share/keyrings/timescale.gpg] https://packagecloud.io/timescale/timescaledb/debian/ bookworm main" \
            > /etc/apt/sources.list.d/timescale.list; \
        apt-get update; \
    fi; \
    packages=""; \
    if [ "${INSTALL_POSTGIS}" = "true" ]; then \
        packages="${packages} postgresql-${POSTGRES_MAJOR}-postgis-3=${POSTGIS_APT_VERSION}"; \
    fi; \
    if [ "${INSTALL_PGVECTOR}" = "true" ]; then \
        packages="${packages} postgresql-${POSTGRES_MAJOR}-pgvector=${PGVECTOR_APT_VERSION}"; \
    fi; \
    if [ "${INSTALL_TIMESCALE}" = "true" ]; then \
        packages="${packages} timescaledb-2-postgresql-${POSTGRES_MAJOR}=${TIMESCALEDB_APT_VERSION}"; \
    fi; \
    if [ "${INSTALL_TIMESCALEDB_TOOLS}" = "true" ]; then \
        packages="${packages} timescaledb-tools=${TIMESCALEDB_TOOLS_APT_VERSION}"; \
    fi; \
  if [ -z "${packages}" ]; then \
        echo "At least one extension must be enabled" >&2; \
        exit 1; \
    fi; \
    # shellcheck disable=SC2086 \
    apt-get install -y --no-install-recommends ${packages}; \
    apt-get purge -y --auto-remove curl gnupg; \
    rm -rf /var/lib/apt/lists/*

COPY versions/ /opt/versions/
COPY variants/ /opt/variants/

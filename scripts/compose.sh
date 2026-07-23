#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "Missing .env. Copy .env.example first:" >&2
  echo "  cp .env.example .env" >&2
  exit 1
fi

CLI_IMAGE_VARIANT="${IMAGE_VARIANT:-}"

set -a
# shellcheck disable=SC1091
source .env
# shellcheck disable=SC1091
source variants/manifest.env
set +a

IMAGE_VARIANT="${CLI_IMAGE_VARIANT:-${IMAGE_VARIANT:-${DEFAULT_VARIANT}}}"
VARIANT_ENV_FILE="variants/${IMAGE_VARIANT}.env"

if [[ ! -f "versions/${POSTGRES_MAJOR}.env" ]]; then
  echo "Missing versions/${POSTGRES_MAJOR}.env" >&2
  exit 1
fi

if [[ ! -f "$VARIANT_ENV_FILE" ]]; then
  echo "Missing ${VARIANT_ENV_FILE}" >&2
  echo "IMAGE_VARIANT must be one of: timescale, pgvector, full" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source "$VARIANT_ENV_FILE"
set +a

compose_args=(
  --env-file .env
  --env-file "versions/${POSTGRES_MAJOR}.env"
  --env-file "$VARIANT_ENV_FILE"
  -f docker-compose.yml
)

if [[ "${REQUIRES_TIMESCALE_PRELOAD}" == "true" ]]; then
  compose_args+=(-f docker-compose.timescale.yml)
fi

exec docker compose "${compose_args[@]}" "$@"

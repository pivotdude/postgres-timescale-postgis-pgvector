#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRITE=false

usage() {
  cat <<'EOF'
Check pinned package versions against upstream registries.

Usage:
  scripts/check-versions.sh [--write]

Options:
  --write   Update versions/*.env when newer packages are available
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write)
      WRITE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

latest_postgres_image_tag() {
  local major="$1"
  python3 - "$major" <<'PY'
import json
import re
import sys
import urllib.request

major = sys.argv[1]
pattern = re.compile(rf"^{re.escape(major)}\.(\d+)-bookworm$")
best = (-1, None)

url = f"https://registry.hub.docker.com/v2/repositories/library/postgres/tags?page_size=100&name={major}."
while url:
    with urllib.request.urlopen(url, timeout=30) as response:
        data = json.load(response)
    for tag in data.get("results", []):
        match = pattern.fullmatch(tag["name"])
        if match:
            minor = int(match.group(1))
            if minor > best[0]:
                best = (minor, tag["name"])
    url = data.get("next")

if best[1] is None:
    raise SystemExit(f"Could not find postgres {major}.x-bookworm tag on Docker Hub")

print(best[1])
PY
}

query_apt_versions() {
  local major="$1"
  local image_tag="$2"

  docker run --rm -i "postgres:${image_tag}" bash -s "$major" <<'EOF'
set -euo pipefail
major="$1"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl gnupg ca-certificates
curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
  | gpg --dearmor -o /usr/share/keyrings/timescale.gpg
echo "deb [signed-by=/usr/share/keyrings/timescale.gpg] https://packagecloud.io/timescale/timescaledb/debian/ bookworm main" \
  > /etc/apt/sources.list.d/timescale.list
apt-get update -qq

postgis="$(apt-cache policy "postgresql-${major}-postgis-3" | awk '/Candidate:/ {print $2}')"
pgvector="$(apt-cache policy "postgresql-${major}-pgvector" | awk '/Candidate:/ {print $2}')"
timescaledb="$(apt-cache policy "timescaledb-2-postgresql-${major}" | awk '/Candidate:/ {print $2}')"
tools="$(apt-cache policy timescaledb-tools | awk '/Candidate:/ {print $2}')"

printf 'POSTGIS_APT_VERSION=%s\n' "$postgis"
printf 'PGVECTOR_APT_VERSION=%s\n' "$pgvector"
printf 'TIMESCALEDB_APT_VERSION=%s\n' "$timescaledb"
printf 'TIMESCALEDB_TOOLS_APT_VERSION=%s\n' "$tools"
EOF
}

human_version() {
  local key="$1"
  local apt_version="$2"

  python3 - "$key" "$apt_version" <<'PY'
import re
import sys

key, apt_version = sys.argv[1:3]
if apt_version in {"", "(none)"}:
    raise SystemExit(f"No candidate version available for {key}")

if key == "POSTGIS_APT_VERSION":
    print(re.split(r"[+~-]", apt_version, maxsplit=1)[0])
elif key == "PGVECTOR_APT_VERSION":
    print(re.split(r"[-~]", apt_version, maxsplit=1)[0])
elif key in {"TIMESCALEDB_APT_VERSION", "TIMESCALEDB_TOOLS_APT_VERSION"}:
    print(re.split(r"[~]", apt_version, maxsplit=1)[0])
else:
    raise SystemExit(f"Unsupported key: {key}")
PY
}

postgres_version_from_tag() {
  local image_tag="$1"
  echo "${image_tag%-bookworm}"
}

update_env_file() {
  local env_file="$1"
  shift

  python3 - "$env_file" "$@" <<'PY'
import pathlib
import sys

env_file = pathlib.Path(sys.argv[1])
updates = {}
for index in range(2, len(sys.argv), 2):
    updates[sys.argv[index]] = sys.argv[index + 1]

lines = env_file.read_text().splitlines()
output = []
seen = set()

for line in lines:
    if not line or line.lstrip().startswith("#") or "=" not in line:
        output.append(line)
        continue

    key, _ = line.split("=", 1)
    if key in updates:
        output.append(f"{key}={updates[key]}")
        seen.add(key)
    else:
        output.append(line)

for key, value in updates.items():
    if key not in seen:
        output.append(f"{key}={value}")

env_file.write_text("\n".join(output) + "\n")
PY
}

changes=0

for env_file in "$ROOT_DIR"/versions/[0-9]*.env; do
  [[ -f "$env_file" ]] || continue

  # shellcheck disable=SC1090
  source "$env_file"

  latest_image_tag="$(latest_postgres_image_tag "$POSTGRES_MAJOR")"
  latest_postgres_version="$(postgres_version_from_tag "$latest_image_tag")"

  postgis_apt=""
  pgvector_apt=""
  timescaledb_apt=""
  tools_apt=""

  while IFS='=' read -r key value; do
    case "$key" in
      POSTGIS_APT_VERSION) postgis_apt="$value" ;;
      PGVECTOR_APT_VERSION) pgvector_apt="$value" ;;
      TIMESCALEDB_APT_VERSION) timescaledb_apt="$value" ;;
      TIMESCALEDB_TOOLS_APT_VERSION) tools_apt="$value" ;;
    esac
  done < <(query_apt_versions "$POSTGRES_MAJOR" "$latest_image_tag")

  postgis_version="$(human_version POSTGIS_APT_VERSION "$postgis_apt")"
  pgvector_version="$(human_version PGVECTOR_APT_VERSION "$pgvector_apt")"
  timescaledb_version="$(human_version TIMESCALEDB_APT_VERSION "$timescaledb_apt")"

  echo "== PostgreSQL ${POSTGRES_MAJOR} =="

  file_changed=false
  update_args=()

  declare -A current_values=(
    [POSTGRES_IMAGE_TAG]="$POSTGRES_IMAGE_TAG"
    [POSTGRES_VERSION]="$POSTGRES_VERSION"
    [POSTGIS_VERSION]="$POSTGIS_VERSION"
    [PGVECTOR_VERSION]="$PGVECTOR_VERSION"
    [TIMESCALEDB_VERSION]="$TIMESCALEDB_VERSION"
    [POSTGIS_APT_VERSION]="$POSTGIS_APT_VERSION"
    [PGVECTOR_APT_VERSION]="$PGVECTOR_APT_VERSION"
    [TIMESCALEDB_APT_VERSION]="$TIMESCALEDB_APT_VERSION"
    [TIMESCALEDB_TOOLS_APT_VERSION]="$TIMESCALEDB_TOOLS_APT_VERSION"
  )

  declare -A next_values=(
    [POSTGRES_IMAGE_TAG]="$latest_image_tag"
    [POSTGRES_VERSION]="$latest_postgres_version"
    [POSTGIS_VERSION]="$postgis_version"
    [PGVECTOR_VERSION]="$pgvector_version"
    [TIMESCALEDB_VERSION]="$timescaledb_version"
    [POSTGIS_APT_VERSION]="$postgis_apt"
    [PGVECTOR_APT_VERSION]="$pgvector_apt"
    [TIMESCALEDB_APT_VERSION]="$timescaledb_apt"
    [TIMESCALEDB_TOOLS_APT_VERSION]="$tools_apt"
  )

  for key in POSTGRES_IMAGE_TAG POSTGRES_VERSION POSTGIS_VERSION PGVECTOR_VERSION TIMESCALEDB_VERSION \
    POSTGIS_APT_VERSION PGVECTOR_APT_VERSION TIMESCALEDB_APT_VERSION TIMESCALEDB_TOOLS_APT_VERSION; do
    current_value="${current_values[$key]}"
    new_value="${next_values[$key]}"

    if [[ "$current_value" != "$new_value" ]]; then
      echo "  ${key}: ${current_value} -> ${new_value}"
      file_changed=true
      changes=$((changes + 1))
      update_args+=("$key" "$new_value")
    else
      echo "  ${key}: ${current_value} (up to date)"
    fi
  done

  if [[ "$file_changed" == true && "$WRITE" == true ]]; then
    update_env_file "$env_file" "${update_args[@]}"
    echo "  updated ${env_file#"$ROOT_DIR"/}"
  fi

  echo
done

if [[ "$changes" -eq 0 ]]; then
  echo "All pinned versions are up to date."
  exit 0
fi

if [[ "$WRITE" == false ]]; then
  echo "Run with --write to update versions/*.env"
  exit 2
fi

echo "Updated ${changes} pinned value(s)."

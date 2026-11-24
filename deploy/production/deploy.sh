#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

release_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
release="${release_directory##*/}"
export TRACKIT_ROOT="$(cd -- "$release_directory/../.." && pwd)"
export TRACKIT_IMAGE="${1:?Pass the immutable image reference}"
[[ "$release" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid release ID' >&2; exit 1; }
[[ "$TRACKIT_IMAGE" =~ ^ghcr.io/alnoi/locked-in-backend@sha256:[0-9a-f]{64}$ ]] || { echo 'Invalid image reference' >&2; exit 1; }
[[ -f "$TRACKIT_ROOT/.env" ]] || { echo 'Missing server .env' >&2; exit 1; }

exec 9>"$TRACKIT_ROOT/deploy.lock"
flock -n 9 || { echo 'Another deployment is running' >&2; exit 1; }
compose=(docker compose --project-directory "$TRACKIT_ROOT" --env-file "$TRACKIT_ROOT/.env" -f "$release_directory/compose.yaml")
previous_release=''
previous_image=''
if [[ -f "$TRACKIT_ROOT/current.release" ]]; then
  read -r previous_release previous_image < "$TRACKIT_ROOT/current.release"
  [[ "$previous_release" =~ ^[0-9a-f]{40}$ && "$previous_image" =~ ^ghcr.io/alnoi/locked-in-backend@sha256:[0-9a-f]{64}$ ]] || { echo 'Invalid previous release' >&2; exit 1; }
  [[ -f "$TRACKIT_ROOT/releases/$previous_release/compose.yaml" ]] || { echo 'Previous release configuration is missing' >&2; exit 1; }
fi

"${compose[@]}" up -d --wait --wait-timeout 90 postgres
mkdir -p "$TRACKIT_ROOT/backups"
backup="$TRACKIT_ROOT/backups/$(date -u +%Y%m%dT%H%M%SZ)-$release.dump"
"${compose[@]}" exec -T postgres sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$backup.tmp"
mv -- "$backup.tmp" "$backup"
docker pull "$TRACKIT_IMAGE"

restore_previous() {
  local failure="${1:-1}"
  trap - ERR HUP INT TERM
  "${compose[@]}" logs --tail 80 backend >&2 || true
  if [[ -n "$previous_image" ]]; then
    echo "Restoring release $previous_release" >&2
    if ! TRACKIT_IMAGE="$previous_image" docker compose --project-directory "$TRACKIT_ROOT" --env-file "$TRACKIT_ROOT/.env" -f "$TRACKIT_ROOT/releases/$previous_release/compose.yaml" up -d --no-deps --wait --wait-timeout 90 backend; then
      echo 'Previous release could not start; inspect the database migration and backend logs' >&2
    fi
  else
    "${compose[@]}" stop backend || true
  fi
  exit "$failure"
}
trap 'restore_previous $?' ERR
trap 'restore_previous 129' HUP
trap 'restore_previous 130' INT
trap 'restore_previous 143' TERM
"${compose[@]}" up -d --no-deps --wait --wait-timeout 90 backend
printf '%s %s\n' "$release" "$TRACKIT_IMAGE" > "$TRACKIT_ROOT/current.release.tmp"
mv -- "$TRACKIT_ROOT/current.release.tmp" "$TRACKIT_ROOT/current.release"
trap - ERR HUP INT TERM
printf 'Deployed %s\n' "$TRACKIT_IMAGE"

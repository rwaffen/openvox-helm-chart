#!/bin/bash
set -euo pipefail

image=${1:?Usage: test.sh IMAGE}
name="openvox-postgresql-test-$$"
volume="$name-data"
cleanup() {
  podman rm -f "$name" >/dev/null 2>&1 || true
  podman volume rm "$volume" >/dev/null 2>&1 || true
}
trap cleanup EXIT
podman volume create "$volume" >/dev/null
podman run -d --name "$name" --userns=keep-id:uid=1001230000,gid=0 \
  --user 1001230000:0 --cap-drop=ALL --security-opt=no-new-privileges \
  -v "$volume:/var/lib/postgresql/data:U" \
  -e POSTGRES_PASSWORD=test-admin-only -e OPENVOX_USER=puppetdb \
  -e OPENVOX_PASSWORD=test-app-only -e OPENVOX_DATABASE=puppetdb "$image" >/dev/null

ready() {
  for _attempt in {1..60}; do
    if podman exec "$name" pg_isready -h 127.0.0.1 -U postgres -d puppetdb >/dev/null; then
      return
    fi
    sleep 1
  done
  podman logs "$name" >&2
  return 1
}
query() {
  podman exec -e PGPASSWORD=test-app-only "$name" \
    psql -h 127.0.0.1 -U puppetdb -d puppetdb -At --set=ON_ERROR_STOP=1 -c "$1"
}
ready
[[ "$(query "SELECT count(*) FROM pg_extension WHERE extname IN ('pg_trgm','pgcrypto')")" == 2 ]]
[[ "$(query "SELECT rolsuper FROM pg_roles WHERE rolname = current_user")" == f ]]
query 'CREATE TABLE restart_check (value integer); INSERT INTO restart_check VALUES (42);' >/dev/null
podman restart "$name" >/dev/null
ready
[[ "$(query 'SELECT value FROM restart_check')" == 42 ]]
echo 'PASS: arbitrary UID, no capabilities, extensions, application role and persistent restart'

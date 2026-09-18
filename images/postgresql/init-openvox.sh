#!/bin/bash
set -euo pipefail

: "${OPENVOX_DATABASE:?Database name is required}"
: "${OPENVOX_USER:?Database user is required}"
: "${OPENVOX_PASSWORD:?Database password is required}"

if [[ "$OPENVOX_USER" == "$POSTGRES_USER" || "$OPENVOX_DATABASE" == "$POSTGRES_DB" ]]; then
  echo 'OpenVox must use a separate database and non-superuser role.' >&2
  exit 1
fi

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --no-psqlrc --set=ON_ERROR_STOP=1 \
  --set=app_user="$OPENVOX_USER" --set=app_password="$OPENVOX_PASSWORD" \
  --set=app_database="$OPENVOX_DATABASE" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_user', :'app_password') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'app_database', :'app_user') \gexec
SQL

psql --username "$POSTGRES_USER" --dbname "$OPENVOX_DATABASE" --no-psqlrc --set=ON_ERROR_STOP=1 <<'SQL'
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SQL

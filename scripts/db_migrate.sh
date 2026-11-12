#!/usr/bin/env bash
# Spustí ešte nepoužité migrácie z db/migrations nad lokálnou databázou rejnox.
# Beží ako správca postgres; heslo sa číta z %APPDATA%/postgresql/pgpass.conf.
set -euo pipefail

cd "$(dirname "$0")/.."
PSQL="${PSQL:-/c/Program Files/PostgreSQL/17/bin/psql.exe}"
run() { "$PSQL" -U postgres -h localhost -w -d rejnox -v ON_ERROR_STOP=1 -q "$@"; }

run -c "CREATE TABLE IF NOT EXISTS schema_migrations (
          name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"

for file in db/migrations/*.sql; do
  name="$(basename "$file")"
  if [ "$(run -tAc "SELECT 1 FROM schema_migrations WHERE name = '$name'")" = "1" ]; then
    echo "preskakujem $name"
    continue
  fi
  echo "spúšťam $name"
  # Migrácia aj jej zápis sú v jednej transakcii: buď prejde celá, alebo nič.
  run -1 -f "$file" -c "INSERT INTO schema_migrations (name) VALUES ('$name')"
done
echo "hotovo"

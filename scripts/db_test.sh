#!/usr/bin/env bash
# Spustí kontroly prístupových pravidiel ako rola rejnox_app (config/.env).
set -euo pipefail

cd "$(dirname "$0")/.."
PSQL="${PSQL:-/c/Program Files/PostgreSQL/17/bin/psql.exe}"
DATABASE_URL="$(grep '^DATABASE_URL=' config/.env | cut -d= -f2-)"

for file in tests/db/*.sql; do
  echo "== $file"
  "$PSQL" "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "$file"
done

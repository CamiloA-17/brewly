#!/usr/bin/env bash
# Aplica todas las migraciones sobre una base temporal y ejecuta las pruebas.
# Uso: supabase/tests/run.sh   (requiere psql y un PostgreSQL local >= 15)
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB="${BREWLY_TEST_DB:-brewly_test}"
PSQL=(psql -X -q -v ON_ERROR_STOP=1 -d "$DB")

dropdb --if-exists "$DB"
createdb "$DB"
"${PSQL[@]}" -f "$DIR/tests/00_supabase_stub.sql"
for f in "$DIR"/migrations/*.sql; do
  echo "→ $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done
for t in "$DIR"/tests/[1-9]*_test.sql; do
  echo "▶ $(basename "$t")"
  "${PSQL[@]}" -o /dev/null -f "$t" 2>&1 | sed "s/^psql:[^ ]* NOTICE:  /  /"
done
echo "✔ Todas las pruebas pasaron"

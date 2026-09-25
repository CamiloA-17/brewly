#!/usr/bin/env bash
# Runs every SQL test file against $DATABASE_URL (migrations must already be applied).
# Each file runs inside a transaction that is rolled back, so the database is left untouched.
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must be set}"
cd "$(dirname "$0")"

status=0
for test_file in [0-9]*_*.sql; do
    if psql "$DATABASE_URL" --quiet --no-psqlrc -v ON_ERROR_STOP=1 \
        -f _helpers.sql -f "$test_file" >/dev/null; then
        echo "PASS  $test_file"
    else
        echo "FAIL  $test_file"
        status=1
    fi
done
exit $status

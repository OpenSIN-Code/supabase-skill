#!/bin/bash
# Apply SQL migration to Supabase
# Usage: ./apply-migration.sh /path/to/migration.sql
# Docs: SKILL.md

set -euo pipefail

FILE="${1:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "Usage: $0 /path/to/migration.sql"
  echo ""
  echo "Example:"
  echo "  $0 ./scripts/supabase/setup-foo.sql"
  exit 1
fi

echo "📄 Applying migration: $FILE"
echo ""

# Run via Docker exec on supabase-db
docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$FILE" 2>&1

echo ""
echo "✅ Migration applied"

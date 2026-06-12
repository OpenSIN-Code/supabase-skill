#!/bin/bash
# Verify RLS policies on a table
# Usage: ./check-rls.sh [--table shop.products] [--violation-test]
# Docs: SKILL.md

set -uo pipefail

TABLE="${2:-shop.products}"
VIOLATION_TEST=false

if [ "${1:-}" = "--violation-test" ]; then
  VIOLATION_TEST=true
  TABLE="${3:-shop.products}"
fi

echo "🔒 RLS Check: $TABLE"
echo ""

# Check if RLS is enabled
ENABLED=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT relrowsecurity FROM pg_class
WHERE oid::regclass::text = '$TABLE';" 2>&1 | tr -d ' ')

if [ "$ENABLED" = "t" ]; then
  echo "✓ RLS enabled on $TABLE"
else
  echo "✗ RLS NOT enabled on $TABLE!"
  echo "  (Default-deny on all new tables — see AGENTS.md rule #4)"
  exit 1
fi

# List policies
echo ""
echo "Policies:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT
  polname as policy,
  CASE polcmd
    WHEN 'r' THEN 'SELECT'
    WHEN 'a' THEN 'INSERT'
    WHEN 'w' THEN 'UPDATE'
    WHEN 'd' THEN 'DELETE'
    WHEN '*' THEN 'ALL'
  END as command,
  polpermissive as permissive,
  pg_get_expr(qual, qualrelid::regclass, true) as using_expr,
  pg_get_expr(with_check, with_check_relid::regclass, true) as check_expr
FROM pg_policy
WHERE polrelid::regclass::text = '$TABLE'
ORDER BY polname;" 2>&1

# Test: can anon key read?
if [ "$VIOLATION_TEST" = "true" ]; then
  echo ""
  echo "Violation test:"

  ANON_KEY=$(grep SUPABASE_ANON_KEY .env.local 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")

  if [ -z "$ANON_KEY" ]; then
    echo "  ⚠️  No ANON_KEY in .env.local — skipping live test"
  else
    # Try reading as anon
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      "https://supabase.delqhi.com/rest/v1/$TABLE?select=id&limit=1" \
      -H "apikey: $ANON_KEY" \
      -H "Authorization: Bearer $ANON_KEY" \
      -H "Accept-Profile: shop" 2>&1)

    if [ "$STATUS" = "200" ]; then
      echo "  ✓ Anon can read $TABLE (expected for public data)"
    elif [ "$STATUS" = "401" ] || [ "$STATUS" = "403" ]; then
      echo "  ✓ Anon correctly blocked from $TABLE (private data)"
    else
      echo "  ⚠️  Unexpected status: $STATUS"
    fi
  fi
fi

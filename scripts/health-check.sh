#!/bin/bash
# Supabase health check
# Usage: ./health-check.sh
# Docs: SKILL.md

set -uo pipefail

echo "=== Supabase Health Check ==="
echo ""

# Container status
echo "1. Docker containers:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>&1 | head -15

echo ""
echo "2. Postgres connectivity (via Docker):"
docker exec supabase-db psql -U postgres -d postgres -c "SELECT version();" 2>&1 | head -3

echo ""
echo "3. Schemas present:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT schema_name, table_count
FROM information_schema.schemata s
LEFT JOIN (
  SELECT table_schema, COUNT(*) as table_count
  FROM information_schema.tables
  WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
  GROUP BY table_schema
) t ON s.schema_name = t.table_schema
WHERE s.schema_name NOT IN ('pg_catalog', 'information_schema')
ORDER BY s.schema_name;" 2>&1 | head -10

echo ""
echo "4. Key tables in 'shop' schema:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT table_name, pg_size_pretty(pg_total_relation_size('shop.' || table_name)) as size
FROM information_schema.tables
WHERE table_schema = 'shop'
ORDER BY pg_total_relation_size('shop.' || table_name) DESC
LIMIT 10;" 2>&1 | head -15

echo ""
echo "5. Public REST API health:"
curl -s -o /dev/null -w "  Status: %{http_code}\n" https://supabase.delqhi.com/auth/v1/health
curl -s -o /dev/null -w "  Products endpoint: %{http_code}\n" https://supabase.delqhi.com/rest/v1/products?select=id&limit=1

echo ""
echo "6. Disk usage (Postgres data):"
docker exec supabase-db df -h /var/lib/postgresql/data 2>&1 | tail -2

#!/bin/bash
# Quick psql exec on Supabase DB
# Usage: ./psql-exec.sh "SELECT 1" [--schema shop]
# Docs: SKILL.md

set -euo pipefail

QUERY="${1:-}"
if [ -z "$QUERY" ]; then
  echo "Usage: $0 \"SELECT ...\" [--schema shop]"
  exit 1
fi

SCHEMA=""
if [ "${2:-}" = "--schema" ]; then
  SCHEMA="SET search_path TO $3, public;"
fi

docker exec -i supabase-db psql -U postgres -d postgres -c "$SCHEMA $QUERY" 2>&1

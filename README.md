# Supabase Skill

> Comprehensive Supabase skill for opencode agents — self-hosted Supabase on OCI VM, SQL migrations, RLS, Auth, Storage, Realtime, Edge Functions, backups, monitoring.

## What this skill provides

- **SQL migrations**: idempotent scripts, table alterations, RLS policies
- **Self-hosted Supabase**: Docker compose management, container health
- **PostgREST API**: REST API access, schema introspection
- **Auth**: user management, JWT, admin operations
- **Storage**: S3-compatible bucket operations
- **Realtime**: WebSocket subscriptions, presence, broadcast
- **Edge Functions**: Deno functions, deployment, secrets
- **Backups**: pg_dump automation, OCI Object Storage upload
- **Monitoring**: container status, query performance, log aggregation

## Quick start

```bash
# Health check (self-hosted sin-supabase)
scripts/health-check.sh

# Run migration
scripts/apply-migration.sh /path/to/migration.sql

# Backup DB
scripts/backup-db.sh

# SQL query via psql
scripts/psql-exec.sh "SELECT * FROM shop.products LIMIT 5;"

# RLS test
scripts/check-rls.sh
```

## OpenSIN Self-Hosted Supabase

- **VM**: `sin-supabase` (92.5.60.87, ARM A1, 4 OCPU / 24 GB)
- **Docker Stack**: postgres + postgrest + auth + storage + realtime + kong + studio + functions + meta + pooler
- **Postgres Port (internal)**: 5432
- **Postgres Port (host)**: 5433
- **Kong Port**: 8006 → routes to all services
- **Studio**: http://localhost:3004 (internal)
- **Public URL**: `https://supabase.delqhi.com` (via Cloudflare Tunnel)
- **Schemas**: `public` (Supabase core) + `shop` (OpenSIN app data)

## File structure

```
supabase-skill/
├── README.md
├── SKILL.md
├── scripts/
│   ├── health-check.sh          # Container status, query test
│   ├── apply-migration.sh       # Run SQL files idempotently
│   ├── psql-exec.sh             # Quick psql query
│   ├── backup-db.sh             # pg_dump → OCI Object Storage
│   ├── restore-db.sh            # Restore from backup
│   ├── check-rls.sh             # Verify RLS policies
│   ├── jwt-decode.sh            # Decode Supabase JWT
│   ├── storage-helper.sh        # S3-compatible bucket ops
│   ├── env-exec.sh              # Load .env.local + run command
│   └── studio-screenshot.sh     # Capture studio UI state
├── references/
│   ├── sin-supabase.md          # The sin-supabase instance
│   ├── connection-strings.md    # All URLs, ports, secrets
│   ├── schemas.md               # public vs shop schema
│   ├── rls-policies.md          # Row Level Security patterns
│   ├── auth.md                  # JWT, GoTrue, admin operations
│   ├── storage.md               # S3 buckets, policies
│   ├── realtime.md              # WebSocket, presence
│   ├── edge-functions.md        # Deno deploy
│   ├── postgrest.md             # REST API, schema cache
│   ├── kong.md                  # API gateway config
│   ├── docker-ops.md            # Container lifecycle
│   ├── backup-strategy.md       # Daily/weekly/forever
│   └── limits.md                # Free tier limits
├── examples/
│   ├── create-table.md          # SQL example with RLS
│   ├── add-column.md            # Idempotent ALTER TABLE
│   ├── seed-products.md         # Insert test data
│   ├── setup-storage-bucket.md  # S3 bucket + RLS
│   ├── custom-jwt.md            # Admin JWT generation
│   └── reset-password.md        # Auth admin operations
└── templates/
    ├── migration.sql            # Idempotent migration template
    ├── rls-policy.sql           # RLS policy template
    ├── docker-compose.yml       # Supabase stack template
    └── env.example              # Env vars template
```

## See also

- [Self-host Supabase docs](https://supabase.com/docs/guides/self-hosting)
- [PostgREST docs](https://postgrest.org/en/stable/)
- [SIN-Shop-Center/SIN-Supabase-OCI-Bundle](https://github.com/SIN-Shop-Center/SIN-Supabase-OCI-Bundle) — historical self-hosted bundle

---
name: supabase
description: Supabase skill for opencode agents — self-hosted Supabase on OCI VM, SQL migrations, RLS policies, Auth, Storage, Realtime, Edge Functions, Triggers, Backups. Triggers on "supabase", "supabase migration", "supabase rls", "supabase auth", "supabase storage", "supabase db", "psql", "kong", "postgrest", "supabase studio", "supabase function".
version: 1.0.0
author: Jeremy Schulze
license: MIT
---

# Supabase Skill

This skill provides instant access to the OpenSIN **self-hosted Supabase** instance (`sin-supabase` on OCI Frankfurt).

## When to use

- "Run a SQL migration" / "alter table" / "add column"
- "Setup RLS policy" / "row level security"
- "Check Supabase health" / "container status"
- "Backup database" / "pg_dump" / "restore"
- "Generate admin JWT" / "decode JWT"
- "Storage bucket" / "S3 upload"
- "Realtime subscription" / "WebSocket"
- "Deploy edge function" / "Deno function"
- "PostgREST query" / "REST API"

## When NOT to use

- Managed Supabase Cloud (different URL/API)
- Pure Postgres without Supabase (use postgres-skill if available)
- Other BaaS (Firebase, Appwrite) — use their dedicated skills

## OpenSIN Self-Hosted Supabase

- **VM**: `sin-supabase` (ARM A1, 4 OCPU / 24 GB)
- **Public URL**: `https://supabase.delqhi.com` (via Cloudflare Tunnel)
- **Internal Postgres**: `db:5432` (Docker network)
- **External Postgres**: `92.5.60.87:5433` (user: `simone`, pwd: `simone123`)
- **Schemas**: `public` (Supabase core: auth, storage, etc.) + `shop` (OpenSIN app data)
- **Auth**: `supabase.auth.users`, JWT-based, `service_role` bypasses RLS
- **Storage**: S3-compatible via `supabase-storage`
- **Realtime**: WebSocket via `supabase-realtime`

## Quick reference

### Connection strings

```bash
# Internal (from within Docker network)
DATABASE_URL="postgresql://postgres:postgres@db:5432/postgres?sslmode=disable"

# External (from outside the VM)
DATABASE_URL_EXTERNAL="postgresql://simone:simone123@92.5.60.87:5433/postgres?sslmode=disable"
```

### Direct psql via Docker

```bash
# From inside the VM
docker exec supabase-db psql -U postgres -d postgres -c "SELECT 1"

# With search_path
docker exec supabase-db psql -U postgres -d postgres -c "SET search_path TO shop, public; \\dt"
```

### Public REST API

```bash
# From anywhere
curl -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" \
  "https://supabase.delqhi.com/rest/v1/products?select=id,title&limit=5"

# With schema
curl -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" \
  -H "Accept-Profile: shop" \
  "https://supabase.delqhi.com/rest/v1/products?select=id,title"
```

### Service Role (admin, bypasses RLS)

```bash
# From env or Infisical
SERVICE_KEY=$(grep SUPABASE_SERVICE_ROLE_KEY .env.local | cut -d= -f2 | tr -d '"')

# Full admin access
curl -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" \
  "https://supabase.delqhi.com/rest/v1/products?select=*" | jq
```

### Supabase Auth API

```bash
# Login (get JWT)
curl -X POST "https://supabase.delqhi.com/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"..."}'

# User info
curl -H "apikey: $ANON_KEY" -H "Authorization: Bearer $USER_JWT" \
  "https://supabase.delqhi.com/auth/v1/user"
```

### Storage API (S3-compatible)

```bash
# List buckets
curl -H "apikey: $SERVICE_KEY" \
  "https://supabase.delqhi.com/storage/v1/bucket"

# Upload to bucket
curl -X POST "https://supabase.delqhi.com/storage/v1/object/products/image.jpg" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: image/jpeg" \
  --data-binary @image.jpg
```

## Schema mapping

| App expects (snake_case) | Actual table column | View maps |
|--------------------------|---------------------|-----------|
| `title` | `products.name` | ✓ via `products_v` view |
| `image_url` | `products.images[0]` | ✓ via view (JSONB → text) |
| `image_gallery` | `products.image_gallery` | ✓ via view |
| `variants` | `products.variants` (jsonb) | ✓ via view |
| `amount_total` | `orders.subtotal_amount * 100` | ✓ via view |
| `fulfillment_status` | `orders.status` | ✓ via view |

**Always** read via the view (`shop.products_v`) for app code.
**Always** write directly to the table (`shop.products`).

## Common commands

```bash
# Health check
scripts/health-check.sh

# Apply migration
scripts/apply-migration.sh scripts/supabase/setup-foo.sql

# Quick query
scripts/psql-exec.sh "SELECT count(*) FROM shop.products"

# Backup
scripts/backup-db.sh

# RLS check
scripts/check-rls.sh
```

## Known issues

- **Postgres external port 5433** is closed by default (security). Use Docker exec from inside VM, or `ssh -L 5433:localhost:5433` tunnel.
- **Supabase Studio** at `http://localhost:3004` only on VM (not exposed publicly).
- **pg_dump** includes only `shop` schema (per backup-shop-db.sh).
- **CORS** is restricted to configured origins.

## References

- [sin-supabase.md](references/sin-supabase.md) — The OpenSIN instance details
- [connection-strings.md](references/connection-strings.md) — All URLs, ports, secrets
- [schemas.md](references/schemas.md) — public vs shop schema details
- [rls-policies.md](references/rls-policies.md) — Row Level Security patterns
- [auth.md](references/auth.md) — JWT, GoTrue, admin operations
- [storage.md](references/storage.md) — S3 buckets, policies
- [realtime.md](references/realtime.md) — WebSocket, presence
- [edge-functions.md](references/edge-functions.md) — Deno deploy
- [postgrest.md](references/postgrest.md) — REST API, schema cache
- [kong.md](references/kong.md) — API gateway config
- [docker-ops.md](references/docker-ops.md) — Container lifecycle
- [backup-strategy.md](references/backup-strategy.md) — Daily/weekly/forever
- [limits.md](references/limits.md) — Free tier limits

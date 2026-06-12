# sin-supabase — The OpenSIN Supabase Instance

## Overview

- **VM Name**: `sin-supabase`
- **VM Type**: `VM.Standard.A1.Flex` (ARM Ampere, Always Free)
- **Resources**: 4 OCPU, 24 GB RAM, ~50 GB Boot Volume
- **Region**: `eu-frankfurt-1`, AD: `PjAL:EU-FRANKFURT-1-AD-1`
- **OS**: Ubuntu 24.04
- **Provider**: Oracle Cloud Infrastructure (OCI)
- **Public IP**: 92.5.60.87 (Ephemeral, via Cloudflare Tunnel)
- **Public URL**: `https://supabase.delqhi.com`

## Services running (Docker)

| Container | Port (host) | Purpose |
|-----------|-------------|---------|
| `supabase-db` | 5432 (internal), 5433 (external) | PostgreSQL 15 |
| `supabase-kong` | 8006 | API gateway (routes all services) |
| `supabase-postgrest` | 3000 (internal) | PostgREST / REST API |
| `supabase-auth` | (internal) | GoTrue / auth service |
| `supabase-storage` | 5000 (internal) | S3-compatible storage |
| `supabase-realtime` | (internal) | WebSocket server |
| `supabase-studio` | 3004 (internal) | Web UI |
| `supabase-meta` | 8080 (internal) | Postgres metadata API |
| `supabase-edge-functions` | (internal) | Deno functions runtime |
| `supabase-pooler` | 6543, 5434 (external) | Supavisor connection pooler |

## Schemas

| Schema | Owner | Purpose |
|--------|-------|---------|
| `public` | supabase | Supabase core (auth.users, storage.objects, etc.) |
| `shop` | postgres | OpenSIN app data (products, orders, cart_items, etc.) |
| `pg_catalog` | postgres | Postgres system catalog (read-only) |
| `information_schema` | postgres | SQL standard schema info (read-only) |

## Database credentials

| User | Password | Scope |
|------|----------|-------|
| `postgres` | `secure_supabase_2026` | Superuser (internal only) |
| `simone` | `simone123` | App user (external, less privileged) |

## Connection strings

```
# Internal (Docker network)
postgresql://postgres:secure_supabase_2026@db:5432/postgres?sslmode=disable&search_path=shop

# External (from outside the VM, port 5433)
postgresql://simone:simone123@92.5.60.87:5433/postgres?sslmode=disable&search_path=shop
```

⚠️  **Port 5433 is closed by default** (security). Use SSH tunnel:
```bash
ssh -L 5433:localhost:5433 ubuntu@92.5.60.87
# Then connect to localhost:5433 from your local machine
```

## Supabase API keys

- **anon key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIs...` (safe for client)
- **service_role key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiw...` (admin, bypasses RLS)

Store in:
- `.env.local` (local dev)
- Cloudflare Workers Secrets (prod)
- GitHub Secrets (CI/CD)
- Infisical: `/SIN-Webshop-01` path

## Storage

- **Default buckets**: None (create per-need)
- **Production buckets**:
  - `products` — product images (read via signed URLs)
  - `media` — CMS media
  - `avatars` — user avatars (if applicable)

## Backups

- **Daily cron** at 3 AM UTC: `pg_dump -n shop` → OCI Object Storage
- **Retention**: 30 days
- **Location**: `s3://simone-backups/db/shop-YYYYMMDD-HHMM.sql.gz`
- **Config**: `scripts/ops/backup-shop-db.sh` + `/etc/cron.daily/backup-shop-db`

## Maintenance

| Task | Frequency | Command |
|------|-----------|---------|
| Container health check | every 5 min | `docker ps` |
| Backup | daily 3 AM | `pg_dump` via cron |
| WAL archiving | always on | Postgres config |
| Vacuum | weekly (auto) | autovacuum |
| Reindex | monthly | `REINDEX DATABASE CONCURRENTLY` |
| Docker image updates | as needed | `docker compose pull` |

## Key URLs (for browser)

| Service | URL | Auth |
|---------|-----|------|
| Studio (UI) | `http://localhost:3004` (internal only) | admin user |
| REST API | `https://supabase.delqhi.com/rest/v1/...` | anon/service JWT |
| Auth API | `https://supabase.delqhi.com/auth/v1/...` | anon/service JWT |
| Storage API | `https://supabase.delqhi.com/storage/v1/...` | anon/service JWT |
| Realtime | `wss://supabase.delqhi.com/realtime/v1/websocket` | anon JWT |

## Known issues

1. **External Postgres port 5433** is closed by default. Use SSH tunnel.
2. **Studio** is only accessible from inside the VM (port 3004).
3. **Public URL** (`supabase.delqhi.com`) routes ONLY through Cloudflare Tunnel (port 8006 NEVER exposed publicly — see AGENTS.md rule #1).
4. **Storage** uses internal S3 API on port 5000.
5. **Postgres** accepts both `postgres` (superuser) and `simone` (app) users.

## See also

- [connection-strings.md](connection-strings.md) — All URLs, ports, secrets
- [schemas.md](schemas.md) — public vs shop schema details
- [docker-ops.md](docker-ops.md) — Container lifecycle
- [backup-strategy.md](backup-strategy.md) — Daily/weekly/forever

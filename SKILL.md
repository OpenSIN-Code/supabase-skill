# skill-supabase — Single Source of Truth for SIN-Supabase on OCI

> **Purpose:** Autonomous agent access to the self-hosted Supabase instance on OCI VM `sin-supabase` (`92.5.60.87`).
> **Last verified:** 2026-06-17 (live via SSH + Docker inspect + Postgres queries)
> **Companion skill:** `skill-oci-oracle-cloud` (§1.1, §6, §21 for VM-level access)

---

## 0. Hard Mandates

1. **NEVER** print actual JWT tokens, API keys, passwords, or `.env` values in chat, commits, or skill files — reference the `.env` path on the VM instead.
2. **SSH access:** `ssh sin-supabase` (alias in `~/.ssh/config`, key `~/.ssh/id_ed25519`). Priority-20 is NOT enforced in this environment (see `skill-oci-oracle-cloud` §21.14).
3. **All changes to Supabase containers** must go through `docker compose -p sin-supabase` in `/opt/sin-supabase/`.
4. **Postgres direct access:** `docker exec supabase-db psql -U postgres` — use for queries only, never for destructive operations without explicit operator approval.

---

## 1. Inventory (live-verified 2026-06-17)

### 1.1 Location

| Property | Value |
|---|---|
| VM | `sin-supabase` (`92.5.60.87`) — OCI A1.Flex, aarch64, 24 GB RAM |
| Install path | `/opt/sin-supabase/` |
| Docker compose project | `sin-supabase` (13 containers) |
| Docker network | `haus-netzwerk` (external, `172.20.0.0/16`, fixed IPs) |
| Compose file | `/opt/sin-supabase/docker-compose.yml` |
| `.env` file | `/opt/sin-supabase/.env` (54 variables — keys only, see §3) |
| A2A runtime | `sin-supabase.service` → `/opt/sin-control-plane/a2a/team-infratructur/A2A-SIN-Supabase/` |
| A2A logs | `/opt/sin-control-plane/logs/sin-supabase-a2a.log` |
| Cloudflare tunnel | `simone-api` → `supabase.delqhi.com` → `localhost:8006` (Kong) |

### 1.2 Containers (13) — network IPs, ports, images

| Container | IP (haus-netzwerk) | Image | Host Port | Internal Port | Purpose |
|---|---|---|---|---|---|
| `supabase-studio` | `172.20.0.70` | `supabase/studio:2025.12.17-sha-43f4f7f` | `3004` | `3000` | Studio dashboard |
| `supabase-db` | `172.20.0.71` | `supabase/postgres:15.8.1.085` | `5433` | `5432` | PostgreSQL 15.8 |
| `supabase-vector` | `172.20.0.72` | `timberio/vector:0.28.1-alpine` | — | — | Log pipeline |
| `supabase-pooler` | `172.20.0.73` | `supabase/supavisor:2.7.4` | `6543`, `5434` | `6543`, `5432` | Connection pooler (Supavisor) |
| `supabase-analytics` | `172.20.0.74` | `supabase/logflare:1.27.0` | `4000` | `4000` | Analytics (Logflare) |
| `supabase-meta` | `172.20.0.75` | `supabase/postgres-meta:v0.95.1` | — | `8080` | Postgres metadata API |
| `supabase-kong` | `172.20.0.76` | `kong:2.8.1` | `8006`, `8444` | `8000`, `8443` | API gateway (Kong) |
| `supabase-auth` | `172.20.0.77` | `supabase/gotrue:v2.184.0` | — | `9999` | Auth (GoTrue) |
| `supabase-rest` | `172.20.0.78` | `postgrest/postgrest:v14.1` | — | `3000` | REST API (PostgREST) |
| `realtime-dev.supabase-realtime` | `172.20.0.79` | `supabase/realtime:v2.68.0` | — | — | Realtime subscriptions |
| `supabase-storage` | `172.20.0.80` | `supabase/storage-api:v1.33.0` | — | `5000` | Storage API |
| `supabase-imgproxy` | `172.20.0.81` | `darthsim/imgproxy:v3.30.1` | — | `8080` | Image transformation |
| `supabase-edge-functions` | `172.20.0.82` | `supabase/edge-runtime:v1.69.28` | — | — | Edge Functions runtime |

### 1.3 Other containers on `haus-netzwerk` network

| Container | IP | Host Port | Purpose |
|---|---|---|---|
| `sin-room13` | `172.20.0.2` | `8014` | SIN Room13 service |
| `simone-api` | `172.20.0.3` | `8080` | Simone API (Python) |
| `simone-worker` | `172.20.0.4` | — | Simone background worker |

### 1.4 Resource usage (live snapshot)

| Container | CPU | Memory |
|---|---|---|
| supabase-kong | 0.02 % | 634 MB |
| supabase-analytics | 4.39 % | 621 MB |
| supabase-db | 0.26 % | 266 MB |
| realtime-dev.supabase-realtime | 0.60 % | 191 MB |
| supabase-pooler | 0.17 % | 188 MB |
| supabase-studio | 0.00 % | 182 MB |
| supabase-storage | 0.25 % | 119 MB |
| supabase-meta | 27.00 % | 93 MB |
| supabase-rest | 0.05 % | 76 MB |
| supabase-vector | 0.12 % | 26 MB |
| supabase-edge-functions | 0.01 % | 28 MB |
| supabase-imgproxy | 5.27 % | 20 MB |
| supabase-auth | 0.02 % | 9 MB |
| **Total** | ~38 % | **~2.5 GB** of 24 GB |

---

## 2. Postgres Database

### 2.1 Version & Databases

| Property | Value |
|---|---|
| Version | PostgreSQL 15.8 on aarch64-unknown-linux-gnu |
| Databases | `postgres`, `_supabase`, `simone_shop` |
| Host port | `5433` (mapped to container `5432`) |
| Pooler port (transaction) | `6543` |
| Pooler port (session) | `5434` |
| Superuser | `postgres` (password in `/opt/sin-supabase/.env` → `POSTGRES_PASSWORD`) |

### 2.2 Extensions

| Extension | Version | Purpose |
|---|---|---|
| `pg_graphql` | 1.5.11 | GraphQL API |
| `pg_net` | 0.14.0 | HTTP requests from SQL |
| `pg_stat_statements` | 1.10 | Query statistics |
| `pgcrypto` | 1.3 | Cryptographic functions |
| `pgjwt` | 0.2.0 | JWT generation |
| `pgmq` | 1.4.4 | Message queues |
| `plpgsql` | 1.0 | PL/pgSQL language |
| `supabase_vault` | 0.3.1 | Secrets vault |
| `uuid-ossp` | 1.1 | UUID generation |
| `vector` | 0.8.0 | pgvector — embeddings storage |

### 2.3 Connection Strings (templates — fill from `.env`)

```
# Direct (localhost on sin-supabase)
postgresql://postgres:<POSTGRES_PASSWORD>@localhost:5433/postgres

# Via pooler (transaction mode)
postgresql://postgres:<POSTGRES_PASSWORD>@localhost:6543/postgres

# Via pooler (session mode)
postgresql://postgres:<POSTGRES_PASSWORD>@localhost:5434/postgres

# From other containers on haus-netzwerk
postgresql://postgres:<POSTGRES_PASSWORD>@172.20.0.71:5432/postgres
```

### 2.4 Autonomous psql access

```bash
# Quick query
ssh sin-supabase 'docker exec supabase-db psql -U postgres -c "SELECT count(*) FROM pg_tables WHERE schemaname = \"public\";"'

# List databases
ssh sin-supabase 'docker exec supabase-db psql -U postgres -c "\l"'

# List extensions
ssh sin-supabase 'docker exec supabase-db psql -U postgres -c "SELECT extname, extversion FROM pg_extension ORDER BY extname;"'

# Backup a database
ssh sin-supabase 'docker exec supabase-db pg_dump -U postgres -d simone_shop > /tmp/simone_shop_backup.sql'
```

---

## 3. `.env` Variables (keys only — NEVER print values)

Location: `/opt/sin-supabase/.env`

```env
# Auth & JWT
JWT_SECRET=
ANON_KEY=
SERVICE_ROLE_KEY=
JWT_EXPIRY=

# Postgres
POSTGRES_PASSWORD=
POSTGRES_HOST=
POSTGRES_PORT=
POSTGRES_DB=

# Kong (API Gateway)
KONG_HTTP_PORT=
KONG_HTTPS_PORT=

# Studio
STUDIO_PORT=
DASHBOARD_PASSWORD=
DASHBOARD_USERNAME=
STUDIO_DEFAULT_PROJECT=
STUDIO_DEFAULT_ORGANIZATION=

# Security
SECRET_KEY_BASE=
VAULT_ENC_KEY=
PG_META_CRYPTO_KEY=

# Logging
LOGFLARE_PUBLIC_ACCESS_TOKEN=
LOGFLARE_PRIVATE_ACCESS_TOKEN=

# URLs
SITE_URL=
API_EXTERNAL_URL=
SUPABASE_PUBLIC_URL=

# SMTP
SMTP_ADMIN_EMAIL=
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASS=
SMTP_SENDER_NAME=

# Pooler
POOLER_PROXY_PORT_TRANSACTION=
POOLER_MAX_CLIENT_CONN=
POOLER_DB_POOL_SIZE=
POOLER_TENANT_ID=
POOLER_DEFAULT_POOL_SIZE=

# Feature flags
DISABLE_SIGNUP=
ENABLE_EMAIL_SIGNUP=
ENABLE_EMAIL_AUTOCONFIRM=
ENABLE_PHONE_SIGNUP=
ENABLE_PHONE_AUTOCONFIRM=
ENABLE_ANONYMOUS_USERS=
ADDITIONAL_REDIRECT_URLS=

# Storage / Images
IMGPROXY_ENABLE_WEBP_DETECTION=
FILE_SIZE_LIMIT=

# Edge Functions
FUNCTIONS_VERIFY_JWT=

# PostgREST
PGRST_DB_SCHEMAS=

# Mailer
MAILER_URLPATHS_INVITE=
MAILER_URLPATHS_CONFIRMATION=
MAILER_URLPATHS_RECOVERY=
MAILER_URLPATHS_EMAIL_CHANGE=

# Docker
DOCKER_SOCKET_LOCATION=
```

> **To read a specific value (autonomous):**
> ```bash
> ssh sin-supabase 'grep "^POSTGRES_PASSWORD=" /opt/sin-supabase/.env | cut -d= -f2'
> ```
> **NEVER print the output in chat — pipe to a file or use inline.**

---

## 4. Kong API Gateway

### 4.1 Routes

| Path | Service | Container | Description |
|---|---|---|---|
| `/auth/v1/*` | `http://auth:9999/` | supabase-auth | GoTrue authentication |
| `/auth/v1/verify` | `http://auth:9999/verify` | supabase-auth | Token verification |
| `/auth/v1/callback` | `http://auth:9999/callback` | supabase-auth | OAuth callback |
| `/auth/v1/authorize` | `http://auth:9999/authorize` | supabase-auth | OAuth authorize |
| `/rest/v1/*` | PostgREST | supabase-rest | REST API (auto-generated from DB) |
| `/realtime/v1/*` | Realtime | supabase-realtime | WebSocket subscriptions |
| `/storage/v1/*` | Storage API | supabase-storage | File storage |
| `/functions/v1/*` | Edge Functions | supabase-edge-functions | Serverless functions |
| `/pg/*` | postgres-meta | supabase-meta | DB management API |

### 4.2 Authentication

- **Anon key:** JWT with role `anon` — passed as `apikey` header.
- **Service role key:** JWT with role `service_role` — bypasses RLS. NEVER expose client-side.
- Both are in `/opt/sin-supabase/.env` → `ANON_KEY`, `SERVICE_ROLE_KEY`.
- Kong validates via `key-auth` plugin + ACL groups (`anon`, `admin`).

### 4.3 Dashboard access

- Studio URL (local): `http://localhost:3004`
- Studio URL (public): `https://supabase.delqhi.com` (redirects to Studio or Kong)
- Dashboard credentials: `DASHBOARD_USERNAME` + `DASHBOARD_PASSWORD` in `.env`
- Basic auth on Kong for dashboard consumer.

### 4.4 Public access

```
supabase.delqhi.com → Cloudflare → sin-supabase:8006 → Kong → backend services
```

- `/rest/v1/` → HTTP 401 without `apikey` header (expected)
- `/auth/v1/health` → HTTP 401 without `apikey` header (expected)
- Studio → HTTP 307 (redirect to login)

### 4.5 Autonomous API test

```bash
# Read ANON_KEY from .env (do NOT print in chat)
ANON_KEY=$(ssh sin-supabase 'grep "^ANON_KEY=" /opt/sin-supabase/.env | cut -d= -f2')

# Test REST API
curl -sS -H "apikey: $ANON_KEY" https://supabase.delqhi.com/rest/v1/ -o /dev/null -w "HTTP %{http_code}\n"

# Test Auth health
curl -sS -H "apikey: $ANON_KEY" https://supabase.delqhi.com/auth/v1/health -w "\nHTTP %{http_code}\n"
```

---

## 5. Autonomous Operations Matrix

| Action | Command |
|---|---|
| List all Supabase containers | `ssh sin-supabase 'docker ps --filter name=supabase --format "{{.Names}}\t{{.Status}}"'` |
| Restart all Supabase services | `ssh sin-supabase 'cd /opt/sin-supabase && docker compose -p sin-supabase restart'` |
| Restart single container | `ssh sin-supabase 'docker restart supabase-kong'` |
| View logs | `ssh sin-supabase 'docker logs --tail 50 supabase-db'` |
| Studio access | `ssh sin-supabase 'curl -sS -o /dev/null -w "%{http_code}" http://localhost:3004'` |
| Kong health | `ssh sin-supabase 'curl -sS http://localhost:8001/status'` |
| Postgres query | `ssh sin-supabase 'docker exec supabase-db psql -U postgres -c "<SQL>"'` |
| Postgres backup | `ssh sin-supabase 'docker exec supabase-db pg_dump -U postgres <db> > /tmp/<db>.sql'` |
| Postgres restore | `ssh sin-supabase 'docker exec -i supabase-db psql -U postgres < < /tmp/<db>.sql'` |
| Update .env | `ssh sin-supabase 'sudo nano /opt/sin-supabase/.env'` (then restart affected container) |
| Pull + redeploy | `ssh sin-supabase 'cd /opt/sin-supabase && git pull && docker compose -p sin-supabase up -d'` |
| A2A runtime status | `ssh sin-supabase 'systemctl status sin-supabase.service --no-pager'` |
| A2A runtime logs | `ssh sin-supabase 'tail -50 /opt/sin-control-plane/logs/sin-supabase-a2a.log'` |
| Container resource usage | `ssh sin-supabase 'docker stats --no-stream --filter name=supabase'` |
| Network inspect | `ssh sin-supabase 'docker network inspect haus-netzwerk'` |

---

## 6. Recovery Playbooks

### 6.1 Supabase completely down

```bash
# 1. Check if containers are running
ssh sin-supabase 'docker ps | grep supabase'

# 2. If not, start the whole stack
ssh sin-supabase 'cd /opt/sin-supabase && docker compose -p sin-supabase up -d'

# 3. Wait and verify
sleep 15
ssh sin-supabase 'docker ps | grep supabase | wc -l'  # should be 13
ssh sin-supabase 'curl -sS -o /dev/null -w "%{http_code}" http://localhost:8006'
ssh sin-supabase 'curl -sS -o /dev/null -w "%{http_code}" http://localhost:3004'
```

### 6.2 Postgres won't start

```bash
# Check logs
ssh sin-supabase 'docker logs supabase-db 2>&1 | tail -30'

# Common causes:
# - Corrupted WAL: docker exec supabase-db pg_resetwal -D /var/lib/postgresql/data
# - Disk full: df -h / (see skill-oci-oracle-cloud §10.2)
# - Lock file stale: rm /var/lib/postgresql/data/postmaster.pid (inside container)

# Reset and restart
ssh sin-supabase 'docker restart supabase-db'
sleep 10
ssh sin-supabase 'docker exec supabase-db psql -U postgres -c "SELECT 1;"'
```

### 6.3 Kong / API gateway down (supabase.delqhi.com 502)

```bash
# Restart Kong
ssh sin-supabase 'docker restart supabase-kong'
sleep 5
ssh sin-supabase 'curl -sS http://localhost:8001/status'

# If Kong config is broken, rebuild from compose
ssh sin-supabase 'cd /opt/sin-supabase && docker compose -p sin-supabase up -d --force-recreate kong'

# Also check Cloudflare tunnel (see skill-oci-oracle-cloud §6.3)
ssh sin-supabase 'sudo systemctl restart cloudflared cloudflared-simone-api'
```

### 6.4 Auth (GoTrue) issues

```bash
# Check auth logs
ssh sin-supabase 'docker logs --tail 30 supabase-auth'

# Verify JWT_SECRET is set
ssh sin-supabase 'docker inspect supabase-auth --format "{{range .Config.Env}}{{println .}}{{end}}" | grep GOTRUE_JWT_SECRET'

# Restart auth
ssh sin-supabase 'docker restart supabase-auth'
```

### 6.5 Database backup & restore

```bash
# Full backup (all databases)
ssh sin-supabase 'docker exec supabase-db pg_dumpall -U postgres > /tmp/supabase_full_backup_$(date +%Y%m%d).sql'

# Single database backup
ssh sin-supabase 'docker exec supabase-db pg_dump -U postgres -d simone_shop > /tmp/simone_shop_$(date +%Y%m%d).sql'

# Restore
scp /tmp/backup.sql sin-supabase:/tmp/backup.sql
ssh sin-supabase 'docker exec -i supabase-db psql -U postgres < /tmp/backup.sql'

# Download backup to Mac
scp sin-supabase:/tmp/supabase_full_backup_*.sql /Users/jeremy/dev/backups/
```

---

## 7. A2A Control Plane

The `sin-supabase.service` systemd unit runs a Node.js A2A control plane that manages Supabase programmatically.

| Property | Value |
|---|---|
| Service file | `/etc/systemd/system/sin-supabase.service` |
| Working dir | `/opt/sin-control-plane/a2a/team-infratructur/A2A-SIN-Supabase` |
| Entry point | `dist/src/cli.js serve-a2a` |
| Env file | `/opt/sin-control-plane/.env.runtime` |
| Logs | `/opt/sin-control-plane/logs/sin-supabase-a2a.log` |
| Restart policy | `always` (RestartSec=5) |

### 7.1 Autonomous A2A operations

```bash
# Status
ssh sin-supabase 'systemctl status sin-supabase.service --no-pager'

# Restart A2A runtime
ssh sin-supabase 'sudo systemctl restart sin-supabase.service'

# View recent logs
ssh sin-supabase 'tail -100 /opt/sin-control-plane/logs/sin-supabase-a2a.log'

# Check if A2A is listening
ssh sin-supabase 'ss -tlnp | grep -E "3456|7860|7861|7862|7863|7864|7865|8090|8091|8234"'
```

---

## 8. Integration with OpenSIN-Chat

OpenSIN-Chat (running on the same VM, port `38471`) can optionally use Supabase as its database backend.

### 8.1 Current state

- OpenSIN-Chat currently uses **SQLite** (`file:../storage/openafd.db`) — NOT Supabase Postgres.
- To migrate to Supabase Postgres, update `OpenSIN-Chat/docker/.env`:
  ```env
  DATABASE_URL=postgresql://postgres:<POSTGRES_PASSWORD>@172.20.0.71:5432/opensin_chat
  ```
  Then restart: `ssh sin-supabase 'cd /home/ubuntu/OpenSIN-Chat/docker && docker compose -p opensin restart opensin-chat'`

### 8.2 Supabase Storage integration

OpenSIN-Chat can use Supabase Storage for document uploads:
```env
SUPABASE_STORAGE_ENABLED=true
SUPABASE_STORAGE_URL=http://172.20.0.76:8000/storage/v1
SUPABASE_SERVICE_KEY=<SERVICE_ROLE_KEY from /opt/sin-supabase/.env>
```

### 8.3 pgvector for embeddings

Supabase has `vector` 0.8.0 installed. OpenSIN-Chat can use it for embeddings:
```env
VECTOR_DB=pgvector
PGVECTOR_CONNECTION_STRING=postgresql://postgres:<POSTGRES_PASSWORD>@172.20.0.71:5432/postgres
PGVECTOR_TABLE_NAME=opensin_vectors
```

---

## 9. Security Notes

1. **`SERVICE_ROLE_KEY` bypasses RLS** — never expose it in client-side code, browser extensions, or public repos.
2. **Dashboard credentials** (`DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD`) protect Studio — rotate regularly.
3. **`JWT_SECRET`** signs all auth tokens — if compromised, all sessions are invalid. Rotate and restart `supabase-auth`.
4. **Postgres port `5433` is open on `0.0.0.0`** — ensure OCI Security List restricts access to known IPs only.
5. **Pooler ports `6543`/`5434` are open on `0.0.0.0`** — same restriction applies.
6. **Kong port `8006` is open** — this is the public API entry point via Cloudflare tunnel. Direct access should be blocked by OCI Security List (only Cloudflare tunnel needs `localhost:8006`).

---

## 10. Cross-References

| Resource | Location |
|---|---|
| OCI VM skill | `skill-oci-oracle-cloud` §1.1, §6, §21 |
| Cloudflare tunnel config | `skill-oci-oracle-cloud` §6.1 (`simone-api` tunnel) |
| SSH access | `skill-oci-oracle-cloud` §21.3–21.4 |
| OpenSIN-Chat deployment | `skill-oci-oracle-cloud` §21.6–21.10 |
| Infisical secrets | `skill-oci-oracle-cloud` §11 |
| Disk-full recovery | `skill-oci-oracle-cloud` §10.2 |
| Compose source | `/opt/sin-supabase/docker-compose.yml` on VM |
| A2A control plane | `/opt/sin-control-plane/` on VM |

---

## 11. Version History

| Date | Change |
|---|---|
| 2026-06-17 | Skill created — full live inventory, 13 containers, Postgres 15.8, Kong routes, .env keys, A2A runtime, recovery playbooks |

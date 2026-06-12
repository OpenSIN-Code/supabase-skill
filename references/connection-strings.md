# Supabase Connection Strings

## Database (Postgres)

### Internal (Docker network)

```bash
DATABASE_URL="postgresql://postgres:secure_supabase_2026@db:5432/postgres?sslmode=disable&search_path=shop"
```

Use this from:
- Other containers in the same `supabase_default` Docker network
- Inside the VM (via `docker exec supabase-db psql ...`)

### External (from outside VM)

```bash
DATABASE_URL_EXTERNAL="postgresql://simone:simone123@92.5.60.87:5433/postgres?sslmode=disable&search_path=shop"
```

⚠️  **Port 5433 is closed by default** (security). Use SSH tunnel:

```bash
ssh -L 5433:localhost:5433 ubuntu@92.5.60.87
# Then connect to localhost:5433
```

Or run on the VM directly:
```bash
ssh ubuntu@92.5.60.87 "docker exec supabase-db psql -U postgres -d postgres -c '...'"
```

## REST API (PostgREST)

### Anon (read-only, RLS-respecting)

```
https://supabase.delqhi.com/rest/v1/{table}?{query}
```

Header:
- `apikey: <anon-key>`
- `Authorization: Bearer <anon-key>`

Example:
```bash
curl "https://supabase.delqhi.com/rest/v1/products?select=id,title&limit=5" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Accept-Profile: shop"
```

### Service role (admin, bypasses RLS)

Same URL, but use `service_role` key.

## Auth API (GoTrue)

```
https://supabase.delqhi.com/auth/v1/...
```

Endpoints:
- `POST /auth/v1/token?grant_type=password` — login
- `POST /auth/v1/signup` — register
- `POST /auth/v1/logout` — logout
- `GET /auth/v1/user` — current user info
- `POST /auth/v1/admin/users` — admin: create user
- `DELETE /auth/v1/admin/users/{id}` — admin: delete user
- `POST /auth/v1/admin/generate_link` — admin: magic link / recovery / invite

## Storage API (S3-compatible)

```
https://supabase.delqhi.com/storage/v1/...
```

Endpoints:
- `GET /storage/v1/bucket` — list buckets
- `POST /storage/v1/bucket` — create bucket
- `GET /storage/v1/object/list/{bucket}` — list files
- `POST /storage/v1/object/{bucket}/{path}` — upload
- `GET /storage/v1/object/{bucket}/{path}` — download
- `DELETE /storage/v1/object/{bucket}/{path}` — delete
- `GET /storage/v1/object/public/{bucket}/{path}` — public URL (if bucket is public)

## Realtime API (WebSocket)

```
wss://supabase.delqhi.com/realtime/v1/websocket
```

Auth: `Bearer <jwt>` in subprotocol header

Subscribe to:
- Postgres changes (per table, per row)
- Broadcast events
- Presence (online users)

## Edge Functions

```
https://supabase.delqhi.com/functions/v1/{function-name}
```

Deploy with:
```bash
supabase functions deploy <name> --project-ref <ref>
```

Self-hosted:
```bash
docker exec supabase-edge-functions supabase functions deploy <name>
```

## Kong Gateway (port 8006)

Kong routes all the above services. From outside the VM, only the public `https://supabase.delqhi.com` is accessible (via Cloudflare Tunnel).

⚠️  **Never expose port 8006 directly** (Cloudflare blocks all ports except 80/443/2052/2053/2082/2083/2086/2087/2095/2096/8443).

## See also

- [sin-supabase.md](sin-supabase.md) — Instance overview
- [kong.md](kong.md) — API gateway config
- [postgrest.md](postgrest.md) — REST API details

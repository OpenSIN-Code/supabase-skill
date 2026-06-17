# supabase-skill — SIN-Supabase on OCI

Autonomous agent access to self-hosted Supabase on OCI VM `sin-supabase` (92.5.60.87).

## Contents

- `SKILL.md` — 490 lines, §0–§11 (inventory, Postgres, Kong, .env, recovery, A2A)
- `references/` — Connection strings, schemas, RLS policies, auth, backup strategy

## Live-verified 2026-06-17

- 13 Supabase containers on `haus-netzwerk` Docker network (172.20.0.0/16)
- PostgreSQL 15.8 with 10 extensions (pgvector 0.8.0, pg_graphql, pgmq, etc.)
- Kong API gateway on port 8006 → supabase.delqhi.com via Cloudflare tunnel
- A2A control plane via sin-supabase.service

## License

MIT

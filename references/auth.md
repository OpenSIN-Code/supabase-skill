# Supabase Auth

## Service: GoTrue

URL: `https://supabase.delqhi.com/auth/v1`

## Key types

- **anon key** (publishable): `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIs...`
  - Role: `anon`
  - Bypasses nothing (RLS enforced)
  - Safe for client-side code

- **service_role key** (admin): `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiw...`
  - Role: `service_role`
  - Bypasses ALL RLS
  - **Never** expose to client
  - Use only in server-side code, cron, admin operations

## JWT structure

```json
{
  "aud": "authenticated",
  "exp": 1234567890,
  "iat": 1234567890,
  "iss": "https://supabase.delqhi.com/auth/v1",
  "sub": "user-uuid",
  "email": "user@example.com",
  "phone": "",
  "app_metadata": {
    "provider": "email",
    "providers": ["email"]
  },
  "user_metadata": {
    "name": "Max"
  },
  "role": "authenticated",
  "aal": "aal1",
  "amr": [{"method": "password", "timestamp": 1234567890}],
  "session_id": "..."
}
```

## Common operations

### Login (password)

```bash
curl -X POST "https://supabase.delqhi.com/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"..."}'
```

Response: `{ access_token, refresh_token, expires_in, user, ... }`

### Get current user

```bash
curl -H "apikey: $ANON_KEY" -H "Authorization: Bearer $USER_JWT" \
  "https://supabase.delqhi.com/auth/v1/user"
```

### Signup (admin)

```bash
SERVICE_KEY="..."
curl -X POST "https://supabase.delqhi.com/auth/v1/admin/users" \
  -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"new@example.com","password":"...","email_confirm":true}'
```

### Generate magic link (admin)

```bash
curl -X POST "https://supabase.delqhi.com/auth/v1/admin/generate_link" \
  -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"magiclink","email":"user@example.com"}'
```

### Reset password (admin)

```bash
curl -X PUT "https://supabase.delqhi.com/auth/v1/admin/users/{user_id}" \
  -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"password":"new-password","email_confirm":true}'
```

## See also

- [Supabase Auth docs](https://supabase.com/docs/guides/auth)
- `scripts/jwt-decode.sh` — decode JWT payload
- [auth.md in cj-skill](../cj-dropshipping-skill/references/auth.md) — CJ OAuth (different)

# Row Level Security (RLS) Policies

## Default

**All new tables have RLS enabled by default** (PostgreSQL default in Supabase). Without a policy, no rows are visible (default-deny).

## Enable RLS (idempotent)

```sql
ALTER TABLE shop.products ENABLE ROW LEVEL SECURITY;
```

## Common patterns

### Public read (catalog visible to all)

```sql
-- Anyone can read active products
CREATE POLICY "products_public_read" ON shop.products
  FOR SELECT
  USING (is_active = true);
```

### User owns data (orders, addresses)

```sql
-- Users see only their own orders
CREATE POLICY "orders_select_own" ON shop.orders
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users create orders for themselves
CREATE POLICY "orders_insert_self" ON shop.orders
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

### Admin bypass (service_role)

The `service_role` key bypasses ALL RLS. Use only in:
- Server-side route handlers
- Cron jobs
- Admin operations
- **Never** in client-side code

### Custom JWT claims

```sql
-- Check user role from custom claim
CREATE POLICY "products_admin_write" ON shop.products
  FOR ALL
  USING (auth.jwt() ->> 'role' = 'admin');
```

## List policies

```sql
SELECT
  schemaname,
  tablename,
  policyname,
  CASE cmd
    WHEN 'r' THEN 'SELECT'
    WHEN 'a' THEN 'INSERT'
    WHEN 'w' THEN 'UPDATE'
    WHEN 'd' THEN 'DELETE'
    WHEN '*' THEN 'ALL'
  END as command,
  permissive,
  pg_get_expr(qual, qualrelid::regclass, true) as using_expr,
  pg_get_expr(with_check, with_check_relid::regclass, true) as check_expr
FROM pg_policies
WHERE schemaname = 'shop'
ORDER BY tablename, policyname;
```

## Test RLS

```bash
# 1. Without auth — should fail or return []
curl -H "apikey: $ANON_KEY" \
  "https://supabase.delqhi.com/rest/v1/orders?select=*"

# 2. With user JWT — should return only user's orders
curl -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $USER_JWT" \
  "https://supabase.delqhi.com/rest/v1/orders?select=*"
```

## Disable RLS (DANGEROUS)

```sql
ALTER TABLE shop.products DISABLE ROW LEVEL SECURITY;
```

⚠️  This makes ALL rows visible to anon key. Never do this for user data.

## See also

- [PostgreSQL RLS docs](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Supabase Auth + RLS](https://supabase.com/docs/guides/auth/row-level-security)
- `scripts/check-rls.sh` — verify RLS is active + policies exist

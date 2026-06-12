# Schemas — public vs shop

The OpenSIN Supabase has two main schemas for app data:

## `public` (Supabase core)

Owned by Supabase. Contains:
- `auth.users` — user accounts
- `auth.sessions` — login sessions
- `auth.identities` — OAuth identities
- `storage.buckets` — S3 bucket metadata
- `storage.objects` — S3 object metadata
- `realtime.subscriptions` — WebSocket subscriptions

⚠️  **Don't** create app tables in `public`. Use `shop` instead.

## `shop` (OpenSIN app)

Owned by OpenSIN. Contains all app data:

| Table | Purpose |
|-------|---------|
| `products` | Product catalog (CJ imports) |
| `categories` | Category tree |
| `cart_items` | Shopping cart |
| `orders` | Customer orders (from Stripe) |
| `addresses` | Customer addresses |
| `reviews` | Product reviews (CJ imports) |
| `cj_auth` | CJ OAuth token cache (id=1) |
| `affiliate_*` | Affiliate program tables |
| `admin_*` | Admin panel tables |
| `audit_log` | Admin action audit trail |

## View: `shop.products_v`

A SQL view that maps column names to what the app expects:

```sql
CREATE VIEW shop.products_v AS
SELECT
  p.id,
  p.name AS title,                                    -- name → title
  p.slug,
  p.description,
  p.price,
  p.original_price,
  p.compare_at_price,
  p.category_id,
  COALESCE(p.images->>0, '') AS image_url,            -- images[0] → image_url
  COALESCE(
    p.image_gallery,                                  -- real text[] column (cj-sync)
    ARRAY(SELECT jsonb_array_elements_text(p.images)),
    ARRAY[]::text[]
  ) AS image_gallery,                                  -- images[] → text[]
  p.stock,
  p.is_active,
  COALESCE(p.variants, '[]'::jsonb) AS variants,      -- variant selector JSONB
  p.metadata,
  p.badge,                                            -- bestseller | neu | sale
  p.sold_count,                                       -- social proof
  p.created_at,
  p.updated_at,
  p.cj_product_id,
  p.cj_variant_id,
  p.cj_sku,
  p.cj_cost_price,
  p.cj_last_synced_at,
  COALESCE(p.rating, (p.metadata->>'rating')::numeric, 0) AS rating,
  COALESCE(p.rating_count, (p.metadata->>'ratingCount')::integer, 0) AS rating_count,
  COALESCE((p.metadata->>'is_featured')::boolean, false) AS is_featured
FROM shop.products p;
```

**Always read via the view** for app code, **write directly to the table** for inserts/updates.

## Why not just rename the table columns?

Legacy code (`app/lib/queries.ts`, components, etc.) uses snake_case `title` and `image_url`. Renaming the table columns would require touching hundreds of files. The view is a clean abstraction layer.

## How to add new columns

1. Add column to `shop.products` (or other table):
   ```sql
   ALTER TABLE shop.products ADD COLUMN new_field text;
   ```
2. Update the view (`shop.products_v`) to include the new column.
3. Notify PostgREST: `NOTIFY pgrst, 'reload schema';`
4. Update app code to consume the new field.

## Listing all tables

```sql
-- All tables in shop
SELECT table_name, pg_size_pretty(pg_total_relation_size('shop.' || table_name)) as size
FROM information_schema.tables
WHERE table_schema = 'shop'
ORDER BY pg_total_relation_size('shop.' || table_name) DESC;
```

## See also

- [rls-policies.md](rls-policies.md) — RLS per schema
- [sin-supabase.md](sin-supabase.md) — Instance details

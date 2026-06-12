# Backup Strategy

## Daily backup (cron)

**Script**: `scripts/ops/backup-shop-db.sh`
**Schedule**: `0 3 * * *` (3 AM UTC daily)
**Location**: `/etc/cron.daily/backup-shop-db`

### What gets backed up

- Only `shop` schema (not `public` or Supabase core)
- `pg_dump -U postgres -d postgres -n shop --no-owner --clean --if-exists`
- Compressed with gzip
- SHA256 hash for integrity

### Where it goes

- OCI Object Storage: `s3://simone-backups/db/shop-YYYYMMDD-HHMM.sql.gz`
- (Optional) local retention: `/tmp/shop-*.sql.gz` (cleared after upload)

### Retention

- Default: 30 days
- Configurable via `BACKUP_BUCKET` env var
- Files older than 30 days auto-deleted from Object Storage

## Manual backup

```bash
./scripts/backup-db.sh              # to OCI Object Storage
./scripts/backup-db.sh --local     # keep local only
./scripts/backup-db.sh --keep=7    # only keep 7 days
```

## Restore

```bash
# 1. Download backup
aws s3 cp s3://simone-backups/db/shop-YYYYMMDD-HHMM.sql.gz ./restore.sql.gz \
  --endpoint-url "$OCI_S3_ENDPOINT"

# 2. Decompress
gunzip restore.sql.gz

# 3. Restore
docker exec -i supabase-db psql -U postgres -d postgres < restore.sql

# 4. Verify
docker exec supabase-db psql -U postgres -d postgres -c "SELECT count(*) FROM shop.products"
```

## Restore to a specific point

Postgres has **Point-In-Time Recovery (PITR)** if WAL archiving is enabled. Check:

```bash
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT name, setting FROM pg_settings
WHERE name IN ('wal_level', 'archive_mode', 'archive_command');"
```

⚠️  Currently NOT enabled for OpenSIN. To enable, see [Supabase PITR docs](https://supabase.com/docs/guides/platform/backups#point-in-time-recovery).

## Backup size estimation

- Shop schema: ~50 MB (data only)
- Daily growth: ~1 MB
- 30 days: ~80 MB total

## Disaster recovery

- **VM dies** → restore from latest OCI backup (RPO: 24h, RTO: ~30 min)
- **Single table corrupt** → restore from latest backup, lose only last 24h
- **Schema mistake** → restore from latest backup

## See also

- `scripts/ops/backup-shop-db.sh` — production script
- [sin-supabase.md](sin-supabase.md) — Instance details
- [docker-ops.md](docker-ops.md) — Container operations

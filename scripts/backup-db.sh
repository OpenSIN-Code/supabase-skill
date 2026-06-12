#!/bin/bash
# Backup Supabase DB to OCI Object Storage
# Usage: ./backup-db.sh [--local] [--keep 30]
# Docs: SKILL.md

set -uo pipefail

LOCAL_ONLY=false
KEEP_DAYS=30
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_ONLY=true ;;
    --keep=*) KEEP_DAYS="${arg#*=}" ;;
  esac
done

STAMP="$(date +%Y%m%d-%H%M)"
TMP="/tmp/shop-${STAMP}.sql.gz"
BUCKET="${BACKUP_BUCKET:-s3://simone-backups/db}"

echo "📦 Backup starting: $STAMP"

# Dump (shop schema only)
docker exec supabase-db pg_dump \
  -U postgres -d postgres -n shop --no-owner --clean --if-exists \
  | gzip > "$TMP"

SIZE=$(ls -la "$TMP" | awk '{print $5}')
echo "✓ Dump: $TMP ($SIZE bytes)"

# SHA256 for integrity
sha256sum "$TMP" | awk '{print $1}' > "$TMP.sha256"
echo "✓ Hash: $(cat $TMP.sha256)"

# Upload (if not local-only)
if [ "$LOCAL_ONLY" = "false" ] && [ -n "${OCI_S3_ENDPOINT:-}" ]; then
  aws s3 cp "$TMP" "$BUCKET/" --endpoint-url "$OCI_S3_ENDPOINT"
  echo "✓ Uploaded: $BUCKET/shop-${STAMP}.sql.gz"

  aws s3 cp "$TMP.sha256" "$BUCKET/" --endpoint-url "$OCI_S3_ENDPOINT"

  # Cleanup old backups
  aws s3 ls "$BUCKET/" --endpoint-url "$OCI_S3_ENDPOINT" | while read -r line; do
    file=$(echo "$line" | awk '{print $4}')
    if [ -n "$file" ]; then
      file_date=$(echo "$file" | grep -oE '[0-9]{8}-[0-9]{4}' | head -1)
      if [ -n "$file_date" ]; then
        file_epoch=$(date -j -f "%Y%m%d-%H%M" "$file_date" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
        age_days=$(( (now_epoch - file_epoch) / 86400 ))
        if [ "$age_days" -gt "$KEEP_DAYS" ]; then
          echo "🗑️  Deleting old: $file (${age_days} days)"
          aws s3 rm "$BUCKET/$file" --endpoint-url "$OCI_S3_ENDPOINT"
        fi
      fi
    fi
  done
else
  echo "⚠️  Skipping upload (--local or no OCI_S3_ENDPOINT)"
fi

# Cleanup local temp
rm -f "$TMP" "$TMP.sha256"
echo "✅ Done"

#!/bin/bash
# Supabase Storage helper (S3-compatible)
# Usage: ./storage-helper.sh <list|upload|download|delete> [args]
# Docs: SKILL.md

set -uo pipefail

CMD="${1:-}"
shift || true

SERVICE_KEY=$(grep SUPABASE_SERVICE_ROLE_KEY .env.local 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
BASE="https://supabase.delqhi.com/storage/v1"

case "$CMD" in
  list-buckets)
    echo "📦 Buckets:"
    curl -s -H "Authorization: Bearer $SERVICE_KEY" "$BASE/bucket" | python3 -c "
import json, sys
for b in json.load(sys.stdin):
    print(f'  {b[\"id\"]:30s} | public={b.get(\"public\", False)} | {b.get(\"file_size_limit\", 0)/1024/1024}MB max')
" 2>&1
    ;;

  list)
    BUCKET="${1:-}"
    PREFIX="${2:-}"
    if [ -z "$BUCKET" ]; then
      echo "Usage: $0 list <bucket> [prefix]"
      exit 1
    fi
    echo "📁 Files in $BUCKET (prefix: $PREFIX):"
    curl -s -H "Authorization: Bearer $SERVICE_KEY" \
      "$BASE/object/list/$BUCKET?prefix=$PREFIX" | python3 -c "
import json, sys
try:
    files = json.load(sys.stdin)
    if not files:
        print('  (empty)')
    for f in files[:50]:
        size_kb = f.get('metadata', {}).get('size', 0) / 1024
        print(f'  {f[\"name\"]:50s} | {size_kb:.1f} KB')
except Exception as e:
    print(f'Error: {e}')
" 2>&1
    ;;

  upload)
    BUCKET="${1:-}"
    REMOTE_PATH="${2:-}"
    LOCAL_FILE="${3:-}"
    if [ -z "$BUCKET" ] || [ -z "$REMOTE_PATH" ] || [ -z "$LOCAL_FILE" ]; then
      echo "Usage: $0 upload <bucket> <remote-path> <local-file>"
      exit 1
    fi
    if [ ! -f "$LOCAL_FILE" ]; then
      echo "❌ Local file not found: $LOCAL_FILE"
      exit 1
    fi
    CONTENT_TYPE=$(file --mime-type -b "$LOCAL_FILE")
    echo "📤 Uploading $LOCAL_FILE → $BUCKET/$REMOTE_PATH ($CONTENT_TYPE)"
    curl -s -X POST "$BASE/object/$BUCKET/$REMOTE_PATH" \
      -H "Authorization: Bearer $SERVICE_KEY" \
      -H "Content-Type: $CONTENT_TYPE" \
      --data-binary "@$LOCAL_FILE" | python3 -m json.tool
    ;;

  download)
    BUCKET="${1:-}"
    REMOTE_PATH="${2:-}"
    LOCAL_FILE="${3:-}"
    if [ -z "$BUCKET" ] || [ -z "$REMOTE_PATH" ] || [ -z "$LOCAL_FILE" ]; then
      echo "Usage: $0 download <bucket> <remote-path> <local-file>"
      exit 1
    fi
    echo "📥 Downloading $BUCKET/$REMOTE_PATH → $LOCAL_FILE"
    curl -s -o "$LOCAL_FILE" \
      -H "Authorization: Bearer $SERVICE_KEY" \
      "$BASE/object/$BUCKET/$REMOTE_PATH"
    ls -la "$LOCAL_FILE"
    ;;

  delete)
    BUCKET="${1:-}"
    REMOTE_PATH="${2:-}"
    if [ -z "$BUCKET" ] || [ -z "$REMOTE_PATH" ]; then
      echo "Usage: $0 delete <bucket> <remote-path>"
      exit 1
    fi
    echo "🗑️  Deleting $BUCKET/$REMOTE_PATH"
    curl -s -X DELETE "$BASE/object/$BUCKET/$REMOTE_PATH" \
      -H "Authorization: Bearer $SERVICE_KEY" | python3 -m json.tool
    ;;

  public-url)
    BUCKET="${1:-}"
    REMOTE_PATH="${2:-}"
    if [ -z "$BUCKET" ] || [ -z "$REMOTE_PATH" ]; then
      echo "Usage: $0 public-url <bucket> <remote-path>"
      exit 1
    fi
    echo "Public URL:"
    echo "  $BASE/object/public/$BUCKET/$REMOTE_PATH"
    ;;

  *)
    echo "Usage: $0 <list-buckets|list|upload|download|delete|public-url> ..."
    ;;
esac

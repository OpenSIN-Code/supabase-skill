#!/bin/bash
# Decode a Supabase JWT (no signature verification, just payload inspection)
# Usage: ./jwt-decode.sh <jwt>
# Docs: SKILL.md

JWT="${1:-}"
if [ -z "$JWT" ]; then
  # Try to read from .env.local
  if [ -f .env.local ]; then
    JWT=$(grep -E "^SUPABASE_ANON_KEY|^SUPABASE_SERVICE_ROLE_KEY" .env.local | head -1 | cut -d= -f2 | tr -d '"' || echo "")
  fi
fi

if [ -z "$JWT" ]; then
  echo "Usage: $0 <jwt-token>"
  echo "   (or run from a dir with .env.local)"
  exit 1
fi

# Split JWT: header.payload.signature
PAYLOAD=$(echo "$JWT" | cut -d. -f2)

# Base64url decode (add padding)
LEN=$((${#PAYLOAD} % 4))
if [ $LEN -eq 2 ]; then PADDING="=="; elif [ $LEN -eq 3 ]; then PADDING="="; else PADDING=""; fi
DECODED=$(echo "${PAYLOAD}${PADDING}" | tr '_-' '/+' | base64 -d 2>/dev/null)

if [ -z "$DECODED" ]; then
  echo "Failed to decode JWT"
  exit 1
fi

echo "$DECODED" | python3 -m json.tool 2>/dev/null || echo "$DECODED"

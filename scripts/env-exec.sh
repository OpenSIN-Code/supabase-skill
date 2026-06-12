#!/bin/bash
# Load .env.local vars and run a command
# Usage: ./env-exec.sh <command...>
# Docs: SKILL.md

if [ ! -f .env.local ]; then
  echo "❌ .env.local not found in current dir"
  exit 1
fi

# Load vars into env
set -a
source .env.local
set +a

# Run the passed command
exec "$@"

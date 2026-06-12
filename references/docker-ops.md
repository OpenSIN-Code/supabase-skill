# Docker Operations

## Container lifecycle

```bash
# List running
docker ps

# List all (including stopped)
docker ps -a

# Start/stop/restart
docker compose start supabase-db
docker compose stop supabase-auth
docker restart supabase-kong

# Logs
docker logs supabase-db --tail 100 -f
docker logs supabase-storage --since 1h
```

## Health checks

```bash
# All containers
docker ps --format 'table {{.Names}}\t{{.Status}}' | head

# Specific container
docker inspect --format='{{.State.Health.Status}}' supabase-db

# Resource usage
docker stats --no-stream | head
```

## Disk usage

```bash
# All containers
docker system df

# Per container
docker exec supabase-db du -sh /var/lib/postgresql/data

# Volume usage
docker volume ls
docker volume inspect supabase_db_data
```

## Network

```bash
# List networks
docker network ls

# Inspect
docker network inspect supabase_default

# List containers in network
docker network inspect supabase_default -f '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}'
```

## Update images

```bash
cd /opt/sin-supabase  # or wherever docker-compose.yml is

# Pull latest
docker compose pull

# Restart with new images
docker compose up -d

# Or do it rolling
docker compose up -d --no-deps <service>
```

## Common issues

### Container won't start

```bash
# Check logs
docker logs <container>

# Check disk
df -h

# Check memory
free -h
```

### Postgres out of disk

```bash
# Find large tables/indexes
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) as size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
LIMIT 20;"

# Vacuum full
docker exec supabase-db vacuumdb -U postgres -d postgres -f

# Reindex
docker exec supabase-db psql -U postgres -d postgres -c "REINDEX DATABASE CONCURRENTLY postgres;"
```

### Connection pool exhausted

```bash
# Check active connections
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT count(*), state FROM pg_stat_activity GROUP BY state;"

# Kill idle connections
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE state = 'idle' AND query_start < now() - interval '10 minutes';"
```

### Kong 502 errors

```bash
# Kong can't reach backend — check container health
docker ps

# Restart Kong (it caches DNS for 1 hour)
docker restart supabase-kong
```

## See also

- [sin-supabase.md](sin-supabase.md) — Instance details
- [backup-strategy.md](backup-strategy.md) — Backup/recovery

#!/usr/bin/env bash
set -euo pipefail
umask 077

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
exec 9>.operation.lock
flock 9

install -d -m 0700 backups
stamp=$(date -u +%Y%m%dT%H%M%SZ)
staging=$(mktemp -d backups/.staging.XXXXXX)
trap 'rm -rf -- "$staging"' EXIT

docker compose exec -T mysql sh -ec '
  MYSQL_PWD="$MYSQL_PASSWORD" exec mysqldump --single-transaction \
    --no-tablespaces --set-gtid-purged=OFF -u "$MYSQL_USER" "$MYSQL_DATABASE"
' | gzip -c >"$staging/ghost.sql.gz"
tar -czf "$staging/content.tar.gz" content

mv -T -- "$staging" "backups/$stamp"
find backups -mindepth 1 -maxdepth 1 -type d \
  -name '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z' \
  -mtime +6 -exec rm -rf -- {} +
printf 'Ghost backup saved to %s/backups/%s\n' "$PWD" "$stamp"

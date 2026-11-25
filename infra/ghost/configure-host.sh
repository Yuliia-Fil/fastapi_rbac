#!/usr/bin/env bash
set -euo pipefail
umask 077

domain=${1:?Provide the public hostname}
bundle_dir=${2:?Provide the deployment bundle directory}
stack_dir=/opt/ghost

install -d -m 0700 "$stack_dir"
exec 9>"$stack_dir/.operation.lock"
flock 9

install -m 0600 "$bundle_dir/compose.yml" "$stack_dir/compose.yml"
install -m 0644 "$bundle_dir/Caddyfile" "$stack_dir/Caddyfile"
install -m 0700 "$bundle_dir/backup.sh" "$stack_dir/backup.sh"
install -d -m 0755 "$stack_dir/content"
install -d -m 0700 -o 10000 -g 10000 "$stack_dir/caddy-data" "$stack_dir/caddy-config"

cd "$stack_dir"
if [[ -f .env ]]; then
  # Preserve initialized database credentials and restrict the update to public URLs.
  secrets=$(grep -E '^MYSQL_(ROOT_)?PASSWORD=[0-9a-f]{64}$' .env)
  [[ $(grep -c '^MYSQL_PASSWORD=' <<<"$secrets") == 1 ]]
  [[ $(grep -c '^MYSQL_ROOT_PASSWORD=' <<<"$secrets") == 1 ]]
else
  mysql_password=$(openssl rand -hex 32)
  mysql_root_password=$(openssl rand -hex 32)
  secrets=$(printf 'MYSQL_PASSWORD=%s\nMYSQL_ROOT_PASSWORD=%s' \
    "$mysql_password" "$mysql_root_password")
  unset mysql_password mysql_root_password
fi

env_file=$(mktemp .env.XXXXXX)
trap 'rm -f -- "$env_file"' EXIT
printf 'GHOST_URL=https://%s\nCADDY_SITE=%s\n%s\n' "$domain" "$domain" "$secrets" >"$env_file"
mv -f -- "$env_file" .env
unset secrets

docker compose pull
docker compose up -d --wait --wait-timeout 240
# Recreate the proxy to pick up a replaced bind-mounted Caddyfile.
docker compose up -d --no-deps --force-recreate caddy

cat >/etc/systemd/system/ghost-backup.service <<'EOF'
[Unit]
Description=Back up Ghost database and content
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
ExecStart=/opt/ghost/backup.sh
EOF

cat >/etc/systemd/system/ghost-backup.timer <<'EOF'
[Unit]
Description=Back up Ghost daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now ghost-backup.timer

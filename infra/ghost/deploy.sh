#!/usr/bin/env bash
set -euo pipefail
umask 077

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ $# -gt 1 || ( $# -eq 1 && $1 != --dry-run ) ]]; then
  printf 'Usage: %s [--dry-run]\n' "$0" >&2
  exit 2
fi

if [[ ${1:-} == --dry-run ]]; then
  command -v terraform >/dev/null || { printf 'Missing tool: terraform\n' >&2; exit 1; }
  terraform init -backend=false -input=false
  terraform validate
  terraform test
  CADDY_SITE=blog.example.com GHOST_URL=https://blog.example.com \
    MYSQL_PASSWORD=unused-example MYSQL_ROOT_PASSWORD=unused-example \
    docker compose --env-file /dev/null config --quiet
  printf 'Dry run passed. No AWS APIs were called.\n'
  exit 0
fi

for tool in terraform aws session-manager-plugin curl jq tar base64; do
  command -v "$tool" >/dev/null || { printf 'Missing tool: %s\n' "$tool" >&2; exit 1; }
done

export AWS_PAGER=""
aws sts get-caller-identity >/dev/null
scratch=$(mktemp -d .deploy-XXXXXX)
trap 'rm -rf -- "$scratch"' EXIT
terraform init -input=false
terraform plan -input=false -lock-timeout=30s -out="$scratch/deploy.tfplan"
if ! terraform show -json "$scratch/deploy.tfplan" |
  jq -e 'all(.resource_changes[]?; (.change.actions | index("delete")) == null)' >/dev/null; then
  printf 'Deployment stopped. Review the plan for resources that would be deleted or replaced.\n' >&2
  exit 1
fi
terraform apply -input=false -lock-timeout=30s "$scratch/deploy.tfplan"

region=$(terraform output -raw region)
instance_id=$(terraform output -raw instance_id)
blog_url=$(terraform output -raw blog_url)
domain=${blog_url#https://}

ssm() {
  aws --region "$region" ssm "$@"
}

printf 'Waiting for Session Manager to register %s.\n' "$instance_id"
agent_status=""
for ((attempt = 0; attempt < 60; attempt++)); do
  agent_status=$(ssm describe-instance-information --filters "Key=InstanceIds,Values=$instance_id" \
    --query 'InstanceInformationList[0].PingStatus' --output text)
  [[ $agent_status != Online ]] || break
  sleep 5
done
if [[ $agent_status != Online ]]; then
  printf 'SSM agent did not come online. Check EC2 instance status, IAM, and outbound connectivity.\n' >&2
  exit 1
fi

# This bundle contains public configuration and scripts only.
bundle=$(tar -czf - compose.yml Caddyfile configure-host.sh backup.sh | base64 | tr -d '\n')
{
  cat <<'REMOTE'
set -eu
cloud-init status --wait
bundle_dir=$(mktemp -d /var/tmp/ghost.XXXXXX)
trap 'rm -rf -- "$bundle_dir"' EXIT
REMOTE
  printf 'printf "%%s" %s | base64 -d | tar -xzf - -C "$bundle_dir"\n' "$bundle"
  printf 'bash "$bundle_dir/configure-host.sh" %s "$bundle_dir"\n' "$domain"
} | jq -Rs '{commands: [.], executionTimeout: ["900"]}' >"$scratch/ssm.json"

command_id=$(ssm send-command --instance-ids "$instance_id" --document-name AWS-RunShellScript \
  --parameters "file://$scratch/ssm.json" --query 'Command.CommandId' --output text)
printf 'Waiting for host configuration (SSM command %s).\n' "$command_id"
status=""
for ((attempt = 0; attempt < 180; attempt++)); do
  status=$(ssm get-command-invocation --command-id "$command_id" --instance-id "$instance_id" \
    --query Status --output text 2>/dev/null) || status=Pending
  case "$status" in
    Success | Cancelled | TimedOut | Failed | Cancelling) break ;;
  esac
  sleep 5
done
if [[ $status != Success ]]; then
  printf 'Host configuration ended with status %s. Inspect SSM command %s.\n' "$status" "$command_id" >&2
  exit 1
fi

session=(aws ssm start-session --region "$region" --target "$instance_id")
if [[ -n ${AWS_PROFILE:-} ]]; then
  session+=(--profile "$AWS_PROFILE")
fi
printf 'Blog: %s\nGhost Admin: %s/ghost/\nOpen a shell: ' "$blog_url" "$blog_url"
printf '%q ' "${session[@]}"
printf '\n'
curl --fail --silent --show-error --retry 12 --retry-delay 5 --retry-all-errors \
  --max-time 10 --output /dev/null "$blog_url/"
printf 'Public HTTPS check passed.\n'

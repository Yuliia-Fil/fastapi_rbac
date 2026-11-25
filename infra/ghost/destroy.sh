#!/usr/bin/env bash
set -euo pipefail
umask 077

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ $# -ne 0 ]]; then
  printf 'Usage: %s\n' "$0" >&2
  exit 2
fi
if [[ ! -s terraform.tfstate ]]; then
  printf 'No local Terraform state found in %s. Restore the deployment state before destroying.\n' "$PWD" >&2
  exit 1
fi

scratch=$(mktemp -d .destroy-XXXXXX)
trap 'rm -rf -- "$scratch"' EXIT
terraform init -input=false
terraform plan -destroy -input=false -lock-timeout=30s -out="$scratch/destroy.tfplan"
printf 'This removes the VM, its disk and its DNS record. Copy a backup off the VM first.\n'
read -r -p 'Type destroy to apply the plan: ' confirmation
if [[ $confirmation != destroy ]]; then
  printf 'Teardown cancelled.\n'
  exit 1
fi
terraform apply -input=false -lock-timeout=30s "$scratch/destroy.tfplan"

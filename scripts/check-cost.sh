#!/usr/bin/env bash
set -Eeuo pipefail

tfvars_file="${1:-terraform.tfvars}"
budget_usd="${2:-300}"

for command_name in terraform infracost jq; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command not found: ${command_name}" >&2
    exit 2
  fi
done

if [[ ! -f "${tfvars_file}" ]]; then
  echo "Terraform variable file not found: ${tfvars_file}" >&2
  exit 2
fi

temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

terraform init -backend=false
terraform plan -var-file="${tfvars_file}" -out="${temporary_dir}/plan.tfplan"
terraform show -json "${temporary_dir}/plan.tfplan" > "${temporary_dir}/plan.json"
infracost breakdown --path "${temporary_dir}/plan.json" --format json --out-file "${temporary_dir}/cost.json"

monthly_cost="$(jq -r '.totalMonthlyCost // "0"' "${temporary_dir}/cost.json")"
printf 'Estimated monthly cost: $%s; configured guardrail: $%s\n' "${monthly_cost}" "${budget_usd}"

if ! awk -v cost="${monthly_cost}" -v budget="${budget_usd}" 'BEGIN { exit !(cost <= budget) }'; then
  echo "STOP: the estimated monthly cost exceeds the configured budget." >&2
  exit 1
fi

echo "Cost check passed. Review usage-based and unsupported resources in the Infracost output before applying."

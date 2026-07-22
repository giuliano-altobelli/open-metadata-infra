#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
compose_template="${repo_root}/templates/docker-compose.yml.tftpl"
bootstrap_template="${repo_root}/templates/user-data.sh.tftpl"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! grep -Fq -- "$pattern" "$file"; then
    echo "FAIL: $message" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Fq -- "$pattern" "$file"; then
    echo "FAIL: $message" >&2
    exit 1
  fi
}

assert_contains "$compose_template" "AUTHENTICATION_PROVIDER: basic" "native username/password authentication is missing"
assert_contains "$compose_template" "AUTHENTICATION_ENABLE_SELF_SIGNUP: \"false\"" "self-signup must be disabled"
assert_contains "$compose_template" "PIPELINE_SERVICE_CLIENT_ENABLED: \"false\"" "Airflow client must be disabled"
assert_contains "$compose_template" "postgres:15-alpine" "PostgreSQL 15 container is missing"
assert_contains "$compose_template" "elasticsearch:9.3.0" "the required search container is missing"
assert_not_contains "$compose_template" "openmetadata_ingestion" "Airflow ingestion must not be deployed"
assert_contains "$bootstrap_template" 'docker_runtime_dir="$${MOUNT_POINT}/docker-runtime/$${runtime_instance_id}"' "Docker data must use an instance-scoped directory on the attached EBS volume"
assert_contains "$bootstrap_template" "openssl genpkey" "deployment-specific JWT keys must be generated"

echo "Static infrastructure contract checks passed."

#!/usr/bin/env bash
# US-06 — Validação Sprint 1 (Terraform + AWS CLI)
# Uso:
#   ./scripts/validate-sprint1.sh              # plan + verify (sem apply)
#   ./scripts/validate-sprint1.sh --apply      # init → plan → apply → verify
#   ./scripts/validate-sprint1.sh --verify-only # apenas verificação AWS/outputs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

TFVARS="${TFVARS:-terraform.tfvars}"
PLAN_FILE="${PLAN_FILE:-tfplan}"
APPLY=false
VERIFY_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --verify-only) VERIFY_ONLY=true ;;
    -h|--help)
      echo "Uso: $0 [--apply] [--verify-only]"
      exit 0
      ;;
  esac
done

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; exit 1; }
info() { echo "[INFO] $*"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Comando obrigatorio nao encontrado: $1"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    pass "${label}"
  else
    fail "${label} — esperado: '${expected}', obtido: '${actual}'"
  fi
}

require_cmd terraform
require_cmd aws
require_cmd jq

info "Conta AWS logada:"
aws sts get-caller-identity

if [[ "${VERIFY_ONLY}" == "false" ]]; then
  info "=== 1. terraform init ==="
  terraform init -input=false

  info "=== 2. terraform fmt ==="
  terraform fmt -recursive -check -diff || terraform fmt -recursive

  info "=== 3. terraform validate ==="
  terraform validate

  if [[ ! -f "${TFVARS}" ]]; then
    fail "Arquivo ${TFVARS} nao encontrado. Copie terraform.tfvars.example"
  fi

  info "=== 4. terraform plan ==="
  terraform plan -var-file="${TFVARS}" -out="${PLAN_FILE}" -input=false

  if [[ "${APPLY}" == "true" ]]; then
    info "=== 5. terraform apply ==="
    terraform apply -input=false "${PLAN_FILE}"
  else
    info "Apply ignorado (use --apply para executar). Plano salvo em ${PLAN_FILE}"
  fi
fi

info "=== 6. terraform output ==="
terraform output

info "=== 7. Verificacao AWS CLI ==="

RAW_BUCKET="$(terraform output -raw s3_bucket_raw_name)"
RESULTS_BUCKET="$(terraform output -raw s3_bucket_athena_results_name)"
GLUE_DB="$(terraform output -raw glue_database_name)"
WG="$(terraform output -raw athena_workgroup_name)"
LOG_GROUP="$(terraform output -raw glue_crawler_log_group_name)"
CRAWLER_ROLE="$(terraform output -raw glue_crawler_role_name)"
ANALYSTS_GROUP="$(terraform output -raw athena_analysts_group_name)"

# S3 raw
aws s3api head-bucket --bucket "${RAW_BUCKET}" >/dev/null 2>&1 && pass "S3 raw bucket existe: ${RAW_BUCKET}" || fail "S3 raw bucket ausente"
VERSIONING="$(aws s3api get-bucket-versioning --bucket "${RAW_BUCKET}" --query Status --output text)"
[[ "${VERSIONING}" == "Enabled" ]] && pass "S3 raw versionamento Enabled" || fail "S3 raw versionamento nao habilitado"

# S3 athena results
aws s3api head-bucket --bucket "${RESULTS_BUCKET}" >/dev/null 2>&1 && pass "S3 athena-results existe: ${RESULTS_BUCKET}" || fail "S3 athena-results ausente"

# Glue Database
DB_NAME="$(aws glue get-database --name "${GLUE_DB}" --query Database.Name --output text)"
assert_eq "Glue Database" "${GLUE_DB}" "${DB_NAME}"

# Athena Workgroup
WG_NAME="$(aws athena get-work-group --work-group "${WG}" --query WorkGroup.Name --output text)"
assert_eq "Athena Workgroup" "${WG}" "${WG_NAME}"
WG_ENGINE="$(aws athena get-work-group --work-group "${WG}" --query WorkGroup.Configuration.EngineVersion.SelectedEngineVersion --output text)"
assert_eq "Athena Engine" "Athena engine version 3" "${WG_ENGINE}"

# CloudWatch Log Group
RETENTION="$(aws logs describe-log-groups --log-group-name-prefix "${LOG_GROUP}" --query "logGroups[?logGroupName=='${LOG_GROUP}'].retentionInDays | [0]" --output text)"
assert_eq "Log Group retention (dias)" "14" "${RETENTION}"

# IAM Role Crawler
aws iam get-role --role-name "${CRAWLER_ROLE}" >/dev/null 2>&1 && pass "IAM Role Crawler: ${CRAWLER_ROLE}" || fail "IAM Role Crawler ausente"

# IAM Group Analysts
aws iam get-group --group-name "${ANALYSTS_GROUP}" >/dev/null 2>&1 && pass "IAM Group Analysts: ${ANALYSTS_GROUP}" || fail "IAM Group Analysts ausente"

# Drift check
info "=== 8. Drift check (terraform plan) ==="
PLAN_EXIT=0
terraform plan -var-file="${TFVARS}" -detailed-exitcode -input=false >/dev/null || PLAN_EXIT=$?
if [[ "${PLAN_EXIT}" -eq 0 ]]; then
  pass "Nenhum drift detectado"
elif [[ "${PLAN_EXIT}" -eq 2 ]]; then
  fail "Drift detectado — execute terraform plan para detalhes"
else
  fail "terraform plan falhou (exit ${PLAN_EXIT})"
fi

info "=== Validacao Sprint 1 concluida com sucesso ==="

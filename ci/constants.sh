#!/usr/bin/env bash
set -euo pipefail

declare -r INFRA="${CIDIR}/../infrastructure"
declare -r LOCAL_PLANS="${INFRA}/plans"
declare -r REMOTE_PLANS="s3://${PLAN_BUCKET}"
declare -r GHE_API="https://api.github.com"

export TF_VAR_AWS_REGION=${AWS_REGION}

terraform init -backend-config=${INFRA}/backend.conf ${INFRA}

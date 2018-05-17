#!/usr/bin/env bash
declare -r CIDIR="$(pwd)/$(dirname ${0})"
source ${CIDIR}/constants.sh

declare -r PLAN_PAYLOAD="/tmp/${TRAVIS_PULL_REQUEST_SHA}-plan.json"
declare -r STATUS_PAYLOAD="/tmp/${TRAVIS_PULL_REQUEST_SHA}-status.json"
declare -r LOCAL_PLAN="${LOCAL_PLANS}/${TRAVIS_PULL_REQUEST_SHA}"
declare -r REMOTE_PLAN="${REMOTE_PLANS}/${TRAVIS_PULL_REQUEST_SHA}"

declare -r PLAN_OUTPUT="$(terraform plan -no-color -out=${LOCAL_PLAN} ${INFRA})"
aws s3 cp ${LOCAL_PLAN} ${REMOTE_PLAN}

function post2ghe {
  local payload=$1
  local api_path=$2
  curl --silent --show-error --fail -o /dev/null \
    -H "Accept: application/json" \
    -H "Content-Type:application/json" \
    -H "Authorization: token ${GH_STATUS_TOKEN}" \
    -X POST --data @${payload} "${GHE_API}/v3/repos/${TRAVIS_REPO_SLUG}/${api_path}"
}

declare -r PLAN=$(cat <<EOF
<details><summary>Output from <code>terraform plan</code></summary><p>
<pre>
${PLAN_OUTPUT}
</pre>
</p></details>
EOF
)

echo "${PLAN}" | jq '{body: . }' --raw-input --slurp > ${PLAN_PAYLOAD}
post2ghe "${PLAN_PAYLOAD}" "issues/${TRAVIS_PULL_REQUEST}/comments"
echo "Terraform plan added as comment to PR"

jq -n '{state: "success", description: "Terraform plan added to PR", context: "terraform/plan"}' > ${STATUS_PAYLOAD}
post2ghe "${STATUS_PAYLOAD}" "statuses/${TRAVIS_PULL_REQUEST_SHA}"
echo "PR status for terraform plan added"

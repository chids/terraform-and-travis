#!/usr/bin/env bash
declare -r CIDIR="$(pwd)/$(dirname ${0})"
source ${CIDIR}/constants.sh

# Last commit from last merge (i.e. PR)
declare -r LAST_COMMIT=$(git log -1 --merges --pretty=format:%P|cut -d' ' -f2)

declare -r LOCAL_PLAN="${LOCAL_PLANS}/${LAST_COMMIT}"
declare -r REMOTE_PLAN="${REMOTE_PLANS}/${LAST_COMMIT}"

aws s3 cp ${REMOTE_PLAN} ${LOCAL_PLAN}
terraform apply ${LOCAL_PLAN}

#!/bin/bash
# shellcheck disable=SC2034
# SC2034 - Ignore unused variables because this script is meant to be sourced
#          into other scripts.

# This script is included in all stages - prepare, exec and cleanup.
# It defines basic variables and functions.

set -euo pipefail

# create directory for jobs
JOBS="/home/$(whoami)/jobs"
mkdir -p "${JOBS}"

# create directory the specified runner
RUNNER_DIR="${JOBS}/${CUSTOM_ENV_RUNNER}"
mkdir -p "${RUNNER_DIR}"

# define a directory for this specific job
JOB="${RUNNER_DIR}/${CUSTOM_ENV_CI_JOB_ID}"

# ServerAliveInterval helps with bad connectivity from/to the internal
# VPC
SSH="ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=600 -o StrictHostKeyChecking=no"

# Helpers extracting values from the runner's config.json.
function sshUser() {
  cat "${JOB}/${CUSTOM_ENV_RUNNER}/config.json" | jq -r '.user'
}

function runnerArch() {
  cat "${JOB}/${CUSTOM_ENV_RUNNER}/config.json" | jq -r '.runnerArch'
}

TERRAFORM_JOBS="/home/$(whoami)/terraform"
mkdir -p "${TERRAFORM_JOBS}"

function terraform-wrapper() {
  while true; do
    # ShellCheck prefers `find` over `ls`, `ls` should be fine though in this
    # case
    # shellcheck disable=SC2012
    COUNT=$(ls "$TERRAFORM_JOBS" | wc -l)
    if [[ $COUNT < 5 ]]; then
      break
    fi
    echo Too many terraform processes at the moment, waiting...
    sleep 10
  done

  touch "$TERRAFORM_JOBS/${CUSTOM_ENV_CI_JOB_ID}"
  trap "rm $TERRAFORM_JOBS/${CUSTOM_ENV_CI_JOB_ID}" return

  terraform -chdir=$JOB/${CUSTOM_ENV_RUNNER} "$@"
}

# Rename OpenStack authentication variables to the right names.
set +x
export OS_PROJECT_ID="${CUSTOM_ENV_OS_PROJECT_ID}"
export OS_AUTH_URL="${CUSTOM_ENV_OS_AUTH_URL}"
export OS_USERNAME="${CUSTOM_ENV_OS_USERNAME}"
export OS_PASSWORD="${CUSTOM_ENV_OS_PASSWORD}"

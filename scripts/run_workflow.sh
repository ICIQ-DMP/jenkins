#!/bin/bash
# Trigger a Jenkins job through the nginx reverse proxy exposed by this stack.
#
# Usage:
#   ./scripts/run_workflow.sh <job-name> [param=value ...]
#
# Example:
#   ./scripts/run_workflow.sh run-justicier ID=33 cause=automated+workflow
#
# Reads NGINX_SERVER_NAME and JENKINS_API_USER from .env (see .env.example).
# Requires these files under secrets/ (gitignored, one value per file, no trailing newline):
#   JENKINS_API_TOKEN    - API token of JENKINS_API_USER, used to authenticate
#   JENKINS_BUILD_TOKEN  - build token configured on the target job

set -euo pipefail

PROJECT_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
SECRETS_DIR="${PROJECT_FOLDER}/secrets"
ENV_FILE="${PROJECT_FOLDER}/.env"

usage() {
  echo "Usage: $0 <job-name> [param=value ...]" >&2
  exit 1
}

[ $# -ge 1 ] || usage
JOB="$1"
shift

[ -f "$ENV_FILE" ] || { echo "Missing .env (copy .env.example and fill it in)" >&2; exit 1; }

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

: "${NGINX_SERVER_NAME:?NGINX_SERVER_NAME must be set in .env}"
: "${JENKINS_API_USER:?JENKINS_API_USER must be set in .env}"

read_secret() {
  local file="${SECRETS_DIR}/$1"
  [ -f "$file" ] || { echo "Missing secrets/$1" >&2; exit 1; }
  tr -d '[:space:]' < "$file"
}

API_TOKEN="$(read_secret JENKINS_API_TOKEN)"
BUILD_TOKEN="$(read_secret JENKINS_BUILD_TOKEN)"
JENKINS_URL="http://${NGINX_SERVER_NAME}"

# Build the query string from any extra param=value arguments.
query="token=${BUILD_TOKEN}"
for param in "$@"; do
  case "$param" in
    *=*) query="${query}&${param}" ;;
    *) echo "Ignoring malformed parameter (expected key=value): ${param}" >&2 ;;
  esac
done

echo "--- Requesting crumb ---"
crumb_response=$(curl -sf -u "${JENKINS_API_USER}:${API_TOKEN}" "${JENKINS_URL}/crumbIssuer/api/json")
CRUMB=$(echo "$crumb_response" | jq -r '.crumb')

echo "--- Triggering job '${JOB}' ---"
curl -v -X POST \
  -u "${JENKINS_API_USER}:${API_TOKEN}" \
  -H "Jenkins-Crumb:${CRUMB}" \
  "${JENKINS_URL}/job/${JOB}/buildWithParameters?${query}"

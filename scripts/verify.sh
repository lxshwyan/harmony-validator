#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/env.sh"

cd "${PROJECT_DIR}"
"${OHPM}" install
"${SCRIPT_DIR}/test-local.sh"
"${SCRIPT_DIR}/build-release.sh"
"${SCRIPT_DIR}/scan-har.sh"

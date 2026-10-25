#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TASK_ROOT}/scripts/env.sh"
HAR="${1:-${TASK_ROOT}/validator/build/default/outputs/default/validator.har}"
if [[ ! -t 0 ]]; then
  echo 'Run this script in an interactive terminal and enter the OHPM signing-key passphrase there.' >&2
  exit 1
fi
"${OHPM}" prepublish "${HAR}"
exec "${OHPM}" publish "${HAR}"

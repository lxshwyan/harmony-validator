#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAR="${1:-${PROJECT_DIR}/validator/build/default/outputs/default/validator.har}"
MAX_BYTES="${HMKIT_MAX_HAR_BYTES:-131072}"

if [[ ! -f "${HAR}" ]]; then
  echo "HAR not found: ${HAR}" >&2
  exit 1
fi

ACTUAL_BYTES="$(wc -c < "${HAR}" | tr -d ' ')"
if (( ACTUAL_BYTES > MAX_BYTES )); then
  echo "HAR size ${ACTUAL_BYTES} bytes exceeds budget ${MAX_BYTES} bytes." >&2
  exit 1
fi

echo "HAR size budget passed (${ACTUAL_BYTES}/${MAX_BYTES} bytes)."

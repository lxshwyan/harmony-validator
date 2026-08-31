#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAR="${1:-${PROJECT_DIR}/validator/build/default/outputs/default/validator.har}"
CONTRACT="${SCRIPT_DIR}/api-contract.txt"

if [[ ! -f "${HAR}" ]]; then
  echo "HAR not found: ${HAR}" >&2
  exit 1
fi

PUBLIC_API="$(tar -xOzf "${HAR}" package/Index.d.ets)"
while IFS= read -r symbol; do
  [[ -z "${symbol}" ]] && continue
  if ! grep -Eq "(^|[^[:alnum:]_])${symbol}([^[:alnum:]_]|$)" <<<"${PUBLIC_API}"; then
    echo "Public API contract missing symbol: ${symbol}" >&2
    exit 1
  fi
done < "${CONTRACT}"

echo "Public API contract passed ($(wc -l < "${CONTRACT}" | tr -d ' ') symbols)."

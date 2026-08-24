#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/env.sh"

cd "${PROJECT_DIR}"
bash "${HVIGORW}" --mode module \
  -p product=default -p module=validator@default -p buildMode=release \
  assembleHar --no-daemon

HAR="validator/build/default/outputs/default/validator.har"
if [[ ! -f "${HAR}" ]]; then
  echo "Release HAR not found: ${HAR}" >&2
  exit 1
fi
# BuildProfile.ets is generated and changes with buildMode; keep it out of source control.
rm -f validator/BuildProfile.ets
echo "Release HAR: ${PROJECT_DIR}/${HAR}"

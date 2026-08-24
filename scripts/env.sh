#!/usr/bin/env bash

set -euo pipefail

DEVECO_ROOT="${DEVECO_ROOT:-/Applications/DevEco-Studio.app/Contents}"
if [[ ! -x "${DEVECO_ROOT}/tools/node/bin/node" || ! -f "${DEVECO_ROOT}/tools/hvigor/bin/hvigorw" ]]; then
  echo "DevEco toolchain not found at: ${DEVECO_ROOT}" >&2
  echo "Set DEVECO_ROOT to the DevEco Studio Contents directory." >&2
  exit 1
fi

export NODE_HOME="${DEVECO_ROOT}/tools/node"
export PATH="${NODE_HOME}/bin:${PATH}"
export DEVECO_SDK_HOME="${DEVECO_ROOT}/sdk"
export HVIGORW="${DEVECO_ROOT}/tools/hvigor/bin/hvigorw"
export OHPM="${DEVECO_ROOT}/tools/ohpm/bin/ohpm"

#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${TASK_ROOT}/scripts/env.sh"
cd "${TASK_ROOT}"
node scripts/model-codegen.mjs example/models/order.model.json example/models/Order.generated.ets --check
node scripts/test-tooling.mjs
node scripts/test-network.mjs
npm --prefix tooling ci --ignore-scripts --no-audit --no-fund
node "${DEVECO_ROOT}/tools/hvigor/hvigor/node_modules/typescript/lib/tsc.js" \
  --strict --noEmit --module nodenext --target es2022 tooling/standard-schema.typecheck.mts

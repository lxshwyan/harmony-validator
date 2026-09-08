#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${TASK_ROOT}/scripts/env.sh"
cd "${TASK_ROOT}/external-consumer"
"${OHPM}" install --all
HAR="${TASK_ROOT}/validator/build/default/outputs/default/validator.har"
INSTALLED="$(find oh_modules/.ohpm -type f -path '*/@hmkit/validator/ets/modules.abc' -print -quit)"
test -n "${INSTALLED}"
test "$(tar -xOzf "${HAR}" package/ets/modules.abc | shasum -a 256 | awk '{print $1}')" = "$(shasum -a 256 "${INSTALLED}" | awk '{print $1}')"
mkdir -p entry/src/main/ets/pages build
cp "${TASK_ROOT}/scripts/consumer-scenarios.ets" entry/src/main/ets/pages/ConsumerScenarios.ets
for MODE in main lite; do
  cp "${TASK_ROOT}/scripts/consumer-${MODE}.ets" entry/src/main/ets/pages/Index.ets
  bash "${HVIGORW}" assembleHap --mode module -p product=default -p module=entry@default -p buildMode=release --no-daemon
  HAP="entry/build/default/outputs/default/entry-default-unsigned.hap"
  test -s "${HAP}"
  cp "${HAP}" "build/consumer-${MODE}.hap"
  echo "${MODE} consumer HAP bytes: $(wc -c < "${HAP}" | tr -d ' ')"
done

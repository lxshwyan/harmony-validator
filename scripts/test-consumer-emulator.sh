#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${TASK_ROOT}/scripts/env.sh"
HDC="${DEVECO_ROOT}/sdk/default/openharmony/toolchains/hdc"
TARGET="${1:?Pass the explicit emulator HDC target}"
BUNDLE="com.hmkit.validator.consumer"
OUT="${TASK_ROOT}/external-consumer/build/emulator-validation"
mkdir -p "${OUT}"
if [[ "$(${HDC} -t "${TARGET}" shell param get const.product.model | tr -d '\r\n ')" != 'emulator' ]]; then
  echo 'Refusing to run this fixture on a non-emulator target.' >&2
  exit 1
fi
REMOTE='/data/local/tmp/hmkit-validator-layout.json'
LAYOUT="${OUT}/current-layout.json"
dump() {
  "${HDC}" -t "${TARGET}" shell uitest dumpLayout -b "${BUNDLE}" -p "${REMOTE}" >/dev/null
  "${HDC}" -t "${TARGET}" file recv "${REMOTE}" "${LAYOUT}" >/dev/null
}
assert_status() {
  local expected="$1"
  for attempt in 1 2 3 4 5; do
    dump
    if "${NODE_HOME}/bin/node" -e '
      const fs=require("fs"), root=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
      function find(n) { return n.attributes?.id === "validator_consumer_status" ? n.attributes.text : (n.children||[]).map(find).find(Boolean); }
      process.exit(find(root)===process.argv[2]?0:1);
    ' "${LAYOUT}" "${expected}"; then return; fi
  done
  echo "Expected status not reached: ${expected}" >&2
  exit 1
}
click_button() {
  dump
  local coordinates
  coordinates="$("${NODE_HOME}/bin/node" -e '
    const fs=require("fs"), root=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
    function find(n) { return n.attributes?.text === process.argv[2] ? n.attributes : (n.children||[]).map(find).find(Boolean); }
    const a=find(root); if(!a || a.enabled!=="true") process.exit(1);
    const b=a.bounds.match(/\d+/g).map(Number); console.log(Math.floor((b[0]+b[2])/2),Math.floor((b[1]+b[3])/2));
  ' "${LAYOUT}" "$1")"
  read -r x y <<<"${coordinates}"
  "${HDC}" -t "${TARGET}" shell uitest uiInput "${2:-click}" "${x}" "${y}" >/dev/null
}
for mode in main lite; do
  result="$("${HDC}" -t "${TARGET}" install -r "${TASK_ROOT}/external-consumer/build/consumer-${mode}.hap")"
  [[ "${result}" == *'install bundle successfully'* ]] || { echo "${result}"; exit 1; }
  for run in 1 2 3; do
    "${HDC}" -t "${TARGET}" shell aa force-stop -b "${BUNDLE}" >/dev/null
    result="$("${HDC}" -t "${TARGET}" shell aa start -a EntryAbility -b "${BUNDLE}")"
    [[ "${result}" == *'start ability successfully'* ]] || { echo "${result}"; exit 1; }
    assert_status 'PASS 1.2 consumer'
    cp "${LAYOUT}" "${OUT}/${mode}-start-${run}.json"
    echo "${mode}: process restart ${run} PASS"
  done
  click_button 'Run acceptance' doubleClick
  assert_status 'PASS 1.2 consumer'
  cp "${LAYOUT}" "${OUT}/${mode}-repeat.json"
  click_button 'Cancel pending request'
  assert_status 'Cancelled'
  cp "${LAYOUT}" "${OUT}/${mode}-cancel.json"
  click_button 'Run acceptance'
  assert_status 'PASS 1.2 consumer'
  "${HDC}" -t "${TARGET}" shell uitest uiInput keyEvent Back >/dev/null
  "${HDC}" -t "${TARGET}" shell aa start -a EntryAbility -b "${BUNDLE}" >/dev/null
  assert_status 'PASS 1.2 consumer'
  cp "${LAYOUT}" "${OUT}/${mode}-reenter.json"
  "${HDC}" -t "${TARGET}" shell snapshot_display -f /data/local/tmp/hmkit-validator.jpeg >/dev/null
  "${HDC}" -t "${TARGET}" file recv /data/local/tmp/hmkit-validator.jpeg "${OUT}/${mode}-pass.jpeg" >/dev/null
  pid="$("${HDC}" -t "${TARGET}" shell pidof "${BUNDLE}" | tr -d '\r\n ')"
  test -n "${pid}"
  "${HDC}" -t "${TARGET}" shell hilog -x -P "${pid}" > "${OUT}/${mode}-process.log"
  echo "${mode}: repeat/cancel-state/recovery/reentry PASS; process ${pid} alive"
done
echo "Emulator smoke passed; evidence: ${OUT}"

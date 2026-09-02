#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STRING_SCHEMA="${ROOT_DIR}/validator/src/main/ets/schemas/StringSchema.ets"
LITE_ENTRY="${ROOT_DIR}/validator/src/main/ets/lite.ets"
HAR="${ROOT_DIR}/validator/build/default/outputs/default/validator.har"

if rg -n "from '../rules/|from '../rules'" "${STRING_SCHEMA}"; then
  echo "StringSchema must not statically import concrete rule modules." >&2
  exit 1
fi

if rg -n "registerAllStringRules|rules/registerAll" "${LITE_ENTRY}"; then
  echo "The lite entry must not register all built-in rules." >&2
  exit 1
fi

RULES=(mobile email idCard bankCard plateNumber creditCode postalCode landline vin ipv4 chineseName qq wechat url uuid ipv6 base64 hostname)
for rule in "${RULES[@]}"; do
  wrapper="${ROOT_DIR}/validator/rules/${rule}.ets"
  implementation="${ROOT_DIR}/validator/src/main/ets/rules/${rule}.ets"
  test -f "${wrapper}" || { echo "Missing public rule entry: ${rule}" >&2; exit 1; }
  test -f "${implementation}" || { echo "Missing rule implementation: ${rule}" >&2; exit 1; }
  rg -q "src/main/ets/rules/${rule}" "${wrapper}" || {
    echo "Rule wrapper does not target its own implementation: ${rule}" >&2
    exit 1
  }
done

test -f "${HAR}" || { echo "Release HAR not found: ${HAR}" >&2; exit 1; }
tar -tzf "${HAR}" | rg -q '^package/Index\.d\.ets$'
tar -tzf "${HAR}" | rg -q '^package/lite\.d\.ets$'
for rule in "${RULES[@]}"; do
  tar -tzf "${HAR}" | rg -q "^package/rules/${rule}\.d\.ets$" || {
    echo "Release HAR is missing public rule declaration: ${rule}" >&2
    exit 1
  }
done

echo "Lite entry and ${#RULES[@]} on-demand rule paths passed dependency checks."

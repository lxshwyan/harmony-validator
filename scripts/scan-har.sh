#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAR="${1:-${PROJECT_DIR}/validator/build/default/outputs/default/validator.har}"

if [[ ! -f "${HAR}" ]]; then
  echo "HAR not found: ${HAR}" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT
tar -xzf "${HAR}" -C "${TEMP_DIR}"

if grep -R -n -E 'BEGIN (RSA |OPENSSH )?PRIVATE KEY|ssh-rsa|publish_id|key_path|OHPM_KEY_PASSPHRASE' "${TEMP_DIR}"; then
  echo "Sensitive publishing material found in HAR." >&2
  exit 1
fi

PACKAGE_META="${TEMP_DIR}/package/oh-package.json5"
if [[ ! -f "${PACKAGE_META}" ]]; then
  echo "oh-package.json5 not found in HAR." >&2
  exit 1
fi
if ! grep -q '"debug":false' "${PACKAGE_META}" || ! grep -q '"obfuscated":true' "${PACKAGE_META}"; then
  echo "HAR is not a release/obfuscated package." >&2
  exit 1
fi

SOURCE_VERSION="$(grep -E '"version"' "${PROJECT_DIR}/validator/oh-package.json5" | head -n 1 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
PACKAGE_VERSION="$(grep -Eo '"version":"[^"]+"' "${PACKAGE_META}" | head -n 1 | cut -d '"' -f 4)"
if [[ -z "${SOURCE_VERSION}" || "${SOURCE_VERSION}" != "${PACKAGE_VERSION}" ]]; then
  echo "HAR version (${PACKAGE_VERSION}) does not match source (${SOURCE_VERSION})." >&2
  exit 1
fi

echo "HAR security, version, and release metadata checks passed (${PACKAGE_VERSION})."

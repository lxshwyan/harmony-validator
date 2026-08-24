#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/env.sh"

REPORT="${1:-${PROJECT_DIR}/validator/.test/default/outputs/test/reports/coverageReport.json}"
MIN_LINES="${COVERAGE_MIN_LINES:-90}"
MIN_FUNCTIONS="${COVERAGE_MIN_FUNCTIONS:-80}"
MIN_BRANCHES="${COVERAGE_MIN_BRANCHES:-80}"

if [[ ! -f "${REPORT}" ]]; then
  echo "Coverage report not found: ${REPORT}" >&2
  exit 1
fi

node - "${REPORT}" "${MIN_LINES}" "${MIN_FUNCTIONS}" "${MIN_BRANCHES}" <<'NODE'
const fs = require('fs');

const reportPath = process.argv[2];
const limits = {
  lines: Number(process.argv[3]),
  functions: Number(process.argv[4]),
  branches: Number(process.argv[5]),
};

const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
const summary = report.summary;
let passed = true;

for (const name of ['lines', 'functions', 'branches']) {
  const actual = summary?.[name]?.pct;
  const minimum = limits[name];
  if (!Number.isFinite(actual) || !Number.isFinite(minimum)) {
    console.error(`Invalid coverage value for ${name}.`);
    passed = false;
    continue;
  }
  const status = actual >= minimum ? 'PASS' : 'FAIL';
  console.log(`${name}: ${actual.toFixed(2)}% (minimum ${minimum.toFixed(2)}%) ${status}`);
  if (actual < minimum) {
    passed = false;
  }
}

if (!passed) {
  console.error('Coverage thresholds were not met.');
  process.exit(1);
}
NODE

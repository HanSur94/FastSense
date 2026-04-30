#!/usr/bin/env bash
# check_skip_list_parity.sh — DIFF-04 (Phase 1015)
#
# Compares the skip-list blocks in tests/test_examples_smoke.m and
# examples/run_all_examples.m and exits non-zero on drift.
#
# Skip-list block convention (must match in both files):
#   % SKIP_LIST_BEGIN
#   <one example name per line, no leading/trailing whitespace>
#   % SKIP_LIST_END
#
# If either file is absent or its block is absent, parity holds
# vacuously and the script exits 0 — this lets the script ship before
# Phase 1012's smoke harness lands on every branch.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_FILE="$REPO_ROOT/tests/test_examples_smoke.m"
EXAMPLES_FILE="$REPO_ROOT/examples/run_all_examples.m"

extract_block() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return 1
    fi
    if ! grep -q 'SKIP_LIST_BEGIN' "$file"; then
        return 1
    fi
    awk '/SKIP_LIST_BEGIN/{flag=1; next} /SKIP_LIST_END/{flag=0} flag' "$file" \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        | grep -v '^$' \
        | sort
}

SMOKE_BLOCK="$(extract_block "$SMOKE_FILE" || true)"
EXAMPLES_BLOCK="$(extract_block "$EXAMPLES_FILE" || true)"

if [ -z "$SMOKE_BLOCK" ] && [ -z "$EXAMPLES_BLOCK" ]; then
    echo "check_skip_list_parity: no skip-list blocks found in either file — parity vacuously holds (exit 0)."
    exit 0
fi

if [ -z "$SMOKE_BLOCK" ] || [ -z "$EXAMPLES_BLOCK" ]; then
    echo "check_skip_list_parity: skip-list block present in only one file — drift detected."
    echo "  smoke present: $([ -n "$SMOKE_BLOCK" ] && echo yes || echo no)"
    echo "  examples present: $([ -n "$EXAMPLES_BLOCK" ] && echo yes || echo no)"
    exit 1
fi

if [ "$SMOKE_BLOCK" = "$EXAMPLES_BLOCK" ]; then
    echo "check_skip_list_parity: skip lists match (exit 0)."
    exit 0
fi

echo "check_skip_list_parity: skip-list drift detected:"
diff <(echo "$SMOKE_BLOCK") <(echo "$EXAMPLES_BLOCK") || true
exit 1

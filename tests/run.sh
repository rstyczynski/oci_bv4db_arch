#!/usr/bin/env bash
# tests/run.sh — centralized test runner (RUP quality gates)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

show_help() {
  cat <<'EOF'
Usage:
  tests/run.sh --integration [--component <scope>]
  tests/run.sh --integration --new-only <path/to/new_tests.manifest>

Options:
  --integration            Run integration suite
  --component <scope>      Limit suite to tests/manifests/component_<scope>.manifest
  --new-only <manifest>    Run only tests listed in new_tests.manifest (format: suite:script[:function])
  -h, --help               Show help

Notes:
  - This repo currently implements integration tests as standalone bash scripts under tests/integration/.
  - unit/smoke suites are not implemented yet in this repo; runner will error if requested.
EOF
}

suite=""
component=""
new_only_manifest=""

while [ $# -gt 0 ]; do
  case "$1" in
    --integration) suite="integration"; shift ;;
    --unit|--smoke)
      echo "Unsupported suite in this repo: $1" >&2
      exit 2
      ;;
    --component) component="${2:-}"; shift 2 ;;
    --new-only) new_only_manifest="${2:-}"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2
      ;;
  esac
done

[ -n "$suite" ] || { echo "Missing suite flag (e.g. --integration)" >&2; exit 2; }

resolve_manifest_tests() {
  local manifest="$1"
  [ -f "$manifest" ] || { echo "Manifest not found: $manifest" >&2; exit 2; }
  awk -F: -v s="$suite" '
    $0 ~ /^[[:space:]]*#/ { next }
    NF >= 2 && $1 == s { print $2 }
  ' "$manifest"
}

resolve_new_only_tests() {
  local manifest="$1"
  [ -f "$manifest" ] || { echo "new_tests.manifest not found: $manifest" >&2; exit 2; }
  awk -F: -v s="$suite" '
    $0 ~ /^[[:space:]]*#/ { next }
    NF >= 2 && $1 == s { print $2 }
  ' "$manifest"
}

tests=()

if [ -n "$new_only_manifest" ]; then
  while IFS= read -r t; do
    [ -n "$t" ] && tests+=("$t")
  done < <(resolve_new_only_tests "$new_only_manifest")
else
  if [ -n "$component" ]; then
    manifest="$REPO_ROOT/tests/manifests/component_${component}.manifest"
    while IFS= read -r t; do
      [ -n "$t" ] && tests+=("$t")
    done < <(resolve_manifest_tests "$manifest")
  else
    while IFS= read -r t; do
      [ -n "$t" ] && tests+=("$t")
    done < <(cd "$REPO_ROOT/tests/integration" && ls -1 test_*.sh 2>/dev/null || true)
  fi
fi

[ "${#tests[@]}" -gt 0 ] || { echo "No tests selected" >&2; exit 2; }

pass=0
fail=0

echo ""
echo "=== Running $suite tests (${#tests[@]} selected) ==="
echo ""

for t in "${tests[@]}"; do
  path="$REPO_ROOT/tests/${suite}/${t}"
  if [ ! -f "$path" ]; then
    echo "[FAIL] missing test script: $path"
    fail=$((fail+1))
    continue
  fi
  echo "--- $suite:$t ---"
  if bash "$path"; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
  fi
  echo ""
done

echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]


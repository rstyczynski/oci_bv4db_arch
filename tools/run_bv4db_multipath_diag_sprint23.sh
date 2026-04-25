#!/usr/bin/env bash
# Sprint 23: Multipath diagnostics (Sprint 22 baseline + LB follow-on sprint)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
S20_DIAG="$REPO_DIR/tools/run_bv4db_multipath_diag_sprint20.sh"
PROGRESS_DIR="$REPO_DIR/progress/sprint_23"

DEFAULT_PREFIX="bv4db-s23-mpath"
if [ -z "${NAME_PREFIX:-}" ]; then
  export NAME_PREFIX="$DEFAULT_PREFIX"
  echo "  [INFO] NAME_PREFIX not set; using Sprint 23 default: NAME_PREFIX=$NAME_PREFIX" >&2
fi

mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"
export PROGRESS_DIR="$PROGRESS_DIR"

echo "  [INFO] Working directory: $(pwd)"
echo "  [INFO] State will be: $(pwd)/state-${NAME_PREFIX}.json"

exec "$S20_DIAG"


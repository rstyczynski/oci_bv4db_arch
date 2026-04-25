#!/usr/bin/env bash
# Sprint 21 (BV4DB-52): Sprint 20 redo + fstab persistence workflow.

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
S20="$REPO_DIR/tools/run_bv4db_multipath_diag_sprint20.sh"

DEFAULT_PREFIX="bv4db-s20-mpath"
if [ -z "${NAME_PREFIX:-}" ]; then
  export NAME_PREFIX="$DEFAULT_PREFIX"
  echo "  [INFO] NAME_PREFIX not set; defaulting to reuse Sprint 20 instance: NAME_PREFIX=$NAME_PREFIX" >&2
elif [ "$NAME_PREFIX" != "$DEFAULT_PREFIX" ]; then
  echo "  [WARN] NAME_PREFIX=$NAME_PREFIX will create/adopt a separate instance. To reuse Sprint 20 instance use: NAME_PREFIX=$DEFAULT_PREFIX" >&2
fi

export PROGRESS_DIR="$REPO_DIR/progress/sprint_21"
mkdir -p "$PROGRESS_DIR"
exec "$S20"


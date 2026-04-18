#!/usr/bin/env bash
# run_bv_fio_oracle_sprint8.sh — Sprint 8 wrapper over the reusable Oracle layout runner.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

export PROGRESS_DIR="$REPO_DIR/progress/sprint_8"
export PROFILE_FILE="$REPO_DIR/progress/sprint_5/oracle-layout.fio"
export SPRINT_LABEL="Sprint 8"
export NAME_PREFIX="bv4db-oracle8-run"
export FIO_RUNTIME_SEC="${FIO_RUNTIME_SEC:-600}"
export STORAGE_LAYOUT_MODE="single_uhp"

exec "$REPO_DIR/tools/run_bv_fio_oracle.sh"

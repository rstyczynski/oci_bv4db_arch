#!/usr/bin/env bash
# run_bv_fio_oracle_sprint9_multi.sh — Sprint 9 separated-volume Oracle layout with 4 KB redo.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

export PROGRESS_DIR="$REPO_DIR/progress/sprint_9"
export PROFILE_FILE="$REPO_DIR/progress/sprint_9/oracle-layout-4k-redo.fio"
export SPRINT_LABEL="Sprint 9 Multi Volume"
export NAME_PREFIX="bv4db-oracle9-multi-run"
export RUN_LEVEL="integration"
export FIO_RUNTIME_SEC="${FIO_RUNTIME_SEC:-600}"
export STORAGE_LAYOUT_MODE="multi_volume"
export ARTIFACT_PREFIX="oracle-multi-4k-redo-integration"

exec "$REPO_DIR/tools/run_bv_fio_oracle.sh"

#!/usr/bin/env bash
# run_bv_fio_oracle_sprint5.sh — Sprint 5 wrapper over the reusable Oracle layout runner.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

export PROGRESS_DIR="$REPO_DIR/progress/sprint_5"
export PROFILE_FILE="$PROGRESS_DIR/oracle-layout.fio"
export SPRINT_LABEL="Sprint 5"
export NAME_PREFIX="bv4db-oracle5-run"
export FIO_RUNTIME_SEC="${FIO_RUNTIME_SEC:-600}"

exec "$REPO_DIR/tools/run_bv_fio_oracle.sh"

#!/usr/bin/env bash
# run_oracle_db_sprint18.sh — Sprint 18 mirror rerun of Sprint 17 with 900-second phases

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

export PROGRESS_DIR="${PROGRESS_DIR:-$REPO_DIR/progress/sprint_18}"
export SPRINT_LABEL="${SPRINT_LABEL:-Sprint 18}"
export SPRINT_NUMBER="${SPRINT_NUMBER:-18}"
export NAME_PREFIX="${NAME_PREFIX:-bv4db-oracle18-run}"
export METRICS_STATE_PREFIX="${METRICS_STATE_PREFIX:-metrics-sprint18}"
export SUMMARY_BASENAME="${SUMMARY_BASENAME:-sprint_18_summary.md}"
export OUTPUT_INDEX_BASENAME="${OUTPUT_INDEX_BASENAME:-sprint_18_outputs.md}"
export FIO_ARTIFACT_PREFIX="${FIO_ARTIFACT_PREFIX:-oracle18-fio-uhp-multi-900s}"
export SWINGBENCH_ARTIFACT_PREFIX="${SWINGBENCH_ARTIFACT_PREFIX:-oracle18-swingbench-uhp-multi-900s}"
export FIO_RUNTIME_SEC="${FIO_RUNTIME_SEC:-900}"
export SWINGBENCH_WORKLOAD_DURATION="${SWINGBENCH_WORKLOAD_DURATION:-900}"

exec "$REPO_DIR/tools/run_oracle_db_sprint17.sh"

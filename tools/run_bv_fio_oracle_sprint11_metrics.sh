#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROGRESS_DIR="$REPO_DIR/progress/sprint_11"
RUN_NAME_PREFIX="bv4db-oracle11-metrics-run"
RUN_STATE="$PROGRESS_DIR/state-${RUN_NAME_PREFIX}.json"
METRICS_NAME_PREFIX="metrics-oracle11"
METRICS_STATE="$PROGRESS_DIR/state-${METRICS_NAME_PREFIX}.json"
METRICS_DEF="$PROGRESS_DIR/metrics-definition.json"
REPORT_FILE="$PROGRESS_DIR/oci-metrics-report.md"
RAW_FILE="$PROGRESS_DIR/oci-metrics-raw.json"

mkdir -p "$PROGRESS_DIR"

PROGRESS_DIR="$PROGRESS_DIR" \
PROFILE_FILE="$REPO_DIR/progress/sprint_10/oracle-layout-4k-redo.fio" \
SPRINT_LABEL="Sprint 11" \
NAME_PREFIX="$RUN_NAME_PREFIX" \
RUN_LEVEL="integration" \
FIO_RUNTIME_SEC="300" \
ARTIFACT_PREFIX="oracle-balanced-single-metrics-300s" \
STORAGE_LAYOUT_MODE="single_uhp" \
COMPUTE_SHAPE="VM.Standard.E5.Flex" \
COMPUTE_OCPUS="8" \
COMPUTE_MEMORY_GB="32" \
VPU_SINGLE="10" \
"$REPO_DIR/tools/run_bv_fio_oracle.sh"

sleep 120

main_archived=$(ls -t "$PROGRESS_DIR"/state-${RUN_NAME_PREFIX}.deleted-*.json | head -1)
volume_archived=$(ls -t "$PROGRESS_DIR"/state-bv-singleuhp.deleted-*.json | head -1)
[ -f "$main_archived" ] || { echo "missing archived main run state" >&2; exit 1; }
[ -f "$volume_archived" ] || { echo "missing archived blockvolume state" >&2; exit 1; }

jq -s '.[0] * {blockvolume: .[1].blockvolume}' "$main_archived" "$volume_archived" > "$METRICS_STATE"

cd "$PROGRESS_DIR"
NAME_PREFIX="$METRICS_NAME_PREFIX" \
METRICS_DEF_FILE="$METRICS_DEF" \
REPORT_FILE="$REPORT_FILE" \
RAW_FILE="$RAW_FILE" \
"$REPO_DIR/oci_scaffold/resource/operate-metrics.sh"

echo "  [INFO] Metrics report saved: $REPORT_FILE"
echo "  [INFO] Metrics raw data saved: $RAW_FILE"

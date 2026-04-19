#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROGRESS_DIR="$REPO_DIR/progress/sprint_12"
RUN_NAME_PREFIX="bv4db-oracle12-metrics-run"
RUN_STATE="$PROGRESS_DIR/state-${RUN_NAME_PREFIX}.json"
METRICS_NAME_PREFIX="metrics-oracle12"
METRICS_STATE="$PROGRESS_DIR/state-${METRICS_NAME_PREFIX}.json"
METRICS_DEF="$PROGRESS_DIR/metrics-definition.json"
REPORT_FILE="$PROGRESS_DIR/oci-metrics-report.md"
HTML_REPORT_FILE="$PROGRESS_DIR/oci-metrics-report.html"
RAW_FILE="$PROGRESS_DIR/oci-metrics-raw.json"

mkdir -p "$PROGRESS_DIR"

PROGRESS_DIR="$PROGRESS_DIR" \
PROFILE_FILE="$REPO_DIR/progress/sprint_10/oracle-layout-4k-redo.fio" \
SPRINT_LABEL="Sprint 12" \
NAME_PREFIX="$RUN_NAME_PREFIX" \
RUN_LEVEL="integration" \
FIO_RUNTIME_SEC="300" \
ARTIFACT_PREFIX="oracle-balanced-multi-metrics-300s" \
STORAGE_LAYOUT_MODE="multi_volume" \
COMPUTE_SHAPE="VM.Standard.E5.Flex" \
COMPUTE_OCPUS="8" \
COMPUTE_MEMORY_GB="32" \
VPU_DATA="10" \
VPU_REDO="10" \
VPU_FRA="10" \
"$REPO_DIR/tools/run_bv_fio_oracle.sh"

sleep 120

main_archived=$(ls -t "$PROGRESS_DIR"/state-${RUN_NAME_PREFIX}.deleted-*.json | head -1)
data1_archived=$(ls -t "$PROGRESS_DIR"/state-bv-data1.deleted-*.json | head -1)
data2_archived=$(ls -t "$PROGRESS_DIR"/state-bv-data2.deleted-*.json | head -1)
redo1_archived=$(ls -t "$PROGRESS_DIR"/state-bv-redo1.deleted-*.json | head -1)
redo2_archived=$(ls -t "$PROGRESS_DIR"/state-bv-redo2.deleted-*.json | head -1)
fra_archived=$(ls -t "$PROGRESS_DIR"/state-bv-fra.deleted-*.json | head -1)

[ -f "$main_archived" ] || { echo "missing archived main run state" >&2; exit 1; }
[ -f "$data1_archived" ] || { echo "missing data1 archived state" >&2; exit 1; }
[ -f "$data2_archived" ] || { echo "missing data2 archived state" >&2; exit 1; }
[ -f "$redo1_archived" ] || { echo "missing redo1 archived state" >&2; exit 1; }
[ -f "$redo2_archived" ] || { echo "missing redo2 archived state" >&2; exit 1; }
[ -f "$fra_archived" ] || { echo "missing fra archived state" >&2; exit 1; }

jq -n \
  --slurpfile main "$main_archived" \
  --slurpfile data1 "$data1_archived" \
  --slurpfile data2 "$data2_archived" \
  --slurpfile redo1 "$redo1_archived" \
  --slurpfile redo2 "$redo2_archived" \
  --slurpfile fra "$fra_archived" \
  --arg metrics_def "$METRICS_DEF" \
  --arg report_file "$REPORT_FILE" \
  --arg html_report_file "$HTML_REPORT_FILE" \
  --arg raw_file "$RAW_FILE" \
  '
  $main[0] * {
    inputs: (($main[0].inputs // {}) + {
      metrics_definition_file: $metrics_def,
      metrics_report_file: $report_file,
      metrics_html_report_file: $html_report_file,
      metrics_raw_file: $raw_file
    }),
    volumes: {
      data1: {ocid: $data1[0].blockvolume.ocid},
      data2: {ocid: $data2[0].blockvolume.ocid},
      redo1: {ocid: $redo1[0].blockvolume.ocid},
      redo2: {ocid: $redo2[0].blockvolume.ocid},
      fra: {ocid: $fra[0].blockvolume.ocid}
    }
  }' > "$METRICS_STATE"

cd "$PROGRESS_DIR"
NAME_PREFIX="$METRICS_NAME_PREFIX" \
METRICS_DEF_FILE="$METRICS_DEF" \
REPORT_FILE="$REPORT_FILE" \
HTML_REPORT_FILE="$HTML_REPORT_FILE" \
RAW_FILE="$RAW_FILE" \
"$REPO_DIR/oci_scaffold/resource/operate-metrics.sh"

echo "  [INFO] Metrics report saved: $REPORT_FILE"
echo "  [INFO] Metrics HTML report saved: $HTML_REPORT_FILE"
echo "  [INFO] Metrics raw data saved: $RAW_FILE"

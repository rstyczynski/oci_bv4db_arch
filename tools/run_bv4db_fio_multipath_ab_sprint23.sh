#!/usr/bin/env bash
# Sprint 23: A/B fio benchmark with explicit multipath load balancing configuration.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
S20_AB="$REPO_DIR/tools/run_bv4db_fio_multipath_ab_sprint20.sh"
PROGRESS_DIR="$REPO_DIR/progress/sprint_23"

DEFAULT_PREFIX="bv4db-s23-mpath"
if [ -z "${NAME_PREFIX:-}" ]; then
  export NAME_PREFIX="$DEFAULT_PREFIX"
  echo "  [INFO] NAME_PREFIX not set; using Sprint 23 default: NAME_PREFIX=$NAME_PREFIX" >&2
fi

mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"
export PROGRESS_DIR="$PROGRESS_DIR"

export SPRINT_MNT="${SPRINT_MNT:-/mnt/sprint23}"
export USE_FSTAB="${USE_FSTAB:-true}"
export FSTAB_TAG="${FSTAB_TAG:-bv4db-sprint23}"

# Enable multipath load balancing by default for Sprint 23.
export MULTIPATH_LB_ENABLE="${MULTIPATH_LB_ENABLE:-true}"

# Copy sprint fstab helper to guest for operator workflows.
export GUEST_FSTAB_LOCAL="${GUEST_FSTAB_LOCAL:-$REPO_DIR/tools/guest/bv4db_sprint23_fstab.sh}"
export GUEST_FSTAB_REMOTE="${GUEST_FSTAB_REMOTE:-/tmp/bv4db_sprint23_fstab.sh}"

# Reuse Sprint 22 metrics definition by default (can override).
export METRICS_ENABLE="${METRICS_ENABLE:-true}"
export METRICS_DEF_FILE="${METRICS_DEF_FILE:-$PROGRESS_DIR/metrics-definition.json}"

echo "  [INFO] Working directory: $(pwd)"
echo "  [INFO] State will be: $(pwd)/state-${NAME_PREFIX}.json"
echo "  [INFO] Executing Sprint 20 A/B script (stable baseline) with Sprint 23 settings..."

exec "$S20_AB"


#!/usr/bin/env bash
# Sprint 22 (BV4DB-52): A/B benchmark with fstab persistence.
# This script wraps Sprint 20's proven A/B script.
#
# IMPORTANT: This script cd's to progress/sprint_22 so that:
#   - State file is created in progress/sprint_22/
#   - teardown.sh works correctly when run with NAME_PREFIX from that directory

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
S20_AB="$REPO_DIR/tools/run_bv4db_fio_multipath_ab_sprint20.sh"
PROGRESS_DIR="$REPO_DIR/progress/sprint_22"

# Sprint 22 uses its own prefix
DEFAULT_PREFIX="bv4db-s22-mpath"
if [ -z "${NAME_PREFIX:-}" ]; then
  export NAME_PREFIX="$DEFAULT_PREFIX"
  echo "  [INFO] NAME_PREFIX not set; using Sprint 22 default: NAME_PREFIX=$NAME_PREFIX" >&2
fi

# Create and cd to progress directory - THIS IS KEY FOR TEARDOWN TO WORK
mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"

# Export PROGRESS_DIR for Sprint 20 script to use
export PROGRESS_DIR="$PROGRESS_DIR"

# Sprint 22 specific mountpoint
export SPRINT_MNT="${SPRINT_MNT:-/mnt/sprint22}"

# Sprint 22 enables fstab handling
export USE_FSTAB="${USE_FSTAB:-true}"
export FSTAB_TAG="${FSTAB_TAG:-bv4db-sprint22}"

# Copy sprint fstab helper to guest for operator workflows.
export GUEST_FSTAB_LOCAL="${GUEST_FSTAB_LOCAL:-$REPO_DIR/tools/guest/bv4db_sprint22_fstab.sh}"
export GUEST_FSTAB_REMOTE="${GUEST_FSTAB_REMOTE:-/tmp/bv4db_sprint22_fstab.sh}"

# Sprint 22 additions:
# - generate OCI metrics report after each test window (multipath + single-path)
export METRICS_ENABLE="${METRICS_ENABLE:-true}"
export METRICS_DEF_FILE="${METRICS_DEF_FILE:-$PROGRESS_DIR/metrics-definition.json}"

echo "  [INFO] Working directory: $(pwd)"
echo "  [INFO] State will be: $(pwd)/state-${NAME_PREFIX}.json"

# Execute Sprint 20 A/B script (proven stable)
echo "  [INFO] Executing Sprint 20 A/B script (stable baseline)..."
exec "$S20_AB"

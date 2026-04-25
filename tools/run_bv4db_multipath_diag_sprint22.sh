#!/usr/bin/env bash
# Sprint 22 (BV4DB-52): Multipath diagnostics with fstab persistence.
# This script wraps Sprint 20's proven diagnostics script.
#
# IMPORTANT: This script cd's to progress/sprint_22 so that:
#   - State file is created in progress/sprint_22/
#   - teardown.sh works correctly when run with NAME_PREFIX from that directory

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
S20_DIAG="$REPO_DIR/tools/run_bv4db_multipath_diag_sprint20.sh"
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

echo "  [INFO] Working directory: $(pwd)"
echo "  [INFO] State will be: $(pwd)/state-${NAME_PREFIX}.json"

# Execute Sprint 20 diagnostics (proven stable)
echo "  [INFO] Executing Sprint 20 diagnostics script (stable baseline)..."
exec "$S20_DIAG"

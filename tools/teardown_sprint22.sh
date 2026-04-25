#!/usr/bin/env bash
# Sprint 22 teardown wrapper.
# This script cd's to progress/sprint_22 before calling teardown.sh
# so that NAME_PREFIX resolves to the correct state file.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROGRESS_DIR="$REPO_DIR/progress/sprint_22"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"

# Sprint 22 prefix
DEFAULT_PREFIX="bv4db-s22-mpath"
export NAME_PREFIX="${NAME_PREFIX:-$DEFAULT_PREFIX}"

# Add scaffold to PATH
export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"

# Check state file exists
STATE_FILE="$PROGRESS_DIR/state-${NAME_PREFIX}.json"
if [ ! -f "$STATE_FILE" ]; then
  echo "  [INFO] No Sprint 22 state file found: $STATE_FILE"
  echo "  [INFO] Nothing to teardown."
  exit 0
fi

echo "  [INFO] Sprint 22 teardown"
echo "  [INFO] State file: $STATE_FILE"

# cd to progress directory - THIS IS KEY
cd "$PROGRESS_DIR"

# Now NAME_PREFIX will resolve to ./state-bv4db-s22-mpath.json correctly
echo "  [INFO] Working directory: $(pwd)"

# Run teardown
exec "$SCAFFOLD_DIR/do/teardown.sh"

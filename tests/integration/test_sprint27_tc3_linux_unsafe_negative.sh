#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPRINT27_CASES="tc3" exec "$SCRIPT_DIR/test_sprint27_vpu_upgrade_multipath.sh"

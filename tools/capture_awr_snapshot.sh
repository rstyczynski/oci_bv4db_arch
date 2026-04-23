#!/usr/bin/env bash
# capture_awr_snapshot.sh — Capture AWR snapshot for benchmark window
#
# This script captures an AWR snapshot and outputs the snapshot ID.
# Use before and after workload to bracket the benchmark window.
#
# Prerequisites:
# - Oracle Database Free running
# - Run as oracle user or with sudo access
# - Database must have Diagnostics Pack license (included in Free edition for AWR)
#
# Usage: capture_awr_snapshot.sh [begin|end] [output_file]

set -euo pipefail

SNAPSHOT_TYPE="${1:-begin}"  # begin or end
OUTPUT_FILE="${2:-/tmp/awr_${SNAPSHOT_TYPE}_snap_id.txt}"
ORACLE_SID="${ORACLE_SID:-FREE}"
LOG_FILE="${LOG_FILE:-/tmp/awr_capture.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Set Oracle environment if not already set
if [ -z "${ORACLE_HOME:-}" ]; then
    export ORACLE_BASE=/opt/oracle
    export ORACLE_HOME=/opt/oracle/product/23ai/dbhomeFree
    export ORACLE_SID=$ORACLE_SID
    export PATH=$ORACLE_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$ORACLE_HOME/lib:${LD_LIBRARY_PATH:-}
fi

log "=== AWR Snapshot Capture ($SNAPSHOT_TYPE) ==="

# Capture AWR snapshot and get the ID
SNAP_ID=$(sqlplus -S / as sysdba <<'EOF'
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 100
SET TRIMSPOOL ON
SET SERVEROUTPUT ON

-- Create AWR snapshot
DECLARE
    v_snap_id NUMBER;
BEGIN
    v_snap_id := DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();
    DBMS_OUTPUT.PUT_LINE(v_snap_id);
END;
/
EOF
)

# Clean up the output (remove whitespace)
SNAP_ID=$(echo "$SNAP_ID" | tr -d '[:space:]')

if [ -z "$SNAP_ID" ] || [ "$SNAP_ID" = "0" ]; then
    log "ERROR: Failed to capture AWR snapshot"
    exit 1
fi

# Save snapshot ID to file
echo "$SNAP_ID" > "$OUTPUT_FILE"

# Get snapshot details
SNAP_TIME=$(sqlplus -S / as sysdba <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 100
SET TRIMSPOOL ON

SELECT TO_CHAR(end_interval_time, 'YYYY-MM-DD HH24:MI:SS')
FROM dba_hist_snapshot
WHERE snap_id = $SNAP_ID
AND ROWNUM = 1;
EOF
)
SNAP_TIME=$(echo "$SNAP_TIME" | tr -d '[:space:]' | head -1)

log "Snapshot captured successfully"
log "  Type: $SNAPSHOT_TYPE"
log "  Snapshot ID: $SNAP_ID"
log "  Snapshot Time: $SNAP_TIME"
log "  Output file: $OUTPUT_FILE"

# Output just the snapshot ID for scripting
echo "$SNAP_ID"

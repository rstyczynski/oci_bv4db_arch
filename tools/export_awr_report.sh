#!/usr/bin/env bash
# export_awr_report.sh — Export AWR report as HTML for benchmark window
#
# This script generates an AWR report between two snapshot IDs.
# The report is exported as HTML for portability and readability.
#
# Prerequisites:
# - Oracle Database Free running
# - AWR snapshots captured (begin and end)
# - Run as oracle user or with sudo access
#
# Usage: export_awr_report.sh <begin_snap_id> <end_snap_id> [output_file]

set -euo pipefail

BEGIN_SNAP_ID="${1:-}"
END_SNAP_ID="${2:-}"
OUTPUT_FILE="${3:-/tmp/awr_report.html}"
ORACLE_SID="${ORACLE_SID:-FREE}"
LOG_FILE="${LOG_FILE:-/tmp/awr_export.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

if [ -z "$BEGIN_SNAP_ID" ] || [ -z "$END_SNAP_ID" ]; then
    echo "Usage: export_awr_report.sh <begin_snap_id> <end_snap_id> [output_file]"
    exit 1
fi

# Set Oracle environment if not already set
if [ -z "${ORACLE_HOME:-}" ]; then
    export ORACLE_BASE=/opt/oracle
    export ORACLE_HOME=/opt/oracle/product/23ai/dbhomeFree
    export ORACLE_SID=$ORACLE_SID
    export PATH=$ORACLE_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$ORACLE_HOME/lib:${LD_LIBRARY_PATH:-}
fi

log "=== AWR Report Export ==="
log "Begin Snapshot: $BEGIN_SNAP_ID"
log "End Snapshot: $END_SNAP_ID"
log "Output file: $OUTPUT_FILE"

# Get DBID and instance number
DBID=$(sqlplus -S / as sysdba <<'EOF'
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SELECT dbid FROM v$database;
EOF
)
DBID=$(echo "$DBID" | tr -d '[:space:]')

INST_NUM=$(sqlplus -S / as sysdba <<'EOF'
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SELECT instance_number FROM v$instance;
EOF
)
INST_NUM=$(echo "$INST_NUM" | tr -d '[:space:]')

log "Database ID: $DBID"
log "Instance Number: $INST_NUM"

# Verify snapshots exist
SNAP_CHECK=$(sqlplus -S / as sysdba <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SELECT COUNT(*)
FROM dba_hist_snapshot
WHERE snap_id IN ($BEGIN_SNAP_ID, $END_SNAP_ID)
AND dbid = $DBID;
EOF
)
SNAP_CHECK=$(echo "$SNAP_CHECK" | tr -d '[:space:]')

if [ "$SNAP_CHECK" != "2" ]; then
    log "ERROR: One or both snapshots not found (found $SNAP_CHECK of 2)"
    exit 1
fi

log "Snapshots verified"

# Generate AWR report
log "Generating AWR report..."

# Create temporary SQL script for AWR report generation
TMP_SQL=$(mktemp /tmp/awr_report_XXXXXX.sql)
TMP_OUTPUT=$(mktemp /tmp/awr_output_XXXXXX.html)

cat > "$TMP_SQL" <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET TRIMSPOOL ON
SET LINESIZE 8000
SET PAGESIZE 0
SET LONG 1000000
SET LONGCHUNKSIZE 1000000

SPOOL $TMP_OUTPUT

SELECT output
FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(
    l_dbid => $DBID,
    l_inst_num => $INST_NUM,
    l_bid => $BEGIN_SNAP_ID,
    l_eid => $END_SNAP_ID
));

SPOOL OFF
EXIT;
EOF

sqlplus -S / as sysdba @"$TMP_SQL" >> "$LOG_FILE" 2>&1

# Check if report was generated
if [ ! -s "$TMP_OUTPUT" ]; then
    log "ERROR: AWR report generation failed - empty output"
    rm -f "$TMP_SQL" "$TMP_OUTPUT"
    exit 1
fi

# Move report to final location
mv "$TMP_OUTPUT" "$OUTPUT_FILE"
rm -f "$TMP_SQL"

# Get report size
REPORT_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "unknown")

log "AWR report generated successfully"
log "  File: $OUTPUT_FILE"
log "  Size: $REPORT_SIZE bytes"

# Get snapshot time range for reference
SNAP_RANGE=$(sqlplus -S / as sysdba <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 200
SELECT
    TO_CHAR(b.end_interval_time, 'YYYY-MM-DD HH24:MI:SS') || ' to ' ||
    TO_CHAR(e.end_interval_time, 'YYYY-MM-DD HH24:MI:SS')
FROM dba_hist_snapshot b, dba_hist_snapshot e
WHERE b.snap_id = $BEGIN_SNAP_ID
AND e.snap_id = $END_SNAP_ID
AND b.dbid = $DBID
AND e.dbid = $DBID
AND ROWNUM = 1;
EOF
)
SNAP_RANGE=$(echo "$SNAP_RANGE" | head -1 | xargs)

log "  Time range: $SNAP_RANGE"
log "==========================="

echo "$OUTPUT_FILE"

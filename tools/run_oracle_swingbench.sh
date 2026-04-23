#!/usr/bin/env bash
# run_oracle_swingbench.sh — build a Swingbench SOE schema and run charbench

set -euo pipefail

WORKLOAD_DURATION="${1:-${WORKLOAD_DURATION:-300}}"
ORACLE_SID="${ORACLE_SID:-FREE}"
ORACLE_PDB="${ORACLE_PDB:-FREEPDB1}"
ORACLE_PWD="${ORACLE_PWD:-BenchmarkPwd123}"
SWINGBENCH_HOME="${SWINGBENCH_HOME:-/opt/swingbench}"
SWINGBENCH_SCHEMA="${SWINGBENCH_SCHEMA:-soe}"
SWINGBENCH_PASSWORD="${SWINGBENCH_PASSWORD:-soe}"
SWINGBENCH_SCALE="${SWINGBENCH_SCALE:-1}"
SWINGBENCH_USERS="${SWINGBENCH_USERS:-4}"
SWINGBENCH_BUILD_THREADS="${SWINGBENCH_BUILD_THREADS:-4}"
BUILD_SCHEMA="${BUILD_SCHEMA:-true}"
RESULTS_DIR="${RESULTS_DIR:-/tmp/swingbench}"
LOG_FILE="${LOG_FILE:-$RESULTS_DIR/charbench.log}"
RESULTS_XML="${RESULTS_XML:-$RESULTS_DIR/results.xml}"
RESULTS_TXT="${RESULTS_TXT:-$RESULTS_DIR/results.txt}"
RESULTS_DB_JSON="${RESULTS_DB_JSON:-$RESULTS_DIR/results_db.json}"
CONNECT_STRING="${CONNECT_STRING:-//localhost:1521/$ORACLE_PDB}"
CONFIG_FILE="${CONFIG_FILE:-$RESULTS_DIR/SOE_Server_Side_V2.xml}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

run_sys_sql() {
    sqlplus -S / as sysdba <<SQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 1000
SET VERIFY OFF
$1
SQL
}

runtime_token() {
    local total="$1"
    local hours minutes seconds
    hours=$((total / 3600))
    minutes=$(((total % 3600) / 60))
    seconds=$((total % 60))
    if [ "$seconds" -eq 0 ]; then
        printf '%d:%02d' "$hours" "$minutes"
    else
        printf '%d:%02d.%02d' "$hours" "$minutes" "$seconds"
    fi
}

[ -f "$HOME/.oracle_env" ] && . "$HOME/.oracle_env"
export ORACLE_SID
export PATH="${ORACLE_HOME:-/opt/oracle/product/23ai/dbhomeFree}/bin:$PATH"
export LD_LIBRARY_PATH="${ORACLE_HOME:-/opt/oracle/product/23ai/dbhomeFree}/lib:${LD_LIBRARY_PATH:-}"

command -v sqlplus >/dev/null 2>&1 || { echo "sqlplus not found" >&2; exit 1; }
command -v java >/dev/null 2>&1 || { echo "java not found" >&2; exit 1; }
[ -x "$SWINGBENCH_HOME/bin/oewizard" ] || { echo "missing $SWINGBENCH_HOME/bin/oewizard" >&2; exit 1; }
[ -x "$SWINGBENCH_HOME/bin/charbench" ] || { echo "missing $SWINGBENCH_HOME/bin/charbench" >&2; exit 1; }
[ -f "$CONFIG_FILE" ] || { echo "missing config file $CONFIG_FILE" >&2; exit 1; }

mkdir -p "$RESULTS_DIR"
: >"$LOG_FILE"

RUNTIME_TOKEN="$(runtime_token "$WORKLOAD_DURATION")"

log "=== Swingbench Oracle Load Generation ==="
log "Connect string: $CONNECT_STRING"
log "Schema: $SWINGBENCH_SCHEMA"
log "Users: $SWINGBENCH_USERS"
log "Scale: $SWINGBENCH_SCALE"
log "Runtime: $WORKLOAD_DURATION seconds ($RUNTIME_TOKEN)"
log "Config file: $CONFIG_FILE"

DB_STATUS="$(run_sys_sql 'SELECT status FROM v$instance;' | tr -d '[:space:]')"
[ "$DB_STATUS" = "OPEN" ] || { log "ERROR: database status is $DB_STATUS"; exit 1; }

PDB_STATUS="$(run_sys_sql "SELECT open_mode FROM v\$pdbs WHERE name = UPPER('$ORACLE_PDB');" | tr -d '[:space:]')"
if [ "$PDB_STATUS" != "READWRITE" ]; then
    log "Opening PDB $ORACLE_PDB"
    run_sys_sql "ALTER PLUGGABLE DATABASE $ORACLE_PDB OPEN;"
fi

if [ "$BUILD_SCHEMA" = "true" ]; then
    log "Dropping existing Swingbench schema if present"
    run_sys_sql "
ALTER SESSION SET CONTAINER = $ORACLE_PDB;
BEGIN
    EXECUTE IMMEDIATE 'DROP USER $SWINGBENCH_SCHEMA CASCADE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1918 THEN RAISE; END IF;
END;
/
" >/dev/null

    log "Creating Swingbench SOE schema"
    "$SWINGBENCH_HOME/bin/oewizard" \
        -cl \
        -create \
        -cs "$CONNECT_STRING" \
        -u "$SWINGBENCH_SCHEMA" \
        -p "$SWINGBENCH_PASSWORD" \
        -scale "$SWINGBENCH_SCALE" \
        -tc "$SWINGBENCH_BUILD_THREADS" \
        -dba "sys as sysdba" \
        -dbap "$ORACLE_PWD" \
        -ts USERS >>"$LOG_FILE" 2>&1
fi

log "Running charbench workload"
"$SWINGBENCH_HOME/bin/charbench" \
    -c "$CONFIG_FILE" \
    -u "$SWINGBENCH_SCHEMA" \
    -p "$SWINGBENCH_PASSWORD" \
    -cs "$CONNECT_STRING" \
    -uc "$SWINGBENCH_USERS" \
    -min 0 \
    -max 0 \
    -intermin 0 \
    -intermax 0 \
    -v users,tpm,tps,errs,vresp \
    -nc \
    -r "$RESULTS_XML" \
    -rt "$RUNTIME_TOKEN" >>"$LOG_FILE" 2>&1

if [ -x "$SWINGBENCH_HOME/bin/results2txt" ] && [ -f "$RESULTS_XML" ]; then
    log "Rendering text summary from Swingbench XML results"
    "$SWINGBENCH_HOME/bin/results2txt" -f "$RESULTS_XML" >"$RESULTS_TXT" 2>>"$LOG_FILE" || true
fi

log "Exporting latest BENCHMARK_RESULTS row from database"
sqlplus -S "$SWINGBENCH_SCHEMA/$SWINGBENCH_PASSWORD@localhost:1521/$ORACLE_PDB" <<SQL >"$RESULTS_DB_JSON"
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LONG 1000000
SET LONGCHUNKSIZE 1000000
SET LINESIZE 32767
SET TRIMSPOOL ON
SELECT results_json
FROM benchmark_results
ORDER BY recording_time DESC
FETCH FIRST 1 ROW ONLY;
SQL

log "Swingbench workload completed"
log "Artifacts:"
log "  Log: $LOG_FILE"
log "  XML: $RESULTS_XML"
log "  TXT: $RESULTS_TXT"
log "  DB JSON: $RESULTS_DB_JSON"

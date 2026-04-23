#!/usr/bin/env bash
# install_oracle_db_free.sh — Automated Oracle Database Free 23ai installation
#
# This script is designed to run on a remote Oracle Linux host via SSH.
# It installs Oracle Database Free 23ai and creates a container database.
#
# Prerequisites:
# - Oracle Linux 8 or 9
# - Block volume storage mounted at /u02/oradata, /u03/redo, /u04/fra
# - Sufficient memory (minimum 2GB recommended)
#
# Usage: Run this script as root on the target host

set -euo pipefail

ORACLE_BASE="${ORACLE_BASE:-/opt/oracle}"
ORACLE_HOME="${ORACLE_HOME:-/opt/oracle/product/23ai/dbhomeFree}"
ORACLE_SID="${ORACLE_SID:-FREE}"
ORACLE_PDB="${ORACLE_PDB:-FREEPDB1}"
ORACLE_PWD="${ORACLE_PWD:-BenchmarkPwd123}"
ORACLE_CHARACTERSET="${ORACLE_CHARACTERSET:-AL32UTF8}"
DATA_DIR="${DATA_DIR:-/u02/oradata}"
REDO_DIR="${REDO_DIR:-/u03/redo}"
FRA_DIR="${FRA_DIR:-/u04/fra}"
LOG_FILE="${LOG_FILE:-/tmp/oracle-db-free-install.log}"

# Oracle Database Free download URLs
DB_FREE_RPM_EL8="https://download.oracle.com/otn-pub/otn_software/db-free/oracle-database-free-23ai-1.0-1.el8.x86_64.rpm"
DB_FREE_RPM_EL9="https://download.oracle.com/otn-pub/otn_software/db-free/oracle-database-free-23ai-1.0-1.el9.x86_64.rpm"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting Oracle Database Free 23ai installation"

# Verify running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: This script must be run as root"
    exit 1
fi

# Determine OS version
OS_VERSION=$(grep -oP '(?<=VERSION_ID=")[0-9]+' /etc/os-release || echo "8")
log "Detected OS version: $OS_VERSION"

# Verify mount points exist
for mp in "$DATA_DIR" "$REDO_DIR" "$FRA_DIR"; do
    if ! mountpoint -q "$mp" 2>/dev/null; then
        log "WARNING: $mp is not a mount point, checking if directory exists..."
        if [ ! -d "$mp" ]; then
            log "ERROR: $mp does not exist"
            exit 1
        fi
    fi
done

log "Storage mount points verified"

# Install Oracle Database preinstall package
log "Installing Oracle Database preinstall package..."
if ! rpm -q oracle-database-preinstall-23ai >/dev/null 2>&1; then
    dnf install -y oracle-database-preinstall-23ai >> "$LOG_FILE" 2>&1
    log "Preinstall package installed"
else
    log "Preinstall package already installed"
fi

# Install Oracle Database Free (download from Oracle if not in repos)
log "Installing Oracle Database Free 23ai..."
if ! rpm -q oracle-database-free-23ai >/dev/null 2>&1; then
    # Oracle Database Free is not in standard repos, download directly
    if [ "$OS_VERSION" = "9" ]; then
        DB_FREE_URL="$DB_FREE_RPM_EL9"
    else
        DB_FREE_URL="$DB_FREE_RPM_EL8"
    fi

    log "Downloading Oracle Database Free 23ai from Oracle..."
    RPM_FILE="/tmp/oracle-database-free-23ai.rpm"

    # Download with curl (follows redirects)
    if ! curl -L -o "$RPM_FILE" "$DB_FREE_URL" >> "$LOG_FILE" 2>&1; then
        log "ERROR: Failed to download Oracle Database Free RPM"
        exit 1
    fi

    log "Installing downloaded RPM..."
    dnf install -y "$RPM_FILE" >> "$LOG_FILE" 2>&1
    rm -f "$RPM_FILE"
    log "Oracle Database Free 23ai installed"
else
    log "Oracle Database Free 23ai already installed"
fi

# Verify Oracle Home exists
if [ ! -d "$ORACLE_HOME" ]; then
    log "ERROR: Oracle Home not found at $ORACLE_HOME"
    exit 1
fi

log "Oracle Home verified: $ORACLE_HOME"

# Set directory ownership for oracle user
log "Setting directory ownership..."
for mp in "$DATA_DIR" "$REDO_DIR" "$FRA_DIR"; do
    chown -R oracle:oinstall "$mp"
    chmod 755 "$mp"
done

# Create Oracle environment file
log "Creating Oracle environment file..."
cat > /home/oracle/.oracle_env <<EOF
export ORACLE_BASE=$ORACLE_BASE
export ORACLE_HOME=$ORACLE_HOME
export ORACLE_SID=$ORACLE_SID
export PATH=\$ORACLE_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
export TNS_ADMIN=\$ORACLE_HOME/network/admin
EOF
chown oracle:oinstall /home/oracle/.oracle_env

# Add to oracle user's profile if not already there
if ! grep -q '.oracle_env' /home/oracle/.bashrc 2>/dev/null; then
    echo 'source ~/.oracle_env' >> /home/oracle/.bashrc
fi

# Check if database already exists
if [ -f "$ORACLE_HOME/dbs/spfile${ORACLE_SID}.ora" ] || [ -f "$ORACLE_HOME/dbs/init${ORACLE_SID}.ora" ]; then
    log "Database instance $ORACLE_SID already exists"

    # Try to start if not running
    su - oracle -c "source ~/.oracle_env && sqlplus -S / as sysdba <<SQL
startup;
alter pluggable database all open;
exit;
SQL" >> "$LOG_FILE" 2>&1 || true

    log "Existing database startup attempted"
else
    # Create response file for silent database creation
    log "Creating database response file..."
    RESPONSE_FILE="/tmp/dbca_free.rsp"

    cat > "$RESPONSE_FILE" <<EOF
responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v23.0.0
gdbName=$ORACLE_SID
sid=$ORACLE_SID
databaseConfigType=SI
createAsContainerDatabase=true
numberOfPDBs=1
pdbName=$ORACLE_PDB
pdbAdminPassword=$ORACLE_PWD
templateName=FREE_Database
sysPassword=$ORACLE_PWD
systemPassword=$ORACLE_PWD
emConfiguration=NONE
datafileDestination=$DATA_DIR
recoveryAreaDestination=$FRA_DIR
recoveryAreaSize=10240
storageType=FS
characterSet=$ORACLE_CHARACTERSET
nationalCharacterSet=AL16UTF16
listeners=LISTENER
memoryPercentage=40
automaticMemoryManagement=false
totalMemory=1536
databaseType=MULTIPURPOSE
EOF

    chown oracle:oinstall "$RESPONSE_FILE"

    # Create the database using DBCA
    log "Creating database (this may take several minutes)..."

    # Configure and run database creation script
    # Oracle Database Free uses /etc/init.d/oracle-free-23ai configure
    # or direct DBCA invocation

    # First, try the configure script which is the recommended approach
    if [ -x "/etc/init.d/oracle-free-23ai" ]; then
        log "Using oracle-free-23ai configure script..."

        # Create a configure response for non-interactive setup
        # The configure script reads from stdin for password
        echo -e "${ORACLE_PWD}\n${ORACLE_PWD}" | /etc/init.d/oracle-free-23ai configure >> "$LOG_FILE" 2>&1 || {
            log "Configure script failed, attempting manual DBCA..."

            # Manual DBCA as fallback
            su - oracle -c "source ~/.oracle_env && dbca -silent -createDatabase \
                -templateName General_Purpose.dbc \
                -gdbname $ORACLE_SID \
                -sid $ORACLE_SID \
                -responseFile NO_VALUE \
                -characterSet $ORACLE_CHARACTERSET \
                -sysPassword $ORACLE_PWD \
                -systemPassword $ORACLE_PWD \
                -createAsContainerDatabase true \
                -numberOfPDBs 1 \
                -pdbName $ORACLE_PDB \
                -pdbAdminPassword $ORACLE_PWD \
                -databaseType MULTIPURPOSE \
                -memoryPercentage 30 \
                -storageType FS \
                -datafileDestination $DATA_DIR \
                -recoveryAreaDestination $FRA_DIR \
                -recoveryAreaSize 10240 \
                -emConfiguration NONE" >> "$LOG_FILE" 2>&1
        }
    else
        log "Configure script not found, using DBCA directly..."
        su - oracle -c "source ~/.oracle_env && dbca -silent -createDatabase \
            -templateName General_Purpose.dbc \
            -gdbname $ORACLE_SID \
            -sid $ORACLE_SID \
            -responseFile NO_VALUE \
            -characterSet $ORACLE_CHARACTERSET \
            -sysPassword $ORACLE_PWD \
            -systemPassword $ORACLE_PWD \
            -createAsContainerDatabase true \
            -numberOfPDBs 1 \
            -pdbName $ORACLE_PDB \
            -pdbAdminPassword $ORACLE_PWD \
            -databaseType MULTIPURPOSE \
            -memoryPercentage 30 \
            -storageType FS \
            -datafileDestination $DATA_DIR \
            -recoveryAreaDestination $FRA_DIR \
            -recoveryAreaSize 10240 \
            -emConfiguration NONE" >> "$LOG_FILE" 2>&1
    fi

    log "Database creation completed"
fi

# Configure listener if not running
log "Configuring listener..."
su - oracle -c "source ~/.oracle_env && lsnrctl status" >> "$LOG_FILE" 2>&1 || {
    log "Starting listener..."
    su - oracle -c "source ~/.oracle_env && lsnrctl start" >> "$LOG_FILE" 2>&1 || true
}

# Verify database status
log "Verifying database status..."
DB_STATUS=$(su - oracle -c "source ~/.oracle_env && sqlplus -S / as sysdba <<SQL
set heading off
set feedback off
select status from v\\\$instance;
exit;
SQL" 2>/dev/null | tr -d '[:space:]')

if [ "$DB_STATUS" = "OPEN" ]; then
    log "SUCCESS: Database instance $ORACLE_SID is OPEN"
else
    log "WARNING: Database status is '$DB_STATUS', attempting startup..."
    su - oracle -c "source ~/.oracle_env && sqlplus -S / as sysdba <<SQL
startup;
exit;
SQL" >> "$LOG_FILE" 2>&1 || true
fi

# Verify PDB status
log "Verifying PDB status..."
PDB_STATUS=$(su - oracle -c "source ~/.oracle_env && sqlplus -S / as sysdba <<SQL
set heading off
set feedback off
select open_mode from v\\\$pdbs where name = upper('$ORACLE_PDB');
exit;
SQL" 2>/dev/null | tr -d '[:space:]')

if [ "$PDB_STATUS" = "READWRITE" ]; then
    log "SUCCESS: PDB $ORACLE_PDB is open READ WRITE"
else
    log "WARNING: PDB status is '$PDB_STATUS', attempting to open..."
    su - oracle -c "source ~/.oracle_env && sqlplus -S / as sysdba <<SQL
alter pluggable database $ORACLE_PDB open;
alter pluggable database $ORACLE_PDB save state;
exit;
SQL" >> "$LOG_FILE" 2>&1 || true
fi

# Final status report
log "=== Oracle Database Free 23ai Installation Summary ==="
log "ORACLE_HOME: $ORACLE_HOME"
log "ORACLE_SID: $ORACLE_SID"
log "ORACLE_PDB: $ORACLE_PDB"
log "DATA_DIR: $DATA_DIR"
log "REDO_DIR: $REDO_DIR"
log "FRA_DIR: $FRA_DIR"

su - oracle -c "source ~/.oracle_env && sqlplus -S / as sysdba <<SQL
set linesize 200
col name format a20
col open_mode format a15

prompt
prompt === Instance Status ===
select instance_name, status, database_status from v\\\$instance;

prompt
prompt === PDB Status ===
select name, open_mode from v\\\$pdbs;

prompt
prompt === Datafile Locations ===
select name from v\\\$datafile where rownum <= 5;

prompt
prompt === Redo Log Locations ===
select member from v\\\$logfile where rownum <= 3;

exit;
SQL" 2>&1 | tee -a "$LOG_FILE"

log "Installation complete"

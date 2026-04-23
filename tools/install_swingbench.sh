#!/usr/bin/env bash
# install_swingbench.sh — install Swingbench on an Oracle benchmark host
#
# Swingbench is the standard Oracle Database Free load generator for Sprint 15.

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/swingbench}"
DOWNLOAD_URL="${DOWNLOAD_URL:-https://github.com/domgiles/swingbench-public/releases/download/production/swingbenchlatest.zip}"
WORK_DIR="${WORK_DIR:-/tmp/swingbench-install}"
LOG_FILE="${LOG_FILE:-/tmp/install-swingbench.log}"
INSTALL_OWNER="${INSTALL_OWNER:-oracle:oinstall}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || {
        log "ERROR: required command not found: $cmd"
        exit 1
    }
}

install_prereqs() {
    if [ "$(id -u)" -eq 0 ]; then
        dnf install -y curl unzip java-17-openjdk-headless >>"$LOG_FILE" 2>&1
    fi
}

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

log "Installing Swingbench into $INSTALL_DIR"
install_prereqs
require_command curl
require_command unzip
require_command java

rm -rf "$WORK_DIR" "$INSTALL_DIR"
mkdir -p "$WORK_DIR" "$(dirname "$INSTALL_DIR")"

ZIP_FILE="$WORK_DIR/swingbench.zip"
curl -fL "$DOWNLOAD_URL" -o "$ZIP_FILE" >>"$LOG_FILE" 2>&1
unzip -q "$ZIP_FILE" -d "$WORK_DIR"

EXTRACTED_DIR="$(find "$WORK_DIR" -mindepth 1 -maxdepth 2 -type d -name swingbench | head -n 1)"
[ -n "$EXTRACTED_DIR" ] || {
    log "ERROR: failed to locate extracted swingbench directory"
    exit 1
}

mv "$EXTRACTED_DIR" "$INSTALL_DIR"

[ -x "$INSTALL_DIR/bin/charbench" ] || {
    log "ERROR: Swingbench install is incomplete: missing $INSTALL_DIR/bin/charbench"
    exit 1
}

if [ "$(id -u)" -eq 0 ]; then
    chown -R "$INSTALL_OWNER" "$INSTALL_DIR"
fi

log "Swingbench installed successfully"
log "Swingbench home: $INSTALL_DIR"

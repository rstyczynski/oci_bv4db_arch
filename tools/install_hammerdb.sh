#!/usr/bin/env bash
# install_hammerdb.sh — install HammerDB as the documented Sprint 15 fallback

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/hammerdb}"
WORK_DIR="${WORK_DIR:-/tmp/hammerdb-install}"
LOG_FILE="${LOG_FILE:-/tmp/install-hammerdb.log}"
INSTALL_OWNER="${INSTALL_OWNER:-oracle:oinstall}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

os_major() {
    grep -oP '(?<=VERSION_ID=")[0-9]+' /etc/os-release 2>/dev/null || echo "8"
}

select_url() {
    case "$(os_major)" in
        9) echo "https://github.com/TPC-Council/HammerDB/releases/download/v5.0/HammerDB-5.0-Prod-Lin-RHEL9.tar.gz" ;;
        *) echo "https://github.com/TPC-Council/HammerDB/releases/download/v5.0/HammerDB-5.0-Prod-Lin-RHEL8.tar.gz" ;;
    esac
}

if [ "$(id -u)" -eq 0 ]; then
    dnf install -y curl tar >>"$LOG_FILE" 2>&1
fi

command -v curl >/dev/null 2>&1 || { log "ERROR: curl not found"; exit 1; }
command -v tar >/dev/null 2>&1 || { log "ERROR: tar not found"; exit 1; }

URL="${DOWNLOAD_URL:-$(select_url)}"
ARCHIVE="$WORK_DIR/hammerdb.tar.gz"

log "Installing HammerDB fallback into $INSTALL_DIR"
rm -rf "$WORK_DIR" "$INSTALL_DIR"
mkdir -p "$WORK_DIR" "$(dirname "$INSTALL_DIR")"

curl -fL "$URL" -o "$ARCHIVE" >>"$LOG_FILE" 2>&1
tar -xzf "$ARCHIVE" -C "$WORK_DIR"

EXTRACTED_DIR="$(find "$WORK_DIR" -mindepth 1 -maxdepth 2 -type d \( -iname 'HammerDB*' -o -iname 'hammerdb*' \) | head -n 1)"
[ -n "$EXTRACTED_DIR" ] || { log "ERROR: failed to locate extracted HammerDB directory"; exit 1; }

mv "$EXTRACTED_DIR" "$INSTALL_DIR"

if [ "$(id -u)" -eq 0 ]; then
    chown -R "$INSTALL_OWNER" "$INSTALL_DIR"
fi

log "HammerDB fallback installed successfully"
log "HammerDB home: $INSTALL_DIR"

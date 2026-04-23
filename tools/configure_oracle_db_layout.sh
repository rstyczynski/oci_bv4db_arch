#!/usr/bin/env bash
# configure_oracle_db_layout.sh — Configure Oracle Database storage layout on OCI block volumes
#
# This script prepares the storage layout for Oracle Database Free on OCI block volumes.
# It supports both single-volume (partitioned) and multi-volume configurations.
#
# Prerequisites:
# - Block volume(s) attached and visible to the guest
# - iSCSI/multipath configured for attached volumes
#
# Usage: Run this script as root on the target host with appropriate environment variables

set -euo pipefail

STORAGE_LAYOUT_MODE="${STORAGE_LAYOUT_MODE:-single_uhp}"
LOG_FILE="${LOG_FILE:-/tmp/oracle-storage-layout.log}"

# Single volume configuration
SINGLE_DEV="${SINGLE_DEV:-}"

# Multi-volume configuration
DATA1_DEV="${DATA1_DEV:-}"
DATA2_DEV="${DATA2_DEV:-}"
REDO1_DEV="${REDO1_DEV:-}"
REDO2_DEV="${REDO2_DEV:-}"
FRA_DEV="${FRA_DEV:-}"

# Mount points
DATA_MOUNT="/u02/oradata"
REDO_MOUNT="/u03/redo"
FRA_MOUNT="/u04/fra"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting Oracle Database storage layout configuration"
log "Mode: $STORAGE_LAYOUT_MODE"

# Verify running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: This script must be run as root"
    exit 1
fi

# Install required packages
log "Installing required packages..."
dnf install -y lvm2 parted >/dev/null 2>&1 || true

configure_single_volume_layout() {
    local base_dev="$1"

    log "Configuring single-volume layout on $base_dev"

    if [ ! -b "$base_dev" ]; then
        log "ERROR: Device $base_dev does not exist"
        exit 1
    fi

    # Check if already configured
    if mountpoint -q "$DATA_MOUNT" && mountpoint -q "$REDO_MOUNT" && mountpoint -q "$FRA_MOUNT"; then
        log "Storage layout already configured"
        return 0
    fi

    # Wipe and partition the device
    log "Partitioning device $base_dev..."
    wipefs -af "$base_dev" >/dev/null 2>&1 || true

    # Create GPT partition table with Oracle-style layout
    # DATA: 200GB (partitions 1 and 2 for striping)
    # REDO: 50GB (partitions 3 and 4 for striping)
    # FRA: remainder
    if command -v sfdisk >/dev/null 2>&1; then
        cat <<PARTS | sfdisk --force --no-reread --wipe always --label gpt "$base_dev" >/dev/null
,200G,L
,200G,L
,50G,L
,50G,L
,,L
PARTS
    else
        parted -s "$base_dev" mklabel gpt \
            mkpart primary 1MiB 200GiB \
            mkpart primary 200GiB 400GiB \
            mkpart primary 400GiB 450GiB \
            mkpart primary 450GiB 500GiB \
            mkpart primary 500GiB 100% >/dev/null
    fi

    partprobe "$base_dev" >/dev/null 2>&1 || true
    udevadm settle

    # Wait for partitions to appear
    log "Waiting for partitions..."
    for _ in $(seq 1 20); do
        mapfile -t PARTS < <(lsblk -lnpo NAME,TYPE "$base_dev" | awk '$2=="part"{print $1}')
        if [ "${#PARTS[@]}" -ge 5 ]; then
            break
        fi
        kpartx -av "$base_dev" >/dev/null 2>&1 || true
        sleep 3
        udevadm settle
    done

    if [ "${#PARTS[@]}" -lt 5 ]; then
        log "ERROR: Expected 5 partitions on $base_dev, found ${#PARTS[@]}"
        exit 1
    fi

    DATA1="${PARTS[0]}"
    DATA2="${PARTS[1]}"
    REDO1="${PARTS[2]}"
    REDO2="${PARTS[3]}"
    FRA="${PARTS[4]}"

    log "Partitions: DATA1=$DATA1, DATA2=$DATA2, REDO1=$REDO1, REDO2=$REDO2, FRA=$FRA"

    # Create LVM for DATA (striped)
    log "Creating DATA volume group..."
    pvcreate -ff -y "$DATA1" "$DATA2"
    vgcreate vg_data "$DATA1" "$DATA2"
    lvcreate -l 100%FREE -n lv_oradata -i 2 -I 256K vg_data
    mkfs.ext4 -F -E nodiscard /dev/vg_data/lv_oradata

    # Create LVM for REDO (striped)
    log "Creating REDO volume group..."
    pvcreate -ff -y "$REDO1" "$REDO2"
    vgcreate vg_redo "$REDO1" "$REDO2"
    lvcreate -l 100%FREE -n lv_redo -i 2 -I 256K vg_redo
    mkfs.ext4 -F -E nodiscard /dev/vg_redo/lv_redo

    # Create filesystem for FRA (direct mount)
    log "Creating FRA filesystem..."
    mkfs.ext4 -F -E nodiscard "$FRA"

    # Create mount points and mount
    log "Creating mount points and mounting..."
    mkdir -p "$DATA_MOUNT" "$REDO_MOUNT" "$FRA_MOUNT"
    mount /dev/vg_data/lv_oradata "$DATA_MOUNT"
    mount /dev/vg_redo/lv_redo "$REDO_MOUNT"
    mount "$FRA" "$FRA_MOUNT"

    # Set ownership for oracle user
    chown oracle:oinstall "$DATA_MOUNT" "$REDO_MOUNT" "$FRA_MOUNT" 2>/dev/null || {
        # oracle user may not exist yet, set to opc temporarily
        chown opc:opc "$DATA_MOUNT" "$REDO_MOUNT" "$FRA_MOUNT"
    }
    chmod 755 "$DATA_MOUNT" "$REDO_MOUNT" "$FRA_MOUNT"

    log "Single-volume layout configuration complete"
}

configure_multi_volume_layout() {
    log "Configuring multi-volume layout"

    # Verify all devices exist
    for dev_var in DATA1_DEV DATA2_DEV REDO1_DEV REDO2_DEV FRA_DEV; do
        dev="${!dev_var}"
        if [ -z "$dev" ]; then
            log "ERROR: $dev_var is not set"
            exit 1
        fi
        if [ ! -b "$dev" ]; then
            log "ERROR: Device $dev does not exist"
            exit 1
        fi
    done

    # Check if already configured
    if mountpoint -q "$DATA_MOUNT" && mountpoint -q "$REDO_MOUNT" && mountpoint -q "$FRA_MOUNT"; then
        log "Storage layout already configured"
        return 0
    fi

    # Create LVM for DATA (striped across two volumes)
    log "Creating DATA volume group..."
    if ! vgs vg_data >/dev/null 2>&1; then
        pvcreate -ff -y "$DATA1_DEV" "$DATA2_DEV"
        vgcreate vg_data "$DATA1_DEV" "$DATA2_DEV"
        lvcreate -l 100%FREE -n lv_oradata -i 2 -I 256K vg_data
        mkfs.ext4 -F -E nodiscard /dev/vg_data/lv_oradata
    fi

    # Create LVM for REDO (striped across two volumes)
    log "Creating REDO volume group..."
    if ! vgs vg_redo >/dev/null 2>&1; then
        pvcreate -ff -y "$REDO1_DEV" "$REDO2_DEV"
        vgcreate vg_redo "$REDO1_DEV" "$REDO2_DEV"
        lvcreate -l 100%FREE -n lv_redo -i 2 -I 256K vg_redo
        mkfs.ext4 -F -E nodiscard /dev/vg_redo/lv_redo
    fi

    # Create filesystem for FRA (direct mount)
    log "Creating FRA filesystem..."
    if ! blkid "$FRA_DEV" >/dev/null 2>&1; then
        mkfs.ext4 -F -E nodiscard "$FRA_DEV"
    fi

    # Create mount points and mount
    log "Creating mount points and mounting..."
    mkdir -p "$DATA_MOUNT" "$REDO_MOUNT" "$FRA_MOUNT"
    mountpoint -q "$DATA_MOUNT" || mount /dev/vg_data/lv_oradata "$DATA_MOUNT"
    mountpoint -q "$REDO_MOUNT" || mount /dev/vg_redo/lv_redo "$REDO_MOUNT"
    mountpoint -q "$FRA_MOUNT" || mount "$FRA_DEV" "$FRA_MOUNT"

    # Set ownership for oracle user
    chown oracle:oinstall "$DATA_MOUNT" "$REDO_MOUNT" "$FRA_MOUNT" 2>/dev/null || {
        chown opc:opc "$DATA_MOUNT" "$REDO_MOUNT" "$FRA_MOUNT"
    }
    chmod 755 "$DATA_MOUNT" "$REDO_MOUNT" "$FRA_MOUNT"

    log "Multi-volume layout configuration complete"
}

# Execute appropriate layout configuration
case "$STORAGE_LAYOUT_MODE" in
    single_uhp|single)
        if [ -z "$SINGLE_DEV" ]; then
            log "ERROR: SINGLE_DEV must be set for single-volume layout"
            exit 1
        fi
        configure_single_volume_layout "$SINGLE_DEV"
        ;;
    multi_volume|multi)
        configure_multi_volume_layout
        ;;
    *)
        log "ERROR: Unknown storage layout mode: $STORAGE_LAYOUT_MODE"
        exit 1
        ;;
esac

# Verify configuration
log "=== Storage Layout Summary ==="
log "Mount points:"
df -h "$DATA_MOUNT" "$REDO_MOUNT" "$FRA_MOUNT" 2>&1 | tee -a "$LOG_FILE"

log ""
log "Block device layout:"
lsblk 2>&1 | tee -a "$LOG_FILE"

log ""
log "LVM status:"
vgs 2>&1 | tee -a "$LOG_FILE" || true
lvs 2>&1 | tee -a "$LOG_FILE" || true

log "Storage layout configuration complete"

set -euo pipefail

MNT=/mnt/s27clean

cleanup_baseline_iscsi() {
  set +e
  sudo umount "$MNT" 2>&1 || true
  disconnect_iscsi_attachment "$IQN" "$IP" "$PORT"
}
trap cleanup_baseline_iscsi EXIT

connect_iscsi_attachment "$IQN" "$IP" "$PORT" "$CHAP_USER" "$CHAP_SECRET"
wait_for_any_baseline_device "$IQN" "tc4_baseline"
DEV="$(cat /tmp/sprint27-baseline-device)"
echo "tc4_baseline_device=$DEV"

sudo mkdir -p "$MNT"
sudo mkfs.ext4 -F -q "$DEV"
sudo blkid "$DEV" 2>&1 || true
sudo mount "$DEV" "$MNT"
sudo chown opc:opc "$MNT"
dd if=/dev/urandom of="$MNT/stable.bin" bs=1M count=256 status=none
sha256sum "$MNT/stable.bin" | tee "$MNT/stable.sha256"
sync
sha256sum -c "$MNT/stable.sha256"
sudo umount "$MNT"
disconnect_iscsi_attachment "$IQN" "$IP" "$PORT"
trap - EXIT
echo "linux_clean_release=complete"

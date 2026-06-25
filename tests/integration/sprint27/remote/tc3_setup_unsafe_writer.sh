set -euo pipefail

MNT=/mnt/s27unsafe
PID_FILE=/tmp/s27unsafe-writer.pid
STDOUT_FILE=/tmp/s27unsafe-writer.stdout
STDERR_FILE=/tmp/s27unsafe-writer.stderr
setup_complete=false

cleanup_on_failure() {
  set +e
  if [ "$setup_complete" != "true" ]; then
    sudo umount "$MNT" 2>&1 || true
    disconnect_iscsi_attachment "$IQN" "$IP" "$PORT"
  fi
}
trap cleanup_on_failure EXIT

connect_iscsi_attachment "$IQN" "$IP" "$PORT" "$CHAP_USER" "$CHAP_SECRET"
wait_for_any_baseline_device "$IQN" "tc3_baseline"
DEV="$(cat /tmp/sprint27-baseline-device)"
echo "tc3_baseline_device=$DEV"

sudo mkdir -p "$MNT"
sudo mkfs.ext4 -F -q "$DEV"
sudo blkid "$DEV" 2>&1 || true
sudo mount "$DEV" "$MNT"
sudo chown opc:opc "$MNT"
dd if=/dev/urandom of="$MNT/stable.bin" bs=1M count=128 status=none
sha256sum "$MNT/stable.bin" | tee "$MNT/stable.sha256"
( i=0; while true; do dd if=/dev/urandom of="$MNT/live-writer.bin" bs=1M count=16 conv=notrunc oflag=direct status=none; i=$((i+1)); echo "$i" > "$MNT/writer.count"; sleep 1; done ) > "$STDOUT_FILE" 2> "$STDERR_FILE" &
echo $! | tee "$PID_FILE"
sync
echo "linux_unsafe_setup=mounted_writer_active"
echo "writer_pid_file=$PID_FILE"
echo "writer_stdout_file=$STDOUT_FILE"
echo "writer_stderr_file=$STDERR_FILE"
findmnt "$MNT"
setup_complete=true
trap - EXIT

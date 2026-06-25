set +e

MNT=/mnt/s27unsafe
PID_FILE=/tmp/s27unsafe-writer.pid
STDOUT_FILE=/tmp/s27unsafe-writer.stdout
STDERR_FILE=/tmp/s27unsafe-writer.stderr

run_bounded() {
  local seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  else
    "$@"
  fi
}

echo "--- TC3 post-detach Linux process status ---"
if [ -f "$PID_FILE" ]; then
  PID="$(cat "$PID_FILE" 2>/dev/null)"
  echo "writer_pid=$PID"
  ps -fp "$PID" || true
  sudo kill "$PID" 2>/dev/null || true
else
  echo "writer_pid_file_missing=$PID_FILE"
fi

echo "--- TC3 post-detach kernel log tail ---"
dmesg | tail -80 || true

echo "--- TC3 post-detach mount state ---"
run_bounded 10s findmnt "$MNT" || true

echo "--- TC3 post-detach writer stderr from safe path ---"
cat "$STDERR_FILE" 2>/dev/null || true

echo "tc3_stale_mount_direct_reads=skipped"
echo "tc3_stale_mount_reason=after force-detach, stat/read/checksum operations under the mounted detached filesystem can block indefinitely; this is the unsafe behavior being isolated"

echo "--- TC3 post-detach lazy unmount attempt ---"
run_bounded 15s sudo umount -l "$MNT" 2>&1 || true

disconnect_iscsi_attachment "$IQN" "$IP" "$PORT"
echo "linux_unsafe_post_detach_collected=true"

connect_iscsi_attachment() {
  iqn="$1"
  ip="$2"
  port="$3"
  chap_user="${4:-}"
  chap_secret="${5:-}"
  echo "iscsi_connect_start=true iqn=$iqn portal=$ip:$port"
  sudo iscsiadm -m node -o new -T "$iqn" -p "$ip:$port" 2>&1 || true
  sudo iscsiadm -m node -T "$iqn" -p "$ip:$port" -o update -n node.startup -v manual 2>&1 || true
  if [ -n "$chap_user" ] && [ -n "$chap_secret" ]; then
    sudo iscsiadm -m node -T "$iqn" -p "$ip:$port" -o update -n node.session.auth.authmethod -v CHAP
    sudo iscsiadm -m node -T "$iqn" -p "$ip:$port" -o update -n node.session.auth.username -v "$chap_user"
    sudo iscsiadm -m node -T "$iqn" -p "$ip:$port" -o update -n node.session.auth.password -v "$chap_secret"
  fi
  sudo iscsiadm -m node -T "$iqn" -p "$ip:$port" -l
  echo "iscsi_connect_complete=true"
  sudo iscsiadm -m session 2>&1 || true
}

disconnect_iscsi_attachment() {
  iqn="$1"
  ip="$2"
  port="$3"
  echo "iscsi_disconnect_start=true iqn=$iqn portal=$ip:$port"
  sudo iscsiadm -m node -T "$iqn" -p "$ip:$port" -u 2>&1 || true
  sudo iscsiadm -m node -o delete -T "$iqn" -p "$ip:$port" 2>&1 || true
  sudo iscsiadm -m session 2>&1 || true
  echo "iscsi_disconnect_complete=true"
}

discover_baseline_device() {
  iqn="$1"
  consistent_dev="${CONSISTENT_DEV:-/dev/oracleoci/oraclevdb}"
  if [ -b "$consistent_dev" ]; then
    echo "$consistent_dev"
    return 0
  fi
  for dev in /dev/disk/by-path/*"$iqn"*; do
    if [ -e "$dev" ]; then
      real="$(readlink -f "$dev" 2>/dev/null || true)"
      if [ -n "$real" ] && [ -b "$real" ]; then
        echo "$real"
        return 0
      fi
    fi
  done
  lsblk -dnpo PATH,TYPE,MODEL 2>/dev/null \
    | awk '$2 == "disk" && $3 == "BlockVolume" && $1 != "/dev/sda" { print $1; exit }'
}

wait_for_baseline_consistent_path() {
  label="$1"
  consistent_dev="${CONSISTENT_DEV:-/dev/oracleoci/oraclevdb}"
  max_polls="${SPRINT27_BASELINE_CONSISTENT_PATH_POLLS:-4}"
  sleep_seconds="${SPRINT27_BASELINE_CONSISTENT_PATH_SLEEP_SECONDS:-15}"

  echo "${label}_consistent_path_wait_start=true path=$consistent_dev max_polls=$max_polls sleep_seconds=$sleep_seconds"
  for i in $(seq 1 "$max_polls"); do
    if [ -b "$consistent_dev" ]; then
      echo "${label}_consistent_path_ready=true path=$consistent_dev real=$(readlink -f "$consistent_dev" 2>/dev/null || true) poll=$i"
      ls -l "$consistent_dev" 2>&1 || true
      echo "--- ${label}: /dev/oracleoci links after consistent path wait ---"
      ls -l /dev/oracleoci 2>&1 || true
      echo "$consistent_dev" > /tmp/sprint27-baseline-device
      return 0
    fi
    echo "${label}_consistent_path_ready=false path=$consistent_dev poll=$i"
    if [ "$i" -lt "$max_polls" ]; then
      sleep "$sleep_seconds"
    fi
  done

  echo "${label}_consistent_path_fallback=true path=$consistent_dev reason=consistent_path_not_available_after_wait"
  echo "--- ${label}: /dev/oracleoci links before fallback discovery ---"
  ls -l /dev/oracleoci 2>&1 || true
  return 1
}

wait_for_any_baseline_device() {
  iqn="$1"
  label="$2"
  if wait_for_baseline_consistent_path "$label"; then
    return 0
  fi

  for i in $(seq 1 "${SPRINT27_DEVICE_WAIT_POLLS:-8}"); do
    dev="$(discover_baseline_device "$iqn" 2>/dev/null || true)"
    if [ -n "$dev" ] && [ -b "$dev" ]; then
      echo "${label}_device_ready=true path=$dev poll=$i"
      ls -l "$dev" 2>&1 || true
      echo "${label}_device_realpath=$(readlink -f "$dev" 2>/dev/null || true)"
      echo "--- ${label}: /dev/oracleoci links at baseline ---"
      ls -l /dev/oracleoci 2>&1 || true
      if [ -e /dev/oracleoci/oraclevdb ]; then
        echo "${label}_consistent_path_exists=true path=/dev/oracleoci/oraclevdb real=$(readlink -f /dev/oracleoci/oraclevdb 2>/dev/null || true)"
      else
        echo "${label}_consistent_path_exists=false path=/dev/oracleoci/oraclevdb"
      fi
      echo "$dev" > /tmp/sprint27-baseline-device
      return 0
    fi
    echo "${label}_device_ready=false path=DISCOVER_BY_ISCSI poll=$i"
    sleep "${SPRINT27_DEVICE_WAIT_SLEEP_SECONDS:-15}"
  done
  echo "${label}_device_missing_after_wait=true path=DISCOVER_BY_ISCSI"
  echo "--- ${label}: lsblk ---"
  lsblk -o NAME,PATH,TYPE,SIZE,MODEL,WWN,FSTYPE,UUID,MOUNTPOINT 2>&1 || true
  echo "--- ${label}: /dev/oracleoci ---"
  ls -l /dev/oracleoci 2>&1 || true
  echo "--- ${label}: /dev/disk/by-path ---"
  ls -l /dev/disk/by-path 2>&1 || true
  echo "--- ${label}: iscsi sessions ---"
  sudo iscsiadm -m session 2>&1 || true
  echo "--- ${label}: oracle cloud agent block plugin tail ---"
  sudo tail -120 /var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log 2>&1 || true
  return 1
}

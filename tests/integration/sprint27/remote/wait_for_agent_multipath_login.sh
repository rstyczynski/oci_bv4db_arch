set -u

CONSISTENT_DEV="${CONSISTENT_DEV:-/dev/oracleoci/oraclevdb}"
MAX_POLLS="${SPRINT27_AGENT_WAIT_POLLS:-8}"
SLEEP_SECONDS="${SPRINT27_AGENT_WAIT_SLEEP_SECONDS:-15}"

for i in $(seq 1 "$MAX_POLLS"); do
  echo "--- agent multipath wait poll=$i/$MAX_POLLS ---"
  echo "consistent_path_probe=$CONSISTENT_DEV"
  if [ -e "$CONSISTENT_DEV" ]; then
    echo "consistent_path_exists=true path=$CONSISTENT_DEV real=$(readlink -f "$CONSISTENT_DEV" 2>/dev/null || true)"
    ls -l "$CONSISTENT_DEV" 2>&1 || true
  else
    echo "consistent_path_exists=false path=$CONSISTENT_DEV"
  fi

  echo "--- agent multipath wait: oracleoci links ---"
  ls -l /dev/oracleoci 2>&1 || true
  echo "--- agent multipath wait: mapper links ---"
  ls -l /dev/mapper 2>&1 || true
  echo "--- agent multipath wait: iscsi sessions ---"
  sudo iscsiadm -m session 2>&1 || true
  echo "--- agent multipath wait: multipath -ll ---"
  sudo multipath -ll 2>&1 || true
  echo "--- agent multipath wait: multipathd paths ---"
  sudo multipathd show paths 2>&1 || true
  echo "--- agent multipath wait: oracle agent state ---"
  systemctl is-active oracle-cloud-agent 2>&1 || true
  systemctl is-active multipathd 2>&1 || true

  consistent_real=""
  if [ -e "$CONSISTENT_DEV" ]; then
    consistent_real="$(readlink -f "$CONSISTENT_DEV" 2>/dev/null || true)"
  fi

  matched_mapper=""
  for map in /dev/mapper/mpath*; do
    [ -e "$map" ] || continue
    map_real="$(readlink -f "$map" 2>/dev/null || true)"
    echo "mapper_path=$map real=$map_real"
    if [ -n "$consistent_real" ] && [ "$map_real" = "$consistent_real" ]; then
      matched_mapper="$map"
    fi
  done

  if [ -n "$matched_mapper" ]; then
    echo "agent_multipath_wait_result=PASS mapper=$matched_mapper"
    exit 0
  fi

  if [ "$i" -lt "$MAX_POLLS" ]; then
    sleep "$SLEEP_SECONDS"
  fi
done

echo "--- agent multipath wait: final plugin log tail ---"
sudo tail -300 /var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log 2>&1 || true
echo "agent_multipath_wait_result=FAIL"
exit 1

#!/usr/bin/env bash
# Sprint 20 (BV4DB-51): A/B load test with multipath vs single-path (fio preferred, dd fallback).

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="$REPO_DIR/progress/sprint_20"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="${NAME_PREFIX:-bv4db-s20-mpath-ab}"
export OCI_REGION="${OCI_REGION:-}"
export OCI_CLI_REGION="${OCI_CLI_REGION:-${OCI_REGION:-}}"

_on_err() {
  local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
  echo "  [FAIL] run_bv4db_fio_multipath_ab_sprint20.sh failed (exit $ec) at line $line: $cmd" >&2
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE — Sprint 1 shared infra is required" >&2; exit 1; }

mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"

source "$SCAFFOLD_DIR/do/oci_scaffold.sh"

ssh_opts=(-n -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes)
scp_opts=(-B -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes)

COMPARTMENT_OCID=$(jq -r '.compartment.ocid' "$INFRA_STATE")
SUBNET_OCID=$(jq -r '.subnet.ocid' "$INFRA_STATE")
PUBKEY_FILE="$SPRINT1_DIR/bv4db-key.pub"

_ssh() { ssh "${ssh_opts[@]}" "$@"; }
_scp() { scp "${scp_opts[@]}" "$@"; }

enable_block_volume_plugin() {
  local instance_id="$1"
  oci compute instance update \
    --instance-id "$instance_id" \
    --agent-config '{"areAllPluginsDisabled":false,"isManagementDisabled":false,"isMonitoringDisabled":false,"pluginsConfig":[{"name":"Block Volume Management","desiredState":"ENABLED"}]}' \
    --force >/dev/null
}

guest_login_targets() {
  local ssh_host="$1"
  local mode="$2"   # multipath|single
  local iqn="$3"
  local port="$4"
  local expected_path="$5"
  shift 5
  local -a targets=("$@")

  _ssh "$ssh_host" sudo bash -s -- "$mode" "$iqn" "$port" "$expected_path" "${targets[@]}" <<'EOF'
set -euo pipefail
MODE="$1"
IQN="$2"
PORT="$3"
DEVICE_PATH="$4"
shift 4
TARGETS=("$@")

systemctl enable --now iscsid >/dev/null

if [ "$MODE" = "multipath" ]; then
  mpathconf --enable --with_multipathd y >/dev/null
  systemctl enable --now multipathd >/dev/null
else
  systemctl disable --now multipathd >/dev/null 2>&1 || true
fi

if [ "$MODE" = "single" ]; then
  TARGETS=("${TARGETS[0]}")
fi

for host in "${TARGETS[@]}"; do
  iscsiadm -m node -o new -T "$IQN" -p "${host}:${PORT}" >/dev/null 2>&1 || true
  iscsiadm -m node -T "$IQN" -p "${host}:${PORT}" --op update -n node.startup -v automatic >/dev/null
  iscsiadm -m node -T "$IQN" -p "${host}:${PORT}" --login >/dev/null 2>&1 || true
done

udevadm settle

for _ in $(seq 1 24); do
  if [ -b "$DEVICE_PATH" ]; then
    exit 0
  fi
  sleep 5
done

echo "Expected device path not present after iSCSI login: $DEVICE_PATH" >&2
iscsiadm -m session || true
multipath -ll || true
ls -l /dev/oracleoci || true
exit 1
EOF
}

guest_prepare_fs() {
  local ssh_host="$1"
  local dev="$2"
  local mnt="$3"
  _ssh "$ssh_host" sudo bash -s -- "$dev" "$mnt" <<'EOF'
set -euo pipefail
DEV="$1"
MNT="$2"
mkdir -p "$MNT"
if ! blkid "$DEV" >/dev/null 2>&1; then
  mkfs.xfs -f "$DEV" >/dev/null
fi
mountpoint -q "$MNT" || mount "$DEV" "$MNT"
chmod 777 "$MNT"
EOF
}

guest_collect_diag() {
  local ssh_host="$1"
  local out_file="$2"
  _ssh "$ssh_host" sudo bash -s -- <<'EOF' >"$out_file"
set -euo pipefail
echo "=== date ==="; date -u; echo
echo "=== iscsiadm -m session ==="; iscsiadm -m session || true; echo
echo "=== systemctl status multipathd ==="; systemctl status multipathd --no-pager || true; echo
echo "=== multipath -ll ==="; multipath -ll || true; echo
echo "=== multipathd show paths ==="; multipathd show paths || true; echo
echo "=== multipathd show maps ==="; multipathd show maps || true; echo
echo "=== lsblk ==="; lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINTS || true; echo
EOF
}

guest_run_fio() {
  local ssh_host="$1"
  local mnt="$2"
  local out_json="$3"
  local runtime="${FIO_RUNTIME_SEC:-120}"
  _ssh "$ssh_host" sudo bash -s -- "$mnt" "$runtime" "$out_json" <<'EOF'
set -euo pipefail
MNT="$1"
RUNTIME="$2"
OUT="$3"
command -v fio >/dev/null 2>&1 || { echo "fio not found" >&2; exit 42; }
fio \
  --name=ab-4k \
  --rw=randrw \
  --rwmixread=70 \
  --bs=4k \
  --size=16G \
  --time_based=1 \
  --runtime="$RUNTIME" \
  --numjobs=4 \
  --iodepth=32 \
  --ioengine=libaio \
  --direct=1 \
  --group_reporting \
  --output="$OUT" \
  --output-format=json \
  --filename="$MNT/testfile"
EOF
}

guest_run_dd_fallback() {
  local ssh_host="$1"
  local mnt="$2"
  local out_json="$3"
  local out_txt="$4"
  local jobs="${DD_JOBS:-4}"
  local size_gb="${DD_SIZE_GB:-16}"  # per worker
  local bs="${DD_BS:-16M}"
  _ssh "$ssh_host" sudo bash -s -- "$mnt" "$jobs" "$size_gb" "$bs" "$out_json" "$out_txt" <<'EOF'
set -euo pipefail
MNT="$1"
JOBS="$2"
SIZE_GB="$3"
BS="$4"
OUT_JSON="$5"
OUT_TXT="$6"

COUNT=$(( (SIZE_GB * 1024) / 16 ))

{
  echo "=== dd fallback workload ==="
  echo "date: $(date -u)"
  echo "mnt: $MNT"
  echo "jobs: $JOBS"
  echo "size_gb: $SIZE_GB"
  echo "bs: $BS"
  echo "count: $COUNT"
  echo

  echo "== write =="
  for i in $(seq 1 "$JOBS"); do
    (
      f="$MNT/ddfile_${i}"
      dd if=/dev/zero of="$f" bs="$BS" count="$COUNT" oflag=direct conv=fdatasync 2>&1 | sed "s/^/[job $i] /"
    ) &
  done
  wait || true
  echo

  echo "== read =="
  for i in $(seq 1 "$JOBS"); do
    (
      f="$MNT/ddfile_${i}"
      dd if="$f" of=/dev/null bs="$BS" iflag=direct 2>&1 | sed "s/^/[job $i] /"
    ) &
  done
  wait || true
  echo
} >"$OUT_TXT"

extract_mbps_sum() {
  python3 - <<'PY' "$1" "$2"
import re,sys
path=sys.argv[1]
section=sys.argv[2]
s=open(path,'r',encoding='utf-8',errors='ignore').read()
pat=r"== %s ==\\n(.*?)\\n\\n"%re.escape(section)
m=re.search(pat,s,flags=re.S)
blob=m.group(1) if m else s
hits=re.findall(r",\\s*([0-9.]+)\\s*([kMG]B)/s", blob)
total=0.0
for v,u in hits:
    v=float(v)
    scale={"kB":1/1024,"MB":1.0,"GB":1024.0}.get(u,0.0)
    total += v*scale
print(f"{total:.2f}")
PY
}

W_MBPS="$(extract_mbps_sum "$OUT_TXT" "write")"
R_MBPS="$(extract_mbps_sum "$OUT_TXT" "read")"

python3 - <<'PY' "$OUT_JSON" "$R_MBPS" "$W_MBPS"
import json,sys
out=sys.argv[1]
r=float(sys.argv[2]); w=float(sys.argv[3])
payload={"generator":"dd","read_mbps":r,"write_mbps":w,"total_mbps":r+w}
with open(out,"w") as f: json.dump(payload,f,indent=2,sort_keys=True)
PY
EOF
}

extract_total_bw_mbps() {
  python3 - <<'PY' "$1"
import json, sys
p=sys.argv[1]
d=json.load(open(p,"r"))
if d.get("generator") == "dd":
  print(f"{float(d.get('total_mbps',0.0)):.2f}")
  raise SystemExit(0)
jobs=d.get("jobs") or []
rbw=sum(j.get("read",{}).get("bw",0) for j in jobs)   # KiB/s
wbw=sum(j.get("write",{}).get("bw",0) for j in jobs)
print(f"{(rbw+wbw)/1024:.2f}")
PY
}

main() {
  echo ""
  echo "=== Sprint 20: A/B multipath vs single-path ==="
  echo ""

  local ts; ts="$(date -u '+%Y%m%d_%H%M%S')"
  local state_json="$PROGRESS_DIR/state-bv4db-s20-mpath-ab_${ts}.json"
  local diag_mpath="$PROGRESS_DIR/diag_multipath_${ts}.txt"
  local diag_single="$PROGRESS_DIR/diag_singlepath_${ts}.txt"
  local result_mpath="$PROGRESS_DIR/fio_multipath_${ts}.json"
  local result_single="$PROGRESS_DIR/fio_singlepath_${ts}.json"
  local dd_mpath_txt="$PROGRESS_DIR/dd_multipath_${ts}.txt"
  local dd_single_txt="$PROGRESS_DIR/dd_singlepath_${ts}.txt"
  local summary_md="$PROGRESS_DIR/fio_compare_${ts}.md"

  export COMPUTE_SHAPE="${COMPUTE_SHAPE:-VM.Standard.E5.Flex}"
  export COMPUTE_OCPUS="${COMPUTE_OCPUS:-16}"
  export COMPUTE_MEMORY_GB="${COMPUTE_MEMORY_GB:-64}"
  export BLOCKVOLUME_SIZE_GB="${BLOCKVOLUME_SIZE_GB:-1500}"
  export BLOCKVOLUME_VPUS_PER_GB="${BLOCKVOLUME_VPUS_PER_GB:-120}"
  export ATTACHMENT_TYPE="${ATTACHMENT_TYPE:-iscsi}"

  ensure_compute.sh --compartment-ocid "$COMPARTMENT_OCID" --subnet-ocid "$SUBNET_OCID" --ssh-pubkey-file "$PUBKEY_FILE" --shape "$COMPUTE_SHAPE" --ocpus "$COMPUTE_OCPUS" --memory-gb "$COMPUTE_MEMORY_GB"
  ensure_blockvolume.sh --compartment-ocid "$COMPARTMENT_OCID" --size-gb "$BLOCKVOLUME_SIZE_GB" --vpus-per-gb "$BLOCKVOLUME_VPUS_PER_GB"
  ensure_blockvolume_attachment.sh --attachment-type "$ATTACHMENT_TYPE"

  local instance_id volume_attach_id public_ip
  instance_id=$(jq -r '.compute.ocid' state.json)
  volume_attach_id=$(jq -r '.blockvolume_attachment.ocid' state.json)
  public_ip=$(jq -r '.compute.public_ip' state.json)

  enable_block_volume_plugin "$instance_id"

  local attachment_json iqn port
  attachment_json=$(oci compute volume-attachment get --volume-attachment-id "$volume_attach_id")
  iqn=$(echo "$attachment_json" | jq -r '.data.iqn')
  port=$(echo "$attachment_json" | jq -r '.data.port')
  mapfile -t target_ips < <(echo "$attachment_json" | jq -r '([.data.ipv4] + [.data."multipath-devices"[]?.ipv4]) | unique[]')

  local ssh_host="opc@${public_ip}"
  local expected_path="/dev/oracleoci/oraclevdb"
  local mnt="/mnt/sprint20"
  local generator="fio"

  echo "  [A] multipath mode"
  guest_login_targets "$ssh_host" "multipath" "$iqn" "$port" "$expected_path" "${target_ips[@]}"
  guest_collect_diag "$ssh_host" "$diag_mpath"
  guest_prepare_fs "$ssh_host" "$expected_path" "$mnt"
  set +e
  guest_run_fio "$ssh_host" "$mnt" "/tmp/fio_multipath.json"
  ec=$?
  set -e
  if [ "$ec" -eq 0 ]; then
    _scp "$ssh_host:/tmp/fio_multipath.json" "$result_mpath"
  else
    generator="dd"
    guest_run_dd_fallback "$ssh_host" "$mnt" "/tmp/dd_multipath.json" "/tmp/dd_multipath.txt"
    _scp "$ssh_host:/tmp/dd_multipath.json" "$result_mpath"
    _scp "$ssh_host:/tmp/dd_multipath.txt" "$dd_mpath_txt"
  fi

  echo "  [B] single-path mode"
  guest_login_targets "$ssh_host" "single" "$iqn" "$port" "$expected_path" "${target_ips[@]}"
  guest_collect_diag "$ssh_host" "$diag_single"
  guest_prepare_fs "$ssh_host" "$expected_path" "$mnt"
  if [ "$generator" = "fio" ]; then
    set +e
    guest_run_fio "$ssh_host" "$mnt" "/tmp/fio_singlepath.json"
    ec=$?
    set -e
    if [ "$ec" -eq 0 ]; then
      _scp "$ssh_host:/tmp/fio_singlepath.json" "$result_single"
    else
      generator="dd"
      guest_run_dd_fallback "$ssh_host" "$mnt" "/tmp/dd_singlepath.json" "/tmp/dd_singlepath.txt"
      _scp "$ssh_host:/tmp/dd_singlepath.json" "$result_single"
      _scp "$ssh_host:/tmp/dd_singlepath.txt" "$dd_single_txt"
    fi
  else
    guest_run_dd_fallback "$ssh_host" "$mnt" "/tmp/dd_singlepath.json" "/tmp/dd_singlepath.txt"
    _scp "$ssh_host:/tmp/dd_singlepath.json" "$result_single"
    _scp "$ssh_host:/tmp/dd_singlepath.txt" "$dd_single_txt"
  fi

  local bw_mpath bw_single
  bw_mpath="$(extract_total_bw_mbps "$result_mpath")"
  bw_single="$(extract_total_bw_mbps "$result_single")"

  cat >"$summary_md" <<EOF
# Sprint 20 — A/B (multipath vs single-path)

## Inputs

* shape: $COMPUTE_SHAPE ($COMPUTE_OCPUS OCPUs, $COMPUTE_MEMORY_GB GB)
* block volume: UHP ($BLOCKVOLUME_SIZE_GB GB, $BLOCKVOLUME_VPUS_PER_GB VPU/GB)
* generator: $generator
* fio (if used): randrw 70/30, bs=4k, numjobs=4, iodepth=32, runtime=${FIO_RUNTIME_SEC:-120}s
* dd (if used): jobs=${DD_JOBS:-4}, size_gb=${DD_SIZE_GB:-16} per job, bs=${DD_BS:-16M}

## Results (Total BW)

* multipath: ${bw_mpath} MB/s
* single-path: ${bw_single} MB/s

## Artifacts

* diagnostics multipath: $(basename "$diag_mpath")
* diagnostics single-path: $(basename "$diag_single")
* result multipath: $(basename "$result_mpath")
* result single-path: $(basename "$result_single")
EOF

  cp -f state.json "$state_json"

  echo "  [INFO] Teardown ..."
  teardown_compute.sh || true
  teardown_blockvolume_attachment.sh || true
  teardown_blockvolume.sh || true

  echo "  [DONE] Summary: $summary_md"
}

main "$@"


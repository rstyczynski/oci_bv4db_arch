#!/usr/bin/env bash
# Sprint 30 root-side executor. It operates only on the five devices described
# by a controller-generated manifest and never discovers a formatting target.
set -euo pipefail

STATE_DIR=/var/lib/bv4db-sprint30
BASELINE="$STATE_DIR/baseline.json"
MANIFEST="$STATE_DIR/manifest.json"

die() { echo "ERROR: $*" >&2; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command missing: $1"; }
json_tmp() { printf '%s.tmp.%s' "$1" "$$"; }
atomic_copy() { local tmp; tmp=$(json_tmp "$2"); cp "$1" "$tmp"; mv "$tmp" "$2"; }

device_leaf() {
  local dev="$1" parent
  dev=$(readlink -f "$dev")
  while parent=$(lsblk -dnro PKNAME "$dev" 2>/dev/null) && [ -n "$parent" ]; do dev="/dev/$parent"; done
  readlink -f "$dev"
}

capture_controls() {
  local out="$1" iface rx tx rps xps
  iface=$(jq -r '.iscsi_interface' "$MANIFEST")
  rx=$(find "/sys/class/net/$iface/queues" -maxdepth 1 -type d -name 'rx-*' -print 2>/dev/null | sort | jq -Rsc 'split("\n")|map(select(length>0))')
  tx=$(find "/sys/class/net/$iface/queues" -maxdepth 1 -type d -name 'tx-*' -print 2>/dev/null | sort | jq -Rsc 'split("\n")|map(select(length>0))')
  rps=$(while IFS= read -r q; do jq -nc --arg path "$q" --arg cpus "$(cat "$q/rps_cpus" 2>/dev/null || echo 0)" --arg flow "$(cat "$q/rps_flow_cnt" 2>/dev/null || echo 0)" '{path:$path,cpus:$cpus,flow_count:$flow}'; done < <(jq -r '.[]' <<<"$rx") | jq -s .)
  xps=$(while IFS= read -r q; do jq -nc --arg path "$q" --arg cpus "$(cat "$q/xps_cpus" 2>/dev/null || echo 0)" '{path:$path,cpus:$cpus}'; done < <(jq -r '.[]' <<<"$tx") | jq -s .)
  jq -n \
    --arg rmem "$(sysctl -n net.core.rmem_max)" \
    --arg wmem "$(sysctl -n net.core.wmem_max)" \
    --arg tcp_rmem "$(sysctl -n net.ipv4.tcp_rmem)" \
    --arg tcp_wmem "$(sysctl -n net.ipv4.tcp_wmem)" \
    --arg backlog "$(sysctl -n net.core.netdev_max_backlog)" \
    --arg rps_sock "$(sysctl -n net.core.rps_sock_flow_entries 2>/dev/null || echo 0)" \
    --arg cc "$(sysctl -n net.ipv4.tcp_congestion_control)" \
    --arg online "$(cat /sys/devices/system/cpu/online)" \
    --arg iface "$iface" --argjson rx "$rx" --argjson tx "$tx" --argjson rps "$rps" --argjson xps "$xps" \
    '{rmem_max:$rmem,wmem_max:$wmem,tcp_rmem:$tcp_rmem,tcp_wmem:$tcp_wmem,netdev_max_backlog:$backlog,rps_sock_flow_entries:$rps_sock,tcp_congestion_control:$cc,online_cpus:$online,interface:$iface,rx_queues:$rx,tx_queues:$tx,rps:$rps,xps:$xps}' > "$out"
}

restore_controls() {
  [ -s "$BASELINE" ] || die "baseline is missing"
  sysctl -q -w "net.core.rmem_max=$(jq -r .rmem_max "$BASELINE")"
  sysctl -q -w "net.core.wmem_max=$(jq -r .wmem_max "$BASELINE")"
  sysctl -q -w "net.ipv4.tcp_rmem=$(jq -r .tcp_rmem "$BASELINE")"
  sysctl -q -w "net.ipv4.tcp_wmem=$(jq -r .tcp_wmem "$BASELINE")"
  sysctl -q -w "net.core.netdev_max_backlog=$(jq -r .netdev_max_backlog "$BASELINE")"
  sysctl -q -w "net.core.rps_sock_flow_entries=$(jq -r .rps_sock_flow_entries "$BASELINE")" 2>/dev/null || true
  sysctl -q -w "net.ipv4.tcp_congestion_control=$(jq -r .tcp_congestion_control "$BASELINE")"
  local q value
  while IFS=$'\t' read -r q value; do [ ! -w "$q/rps_cpus" ] || printf '%s\n' "$value" > "$q/rps_cpus"; done < <(jq -r '.rps[]|[.path,.cpus]|@tsv' "$BASELINE")
  while IFS=$'\t' read -r q value; do [ ! -w "$q/rps_flow_cnt" ] || printf '%s\n' "$value" > "$q/rps_flow_cnt"; done < <(jq -r '.rps[]|[.path,.flow_count]|@tsv' "$BASELINE")
  while IFS=$'\t' read -r q value; do [ ! -w "$q/xps_cpus" ] || printf '%s\n' "$value" > "$q/xps_cpus"; done < <(jq -r '.xps[]|[.path,.cpus]|@tsv' "$BASELINE")
}

cpu_mask() {
  local count hex
  count=$(nproc)
  if [ "$count" -ge 63 ]; then die "CPU mask helper supports fewer than 63 CPUs"; fi
  printf -v hex '%x' "$(( (1 << count) - 1 ))"
  printf '%s\n' "$hex"
}

apply_candidate() {
  local id="$1" mask q current min def max
  case "$id" in
    REGULAR_BASELINE_INITIAL|REGULAR_BASELINE_FINAL|REGULAR_CHECKPOINT) ;;
    TCP_BUF_2X|TCP_BUF_4X)
      local factor=2; [ "$id" = TCP_BUF_4X ] && factor=4
      sysctl -q -w "net.core.rmem_max=$(( $(jq -r .rmem_max "$BASELINE") * factor ))"
      sysctl -q -w "net.core.wmem_max=$(( $(jq -r .wmem_max "$BASELINE") * factor ))"
      read -r min def max <<<"$(jq -r .tcp_rmem "$BASELINE")"; sysctl -q -w "net.ipv4.tcp_rmem=$min $def $((max * factor))"
      read -r min def max <<<"$(jq -r .tcp_wmem "$BASELINE")"; sysctl -q -w "net.ipv4.tcp_wmem=$min $def $((max * factor))"
      ;;
    NETDEV_BACKLOG_2X|NETDEV_BACKLOG_4X)
      local factor=2; [ "$id" = NETDEV_BACKLOG_4X ] && factor=4
      sysctl -q -w "net.core.netdev_max_backlog=$(( $(jq -r .netdev_max_backlog "$BASELINE") * factor ))"
      ;;
    RPS_ALL_ONLINE|RPS_RFS_65536)
      mask=$(cpu_mask)
      while IFS= read -r q; do [ ! -w "$q/rps_cpus" ] || printf '%s\n' "$mask" > "$q/rps_cpus"; done < <(jq -r '.rx_queues[]' "$BASELINE")
      if [ "$id" = RPS_RFS_65536 ]; then
        sysctl -q -w net.core.rps_sock_flow_entries=65536
        current=$(jq '.rx_queues|length' "$BASELINE"); [ "$current" -gt 0 ] || die "no RX queues"
        while IFS= read -r q; do [ ! -w "$q/rps_flow_cnt" ] || printf '%s\n' "$((65536/current))" > "$q/rps_flow_cnt"; done < <(jq -r '.rx_queues[]' "$BASELINE")
      fi
      ;;
    XPS_BY_QUEUE)
      mask=$(cpu_mask)
      while IFS= read -r q; do [ ! -w "$q/xps_cpus" ] || printf '%s\n' "$mask" > "$q/xps_cpus"; done < <(jq -r '.tx_queues[]' "$BASELINE")
      ;;
    *) die "candidate is not supported by guest executor: $id" ;;
  esac
}

capture_errors() {
  local out="$1" iface
  iface=$(jq -r '.iscsi_interface' "$MANIFEST")
  jq -n --argjson net "$(ip -s -j link show dev "$iface")" \
    --argjson snmp "$(nstat -az 2>/dev/null | awk 'NF==2{print $1"="$2}' | jq -Rsc 'split("\n")|map(select(length>0)|split("="))|from_entries')" \
    --arg dmesg "$(dmesg --level=err,crit,alert,emerg --since '-2 minutes' 2>/dev/null || true)" \
    '{network:$net,nstat:$snmp,kernel_errors:$dmesg}' > "$out"
}

prepare() {
  local input="$1" evidence="$2" role iqn ip port path root_leaf leaf sig
  need jq; need lsblk; need iscsiadm; need fio; need iostat
  install -d -m 0700 "$STATE_DIR" "$evidence"
  jq -e '.vpu==50 and (.volumes|length)==5 and all(.volumes[];.created==true and .vpu==50 and .is_multipath==false and .multipath_devices==0)' "$input" >/dev/null || die "manifest contract rejected"
  atomic_copy "$input" "$MANIFEST"
  systemctl enable --now iscsid >/dev/null
  root_leaf=$(device_leaf "$(findmnt -nro SOURCE /)")
  while IFS=$'\t' read -r role iqn ip port path; do
    iscsiadm -m node -o new -T "$iqn" -p "$ip:$port" >/dev/null 2>&1 || true
    iscsiadm -m node -T "$iqn" -p "$ip:$port" --op update -n node.startup -v manual >/dev/null
    iscsiadm -m node -T "$iqn" -p "$ip:$port" --login >/dev/null 2>&1 || true
    udevadm settle
    for _ in $(seq 1 60); do [ -b "$path" ] && break; sleep 2; done
    [ -b "$path" ] || die "$role path did not appear: $path"
    leaf=$(device_leaf "$path"); [ "$leaf" != "$root_leaf" ] || die "boot device selected for $role"
    [ "$(iscsiadm -m session 2>/dev/null | grep -F -c "$iqn")" -eq 1 ] || die "$role does not have exactly one iSCSI session"
  done < <(jq -r '.volumes[]|[.role,.iqn,.ipv4,(.port|tostring),.path]|@tsv' "$MANIFEST")

  if [ ! -s "$STATE_DIR/layout_initialized" ]; then
    while IFS= read -r path; do
      sig=$(wipefs -n "$path" 2>/dev/null || true); [ -z "$sig" ] || die "fresh volume has signatures: $path"
      [ -z "$(lsblk -nro MOUNTPOINTS "$path" | tr -d '[:space:]')" ] || die "fresh volume is mounted: $path"
      pvs --noheadings -o pv_name 2>/dev/null | awk '{$1=$1};1' | grep -Fxq "$path" && die "fresh volume is already an LVM PV: $path"
    done < <(jq -r '.volumes[].path' "$MANIFEST")
    pvcreate /dev/oracleoci/oraclevdb /dev/oracleoci/oraclevdc
    vgcreate vg_data /dev/oracleoci/oraclevdb /dev/oracleoci/oraclevdc
    lvcreate -l 100%FREE -n lv_oradata -i 2 -I 256K vg_data
    mkfs.ext4 -E nodiscard /dev/vg_data/lv_oradata
    pvcreate /dev/oracleoci/oraclevdd /dev/oracleoci/oraclevde
    vgcreate vg_redo /dev/oracleoci/oraclevdd /dev/oracleoci/oraclevde
    lvcreate -l 100%FREE -n lv_redo -i 2 -I 256K vg_redo
    mkfs.ext4 -E nodiscard /dev/vg_redo/lv_redo
    mkfs.ext4 -E nodiscard /dev/oracleoci/oraclevdf
    touch "$STATE_DIR/layout_initialized"
  fi
  mkdir -p /u02/oradata /u03/redo /u04/fra
  mountpoint -q /u02/oradata || mount /dev/vg_data/lv_oradata /u02/oradata
  mountpoint -q /u03/redo || mount /dev/vg_redo/lv_redo /u03/redo
  mountpoint -q /u04/fra || mount /dev/oracleoci/oraclevdf /u04/fra
  chown opc:opc /u02/oradata /u03/redo /u04/fra
  printf 'sprint30-data\n' > /u02/oradata/.sprint30-sentinel
  printf 'sprint30-redo\n' > /u03/redo/.sprint30-sentinel
  printf 'sprint30-fra\n' > /u04/fra/.sprint30-sentinel
  capture_controls "$BASELINE"
  cp "$BASELINE" "$evidence/guest_baseline.json"
  lscpu > "$evidence/lscpu.txt"; lsblk -O -J > "$evidence/lsblk.json"; pvs --reportformat json > "$evidence/pvs.json"; vgs --reportformat json > "$evidence/vgs.json"; lvs --reportformat json -a -o +segtype,stripes,stripesize > "$evidence/lvs.json"
  iscsiadm -m session -P 3 > "$evidence/iscsi_sessions.txt"
}

run_attempt() {
  local candidate="$1" repetition="$2" out="$3" runtime="$4" ramp="$5" started ended rc=0 profile
  mkdir -p "$out"
  restore_controls
  trap 'restore_controls' EXIT INT TERM
  capture_controls "$out/controls_before.json"
  capture_errors "$out/errors_before.json"
  apply_candidate "$candidate"
  capture_controls "$out/controls_applied.json"
  profile="$out/workload.fio"
  cat > "$profile" <<EOF
[global]
ioengine=libaio
direct=1
time_based=1
runtime=$runtime
ramp_time=$ramp
group_reporting=0
invalidate=1
lat_percentiles=1
percentile_list=95:99:99.9

[data-8k]
directory=/u02/oradata
filename=sprint30-data.fio
rw=randrw
rwmixread=70
bs=8k
size=32G
numjobs=4
iodepth=16

[redo]
directory=/u03/redo
filename=sprint30-redo.fio
rw=write
bs=4k
size=4G
numjobs=1
iodepth=1
fdatasync=1

[fra-1m]
directory=/u04/fra
filename=sprint30-fra.fio
rw=readwrite
bs=1M
size=16G
numjobs=1
iodepth=8
rate=120M
EOF
  chown opc:opc "$profile"
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  iostat -o JSON -x 5 > "$out/iostat.json" & local iostat_pid=$!
  set +e
  # The root shell owns the evidence redirect; only fio drops to the opc user.
  # shellcheck disable=SC2024
  sudo -u opc fio --output-format=json --output="$out/fio.json" "$profile" > "$out/fio.log" 2>&1
  rc=$?
  set -e
  kill "$iostat_pid" 2>/dev/null || true; wait "$iostat_pid" 2>/dev/null || true
  ended=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  restore_controls
  trap - EXIT INT TERM
  capture_controls "$out/controls_restored.json"; cmp -s "$BASELINE" "$out/controls_restored.json" || die "baseline restore mismatch"
  capture_errors "$out/errors_after.json"
  jq -n --arg candidate "$candidate" --argjson repetition "$repetition" --arg started "$started" --arg ended "$ended" --argjson rc "$rc" '{candidate_id:$candidate,repetition:$repetition,started_at:$started,ended_at:$ended,fio_exit_code:$rc,restoration_state:"restored"}' > "$out/attempt.json"
  [ "$rc" -eq 0 ]
}

quiesce() {
  restore_controls
  sync
  umount /u04/fra /u03/redo /u02/oradata
  vgchange -an vg_redo; vgchange -an vg_data
  while IFS=$'\t' read -r iqn ip port; do iscsiadm -m node -T "$iqn" -p "$ip:$port" --logout >/dev/null; iscsiadm -m node -o delete -T "$iqn" -p "$ip:$port" >/dev/null; done < <(jq -r '.volumes[]|[.iqn,.ipv4,(.port|tostring)]|@tsv' "$MANIFEST")
}

run_canary() {
  local kind="$1" out="$2" after unit
  mkdir -p "$out"
  restore_controls
  case "$kind" in
    trap)
      set +e
      ( trap 'restore_controls' EXIT; apply_candidate TCP_BUF_2X; false )
      set -e
      ;;
    lease)
      unit="bv4db-sprint30-restore-$$"
      systemd-run --quiet --unit "$unit" --on-active=10s /usr/local/sbin/bv4db-sprint30-guest restore
      apply_candidate TCP_BUF_2X
      sleep 15
      ;;
    *) die "unknown canary: $kind" ;;
  esac
  after="$out/controls_after.json"
  capture_controls "$after"
  cmp -s "$BASELINE" "$after" || die "$kind canary did not restore baseline"
  jq -n --arg kind "$kind" '{kind:$kind,result:"expected_failure_restored",baseline_equal:true}' > "$out/canary.json"
}

case "${1:-}" in
  prepare) [ "$#" -eq 3 ] || die "prepare MANIFEST EVIDENCE"; prepare "$2" "$3" ;;
  run) [ "$#" -eq 6 ] || die "run CANDIDATE REP OUT RUNTIME RAMP"; run_attempt "$2" "$3" "$4" "$5" "$6" ;;
  restore) restore_controls ;;
  canary) [ "$#" -eq 3 ] || die "canary trap|lease OUT"; run_canary "$2" "$3" ;;
  quiesce) quiesce ;;
  *) die "usage: $0 prepare MANIFEST EVIDENCE | run CANDIDATE REP OUT RUNTIME RAMP | restore | quiesce" ;;
esac

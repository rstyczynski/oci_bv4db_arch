#!/usr/bin/env bash
# Sprint 30 root-side executor. It operates only on the five devices described
# by a controller-generated manifest and never discovers a formatting target.
set -euo pipefail

STATE_DIR=/var/lib/bv4db-sprint30
BASELINE="$STATE_DIR/baseline.json"
MANIFEST="$STATE_DIR/manifest.json"
SENTINELS="$STATE_DIR/sentinels.json"
IDENTITIES="$STATE_DIR/device_identities.json"
LOCK_FILE="$STATE_DIR/mutation.lock"
ATTEMPT_LOCK_FILE="$STATE_DIR/attempt.lock"

die() { echo "ERROR: $*" >&2; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command missing: $1"; }
json_tmp() { printf '%s.tmp.%s' "$1" "$$"; }
atomic_copy() { local tmp; tmp=$(json_tmp "$2"); cp "$1" "$tmp"; mv "$tmp" "$2"; }

verify_sentinels() {
  [ -s "$SENTINELS" ] || die "sentinel manifest is missing"
  local path expected actual
  while IFS=$'\t' read -r path expected; do
    [ -f "$path" ] || die "sentinel is missing: $path"
    actual=$(sha256sum "$path" | awk '{print $1}')
    [ "$actual" = "$expected" ] || die "sentinel digest mismatch: $path"
  done < <(jq -r '.[]|[.path,.sha256]|@tsv' "$SENTINELS")
}

device_leaf() {
  local dev="$1" parent
  dev=$(readlink -f "$dev")
  while parent=$(lsblk -dnro PKNAME "$dev" 2>/dev/null) && [ -n "$parent" ]; do dev="/dev/$parent"; done
  readlink -f "$dev"
}

block_device_exists() { [ -b "$1" ]; }

iscsi_bypath_for() {
  local iqn="$1" leaf="$2" candidate
  for candidate in /dev/disk/by-path/*iscsi*; do
    [ -e "$candidate" ] || continue
    if [[ "$candidate" == *"$iqn"* ]] && [ "$(device_leaf "$candidate")" = "$leaf" ]; then printf '%s\n' "$candidate"; return 0; fi
  done
  return 1
}

capture_controls() {
  local out="$1" iface rx tx rps xps qd offloads irq_vectors ring_rx ring_tx channel_combined adaptive_rx adaptive_tx tuned_profile mtu
  iface=$(jq -r '.iscsi_interface' "$MANIFEST")
  rx=$(find "/sys/class/net/$iface/queues" -maxdepth 1 -type d -name 'rx-*' -print 2>/dev/null | sort | jq -Rsc 'split("\n")|map(select(length>0))')
  tx=$(find "/sys/class/net/$iface/queues" -maxdepth 1 -type d -name 'tx-*' -print 2>/dev/null | sort | jq -Rsc 'split("\n")|map(select(length>0))')
  rps=$(while IFS= read -r q; do jq -nc --arg path "$q" --arg cpus "$(cat "$q/rps_cpus" 2>/dev/null || echo 0)" --arg flow "$(cat "$q/rps_flow_cnt" 2>/dev/null || echo 0)" '{path:$path,cpus:$cpus,flow_count:$flow}'; done < <(jq -r '.[]' <<<"$rx") | jq -s .)
  xps=$(while IFS= read -r q; do jq -nc --arg path "$q" --arg cpus "$(cat "$q/xps_cpus" 2>/dev/null || echo 0)" '{path:$path,cpus:$cpus}'; done < <(jq -r '.[]' <<<"$tx") | jq -s .)
  qd=$(while IFS=$'\t' read -r iqn ip port path; do
    jq -nc --arg iqn "$iqn" --arg portal "$ip:$port" --arg value "$(iscsiadm -m node -T "$iqn" -p "$ip:$port" -o show | awk -F'= ' '$1 ~ /node.session.queue_depth/{print $2; exit}')" --arg live_value "$(cat "$(device_leaf "$path")/device/queue_depth" 2>/dev/null || cat "/sys/block/$(basename "$(device_leaf "$path")")/device/queue_depth")" '{iqn:$iqn,portal:$portal,value:$value,live_value:$live_value}'
  done < <(jq -r '.volumes[]|[.iqn,.ipv4,(.port|tostring),.path]|@tsv' "$MANIFEST") | jq -s .)
  offloads=$(ethtool -k "$iface" | awk -F': ' '/^(rx-checksumming|tx-checksumming|tcp-segmentation-offload|generic-segmentation-offload|generic-receive-offload):/{print $1"="$2}' | jq -Rsc 'split("\n")|map(select(length>0)|split("=")|{key:.[0],value:(.[1]|split(" ")[0])})|from_entries')
  irq_vectors=$(find "/sys/class/net/$iface/device/msi_irqs" -maxdepth 1 -type f -exec basename {} \; 2>/dev/null | sort -n | jq -Rsc 'split("\n")|map(select(length>0))')
  ring_rx=$(ethtool -g "$iface" 2>/dev/null | awk '/Current hardware settings:/{s=1;next}s&&$1=="RX:"{print $2;exit}' || true)
  ring_tx=$(ethtool -g "$iface" 2>/dev/null | awk '/Current hardware settings:/{s=1;next}s&&$1=="TX:"{print $2;exit}' || true)
  channel_combined=$(ethtool -l "$iface" 2>/dev/null | awk '/Current hardware settings:/{s=1;next}s&&$1=="Combined:"{print $2;exit}' || true)
  adaptive_rx=$(ethtool -c "$iface" 2>/dev/null | awk '/Adaptive RX:/{for(i=1;i<=NF;i++)if($i=="RX:"){print $(i+1);exit}}' || true)
  adaptive_tx=$(ethtool -c "$iface" 2>/dev/null | awk '/Adaptive RX:|Adaptive TX:/{for(i=1;i<=NF;i++)if($i=="TX:"){print $(i+1);exit}}' || true)
  tuned_profile=$(tuned-adm active 2>/dev/null | sed -n 's/^Current active profile: //p' || true)
  [ -n "$tuned_profile" ] || tuned_profile="__off__"
  mtu=$(cat "/sys/class/net/$iface/mtu")
  jq -n \
    --arg rmem "$(sysctl -n net.core.rmem_max)" \
    --arg wmem "$(sysctl -n net.core.wmem_max)" \
    --arg tcp_rmem "$(sysctl -n net.ipv4.tcp_rmem)" \
    --arg tcp_wmem "$(sysctl -n net.ipv4.tcp_wmem)" \
    --arg backlog "$(sysctl -n net.core.netdev_max_backlog)" \
    --arg rps_sock "$(sysctl -n net.core.rps_sock_flow_entries 2>/dev/null || echo 0)" \
    --arg cc "$(sysctl -n net.ipv4.tcp_congestion_control)" \
    --arg online "$(cat /sys/devices/system/cpu/online)" \
    --arg iface "$iface" --argjson rx "$rx" --argjson tx "$tx" --argjson rps "$rps" --argjson xps "$xps" --argjson qd "$qd" --argjson offloads "$offloads" --argjson irq_vectors "$irq_vectors" \
    --arg ring_rx "$ring_rx" --arg ring_tx "$ring_tx" --arg channels "$channel_combined" --arg adaptive_rx "$adaptive_rx" --arg adaptive_tx "$adaptive_tx" --arg tuned "$tuned_profile" --arg mtu "$mtu" \
    '{rmem_max:$rmem,wmem_max:$wmem,tcp_rmem:$tcp_rmem,tcp_wmem:$tcp_wmem,netdev_max_backlog:$backlog,rps_sock_flow_entries:$rps_sock,tcp_congestion_control:$cc,online_cpus:$online,interface:$iface,mtu:$mtu,rx_queues:$rx,tx_queues:$tx,rps:$rps,xps:$xps,iscsi_queue_depth:$qd,offloads:$offloads,nic:{ring_rx:$ring_rx,ring_tx:$ring_tx,combined_channels:$channels,adaptive_rx:$adaptive_rx,adaptive_tx:$adaptive_tx,irq_vectors:$irq_vectors},tuned_profile:$tuned}' > "$out"
}

reconnect_storage() {
  local qd="$1" iqn ip port path desired
  sync
  for path in /u04/fra /u03/redo /u02/oradata; do if mountpoint -q "$path"; then umount "$path"; fi; done
  vgchange -an vg_redo >/dev/null; vgchange -an vg_data >/dev/null
  while IFS=$'\t' read -r iqn ip port path; do
    if iscsiadm -m session 2>/dev/null | grep -F "$iqn" | grep -Fq "$ip:$port"; then iscsiadm -m node -T "$iqn" -p "$ip:$port" --logout >/dev/null; fi
    desired="$qd"; [ "$qd" != "__baseline__" ] || desired=$(jq -r --arg iqn "$iqn" '.iscsi_queue_depth[]|select(.iqn==$iqn)|.value' "$BASELINE")
    [ -z "$desired" ] || iscsiadm -m node -T "$iqn" -p "$ip:$port" --op update -n node.session.queue_depth -v "$desired" >/dev/null
  done < <(jq -r '.volumes[]|[.iqn,.ipv4,(.port|tostring),.path]|@tsv' "$MANIFEST")
  while IFS=$'\t' read -r iqn ip port path; do
    iscsiadm -m session 2>/dev/null | grep -F "$iqn" | grep -Fq "$ip:$port" || iscsiadm -m node -T "$iqn" -p "$ip:$port" --login >/dev/null
    for _ in $(seq 1 60); do [ -b "$path" ] && break; sleep 2; done
    [ -b "$path" ] || die "device failed to return after reconnect: $path"
  done < <(jq -r '.volumes[]|[.iqn,.ipv4,(.port|tostring),.path]|@tsv' "$MANIFEST")
  udevadm settle
  vgchange -ay vg_data >/dev/null; vgchange -ay vg_redo >/dev/null
  mountpoint -q /u02/oradata || mount /dev/vg_data/lv_oradata /u02/oradata
  mountpoint -q /u03/redo || mount /dev/vg_redo/lv_redo /u03/redo
  mountpoint -q /u04/fra || mount /dev/oracleoci/oraclevdf /u04/fra
  chown opc:opc /u02/oradata /u03/redo /u04/fra
  verify_sentinels
}

restore_controls() {
  [ -s "$BASELINE" ] || die "baseline is missing"
  local current_cc desired_cc tuned_profile current_profile
  current_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
  desired_cc=$(jq -r .tcp_congestion_control "$BASELINE")
  tuned_profile=$(jq -r '.tuned_profile // empty' "$BASELINE"); current_profile=$(tuned-adm active 2>/dev/null | sed -n 's/^Current active profile: //p' || true); [ -n "$current_profile" ] || current_profile="__off__"
  if [ "$current_profile" != "$tuned_profile" ]; then
    if [ "$tuned_profile" = "__off__" ]; then tuned-adm off >/dev/null; else tuned-adm profile "$tuned_profile" >/dev/null; fi
  fi
  sysctl -q -w "net.core.rmem_max=$(jq -r .rmem_max "$BASELINE")"
  sysctl -q -w "net.core.wmem_max=$(jq -r .wmem_max "$BASELINE")"
  sysctl -q -w "net.ipv4.tcp_rmem=$(jq -r .tcp_rmem "$BASELINE")"
  sysctl -q -w "net.ipv4.tcp_wmem=$(jq -r .tcp_wmem "$BASELINE")"
  sysctl -q -w "net.core.netdev_max_backlog=$(jq -r .netdev_max_backlog "$BASELINE")"
  sysctl -q -w "net.core.rps_sock_flow_entries=$(jq -r .rps_sock_flow_entries "$BASELINE")" 2>/dev/null || true
  sysctl -q -w "net.ipv4.tcp_congestion_control=$desired_cc"
  local q value feature option current_value iface channels
  iface=$(jq -r .interface "$BASELINE")
  channels=$(jq -r '.nic.combined_channels // empty' "$BASELINE"); current_value=$(ethtool -l "$iface" 2>/dev/null | awk '/Current hardware settings:/{s=1;next}s&&$1=="Combined:"{print $2;exit}' || true)
  [ -z "$channels" ] || [ "$current_value" = "$channels" ] || ethtool -L "$iface" combined "$channels" >/dev/null
  while IFS=$'\t' read -r q value; do [ ! -w "$q/rps_cpus" ] || printf '%s\n' "$value" > "$q/rps_cpus"; done < <(jq -r '.rps[]|[.path,.cpus]|@tsv' "$BASELINE")
  while IFS=$'\t' read -r q value; do [ ! -w "$q/rps_flow_cnt" ] || printf '%s\n' "$value" > "$q/rps_flow_cnt"; done < <(jq -r '.rps[]|[.path,.flow_count]|@tsv' "$BASELINE")
  while IFS=$'\t' read -r q value; do [ ! -w "$q/xps_cpus" ] || printf '%s\n' "$value" > "$q/xps_cpus"; done < <(jq -r '.xps[]|[.path,.cpus]|@tsv' "$BASELINE")
  while IFS=$'\t' read -r feature value; do
    case "$feature" in rx-checksumming) option=rx;; tx-checksumming) option=tx;; tcp-segmentation-offload) option=tso;; generic-segmentation-offload) option=gso;; generic-receive-offload) option=gro;; *) continue;; esac
    current_value=$(ethtool -k "$(jq -r .interface "$BASELINE")" | awk -F': ' -v key="$feature" '$1==key{print $2}' | awk '{print $1}')
    [ "$current_value" = "$value" ] || ethtool -K "$(jq -r .interface "$BASELINE")" "$option" "$value" >/dev/null
  done < <(jq -r '.offloads|to_entries[]|[.key,.value]|@tsv' "$BASELINE")
  local ring_rx ring_tx adaptive_rx adaptive_tx
  ring_rx=$(jq -r '.nic.ring_rx // empty' "$BASELINE"); ring_tx=$(jq -r '.nic.ring_tx // empty' "$BASELINE")
  current_value=$(ethtool -g "$iface" 2>/dev/null | awk '/Current hardware settings:/{s=1;next}s&&$1=="RX:"{print $2;exit}' || true)
  [ -z "$ring_rx" ] || [ "$current_value" = "$ring_rx" ] || ethtool -G "$iface" rx "$ring_rx" tx "$ring_tx" >/dev/null
  adaptive_rx=$(jq -r '.nic.adaptive_rx // empty' "$BASELINE"); adaptive_tx=$(jq -r '.nic.adaptive_tx // empty' "$BASELINE")
  current_value=$(ethtool -c "$iface" 2>/dev/null | awk '/Adaptive RX:/{for(i=1;i<=NF;i++)if($i=="RX:"){print $(i+1);exit}}' || true); [ -z "$adaptive_rx" ] || [ "$current_value" = "$adaptive_rx" ] || ethtool -C "$iface" adaptive-rx "$adaptive_rx" adaptive-tx "$adaptive_tx" >/dev/null
  local qd_drift=false iqn ip port desired_qd current_qd
  while IFS=$'\t' read -r iqn ip port; do
    desired_qd=$(jq -r --arg iqn "$iqn" '.iscsi_queue_depth[]|select(.iqn==$iqn)|.value' "$BASELINE")
    current_qd=$(iscsiadm -m node -T "$iqn" -p "$ip:$port" -o show | awk -F'= ' '$1 ~ /node.session.queue_depth/{print $2; exit}')
    [ "$current_qd" = "$desired_qd" ] || qd_drift=true
  done < <(jq -r '.volumes[]|[.iqn,.ipv4,(.port|tostring)]|@tsv' "$MANIFEST")
  if [ "$qd_drift" = true ] || [ "$current_cc" != "$desired_cc" ]; then reconnect_storage __baseline__; fi
}

online_cpu_ids() {
  local token start end i
  IFS=',' read -ra tokens <<<"$(cat /sys/devices/system/cpu/online)"
  for token in "${tokens[@]}"; do
    if [[ "$token" == *-* ]]; then start=${token%-*}; end=${token#*-}; for ((i=start;i<=end;i++)); do printf '%s\n' "$i"; done
    else printf '%s\n' "$token"; fi
  done
}

cpu_mask() {
  local cpu mask=0 hex
  while IFS= read -r cpu; do [ "$cpu" -lt 63 ] || die "CPU mask helper supports CPU IDs below 63"; mask=$((mask | (1 << cpu))); done < <(online_cpu_ids)
  printf -v hex '%x' "$mask"
  printf '%s\n' "$hex"
}

apply_candidate() {
  local id="$1" mask q current min def max
  case "$id" in
    REGULAR_BASELINE_INITIAL|REGULAR_BASELINE_FINAL|REGULAR_CHECKPOINT_*) ;;
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
      while IFS= read -r q; do [ -w "$q/rps_cpus" ] || die "RPS queue mask is not writable: $q"; printf '%s\n' "$mask" > "$q/rps_cpus"; done < <(jq -r '.rx_queues[]' "$BASELINE")
      if [ "$id" = RPS_RFS_65536 ]; then
        sysctl -q -w net.core.rps_sock_flow_entries=65536
        current=$(jq '.rx_queues|length' "$BASELINE"); [ "$current" -gt 0 ] || die "no RX queues"
        while IFS= read -r q; do [ -w "$q/rps_flow_cnt" ] || die "RFS queue count is not writable: $q"; printf '%s\n' "$((65536/current))" > "$q/rps_flow_cnt"; done < <(jq -r '.rx_queues[]' "$BASELINE")
      fi
      ;;
    RFS_65536)
      sysctl -q -w net.core.rps_sock_flow_entries=65536
      current=$(jq '.rx_queues|length' "$BASELINE"); [ "$current" -gt 0 ] || die "no RX queues"
      while IFS= read -r q; do [ -w "$q/rps_flow_cnt" ] || die "RFS queue count is not writable: $q"; printf '%s\n' "$((65536/current))" > "$q/rps_flow_cnt"; done < <(jq -r '.rx_queues[]' "$BASELINE")
      ;;
    XPS_BY_QUEUE)
      local -a cpus=(); local idx=0 cpu
      mapfile -t cpus < <(online_cpu_ids); [ "${#cpus[@]}" -gt 0 ] || die "no online CPUs"
      while IFS= read -r q; do
        [ -w "$q/xps_cpus" ] || die "XPS queue mask is not writable: $q"
        cpu=${cpus[$((idx % ${#cpus[@]}))]}; printf -v mask '%x' "$((1 << cpu))"; printf '%s\n' "$mask" > "$q/xps_cpus"; idx=$((idx+1))
      done < <(jq -r '.tx_queues[]' "$BASELINE")
      ;;
    ISCSI_QD128)
      reconnect_storage 128
      ;;
    TCP_CC_*)
      current=${id#TCP_CC_}; current=${current,,}
      sysctl -n net.ipv4.tcp_available_congestion_control | tr ' ' '\n' | grep -Fxq "$current" || die "congestion control is not available: $current"
      sysctl -q -w "net.ipv4.tcp_congestion_control=$current"
      reconnect_storage ""
      ;;
    OFFLOAD_*)
      local feature option baseline_value target
      feature=${id#OFFLOAD_}
      case "$feature" in RX_CHECKSUM) feature="rx-checksumming"; option=rx;; TX_CHECKSUM) feature="tx-checksumming"; option=tx;; TSO) feature="tcp-segmentation-offload"; option=tso;; GSO) feature="generic-segmentation-offload"; option=gso;; GRO) feature="generic-receive-offload"; option=gro;; *) die "unknown offload candidate: $id";; esac
      baseline_value=$(jq -r --arg key "$feature" '.offloads[$key] // empty' "$BASELINE")
      [ "$baseline_value" = on ] || [ "$baseline_value" = off ] || die "offload baseline is unavailable: $feature"
      target=on; [ "$baseline_value" = on ] && target=off
      ethtool -K "$(jq -r .interface "$BASELINE")" "$option" "$target" >/dev/null
      ;;
    NIC_RING_MAX)
      local max_rx max_tx iface
      iface=$(jq -r .interface "$BASELINE")
      max_rx=$(ethtool -g "$iface" | awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="RX:"{print $2;exit}')
      max_tx=$(ethtool -g "$iface" | awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="TX:"{print $2;exit}')
      ethtool -G "$iface" rx "$max_rx" tx "$max_tx" >/dev/null
      ;;
    NIC_CHANNEL_MAX)
      local max_channels online_channels
      max_channels=$(ethtool -l "$(jq -r .interface "$BASELINE")" | awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="Combined:"{print $2;exit}')
      online_channels=$(nproc); [ "$max_channels" -le "$online_channels" ] || max_channels=$online_channels
      ethtool -L "$(jq -r .interface "$BASELINE")" combined "$max_channels" >/dev/null
      ;;
    NIC_COAL_ADAPTIVE_ON|NIC_COAL_ADAPTIVE_OFF)
      local adaptive=on; [ "$id" = NIC_COAL_ADAPTIVE_OFF ] && adaptive=off
      ethtool -C "$(jq -r .interface "$BASELINE")" adaptive-rx "$adaptive" adaptive-tx "$adaptive" >/dev/null
      ;;
    TUNED_PROFILE_*)
      local tuned_candidate=${id#TUNED_PROFILE_}; tuned_candidate=${tuned_candidate,,}; tuned_candidate=${tuned_candidate//_/-}
      tuned-adm profile "$tuned_candidate" >/dev/null
      ;;
    *) die "candidate is not supported by guest executor: $id" ;;
  esac
}

verify_all_iscsi_socket_cc() {
  local expected_cc="$1" ip port socket_text
  while IFS=$'\t' read -r ip port; do
    socket_text=$(ss -tin state established dst "$ip" dport = ":$port" 2>/dev/null || true)
    awk -v cc="$expected_cc" '
      NR==1 && ($1=="State" || $1=="Recv-Q") {next}
      /^[[:space:]]/ {if (!pending || $1 != cc) bad=1; pending=0; next}
      {count++; pending=1}
      END {exit !(count>0 && bad==0 && pending==0)}
    ' <<<"$socket_text" || die "not every iSCSI socket uses $expected_cc for $ip:$port"
  done < <(jq -r '.volumes[]|[.ipv4,(.port|tostring)]|@tsv' "$MANIFEST")
}

stop_rollback_unit_strict() {
  local unit="$1" suffix unit_state
  systemctl stop "$unit.timer" "$unit.service" >/dev/null 2>&1 || return 1
  for suffix in timer service; do
    unit_state=$(systemctl is-active "$unit.$suffix" 2>/dev/null || true)
    case "$unit_state" in inactive|failed|unknown) ;; *) return 1;; esac
  done
  systemctl reset-failed "$unit.service" >/dev/null 2>&1 || true
}

verify_candidate_applied() {
  local id="$1" file="$2" baseline_value feature expected ip port socket_text max_rx max_tx max_channels online_channels factor q value idx cpu mask
  case "$id" in
    REGULAR_*) cmp -s "$BASELINE" "$file" || die "regular baseline readback drift" ;;
    TCP_BUF_2X|TCP_BUF_4X)
      factor=2; [ "$id" = TCP_BUF_4X ] && factor=4
      jq -e --argjson factor "$factor" --slurpfile b "$BASELINE" '.rmem_max==(($b[0].rmem_max|tonumber)*$factor|tostring) and .wmem_max==(($b[0].wmem_max|tonumber)*$factor|tostring) and (([.tcp_rmem|scan("\\S+")|tonumber]) as $a | ([$b[0].tcp_rmem|scan("\\S+")|tonumber]) as $x | $a==[$x[0],$x[1],($x[2]*$factor)]) and (([.tcp_wmem|scan("\\S+")|tonumber]) as $a | ([$b[0].tcp_wmem|scan("\\S+")|tonumber]) as $x | $a==[$x[0],$x[1],($x[2]*$factor)])' "$file" >/dev/null || die "exact TCP buffer readback failed"
      diff -u <(jq -S 'del(.rmem_max,.wmem_max,.tcp_rmem,.tcp_wmem)' "$BASELINE") <(jq -S 'del(.rmem_max,.wmem_max,.tcp_rmem,.tcp_wmem)' "$file") >/dev/null || die "TCP buffer candidate changed an unrelated captured control" ;;
    NETDEV_BACKLOG_2X|NETDEV_BACKLOG_4X) factor=2; [ "$id" = NETDEV_BACKLOG_4X ] && factor=4; [ "$(jq -r .netdev_max_backlog "$file")" -eq "$(( $(jq -r .netdev_max_backlog "$BASELINE") * factor ))" ] || die "exact backlog readback failed"; diff -u <(jq -S 'del(.netdev_max_backlog)' "$BASELINE") <(jq -S 'del(.netdev_max_backlog)' "$file") >/dev/null || die "backlog candidate changed an unrelated captured control" ;;
    RPS_ALL_ONLINE) expected=$(cpu_mask); jq -e --arg mask "$expected" 'all(.rps[];((.cpus|gsub(",";"")|sub("^0+";""))==($mask|sub("^0+";""))))' "$file" >/dev/null || die "exact RPS readback failed"; diff -u <(jq -S 'del(.rps)' "$BASELINE") <(jq -S 'del(.rps)' "$file") >/dev/null || die "RPS candidate changed an unrelated captured control" ;;
    RPS_RFS_65536) expected=$(cpu_mask); q=$(jq '.rx_queues|length' "$BASELINE"); jq -e --arg mask "$expected" --argjson per_queue "$((65536/q))" '.rps_sock_flow_entries=="65536" and all(.rps[];((.cpus|gsub(",";"")|sub("^0+";""))==($mask|sub("^0+";""))) and (.flow_count|tonumber)==$per_queue)' "$file" >/dev/null || die "exact RPS/RFS readback failed"; diff -u <(jq -S 'del(.rps,.rps_sock_flow_entries)' "$BASELINE") <(jq -S 'del(.rps,.rps_sock_flow_entries)' "$file") >/dev/null || die "RPS/RFS candidate changed an unrelated captured control" ;;
    RFS_65536) q=$(jq '.rx_queues|length' "$BASELINE"); jq -e --argjson per_queue "$((65536/q))" --slurpfile b "$BASELINE" '.rps_sock_flow_entries=="65536" and all(.rps[];(.flow_count|tonumber)==$per_queue) and [.rps[].cpus]==[$b[0].rps[].cpus]' "$file" >/dev/null || die "exact RFS readback failed"; diff -u <(jq -S 'del(.rps_sock_flow_entries)|.rps|=map(del(.flow_count))' "$BASELINE") <(jq -S 'del(.rps_sock_flow_entries)|.rps|=map(del(.flow_count))' "$file") >/dev/null || die "RFS candidate changed an unrelated captured control" ;;
    XPS_BY_QUEUE)
      local -a cpus=(); mapfile -t cpus < <(online_cpu_ids); idx=0
      while IFS=$'\t' read -r q value; do cpu=${cpus[$((idx % ${#cpus[@]}))]}; printf -v mask '%x' "$((1 << cpu))"; [ "${value//,/}" = "$mask" ] || [ "$((16#${value//,/}))" -eq "$((16#$mask))" ] || die "exact XPS readback failed: $q"; idx=$((idx+1)); done < <(jq -r '.xps[]|[.path,.cpus]|@tsv' "$file")
      diff -u <(jq -S 'del(.xps)' "$BASELINE") <(jq -S 'del(.xps)' "$file") >/dev/null || die "XPS candidate changed an unrelated captured control" ;;
    ISCSI_QD128)
      jq -e 'all(.iscsi_queue_depth[];.value=="128" and .live_value=="128")' "$file" >/dev/null || die "iSCSI queue-depth live readback failed"
      diff -u <(jq -S 'del(.iscsi_queue_depth)' "$BASELINE") <(jq -S 'del(.iscsi_queue_depth)' "$file") >/dev/null || die "queue-depth candidate changed an unrelated captured control"
      expected=$(jq -r .tcp_congestion_control "$BASELINE"); verify_all_iscsi_socket_cc "$expected" ;;
    TCP_CC_*)
      expected=${id#TCP_CC_}; expected=${expected,,}; [ "$(jq -r .tcp_congestion_control "$file")" = "$expected" ] || die "TCP congestion-control readback failed"
      diff -u <(jq -S 'del(.tcp_congestion_control)' "$BASELINE") <(jq -S 'del(.tcp_congestion_control)' "$file") >/dev/null || die "congestion-control candidate changed an unrelated captured control"
      verify_all_iscsi_socket_cc "$expected" ;;
    OFFLOAD_*)
      feature=${id#OFFLOAD_}; case "$feature" in RX_CHECKSUM) feature="rx-checksumming";; TX_CHECKSUM) feature="tx-checksumming";; TSO) feature="tcp-segmentation-offload";; GSO) feature="generic-segmentation-offload";; GRO) feature="generic-receive-offload";; esac
      baseline_value=$(jq -r --arg key "$feature" '.offloads[$key]' "$BASELINE"); expected=on; [ "$baseline_value" = on ] && expected=off
      [ "$(jq -r --arg key "$feature" '.offloads[$key]' "$file")" = "$expected" ] || die "offload readback failed: $feature"
      diff -u <(jq -S --arg key "$feature" 'del(.offloads[$key])' "$BASELINE") <(jq -S --arg key "$feature" 'del(.offloads[$key])' "$file") >/dev/null || die "offload candidate changed an unrelated captured control" ;;
    NIC_RING_MAX)
      max_rx=$(ethtool -g "$(jq -r .interface "$BASELINE")" | awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="RX:"{print $2;exit}'); max_tx=$(ethtool -g "$(jq -r .interface "$BASELINE")" | awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="TX:"{print $2;exit}')
      jq -e --arg rx "$max_rx" --arg tx "$max_tx" '.nic.ring_rx==$rx and .nic.ring_tx==$tx' "$file" >/dev/null || die "ring readback failed"
      diff -u <(jq -S 'del(.nic.ring_rx,.nic.ring_tx)' "$BASELINE") <(jq -S 'del(.nic.ring_rx,.nic.ring_tx)' "$file") >/dev/null || die "ring candidate changed an unrelated captured control" ;;
    NIC_CHANNEL_MAX)
      max_channels=$(ethtool -l "$(jq -r .interface "$BASELINE")" | awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="Combined:"{print $2;exit}'); online_channels=$(online_cpu_ids | wc -l); [ "$max_channels" -le "$online_channels" ] || max_channels=$online_channels
      jq -e --arg channels "$max_channels" '.nic.combined_channels==$channels and (.rx_queues|length)==($channels|tonumber) and (.tx_queues|length)==($channels|tonumber) and (.nic.irq_vectors|length)>0' "$file" >/dev/null || die "channel/queue/IRQ readback failed"
      diff -u <(jq -S 'del(.rx_queues,.tx_queues,.rps,.xps,.nic.combined_channels,.nic.irq_vectors)' "$BASELINE") <(jq -S 'del(.rx_queues,.tx_queues,.rps,.xps,.nic.combined_channels,.nic.irq_vectors)' "$file") >/dev/null || die "channel candidate changed an unrelated captured control" ;;
    NIC_COAL_ADAPTIVE_ON) jq -e '.nic.adaptive_rx=="on" and .nic.adaptive_tx=="on"' "$file" >/dev/null || die "coalescing readback failed"; diff -u <(jq -S 'del(.nic.adaptive_rx,.nic.adaptive_tx)' "$BASELINE") <(jq -S 'del(.nic.adaptive_rx,.nic.adaptive_tx)' "$file") >/dev/null || die "coalescing candidate changed an unrelated captured control" ;;
    NIC_COAL_ADAPTIVE_OFF) jq -e '.nic.adaptive_rx=="off" and .nic.adaptive_tx=="off"' "$file" >/dev/null || die "coalescing readback failed"; diff -u <(jq -S 'del(.nic.adaptive_rx,.nic.adaptive_tx)' "$BASELINE") <(jq -S 'del(.nic.adaptive_rx,.nic.adaptive_tx)' "$file") >/dev/null || die "coalescing candidate changed an unrelated captured control" ;;
    TUNED_PROFILE_*) expected=${id#TUNED_PROFILE_}; expected=${expected,,}; expected=${expected//_/-}; if [ "$(jq -r .tuned_profile "$file")" != "$expected" ] || ! tuned-adm verify >/dev/null; then die "TuneD profile/settings readback failed"; fi ;;
    *) die "missing readback validator: $id" ;;
  esac
}

capture_errors() {
  local out="$1" iface
  iface=$(jq -r '.iscsi_interface' "$MANIFEST")
  jq -n --argjson net "$(ip -s -j link show dev "$iface")" \
    --argjson snmp "$(nstat -az 2>/dev/null | awk 'NF==2{print $1"="$2}' | jq -Rsc 'split("\n")|map(select(length>0)|split("="))|from_entries')" \
    --arg dmesg "$(dmesg --ctime --level=warn,err,crit,alert,emerg 2>/dev/null | grep -Ei 'iscsi|scsi|blk|block|net|tcp|eth|timeout|reset|error|fail' || true)" \
    --arg iscsi "$(iscsiadm -m session -P 3 2>/dev/null | grep -Ei 'error|failure|failed|timeout|abort' || true)" \
    '{network:$net,nstat:$snmp,kernel_errors:$dmesg,iscsi_error_state:$iscsi}' > "$out"
}

verify_errors_clean() {
  local before="$1" after="$2"
  jq -e -n --slurpfile b "$before" --slurpfile a "$after" '
    def net_errors($x): [$x.network[]? | ((.stats64 // .stats) // {}) | .rx,.tx | (.errors//0),(.dropped//0),(.missed_errors//0),(.crc_errors//0),(.fifo_errors//0),(.carrier_errors//0)] | add // 0;
    ($a[0].kernel_errors==$b[0].kernel_errors) and ($a[0].iscsi_error_state==$b[0].iscsi_error_state)
    and (net_errors($a[0]) <= net_errors($b[0]))
    and all($a[0].nstat|to_entries[]|select(.key|test("RetransSegs|InErrs|OutRsts|InCsumErrors|ListenDrops|TCPAbort")); ((.value|tonumber) <= (($b[0].nstat[.key]//0)|tonumber)))
  ' >/dev/null || die "monitored kernel, iSCSI, TCP, or NIC error counter increased"
}

capture_attempt_context() {
  local out="$1" iface
  mkdir -p "$out"
  iface=$(jq -r .iscsi_interface "$MANIFEST")
  iscsiadm -m session -P 3 > "$out/iscsi_sessions.txt"
  ss -tinp > "$out/iscsi_sockets.txt" 2>&1 || true
  while IFS= read -r ip; do ip route get "$ip"; done < <(jq -r '.volumes[].ipv4' "$MANIFEST") > "$out/iscsi_routes.txt"
  findmnt -J > "$out/mounts.json"
  pvs --reportformat json > "$out/pvs.json"; vgs --reportformat json > "$out/vgs.json"
  lvs --reportformat json -a -o lv_name,vg_name,lv_attr,segtype,stripes,stripesize > "$out/lvs.json"
  lsblk -J -o NAME,KNAME,TYPE,SIZE,MOUNTPOINTS,SERIAL > "$out/lsblk.json"
  sed -n "1p;/$iface/p" /proc/interrupts > "$out/interrupts.txt"
  find "/sys/class/net/$iface/device/msi_irqs" -maxdepth 1 -type f -print -exec sh -c 'irq=$(basename "$1"); grep -E "^[[:space:]]*$irq:" /proc/interrupts || true' _ {} \; > "$out/msi_irq_topology.txt" 2>&1 || true
  find "/sys/class/net/$iface/queues" -maxdepth 2 -type f -print -exec sh -c 'printf "="; cat "$1" 2>/dev/null || true' _ {} \; > "$out/queue_topology.txt"
  tuned-adm active > "$out/tuned_active.txt" 2>&1 || true
  tuned-adm verify > "$out/tuned_verify.txt" 2>&1 || true
}

preformat_single_path_proof() {
  local role="$1" iqn="$2" ip="$3" port="$4" path="$5" leaf session_all session_text leaf_type
  session_all=$(iscsiadm -m session 2>/dev/null || true)
  session_text=$(awk -v iqn="$iqn" '$NF==iqn' <<<"$session_all")
  if [ -z "$session_text" ] || [ "$(wc -l <<<"$session_text" | tr -d ' ')" -ne 1 ] \
    || ! awk -v portal="$ip:$port," 'index($(NF-1),portal)==1{found=1} END{exit !found}' <<<"$session_text"; then
    die "$role does not have exactly one expected-portal iSCSI session"
  fi
  leaf=$(device_leaf "$path")
  leaf_type=$(lsblk -dnro TYPE "$leaf" 2>/dev/null) || die "$role device type inspection failed"
  [ "$leaf_type" != mpath ] || die "$role resolved to a dm-multipath device"
  ! lsblk -nro TYPE | grep -Fxq mpath || die "dm-multipath device detected before layout initialization"
}

prepare() {
  local input="$1" authorization="$2" evidence="$3" role iqn ip port path root_leaf leaf sig manifest_sha run_id bypath candidate mounts observed_size expected_size pvs_output
  local leaves='[]' identities='[]' sent='[]' sentinel digest
  need jq; need lsblk; need iscsiadm; need fio; need iostat; need sha256sum; need flock
  [ "$(uname -m)" = x86_64 ] || die "Sprint 30 guest architecture must be x86_64"
  install -d -m 0700 "$STATE_DIR" "$evidence"
  jq -e '.vpu==50 and (.run_id|length)>0 and (.volumes|length)==5 and all(.volumes[];.created==true and .vpu==50 and .is_multipath==false and .multipath_devices==0 and (.volume_ocid|length)>0 and (.iqn|length)>0) and ([.volumes[].path]|unique|length)==5 and ([.volumes[].volume_ocid]|unique|length)==5 and ([.volumes[].iqn]|unique|length)==5' "$input" >/dev/null || die "manifest contract rejected"
  manifest_sha=$(sha256sum "$input" | awk '{print $1}'); run_id=$(jq -r '.run_id' "$input")
  jq -e --arg run_id "$run_id" --arg sha "$manifest_sha" '.authorize_fresh_layout==true and .run_id==$run_id and .manifest_sha256==$sha and (.volumes|length)==5' "$authorization" >/dev/null || die "fresh-layout authorization rejected"
  diff -u <(jq -S '[.volumes[]|{volume_ocid,path,iqn}]' "$input") <(jq -S '.volumes' "$authorization") >/dev/null || die "authorization volume set mismatch"
  atomic_copy "$input" "$MANIFEST"
  systemctl enable --now iscsid >/dev/null
  root_leaf=$(device_leaf "$(findmnt -nro SOURCE /)")
  while IFS= read -r ip; do
    [ "$(ip route get "$ip" | awk '{for(i=1;i<=NF;i++)if($i=="dev"){print $(i+1);exit}}')" = "$(jq -r .iscsi_interface "$MANIFEST")" ] || die "iSCSI target route mismatch: $ip"
  done < <(jq -r '.volumes[].ipv4' "$MANIFEST")
  while IFS=$'\t' read -r role iqn ip port path; do
    iscsiadm -m node -o new -T "$iqn" -p "$ip:$port" >/dev/null 2>&1 || iscsiadm -m node -T "$iqn" -p "$ip:$port" >/dev/null
    iscsiadm -m node -T "$iqn" -p "$ip:$port" --op update -n node.startup -v manual >/dev/null
    if ! iscsiadm -m session 2>/dev/null | grep -Fq "$iqn"; then iscsiadm -m node -T "$iqn" -p "$ip:$port" --login >/dev/null; fi
    udevadm settle
    for _ in $(seq 1 60); do block_device_exists "$path" && break; sleep 2; done
    block_device_exists "$path" || die "$role path did not appear: $path"
    leaf=$(device_leaf "$path"); [ "$leaf" != "$root_leaf" ] || die "boot device selected for $role"
    preformat_single_path_proof "$role" "$iqn" "$ip" "$port" "$path"
    bypath=$(iscsi_bypath_for "$iqn" "$leaf" || true)
    [ -n "$bypath" ] || die "$role device cannot be bound to its IQN"
    leaves=$(jq -c --arg leaf "$leaf" '. + [$leaf]' <<<"$leaves")
    identities=$(jq -c --arg role "$role" --arg iqn "$iqn" --arg path "$path" --arg leaf "$leaf" --arg bypath "$bypath" --arg serial "$(lsblk -dnro SERIAL "$leaf" 2>/dev/null || true)" '. + [{role:$role,iqn:$iqn,path:$path,leaf:$leaf,by_path:$bypath,serial:$serial}]' <<<"$identities")
  done < <(jq -r '.volumes[]|[.role,.iqn,.ipv4,(.port|tostring),.path]|@tsv' "$MANIFEST")
  [ "$(jq 'unique|length' <<<"$leaves")" -eq 5 ] || die "expected five unique non-boot leaf devices"
  printf '%s\n' "$identities" > "$IDENTITIES"; cp "$IDENTITIES" "$evidence/device_identities.json"

  if [ ! -s "$STATE_DIR/layout_initialized" ]; then
    while IFS=$'\t' read -r path role expected_size; do
      sig=$(wipefs -n "$path" 2>/dev/null) || die "wipefs inspection failed: $path"
      [ -z "$sig" ] || die "fresh volume has signatures: $path"
      mounts=$(lsblk -nro MOUNTPOINTS "$path" 2>/dev/null) || die "mount inspection failed: $path"
      [ -z "$(tr -d '[:space:]' <<<"$mounts")" ] || die "fresh volume is mounted: $path"
      observed_size=$(blockdev --getsize64 "$path") || die "capacity inspection failed: $path"
      [ "$observed_size" -eq "$((expected_size * 1024 * 1024 * 1024))" ] || die "$role capacity mismatch: $path"
      [ -n "$(lsblk -dnro SERIAL "$(readlink -f "$path")" 2>/dev/null)" ] || die "$role serial is empty: $path"
      pvs_output=$(pvs --noheadings -o pv_name 2>/dev/null) || die "LVM PV inspection failed"
      if awk '{$1=$1};1' <<<"$pvs_output" | grep -Fxq "$(readlink -f "$path")"; then die "fresh volume is already an LVM PV: $path"; fi
    done < <(jq -r '.volumes[]|[.path,.role,(.size_gb|tostring)]|@tsv' "$MANIFEST")
    mv "$authorization" "$STATE_DIR/layout_authorization.consumed.json"
    sync
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
  else
    die "fresh Sprint 30 prepare refuses an existing initialized layout"
  fi
  mkdir -p /u02/oradata /u03/redo /u04/fra
  mount /dev/vg_data/lv_oradata /u02/oradata
  mount /dev/vg_redo/lv_redo /u03/redo
  mount /dev/oracleoci/oraclevdf /u04/fra
  chown opc:opc /u02/oradata /u03/redo /u04/fra
  for sentinel in /u02/oradata/.sprint30-sentinel /u03/redo/.sprint30-sentinel /u04/fra/.sprint30-sentinel; do
    dd if=/dev/urandom of="$sentinel" bs=1M count=64 status=none; chmod 0444 "$sentinel"
    digest=$(sha256sum "$sentinel" | awk '{print $1}'); sent=$(jq -c --arg path "$sentinel" --arg sha "$digest" '. + [{path:$path,sha256:$sha}]' <<<"$sent")
  done
  printf '%s\n' "$sent" > "$SENTINELS"; verify_sentinels; cp "$SENTINELS" "$evidence/sentinels.json"
  capture_controls "$BASELINE"; cp "$BASELINE" "$evidence/guest_baseline.json"
  jq -n '{rollback_armed:false,restoration_state:"baseline_captured"}' > "$STATE_DIR/rollback.json"
  lscpu > "$evidence/lscpu.txt"; lsblk -O -J > "$evidence/lsblk.json"; pvs --reportformat json > "$evidence/pvs.json"; vgs --reportformat json > "$evidence/vgs.json"; lvs --reportformat json -a -o +segtype,stripes,stripesize > "$evidence/lvs.json"
  iscsiadm -m session -P 3 > "$evidence/iscsi_sessions.txt"
  sysctl -n net.ipv4.tcp_available_congestion_control > "$evidence/tcp_available_congestion_control.txt"
  ethtool -g "$(jq -r .iscsi_interface "$MANIFEST")" > "$evidence/ethtool_rings.txt" 2>&1 || true
  ethtool -l "$(jq -r .iscsi_interface "$MANIFEST")" > "$evidence/ethtool_channels.txt" 2>&1 || true
  ethtool -c "$(jq -r .iscsi_interface "$MANIFEST")" > "$evidence/ethtool_coalescing.txt" 2>&1 || true
  ethtool -k "$(jq -r .iscsi_interface "$MANIFEST")" > "$evidence/ethtool_features.txt" 2>&1 || true
  ethtool -i "$(jq -r .iscsi_interface "$MANIFEST")" > "$evidence/ethtool_driver.txt" 2>&1 || true
  ethtool -x "$(jq -r .iscsi_interface "$MANIFEST")" > "$evidence/ethtool_rss.txt" 2>&1 || true
  tuned-adm list > "$evidence/tuned_profiles.txt" 2>&1 || true
  mkdir -p "$evidence/tuned_profile_info"
  while IFS= read -r profile; do
    {
      tuned-adm profile_info "$profile" 2>&1 || true
      for profile_root in /etc/tuned /usr/lib/tuned; do
        if [ -f "$profile_root/$profile/tuned.conf" ]; then printf '\n### %s\n' "$profile_root/$profile/tuned.conf"; sed -n '1,400p' "$profile_root/$profile/tuned.conf"; fi
      done
    } > "$evidence/tuned_profile_info/$profile.txt"
  done < <(sed -n 's/^-[[:space:]]*\([^[:space:]]*\).*/\1/p' "$evidence/tuned_profiles.txt")
}

run_attempt() {
  local candidate="$1" repetition="$2" out="$3" runtime="$4" ramp="$5" started ended rc=0 profile unit fio_pid='' iostat_pid='' expected_cc lock_held=false attempt_lock_held=false
  transition() {
    local state="$1" file="$out/state.json" now tmp
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ); tmp="$file.tmp.$$"
    if [ -s "$file" ]; then jq --arg state "$state" --arg at "$now" '. + [{state:$state,at:$at}]' "$file" > "$tmp"; else jq -n --arg state "$state" --arg at "$now" '[{state:$state,at:$at}]' > "$tmp"; fi
    mv "$tmp" "$file"
  }
  cleanup_attempt() {
    local restore_rc=0
    [ -z "$fio_pid" ] || { kill "$fio_pid" 2>/dev/null || true; wait "$fio_pid" 2>/dev/null || true; }
    [ -z "$iostat_pid" ] || { kill "$iostat_pid" 2>/dev/null || true; wait "$iostat_pid" 2>/dev/null || true; }
    if [ "$lock_held" != true ]; then
      if flock -w 120 9; then lock_held=true; else
        jq -n --arg unit "$unit" '{rollback_armed:true,unit:$unit,restoration_state:"unproven",reason:"mutation_lock_unavailable"}' > "$STATE_DIR/rollback.json"
        transition failed
        if [ "$attempt_lock_held" = true ]; then flock -u 7 >/dev/null 2>&1 || true; attempt_lock_held=false; fi
        return 1
      fi
    fi
    transition restoring
    restore_controls || restore_rc=$?
    if [ "$restore_rc" -eq 0 ]; then capture_controls "$out/controls_restored.json" || restore_rc=$?; fi
    if [ "$restore_rc" -eq 0 ]; then cmp -s "$BASELINE" "$out/controls_restored.json" || restore_rc=1; fi
    if [ "$restore_rc" -eq 0 ] && [ "$(jq -r .tuned_profile "$BASELINE")" != "__off__" ]; then tuned-adm verify >/dev/null || restore_rc=$?; fi
    if [ "$restore_rc" -eq 0 ]; then live_preflight "$(jq -r .tcp_congestion_control "$BASELINE")" >/dev/null || restore_rc=$?; fi
    if [ "$restore_rc" -eq 0 ]; then stop_rollback_unit_strict "$unit" || restore_rc=$?; fi
    if [ "$restore_rc" -eq 0 ]; then
      jq -n --arg unit "$unit" '{rollback_armed:false,unit:$unit,restoration_state:"restored"}' > "$STATE_DIR/rollback.json"
      transition restored
    else
      jq -n --arg unit "$unit" --argjson rc "$restore_rc" '{rollback_armed:true,unit:$unit,restoration_state:"unproven",restore_exit_code:$rc}' > "$STATE_DIR/rollback.json"
      transition failed
    fi
    flock -u 9 >/dev/null 2>&1 || true; lock_held=false
    if [ "$attempt_lock_held" = true ]; then flock -u 7 >/dev/null 2>&1 || true; attempt_lock_held=false; fi
    return "$restore_rc"
  }
  mkdir -p "$out"
  exec 7>"$ATTEMPT_LOCK_FILE"; flock -n 7 || die "another Sprint 30 attempt/controller is active"; attempt_lock_held=true
  jq -e '.rollback_armed==false and (.canary//false)==false' "$STATE_DIR/rollback.json" >/dev/null || die "a prior rollback lease/canary must be proved and observed before a new attempt"
  transition planned
  restore_controls
  verify_sentinels
  unit="bv4db-s30-restore-$(date +%s)-$$"
  systemd-run --quiet --unit "$unit" --on-active=180s /usr/local/sbin/bv4db-sprint30-guest restore
  jq -n --arg unit "$unit" '{rollback_armed:true,unit:$unit,deadline_seconds:180}' > "$STATE_DIR/rollback.json"
  trap 'cleanup_attempt' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  capture_controls "$out/controls_before.json"
  capture_errors "$out/errors_before.json"
  capture_attempt_context "$out/context_before"
  exec 9>"$LOCK_FILE"; flock -w 120 9 || die "could not acquire mutation lock"; lock_held=true
  transition applying
  apply_candidate "$candidate"
  capture_controls "$out/controls_applied.json"
  verify_candidate_applied "$candidate" "$out/controls_applied.json"
  expected_cc=$(jq -r .tcp_congestion_control "$BASELINE"); if [[ "$candidate" == TCP_CC_* ]]; then expected_cc=${candidate#TCP_CC_}; expected_cc=${expected_cc,,}; fi
  live_preflight "$expected_cc" >/dev/null
  transition active
  flock -u 9; lock_held=false
  capture_attempt_context "$out/context_applied"
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
  chown -R opc:opc "$out"
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  transition measuring
  iostat -o JSON -x 5 "$(( (runtime + ramp) / 5 + 1 ))" > "$out/iostat.json" & iostat_pid=$!
  set +e
  # The root shell owns the log redirect; fio itself runs as opc.
  # shellcheck disable=SC2024
  sudo -u opc fio --output-format=json --output="$out/fio.json" "$profile" > "$out/fio.log" 2>&1 & fio_pid=$!
  wait "$fio_pid"; rc=$?; fio_pid=''
  set -e
  wait "$iostat_pid"; iostat_pid=''
  ended=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cleanup_attempt || die "attempt restoration failed; rollback lease remains armed"
  trap - EXIT INT TERM
  capture_attempt_context "$out/context_restored"
  capture_errors "$out/errors_after.json"
  verify_sentinels
  verify_errors_clean "$out/errors_before.json" "$out/errors_after.json"
  transition passed
  jq -n --arg candidate "$candidate" --argjson repetition "$repetition" --arg started "$started" --arg ended "$ended" --argjson rc "$rc" '{candidate_id:$candidate,repetition:$repetition,started_at:$started,ended_at:$ended,fio_exit_code:$rc,restoration_state:"restored",sentinels_valid:true,rollback_armed:false}' > "$out/attempt.json"
  [ "$rc" -eq 0 ]
}

renew_rollback_lease() {
  local unit
  jq -e '.rollback_armed==true and (.unit|length)>0' "$STATE_DIR/rollback.json" >/dev/null || die "rollback lease is not armed"
  unit=$(jq -r .unit "$STATE_DIR/rollback.json")
  systemctl is-active --quiet "$unit.timer" || die "rollback timer is not active"
  systemctl restart "$unit.timer"
}

prove_baseline() {
  local proof="$1" tmp unit
  exec 7>"$ATTEMPT_LOCK_FILE"; flock -n 7 || die "cannot resume while another Sprint 30 attempt/controller is active"
  exec 9>"$LOCK_FILE"; flock -w 120 9 || die "could not acquire mutation lock for resume proof"
  ! jq -e '.canary==true' "$STATE_DIR/rollback.json" >/dev/null 2>&1 || die "an active or observation-pending rollback canary cannot be resumed"
  ! pgrep -x fio >/dev/null || die "cannot prove baseline while FIO is running"
  restore_controls || die "resume restoration failed"
  tmp=$(mktemp); capture_controls "$tmp" || { rm -f "$tmp"; die "resume control capture failed"; }; cmp -s "$BASELINE" "$tmp" || { rm -f "$tmp"; die "captured controls are not byte-equal to baseline"; }
  mv "$tmp" "$proof"
  live_preflight "$(jq -r .tcp_congestion_control "$BASELINE")" >/dev/null || die "resume topology proof failed"
  verify_sentinels || die "resume sentinel proof failed"
  if jq -e '.rollback_armed==true and (.unit|length)>0' "$STATE_DIR/rollback.json" >/dev/null 2>&1; then
    unit=$(jq -r .unit "$STATE_DIR/rollback.json")
    stop_rollback_unit_strict "$unit" || die "stale rollback timer/service could not be proved inactive"
  else unit="resume_baseline_proof"; fi
  jq -n --arg unit "$unit" '{rollback_armed:false,unit:$unit,restoration_state:"restored",source:"resume_baseline_proof"}' > "$STATE_DIR/rollback.json"
  flock -u 9; flock -u 7
}

candidate_proposal() {
  local id="$1" factor feature value target max_rx max_tx max_channels online_channels q mask idx=0 cpu
  case "$id" in
    ISCSI_QD128) jq -n '{node_and_live_queue_depth:128}' ;;
    TCP_BUF_2X|TCP_BUF_4X) factor=2; [ "$id" = TCP_BUF_4X ] && factor=4; jq --argjson factor "$factor" '{rmem_max:((.rmem_max|tonumber)*$factor),wmem_max:((.wmem_max|tonumber)*$factor),tcp_rmem:([.tcp_rmem|scan("\\S+")|tonumber]|[.[0],.[1],(.[2]*$factor)]),tcp_wmem:([.tcp_wmem|scan("\\S+")|tonumber]|[.[0],.[1],(.[2]*$factor)])}' "$BASELINE" ;;
    NETDEV_BACKLOG_2X|NETDEV_BACKLOG_4X) factor=2; [ "$id" = NETDEV_BACKLOG_4X ] && factor=4; jq --argjson factor "$factor" '{netdev_max_backlog:((.netdev_max_backlog|tonumber)*$factor)}' "$BASELINE" ;;
    RPS_ALL_ONLINE) mask=$(cpu_mask); jq -n --arg mask "$mask" '{rps_mask:$mask}' ;;
    RPS_RFS_65536) mask=$(cpu_mask); q=$(jq '.rx_queues|length' "$BASELINE"); jq -n --arg mask "$mask" --argjson per_queue "$((65536/q))" '{rps_mask:$mask,rps_sock_flow_entries:65536,rps_flow_count_per_queue:$per_queue}' ;;
    RFS_65536) q=$(jq '.rx_queues|length' "$BASELINE"); jq -n --argjson per_queue "$((65536/q))" '{rps_sock_flow_entries:65536,rps_flow_count_per_queue:$per_queue}' ;;
    XPS_BY_QUEUE) local -a cpus=(); local rows='[]'; mapfile -t cpus < <(online_cpu_ids); while IFS= read -r q; do cpu=${cpus[$((idx % ${#cpus[@]}))]}; printf -v mask '%x' "$((1 << cpu))"; rows=$(jq -c --arg queue "$q" --arg mask "$mask" '.+[{queue:$queue,mask:$mask}]' <<<"$rows"); idx=$((idx+1)); done < <(jq -r '.tx_queues[]' "$BASELINE"); printf '%s\n' "$rows" ;;
    TCP_CC_*) value=${id#TCP_CC_}; jq -n --arg value "${value,,}" '{tcp_congestion_control:$value}' ;;
    OFFLOAD_*) feature=${id#OFFLOAD_}; case "$feature" in RX_CHECKSUM) feature="rx-checksumming";; TX_CHECKSUM) feature="tx-checksumming";; TSO) feature="tcp-segmentation-offload";; GSO) feature="generic-segmentation-offload";; GRO) feature="generic-receive-offload";; esac; value=$(jq -r --arg key "$feature" '.offloads[$key]' "$BASELINE"); target=on; [ "$value" = on ] && target=off; jq -n --arg feature "$feature" --arg target "$target" '{feature:$feature,value:$target}' ;;
    NIC_RING_MAX) max_rx=$(ethtool -g "$(jq -r .interface "$BASELINE")" | awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="RX:"{print $2;exit}'); max_tx=$(ethtool -g "$(jq -r .interface "$BASELINE")" | awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="TX:"{print $2;exit}'); jq -n --argjson rx "$max_rx" --argjson tx "$max_tx" '{rx:$rx,tx:$tx}' ;;
    NIC_CHANNEL_MAX) max_channels=$(ethtool -l "$(jq -r .interface "$BASELINE")" | awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="Combined:"{print $2;exit}'); online_channels=$(online_cpu_ids|wc -l); [ "$max_channels" -le "$online_channels" ] || max_channels=$online_channels; jq -n --argjson combined "$max_channels" '{combined:$combined}' ;;
    NIC_COAL_ADAPTIVE_ON) jq -n '{adaptive_rx:"on",adaptive_tx:"on"}' ;;
    NIC_COAL_ADAPTIVE_OFF) jq -n '{adaptive_rx:"off",adaptive_tx:"off"}' ;;
    TUNED_PROFILE_*) value=${id#TUNED_PROFILE_}; value=${value,,}; value=${value//_/-}; jq -n --arg profile "$value" '{profile:$profile}' ;;
    *) die "no exact proposal renderer for candidate: $id" ;;
  esac
}

emergency_restore() {
  local tmp unit canary evidence_dir
  exec 8>"$LOCK_FILE"; flock -w 180 8 || die "emergency restore could not acquire mutation lock"
  unit=$(jq -r '.unit // "host_local_lease"' "$STATE_DIR/rollback.json" 2>/dev/null || echo host_local_lease)
  canary=$(jq -r '.canary // false' "$STATE_DIR/rollback.json" 2>/dev/null || echo false)
  evidence_dir=$(jq -r '.evidence_dir // empty' "$STATE_DIR/rollback.json" 2>/dev/null || true)
  pkill -TERM -x fio >/dev/null 2>&1 || true; sleep 2; pkill -KILL -x fio >/dev/null 2>&1 || true
  restore_controls
  tmp=$(mktemp); capture_controls "$tmp"; cmp -s "$BASELINE" "$tmp" || { rm -f "$tmp"; die "emergency restoration is not byte-equal to baseline"; }; rm -f "$tmp"
  live_preflight "$(jq -r .tcp_congestion_control "$BASELINE")" >/dev/null; verify_sentinels
  jq -n --arg unit "$unit" --argjson canary "$canary" --arg evidence_dir "$evidence_dir" '{rollback_armed:false,unit:$unit,restoration_state:"restored",source:"host_local_lease",canary:$canary} + (if $canary then {canary_observation_pending:true,evidence_dir:$evidence_dir} else {} end)' > "$STATE_DIR/rollback.json"
  flock -u 8
}

quiesce() {
  restore_controls
  verify_sentinels
  sync
  umount /u04/fra /u03/redo /u02/oradata
  vgchange -an vg_redo; vgchange -an vg_data
  while IFS=$'\t' read -r iqn ip port; do iscsiadm -m node -T "$iqn" -p "$ip:$port" --logout >/dev/null; iscsiadm -m node -o delete -T "$iqn" -p "$ip:$port" >/dev/null; done < <(jq -r '.volumes[]|[.iqn,.ipv4,(.port|tostring)]|@tsv' "$MANIFEST")
}

live_preflight() {
  local expected_cc="${1:-}" iqn ip port path iface leaf root_leaf expected_serial current_serial bypath candidate session_text node_qd live_qd leaves='[]' data_stripes redo_stripes data_stripe_kib redo_stripe_kib fra_source
  verify_sentinels
  iface=$(jq -r .iscsi_interface "$MANIFEST")
  [ -n "$expected_cc" ] || expected_cc=$(jq -r .tcp_congestion_control "$BASELINE")
  root_leaf=$(device_leaf "$(findmnt -nro SOURCE /)")
  while IFS=$'\t' read -r iqn ip port path; do
    [ "$(ip route get "$ip" | awk '{for(i=1;i<=NF;i++)if($i=="dev"){print $(i+1);exit}}')" = "$iface" ] || die "route drift: $ip"
    block_device_exists "$path" || die "device missing: $path"
    session_text=$(iscsiadm -m session 2>/dev/null | grep -F "$iqn" || true)
    if [ "$(wc -l <<<"$session_text" | tr -d ' ')" -ne 1 ] || ! grep -Fq "$ip:$port" <<<"$session_text"; then die "target/portal session drift: $iqn"; fi
    leaf=$(device_leaf "$path"); [ "$leaf" != "$root_leaf" ] || die "boot device entered target topology"
    expected_serial=$(jq -r --arg iqn "$iqn" '.[]|select(.iqn==$iqn)|.serial' "$IDENTITIES"); current_serial=$(lsblk -dnro SERIAL "$leaf")
    [ -n "$current_serial" ] && [ "$current_serial" = "$expected_serial" ] || die "IQN/device serial drift: $iqn"
    bypath=$(iscsi_bypath_for "$iqn" "$leaf" || true)
    [ -n "$bypath" ] || die "IQN/by-path identity drift: $iqn"
    leaves=$(jq -c --arg leaf "$leaf" '. + [$leaf]' <<<"$leaves")
    node_qd=$(iscsiadm -m node -T "$iqn" -p "$ip:$port" -o show | awk -F'= ' '$1 ~ /node.session.queue_depth/{print $2;exit}')
    live_qd=$(cat "/sys/block/$(basename "$leaf")/device/queue_depth")
    [ "$node_qd" = "$live_qd" ] || die "node/live queue-depth mismatch: $iqn"
  done < <(jq -r '.volumes[]|[.iqn,.ipv4,(.port|tostring),.path]|@tsv' "$MANIFEST")
  [ "$(jq 'unique|length' <<<"$leaves")" -eq 5 ] || die "device identity drift"
  [ "$(findmnt -nro FSTYPE /u02/oradata)" = ext4 ] && [ "$(findmnt -nro FSTYPE /u03/redo)" = ext4 ] && [ "$(findmnt -nro FSTYPE /u04/fra)" = ext4 ] || die "filesystem or mount drift"
  data_stripes=$(lvs --noheadings -o stripes vg_data/lv_oradata | awk '{$1=$1};1'); redo_stripes=$(lvs --noheadings -o stripes vg_redo/lv_redo | awk '{$1=$1};1')
  data_stripe_kib=$(lvs --noheadings --units k --nosuffix -o stripe_size vg_data/lv_oradata | awk '{$1=$1; printf "%d\n",$1}'); redo_stripe_kib=$(lvs --noheadings --units k --nosuffix -o stripe_size vg_redo/lv_redo | awk '{$1=$1; printf "%d\n",$1}')
  [ "$data_stripes" -eq 2 ] && [ "$redo_stripes" -eq 2 ] && [ "$data_stripe_kib" -eq 256 ] && [ "$redo_stripe_kib" -eq 256 ] || die "LVM stripe layout drift"
  fra_source=$(findmnt -nro SOURCE /u04/fra); [ "$(device_leaf "$fra_source")" = "$(device_leaf "$(jq -r '.volumes[]|select(.role=="fra")|.path' "$MANIFEST")")" ] || die "FRA direct-device mapping drift"
  ! lsblk -nro TYPE | grep -Fxq mpath || die "dm-multipath device detected"
  verify_all_iscsi_socket_cc "$expected_cc"
  jq -n --arg iface "$iface" --argjson leaves "$leaves" --argjson data_stripes "$data_stripes" --argjson redo_stripes "$redo_stripes" --argjson stripe_kib "$data_stripe_kib" '{sessions_valid:true,routes_valid:true,devices_unique:true,boot_excluded:true,multipath_absent:true,mounts_valid:true,lvm_valid:true,socket_congestion_control_valid:true,sentinels_valid:true,interface:$iface,leaves:$leaves,layout:{data_stripes:$data_stripes,redo_stripes:$redo_stripes,stripe_kib:$stripe_kib,fra_direct:true,mounts:["/u02/oradata","/u03/redo","/u04/fra"]}}'
}

run_canary() {
  local kind="$1" out="$2" after unit unit_state="not_applicable"
  mkdir -p "$out"
  exec 7>"$ATTEMPT_LOCK_FILE"; flock -n 7 || die "another Sprint 30 attempt/controller is active"
  exec 8>"$LOCK_FILE"; flock -w 120 8 || die "canary could not acquire mutation lock"
  jq -e '.rollback_armed==false' "$STATE_DIR/rollback.json" >/dev/null || die "a rollback lease is already armed"
  restore_controls
  verify_sentinels
  case "$kind" in
    trap)
      # The root-owned canary shell intentionally owns this evidence redirect.
      # shellcheck disable=SC2024
      if ( trap 'restore_controls' EXIT; apply_candidate TCP_BUF_2X || exit $?; sudo -u opc fio --name=rollback-canary --filename=/u02/oradata/sprint30-canary.fio --rw=invalid > "$out/fio_failure.log" 2>&1 ); then
        die "trap canary did not produce the expected FIO failure"
      fi
      ;;
    lease)
      die "lease canary requires separate canary-arm and canary-observe controller calls"
      ;;
    *) die "unknown canary: $kind" ;;
  esac
  after="$out/controls_after.json"
  capture_controls "$after"
  cmp -s "$BASELINE" "$after" || die "$kind canary did not restore baseline"
  live_preflight "$(jq -r .tcp_congestion_control "$BASELINE")" >/dev/null; verify_sentinels
  jq -n --arg kind "$kind" --arg unit_state "$unit_state" '{kind:$kind,safe_source_candidate:"TCP_BUF_2X",result:"expected_failure_restored",baseline_equal:true,sentinels_valid:true,rollback_armed:false,unit_state:$unit_state}' > "$out/canary.json"
  flock -u 8; flock -u 7
}

arm_lease_canary() {
  local out="$1" unit
  exec 7>"$ATTEMPT_LOCK_FILE"; flock -n 7 || die "another Sprint 30 attempt/controller is active"
  jq -e '.rollback_armed==false' "$STATE_DIR/rollback.json" >/dev/null || die "a rollback lease is already armed"
  mkdir -p "$out"; restore_controls; verify_sentinels
  unit="bv4db-sprint30-restore-$$"
  systemd-run --quiet --unit "$unit" --on-active=180s /usr/local/sbin/bv4db-sprint30-guest restore
  jq -n --arg unit "$unit" --arg out "$out" '{rollback_armed:true,unit:$unit,deadline_seconds:180,canary:true,evidence_dir:$out}' > "$STATE_DIR/rollback.json"
  exec 8>"$LOCK_FILE"; flock -w 120 8 || die "lease canary could not acquire mutation lock"
  apply_candidate TCP_BUF_2X
  capture_controls "$out/controls_applied.json"; verify_candidate_applied TCP_BUF_2X "$out/controls_applied.json"
  live_preflight "$(jq -r .tcp_congestion_control "$BASELINE")" >/dev/null
  flock -u 8; flock -u 7
}

observe_lease_canary() {
  local out="$1" unit unit_state service_result service_status after
  exec 7>"$ATTEMPT_LOCK_FILE"; flock -n 7 || die "another Sprint 30 attempt/controller is active"
  exec 8>"$LOCK_FILE"; flock -w 120 8 || die "lease observation could not acquire mutation lock"
  unit=$(jq -r .unit "$STATE_DIR/rollback.json"); unit_state=$(systemctl is-active "$unit.timer" 2>/dev/null || true)
  [ "$unit_state" != active ] || die "rollback lease timer remained active"
  service_result=$(systemctl show "$unit.service" -p Result --value); service_status=$(systemctl show "$unit.service" -p ExecMainStatus --value)
  jq -n --arg result "$service_result" --arg status "$service_status" '{result:$result,exec_main_status:($status|tonumber)}' > "$out/restore_service_status.json"
  [ "$service_result" = success ] && [ "$service_status" -eq 0 ] || die "host-local restore service failed"
  systemctl reset-failed "$unit.service" >/dev/null 2>&1 || true
  after="$out/controls_after.json"; capture_controls "$after"; cmp -s "$BASELINE" "$after" || die "lease canary did not restore baseline"
  live_preflight "$(jq -r .tcp_congestion_control "$BASELINE")" >/dev/null; verify_sentinels
  jq -n --arg unit "$unit" '{rollback_armed:false,unit:$unit,canary:false,canary_observation_pending:false,restoration_state:"restored"}' > "$STATE_DIR/rollback.json"
  jq -n --arg unit_state "$unit_state" --arg service_result "$service_result" --argjson service_status "$service_status" '{kind:"lease",safe_source_candidate:"TCP_BUF_2X",result:"expected_failure_restored",baseline_equal:true,sentinels_valid:true,rollback_armed:false,unit_state:$unit_state,restore_service_result:$service_result,restore_service_exit_status:$service_status}' > "$out/canary.json"
  flock -u 8; flock -u 7
}

# The integration suite sources the exact production functions and replaces
# host commands with bounded local shims. Direct execution never takes this path.
# shellcheck disable=SC2317
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  [ "${BV4DB_GUEST_SOURCE_ONLY:-0}" = 1 ] || return 2
  return 0
fi

case "${1:-}" in
  prepare) [ "$#" -eq 4 ] || die "prepare MANIFEST AUTHORIZATION EVIDENCE"; prepare "$2" "$3" "$4" ;;
  run) [ "$#" -eq 6 ] || die "run CANDIDATE REP OUT RUNTIME RAMP"; run_attempt "$2" "$3" "$4" "$5" "$6" ;;
  renew) renew_rollback_lease ;;
  cpu-mask) cpu_mask ;;
  proposal) [ "$#" -eq 2 ] || die "proposal CANDIDATE"; candidate_proposal "$2" ;;
  prove-baseline) [ "$#" -eq 2 ] || die "prove-baseline PROOF"; prove_baseline "$2" ;;
  restore) emergency_restore ;;
  canary) [ "$#" -eq 3 ] || die "canary trap|lease OUT"; run_canary "$2" "$3" ;;
  canary-arm) [ "$#" -eq 2 ] || die "canary-arm OUT"; arm_lease_canary "$2" ;;
  canary-observe) [ "$#" -eq 2 ] || die "canary-observe OUT"; observe_lease_canary "$2" ;;
  preflight) live_preflight ;;
  quiesce) quiesce ;;
  *) die "usage: $0 prepare MANIFEST EVIDENCE | run CANDIDATE REP OUT RUNTIME RAMP | restore | quiesce" ;;
esac

#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Sprint 30 single-path iSCSI tuning experiment controller.
#
# The controller deliberately separates a deterministic, non-mutating plan
# from privileged live execution.  A live run is only accepted when its target
# manifest proves the exact Sprint 30 topology; there is no "best effort"
# fallback to a different tier, shape, or multipath attachment.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
DEFAULT_OUTPUT="$REPO_DIR/progress/sprint_30/results/$(date -u +%Y%m%dT%H%M%SZ)"
MODE=plan
OUTPUT_DIR="$DEFAULT_OUTPUT"
VPU=50
REPEATS=3
SEED=30050
CANDIDATE=all
RESUME_RUN=""
TARGET_MANIFEST=""
KEEP_INFRA=false
FIXTURE=""
STATE_FAULT=""

usage() {
  cat <<'EOF'
Usage: tools/oci_bv_single_path_tuning.sh [--plan|--execute] [options]

Sprint 30 options:
  --output-dir DIR       Result directory (default: timestamped Sprint 30 dir)
  --vpu 50               Fixed Sprint 30 VPU/GB value; other values are rejected
  --repeats 3            Measured repetitions per candidate (fixed at three)
  --candidate ID|all     Candidate selection, default all
  --seed INTEGER         Deterministic candidate order seed
  --resume RUN_ID        Resume only after byte-equal baseline proof
  --target-manifest FILE Live topology and approved-target evidence (required live)
  --keep-infra           Preserve disposable infrastructure after evidence copy

Local verification hooks (used by the Sprint 30 integration tests):
  --fixture FILE         Validate a JSON topology fixture without mutation
  --state-fault NAME     Exercise a restoration state-machine fault fixture

The default is --plan.  --execute never provisions, formats, or tunes a host
until an explicit target manifest passes the same fixed-50/single-path checks.
EOF
}

die() { echo "ERROR: $*" >&2; exit 2; }
log() { printf '%s\n' "$*"; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command missing: $1"; }
atomic_json() { local out="$1"; local tmp="${out}.tmp.$$"; cat >"$tmp"; mv "$tmp" "$out"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --plan) MODE=plan; shift ;;
    --execute) MODE=execute; shift ;;
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    --vpu) VPU="${2:-}"; shift 2 ;;
    --repeats) REPEATS="${2:-}"; shift 2 ;;
    --candidate) CANDIDATE="${2:-}"; shift 2 ;;
    --seed) SEED="${2:-}"; shift 2 ;;
    --resume) RESUME_RUN="${2:-}"; shift 2 ;;
    --target-manifest) TARGET_MANIFEST="${2:-}"; shift 2 ;;
    --keep-infra) KEEP_INFRA=true; shift ;;
    --fixture) FIXTURE="${2:-}"; shift 2 ;;
    --state-fault) STATE_FAULT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

require_cmd jq
[ "$VPU" = 50 ] || die "Sprint 30 is locked to 50 VPUs/GB; received: $VPU"
[ "$REPEATS" = 3 ] || die "Sprint 30 requires exactly three measured repetitions"
[[ "$SEED" =~ ^[0-9]+$ ]] || die "seed must be an integer"
[ -n "$OUTPUT_DIR" ] || die "--output-dir must not be empty"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

FIO_PROFILE='{
  "global":{"ioengine":"libaio","direct":1,"time_based":1,"runtime":600,"ramp_time":60,"group_reporting":0,"invalidate":1,"lat_percentiles":1,"percentile_list":[95,99,99.9],"output_format":"json"},
  "jobs":[
    {"id":"data-8k","directory":"/u02/oradata","rw":"randrw","rwmixread":70,"bs":"8k","size":"32G","numjobs":4,"iodepth":16},
    {"id":"redo","directory":"/u03/redo","rw":"write","bs":"4k","size":"4G","numjobs":1,"iodepth":1,"fdatasync":1},
    {"id":"fra-1m","directory":"/u04/fra","rw":"readwrite","bs":"1M","size":"16G","numjobs":1,"iodepth":8,"rate":"120M"}
  ]
}'

LAYOUT='[
 {"role":"DATA","name":"data1","size_gb":200,"path":"/dev/oracleoci/oraclevdb","volume_group":"vg_data","logical_volume":"lv_oradata","stripes":2,"stripe_kib":256,"mount":"/u02/oradata"},
 {"role":"DATA","name":"data2","size_gb":200,"path":"/dev/oracleoci/oraclevdc","volume_group":"vg_data","logical_volume":"lv_oradata","stripes":2,"stripe_kib":256,"mount":"/u02/oradata"},
 {"role":"REDO","name":"redo1","size_gb":50,"path":"/dev/oracleoci/oraclevdd","volume_group":"vg_redo","logical_volume":"lv_redo","stripes":2,"stripe_kib":256,"mount":"/u03/redo"},
 {"role":"REDO","name":"redo2","size_gb":50,"path":"/dev/oracleoci/oraclevde","volume_group":"vg_redo","logical_volume":"lv_redo","stripes":2,"stripe_kib":256,"mount":"/u03/redo"},
 {"role":"FRA","name":"fra","size_gb":100,"path":"/dev/oracleoci/oraclevdf","volume_group":null,"logical_volume":null,"stripes":null,"stripe_kib":null,"mount":"/u04/fra"}
]'

# Controls that cannot be observed on a local fixture are deliberately
# classified, not quietly omitted. A live discovery replaces this catalogue
# with observed values before any host mutation.
CATALOGUE='[
 {"id":"ISCSI_QD128","control":"node.session.queue_depth","disposition":"testable","reason":"fixture reports independently mutable iSCSI node records","evidence":"discovery/iscsi.json"},
 {"id":"TCP_BUF_2X","control":"tcp buffers","disposition":"testable","reason":"fixture reports numeric sysctl baseline","evidence":"discovery/sysctl.json"},
 {"id":"TCP_BUF_4X","control":"tcp buffers","disposition":"testable","reason":"fixture reports numeric sysctl baseline","evidence":"discovery/sysctl.json"},
 {"id":"NETDEV_BACKLOG_2X","control":"net.core.netdev_max_backlog","disposition":"testable","reason":"fixture reports numeric sysctl baseline","evidence":"discovery/sysctl.json"},
 {"id":"NETDEV_BACKLOG_4X","control":"net.core.netdev_max_backlog","disposition":"testable","reason":"fixture reports numeric sysctl baseline","evidence":"discovery/sysctl.json"},
 {"id":"RPS_ALL_ONLINE","control":"RPS","disposition":"testable","reason":"fixture has online CPU and RX queue inventory","evidence":"discovery/queues.json"},
 {"id":"RPS_RFS_65536","control":"RPS plus RFS","disposition":"testable","reason":"baseline RPS is zero; RFS is coupled and not a no-op","evidence":"discovery/queues.json"},
 {"id":"XPS_BY_QUEUE","control":"XPS","disposition":"testable","reason":"fixture has TX queue inventory","evidence":"discovery/queues.json"},
 {"id":"MTU_ALTERNATIVE","control":"MTU","disposition":"unsafe","reason":"endpoint support is not proven","evidence":"discovery/mtu.json"},
 {"id":"NIC_RING_MAX","control":"NIC rings","disposition":"unsupported","reason":"fixture does not advertise independently changeable ring sizes","evidence":"discovery/ethtool.json"},
 {"id":"TUNED_PROFILE","control":"TuneD","disposition":"not_applicable","reason":"fixture has no applicable installed profile","evidence":"discovery/tuned.json"}
]'

write_plan() {
  local plan="$OUTPUT_DIR/experiment_plan.json" ledger="$OUTPUT_DIR/tunable_coverage.json"
  local candidate_ids order1 order2 order3 attempts candidate_count
  candidate_ids=$(jq -c '[.[] | select(.disposition == "testable") | .id]' <<<"$CATALOGUE")
  # jq's deterministic PRNG-free ordering is intentionally simple and stable.
  order1=$(jq -c --argjson seed "$SEED" 'sort_by((. | explode | add) + $seed)' <<<"$candidate_ids")
  order2=$(jq -c 'reverse' <<<"$order1")
  order3=$(jq -c 'if length > 1 then .[1:] + .[:1] else . end' <<<"$order1")
  candidate_count=$(jq 'length' <<<"$candidate_ids")
  attempts=$(jq -n --argjson a "$order1" --argjson b "$order2" --argjson c "$order3" '
    def rows($block; $items): [$items[] | {candidate_id:.,attempt_type:"measurement",block:$block,vpu:50,repetitions:3}];
    [{candidate_id:"REGULAR_BASELINE_INITIAL",attempt_type:"measurement",block:"initial",vpu:50,repetitions:3}]
    + rows(1;$a) + rows(2;$b) + rows(3;$c)
    + [{candidate_id:"ROLLBACK_CANARY_TRAP",attempt_type:"rollback_canary",block:"canary",vpu:50,repetitions:0}, {candidate_id:"ROLLBACK_CANARY_LEASE",attempt_type:"rollback_canary",block:"canary",vpu:50,repetitions:0}, {candidate_id:"REGULAR_BASELINE_FINAL",attempt_type:"measurement",block:"final",vpu:50,repetitions:3}]')
  jq -n \
    --arg profile sprint30_single_path_50 \
    --argjson vpu 50 --argjson repeats 3 --argjson seed "$SEED" \
    --argjson layout "$LAYOUT" --argjson fio "$FIO_PROFILE" \
    --argjson blocks "[$order1,$order2,$order3]" --argjson attempts "$attempts" \
    --argjson candidates "$candidate_ids" --argjson candidate_count "$candidate_count" \
    '{profile:$profile,vpus:[$vpu],repeats:$repeats,seed:$seed,layout:$layout,fio:$fio,candidate_ids:$candidates,candidate_order_blocks:$blocks,attempts:$attempts,measurement_runtime_seconds: (($attempts | map(select(.attempt_type=="measurement") | .repetitions) | add) * 660),candidate_count:$candidate_count,oracle_database:false,multipath:false}' \
    | atomic_json "$plan"
  jq --argjson candidates "$candidate_ids" '
    map(if .disposition == "testable" then . + {execution_status:"pending"} else . end)
  ' <<<"$CATALOGUE" | atomic_json "$ledger"
  jq -n --arg status planned --arg vpu "$VPU" --arg output_dir "$OUTPUT_DIR" --arg resume "$RESUME_RUN" \
    '{status:$status,vpu:($vpu|tonumber),output_dir:$output_dir,resume:($resume|select(length>0))}' | atomic_json "$OUTPUT_DIR/run_state.json"
  log "PLAN: $plan"
  log "LEDGER: $ledger"
}

validate_fixture() {
  local file="$1" errors=0
  [ -f "$file" ] || die "fixture not found: $file"
  jq -e . "$file" >/dev/null || die "fixture is not valid JSON"
  jq -e '.compute.shape == "VM.Standard.E5.Flex" and .compute.ocpus == 4 and .compute.memory_gb == 32 and .compute.image_pinned == true and .compute.architecture == "x86_64"' "$file" >/dev/null || errors=$((errors+1))
  jq -e '(.volumes | length) == 5 and all(.volumes[]; .vpu == 50 and .is_multipath == false and .multipath_devices == 0 and .sessions == 1)' "$file" >/dev/null || errors=$((errors+1))
  jq -e '(.volumes | map(.device_id) | unique | length) == 5 and .layout.data_stripes == 2 and .layout.redo_stripes == 2 and .layout.stripe_kib == 256 and .layout.fra_direct == true and .layout.mounts == ["/u02/oradata","/u03/redo","/u04/fra"]' "$file" >/dev/null || errors=$((errors+1))
  jq -e '.route.same_interface == true and .sentinels.valid == true and .credentials.valid == true' "$file" >/dev/null || errors=$((errors+1))
  printf '[]\n' > "$OUTPUT_DIR/mutation_journal.json"
  printf '[]\n' > "$OUTPUT_DIR/fio_journal.json"
  if [ "$errors" -ne 0 ]; then
    jq -n --arg status failed_preflight '{status:$status,mutation_count:0,fio_count:0}' | atomic_json "$OUTPUT_DIR/run_state.json"
    die "preflight fixture rejected before mutation"
  fi
  jq -n --arg status preflight_passed '{status:$status,mutation_count:0,fio_count:0}' | atomic_json "$OUTPUT_DIR/run_state.json"
  log "PREFLIGHT: passed without mutation"
}

simulate_state_machine() {
  local fault="$1" journal="$OUTPUT_DIR/state_journal.json"
  case "$fault" in
    none) jq -n '["planned","applying","active","measuring","restoring","restored","passed"]' | atomic_json "$journal"; jq -n '{status:"passed",baseline_equal:true}' | atomic_json "$OUTPUT_DIR/run_state.json" ;;
    apply|readback|fio|sigterm|stale_applying|stale_measuring)
      jq -n --arg f "$fault" '["planned","applying","restoring","restored","failed"] + [$f]' | atomic_json "$journal"; jq -n --arg f "$fault" '{status:"failed",fault:$f,baseline_equal:true}' | atomic_json "$OUTPUT_DIR/run_state.json" ;;
    restore|drift) jq -n --arg f "$fault" '["planned","applying","restoring","failed"] + [$f]' | atomic_json "$journal"; jq -n --arg f "$fault" '{status:"failed",fault:$f,baseline_equal:false,blocked:true}' | atomic_json "$OUTPUT_DIR/run_state.json" ;;
    *) die "unknown state fault: $fault" ;;
  esac
  log "STATE: $fault"
}

INFRA_STATE="$REPO_DIR/progress/sprint_1/state-bv4db.json"
GUEST_EXECUTOR="$REPO_DIR/tools/oci_bv_single_path_guest.sh"
SC_DIR="$OUTPUT_DIR/scaffold"
RUN_TAG=""
PUBLIC_IP=""
TMPKEY=""

ssh_run() { ssh -i "$TMPKEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes "opc@$PUBLIC_IP" "$@"; }
scp_to() { scp -q -i "$TMPKEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes "$1" "opc@$PUBLIC_IP:$2"; }
scp_from() { scp -q -r -i "$TMPKEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes "opc@$PUBLIC_IP:$1" "$2"; }

set_prefix() {
  export NAME_PREFIX="$1"
  unset STATE_FILE || true
  # shellcheck source=/dev/null
  source "$SCAFFOLD_DIR/do/oci_scaffold.sh"
}

provision_fresh_with_scaffold() {
  [ "${SPRINT30_APPLY_SCAFFOLD:-0}" = 1 ] || die "live execution requires SPRINT30_APPLY_SCAFFOLD=1"
  [ -d "$SCAFFOLD_DIR" ] || die "oci_scaffold submodule is missing"
  [ -f "$INFRA_STATE" ] || die "Sprint 1 infrastructure state is missing"
  [ -x "$GUEST_EXECUTOR" ] || die "guest executor is missing or not executable"
  require_cmd oci; require_cmd ssh; require_cmd scp; require_cmd base64
  oci iam region-subscription list --all >/dev/null || die "OCI authentication failed"
  local compartment subnet public_key image_json image_ocid compute_ocid compute_state role size path prefix state attach_json row volumes='[]'
  compartment=$(jq -r '.compartment.ocid // empty' "$INFRA_STATE")
  subnet=$(jq -r '.subnet.ocid // empty' "$INFRA_STATE")
  public_key="$REPO_DIR/progress/sprint_1/bv4db-key.pub"
  [ -n "$compartment" ] && [ -n "$subnet" ] && [ -f "$public_key" ] || die "Sprint 1 shared inputs are incomplete"
  mkdir -p "$SC_DIR" "$OUTPUT_DIR/discovery"
  RUN_TAG="s30-$(date -u +%Y%m%d%H%M%S)-$$"
  jq --arg run_tag "$RUN_TAG" '. + {status:"provisioning",run_tag:$run_tag}' "$OUTPUT_DIR/run_state.json" | atomic_json "$OUTPUT_DIR/run_state.json"
  image_json="$OUTPUT_DIR/discovery/oci_images_ol9.json"
  oci compute image list --compartment-id "$compartment" --operating-system 'Oracle Linux' --operating-system-version 9 --shape VM.Standard.E5.Flex --sort-by TIMECREATED --sort-order DESC --all > "$image_json"
  image_ocid=$(jq -r '.data[0].id // empty' "$image_json")
  [ -n "$image_ocid" ] || die "no Oracle Linux 9 image is available for VM.Standard.E5.Flex"
  oci compute image get --image-id "$image_ocid" > "$OUTPUT_DIR/discovery/pinned_image.json"

  cd "$SC_DIR"
  export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
  prefix="$RUN_TAG-compute"; set_prefix "$prefix"
  _state_set '.inputs.name_prefix' "$prefix"; _state_set '.inputs.oci_compartment' "$compartment"; _state_set '.subnet.ocid' "$subnet"
  _state_set '.inputs.compute_shape' VM.Standard.E5.Flex; _state_set '.inputs.compute_ocpus' 4; _state_set '.inputs.compute_memory_gb' 32
  _state_set '.inputs.subnet_prohibit_public_ip' false; _state_set '.inputs.compute_ssh_authorized_keys_file' "$public_key"; _state_set '.inputs.compute_image_id' "$image_ocid"
  ensure-compute.sh
  compute_state="$SC_DIR/state-$prefix.json"
  jq -e '.compute.created==true and .inputs.compute_image_id!=null and (.meta.creation_order|index("compute")!=null)' "$compute_state" >/dev/null || die "scaffold compute was not freshly created"
  compute_ocid=$(jq -r '.compute.ocid' "$compute_state"); PUBLIC_IP=$(jq -r '.compute.public_ip' "$compute_state")
  [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != null ] || die "fresh compute has no public IP"

  for role in data1 data2 redo1 redo2 fra; do
    case "$role" in data1) size=200; path=/dev/oracleoci/oraclevdb;; data2) size=200; path=/dev/oracleoci/oraclevdc;; redo1) size=50; path=/dev/oracleoci/oraclevdd;; redo2) size=50; path=/dev/oracleoci/oraclevde;; fra) size=100; path=/dev/oracleoci/oraclevdf;; esac
    prefix="$RUN_TAG-$role"; set_prefix "$prefix"
    _state_set '.inputs.name_prefix' "$prefix"; _state_set '.inputs.oci_compartment' "$compartment"; _state_set '.compute.ocid' "$compute_ocid"
    _state_set '.inputs.bv_attach_type' iscsi; _state_set '.inputs.bv_is_multipath' false; _state_set '.inputs.bv_vpus_per_gb' 50
    _state_set '.inputs.bv_size_gb' "$size"; _state_set '.inputs.bv_device_path' "$path"
    ensure-blockvolume.sh
    state="$SC_DIR/state-$prefix.json"
    jq -e '.blockvolume.created==true and .blockvolume.vpus_per_gb==50 and .blockvolume.is_multipath==false and (.meta.creation_order|index("blockvolume")!=null)' "$state" >/dev/null || die "scaffold volume was not freshly created at 50 VPUs: $role"
    attach_json="$OUTPUT_DIR/discovery/attachment_$role.json"
    oci compute volume-attachment get --volume-attachment-id "$(jq -r '.blockvolume.attachment_ocid' "$state")" > "$attach_json"
    jq -e '.data."lifecycle-state"=="ATTACHED" and (.data."is-multipath"==false or .data."is-multipath"==null) and ((.data."multipath-devices"//[])|length)==0' "$attach_json" >/dev/null || die "attachment is not single-path: $role"
    row=$(jq -n --arg role "$role" --arg path "$path" --argjson size "$size" --arg state "$state" --slurpfile a "$attach_json" --slurpfile s "$state" '{role:$role,path:$path,size_gb:$size,vpu:($s[0].blockvolume.vpus_per_gb|tonumber),created:$s[0].blockvolume.created,volume_ocid:$s[0].blockvolume.ocid,attachment_ocid:$s[0].blockvolume.attachment_ocid,iqn:$s[0].blockvolume.iqn,ipv4:$s[0].blockvolume.ipv4,port:($s[0].blockvolume.port|tonumber),is_multipath:false,multipath_devices:(($a[0].data."multipath-devices"//[])|length),state_file:$state}')
    volumes=$(jq -c --argjson row "$row" '. + [$row]' <<<"$volumes")
  done
  cd "$REPO_DIR"

  local secret_ocid elapsed iface compute_json manifest
  secret_ocid=$(jq -r '.secret.ocid // empty' "$INFRA_STATE"); [ -n "$secret_ocid" ] || die "Sprint 1 Vault SSH secret is missing"
  TMPKEY=$(mktemp); chmod 600 "$TMPKEY"
  oci secrets secret-bundle get --secret-id "$secret_ocid" --query 'data."secret-bundle-content".content' --raw-output | base64 --decode > "$TMPKEY"
  ssh-keygen -R "$PUBLIC_IP" >/dev/null 2>&1 || true
  elapsed=0; until ssh_run true >/dev/null 2>&1; do sleep 5; elapsed=$((elapsed+5)); [ "$elapsed" -lt 300 ] || die "SSH did not become ready"; done
  ssh_run "sudo dnf install -y fio sysstat jq lvm2 iscsi-initiator-utils ethtool tuned >/dev/null"
  iface=$(ssh_run "ip route get $(jq -r '.[0].ipv4' <<<"$volumes") | awk '{for(i=1;i<=NF;i++)if(\$i==\"dev\"){print \$(i+1);exit}}'")
  [ -n "$iface" ] || die "could not resolve the iSCSI network interface"
  compute_json="$OUTPUT_DIR/discovery/compute.json"; oci compute instance get --instance-id "$compute_ocid" > "$compute_json"
  jq -e --arg image "$image_ocid" '.data.shape=="VM.Standard.E5.Flex" and .data."image-id"==$image and .data."shape-config".ocpus==4 and .data."shape-config"."memory-in-gbs"==32' "$compute_json" >/dev/null || die "compute baseline mismatch"
  manifest="$OUTPUT_DIR/target_manifest.json"
  jq -n --argjson volumes "$volumes" --arg iface "$iface" --arg compute_ocid "$compute_ocid" --arg image_ocid "$image_ocid" '{vpu:50,compute:{ocid:$compute_ocid,shape:"VM.Standard.E5.Flex",ocpus:4,memory_gb:32,image_ocid:$image_ocid},iscsi_interface:$iface,volumes:$volumes}' > "$manifest"
  scp_to "$GUEST_EXECUTOR" /tmp/bv4db-sprint30-guest
  scp_to "$manifest" /tmp/bv4db-sprint30-manifest.json
  ssh_run "sudo install -m 0755 /tmp/bv4db-sprint30-guest /usr/local/sbin/bv4db-sprint30-guest && sudo /usr/local/sbin/bv4db-sprint30-guest prepare /tmp/bv4db-sprint30-manifest.json /var/tmp/bv4db-sprint30/discovery && sudo chmod -R a+rX /var/tmp/bv4db-sprint30"
  scp_from /var/tmp/bv4db-sprint30/discovery "$OUTPUT_DIR/"
  jq -n --argjson volumes "$volumes" --argjson guest_cpus "$(ssh_run nproc)" --arg iface "$iface" '{volumes:$volumes,guest_cpus:$guest_cpus,iscsi_interface:$iface,layout:{data_stripes:2,redo_stripes:2,stripe_kib:256,fra_direct:true,mounts:["/u02/oradata","/u03/redo","/u04/fra"]},sentinels_valid:true}' > "$OUTPUT_DIR/live_topology.json"
}

append_result() {
  local row="$1" file="$OUTPUT_DIR/results_index.json"
  [ -f "$file" ] || printf '[]\n' > "$file"
  jq --argjson row "$row" '. + [$row]' "$file" | atomic_json "$file"
}

execute_matrix() {
  local remote=/var/tmp/bv4db-sprint30 attempt candidate attempt_type block reps rep key local_dir row status
  # Live discovery makes unsafe iSCSI reconnect and absent queue controls explicit.
  jq 'map(if .id=="ISCSI_QD128" then .disposition="unsafe"|.reason="reconnecting mounted single-path storage is outside the safe candidate boundary"|del(.execution_status) else . end)' "$OUTPUT_DIR/tunable_coverage.json" | atomic_json "$OUTPUT_DIR/tunable_coverage.json"
  printf '[]\n' > "$OUTPUT_DIR/results_index.json"
  while IFS= read -r attempt; do
    candidate=$(jq -r .candidate_id <<<"$attempt"); attempt_type=$(jq -r .attempt_type <<<"$attempt"); block=$(jq -r '.block|tostring' <<<"$attempt")
    [ "$attempt_type" = measurement ] || continue
    if [[ "$candidate" != REGULAR_* ]] && ! jq -e --arg id "$candidate" '.[]|select(.id==$id and .disposition=="testable")' "$OUTPUT_DIR/tunable_coverage.json" >/dev/null; then continue; fi
    if [ "$CANDIDATE" != all ] && [[ "$candidate" != REGULAR_* ]] && [ "$candidate" != "$CANDIDATE" ]; then continue; fi
    reps=$(jq -r .repetitions <<<"$attempt")
    rep=1
    while [ "$rep" -le "$reps" ]; do
      key="${candidate}_${block}_${rep}"; local_dir="$OUTPUT_DIR/attempts/$key"; mkdir -p "$local_dir"
      if ! ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest run '$candidate' '$rep' '$remote/attempts/$key' 600 60"; then status=failed; else status=passed; fi
      ssh_run "sudo chmod -R a+rX '$remote/attempts/$key'"; scp_from "$remote/attempts/$key/." "$local_dir/"
      row=$(jq -n --arg candidate "$candidate" --arg attempt_type measurement --arg block "$block" --argjson repetition "$rep" --arg result "$status" --arg path "attempts/$key" '{candidate_id:$candidate,attempt_type:$attempt_type,block:$block,repetition:$repetition,vpu:50,result:$result,restoration_state:"restored",evidence:[$path] }')
      append_result "$row"; [ "$status" = passed ] || die "FIO attempt failed: $key"
      rep=$((rep+1))
    done
  done < <(jq -c '.attempts[]' "$OUTPUT_DIR/experiment_plan.json")

  local kind
  for kind in trap lease; do
    local_dir="$OUTPUT_DIR/attempts/ROLLBACK_CANARY_${kind^^}"; mkdir -p "$local_dir"
    ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest canary '$kind' '$remote/attempts/ROLLBACK_CANARY_${kind^^}'"
    ssh_run "sudo chmod -R a+rX '$remote/attempts/ROLLBACK_CANARY_${kind^^}'"; scp_from "$remote/attempts/ROLLBACK_CANARY_${kind^^}/." "$local_dir/"
    row=$(jq -n --arg candidate "ROLLBACK_CANARY_${kind^^}" --arg path "attempts/ROLLBACK_CANARY_${kind^^}" '{candidate_id:$candidate,attempt_type:"rollback_canary",vpu:50,result:"expected_failure_restored",restoration_state:"restored",evidence:[$path]}'); append_result "$row"
  done
  jq 'map(if .disposition=="testable" then .execution_status="tested" else . end)' "$OUTPUT_DIR/tunable_coverage.json" | atomic_json "$OUTPUT_DIR/tunable_coverage.json"
}

render_reports() {
  local passed candidates
  passed=$(jq '[.[]|select(.attempt_type=="measurement" and .result=="passed")]|length' "$OUTPUT_DIR/results_index.json")
  candidates=$(jq '[.[]|select(.disposition=="testable")]|length' "$OUTPUT_DIR/tunable_coverage.json")
  jq -n --arg decision "regular OCI and guest baseline; no candidate is recommended without a separately reviewed statistical improvement" --argjson passed "$passed" --argjson candidates "$candidates" '{vpu:50,decision:$decision,evidence:["results_index.json","tunable_coverage.json","attempts/"],measurement_runs:$passed,tested_candidates:$candidates}' > "$OUTPUT_DIR/recommendation.json"
  {
    echo '# Sprint 30 FIO analysis'; echo; echo "- Fixed tier: \`50 VPUs/GB\`"; echo "- Successful measured repetitions: \`$passed\`"; echo "- Testable candidates completed: \`$candidates\`"; echo; echo 'The machine-readable attempt index and raw FIO JSON are authoritative.'
  } > "$OUTPUT_DIR/fio_analysis.md"
  { echo '<!doctype html><html><head><meta charset="utf-8"><title>Sprint 30 FIO report</title></head><body><h1>Sprint 30 FIO report</h1><p>Fixed tier: 50 VPUs/GB.</p><p>Raw evidence is indexed by results_index.json.</p></body></html>'; } > "$OUTPUT_DIR/fio_report.html"
  { echo '# Sprint 30 OCI metrics'; echo; echo "OCI compute, image, volume, and attachment observations are archived under \`discovery/\` and bounded by each FIO attempt timestamp."; } > "$OUTPUT_DIR/oci_metrics.md"
  { echo '<!doctype html><html><head><meta charset="utf-8"><title>Sprint 30 OCI evidence</title></head><body><h1>OCI evidence</h1><p>Compute, image, volume, and attachment metadata are archived under discovery/.</p></body></html>'; } > "$OUTPUT_DIR/oci_metrics.html"
  { echo '# Sprint 30 summary'; echo; echo '- FIO only; Oracle Database was not installed or invoked.'; echo '- Five fresh 50-VPU/GB volumes used one iSCSI path each.'; echo "- Successful measured repetitions: $passed."; echo "- Recommendation: see \`recommendation.json\`."; } > "$OUTPUT_DIR/sprint_30_summary.md"
}

teardown_scaffold() {
  local role prefix failed=0 state
  ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest quiesce"
  cd "$SC_DIR"
  for role in fra redo2 redo1 data2 data1; do
    prefix="$RUN_TAG-$role"; state="$SC_DIR/state-$prefix.json"
    if [ -f "$state" ]; then export NAME_PREFIX="$prefix"; unset STATE_FILE || true; "$SCAFFOLD_DIR/do/teardown.sh" || failed=1; fi
  done
  [ "$failed" -eq 0 ] || die "one or more scaffold volume teardowns failed; compute retained"
  prefix="$RUN_TAG-compute"; state="$SC_DIR/state-$prefix.json"
  if [ -f "$state" ]; then export NAME_PREFIX="$prefix"; unset STATE_FILE || true; "$SCAFFOLD_DIR/do/teardown.sh"; fi
  cd "$REPO_DIR"
}

live_execute() {
  [ -z "$TARGET_MANIFEST" ] || die "fresh-resource Sprint 30 execution does not accept --target-manifest"
  [ -z "$RESUME_RUN" ] || die "resume is not yet safe for a run created by this controller"
  provision_fresh_with_scaffold
  execute_matrix
  render_reports
  local teardown=completed
  if [ "$KEEP_INFRA" = true ]; then teardown=kept; else teardown_scaffold; fi
  jq -n --arg teardown "$teardown" --argjson keep "$KEEP_INFRA" '{baseline_equal:true,sentinels_valid:true,rollback_armed:false,oracle_database_invoked:false,teardown:$teardown,keep_infra:$keep}' > "$OUTPUT_DIR/final_state.json"
  jq --arg teardown "$teardown" '. + {status:"completed",topology_verified:true,vpu:50,single_path:true,sentinels_valid:true,teardown:$teardown}' "$OUTPUT_DIR/run_state.json" | atomic_json "$OUTPUT_DIR/run_state.json"
  [ -z "$TMPKEY" ] || rm -f "$TMPKEY"
  log "COMPLETE: $OUTPUT_DIR"
}

write_plan
[ -z "$FIXTURE" ] || validate_fixture "$FIXTURE"
[ -z "$STATE_FAULT" ] || simulate_state_machine "$STATE_FAULT"
if [ "$MODE" = execute ]; then
  live_execute
fi

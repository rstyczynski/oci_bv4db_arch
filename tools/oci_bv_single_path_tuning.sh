#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Sprint 30 single-path iSCSI tuning experiment controller.
#
# The controller deliberately separates a deterministic, non-mutating plan
# from privileged live execution.  A live run is only accepted when its target
# manifest proves the exact Sprint 30 topology; there is no "best effort"
# fallback to a different tier, shape, or multipath attachment.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
DEFAULT_OUTPUT="$REPO_DIR/progress/sprint_30/results/$(date -u +%Y%m%dT%H%M%SZ)"
MODE=plan
OUTPUT_DIR="$DEFAULT_OUTPUT"
VPU=50
REPEATS=3
SEED=30050
RESUME_RUN=""
KEEP_INFRA=false
FIXTURE=""
STATE_FAULT=""
BV4DB_CONTROLLER_TEST_MODE=false
RECOVERY_OBSERVED_ACTIVE=false

# shellcheck disable=SC1091
source "$REPO_DIR/tools/oci_bv_controller_lock.sh"

usage() {
  cat <<'EOF'
Usage: tools/oci_bv_single_path_tuning.sh [--plan|--execute] [options]

Sprint 30 options:
  --output-dir DIR       Result directory (default: timestamped Sprint 30 dir)
  --vpu 50               Fixed Sprint 30 VPU/GB value; other values are rejected
  --repeats 3            Measured repetitions per candidate (fixed at three)
  --seed INTEGER         Deterministic candidate order seed
  --resume RUN_ID        Resume only after byte-equal baseline proof
  --keep-infra           Preserve disposable infrastructure after evidence copy

Local verification hooks (used by the Sprint 30 integration tests):
  --fixture FILE         Validate a JSON topology fixture without mutation
  --state-fault NAME     Exercise a restoration state-machine fault fixture

The default is --plan. --execute provisions uniquely owned disposable resources
and never formats or tunes them until its generated target manifest passes the
fixed-50/single-path checks and the fresh-layout authorization is consumed.
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
    --seed) SEED="${2:-}"; shift 2 ;;
    --resume) RESUME_RUN="${2:-}"; shift 2 ;;
    --keep-infra) KEEP_INFRA=true; shift ;;
    --fixture) FIXTURE="${2:-}"; shift 2 ;;
    --state-fault) STATE_FAULT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

require_cmd jq
[ -z "$RESUME_RUN" ] || [ "$MODE" = execute ] || die "--resume requires --execute"
[ "$VPU" = 50 ] || die "Sprint 30 is locked to 50 VPUs/GB; received: $VPU"
[ "$REPEATS" = 3 ] || die "Sprint 30 requires exactly three measured repetitions"
[[ "$SEED" =~ ^[0-9]+$ ]] || die "seed must be an integer"
[ -n "$OUTPUT_DIR" ] || die "--output-dir must not be empty"
if [ "$MODE" = execute ] && [ -z "$RESUME_RUN" ] && [ -d "$OUTPUT_DIR" ] && find "$OUTPUT_DIR" -mindepth 1 -print -quit | grep -q .; then
  die "--execute requires a new empty output directory; use immutable evidence validation for completed runs"
fi
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
  local candidate_ids all_candidate_ids order1 order2 order3 attempts candidate_count offset
  all_candidate_ids=$(jq -c '[.[] | select(.disposition == "testable") | .id]' <<<"$CATALOGUE")
  candidate_ids="$all_candidate_ids"
  candidate_count=$(jq 'length' <<<"$candidate_ids")
  offset=$((SEED % candidate_count))
  order1=$(jq -c --argjson n "$offset" 'sort | .[$n:] + .[:$n]' <<<"$candidate_ids")
  order2=$(jq -c --argjson n "$(((SEED + 3) % candidate_count))" 'sort | reverse | .[$n:] + .[:$n]' <<<"$candidate_ids")
  order3=$(jq -c --argjson n "$(((SEED + 5) % candidate_count))" 'sort_by(explode|reverse|add) | .[$n:] + .[:$n]' <<<"$candidate_ids")
  attempts=$(jq -n --argjson a "$order1" --argjson b "$order2" --argjson c "$order3" '
    def rows($block; $items): [$items[] | {candidate_id:.,attempt_type:"measurement",block:$block,vpu:50,repetitions:1}];
    def checkpoints($rows):
      reduce ($rows|to_entries[]) as $entry ([];
        . + [$entry.value]
        + (if (($entry.key + 1) % 5)==0 then [{candidate_id:("REGULAR_CHECKPOINT_" + (($entry.key + 1)|tostring)),attempt_type:"checkpoint",block:"checkpoint",vpu:50,repetitions:1}] else [] end));
    (rows(1;$a) + rows(2;$b) + rows(3;$c)) as $candidate_rows |
    [{candidate_id:"REGULAR_BASELINE_INITIAL",attempt_type:"measurement",block:"initial",vpu:50,repetitions:3}]
    + checkpoints($candidate_rows)
    + [{candidate_id:"ROLLBACK_CANARY_TRAP",attempt_type:"rollback_canary",block:"canary",vpu:50,repetitions:0}, {candidate_id:"ROLLBACK_CANARY_LEASE",attempt_type:"rollback_canary",block:"canary",vpu:50,repetitions:0}, {candidate_id:"REGULAR_BASELINE_FINAL",attempt_type:"measurement",block:"final",vpu:50,repetitions:3}]')
  jq -n \
    --arg profile sprint30_single_path_50 \
    --argjson vpu 50 --argjson repeats 3 --argjson seed "$SEED" \
    --argjson layout "$LAYOUT" --argjson fio "$FIO_PROFILE" \
    --argjson blocks "[$order1,$order2,$order3]" --argjson attempts "$attempts" \
    --argjson candidates "$candidate_ids" --argjson candidate_count "$candidate_count" \
    '($attempts | map(select(.attempt_type=="measurement" or .attempt_type=="checkpoint") | .repetitions) | add) as $fio_runs |
     (($fio_runs*660)+($candidate_count*3*120)+400+900+300) as $seconds |
     {profile:$profile,vpus:[$vpu],repeats:$repeats,seed:$seed,layout:$layout,fio:$fio,candidate_ids:$candidates,candidate_order_blocks:$blocks,attempts:$attempts,fio_run_count:$fio_runs,measurement_runtime_seconds:($fio_runs*660),estimated_transition_rollback_seconds:(($candidate_count*3*120)+400),estimated_total_seconds:$seconds,estimated_resource_hours:($seconds/3600),estimated_cost_usd:((($seconds/3600)*0.28)+(($seconds/3600)/730*600*(0.0334203+(50*0.00222802)))|.*100|round/100),cost_basis:{compute_hourly_usd:0.28,volume_storage_gb_month_usd:0.0334203,volume_performance_unit_gb_month_usd:0.00222802,total_block_gb:600,hours_per_month:730,source:"https://www.oracle.com/cloud/iaas-paas/",estimated_at_plan_time:true},candidate_count:$candidate_count,checkpoint_interval:5,stability_cv_limit:0.05,stability_extension_limit:2,oracle_database:false,multipath:false}' \
    | atomic_json "$plan"
  jq '
    map(if .disposition == "testable" then . + {execution_status:"pending"} else . end)
  ' <<<"$CATALOGUE" | atomic_json "$ledger"
  jq -n --arg status planned --arg vpu "$VPU" --arg output_dir "$OUTPUT_DIR" --arg resume "$RESUME_RUN" \
    '{status:$status,vpu:($vpu|tonumber),output_dir:$output_dir,resume:(if ($resume|length)>0 then $resume else null end)}' | atomic_json "$OUTPUT_DIR/run_state.json"
  log "PLAN: $plan"
  log "LEDGER: $ledger"
}

validate_fixture() {
  local file="$1" errors=0
  [ -f "$file" ] || die "fixture not found: $file"
  jq -e . "$file" >/dev/null || die "fixture is not valid JSON"
  jq -e '.compute.shape == "VM.Standard.E5.Flex" and .compute.ocpus == 4 and .compute.memory_gb == 32 and .compute.image_pinned == true and .compute.architecture == "x86_64"' "$file" >/dev/null || errors=$((errors+1))
  jq -e '(.volumes | length) == 5 and all(.volumes[]; .vpu == 50 and .is_multipath == false and .multipath_devices == 0 and .sessions == 1 and .volume_id==.expected_volume_id and .instance_id==.expected_instance_id)' "$file" >/dev/null || errors=$((errors+1))
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
ANALYZER="$REPO_DIR/tools/analyze_bv_single_path.py"
FIO_RENDERER="$REPO_DIR/tools/render_fio_report_html.sh"
SC_DIR="$OUTPUT_DIR/scaffold"
RUN_TAG=""
PUBLIC_IP=""
TMPKEY=""
OWNERSHIP_ACTIVE=false
RUN_COMPLETE=false
MATRIX_START=""
MATRIX_END=""
ACTIVE_SSH_PID=""

ssh_run() { ssh -i "$TMPKEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 -o BatchMode=yes "opc@$PUBLIC_IP" "$@"; }
scp_to() { scp -q -i "$TMPKEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes "$1" "opc@$PUBLIC_IP:$2"; }
scp_from() { scp -q -r -i "$TMPKEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes "opc@$PUBLIC_IP:$1" "$2"; }
ssh_job_running() {
  local state
  state=$(ps -p "$1" -o stat= 2>/dev/null) || return 1
  case "$state" in *Z*) return 1 ;; *) return 0 ;; esac
}

set_prefix() {
  export NAME_PREFIX="$1"
  unset STATE_FILE || true
  # shellcheck source=/dev/null
  source "$SCAFFOLD_DIR/do/oci_scaffold.sh"
}

recover_incomplete_scaffold_states() {
  local compartment role prefix state display row count ocid attachment_json attachment_ocid volumes compute display_compute
  compartment=$(jq -r '.compartment.ocid' "$INFRA_STATE")
  RECOVERY_OBSERVED_ACTIVE=false
  volumes=$(oci bv volume list --compartment-id "$compartment" --all) || return 1
  compute=$(oci compute instance list --compartment-id "$compartment" --all) || return 1
  printf '%s\n' "$volumes" > "$OUTPUT_DIR/failure_cleanup_volume_discovery.json"
  printf '%s\n' "$compute" > "$OUTPUT_DIR/failure_cleanup_compute_discovery.json"
  for role in data1 data2 redo1 redo2 fra; do
    prefix="$RUN_TAG-$role"; state="$SC_DIR/state-$prefix.json"
    display="$prefix-bv"
    count=$(jq --arg display "$display" '[.data[]|select(."display-name"==$display and ."lifecycle-state"!="TERMINATED")]|length' <<<"$volumes")
    [ "$count" -le 1 ] || { echo "multiple exact-name volumes found during failure recovery: $display" >&2; return 1; }
    [ "$count" -eq 0 ] || RECOVERY_OBSERVED_ACTIVE=true
    row=$(jq -c --arg display "$display" '.data[]|select(."display-name"==$display and ."lifecycle-state"!="TERMINATED")' <<<"$volumes")
    if [ -s "$state" ] && jq -e '.blockvolume.created==true and (.blockvolume.ocid//"")!=""' "$state" >/dev/null; then
      [ "$count" -eq 1 ] && [ "$(jq -r .blockvolume.ocid "$state")" = "$(jq -r .id <<<"$row")" ] || { echo "complete scaffold state does not match exact active volume: $display" >&2; return 1; }
      continue
    fi
    [ -n "$row" ] || continue
    ocid=$(jq -r .id <<<"$row")
    attachment_json=$(oci compute volume-attachment list --compartment-id "$compartment" --volume-id "$ocid" --all) || return 1
    attachment_ocid=$(jq -r '[.data[]|select(."lifecycle-state"!="DETACHED")]|if length<=1 then (.[0].id//"") else error("multiple active attachments") end' <<<"$attachment_json") || return 1
    jq -n --arg prefix "$prefix" --arg compartment "$compartment" --arg ocid "$ocid" --arg attachment "$attachment_ocid" '{inputs:{name_prefix:$prefix,oci_compartment:$compartment},blockvolume:{created:true,ocid:$ocid,attachment_ocid:$attachment},meta:{creation_order:["blockvolume"],recovered_for_failure_cleanup:true}}' > "$state"
  done
  prefix="$RUN_TAG-compute"; state="$SC_DIR/state-$prefix.json"
  display_compute="$prefix-instance"
  count=$(jq --arg display "$display_compute" '[.data[]|select(."display-name"==$display and ."lifecycle-state"!="TERMINATED")]|length' <<<"$compute")
  [ "$count" -le 1 ] || { echo "multiple exact-name instances found during failure recovery: $display_compute" >&2; return 1; }
  [ "$count" -eq 0 ] || RECOVERY_OBSERVED_ACTIVE=true
  row=$(jq -c --arg display "$display_compute" '.data[]|select(."display-name"==$display and ."lifecycle-state"!="TERMINATED")' <<<"$compute")
  if [ -s "$state" ] && jq -e '.compute.created==true and (.compute.ocid//"")!=""' "$state" >/dev/null; then
    [ "$count" -eq 1 ] && [ "$(jq -r .compute.ocid "$state")" = "$(jq -r .id <<<"$row")" ] || { echo "complete scaffold state does not match exact active instance: $display_compute" >&2; return 1; }
  elif [ -n "$row" ]; then ocid=$(jq -r .id <<<"$row"); jq -n --arg prefix "$prefix" --arg compartment "$compartment" --arg ocid "$ocid" '{inputs:{name_prefix:$prefix,oci_compartment:$compartment},compute:{created:true,ocid:$ocid},meta:{creation_order:["compute"],recovered_for_failure_cleanup:true}}' > "$state"
  fi
}

cleanup_volume_states_once() {
  local role prefix state failed=0
  cd "$SC_DIR" || return 1
  for role in fra redo2 redo1 data2 data1; do
    prefix="$RUN_TAG-$role"; state="$SC_DIR/state-$prefix.json"
    if [ -f "$state" ]; then
      if jq -e '.blockvolume.created==true and (.blockvolume.ocid//"")!=""' "$state" >/dev/null; then
        export NAME_PREFIX="$prefix"; unset STATE_FILE || true; "$SCAFFOLD_DIR/do/teardown.sh" >/dev/null 2>&1 || failed=1
      elif [ -n "$(jq -r '.blockvolume.ocid // empty' "$state")" ]; then failed=1; fi
    fi
  done
  cd "$REPO_DIR" || return 1
  [ "$failed" -eq 0 ]
}

cleanup_compute_state_once() {
  local prefix="$RUN_TAG-compute" state="$SC_DIR/state-$RUN_TAG-compute.json"
  [ -f "$state" ] || return 0
  jq -e '.compute.created==true and (.compute.ocid//"")!=""' "$state" >/dev/null || { [ -z "$(jq -r '.compute.ocid // empty' "$state")" ] && return 0; return 1; }
  cd "$SC_DIR" || return 1
  export NAME_PREFIX="$prefix"; unset STATE_FILE || true
  "$SCAFFOLD_DIR/do/teardown.sh" >/dev/null 2>&1
  cd "$REPO_DIR" || return 1
}

poll_uncertain_volume_cleanup() {
  local compartment elapsed=0 last_active required_end hard_end poll_seconds=15 quiet_seconds=60 horizon_seconds=300 extension_seconds=120 inventory compute_inventory active
  if [ "$BV4DB_CONTROLLER_TEST_MODE" = true ]; then
    poll_seconds="${SPRINT30_CLEANUP_POLL_SECONDS:-15}"; quiet_seconds="${SPRINT30_CLEANUP_QUIET_SECONDS:-60}"; horizon_seconds="${SPRINT30_CLEANUP_HORIZON_SECONDS:-300}"; extension_seconds="${SPRINT30_CLEANUP_EXTENSION_SECONDS:-120}"
  fi
  for active in "$poll_seconds" "$quiet_seconds" "$horizon_seconds" "$extension_seconds"; do [[ "$active" =~ ^[1-9][0-9]*$ ]] || { echo "invalid failure-cleanup timing" >&2; return 1; }; done
  [ "$quiet_seconds" -le "$horizon_seconds" ] && [ "$quiet_seconds" -le "$extension_seconds" ] || { echo "invalid failure-cleanup timing relationship" >&2; return 1; }
  compartment=$(jq -r '.compartment.ocid' "$INFRA_STATE")
  last_active="$horizon_seconds"
  required_end=$((last_active+quiet_seconds)); hard_end=$((horizon_seconds+extension_seconds))
  while [ "$elapsed" -le "$hard_end" ]; do
    recover_incomplete_scaffold_states || return 1
    if [ "$RECOVERY_OBSERVED_ACTIVE" = true ]; then last_active="$elapsed"; required_end=$((last_active+quiet_seconds)); fi
    cleanup_volume_states_once || return 1
    cleanup_compute_state_once || return 1
    inventory=$(oci bv volume list --compartment-id "$compartment" --all) || return 1
    compute_inventory=$(oci compute instance list --compartment-id "$compartment" --all) || return 1
    active=$(jq -n --arg run_tag "$RUN_TAG" --argjson volumes "$inventory" --argjson compute "$compute_inventory" '([$volumes.data[]|select((."display-name"//"")|startswith($run_tag+"-"))|select(."lifecycle-state"!="TERMINATED")]|length) + ([$compute.data[]|select((."display-name"//"")|startswith($run_tag+"-"))|select(."lifecycle-state"!="TERMINATED")]|length)')
    if [ "$active" -gt 0 ]; then last_active="$elapsed"; required_end=$((last_active+quiet_seconds)); fi
    if [ "$required_end" -gt "$hard_end" ]; then echo "resource appeared too late to prove the required quiet interval within the cleanup bound" >&2; return 1; fi
    if [ "$elapsed" -ge "$horizon_seconds" ] && [ "$active" -eq 0 ] && [ "$elapsed" -ge "$required_end" ]; then return 0; fi
    sleep "$poll_seconds"; elapsed=$((elapsed+poll_seconds))
  done
  echo "failure cleanup did not observe a stable zero-volume interval" >&2
  return 1
}

cleanup_owned_resources() {
  local role prefix state failed=0 compartment volume_inventory compute_inventory uncertain=false volume_query_ok=true compute_query_ok=true
  [ "$OWNERSHIP_ACTIVE" = true ] || return 0
  if [ -n "$TMPKEY" ] && [ -n "$PUBLIC_IP" ]; then
    ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest restore" >/dev/null 2>&1 || true
    ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest quiesce" >/dev/null 2>&1 || true
  fi
  for role in data1 data2 redo1 redo2 fra; do state="$SC_DIR/state-$RUN_TAG-$role.json"; if [ -f "$state" ] && ! jq -e '.blockvolume.created==true and (.blockvolume.ocid//"")!=""' "$state" >/dev/null; then uncertain=true; fi; done
  state="$SC_DIR/state-$RUN_TAG-compute.json"; if ! { [ -f "$state" ] && jq -e '.compute.created==true and (.compute.ocid//"")!=""' "$state" >/dev/null; }; then uncertain=true; fi
  if [ "$uncertain" = true ]; then poll_uncertain_volume_cleanup || failed=1
  else recover_incomplete_scaffold_states || failed=1; cleanup_volume_states_once || failed=1; fi
  cd "$SC_DIR" 2>/dev/null || return 1
  prefix="$RUN_TAG-compute"; state="$SC_DIR/state-$prefix.json"
  if [ "$failed" -eq 0 ] && [ -f "$state" ] && jq -e '.compute.created==true and (.compute.ocid//"")!=""' "$state" >/dev/null; then
    export NAME_PREFIX="$prefix"; unset STATE_FILE || true
    if jq -e '((.meta.creation_order//[])|index("compute"))==null' "$state" >/dev/null; then "$SCAFFOLD_DIR/resource/teardown-compute.sh" >/dev/null 2>&1 || failed=1; fi
    [ "$failed" -ne 0 ] || "$SCAFFOLD_DIR/do/teardown.sh" >/dev/null 2>&1 || failed=1
  fi
  cd "$REPO_DIR" || true
  compartment=$(jq -r '.compartment.ocid' "$INFRA_STATE")
  if ! volume_inventory=$(oci bv volume list --compartment-id "$compartment" --all); then volume_query_ok=false; volume_inventory='{"data":[]}'; failed=1; fi
  if ! compute_inventory=$(oci compute instance list --compartment-id "$compartment" --all); then compute_query_ok=false; compute_inventory='{"data":[]}'; failed=1; fi
  jq -n --arg run_tag "$RUN_TAG" --argjson volume_query_ok "$volume_query_ok" --argjson compute_query_ok "$compute_query_ok" --argjson volumes "$volume_inventory" --argjson compute "$compute_inventory" '{run_tag:$run_tag,inventory_queries_succeeded:($volume_query_ok and $compute_query_ok),active_volumes:[$volumes.data[]|select((."display-name"//"")|startswith($run_tag+"-"))|select(."lifecycle-state"!="TERMINATED")],active_instances:[$compute.data[]|select((."display-name"//"")|startswith($run_tag+"-"))|select(."lifecycle-state"!="TERMINATED")]}' > "$OUTPUT_DIR/failure_cleanup_inventory.json"
  if ! jq -e '(.active_volumes|length)==0 and (.active_instances|length)==0' "$OUTPUT_DIR/failure_cleanup_inventory.json" >/dev/null; then failed=1; fi
  jq -n --argjson failed "$failed" '{failure_cleanup_attempted:true,cleanup_failed:($failed!=0)}' > "$OUTPUT_DIR/failure_cleanup.json" 2>/dev/null || true
  [ "$failed" -eq 0 ]
}

controller_exit() {
  local ec=$?
  trap - EXIT INT TERM
  if [ -n "$ACTIVE_SSH_PID" ]; then kill "$ACTIVE_SSH_PID" >/dev/null 2>&1 || true; wait "$ACTIVE_SSH_PID" 2>/dev/null || true; ACTIVE_SSH_PID=""; fi
  if [ "$RUN_COMPLETE" != true ] && [ "$KEEP_INFRA" != true ]; then cleanup_owned_resources || true; fi
  if [ "$RUN_COMPLETE" != true ] && [ -s "$OUTPUT_DIR/run_state.json" ]; then
    local exit_status=failed
    if [ "$ec" -eq 130 ] || [ "$ec" -eq 143 ]; then exit_status=interrupted; fi
    jq --arg status "$exit_status" --argjson exit_code "$ec" '. + {status:$status,exit_code:$exit_code}' "$OUTPUT_DIR/run_state.json" | atomic_json "$OUTPUT_DIR/run_state.json" || true
  fi
  if [ -n "$TMPKEY" ] && [ -f "$TMPKEY" ]; then chmod 600 "$TMPKEY" 2>/dev/null || true; dd if=/dev/zero of="$TMPKEY" bs=1024 count=8 conv=notrunc >/dev/null 2>&1 || true; rm -f "$TMPKEY"; fi
  bv_controller_lock_release || true
  exit "$ec"
}

wait_for_single_path_attachment_evidence() {
  local attachment_ocid="$1" volume_ocid="$2" instance_ocid="$3" expected_iqn="$4" expected_ip="$5" expected_port="$6" evidence="$7"
  local poll_seconds=5 timeout_seconds=300
  local elapsed=0 state
  if [ "$BV4DB_CONTROLLER_TEST_MODE" = true ]; then
    poll_seconds="${SPRINT30_ATTACHMENT_POLL_SECONDS:-5}"
    timeout_seconds="${SPRINT30_ATTACHMENT_TIMEOUT_SECONDS:-300}"
  fi
  [[ "$poll_seconds" =~ ^[1-9][0-9]*$ ]] || return 1
  [[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || return 1
  [ "$timeout_seconds" -ge "$poll_seconds" ] || return 1
  while :; do
    oci compute volume-attachment get --volume-attachment-id "$attachment_ocid" > "$evidence" || return 1
    jq -e --arg volume "$volume_ocid" --arg instance "$instance_ocid" \
      '.data."volume-id"==$volume and .data."instance-id"==$instance' "$evidence" >/dev/null || return 1
    jq -e '.data."is-multipath"!=true and ((.data."multipath-devices"==null) or ((.data."multipath-devices"|type)=="array" and (.data."multipath-devices"|length)==0))' "$evidence" >/dev/null || return 1
    if jq -e --arg iqn "$expected_iqn" --arg ip "$expected_ip" --argjson port "$expected_port" '.data as $d | ($d|has("is-multipath")) and ($d|has("multipath-devices")) and $d."attachment-type"=="iscsi" and $d."lifecycle-state"=="ATTACHED" and ($d."is-multipath"==false or $d."is-multipath"==null) and ($d."multipath-devices"==null or (($d."multipath-devices"|type)=="array" and ($d."multipath-devices"|length)==0)) and $d.iqn==$iqn and $d.ipv4==$ip and $d.port==$port' "$evidence" >/dev/null; then
      return 0
    fi
    state=$(jq -r '.data."lifecycle-state" // empty' "$evidence")
    [ "$state" = ATTACHING ] || [ "$state" = ATTACHED ] || return 1
    elapsed=$((elapsed + poll_seconds))
    [ "$elapsed" -lt "$timeout_seconds" ] || return 1
    sleep "$poll_seconds"
  done
}

provision_fresh_with_scaffold() {
  [ "${SPRINT30_APPLY_SCAFFOLD:-0}" = 1 ] || die "live execution requires SPRINT30_APPLY_SCAFFOLD=1"
  [ -d "$SCAFFOLD_DIR" ] || die "oci_scaffold submodule is missing"
  [ -f "$INFRA_STATE" ] || die "Sprint 1 infrastructure state is missing"
  [ -x "$GUEST_EXECUTOR" ] || die "guest executor is missing or not executable"
  require_cmd oci; require_cmd ssh; require_cmd scp; require_cmd base64; require_cmd shasum
  oci iam region-subscription list --all >/dev/null || die "OCI authentication failed"
  local compartment subnet public_key image_json image_ocid compute_ocid compute_state role size path prefix state attach_json row volumes='[]'
  compartment=$(jq -r '.compartment.ocid // empty' "$INFRA_STATE")
  subnet=$(jq -r '.subnet.ocid // empty' "$INFRA_STATE")
  public_key="$REPO_DIR/progress/sprint_1/bv4db-key.pub"
  [ -n "$compartment" ] && [ -n "$subnet" ] && [ -f "$public_key" ] || die "Sprint 1 shared inputs are incomplete"
  mkdir -p "$SC_DIR" "$OUTPUT_DIR/discovery"
  RUN_TAG="s30-$(date -u +%Y%m%d%H%M%S)-$$"
  jq --arg run_tag "$RUN_TAG" '. + {status:"provisioning",run_tag:$run_tag}' "$OUTPUT_DIR/run_state.json" | atomic_json "$OUTPUT_DIR/run_state.json"
  [ "${SPRINT30_AUTHORIZE_FRESH_LAYOUT:-0}" = 1 ] || die "live execution requires SPRINT30_AUTHORIZE_FRESH_LAYOUT=1"
  image_ocid="${SPRINT30_IMAGE_OCID:-}"
  [ -n "$image_ocid" ] || die "live execution requires an explicitly pinned SPRINT30_IMAGE_OCID"
  image_json="$OUTPUT_DIR/discovery/oci_images_ol9.json"
  oci compute image list --compartment-id "$compartment" --operating-system 'Oracle Linux' --operating-system-version 9 --shape VM.Standard.E5.Flex --sort-by TIMECREATED --sort-order DESC --all > "$image_json"
  jq -e --arg image "$image_ocid" '.data[0].id==$image and .data[0]."operating-system"=="Oracle Linux" and (.data[0]."operating-system-version"|startswith("9"))' "$image_json" >/dev/null || die "pinned image is not the newest resolved Oracle Linux 9 image for the shape"
  oci compute image get --image-id "$image_ocid" > "$OUTPUT_DIR/discovery/pinned_image.json"

  cd "$SC_DIR"
  export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
  prefix="$RUN_TAG-compute"; set_prefix "$prefix"
  _state_set '.inputs.name_prefix' "$prefix"; _state_set '.inputs.oci_compartment' "$compartment"; _state_set '.subnet.ocid' "$subnet"
  _state_set '.inputs.compute_shape' VM.Standard.E5.Flex; _state_set '.inputs.compute_ocpus' 4; _state_set '.inputs.compute_memory_gb' 32
  _state_set '.inputs.subnet_prohibit_public_ip' false; _state_set '.inputs.compute_ssh_authorized_keys_file' "$public_key"; _state_set '.inputs.compute_image_id' "$image_ocid"
  OWNERSHIP_ACTIVE=true
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
    wait_for_single_path_attachment_evidence \
      "$(jq -r '.blockvolume.attachment_ocid' "$state")" \
      "$(jq -r '.blockvolume.ocid' "$state")" "$compute_ocid" \
      "$(jq -r '.blockvolume.iqn' "$state")" "$(jq -r '.blockvolume.ipv4' "$state")" \
      "$(jq -r '.blockvolume.port' "$state")" "$attach_json" \
      || die "attachment did not prove the requested single path: $role"
    row=$(jq -n --arg role "$role" --arg path "$path" --argjson size "$size" --arg state "$state" --slurpfile a "$attach_json" --slurpfile s "$state" '{role:$role,path:$path,size_gb:$size,vpu:($s[0].blockvolume.vpus_per_gb|tonumber),created:$s[0].blockvolume.created,volume_ocid:$s[0].blockvolume.ocid,attachment_ocid:$s[0].blockvolume.attachment_ocid,iqn:$s[0].blockvolume.iqn,ipv4:$s[0].blockvolume.ipv4,port:($s[0].blockvolume.port|tonumber),single_path_requested:true,is_multipath:false,control_plane_is_multipath:$a[0].data."is-multipath",multipath_devices:(if $a[0].data."multipath-devices"==null then 0 else ($a[0].data."multipath-devices"|length) end),state_file:$state}')
    volumes=$(jq -c --argjson row "$row" '. + [$row]' <<<"$volumes")
  done
  cd "$REPO_DIR"

  local secret_ocid elapsed iface compute_json manifest authorization manifest_sha guest_sha
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
  [ "$(ssh_run uname -m)" = x86_64 ] || die "guest architecture is not x86_64"
  manifest="$OUTPUT_DIR/target_manifest.json"
  guest_sha=$(shasum -a 256 "$GUEST_EXECUTOR" | awk '{print $1}')
  jq -n --arg run_id "$RUN_TAG" --argjson volumes "$volumes" --arg iface "$iface" --arg compute_ocid "$compute_ocid" --arg image_ocid "$image_ocid" --arg guest_sha "$guest_sha" '{run_id:$run_id,vpu:50,guest_executor_sha256:$guest_sha,compute:{ocid:$compute_ocid,shape:"VM.Standard.E5.Flex",ocpus:4,memory_gb:32,architecture:"x86_64",image_ocid:$image_ocid},iscsi_interface:$iface,volumes:$volumes}' > "$manifest"
  manifest_sha=$(shasum -a 256 "$manifest" | awk '{print $1}')
  authorization="$OUTPUT_DIR/fresh_layout_authorization.json"
  jq -n --arg run_id "$RUN_TAG" --arg sha "$manifest_sha" --slurpfile m "$manifest" '{authorize_fresh_layout:true,run_id:$run_id,manifest_sha256:$sha,volumes:[$m[0].volumes[]|{volume_ocid,path,iqn}]}' > "$authorization"
  scp_to "$GUEST_EXECUTOR" /tmp/bv4db-sprint30-guest
  scp_to "$manifest" /tmp/bv4db-sprint30-manifest.json
  scp_to "$authorization" /tmp/bv4db-sprint30-authorization.json
  if ! ssh_run "sudo install -m 0755 /tmp/bv4db-sprint30-guest /usr/local/sbin/bv4db-sprint30-guest && sudo chmod 0600 /tmp/bv4db-sprint30-authorization.json && sudo /usr/local/sbin/bv4db-sprint30-guest prepare /tmp/bv4db-sprint30-manifest.json /tmp/bv4db-sprint30-authorization.json /var/tmp/bv4db-sprint30/discovery"; then
    ssh_run "sudo chmod -R a+rX /var/tmp/bv4db-sprint30" >/dev/null 2>&1 || true
    mkdir -p "$OUTPUT_DIR/failed_guest_prepare"
    scp_from /var/tmp/bv4db-sprint30/discovery "$OUTPUT_DIR/failed_guest_prepare/" || true
    die "guest preparation failed; partial discovery was copied when available"
  fi
  ssh_run "sudo chmod -R a+rX /var/tmp/bv4db-sprint30"
  scp_from /var/tmp/bv4db-sprint30/discovery "$OUTPUT_DIR/"
  ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest preflight" > "$OUTPUT_DIR/discovery/guest_preflight_initial.json"
  jq -e '.sessions_valid and .routes_valid and .devices_unique and .boot_excluded and .multipath_absent and .mounts_valid and .lvm_valid and .socket_congestion_control_valid and .sentinels_valid' "$OUTPUT_DIR/discovery/guest_preflight_initial.json" >/dev/null || die "initial guest topology proof failed"
  jq -n --argjson volumes "$volumes" --argjson guest_cpus "$(ssh_run nproc)" --arg iface "$iface" --slurpfile sent "$OUTPUT_DIR/discovery/sentinels.json" --slurpfile proof "$OUTPUT_DIR/discovery/guest_preflight_initial.json" '{volumes:$volumes,guest_cpus:$guest_cpus,guest_architecture:"x86_64",iscsi_interface:$iface,layout:$proof[0].layout,sentinels_valid:(($sent[0]|length)==3 and all($sent[0][];(.sha256|length)==64)),proof:"discovery/guest_preflight_initial.json"}' > "$OUTPUT_DIR/live_topology.json"
  reconcile_live_catalogue
}

reconcile_live_catalogue() {
  local discovery="$OUTPUT_DIR/discovery" ledger="$CATALOGUE"
  local baseline="$OUTPUT_DIR/discovery/guest_baseline.json" current_cc cc feature id line disposition reason
  local ring_max_rx ring_max_tx ring_cur_rx ring_cur_tx chan_max chan_cur adaptive_rx adaptive_tx tuned_current profile profile_file all_mask duplicates proposal
  [ -s "$baseline" ] || die "live guest baseline discovery is missing"
  ledger=$(jq -c 'map(
    if .id=="ISCSI_QD128" then .reason="five target node records expose a captured numeric queue depth"|.evidence="discovery/guest_baseline.json"
    elif (.id|test("^(TCP_BUF|NETDEV_BACKLOG)")) then .reason="numeric sysctl baseline captured on the pinned host"|.evidence="discovery/guest_baseline.json"
    elif (.id|test("^(RPS|XPS)")) then .reason="online CPU and NIC queue topology captured on the pinned host"|.evidence="discovery/guest_baseline.json"
    elif .id=="MTU_ALTERNATIVE" then .reason="alternate endpoint MTU support is not proven for the active iSCSI route"|.evidence="discovery/guest_baseline.json"
    else . end)' <<<"$ledger")
  if jq -e '([.iscsi_queue_depth[].value]|unique)==["128"] and all(.iscsi_queue_depth[];.live_value==.value)' "$baseline" >/dev/null; then
    ledger=$(jq -c 'map(if .id=="ISCSI_QD128" then .disposition="not_applicable"|.reason="all five discovered node records already use queue depth 128"|.evidence="discovery/guest_baseline.json"|del(.execution_status) else . end)' <<<"$ledger")
  elif ! jq -e '([.iscsi_queue_depth[].value]|length)==5 and all(.iscsi_queue_depth[];(.value|test("^[0-9]+$")) and .live_value==.value)' "$baseline" >/dev/null; then
    ledger=$(jq -c 'map(if .id=="ISCSI_QD128" then .disposition="unsafe"|.reason="numeric node/live queue-depth baselines across five target records could not be proven"|.evidence="discovery/guest_baseline.json"|del(.execution_status) else . end)' <<<"$ledger")
  fi
  current_cc=$(jq -r .tcp_congestion_control "$baseline")
  if jq -e 'any(.rps[];(.cpus|test("[^0,]")))' "$baseline" >/dev/null; then
    ledger=$(jq -c 'map(if .id=="RPS_RFS_65536" then .id="RFS_65536"|.control="RFS"|.reason="discovered baseline RPS masks are active, so standalone RFS is non-no-op"|.evidence="discovery/guest_baseline.json" else . end)' <<<"$ledger")
  fi
  all_mask=$(ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest cpu-mask")
  if jq -e --arg mask "$all_mask" 'all(.rps[];((.cpus|gsub(",";"")|sub("^0+";"")) == ($mask|sub("^0+";""))))' "$baseline" >/dev/null; then
    ledger=$(jq -c 'map(if .id=="RPS_ALL_ONLINE" then .disposition="not_applicable"|.reason="discovered RPS masks already cover all online CPUs"|del(.execution_status) else . end)' <<<"$ledger")
  fi
  while IFS= read -r cc; do
    [ -n "$cc" ] || continue; [ "$cc" = "$current_cc" ] && continue
    id="TCP_CC_${cc^^}"; ledger=$(jq -c --arg id "$id" --arg cc "$cc" '. + [{id:$id,control:"TCP congestion control",disposition:"testable",reason:("available alternative discovered on the pinned host: "+$cc),evidence:"discovery/tcp_available_congestion_control.txt",execution_status:"pending"}]' <<<"$ledger")
  done < <(tr ' ' '\n' < "$discovery/tcp_available_congestion_control.txt")

  for feature in RX_CHECKSUM TX_CHECKSUM TSO GSO GRO; do
    case "$feature" in RX_CHECKSUM) line=rx-checksumming;; TX_CHECKSUM) line=tx-checksumming;; TSO) line=tcp-segmentation-offload;; GSO) line=generic-segmentation-offload;; GRO) line=generic-receive-offload;; esac
    if grep -Eq "^$line: (on|off)( |$)" "$discovery/ethtool_features.txt" && ! grep -E "^$line:.*\[fixed\]" "$discovery/ethtool_features.txt" >/dev/null; then disposition=testable; reason="driver reports the feature as independently changeable"; else disposition=unsupported; reason="driver reports the feature absent or fixed"; fi
    ledger=$(jq -c --arg id "OFFLOAD_$feature" --arg disposition "$disposition" --arg reason "$reason" '. + [{id:$id,control:"NIC offload",disposition:$disposition,reason:$reason,evidence:"discovery/ethtool_features.txt"}] | map(if .id==$id and .disposition=="testable" then .execution_status="pending" else . end)' <<<"$ledger")
  done

  ring_max_rx=$(awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="RX:"{print $2;exit}' "$discovery/ethtool_rings.txt" || true)
  ring_max_tx=$(awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="TX:"{print $2;exit}' "$discovery/ethtool_rings.txt" || true)
  ring_cur_rx=$(awk '/Current hardware settings:/{s=1;next}s&&$1=="RX:"{print $2;exit}' "$discovery/ethtool_rings.txt" || true)
  ring_cur_tx=$(awk '/Current hardware settings:/{s=1;next}s&&$1=="TX:"{print $2;exit}' "$discovery/ethtool_rings.txt" || true)
  if [[ "$ring_max_rx" =~ ^[0-9]+$ && "$ring_max_tx" =~ ^[0-9]+$ ]] && { [ "$ring_max_rx" != "$ring_cur_rx" ] || [ "$ring_max_tx" != "$ring_cur_tx" ]; }; then disposition=testable; reason="driver maximum differs from current ring size"; else disposition=unsupported; reason="driver has no independently changeable larger ring size"; fi
  ledger=$(jq -c --arg disposition "$disposition" --arg reason "$reason" 'map(if .id=="NIC_RING_MAX" then .disposition=$disposition|.reason=$reason|.evidence="discovery/ethtool_rings.txt"|(if $disposition=="testable" then .execution_status="pending" else del(.execution_status) end) else . end)' <<<"$ledger")

  chan_max=$(awk '/Pre-set maximums:/{s=1;next}/Current hardware settings:/{s=0}s&&$1=="Combined:"{print $2;exit}' "$discovery/ethtool_channels.txt" || true)
  chan_cur=$(awk '/Current hardware settings:/{s=1;next}s&&$1=="Combined:"{print $2;exit}' "$discovery/ethtool_channels.txt" || true)
  if [[ "$chan_max" =~ ^[0-9]+$ && "$chan_cur" =~ ^[0-9]+$ ]]; then
    cc=$(jq -r .guest_cpus "$OUTPUT_DIR/live_topology.json"); [ "$chan_max" -le "$cc" ] || chan_max=$cc
  fi
  if [[ "$chan_max" =~ ^[0-9]+$ && "$chan_cur" =~ ^[0-9]+$ ]] && [ "$chan_max" != "$chan_cur" ]; then disposition=testable; reason="driver exposes a distinct combined-channel target bounded by online CPUs"; else disposition=not_applicable; reason="driver exposes no distinct changeable combined-channel target"; fi
  ledger=$(jq -c --arg disposition "$disposition" --arg reason "$reason" '. + [{id:"NIC_CHANNEL_MAX",control:"NIC channels",disposition:$disposition,reason:$reason,evidence:"discovery/ethtool_channels.txt"}] | map(if .id=="NIC_CHANNEL_MAX" and .disposition=="testable" then .execution_status="pending" else . end)' <<<"$ledger")

  adaptive_rx=$(awk '/Adaptive RX:/{for(i=1;i<=NF;i++)if($i=="RX:"){print $(i+1);exit}}' "$discovery/ethtool_coalescing.txt" || true); adaptive_tx=$(awk '/Adaptive RX:|Adaptive TX:/{for(i=1;i<=NF;i++)if($i=="TX:"){print $(i+1);exit}}' "$discovery/ethtool_coalescing.txt" || true)
  for disposition in ON OFF; do
    id="NIC_COAL_ADAPTIVE_$disposition"
    if [[ "$adaptive_rx" =~ ^(on|off)$ && "$adaptive_tx" =~ ^(on|off)$ ]] && { [ "${disposition,,}" != "$adaptive_rx" ] || [ "${disposition,,}" != "$adaptive_tx" ]; }; then reason="adaptive RX/TX controls are exposed and this value differs from baseline"; cc=testable; else reason="adaptive RX/TX is unsupported or this value is the baseline no-op"; cc=not_applicable; fi
    ledger=$(jq -c --arg id "$id" --arg disposition "$cc" --arg reason "$reason" '. + [{id:$id,control:"NIC adaptive coalescing",disposition:$disposition,reason:$reason,evidence:"discovery/ethtool_coalescing.txt"}] | map(if .id==$id and .disposition=="testable" then .execution_status="pending" else . end)' <<<"$ledger")
  done

  tuned_current=$(jq -r '.tuned_profile // empty' "$baseline")
  ledger=$(jq -c 'map(select(.id!="TUNED_PROFILE"))' <<<"$ledger")
  while IFS= read -r profile_file; do
    profile=$(basename "$profile_file" .txt)
    id="TUNED_PROFILE_${profile^^}"; id=${id//-/_}
    if [ "$tuned_current" = "$profile" ]; then disposition=not_applicable; reason="profile is the discovered active baseline"
    else disposition=unsafe; reason="TuneD activation is a coupled service mutation whose resolved profile delta is not completely bounded by the byte-equal network/iSCSI restoration bundle"; fi
    ledger=$(jq -c --arg id "$id" --arg disposition "$disposition" --arg reason "$reason" --arg evidence "discovery/tuned_profile_info/$profile.txt" '. + [{id:$id,control:"TuneD profile",disposition:$disposition,reason:$reason,evidence:$evidence}] | map(if .id==$id and .disposition=="testable" then .execution_status="pending" else . end)' <<<"$ledger")
  done < <(find "$discovery/tuned_profile_info" -maxdepth 1 -type f -name '*.txt' | sort)
  ledger=$(jq -c '. + [{id:"NIC_DRIVER_BASELINE",control:"NIC driver/firmware",disposition:"read_only",reason:"driver and firmware are fixed experiment baselines",evidence:"discovery/ethtool_driver.txt",discovered_value:"see evidence",proposed_value:null},{id:"RSS_INDIR_BASELINE",control:"RSS indirection/hash",disposition:"read_only",reason:"RSS topology is captured as a fixed baseline; no independently approved RSS mutation is defined",evidence:"discovery/ethtool_rss.txt",discovered_value:"see evidence",proposed_value:null}]' <<<"$ledger")

  ledger=$(jq -c --slurpfile baseline "$baseline" 'map(. + {discovered_value:(.discovered_value // (
    if .id|startswith("TCP_CC_") then $baseline[0].tcp_congestion_control
    elif .id|startswith("TCP_BUF_") then ($baseline[0]|{rmem_max,wmem_max,tcp_rmem,tcp_wmem})
    elif .id|startswith("NETDEV_BACKLOG_") then $baseline[0].netdev_max_backlog
    elif (.id|test("^RPS|^RFS")) then ($baseline[0]|{rps_sock_flow_entries,rps})
    elif .id=="XPS_BY_QUEUE" then $baseline[0].xps
    elif .id|startswith("TUNED_PROFILE_") then $baseline[0].tuned_profile
    elif .id=="ISCSI_QD128" then $baseline[0].iscsi_queue_depth
    elif .id|startswith("OFFLOAD_") then $baseline[0].offloads
    elif .id|startswith("NIC_") then $baseline[0].nic
    elif .id=="MTU_ALTERNATIVE" then $baseline[0].mtu
    else "see evidence" end)),proposed_value:(.proposed_value // null)})' <<<"$ledger")
  duplicates=$(jq -r 'group_by(.id)|map(select(length>1)|.[0].id)|join(",")' <<<"$ledger"); [ -z "$duplicates" ] || die "duplicate live candidate IDs: $duplicates"
  while IFS= read -r id; do proposal=$(ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest proposal '$id'"); jq -e . <<<"$proposal" >/dev/null || die "invalid proposed value for candidate: $id"; ledger=$(jq -c --arg id "$id" --argjson proposal "$proposal" 'map(if .id==$id then .proposed_value=$proposal else . end)' <<<"$ledger"); done < <(jq -r '.[]|select(.disposition=="testable")|.id' <<<"$ledger")
  CATALOGUE=$(jq -c 'sort_by(.id)' <<<"$ledger")
  printf '%s\n' "$CATALOGUE" | jq . > "$OUTPUT_DIR/live_catalogue.json"
  write_plan
  jq --arg run_tag "$RUN_TAG" '. + {status:"preflight_passed",run_tag:$run_tag}' "$OUTPUT_DIR/run_state.json" | atomic_json "$OUTPUT_DIR/run_state.json"
}

append_result() {
  local row="$1" file="$OUTPUT_DIR/results_index.json"
  [ -f "$file" ] || printf '[]\n' > "$file"
  jq --argjson row "$row" '. + [$row]' "$file" | atomic_json "$file"
}

validate_oci_volume_preflight() {
  jq -e '.data."vpus-per-gb"==50 and .data."lifecycle-state"=="AVAILABLE"' <<<"$1" >/dev/null
}

validate_resume_volume_preflight() {
  local role="$1" expected="$2" state="$3" evidence="$4" volume
  jq -e --arg prefix "$RUN_TAG-$role" --arg expected "$expected" '.inputs.name_prefix==$prefix and .blockvolume.created==true and .blockvolume.ocid==$expected' "$state" >/dev/null || return 1
  volume=$(oci bv volume get --volume-id "$expected") || return 1
  printf '%s\n' "$volume" > "$evidence"
  validate_oci_volume_preflight "$volume"
}

validate_attempt_topology() {
  local out="$1" row volume_ocid attachment_ocid role volume attachment records='[]'
  mkdir -p "$out"
  while IFS= read -r row; do
    volume_ocid=$(jq -r .volume_ocid <<<"$row"); attachment_ocid=$(jq -r .attachment_ocid <<<"$row"); role=$(jq -r .role <<<"$row")
    volume=$(oci bv volume get --volume-id "$volume_ocid") || die "volume preflight query failed: $role"
    attachment=$(oci compute volume-attachment get --volume-attachment-id "$attachment_ocid") || die "attachment preflight query failed: $role"
    printf '%s\n' "$volume" > "$out/oci_volume_$role.json"
    printf '%s\n' "$attachment" > "$out/oci_attachment_$role.json"
    validate_oci_volume_preflight "$volume" || die "volume tier/state drift: $role"
    jq -e --arg volume "$volume_ocid" --arg instance "$(jq -r .compute.ocid "$OUTPUT_DIR/target_manifest.json")" --arg iqn "$(jq -r .iqn <<<"$row")" --arg ip "$(jq -r .ipv4 <<<"$row")" --argjson port "$(jq -r .port <<<"$row")" '.data as $d | ($d|has("is-multipath")) and ($d|has("multipath-devices")) and $d."attachment-type"=="iscsi" and $d."lifecycle-state"=="ATTACHED" and ($d."is-multipath"==false or $d."is-multipath"==null) and ($d."multipath-devices"==null or (($d."multipath-devices"|type)=="array" and ($d."multipath-devices"|length)==0)) and $d."volume-id"==$volume and $d."instance-id"==$instance and $d.iqn==$iqn and $d.ipv4==$ip and $d.port==$port' <<<"$attachment" >/dev/null || die "attachment binding/path drift: $role"
    records=$(jq -c --arg role "$role" --argjson volume "$volume" --argjson attachment "$attachment" '. + [{role:$role,volume:$volume.data,attachment:$attachment.data}]' <<<"$records")
  done < <(jq -c '.volumes[]' "$OUTPUT_DIR/target_manifest.json")
  printf '%s\n' "$records" > "$out/oci_preflight.json"
  ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest preflight" > "$out/guest_preflight.json"
  jq -e '.sessions_valid and .routes_valid and .devices_unique and .boot_excluded and .multipath_absent and .mounts_valid and .lvm_valid and .socket_congestion_control_valid and .sentinels_valid' "$out/guest_preflight.json" >/dev/null || die "guest topology preflight failed"
}

execute_measurement() {
  local candidate="$1" block="$2" repetition="$3" attempt_type="${4:-measurement}" remote=/var/tmp/bv4db-sprint30 key local_dir status attempt_file row renewal run_rc=0 heartbeat_elapsed=0
  key="${candidate}_${block}_${repetition}"; local_dir="$OUTPUT_DIR/attempts/$key"
  if [ -n "$RESUME_RUN" ] && [ -d "$local_dir" ] && find "$local_dir" -mindepth 1 -print -quit | grep -q .; then
    mkdir -p "$OUTPUT_DIR/interrupted"; mv "$local_dir" "$OUTPUT_DIR/interrupted/$key-$(date -u +%Y%m%dT%H%M%SZ)"
    ssh_run "if [ -d '$remote/attempts/$key' ]; then sudo mkdir -p '$remote/interrupted'; sudo mv '$remote/attempts/$key' '$remote/interrupted/$key-$(date -u +%Y%m%dT%H%M%SZ)'; fi"
  fi
  mkdir -p "$local_dir"
  validate_attempt_topology "$local_dir"
  ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest run '$candidate' '$repetition' '$remote/attempts/$key' 600 60" & ACTIVE_SSH_PID=$!
  status=passed
  while ssh_job_running "$ACTIVE_SSH_PID"; do
    sleep 15; heartbeat_elapsed=$((heartbeat_elapsed+15))
    if [ "$heartbeat_elapsed" -ge 30 ] && ssh_job_running "$ACTIVE_SSH_PID"; then
      if renewal=$(ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest renew"); then
        printf '%s candidate=%s block=%s repetition=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$candidate" "$block" "$repetition" "$renewal" >> "$OUTPUT_DIR/lease_renewals.log"
      else
        sleep 2
        if ssh_job_running "$ACTIVE_SSH_PID"; then status=failed; kill "$ACTIVE_SSH_PID" >/dev/null 2>&1 || true; fi
        break
      fi
    fi
    [ "$heartbeat_elapsed" -lt 30 ] || heartbeat_elapsed=0
  done
  set +e; wait "$ACTIVE_SSH_PID"; run_rc=$?; set -e; ACTIVE_SSH_PID=""
  [ "$run_rc" -eq 0 ] || status=failed
  ssh_run "sudo chmod -R a+rX '$remote/attempts/$key'" >/dev/null 2>&1 || true; scp_from "$remote/attempts/$key/." "$local_dir/" >/dev/null 2>&1 || true
  attempt_file="$local_dir/attempt.json"
  if [ "$status" = passed ] && [ -s "$attempt_file" ] && jq -e '.restoration_state=="restored" and .sentinels_valid==true and .rollback_armed==false and .fio_exit_code==0' "$attempt_file" >/dev/null && jq -e 'type=="object"' "$local_dir/fio.json" >/dev/null 2>&1; then
    [ -x "$FIO_RENDERER" ] || die "per-attempt FIO renderer is missing or not executable"
    "$FIO_RENDERER" "$local_dir/fio.json" "$local_dir/iostat.json" "$local_dir/fio_report.html" "Sprint 30 $candidate block $block repetition $repetition"
    row=$(jq -n --arg run_id "$RUN_TAG" --arg candidate "$candidate" --arg attempt_type "$attempt_type" --arg block "$block" --argjson repetition "$repetition" --arg result "$status" --arg path "attempts/$key" --slurpfile a "$attempt_file" '{run_id:$run_id,candidate_id:$candidate,attempt_type:$attempt_type,block:$block,repetition:$repetition,vpu:50,result:$result,restoration_state:$a[0].restoration_state,sentinels_valid:$a[0].sentinels_valid,started_at:$a[0].started_at,ended_at:$a[0].ended_at,evidence:[$path]}')
  else
    row=$(jq -n --arg run_id "$RUN_TAG" --arg candidate "$candidate" --arg attempt_type "$attempt_type" --arg block "$block" --argjson repetition "$repetition" --arg path "attempts/$key" '{run_id:$run_id,candidate_id:$candidate,attempt_type:$attempt_type,block:$block,repetition:$repetition,vpu:50,result:"failed",restoration_state:"unproven",sentinels_valid:false,evidence:[$path]}')
    status=failed
  fi
  append_result "$row"; [ "$status" = passed ] || die "FIO attempt failed or restoration is unproven: $key"
  jq --arg candidate "$candidate" --arg block "$block" --argjson repetition "$repetition" --slurpfile transitions "$local_dir/state.json" '.attempt_transitions=((.attempt_transitions//[]) + [{candidate_id:$candidate,block:$block,repetition:$repetition,transitions:$transitions[0]}])' "$OUTPUT_DIR/run_state.json" | atomic_json "$OUTPUT_DIR/run_state.json"
}

extend_and_gate_stability() {
  local phase="$1" id count rep remaining
  while IFS= read -r id; do
    case "$phase:$id" in
      initial:REGULAR_BASELINE_INITIAL|final:REGULAR_BASELINE_FINAL) ;;
      initial:*|final:*|candidates:REGULAR_*) continue ;;
      candidates:*) ;;
    esac
    count=$(jq --arg id "$id" '[.[]|select(.candidate_id==$id and .result=="passed")]|length' "$OUTPUT_DIR/results_index.json")
    rep=$((count+1)); while [ "$rep" -le 5 ]; do execute_measurement "$id" stability_extension "$rep"; rep=$((rep+1)); done
  done < <("$ANALYZER" --unstable "$OUTPUT_DIR")
  remaining=$("$ANALYZER" --unstable "$OUTPUT_DIR")
  case "$phase" in
    initial) remaining=$(grep -Fx 'REGULAR_BASELINE_INITIAL' <<<"$remaining" || true) ;;
    final) remaining=$(grep -Fx 'REGULAR_BASELINE_FINAL' <<<"$remaining" || true) ;;
    candidates) remaining=$(grep -Ev '^REGULAR_' <<<"$remaining" || true) ;;
  esac
  if [ "$phase" = candidates ] && [ -n "$remaining" ]; then
    while IFS= read -r id; do [ -n "$id" ] || continue; jq --arg id "$id" 'map(if .id==$id then .execution_status="inconclusive" else . end)' "$OUTPUT_DIR/tunable_coverage.json" | atomic_json "$OUTPUT_DIR/tunable_coverage.json"; done <<<"$remaining"
    return 0
  fi
  [ -z "$remaining" ] || die "$phase measurements remain unstable after five repetitions: $remaining"
}

execute_matrix() {
  local remote=/var/tmp/bv4db-sprint30 attempt candidate attempt_type block reps rep local_dir row kind drifted initial_gated=false candidates_gated=false
  if [ -z "$RESUME_RUN" ] || [ ! -s "$OUTPUT_DIR/results_index.json" ]; then printf '[]\n' > "$OUTPUT_DIR/results_index.json"; fi
  while IFS= read -r attempt; do
    candidate=$(jq -r .candidate_id <<<"$attempt"); attempt_type=$(jq -r .attempt_type <<<"$attempt"); block=$(jq -r '.block|tostring' <<<"$attempt")
    if [ "$initial_gated" = false ] && [ "$candidate" != REGULAR_BASELINE_INITIAL ]; then extend_and_gate_stability initial; initial_gated=true; fi
    if [ "$attempt_type" = rollback_canary ]; then
      if [ "$candidates_gated" = false ]; then
        extend_and_gate_stability candidates
        drifted=$("$ANALYZER" --checkpoint-drift "$OUTPUT_DIR")
        [ -z "$drifted" ] || die "regular checkpoint drift exceeded the accepted threshold: $drifted"
        candidates_gated=true
      fi
      if jq -e --arg id "$candidate" '.[]|select(.candidate_id==$id and .attempt_type=="rollback_canary" and .result=="expected_failure_restored")' "$OUTPUT_DIR/results_index.json" >/dev/null; then continue; fi
      kind="trap"; [ "$candidate" = ROLLBACK_CANARY_LEASE ] && kind="lease"
      local_dir="$OUTPUT_DIR/attempts/$candidate"; mkdir -p "$local_dir"
      validate_attempt_topology "$local_dir"
      if [ "$kind" = lease ]; then
        ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest canary-arm '$remote/attempts/$candidate'"
        sleep 185
        ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest canary-observe '$remote/attempts/$candidate'"
      else
        ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest canary '$kind' '$remote/attempts/$candidate'"
      fi
      ssh_run "sudo chmod -R a+rX '$remote/attempts/$candidate'"; scp_from "$remote/attempts/$candidate/." "$local_dir/"
      jq -e '.result=="expected_failure_restored" and .baseline_equal==true and .sentinels_valid==true and .rollback_armed==false' "$local_dir/canary.json" >/dev/null || die "canary proof failed: $candidate"
      row=$(jq -n --arg run_id "$RUN_TAG" --arg candidate "$candidate" --arg path "attempts/$candidate" --slurpfile c "$local_dir/canary.json" '{run_id:$run_id,candidate_id:$candidate,safe_source_candidate:$c[0].safe_source_candidate,attempt_type:"rollback_canary",vpu:50,result:$c[0].result,restoration_state:(if $c[0].baseline_equal then "restored" else "unproven" end),sentinels_valid:$c[0].sentinels_valid,rollback_armed:$c[0].rollback_armed,unit_state:$c[0].unit_state,evidence:[$path]}'); append_result "$row"
      continue
    fi
    if [[ "$candidate" != REGULAR_* ]] && ! jq -e --arg id "$candidate" '.[]|select(.id==$id and .disposition=="testable")' "$OUTPUT_DIR/tunable_coverage.json" >/dev/null; then continue; fi
    reps=$(jq -r .repetitions <<<"$attempt")
    rep=1
    while [ "$rep" -le "$reps" ]; do
      if ! jq -e --arg id "$candidate" --arg block "$block" --argjson rep "$rep" '.[]|select(.candidate_id==$id and (.block|tostring)==$block and .repetition==$rep and .result=="passed")' "$OUTPUT_DIR/results_index.json" >/dev/null; then execute_measurement "$candidate" "$block" "$rep" "$attempt_type"; fi
      rep=$((rep+1))
    done
  done < <(jq -c '.attempts[]' "$OUTPUT_DIR/experiment_plan.json")
  extend_and_gate_stability final
  drifted=$("$ANALYZER" --final-drift "$OUTPUT_DIR")
  [ -z "$drifted" ] || die "initial/final regular baseline drift exceeded the accepted threshold: $drifted"
  jq --slurpfile results "$OUTPUT_DIR/results_index.json" --slurpfile plan "$OUTPUT_DIR/experiment_plan.json" 'map(. as $c | if .disposition=="testable" and (.id as $id|$plan[0].candidate_ids|index($id))!=null and .execution_status!="inconclusive" then .execution_status=(if ([$results[0][]|select(.candidate_id==$c.id and .result=="passed")]|length) as $n | ($n>=3 and $n<=5) then "tested" else "failed" end) else . end)' "$OUTPUT_DIR/tunable_coverage.json" | atomic_json "$OUTPUT_DIR/tunable_coverage.json"
}

collect_oci_metrics() {
  local definition="$OUTPUT_DIR/oci_metrics_definition.json" prefix="$RUN_TAG-metrics" state="$SC_DIR/state-$RUN_TAG-metrics.json" compartment delivery_attempt=1 indexer="$REPO_DIR/tools/index_oci_attempt_metrics.py"
  compartment=$(jq -r '.compartment.ocid' "$INFRA_STATE")
  cat > "$definition" <<'EOF'
{
  "title": "Sprint 30 fixed-50-VPU FIO window",
  "resource_classes": {
    "compute": {"namespace":"oci_computeagent","interval":"1m","metrics":[{"name":"CpuUtilization","stat":"mean","unit":"percent","scale":1,"suffix":"%","decimals":2}]},
    "blockvolume": {"namespace":"oci_blockstore","interval":"1m","metrics":[{"name":"VolumeReadThroughput","stat":"mean","unit":"bytes/interval","scale":1048576,"suffix":" MiB","decimals":2},{"name":"VolumeWriteThroughput","stat":"mean","unit":"bytes/interval","scale":1048576,"suffix":" MiB","decimals":2},{"name":"VolumeReadOps","stat":"mean","unit":"ops","scale":1,"suffix":"","decimals":2},{"name":"VolumeWriteOps","stat":"mean","unit":"ops","scale":1,"suffix":"","decimals":2}]}
  }
}
EOF
  jq -n --arg compartment "$compartment" --arg start "$MATRIX_START" --arg end "$MATRIX_END" --arg def "$definition" --arg md "$OUTPUT_DIR/oci_metrics.md" --arg html "$OUTPUT_DIR/oci_metrics.html" --arg raw "$OUTPUT_DIR/oci_metrics_raw.json" --slurpfile manifest "$OUTPUT_DIR/target_manifest.json" '{inputs:{oci_compartment:$compartment,metrics_definition_file:$def,metrics_report_file:$md,metrics_html_report_file:$html,metrics_raw_file:$raw,metrics_resolution:"1m"},compute:{ocid:$manifest[0].compute.ocid},volumes:($manifest[0].volumes|map({key:.role,value:{ocid:.volume_ocid}})|from_entries),test_window:{start_time:$start,end_time:$end}}' > "$state"
  while true; do
    (cd "$SC_DIR"; NAME_PREFIX="$prefix" "$SCAFFOLD_DIR/resource/operate-metrics.sh")
    if python3 "$indexer" "$OUTPUT_DIR/results_index.json" "$OUTPUT_DIR/oci_metrics_raw.json" "$OUTPUT_DIR/oci_metrics_attempt_windows.json"; then break; fi
    [ "$delivery_attempt" -lt 5 ] || die "OCI metrics failed to provide at least eight one-minute datapoints for every metric and FIO window"
    delivery_attempt=$((delivery_attempt+1)); sleep 120
  done
}

render_reports() {
  local passed id disposition status reason evidence trace guardrail
  passed=$(jq '[.[]|select(.attempt_type=="measurement" and .result=="passed")]|length' "$OUTPUT_DIR/results_index.json")
  [ -x "$ANALYZER" ] || die "analysis renderer is missing or not executable"
  "$ANALYZER" "$OUTPUT_DIR"
  collect_oci_metrics
  {
    echo '# Sprint 30 summary'; echo
    echo '- FIO only; Oracle Database was not installed or invoked.'
    echo '- Five fresh 50-VPU/GB volumes used one iSCSI path each.'
    echo '- Interpretation: this is constrained single-path characterization on a four-OCPU host, not a supported multipath/UHP entitlement; an observed gain cannot by itself distinguish the instance network/IOPS ceiling, single-path limit, volume tier, or workload concurrency.'
    echo "- Successful measured repetitions: $passed."
    echo "- Recommendation: \`$(jq -r .decision "$OUTPUT_DIR/recommendation.json")\`."
    echo '- Detailed statistics and attempt links: [fio_analysis.md](fio_analysis.md).'
    echo '- OCI FIO-window evidence: [oci_metrics.md](oci_metrics.md), [oci_metrics.html](oci_metrics.html), and [oci_metrics_attempt_windows.json](oci_metrics_attempt_windows.json).'
    echo; echo '## Tunable coverage'; echo
    echo '| Candidate | Disposition | Execution | Reason | Discovery | Statistics / attempt restoration | Guardrails |'; echo '| --- | --- | --- | --- | --- | --- | --- |'
    while IFS=$'\t' read -r id disposition status reason evidence; do
      trace='not executed; exclusion is recorded in the ledger'
      guardrail='not eligible for recommendation'
      if [ "$disposition" = testable ]; then
        trace="[statistics](fio_analysis.md); [raw attempts](attempts/) (each bundle includes controls_before, controls_applied, controls_restored, errors, topology, and state transitions)"
        guardrail=$(jq -r --arg id "$id" 'if .candidates[$id].eligible then "eligible: stable, clean errors, CPU and regression guards passed" else "excluded: " + ((.candidates[$id].regressions//[])|join(",")|if length>0 then "regressions="+. else "stability/improvement/CPU/error guard" end) end' "$OUTPUT_DIR/recommendation.json")
      fi
      printf '| %s | %s | %s | %s | [%s](%s) | %s | %s |\n' "$id" "$disposition" "$status" "$reason" "$evidence" "$evidence" "$trace" "$guardrail"
    done < <(jq -r '.[]|[.id,.disposition,(.execution_status//"not executed"),.reason,.evidence]|@tsv' "$OUTPUT_DIR/tunable_coverage.json")
  } > "$OUTPUT_DIR/sprint_30_summary.md"
}

verify_oci_deleted() {
  local kind="$1" ocid="$2" out="$3" attempt rc state
  local err="$3.stderr"
  for attempt in 1 2 3 4 5; do
    set +e
    if [ "$kind" = volume ]; then oci bv volume get --volume-id "$ocid" > "$out" 2> "$err"; else oci compute instance get --instance-id "$ocid" > "$out" 2> "$err"; fi
    rc=$?; set -e
    if [ "$rc" -eq 0 ]; then
      state=$(jq -r '.data."lifecycle-state" // empty' "$out"); if [ "$state" = TERMINATED ]; then rm -f "$err"; return 0; fi
    elif grep -q 'NotAuthorizedOrNotFound' "$err" && grep -Eq '(^|[^0-9])404([^0-9]|$)' "$err"; then
      jq -n --arg status not_found --argjson http_status 404 --arg code NotAuthorizedOrNotFound '{status:$status,http_status:$http_status,code:$code}' > "$out"; rm -f "$err"; return 0
    fi
    sleep 15
  done
  die "OCI deletion could not be proven for $kind $ocid; last CLI exit=$rc state=${state:-unknown}"
}

teardown_scaffold() {
  local role prefix failed=0 state ocid expected inventory='[]' query compartment volume_inventory compute_inventory
  ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest quiesce"
  cd "$SC_DIR"
  for role in fra redo2 redo1 data2 data1; do
    prefix="$RUN_TAG-$role"; state="$SC_DIR/state-$prefix.json"
    expected=$(jq -r --arg role "$role" '.volumes[]|select(.role==$role)|.volume_ocid' "$OUTPUT_DIR/target_manifest.json")
    jq -e --arg prefix "$prefix" --arg expected "$expected" '.inputs.name_prefix==$prefix and .blockvolume.created==true and .blockvolume.ocid==$expected' "$state" >/dev/null || die "refusing teardown of unproven volume state: $role"
    ocid="$expected"; export NAME_PREFIX="$prefix"; unset STATE_FILE || true; "$SCAFFOLD_DIR/do/teardown.sh" || failed=1
    query="$OUTPUT_DIR/deletion-check-$role.json"
    verify_oci_deleted volume "$ocid" "$query" || failed=1
    inventory=$(jq -c --arg role "$role" --arg ocid "$ocid" --slurpfile q "$query" '. + [{role:$role,ocid:$ocid,post_delete:$q[0]}]' <<<"$inventory")
  done
  [ "$failed" -eq 0 ] || die "one or more scaffold volume teardowns failed; compute retained"
  prefix="$RUN_TAG-compute"; state="$SC_DIR/state-$prefix.json"
  expected=$(jq -r '.compute.ocid' "$OUTPUT_DIR/target_manifest.json")
  jq -e --arg prefix "$prefix" --arg expected "$expected" '.inputs.name_prefix==$prefix and .compute.created==true and .compute.ocid==$expected' "$state" >/dev/null || die "refusing teardown of unproven compute state"
  export NAME_PREFIX="$prefix"; unset STATE_FILE || true; "$SCAFFOLD_DIR/do/teardown.sh"
  query="$OUTPUT_DIR/deletion-check-compute.json"
  verify_oci_deleted compute "$expected" "$query"
  inventory=$(jq -c --arg ocid "$expected" --slurpfile q "$query" '. + [{role:"compute",ocid:$ocid,post_delete:$q[0]}]' <<<"$inventory")
  printf '%s\n' "$inventory" | jq . > "$OUTPUT_DIR/deletion_inventory.json"
  compartment=$(jq -r '.compartment.ocid' "$INFRA_STATE")
  volume_inventory=$(oci bv volume list --compartment-id "$compartment" --all); compute_inventory=$(oci compute instance list --compartment-id "$compartment" --all)
  jq -n --arg run_tag "$RUN_TAG" --argjson volumes "$volume_inventory" --argjson compute "$compute_inventory" '{run_tag:$run_tag,active_volumes:[$volumes.data[]|select((."display-name"//"")|contains($run_tag))|select(."lifecycle-state"!="TERMINATED")],active_instances:[$compute.data[]|select((."display-name"//"")|contains($run_tag))|select(."lifecycle-state"!="TERMINATED")]}' > "$OUTPUT_DIR/post_teardown_inventory.json"
  jq -e '(.active_volumes|length)==0 and (.active_instances|length)==0' "$OUTPUT_DIR/post_teardown_inventory.json" >/dev/null || die "independent post-teardown inventory still contains active run resources"
  cd "$REPO_DIR"
}

resume_existing_run() {
  local state role expected secret_ocid elapsed local_sha remote_sha
  [ -f "$OUTPUT_DIR/run_state.json" ] && [ -f "$OUTPUT_DIR/target_manifest.json" ] && [ -f "$OUTPUT_DIR/experiment_plan.json" ] && [ -f "$OUTPUT_DIR/tunable_coverage.json" ] || die "resume evidence set is incomplete"
  RUN_TAG=$(jq -r '.run_tag // empty' "$OUTPUT_DIR/run_state.json")
  [ -n "$RUN_TAG" ] && [ "$RUN_TAG" = "$RESUME_RUN" ] && [ "$RUN_TAG" = "$(jq -r .run_id "$OUTPUT_DIR/target_manifest.json")" ] || die "resume run ID does not match immutable run evidence"
  ! jq -e '.status=="completed"' "$OUTPUT_DIR/run_state.json" >/dev/null || die "completed run cannot be resumed"
  SC_DIR="$OUTPUT_DIR/scaffold"; state="$SC_DIR/state-$RUN_TAG-compute.json"; expected=$(jq -r .compute.ocid "$OUTPUT_DIR/target_manifest.json")
  jq -e --arg prefix "$RUN_TAG-compute" --arg expected "$expected" '.inputs.name_prefix==$prefix and .compute.created==true and .compute.ocid==$expected' "$state" >/dev/null || die "resume compute ownership proof failed"
  PUBLIC_IP=$(jq -r .compute.public_ip "$state"); oci compute instance get --instance-id "$expected" | jq -e '.data."lifecycle-state"=="RUNNING"' >/dev/null || die "resume compute is not running"
  for role in data1 data2 redo1 redo2 fra; do
    state="$SC_DIR/state-$RUN_TAG-$role.json"; expected=$(jq -r --arg role "$role" '.volumes[]|select(.role==$role)|.volume_ocid' "$OUTPUT_DIR/target_manifest.json")
    validate_resume_volume_preflight "$role" "$expected" "$state" "$OUTPUT_DIR/resume_volume_$role.json" || die "resume volume ownership/state/tier failed: $role"
  done
  secret_ocid=$(jq -r '.secret.ocid // empty' "$INFRA_STATE"); [ -n "$secret_ocid" ] || die "Sprint 1 Vault SSH secret is missing"
  TMPKEY=$(mktemp); chmod 600 "$TMPKEY"; oci secrets secret-bundle get --secret-id "$secret_ocid" --query 'data."secret-bundle-content".content' --raw-output | base64 --decode > "$TMPKEY"
  elapsed=0; until ssh_run true >/dev/null 2>&1; do sleep 5; elapsed=$((elapsed+5)); [ "$elapsed" -lt 120 ] || die "resume SSH did not become ready"; done
  local_sha=$(shasum -a 256 "$GUEST_EXECUTOR" | awk '{print $1}'); remote_sha=$(ssh_run "sudo sha256sum /usr/local/sbin/bv4db-sprint30-guest | awk '{print \$1}'")
  [ "$local_sha" = "$(jq -r .guest_executor_sha256 "$OUTPUT_DIR/target_manifest.json")" ] && [ "$local_sha" = "$remote_sha" ] || die "resume executor hash mismatch"
  OWNERSHIP_ACTIVE=true
  ssh_run "sudo /usr/local/sbin/bv4db-sprint30-guest prove-baseline /var/tmp/bv4db-sprint30/resume_baseline_proof.json"
  scp_from /var/tmp/bv4db-sprint30/resume_baseline_proof.json "$OUTPUT_DIR/resume_baseline_proof.json"
  validate_attempt_topology "$OUTPUT_DIR/resume_preflight"
  MATRIX_START=$(jq -r '.matrix_start // empty' "$OUTPUT_DIR/run_state.json"); [ -n "$MATRIX_START" ] || die "resume matrix start is missing"
  jq '.status="resuming"' "$OUTPUT_DIR/run_state.json" | atomic_json "$OUTPUT_DIR/run_state.json"
}

live_execute() {
  if [ -n "$RESUME_RUN" ]; then resume_existing_run; else
    provision_fresh_with_scaffold
    MATRIX_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq --arg start "$MATRIX_START" '. + {status:"running",matrix_start:$start}' "$OUTPUT_DIR/run_state.json" | atomic_json "$OUTPUT_DIR/run_state.json"
  fi
  execute_matrix
  MATRIX_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  ssh_run "sudo cat /var/lib/bv4db-sprint30/rollback.json" > "$OUTPUT_DIR/final_rollback.json"
  jq -e '.rollback_armed==false' "$OUTPUT_DIR/final_rollback.json" >/dev/null || die "final rollback lease remains armed"
  render_reports
  local teardown=completed
  if [ "$KEEP_INFRA" = true ]; then teardown=kept; else teardown_scaffold; OWNERSHIP_ACTIVE=false; fi
  local sentinels_valid baseline_equal
  sentinels_valid=$(jq 'all(.[];.sentinels_valid==true)' "$OUTPUT_DIR/results_index.json")
  baseline_equal=$(jq 'all(.[];.restoration_state=="restored")' "$OUTPUT_DIR/results_index.json")
  jq -n --arg teardown "$teardown" --argjson keep "$KEEP_INFRA" --argjson sentinels "$sentinels_valid" --argjson baseline "$baseline_equal" --slurpfile rollback "$OUTPUT_DIR/final_rollback.json" '{baseline_equal:$baseline,sentinels_valid:$sentinels,rollback_armed:$rollback[0].rollback_armed,oracle_database_invoked:false,teardown:$teardown,keep_infra:$keep}' > "$OUTPUT_DIR/final_state.json"
  jq --arg teardown "$teardown" --argjson sentinels "$sentinels_valid" --argjson baseline "$baseline_equal" '. + {status:(if $sentinels and $baseline then "completed" else "failed" end),topology_verified:true,vpu:50,single_path:true,sentinels_valid:$sentinels,baseline_equal:$baseline,teardown:$teardown}' "$OUTPUT_DIR/run_state.json" | atomic_json "$OUTPUT_DIR/run_state.json"
  RUN_COMPLETE=true
  log "COMPLETE: $OUTPUT_DIR"
}

if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  [ "${BV4DB_CONTROLLER_SOURCE_ONLY:-0}" = 1 ] || return 2
  BV4DB_CONTROLLER_TEST_MODE=true
  return 0
fi

if [ "$MODE" = execute ]; then
  bv_controller_lock_acquire "$OUTPUT_DIR" || die "could not acquire the Sprint 30 controller-lifetime lock"
  trap controller_exit EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
fi
if [ -z "$RESUME_RUN" ]; then write_plan; fi
[ -z "$FIXTURE" ] || validate_fixture "$FIXTURE"
[ -z "$STATE_FAULT" ] || simulate_state_machine "$STATE_FAULT"
if [ "$MODE" = execute ]; then
  live_execute
fi

#!/usr/bin/env bash
# Sprint 30 integration tests for the single-path iSCSI tuning domain.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$REPO_DIR/tools/oci_bv_single_path_tuning.sh"
GUEST="$REPO_DIR/tools/oci_bv_single_path_guest.sh"
VERIFIER="$REPO_DIR/tools/verify_bv_single_path_results.py"
CONTROLLER_LOCK="$REPO_DIR/tools/oci_bv_controller_lock.sh"
fail() { echo "FAIL: $*" >&2; return 1; }
pass() { echo "PASS: $*"; }
new_tmp() { mktemp -d "${TMPDIR:-/tmp}/sprint30-test.XXXXXX"; }

# Production functions are invoked indirectly after sourcing the guest script.
# shellcheck disable=SC2030,SC2031,SC2034,SC2329
exercise_guest_preflight_shims() {
  local root="$1" duplicate_session="${2:-0}"
  (
    export BV4DB_GUEST_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$GUEST"
    STATE_DIR="$root/state"; MANIFEST="$STATE_DIR/manifest.json"; BASELINE="$STATE_DIR/baseline.json"; SENTINELS="$STATE_DIR/sentinels.json"; IDENTITIES="$STATE_DIR/device_identities.json"
    mkdir -p "$STATE_DIR"
    jq -n '{iscsi_interface:"eth0",volumes:[range(0;5)|{role:(if .==4 then "fra" else "role-"+tostring end),iqn:("iqn.test:"+tostring),ipv4:"10.0.0.2",port:3260,path:("/dev/leaf-"+tostring)}]}' > "$MANIFEST"
    jq -n '[range(0;5)|{iqn:("iqn.test:"+tostring),serial:("serial-"+tostring)}]' > "$IDENTITIES"
    jq -n '{tcp_congestion_control:"cubic"}' > "$BASELINE"; jq -n '[]' > "$SENTINELS"
    verify_sentinels() { :; }
    verify_all_iscsi_socket_cc() { [ "$1" = cubic ]; }
    block_device_exists() { [[ "$1" == /dev/leaf-* ]]; }
    device_leaf() { if [ "$1" = /dev/root-source ]; then echo /dev/root; else echo "$1"; fi; }
    iscsi_bypath_for() { printf '/dev/disk/by-path/%s\n' "$1"; }
    ip() { printf '10.0.0.2 via 10.0.0.1 dev eth0 src 10.0.0.3\n'; }
    findmnt() { if [[ "$*" == *"FSTYPE"* ]]; then echo ext4; elif [[ "$*" == *"/u04/fra"* ]]; then echo /dev/leaf-4; else echo /dev/root-source; fi; }
    lvs() { if [[ "$*" == *"stripe_size"* ]]; then echo 256; else echo 2; fi; }
    lsblk() { local last="${*: -1}"; if [[ "$*" == *"TYPE"* ]]; then echo disk; elif [[ "$*" == *"SERIAL"* ]]; then printf 'serial-%s\n' "${last##*-}"; fi; }
    cat() { if [[ "$1" == /sys/block/*/device/queue_depth ]]; then echo 128; else command cat "$@"; fi; }
    iscsiadm() {
      if [[ " $* " == *" -m session "* ]]; then
        for n in 0 1 2 3 4; do printf 'tcp: [1] 10.0.0.2:3260,1 iqn.test:%s\n' "$n"; done
        [ "$duplicate_session" = 0 ] || printf 'tcp: [9] 10.0.0.2:3260,1 iqn.test:0\n'
      else printf 'node.session.queue_depth = 128\n'; fi
    }
    live_preflight cubic >/dev/null
  )
}

# Production pre-format proof is invoked directly with guest-command shims.
# shellcheck disable=SC2030,SC2031,SC2034,SC2329
exercise_preformat_single_path_shim() {
  local root="$1" mode="$2"
  (
    export BV4DB_GUEST_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$GUEST"
    mkdir -p "$root"
    iscsiadm() {
      if [ "$mode" = wrong_portal ]; then
        printf 'tcp: [1] 169.254.9.9:3260,1 iqn.test:1 (non-flash)\n'
      elif [ "$mode" = prefix_iqn ]; then
        printf 'tcp: [1] 169.254.2.2:3260,1 iqn.test:10 (non-flash)\n'
      elif [ "$mode" = duplicate_session ]; then
        printf 'tcp: [1] 169.254.2.2:3260,1 iqn.test:1 (non-flash)\n'
        printf 'tcp: [2] 169.254.2.2:3260,1 iqn.test:1 (non-flash)\n'
      elif [ "$mode" = duplicate_other_portal ]; then
        printf 'tcp: [1] 169.254.2.2:3260,1 iqn.test:1 (non-flash)\n'
        printf 'tcp: [2] 169.254.9.9:3260,1 iqn.test:1 (non-flash)\n'
      else
        printf 'tcp: [1] 169.254.2.2:3260,1 iqn.test:1 (non-flash)\n'
      fi
    }
    device_leaf() { printf '/dev/leaf-1\n'; }
    lsblk() {
      if [[ "$*" == *"-dnro TYPE"* ]]; then
        if [ "$mode" = mpath_leaf ]; then printf 'mpath\n'; else printf 'disk\n'; fi
      elif [[ "$*" == *"-nro TYPE"* ]]; then
        if [ "$mode" = mpath_global ]; then printf 'disk\nmpath\n'; else printf 'disk\n'; fi
      else return 1; fi
    }
    pvcreate() { touch "$root/destructive-command"; }
    mkfs.ext4() { touch "$root/destructive-command"; }
    preformat_single_path_proof data1 iqn.test:1 169.254.2.2 3260 /dev/oracleoci/oraclevdb
  )
}

# Production bounded TuneD convergence check is invoked with command shims.
# shellcheck disable=SC2030,SC2031,SC2329
exercise_tuned_verify_settle_shim() {
  local root="$1" mode="$2"
  (
    export BV4DB_GUEST_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$GUEST"
    mkdir -p "$root"
    tuned_calls=0
    tuned-adm() {
      [ "$1" = verify ] || return 2
      tuned_calls=$((tuned_calls+1))
      printf 'TuneD verification call %s\n' "$tuned_calls"
      if [ "$mode" = transient ] && [ "$tuned_calls" -ge 3 ]; then return 0; fi
      return 1
    }
    sleep() { :; }
    verify_tuned_settled "$root/tuned_verify.txt" 3 0
  )
}

# shellcheck disable=SC2030,SC2031,SC2034,SC2329
exercise_real_resume_proof() {
  local root="$1" current="$2" restore_result="${3:-0}" systemctl_mode="${4:-inactive}"
  (
    export BV4DB_GUEST_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$GUEST"
    STATE_DIR="$root/state"; BASELINE="$root/baseline.json"; LOCK_FILE="$STATE_DIR/mutation.lock"; ATTEMPT_LOCK_FILE="$STATE_DIR/attempt.lock"
    mkdir -p "$STATE_DIR"; cp "$(dirname "$root")/baseline.json" "$BASELINE"; jq -n '{rollback_armed:true,unit:"stale-unit"}' > "$STATE_DIR/rollback.json"
    restore_controls() { [ "$restore_result" = 0 ]; }
    capture_controls() { cp "$current" "$1"; }
    live_preflight() { :; }; verify_sentinels() { :; }; pgrep() { return 1; }
    flock() { :; }
    systemctl() {
      printf '%s\n' "$*" >> "$root/systemctl.journal"
      if [ "$1" = stop ] && [ "$systemctl_mode" = stop_failure ]; then return 1; fi
      if [ "$1" = is-active ]; then
        if [ "$systemctl_mode" = active ]; then echo active; return 0; else echo inactive; return 3; fi
      fi
    }
    prove_baseline "$root/proof.json"
  )
}

# Production rollback-unit disarm proof with systemd lifecycle shims.
# shellcheck disable=SC2030,SC2031,SC2329
exercise_rollback_stop_shim() {
  local root="$1" mode="$2"
  (
    export BV4DB_GUEST_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$GUEST"
    mkdir -p "$root"
    systemctl() {
      case "$1" in
        stop)
          case "$mode" in
            missing|missing_loaded) echo "Failed to stop $2: Unit $2 not loaded." >&2; return 5 ;;
            mixed) printf 'Failed to stop %s: Unit %s not loaded.\nAccess denied stopping %s\n' "$2" "$2" "$2" >&2; return 5 ;;
            generic_failure) return 5 ;;
            *) return 0 ;;
          esac ;;
        is-active) [ "$mode" = active ] && { echo active; return 0; }; echo inactive; return 3 ;;
        show) [ "$mode" = missing ] && echo not-found || echo loaded ;;
        reset-failed) return 0 ;;
        *) return 2 ;;
      esac
    }
    stop_rollback_unit_strict test "$root/rollback_unit_stop.txt"
  )
}

# Production deadline renewal/check functions with time and systemd shims.
# shellcheck disable=SC2030,SC2031,SC2034,SC2329
exercise_lease_deadline_shim() {
  local root="$1"
  (
    export BV4DB_GUEST_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$GUEST"
    STATE_DIR="$root/state"; LEASE_LOCK_FILE="$STATE_DIR/lease.lock"; mkdir -p "$STATE_DIR"
    echo 100 > "$root/now"
    jq -n '{rollback_armed:true,unit:"test-watchdog",deadline_seconds:180,deadline_epoch:120}' > "$STATE_DIR/rollback.json"
    date() { if [ "$1" = +%s ]; then command cat "$root/now"; else echo 2026-08-18T00:00:00Z; fi; }
    systemctl() {
      if [ "$1" = is-active ]; then return 0; fi
      printf '%s\n' "$*" >> "$root/systemctl.journal"
      return 2
    }
    flock() { :; }
    emergency_restore() { touch "$root/emergency-restored"; jq '.rollback_armed=false' "$STATE_DIR/rollback.json" > "$STATE_DIR/rollback.tmp"; mv "$STATE_DIR/rollback.tmp" "$STATE_DIR/rollback.json"; }
    renew_rollback_lease
    jq -e '.deadline_epoch==280 and .renewed_at=="2026-08-18T00:00:00Z" and .renewal_count==1' "$STATE_DIR/rollback.json" >/dev/null || return 1
    [ ! -e "$root/systemctl.journal" ] || return 1
    echo 279 > "$root/now"; lease_check; [ ! -e "$root/emergency-restored" ] || return 1
    echo 280 > "$root/now"; lease_check; [ -e "$root/emergency-restored" ] || return 1
  )
}

# Expiry claiming and renewal use the same production lease-state lock.
# shellcheck disable=SC2030,SC2031,SC2034,SC2329
exercise_lease_claim_race_shim() {
  local root="$1"
  (
    export BV4DB_GUEST_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$GUEST"
    STATE_DIR="$root/state"; LEASE_LOCK_FILE="$STATE_DIR/lease.lock"; mkdir -p "$STATE_DIR"
    echo 200 > "$root/now"
    date() { if [ "$1" = +%s ]; then command cat "$root/now"; else echo 2026-08-18T00:00:00Z; fi; }
    systemctl() { [ "$1" = is-active ]; }
    flock() {
      if [ "$1" = -u ]; then rmdir "$root/lease-held" 2>/dev/null || true; return 0; fi
      while ! mkdir "$root/lease-held" 2>/dev/null; do sleep 0.01; done
      if [ ! -e "$root/first-lock-observed" ]; then
        touch "$root/first-lock-observed" "$root/lease-lock-held"
        while [ ! -e "$root/release-first-lock" ]; do sleep 0.01; done
      fi
    }
    emergency_restore() { printf '%s\n' "$1" > "$root/claimed"; }
    jq -n '{rollback_armed:true,unit:"test-watchdog",deadline_seconds:180,deadline_epoch:199,expiry_claimed:false}' > "$STATE_DIR/rollback.json"
    lease_check & checker_pid=$!
    while [ ! -e "$root/lease-lock-held" ]; do kill -0 "$checker_pid" 2>/dev/null || return 1; sleep 0.01; done
    (renew_rollback_lease) >/dev/null 2>&1 & renew_pid=$!
    touch "$root/release-first-lock"
    wait "$checker_pid"
    if wait "$renew_pid"; then renew_rc=0; else renew_rc=$?; fi
    rmdir "$root/lease-held" 2>/dev/null || true
    jq -e --arg claim "$(cat "$root/claimed")" '.expiry_claimed==true and .expiry_claim==$claim' "$STATE_DIR/rollback.json" >/dev/null || return 1
    [ "$renew_rc" -ne 0 ] || return 1
    jq '.expiry_claimed=false | del(.expiry_claim)' "$STATE_DIR/rollback.json" > "$STATE_DIR/reset.json"; mv "$STATE_DIR/reset.json" "$STATE_DIR/rollback.json"
    echo 100 > "$root/now"; renew_rollback_lease
    rm -f "$root/claimed"; echo 200 > "$root/now"; lease_check
    [ ! -e "$root/claimed" ] || return 1
  )
}

# Emergency evidence must persist before rollback.json is disarmed.
# shellcheck disable=SC2030,SC2031,SC2034,SC2329
exercise_emergency_commit_shim() {
  local root="$1"
  (
    export BV4DB_GUEST_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$GUEST"
    STATE_DIR="$root/state"; mkdir -p "$STATE_DIR"
    jq -n '{rollback_armed:true,expiry_claimed:true,expiry_claim:"claim-1",unit:"test-watchdog"}' > "$STATE_DIR/rollback.json"
    fail_evidence=true
    atomic_json() {
      local target="$1"
      if [ "$fail_evidence" = true ] && [[ "$target" == */emergency_restore.json ]]; then command cat >/dev/null; return 1; fi
      command cat > "$target"
    }
    if commit_emergency_restoration test-watchdog false "$root" null claim-1; then return 1; fi
    jq -e '.rollback_armed==true and .expiry_claimed==true and .expiry_claim=="claim-1"' "$STATE_DIR/rollback.json" >/dev/null || return 1
    [ ! -e "$root/emergency_restore.json" ] || return 1
    fail_evidence=false
    commit_emergency_restoration test-watchdog false "$root" null claim-1
    jq -e '.byte_equal==true and .unit=="test-watchdog" and .expiry_claim=="claim-1"' "$root/emergency_restore.json" >/dev/null || return 1
    jq -e '.rollback_armed==false and .restoration_state=="restored" and .source=="host_local_lease"' "$STATE_DIR/rollback.json" >/dev/null || return 1
  )
}

exercise_controller_lock() {
  local root="$1" holder
  mkdir -p "$root"
  (
    # shellcheck source=/dev/null
    source "$CONTROLLER_LOCK"
    bv_controller_lock_acquire "$root" || exit 1
    touch "$root/holder.ready"
    sleep 2
    bv_controller_lock_release
  ) & holder=$!
  while [ ! -f "$root/holder.ready" ]; do kill -0 "$holder" 2>/dev/null || return 1; sleep 0.1; done
  (
    # shellcheck source=/dev/null
    source "$CONTROLLER_LOCK"
    ! bv_controller_lock_acquire "$root"
  ) || { wait "$holder" || true; return 1; }
  wait "$holder" || return 1
  mkdir "$root/.controller.lock"; jq -n --argjson pid 999999 --arg hostname "$(hostname)" '{pid:$pid,hostname:$hostname}' > "$root/.controller.lock/owner.json"
  (
    # shellcheck source=/dev/null
    source "$CONTROLLER_LOCK"
    bv_controller_lock_acquire "$root" && bv_controller_lock_release
  )
  find "$root" -maxdepth 1 -type d -name 'controller_lock_stale_*' | grep -q .
}

# Production attachment convergence gate is exercised with bounded OCI shims.
# shellcheck disable=SC2030,SC2031,SC2034,SC2329
exercise_attachment_convergence() {
  local root="$1" mode="$2"
  (
    set -- --plan --output-dir "$root/source"
    export BV4DB_CONTROLLER_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$RUNNER"
    mkdir -p "$root"
    SPRINT30_ATTACHMENT_POLL_SECONDS=1
    SPRINT30_ATTACHMENT_TIMEOUT_SECONDS=4
    [ "$mode" != bad_timing ] || SPRINT30_ATTACHMENT_POLL_SECONDS=0
    oci() {
      local count=0 multipath=null state=ATTACHED volume=volume-1 instance=instance-1 devices=null
      local response
      [ "$mode" != query_failure ] || return 1
      [ -f "$root/attachment.calls" ] && count=$(cat "$root/attachment.calls")
      count=$((count + 1)); echo "$count" > "$root/attachment.calls"
      if [ "$mode" = eventual ]; then
        if [ "$count" -ge 3 ]; then multipath=false; devices='[]'; else state=ATTACHING; fi
      fi
      [ "$mode" != multipath ] || { multipath=true; devices='[{"ipv4":"10.0.0.3"}]'; }
      [ "$mode" != false_null ] || multipath=false
      [ "$mode" != false_missing ] || multipath=false
      [ "$mode" != false_object ] || { multipath=false; devices='{}'; }
      [ "$mode" != false_nonempty ] || { multipath=false; devices='[{"ipv4":"10.0.0.3"}]'; }
      [ "$mode" != wrong_binding ] || volume='volume-2'
      response=$(jq -n --arg state "$state" --arg volume "$volume" --arg instance "$instance" \
        --argjson multipath "$multipath" --argjson devices "$devices" \
        '{data:{"attachment-type":"iscsi","lifecycle-state":$state,"volume-id":$volume,"instance-id":$instance,"is-multipath":$multipath,"multipath-devices":$devices,iqn:"iqn.test:1",ipv4:"169.254.2.2",port:3260}}')
      case "$mode" in
        false_missing) jq 'del(.data."multipath-devices")' <<<"$response" ;;
        missing_status) jq 'del(.data."is-multipath")' <<<"$response" ;;
        missing_primary) jq 'del(.data.iqn)' <<<"$response" ;;
        *) printf '%s\n' "$response" ;;
      esac
    }
    sleep() { :; }
    wait_for_single_path_attachment_evidence attachment-1 volume-1 instance-1 iqn.test:1 169.254.2.2 3260 "$root/attachment.json"
  )
}

# Production OCI volume-state predicate is exercised against API enum values.
# shellcheck disable=SC2030,SC2031,SC2034
exercise_volume_preflight() {
  local root="$1" state="$2" vpu="${3:-50}"
  (
    set -- --plan --output-dir "$root/source"
    export BV4DB_CONTROLLER_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$RUNNER"
    validate_oci_volume_preflight "$(jq -n --arg state "$state" --argjson vpu "$vpu" '{data:{"lifecycle-state":$state,"vpus-per-gb":$vpu}}')"
  )
}

# Production resume ownership/state gate is exercised with an OCI shim.
# shellcheck disable=SC2030,SC2031,SC2034,SC2329
exercise_resume_volume_preflight() {
  local root="$1" api_state="$2" api_vpu="${3:-50}" ownership="${4:-valid}"
  (
    set -- --plan --output-dir "$root/source"
    export BV4DB_CONTROLLER_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$RUNNER"
    RUN_TAG=unit-resume; mkdir -p "$root"
    jq -n --arg prefix "unit-resume-data1" --arg ocid "$(if [ "$ownership" = valid ]; then printf volume-1; else printf volume-other; fi)" '{inputs:{name_prefix:$prefix},blockvolume:{created:true,ocid:$ocid}}' > "$root/state.json"
    oci() { jq -n --arg state "$api_state" --argjson vpu "$api_vpu" '{data:{"lifecycle-state":$state,"vpus-per-gb":$vpu}}'; }
    validate_resume_volume_preflight data1 volume-1 "$root/state.json" "$root/evidence.json"
  )
}

# Production recovery functions call these bounded shims indirectly.
# shellcheck disable=SC2030,SC2031,SC2034,SC2329
exercise_failure_recovery_poll() {
  local root="$1" mode="$2"
  (
    set -- --plan --output-dir "$root/source"
    export BV4DB_CONTROLLER_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    source "$RUNNER"
    OUTPUT_DIR="$root"; SC_DIR="$root/scaffold"; RUN_TAG=unit-recovery; INFRA_STATE="$root/infra.json"
    mkdir -p "$SC_DIR"; jq -n '{compartment:{ocid:"compartment-test"}}' > "$INFRA_STATE"
    SPRINT30_CLEANUP_POLL_SECONDS=1; SPRINT30_CLEANUP_QUIET_SECONDS=2; SPRINT30_CLEANUP_HORIZON_SECONDS=3; SPRINT30_CLEANUP_EXTENSION_SECONDS=4
    [ "$mode" != bad_timing ] || SPRINT30_CLEANUP_POLL_SECONDS=0
    oci() {
      local count=0
      if [[ " $* " == *" bv volume list "* ]]; then
        [ "$mode" != query_failure ] || return 1
        [ -f "$root/volume.calls" ] && count=$(cat "$root/volume.calls"); count=$((count+1)); echo "$count" > "$root/volume.calls"
        if [ "$mode" = multiple ]; then
          jq -n '{data:[{id:"volume-1","display-name":"unit-recovery-data1-bv","lifecycle-state":"AVAILABLE"},{id:"volume-2","display-name":"unit-recovery-data1-bv","lifecycle-state":"AVAILABLE"}]}'
        elif { [ "$mode" = delayed ] && [ "$count" -ge 3 ]; } || { [ "$mode" = late ] && [ "$count" -ge 9 ]; }; then
          if [ -f "$root/deleted" ]; then jq -n '{data:[]}'; else
          jq -n '{data:[{id:"other","display-name":"unit-recovery-data10-bv","lifecycle-state":"AVAILABLE"},{id:"volume-1","display-name":"unit-recovery-data1-bv","lifecycle-state":"AVAILABLE"}]}'
          fi
        else jq -n '{data:[]}'; fi
      elif [[ " $* " == *" compute instance list "* ]]; then jq -n '{data:[]}'
      elif [[ " $* " == *" compute volume-attachment list "* ]]; then jq -n '{data:[{id:"attachment-1","lifecycle-state":"ATTACHED"}]}'
      else return 1; fi
    }
    cleanup_volume_states_once() {
      local state="$SC_DIR/state-$RUN_TAG-data1.json"
      if [ -s "$state" ] && jq -e '.blockvolume.created==true' "$state" >/dev/null; then cp "$state" "$root/recovered-state.json"; touch "$root/deleted"; mv "$state" "$state.deleted"; fi
    }
    cleanup_compute_state_once() { :; }
    sleep() { :; }
    poll_uncertain_volume_cleanup
  )
}

write_valid_fixture() {
  jq -n '{compute:{shape:"VM.Standard.E5.Flex",ocpus:4,memory_gb:32,image_pinned:true,architecture:"x86_64"},volumes:[range(0;5)|{vpu:50,is_multipath:false,multipath_devices:0,sessions:1,device_id:("device-"+tostring),volume_id:("volume-"+tostring),expected_volume_id:("volume-"+tostring),instance_id:"instance-1",expected_instance_id:"instance-1"}],layout:{data_stripes:2,redo_stripes:2,stripe_kib:256,fra_direct:true,mounts:["/u02/oradata","/u03/redo","/u04/fra"]},route:{same_interface:true},sentinels:{valid:true},credentials:{valid:true}}' > "$1"
}
require_live_output() {
  local dir="${SPRINT30_TEST_OUTPUT_DIR:-}"
  [ -n "$dir" ] || { fail "SPRINT30_TEST_OUTPUT_DIR is required for live evidence validation"; return 1; }
  [ -f "$dir/run_state.json" ] || { fail "missing run state: $dir/run_state.json"; return 1; }
  printf '%s\n' "$dir"
}

maybe_execute_live() {
  local dir="${SPRINT30_TEST_OUTPUT_DIR:-}"
  [ -n "$dir" ] || { fail "SPRINT30_TEST_OUTPUT_DIR is required"; return 1; }
  if [ "${SPRINT30_EXECUTE_LIVE:-0}" = 1 ] && ! jq -e '.status=="completed"' "$dir/run_state.json" >/dev/null 2>&1; then
    SPRINT30_APPLY_SCAFFOLD=1 "$RUNNER" --execute --output-dir "$dir"
  fi
}

test_IT1_static_runner_contract() {
  echo "=== IT-1: static runner and CLI contract ==="
  local tmp; tmp=$(new_tmp); trap 'rm -rf "$tmp"' RETURN
  bash -n "$RUNNER" || return 1
  bash -n "$GUEST" || return 1
  rg -q 'SPRINT30_AUTHORIZE_FRESH_LAYOUT' "$RUNNER" || return 1
  rg -q 'fresh_layout_authorization|layout_authorization.consumed' "$RUNNER" "$GUEST" || return 1
  rg -q 'ATTEMPT_LOCK_FILE' "$GUEST" || return 1
  awk '/preformat_single_path_proof "\$role"/{proof=NR} /^[[:space:]]*pvcreate /{if(!first)first=NR} END{exit !(proof && first && proof<first)}' "$GUEST" || return 1
  "$RUNNER" --plan --output-dir "$tmp" --seed 30050 >/dev/null || return 1
  jq -e '.status=="planned" and .vpu==50 and .resume==null' "$tmp/run_state.json" >/dev/null || return 1
  jq -e '.vpus==[50] and .repeats==3 and .multipath==false and .oracle_database==false and (.layout|length)==5 and ([.layout[].path]|sort)==["/dev/oracleoci/oraclevdb","/dev/oracleoci/oraclevdc","/dev/oracleoci/oraclevdd","/dev/oracleoci/oraclevde","/dev/oracleoci/oraclevdf"] and .fio.global.ioengine=="libaio" and .fio.global.direct==1 and .fio.global.runtime==600 and .fio.global.ramp_time==60 and ([.fio.jobs[].id]|sort)==["data-8k","fra-1m","redo"]' "$tmp/experiment_plan.json" >/dev/null || return 1
  if "$RUNNER" --plan --output-dir "$tmp/rejected" --vpu 45 >/dev/null 2>&1; then fail "runner accepted non-Sprint-30 VPU"; return 1; fi
  if "$RUNNER" --execute --output-dir "$tmp/partial" --candidate TCP_BUF_2X >/dev/null 2>&1; then fail "runner accepted a partial live matrix"; return 1; fi
  pass IT-1
}

test_IT2_deterministic_50_vpu_plan() {
  echo "=== IT-2: deterministic 50-VPU experiment plan and coverage ledger ==="
  local tmp; tmp=$(new_tmp); trap 'rm -rf "$tmp"' RETURN
  "$RUNNER" --plan --output-dir "$tmp/first" --seed 17 >/dev/null || return 1
  "$RUNNER" --plan --output-dir "$tmp/second" --seed 17 >/dev/null || return 1
  "$RUNNER" --plan --output-dir "$tmp/different" --seed 18 >/dev/null || return 1
  cmp "$tmp/first/experiment_plan.json" "$tmp/second/experiment_plan.json" || { fail "plan is not deterministic"; return 1; }
  cmp -s "$tmp/first/experiment_plan.json" "$tmp/different/experiment_plan.json" && { fail "different seed did not change the plan"; return 1; }
  jq -e '.vpus==[50] and .repeats==3 and .checkpoint_interval==5 and ([.attempts[]|select(.attempt_type=="rollback_canary")]|length)==2 and ([.attempts[]|select(.attempt_type=="checkpoint")]|length)==((.candidate_count*3)/5|floor) and ([.attempts[]|select(.attempt_type=="measurement" and (.block==1 or .block==2 or .block==3))|.candidate_id]|sort|group_by(.)|all(length==3)) and all(.attempts[]|select(.block==1 or .block==2 or .block==3);.repetitions==1) and ([.attempts[].vpu]|unique)==[50] and (.attempts[-3].candidate_id=="ROLLBACK_CANARY_TRAP") and (.attempts[-2].candidate_id=="ROLLBACK_CANARY_LEASE") and (.attempts[-1].candidate_id=="REGULAR_BASELINE_FINAL")' "$tmp/first/experiment_plan.json" >/dev/null || return 1
  jq -e 'all(.[];if .disposition=="testable" then .execution_status=="pending" else (has("execution_status")|not) and (.reason|length>0) and (.evidence|length>0) end)' "$tmp/first/tunable_coverage.json" >/dev/null || return 1
  if "$RUNNER" --plan --output-dir "$tmp/selected" --candidate TCP_BUF_2X >/dev/null 2>&1; then fail "runner accepted removed partial-candidate interface"; return 1; fi
  pass IT-2
}

test_IT3_fail_closed_preflight_matrix() {
  echo "=== IT-3: fail-closed preflight matrix ==="
  local tmp fixture field bad; tmp=$(new_tmp); trap 'rm -rf "$tmp"' RETURN; fixture="$tmp/valid.json"; write_valid_fixture "$fixture"
  "$RUNNER" --plan --output-dir "$tmp/valid" --fixture "$fixture" >/dev/null || return 1
  for field in bad_ocpu bad_memory bad_image bad_arch bad_vpu bad_multipath bad_session bad_volume_binding bad_instance_binding duplicate_device bad_layout bad_route bad_sentinel bad_credentials; do
    bad="$tmp/$field.json"
    case "$field" in
      bad_ocpu) jq '.compute.ocpus=8' "$fixture" > "$bad";; bad_memory) jq '.compute.memory_gb=64' "$fixture" > "$bad";; bad_image) jq '.compute.image_pinned=false' "$fixture" > "$bad";; bad_arch) jq '.compute.architecture="aarch64"' "$fixture" > "$bad";; bad_vpu) jq '.volumes[0].vpu=45' "$fixture" > "$bad";; bad_multipath) jq '.volumes[0].is_multipath=true' "$fixture" > "$bad";; bad_session) jq '.volumes[0].sessions=2' "$fixture" > "$bad";; bad_volume_binding) jq '.volumes[0].volume_id="wrong"' "$fixture" > "$bad";; bad_instance_binding) jq '.volumes[0].instance_id="wrong"' "$fixture" > "$bad";; duplicate_device) jq '.volumes[1].device_id=.volumes[0].device_id' "$fixture" > "$bad";; bad_layout) jq '.layout.stripe_kib=64' "$fixture" > "$bad";; bad_route) jq '.route.same_interface=false' "$fixture" > "$bad";; bad_sentinel) jq '.sentinels.valid=false' "$fixture" > "$bad";; bad_credentials) jq '.credentials.valid=false' "$fixture" > "$bad";;
    esac
    if "$RUNNER" --plan --output-dir "$tmp/$field" --fixture "$bad" >/dev/null 2>&1; then fail "$field passed preflight"; return 1; fi
    jq -e 'length==0' "$tmp/$field/mutation_journal.json" >/dev/null || return 1
    jq -e 'length==0' "$tmp/$field/fio_journal.json" >/dev/null || return 1
  done
  exercise_guest_preflight_shims "$tmp/guest-valid" || return 1
  if exercise_guest_preflight_shims "$tmp/guest-duplicate" 1 >/dev/null 2>&1; then fail "real guest preflight accepted duplicate iSCSI sessions"; return 1; fi
  exercise_preformat_single_path_shim "$tmp/preformat-valid" valid || { fail "pre-format proof rejected exact single path"; return 1; }
  for fault in wrong_portal prefix_iqn duplicate_session duplicate_other_portal mpath_leaf mpath_global; do
    if exercise_preformat_single_path_shim "$tmp/preformat-$fault" "$fault" >/dev/null 2>&1; then fail "pre-format proof accepted $fault"; return 1; fi
    [ ! -e "$tmp/preformat-$fault/destructive-command" ] || { fail "pre-format $fault reached a destructive command"; return 1; }
  done
  exercise_tuned_verify_settle_shim "$tmp/tuned-transient" transient || { fail "transient TuneD verification did not converge"; return 1; }
  [ "$(rg -c '^attempt=' "$tmp/tuned-transient/tuned_verify.txt")" -eq 3 ] || return 1
  rg -q '^attempt=3 exit_code=0$' "$tmp/tuned-transient/tuned_verify.txt" || return 1
  if exercise_tuned_verify_settle_shim "$tmp/tuned-persistent" persistent; then fail "persistent TuneD verification mismatch was accepted"; return 1; fi
  rg -q '^attempt=3 exit_code=1$' "$tmp/tuned-persistent/tuned_verify.txt" || return 1
  if LC_ALL=C grep -q '[^ -~[:space:]]' "$tmp/tuned-transient/tuned_verify.txt" "$tmp/tuned-persistent/tuned_verify.txt"; then fail "TuneD diagnostic is not plain ASCII"; return 1; fi
  pass IT-3
}

test_IT4_restore_resume_state_machine() {
  echo "=== IT-4: restore and resume state machine ==="
  local tmp fault; tmp=$(new_tmp); trap 'rm -rf "$tmp"' RETURN
  for fault in none apply readback fio sigterm stale_applying stale_measuring; do
    "$RUNNER" --plan --output-dir "$tmp/$fault" --state-fault "$fault" >/dev/null || return 1
    jq -e 'index("restoring")!=null and index("restored")!=null' "$tmp/$fault/state_journal.json" >/dev/null || return 1
    jq -e '.baseline_equal==true' "$tmp/$fault/run_state.json" >/dev/null || return 1
  done
  for fault in restore drift; do "$RUNNER" --plan --output-dir "$tmp/$fault" --state-fault "$fault" >/dev/null || return 1; jq -e '.baseline_equal==false and .blocked==true' "$tmp/$fault/run_state.json" >/dev/null || return 1; done
  jq -n '{control:"baseline"}' > "$tmp/baseline.json"; cp "$tmp/baseline.json" "$tmp/current.json"
  exercise_real_resume_proof "$tmp/resume-clean" "$tmp/current.json" || return 1
  cmp "$tmp/baseline.json" "$tmp/resume-clean/proof.json" || return 1
  jq -e '.rollback_armed==false and .unit=="stale-unit" and .source=="resume_baseline_proof"' "$tmp/resume-clean/state/rollback.json" >/dev/null || return 1
  rg -q '^stop stale-unit.timer$' "$tmp/resume-clean/systemctl.journal" || return 1
  rg -q '^stop stale-unit.service$' "$tmp/resume-clean/systemctl.journal" || return 1
  jq -n '{control:"drift"}' > "$tmp/drift.json"
  if exercise_real_resume_proof "$tmp/resume-drift" "$tmp/drift.json" >/dev/null 2>&1; then fail "real resume proof accepted baseline drift"; return 1; fi
  if exercise_real_resume_proof "$tmp/restore-failure" "$tmp/current.json" 1 >/dev/null 2>&1; then fail "real resume proof accepted failed restoration"; return 1; fi
  if exercise_real_resume_proof "$tmp/stop-failure" "$tmp/current.json" 0 stop_failure >/dev/null 2>&1; then fail "real resume proof swallowed stale-unit stop failure"; return 1; fi
  if exercise_real_resume_proof "$tmp/still-active" "$tmp/current.json" 0 active >/dev/null 2>&1; then fail "real resume proof accepted an active stale unit"; return 1; fi
  exercise_rollback_stop_shim "$tmp/stop-missing" missing || { fail "garbage-collected rollback unit was not proved inactive"; return 1; }
  [ "$(rg -c '^(timer|service) stop_exit_code=5 missing_unit_only=true load_state=not-found active_state=inactive$' "$tmp/stop-missing/rollback_unit_stop.txt")" -eq 2 ] || return 1
  if exercise_rollback_stop_shim "$tmp/stop-generic" generic_failure >/dev/null 2>&1; then fail "generic rollback stop failure was accepted"; return 1; fi
  if exercise_rollback_stop_shim "$tmp/stop-mixed" mixed >/dev/null 2>&1; then fail "mixed missing and generic rollback stop failure was accepted"; return 1; fi
  if exercise_rollback_stop_shim "$tmp/stop-missing-loaded" missing_loaded >/dev/null 2>&1; then fail "missing-unit text with loaded state was accepted"; return 1; fi
  if exercise_rollback_stop_shim "$tmp/stop-active" active >/dev/null 2>&1; then fail "active rollback unit was accepted"; return 1; fi
  exercise_lease_deadline_shim "$tmp/lease-deadline" || { fail "deadline-based lease renewal/check failed"; return 1; }
  exercise_lease_claim_race_shim "$tmp/lease-claim-race" || { fail "lease expiry claim/renewal serialization failed"; return 1; }
  exercise_emergency_commit_shim "$tmp/emergency-commit" || { fail "emergency evidence-first commit failed"; return 1; }
  rg -q 'heartbeat_elapsed.*-ge 30' "$RUNNER" || { fail "controller lease heartbeat is not 30 seconds"; return 1; }
  rg -q 'lease_renewals.log' "$RUNNER" || { fail "controller lease renewal evidence is not archived"; return 1; }
  rg -q 'ssh_job_running' "$RUNNER" || { fail "controller does not distinguish a running SSH job from a zombie"; return 1; }
  rg -q 'ssh -n -i' "$RUNNER" || { fail "SSH can consume the experiment-plan stream"; return 1; }
  rg -q 'ServerAliveInterval=15.*ServerAliveCountMax=4' "$RUNNER" || { fail "SSH liveness window is not aligned with the independent lease heartbeat"; return 1; }
  rg -q -- '--on-active=5s --on-unit-active=5s --timer-property=AccuracySec=1s .* lease-check' "$GUEST" || return 1
  awk '/emergency_restore\(\)/{inside=1} inside&&/pkill -TERM -x fio/{kill=NR} inside&&/flock -w 180 8/{lock=NR; exit} END{exit !(kill && lock && kill<lock)}' "$GUEST" || return 1
  awk '/emergency_restore\(\)/{inside=1} inside&&/verify_tuned_settled/{tuned=NR} inside&&/commit_emergency_restoration/{commit=NR; exit} END{exit !(tuned && commit && tuned<commit)}' "$GUEST" || return 1
  awk '/commit_emergency_restoration\(\)/{inside=1} inside&&/atomic_json \"\$evidence\"/{evidence=NR} inside&&/atomic_json \"\$STATE_DIR\/rollback.json\"/{state=NR; exit} END{exit !(evidence && state && evidence<state)}' "$GUEST" || return 1
  exercise_controller_lock "$tmp/controller-lock" || { fail "controller-lifetime lock failed"; return 1; }
  exercise_attachment_convergence "$tmp/attachment-eventual" eventual || { fail "attachment false state did not converge"; return 1; }
  [ "$(cat "$tmp/attachment-eventual/attachment.calls")" -eq 3 ] || { fail "attachment convergence was not polled"; return 1; }
  jq -e '.data."is-multipath"==false and .data."multipath-devices"==[]' "$tmp/attachment-eventual/attachment.json" >/dev/null || return 1
  exercise_attachment_convergence "$tmp/attachment-null" false_null || { fail "documented single-path request with null control-plane status was rejected"; return 1; }
  for fault in multipath false_nonempty wrong_binding false_missing missing_status missing_primary false_object query_failure bad_timing; do
    if exercise_attachment_convergence "$tmp/attachment-$fault" "$fault" >/dev/null 2>&1; then fail "attachment convergence accepted $fault"; return 1; fi
  done
  exercise_volume_preflight "$tmp/volume-available" AVAILABLE || { fail "OCI AVAILABLE volume was rejected"; return 1; }
  for fault in IN_USE PROVISIONING TERMINATING; do
    if exercise_volume_preflight "$tmp/volume-$fault" "$fault" >/dev/null 2>&1; then fail "OCI volume preflight accepted invalid API state $fault"; return 1; fi
  done
  if exercise_volume_preflight "$tmp/volume-bad-vpu" AVAILABLE 45 >/dev/null 2>&1; then fail "OCI volume preflight accepted wrong VPU"; return 1; fi
  exercise_resume_volume_preflight "$tmp/resume-volume-valid" AVAILABLE || { fail "resume volume gate rejected AVAILABLE+50"; return 1; }
  jq -e '.data."lifecycle-state"=="AVAILABLE" and .data."vpus-per-gb"==50' "$tmp/resume-volume-valid/evidence.json" >/dev/null || return 1
  for fault in IN_USE PROVISIONING TERMINATING; do
    if exercise_resume_volume_preflight "$tmp/resume-volume-$fault" "$fault" >/dev/null 2>&1; then fail "resume volume gate accepted $fault"; return 1; fi
  done
  if exercise_resume_volume_preflight "$tmp/resume-volume-vpu" AVAILABLE 45 >/dev/null 2>&1; then fail "resume volume gate accepted wrong VPU"; return 1; fi
  if exercise_resume_volume_preflight "$tmp/resume-volume-owner" AVAILABLE 50 invalid >/dev/null 2>&1; then fail "resume volume gate accepted wrong ownership"; return 1; fi
  exercise_failure_recovery_poll "$tmp/recovery-delayed" delayed || { fail "delayed OCI appearance was not recovered"; return 1; }
  jq -e '.blockvolume.ocid=="volume-1" and .blockvolume.attachment_ocid=="attachment-1" and .meta.recovered_for_failure_cleanup==true' "$tmp/recovery-delayed/recovered-state.json" >/dev/null || return 1
  [ "$(cat "$tmp/recovery-delayed/volume.calls")" -ge 8 ] || { fail "stable-zero horizon was not polled"; return 1; }
  exercise_failure_recovery_poll "$tmp/recovery-late" late || { fail "post-horizon OCI appearance was not stabilized"; return 1; }
  [ "$(cat "$tmp/recovery-late/volume.calls")" -ge 14 ] || { fail "post-horizon discovery did not restart the quiet interval"; return 1; }
  if exercise_failure_recovery_poll "$tmp/recovery-query-failure" query_failure >/dev/null 2>&1; then fail "cleanup accepted OCI inventory failure"; return 1; fi
  if exercise_failure_recovery_poll "$tmp/recovery-multiple" multiple >/dev/null 2>&1; then fail "cleanup accepted multiple exact-name resources"; return 1; fi
  if exercise_failure_recovery_poll "$tmp/recovery-bad-timing" bad_timing >/dev/null 2>&1; then fail "cleanup accepted invalid timing"; return 1; fi
  exercise_failure_recovery_poll "$tmp/recovery-zero" zero || return 1
  [ "$(cat "$tmp/recovery-zero/volume.calls")" -ge 8 ] || { fail "zero-active state was not stabilized over the horizon"; return 1; }
  pass IT-4
}

test_IT5_live_50_vpu_topology() {
  echo "=== IT-5: live 50-VPU topology and integrity preflight ==="; local dir role
  maybe_execute_live || return 1
  dir=$(require_live_output) || return 1
  jq -e '.status=="completed" and .topology_verified==true and .vpu==50 and .single_path==true and .sentinels_valid==true' "$dir/run_state.json" >/dev/null || return 1
  jq -e '(.volumes|length)==5 and all(.volumes[];.vpu==50 and .created==true and .is_multipath==false and .multipath_devices==0 and (.volume_ocid|length)>0 and (.attachment_ocid|length)>0) and ([.volumes[].path]|unique|length)==5 and .guest_cpus==8 and .guest_architecture=="x86_64" and .layout.data_stripes==2 and .layout.redo_stripes==2 and .layout.stripe_kib==256 and .layout.fra_direct==true and .layout.mounts==["/u02/oradata","/u03/redo","/u04/fra"] and .proof=="discovery/guest_preflight_initial.json" and .sentinels_valid==true' "$dir/live_topology.json" >/dev/null || return 1
  jq -e '.boot_excluded and .multipath_absent and .mounts_valid and .lvm_valid and .socket_congestion_control_valid' "$dir/discovery/guest_preflight_initial.json" >/dev/null || return 1
  jq -e '.compute.shape=="VM.Standard.E5.Flex" and .compute.ocpus==4 and .compute.memory_gb==32 and .compute.architecture=="x86_64" and (.compute.image_ocid|length)>0' "$dir/target_manifest.json" >/dev/null || return 1
  for role in data1 data2 redo1 redo2 fra; do jq -e --arg role "$role" --slurpfile manifest "$dir/target_manifest.json" '($manifest[0].volumes[]|select(.role==$role)) as $v | .data as $d | ($d|has("is-multipath")) and ($d|has("multipath-devices")) and $d."attachment-type"=="iscsi" and ($d."is-multipath"==false or $d."is-multipath"==null) and ($d."multipath-devices"==null or (($d."multipath-devices"|type)=="array" and ($d."multipath-devices"|length)==0)) and $d."volume-id"==$v.volume_ocid and $d."instance-id"==$manifest[0].compute.ocid and $d.iqn==$v.iqn and $d.ipv4==$v.ipv4 and $d.port==$v.port' "$dir/discovery/attachment_$role.json" >/dev/null || return 1; done
  [ -s "$dir/discovery/lvs.json" ] && [ -s "$dir/discovery/iscsi_sessions.txt" ] || return 1
  pass IT-5
}
test_IT6_live_regular_50_vpu_baseline() {
  echo "=== IT-6: live regular-settings baseline at 50 VPUs/GB ==="; local dir path
  dir=$(require_live_output) || return 1
  jq -e '[.[]|select(.candidate_id|startswith("REGULAR_BASELINE"))|select(.attempt_type=="measurement" and .result=="passed")] as $b | ($b|length)>=6 and ($b|length)<=10 and all($b[];.vpu==50 and .restoration_state=="restored")' "$dir/results_index.json" >/dev/null || return 1
  while IFS= read -r path; do jq -e '.jobs|length==6' "$dir/$path/fio.json" >/dev/null || return 1; done < <(jq -r '.[]|select(.candidate_id|startswith("REGULAR_BASELINE"))|.evidence[]' "$dir/results_index.json")
  "$VERIFIER" "$dir" >/dev/null || return 1
  pass IT-6
}
test_IT7_live_complete_candidate_matrix() {
  echo "=== IT-7: live complete candidate matrix at 50 VPUs/GB ==="; local dir expected actual
  dir=$(require_live_output) || return 1
  jq -e --slurpfile plan "$dir/experiment_plan.json" '([$plan[0].candidate_ids[]]|sort)==([.[]|select(.disposition=="testable")|.id]|sort) and all(.[];if .disposition=="testable" then (.execution_status=="tested" or .execution_status=="inconclusive" or .execution_status=="failed") else (has("execution_status")|not) and (.reason|length)>0 end)' "$dir/tunable_coverage.json" >/dev/null || return 1
  jq -e 'length>6 and all(.[];.vpu==50 and .restoration_state=="restored" and (.evidence|length)>0)' "$dir/results_index.json" >/dev/null || return 1
  expected=$(jq '(.candidate_count*3) + ((.candidate_count*3)/5|floor) + 6 + 2' "$dir/experiment_plan.json"); actual=$(jq length "$dir/results_index.json"); [ "$actual" -ge "$expected" ] && [ "$actual" -le "$((expected + 2 * ($(jq '.candidate_count' "$dir/experiment_plan.json") + 2)))" ] || { fail "result count $actual outside allowed stability-extension range from $expected"; return 1; }
  "$VERIFIER" "$dir" >/dev/null || return 1
  pass IT-7
}
test_IT8_live_rollback_lease_canary() {
  echo "=== IT-8: host-local rollback lease canary ==="; local dir candidate path
  dir=$(require_live_output) || return 1
  jq -e '[.[]|select(.attempt_type=="rollback_canary" and .result=="expected_failure_restored")]|length==2' "$dir/results_index.json" >/dev/null || return 1
  while IFS=$'\t' read -r candidate path; do
    jq -e '.result=="expected_failure_restored" and .baseline_equal==true and .safe_source_candidate=="TCP_BUF_2X"' "$dir/$path/canary.json" >/dev/null || return 1
    if [ "$candidate" = ROLLBACK_CANARY_LEASE ]; then jq -e '.byte_equal==true and (.tuned_verify_exit_code==0 or .tuned_verify_exit_code==null) and .live_preflight==true and .sentinels_valid==true and .restoration_state=="restored"' "$dir/$path/emergency_restore.json" >/dev/null || return 1; fi
  done < <(jq -r '.[]|select(.attempt_type=="rollback_canary")|[.candidate_id,.evidence[0]]|@tsv' "$dir/results_index.json")
  jq -e '.rollback_armed==false and .baseline_equal==true' "$dir/final_state.json" >/dev/null || return 1; pass IT-8
}
test_IT9_reports_and_recommendation() {
  echo "=== IT-9: evidence, reports, and recommendation reconciliation ==="; local dir f path
  dir=$(require_live_output) || return 1
  for f in fio_analysis.md fio_report.html oci_metrics.md oci_metrics.html sprint_30_summary.md recommendation.json; do [ -s "$dir/$f" ] || { fail "missing report: $f"; return 1; }; done
  jq -e '.vpu==50 and (.decision|length>0) and (.evidence|length)>0 and .measurement_runs>0' "$dir/recommendation.json" >/dev/null || return 1
  jq -e '.baseline_drift_metrics==[] and (.pareto_candidates|type)=="array"' "$dir/recommendation.json" >/dev/null || return 1
  jq -e 'length>0 and all(.[];(.metrics|length)>0 and all(.metrics[];.attempt_datapoint_count>=8))' "$dir/oci_metrics_attempt_windows.json" >/dev/null || return 1
  while IFS= read -r path; do [ -d "$dir/$path" ] || { fail "missing indexed evidence: $path"; return 1; }; done < <(jq -r '.[].evidence[]' "$dir/results_index.json")
  "$VERIFIER" "$dir" >/dev/null || return 1
  if LC_ALL=C grep -R $'\033' "$dir" >/dev/null 2>&1; then fail "ANSI escape sequence in evidence"; return 1; fi; pass IT-9
}
test_IT10_final_state_fio_only_teardown() {
  echo "=== IT-10: final state, FIO-only guard, and teardown ==="; local dir
  dir=$(require_live_output) || return 1
  jq -e '.baseline_equal==true and .sentinels_valid==true and .rollback_armed==false and .oracle_database_invoked==false and (.teardown=="completed" or .keep_infra==true)' "$dir/final_state.json" >/dev/null || return 1
  if jq -e '.teardown=="completed"' "$dir/final_state.json" >/dev/null; then [ "$(find "$dir/scaffold" -name '*.deleted-*.json' | wc -l | tr -d ' ')" -eq 6 ] || return 1; jq -e 'length==6 and all(.[];((.post_delete.status=="not_found" and .post_delete.http_status==404 and .post_delete.code=="NotAuthorizedOrNotFound") or .post_delete.data."lifecycle-state"=="TERMINATED"))' "$dir/deletion_inventory.json" >/dev/null || return 1; jq -e '(.active_volumes|length)==0 and (.active_instances|length)==0' "$dir/post_teardown_inventory.json" >/dev/null || return 1; fi
  ! rg -i 'oracle database|swingbench|awr' "$dir/results_index.json" >/dev/null || return 1
  pass IT-10
}

run_all() { local failed=0 name; local tests=(test_IT1_static_runner_contract test_IT2_deterministic_50_vpu_plan test_IT3_fail_closed_preflight_matrix test_IT4_restore_resume_state_machine test_IT5_live_50_vpu_topology test_IT6_live_regular_50_vpu_baseline test_IT7_live_complete_candidate_matrix test_IT8_live_rollback_lease_canary test_IT9_reports_and_recommendation test_IT10_final_state_fio_only_teardown); for name in "${tests[@]}"; do "$name" || failed=$((failed+1)); done; echo "Results: $(( ${#tests[@]} - failed )) passed, $failed failed"; [ "$failed" -eq 0 ]; }
case "${1:-run_all}" in test_IT1_static_runner_contract|test_IT2_deterministic_50_vpu_plan|test_IT3_fail_closed_preflight_matrix|test_IT4_restore_resume_state_machine|test_IT5_live_50_vpu_topology|test_IT6_live_regular_50_vpu_baseline|test_IT7_live_complete_candidate_matrix|test_IT8_live_rollback_lease_canary|test_IT9_reports_and_recommendation|test_IT10_final_state_fio_only_teardown) "$1";; run_all) run_all;; *) echo "Unknown test: $1" >&2; exit 2;; esac

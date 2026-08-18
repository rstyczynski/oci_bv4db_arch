#!/usr/bin/env bash
# Sprint 30 integration tests for the single-path iSCSI tuning domain.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$REPO_DIR/tools/oci_bv_single_path_tuning.sh"
fail() { echo "FAIL: $*" >&2; return 1; }
pass() { echo "PASS: $*"; }
new_tmp() { mktemp -d "${TMPDIR:-/tmp}/sprint30-test.XXXXXX"; }

write_valid_fixture() {
  jq -n '{compute:{shape:"VM.Standard.E5.Flex",ocpus:4,memory_gb:32,image_pinned:true,architecture:"x86_64"},volumes:[range(0;5)|{vpu:50,is_multipath:false,multipath_devices:0,sessions:1,device_id:("device-"+tostring)}],layout:{data_stripes:2,redo_stripes:2,stripe_kib:256,fra_direct:true,mounts:["/u02/oradata","/u03/redo","/u04/fra"]},route:{same_interface:true},sentinels:{valid:true},credentials:{valid:true}}' > "$1"
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
  "$RUNNER" --plan --output-dir "$tmp" --seed 30050 >/dev/null || return 1
  jq -e '.vpus==[50] and .repeats==3 and .multipath==false and .oracle_database==false and (.layout|length)==5 and ([.layout[].path]|sort)==["/dev/oracleoci/oraclevdb","/dev/oracleoci/oraclevdc","/dev/oracleoci/oraclevdd","/dev/oracleoci/oraclevde","/dev/oracleoci/oraclevdf"] and .fio.global.ioengine=="libaio" and .fio.global.direct==1 and .fio.global.runtime==600 and .fio.global.ramp_time==60 and ([.fio.jobs[].id]|sort)==["data-8k","fra-1m","redo"]' "$tmp/experiment_plan.json" >/dev/null || return 1
  if "$RUNNER" --plan --output-dir "$tmp/rejected" --vpu 45 >/dev/null 2>&1; then fail "runner accepted non-Sprint-30 VPU"; return 1; fi
  pass IT-1
}

test_IT2_deterministic_50_vpu_plan() {
  echo "=== IT-2: deterministic 50-VPU experiment plan and coverage ledger ==="
  local tmp; tmp=$(new_tmp); trap 'rm -rf "$tmp"' RETURN
  "$RUNNER" --plan --output-dir "$tmp/first" --seed 17 >/dev/null || return 1
  "$RUNNER" --plan --output-dir "$tmp/second" --seed 17 >/dev/null || return 1
  cmp "$tmp/first/experiment_plan.json" "$tmp/second/experiment_plan.json" || { fail "plan is not deterministic"; return 1; }
  jq -e '.vpus==[50] and .repeats==3 and ([.attempts[]|select(.attempt_type=="rollback_canary")]|length)==2 and ([.attempts[]|select(.attempt_type=="measurement" and (.block==1 or .block==2 or .block==3))|.candidate_id]|sort|group_by(.)|all(length==3)) and ([.attempts[].vpu]|unique)==[50]' "$tmp/first/experiment_plan.json" >/dev/null || return 1
  jq -e 'all(.[];if .disposition=="testable" then .execution_status=="pending" else (has("execution_status")|not) and (.reason|length>0) and (.evidence|length>0) end)' "$tmp/first/tunable_coverage.json" >/dev/null || return 1
  pass IT-2
}

test_IT3_fail_closed_preflight_matrix() {
  echo "=== IT-3: fail-closed preflight matrix ==="
  local tmp fixture field bad; tmp=$(new_tmp); trap 'rm -rf "$tmp"' RETURN; fixture="$tmp/valid.json"; write_valid_fixture "$fixture"
  "$RUNNER" --plan --output-dir "$tmp/valid" --fixture "$fixture" >/dev/null || return 1
  for field in bad_ocpu bad_vpu bad_multipath bad_session bad_layout bad_route bad_sentinel bad_credentials; do
    bad="$tmp/$field.json"
    case "$field" in
      bad_ocpu) jq '.compute.ocpus=8' "$fixture" > "$bad";; bad_vpu) jq '.volumes[0].vpu=45' "$fixture" > "$bad";; bad_multipath) jq '.volumes[0].is_multipath=true' "$fixture" > "$bad";; bad_session) jq '.volumes[0].sessions=2' "$fixture" > "$bad";; bad_layout) jq '.layout.stripe_kib=64' "$fixture" > "$bad";; bad_route) jq '.route.same_interface=false' "$fixture" > "$bad";; bad_sentinel) jq '.sentinels.valid=false' "$fixture" > "$bad";; bad_credentials) jq '.credentials.valid=false' "$fixture" > "$bad";;
    esac
    if "$RUNNER" --plan --output-dir "$tmp/$field" --fixture "$bad" >/dev/null 2>&1; then fail "$field passed preflight"; return 1; fi
    jq -e 'length==0' "$tmp/$field/mutation_journal.json" >/dev/null || return 1
    jq -e 'length==0' "$tmp/$field/fio_journal.json" >/dev/null || return 1
  done
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
  pass IT-4
}

test_IT5_live_50_vpu_topology() {
  echo "=== IT-5: live 50-VPU topology and integrity preflight ==="; local dir
  maybe_execute_live || return 1
  dir=$(require_live_output) || return 1
  jq -e '.status=="completed" and .topology_verified==true and .vpu==50 and .single_path==true and .sentinels_valid==true' "$dir/run_state.json" >/dev/null || return 1
  jq -e '(.volumes|length)==5 and all(.volumes[];.vpu==50 and .created==true and .is_multipath==false and .multipath_devices==0 and (.volume_ocid|length)>0 and (.attachment_ocid|length)>0) and ([.volumes[].path]|unique|length)==5 and .guest_cpus==8 and .layout.data_stripes==2 and .layout.redo_stripes==2 and .layout.stripe_kib==256 and .layout.fra_direct==true and .sentinels_valid==true' "$dir/live_topology.json" >/dev/null || return 1
  jq -e '.compute.shape=="VM.Standard.E5.Flex" and .compute.ocpus==4 and .compute.memory_gb==32 and (.compute.image_ocid|length)>0' "$dir/target_manifest.json" >/dev/null || return 1
  [ -s "$dir/discovery/lvs.json" ] && [ -s "$dir/discovery/iscsi_sessions.txt" ] || return 1
  pass IT-5
}
test_IT6_live_regular_50_vpu_baseline() {
  echo "=== IT-6: live regular-settings baseline at 50 VPUs/GB ==="; local dir path
  dir=$(require_live_output) || return 1
  jq -e '[.[]|select(.candidate_id|startswith("REGULAR_BASELINE"))|select(.attempt_type=="measurement" and .result=="passed")]|length==6 and all(.[];.vpu==50 and .restoration_state=="restored")' "$dir/results_index.json" >/dev/null || return 1
  while IFS= read -r path; do jq -e '.jobs|length==6' "$dir/$path/fio.json" >/dev/null || return 1; done < <(jq -r '.[]|select(.candidate_id|startswith("REGULAR_BASELINE"))|.evidence[]' "$dir/results_index.json")
  pass IT-6
}
test_IT7_live_complete_candidate_matrix() {
  echo "=== IT-7: live complete candidate matrix at 50 VPUs/GB ==="; local dir expected actual
  dir=$(require_live_output) || return 1
  jq -e 'length>0 and all(.[];if .disposition=="testable" then .execution_status=="tested" else (has("execution_status")|not) and (.reason|length)>0 end)' "$dir/tunable_coverage.json" >/dev/null || return 1
  jq -e 'length>6 and all(.[];.vpu==50 and .restoration_state=="restored" and (.evidence|length)>0)' "$dir/results_index.json" >/dev/null || return 1
  expected=$(jq '[.[]|select(.disposition=="testable")]|length*9 + 6 + 2' "$dir/tunable_coverage.json"); actual=$(jq length "$dir/results_index.json"); [ "$actual" -eq "$expected" ] || { fail "result count $actual != expected $expected"; return 1; }
  pass IT-7
}
test_IT8_live_rollback_lease_canary() {
  echo "=== IT-8: host-local rollback lease canary ==="; local dir path
  dir=$(require_live_output) || return 1
  jq -e '[.[]|select(.attempt_type=="rollback_canary" and .result=="expected_failure_restored")]|length==2' "$dir/results_index.json" >/dev/null || return 1
  while IFS= read -r path; do jq -e '.result=="expected_failure_restored" and .baseline_equal==true' "$dir/$path/canary.json" >/dev/null || return 1; done < <(jq -r '.[]|select(.attempt_type=="rollback_canary")|.evidence[]' "$dir/results_index.json")
  jq -e '.rollback_armed==false and .baseline_equal==true' "$dir/final_state.json" >/dev/null || return 1; pass IT-8
}
test_IT9_reports_and_recommendation() {
  echo "=== IT-9: evidence, reports, and recommendation reconciliation ==="; local dir f path
  dir=$(require_live_output) || return 1
  for f in fio_analysis.md fio_report.html oci_metrics.md oci_metrics.html sprint_30_summary.md recommendation.json; do [ -s "$dir/$f" ] || { fail "missing report: $f"; return 1; }; done
  jq -e '.vpu==50 and (.decision|length>0) and (.evidence|length)>0 and .measurement_runs>0' "$dir/recommendation.json" >/dev/null || return 1
  while IFS= read -r path; do [ -d "$dir/$path" ] || { fail "missing indexed evidence: $path"; return 1; }; done < <(jq -r '.[].evidence[]' "$dir/results_index.json")
  if LC_ALL=C grep -R $'\033' "$dir" >/dev/null 2>&1; then fail "ANSI escape sequence in evidence"; return 1; fi; pass IT-9
}
test_IT10_final_state_fio_only_teardown() {
  echo "=== IT-10: final state, FIO-only guard, and teardown ==="; local dir
  dir=$(require_live_output) || return 1
  jq -e '.baseline_equal==true and .sentinels_valid==true and .rollback_armed==false and .oracle_database_invoked==false and (.teardown=="completed" or .keep_infra==true)' "$dir/final_state.json" >/dev/null || return 1
  if jq -e '.teardown=="completed"' "$dir/final_state.json" >/dev/null; then [ "$(find "$dir/scaffold" -name '*.deleted-*.json' | wc -l | tr -d ' ')" -eq 6 ] || return 1; fi
  ! rg -i 'oracle database|swingbench|awr' "$dir/results_index.json" >/dev/null || return 1
  pass IT-10
}

run_all() { local failed=0 name; local tests=(test_IT1_static_runner_contract test_IT2_deterministic_50_vpu_plan test_IT3_fail_closed_preflight_matrix test_IT4_restore_resume_state_machine test_IT5_live_50_vpu_topology test_IT6_live_regular_50_vpu_baseline test_IT7_live_complete_candidate_matrix test_IT8_live_rollback_lease_canary test_IT9_reports_and_recommendation test_IT10_final_state_fio_only_teardown); for name in "${tests[@]}"; do "$name" || failed=$((failed+1)); done; echo "Results: $(( ${#tests[@]} - failed )) passed, $failed failed"; [ "$failed" -eq 0 ]; }
case "${1:-run_all}" in test_IT1_static_runner_contract|test_IT2_deterministic_50_vpu_plan|test_IT3_fail_closed_preflight_matrix|test_IT4_restore_resume_state_machine|test_IT5_live_50_vpu_topology|test_IT6_live_regular_50_vpu_baseline|test_IT7_live_complete_candidate_matrix|test_IT8_live_rollback_lease_canary|test_IT9_reports_and_recommendation|test_IT10_final_state_fio_only_teardown) "$1";; run_all) run_all;; *) echo "Unknown test: $1" >&2; exit 2;; esac

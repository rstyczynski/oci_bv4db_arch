#!/usr/bin/env bash
# Live integration test for Sprint 27 non-UHP to UHP VPU update behavior.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODULE_DIR="$REPO_ROOT/terraform/sprint27-vpu-upgrade-multipath"
PROGRESS_DIR="$REPO_ROOT/progress/sprint_27"
REMOTE_SCRIPT_DIR="$REPO_ROOT/tests/integration/sprint27/remote"
STATE_FILE="$REPO_ROOT/progress/sprint_1/state-bv4db.json"
OCI_PROFILE="${OCI_CLI_PROFILE:-avq3}"
export OCI_CLI_PROFILE="$OCI_PROFILE"
export TF_CLI_ARGS="-no-color ${TF_CLI_ARGS:-}"
SPRINT27_CASES="${SPRINT27_CASES:-tc1 tc2 tc3 tc4}"
SPRINT27_POLL_RETRIES="${SPRINT27_POLL_RETRIES:-8}"
SPRINT27_POLL_SLEEP_SECONDS="${SPRINT27_POLL_SLEEP_SECONDS:-15}"
export SPRINT27_DEVICE_WAIT_POLLS="${SPRINT27_DEVICE_WAIT_POLLS:-$SPRINT27_POLL_RETRIES}"
export SPRINT27_DEVICE_WAIT_SLEEP_SECONDS="${SPRINT27_DEVICE_WAIT_SLEEP_SECONDS:-$SPRINT27_POLL_SLEEP_SECONDS}"

PASS=0
FAIL=0
TMPDIR=""
WORKDIR=""
EVIDENCE=""
REATTACHED_ATTACHMENT_ID=""
SCENARIO_WORKDIRS=""
SCENARIO_ATTACHMENTS=""

pass() { echo "PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

trace() {
  if [ -n "${EVIDENCE:-}" ]; then
    printf '%s\n' "$*" | tee -a "$EVIDENCE"
  else
    printf '%s\n' "$*"
  fi
}

require_file() {
  local path="$1"
  if [ -f "$path" ]; then
    pass "file exists: ${path#$REPO_ROOT/}"
  else
    fail "missing file: ${path#$REPO_ROOT/}"
  fi
}

require_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$path"; then
    pass "$label"
  else
    fail "$label"
  fi
}

require_not_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$path"; then
    fail "$label"
  else
    pass "$label"
  fi
}

require_tree_not_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if find "$path" -type f \
      ! -path '*/.terraform/*' \
      ! -name '.terraform.lock.hcl' \
      \( -name '*.tf' -o -name '*.sh' \) \
      -exec grep -Eq "$pattern" {} +; then
    fail "$label"
  else
    pass "$label"
  fi
}

cleanup() {
  local attachment workdir
  for attachment in $SCENARIO_ATTACHMENTS; do
    if [ -n "$attachment" ] && [ "${SPRINT27_KEEP_INFRA:-false}" != "true" ]; then
      oci compute volume-attachment detach \
        --volume-attachment-id "$attachment" \
        --force \
        --wait-for-state DETACHED \
        --max-wait-seconds 900 \
        --wait-interval-seconds 15 >/dev/null 2>&1 || true
    fi
  done
  for workdir in $SCENARIO_WORKDIRS; do
    if [ -n "$workdir" ] && [ -d "$workdir" ] && [ "${SPRINT27_KEEP_INFRA:-false}" != "true" ]; then
      terraform -chdir="$workdir" destroy -auto-approve -input=false >/dev/null 2>&1 || true
    fi
  done
  if [ -n "${REATTACHED_ATTACHMENT_ID:-}" ] && [ "${SPRINT27_KEEP_INFRA:-false}" != "true" ]; then
    oci compute volume-attachment detach \
      --volume-attachment-id "$REATTACHED_ATTACHMENT_ID" \
      --force \
      --wait-for-state DETACHED \
      --max-wait-seconds 900 \
      --wait-interval-seconds 15 >/dev/null 2>&1 || true
  fi
  if [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && [ "${SPRINT27_KEEP_INFRA:-false}" != "true" ]; then
    terraform -chdir="$WORKDIR" destroy -auto-approve -input=false >/dev/null 2>&1 || true
  fi
  if [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

json_value() {
  jq -r "$1 // empty" "$STATE_FILE"
}

discover_context() {
  REGION="${OCI_REGION:-$(json_value '.inputs.oci_region')}"
  COMPARTMENT_ID="${COMPARTMENT_OCID:-$(json_value '.compartment.ocid')}"
  SUBNET_ID="${SUBNET_OCID:-$(json_value '.subnet.ocid')}"

  [ -n "$REGION" ] || { echo "missing region" >&2; return 1; }
  [ -n "$COMPARTMENT_ID" ] || { echo "missing compartment" >&2; return 1; }
  [ -n "$SUBNET_ID" ] || { echo "missing subnet" >&2; return 1; }

  AVAILABILITY_DOMAIN="${AVAILABILITY_DOMAIN:-$(oci iam availability-domain list \
    --compartment-id "$COMPARTMENT_ID" \
    --query 'data[0].name' \
    --raw-output 2>/dev/null || true)}"
  IMAGE_ID="${IMAGE_ID:-$(oci compute image list \
    --compartment-id "$COMPARTMENT_ID" \
    --operating-system 'Oracle Linux' \
    --shape VM.Standard.E5.Flex \
    --sort-by TIMECREATED \
    --sort-order DESC \
    --query 'data[0].id' \
    --raw-output 2>/dev/null || true)}"

  [ -n "$AVAILABILITY_DOMAIN" ] || { echo "missing availability domain" >&2; return 1; }
  [ -n "$IMAGE_ID" ] || { echo "missing image id" >&2; return 1; }
}

attachment_json() {
  terraform -chdir="$WORKDIR" show -json \
    | jq -e '.values.root_module.resources[]
      | select(.address == "oci_core_volume_attachment.test")
      | .values'
}

attachment_get_json() {
  local attachment_id="$1"
  oci compute volume-attachment get --volume-attachment-id "$attachment_id"
}

wait_volume_available() {
  local volume_id="$1"
  local state
  for _ in $(seq 1 60); do
    state="$(oci bv volume get --volume-id "$volume_id" --query 'data."lifecycle-state"' --raw-output 2>/dev/null || true)"
    echo "volume poll lifecycle_state=$state"
    if [ "$state" = "AVAILABLE" ]; then
      return 0
    fi
    sleep 15
  done
  return 1
}

write_evidence_header() {
  local ts
  ts="$(date -u '+%Y%m%d_%H%M%S')"
  EVIDENCE="$PROGRESS_DIR/vpu_upgrade_multipath_evidence_${ts}.txt"
  {
    echo "=== Sprint 27 non-UHP to UHP VPU update evidence ==="
    echo "timestamp_utc=$ts"
    echo "workdir=$WORKDIR"
    echo "region=$REGION"
    echo "oci_profile=$OCI_PROFILE"
    echo "compartment_id=$COMPARTMENT_ID"
    echo "subnet_id=$SUBNET_ID"
    echo "availability_domain=$AVAILABILITY_DOMAIN"
    echo "image_id=$IMAGE_ID"
    echo
  } > "$EVIDENCE"
}

append_oci_evidence() {
  local label="$1"
  local attachment_id="${2:-}"
  local volume_id
  volume_id="$(terraform -chdir="$WORKDIR" output -raw volume_id)"
  if [ -z "$attachment_id" ]; then
    attachment_id="$(terraform -chdir="$WORKDIR" output -raw volume_attachment_id)"
  fi

  {
    echo "=== $label: terraform outputs ==="
    terraform -chdir="$WORKDIR" output
    echo
    echo "=== $label: attachment state json ==="
    attachment_json
    echo
    echo "=== $label: OCI volume get ==="
    oci bv volume get --volume-id "$volume_id"
    echo
    echo "=== $label: OCI attachment get ==="
    oci compute volume-attachment get --volume-attachment-id "$attachment_id"
    echo
  } >> "$EVIDENCE" 2>&1
}

append_guest_evidence() {
  local label="$1"
  local public_ip key_path
  public_ip="$(terraform -chdir="$WORKDIR" output -raw instance_public_ip 2>/dev/null || true)"
  key_path="$TMPDIR/sprint27.key"

  {
    echo "=== $label: guest evidence ==="
    echo "public_ip=$public_ip"
  } >> "$EVIDENCE"

  if [ -z "$public_ip" ]; then
    echo "guest_status=SKIPPED_NO_PUBLIC_IP" >> "$EVIDENCE"
    return 1
  fi

  for _ in $(seq 1 30); do
    if ssh -i "$key_path" \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      "opc@$public_ip" 'true' >/dev/null 2>&1; then
      break
    fi
    sleep 10
  done

  ssh -i "$key_path" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=20 \
    "opc@$public_ip" 'bash -s' >> "$EVIDENCE" 2>&1 <<'REMOTE'
set -o pipefail
echo "--- oracle-cloud-agent ---"
systemctl is-active oracle-cloud-agent || true
systemctl is-enabled oracle-cloud-agent || true
rpm -q oracle-cloud-agent device-mapper-multipath || true
echo "--- IMDS volume attachments ---"
curl -sS -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/volumeAttachments/ 2>&1 || true
echo
echo "--- block plugin log tail ---"
sudo tail -220 /var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log 2>&1 || true
echo "--- iscsi sessions ---"
sudo iscsiadm -m session 2>&1 || true
echo "--- multipath -ll ---"
sudo multipath -ll 2>&1 || true
echo "--- multipathd paths ---"
sudo multipathd show paths 2>&1 || true
echo "--- multipath.conf ---"
sudo sed -n '1,220p' /etc/multipath.conf 2>&1 || true
echo "--- lsblk ---"
lsblk -o NAME,TYPE,SIZE,MODEL,WWN,FSTYPE,MOUNTPOINT 2>&1 || true
REMOTE
}

attachment_state_line() {
  local label="$1"
  local mode="$2"
  local attachment_id="${3:-}"
  local is_multipath multipath_count iscsi_state

  if [ -n "$attachment_id" ]; then
    local get_json
    get_json="$(attachment_get_json "$attachment_id" 2>/dev/null || true)"
    is_multipath="$(printf '%s\n' "$get_json" | jq -r '.data."is-multipath" // "null"' 2>/dev/null || echo "null")"
    multipath_count="$(printf '%s\n' "$get_json" | jq -r '(.data."multipath-devices" // []) | length' 2>/dev/null || echo "0")"
    iscsi_state="$(printf '%s\n' "$get_json" | jq -r '.data."iscsi-login-state" // "null"' 2>/dev/null || echo "null")"
  else
    terraform -chdir="$WORKDIR" apply -refresh-only -auto-approve -input=false >/dev/null || true
    is_multipath="$(attachment_json | jq -r '.is_multipath // "null"')"
    multipath_count="$(attachment_json | jq -r '(.multipath_devices // []) | length')"
    iscsi_state="$(attachment_json | jq -r '.iscsi_login_state // "null"')"
  fi

  echo "$label $mode is_multipath=$is_multipath multipath_devices=$multipath_count iscsi_login_state=$iscsi_state"
  [ "$is_multipath" = "true" ] && [ "$multipath_count" -ge 2 ]
}

poll_for_non_multipath() {
  local label="$1"
  local max_polls="${2:-$SPRINT27_POLL_RETRIES}"
  local attachment_id="${3:-}"
  local is_multipath multipath_count iscsi_state i
  for i in $(seq 1 "$max_polls"); do
    if [ -n "$attachment_id" ]; then
      local get_json
      get_json="$(attachment_get_json "$attachment_id" 2>/dev/null || true)"
      is_multipath="$(printf '%s\n' "$get_json" | jq -r '.data."is-multipath" // "null"' 2>/dev/null || echo "null")"
      multipath_count="$(printf '%s\n' "$get_json" | jq -r '(.data."multipath-devices" // []) | length' 2>/dev/null || echo "0")"
      iscsi_state="$(printf '%s\n' "$get_json" | jq -r '.data."iscsi-login-state" // "null"' 2>/dev/null || echo "null")"
    else
      terraform -chdir="$WORKDIR" apply -refresh-only -auto-approve -input=false >/dev/null || true
      is_multipath="$(attachment_json | jq -r '.is_multipath // "null"')"
      multipath_count="$(attachment_json | jq -r '(.multipath_devices // []) | length')"
      iscsi_state="$(attachment_json | jq -r '.iscsi_login_state // "null"')"
    fi

    echo "$label expected-non-multipath is_multipath=$is_multipath multipath_devices=$multipath_count iscsi_login_state=$iscsi_state"
    if [ "$is_multipath" != "true" ] && [ "$multipath_count" -eq 0 ]; then
      return 0
    fi
    if [ "$i" -lt "$max_polls" ]; then
      sleep "$SPRINT27_POLL_SLEEP_SECONDS"
    fi
  done
  return 1
}

refresh_and_poll() {
  local label="$1"
  local max_polls="${2:-$SPRINT27_POLL_RETRIES}"
  local attachment_id="${3:-}"
  local i
  for i in $(seq 1 "$max_polls"); do
    if attachment_state_line "$label" "poll" "$attachment_id"; then
      return 0
    fi
    if [ "$i" -lt "$max_polls" ]; then
      sleep "$SPRINT27_POLL_SLEEP_SECONDS"
    fi
  done
  return 1
}

remote_exec() {
  local script="$1"
  local public_ip key_path
  public_ip="$(terraform -chdir="$WORKDIR" output -raw instance_public_ip 2>/dev/null || true)"
  key_path="$TMPDIR/sprint27.key"

  for _ in $(seq 1 30); do
    if ssh -i "$key_path" \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      "opc@$public_ip" 'true' >/dev/null 2>&1; then
      break
    fi
    sleep 10
  done

  ssh -i "$key_path" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=30 \
	    "opc@$public_ip" 'bash -s' <<< "$script"
}

run_remote_trace() {
  local script="$1"
  set +e
  remote_exec "$script" 2>&1 | tee -a "$EVIDENCE"
  local rc=${PIPESTATUS[0]}
  set -e
  return "$rc"
}

run_remote_capture_trace() {
  local script="$1"
  local output_file="$2"
  set +e
  remote_exec "$script" 2>&1 | tee "$output_file" | tee -a "$EVIDENCE"
  local rc=${PIPESTATUS[0]}
  set -e
  return "$rc"
}

shell_quote() {
  printf '%q' "$1"
}

remote_script_file() {
  local script_name="$1"
  local path="$REMOTE_SCRIPT_DIR/$script_name"
  if [ ! -f "$path" ]; then
    echo "missing remote script: $path" >&2
    return 1
  fi
  cat "$path"
}

remote_script_with_iscsi_helpers() {
  local script_name="$1"
  local env_block="${2:-}"
  {
    remote_script_file "baseline_iscsi_helpers.sh"
    printf '%s\n' "$env_block"
    remote_script_file "$script_name"
  }
}

assert_uhp_consistent_path() {
  local label="$1"
  local output_file="$TMPDIR/${label}-consistent-path.txt"
  trace "=== ${label}: UHP consistent device path validation ==="
  trace "oracle_reference=https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtouhpvolumes.htm"
  trace "expected=the configured OCI consistent device path exists and resolves to the multipath friendly device"
  run_remote_capture_trace "$(remote_script_file "assert_uhp_consistent_path.sh")" "$output_file"
}

wait_for_agent_multipath_login() {
  local label="$1"
  local output_file="$TMPDIR/${label}-agent-multipath-wait.txt"
  trace "=== ${label}: passive wait for OCI agent iSCSI/multipath login ==="
  trace "owner=Oracle Cloud Agent Block Volume Management plugin"
  trace "policy=diagnostics_only_no_mpathconf_no_modprobe_no_service_mutation"
  run_remote_capture_trace "$(remote_script_file "wait_for_agent_multipath_login.sh")" "$output_file"
}

begin_case() {
  local case_id="$1"
  WORKDIR="$TMPDIR/$case_id"
  cp -R "$MODULE_DIR" "$WORKDIR"
  SCENARIO_WORKDIRS="$SCENARIO_WORKDIRS $WORKDIR"
  cat > "$WORKDIR/terraform.tfvars" <<EOF
region = "$REGION"
oci_profile = "$OCI_PROFILE"
compartment_id = "$COMPARTMENT_ID"
availability_domain = "$AVAILABILITY_DOMAIN"
subnet_id = "$SUBNET_ID"
image_id = "$IMAGE_ID"
ssh_public_key_path = "$TMPDIR/sprint27.key.pub"

name_prefix = "bv4db-s27-$case_id"
compute_shape = "VM.Standard.E5.Flex"
compute_ocpus = 16
compute_memory_gb = 64
assign_public_ip = true
volume_size_gbs = 1500
initial_volume_vpus_per_gb = 20
device_path = "/dev/oracleoci/oraclevdb"
EOF

  terraform -chdir="$WORKDIR" init -input=false || return 1
  terraform -chdir="$WORKDIR" validate || return 1
  terraform -chdir="$WORKDIR" apply -auto-approve -input=false || return 1
}

finish_case() {
  local attachment="$1"
  if [ -n "$attachment" ]; then
    oci compute volume-attachment detach \
      --volume-attachment-id "$attachment" \
      --force \
      --wait-for-state DETACHED \
      --max-wait-seconds 900 \
      --wait-interval-seconds 15 >> "$EVIDENCE" 2>&1 || true
  fi
  terraform -chdir="$WORKDIR" destroy -auto-approve -input=false >> "$EVIDENCE" 2>&1 || true
}

tc1_inplace_update_negative() {
  echo "=== TC1: 20 to 100 without detach - expected negative ===" >> "$EVIDENCE"
  echo "TC1 start: in-place update keeps the original attachment active."
  begin_case "tc1-inplace-negative" || return 1

  poll_for_non_multipath "baseline-non-uhp" || true
  append_oci_evidence "tc1-baseline-non-uhp"

  local volume_id old_attachment_id result
  volume_id="$(terraform -chdir="$WORKDIR" output -raw volume_id)"
  old_attachment_id="$(terraform -chdir="$WORKDIR" output -raw volume_attachment_id)"

  {
    echo "=== TC1 action: update attached volume to 100 without detach ==="
    echo "detach_before_update=false"
    echo "expected_result=NEGATIVE_INPLACE_NO_MULTIPATH"
    echo "oci bv volume update --volume-id $volume_id --vpus-per-gb 100 --force"
  } >> "$EVIDENCE"
  oci bv volume update --volume-id "$volume_id" --vpus-per-gb 100 --force >> "$EVIDENCE" 2>&1
  wait_volume_available "$volume_id" >> "$EVIDENCE" 2>&1 || true

  if ! poll_for_non_multipath "tc1-after-inplace-vpu-100"; then
    result="UNEXPECTED_MULTIPATH_AFTER_INPLACE_UPDATE"
    echo "TC1_RESULT=$result" >> "$EVIDENCE"
    finish_case ""
    return 1
  fi

  result="NEGATIVE_INPLACE_NO_MULTIPATH"
  echo "TC1_RESULT=$result" >> "$EVIDENCE"
  append_oci_evidence "tc1-after-inplace-vpu-100"
  append_guest_evidence "tc1-after-inplace-vpu-100" || true
  finish_case ""
  pass "TC1 in-place 20 to 100 without detach stayed non-multipath"
}

tc2_detach_update_positive() {
  echo "=== TC2: 20 to 100 with detach - expected positive ===" >> "$EVIDENCE"
  echo "TC2 start: detach, update, reattach should enable multipath."
  begin_case "tc2-detach-positive" || return 1

  poll_for_non_multipath "tc2-baseline-non-uhp" || true
  append_oci_evidence "tc2-baseline-non-uhp"

  local volume_id instance_id old_attachment_id new_attachment_id result consistent_path_ok agent_wait_ok
  volume_id="$(terraform -chdir="$WORKDIR" output -raw volume_id)"
  instance_id="$(terraform -chdir="$WORKDIR" output -raw instance_id)"
  old_attachment_id="$(terraform -chdir="$WORKDIR" output -raw volume_attachment_id)"
  {
    echo "=== TC2 action: detach before VPU update ==="
    echo "oracle_reference=https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm"
    echo "reason=Oracle documents multipath enablement during attachment; the volume is detached before changing to UHP so the next attachment is evaluated as UHP."
    echo "detach_before_update=true"
    echo "reattach_before_update=false"
    echo "old_volume_attachment_id=$old_attachment_id"
    echo "oci compute volume-attachment detach --volume-attachment-id $old_attachment_id --force --wait-for-state DETACHED"
  } >> "$EVIDENCE"
  echo "TC2 detach before update: detach_before_update=true old_volume_attachment_id=$old_attachment_id"
  oci compute volume-attachment detach \
    --volume-attachment-id "$old_attachment_id" \
    --force \
    --wait-for-state DETACHED \
    --max-wait-seconds 900 \
    --wait-interval-seconds 15 >> "$EVIDENCE" 2>&1

  {
    echo "=== TC2 action: update detached volume ==="
    echo "attachment_lifecycle=detached_before_vpu_update"
    echo "oci bv volume update --volume-id $volume_id --vpus-per-gb 100 --force"
  } >> "$EVIDENCE"
  echo "TC2 update action: detach_before_update=true attachment_lifecycle=detached_before_vpu_update"
  oci bv volume update --volume-id "$volume_id" --vpus-per-gb 100 --force >> "$EVIDENCE" 2>&1
  wait_volume_available "$volume_id" >> "$EVIDENCE" 2>&1 || true

  {
    echo "=== TC2 action: attach after VPU update ==="
    echo "oracle_reference=https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm"
    echo "reason=Attach the now-UHP volume after the VPU update so OCI can evaluate multipath at attachment time."
    echo "attach_after_update=true"
    echo "oci compute volume-attachment attach-iscsi-volume --instance-id $instance_id --volume-id $volume_id --device /dev/oracleoci/oraclevdb --display-name bv4db-s27-vpu-upgrade-reattachment --wait-for-state ATTACHED"
  } >> "$EVIDENCE"
  echo "TC2 attach after update: attach_after_update=true"
  new_attachment_id="$(oci compute volume-attachment attach-iscsi-volume \
    --instance-id "$instance_id" \
    --volume-id "$volume_id" \
    --device "/dev/oracleoci/oraclevdb" \
    --display-name "bv4db-s27-vpu-upgrade-reattachment" \
    --wait-for-state ATTACHED \
    --max-wait-seconds 900 \
    --wait-interval-seconds 15 \
    --query 'data.id' \
    --raw-output)"
  REATTACHED_ATTACHMENT_ID="$new_attachment_id"
  SCENARIO_ATTACHMENTS="$SCENARIO_ATTACHMENTS $new_attachment_id"
  {
    echo "new_volume_attachment_id=$new_attachment_id"
  } >> "$EVIDENCE"

  if refresh_and_poll "tc2-after-attach-vpu-100" "$SPRINT27_POLL_RETRIES" "$new_attachment_id"; then
    result="PASS_DETACH_UPDATE_ATTACH_MULTIPATH"
  else
    result="NEGATIVE_AFTER_DETACH_UPDATE_ATTACH"
  fi

  append_oci_evidence "tc2-after-attach-vpu-100" "$new_attachment_id"
  agent_wait_ok=false
  if [ "$result" = "PASS_DETACH_UPDATE_ATTACH_MULTIPATH" ] && wait_for_agent_multipath_login "tc2-after-attach-vpu-100"; then
    agent_wait_ok=true
  fi
  consistent_path_ok=false
  if [ "$result" = "PASS_DETACH_UPDATE_ATTACH_MULTIPATH" ] && assert_uhp_consistent_path "tc2-after-attach-vpu-100"; then
    consistent_path_ok=true
  fi
  append_guest_evidence "tc2-after-attach-vpu-100" || true

  if [ "$result" = "PASS_DETACH_UPDATE_ATTACH_MULTIPATH" ] && [ "$consistent_path_ok" != "true" ]; then
    result="NEGATIVE_AFTER_DETACH_UPDATE_ATTACH_CONSISTENT_PATH_INVALID"
    {
      echo "tc2_agent_wait_ok=$agent_wait_ok"
      echo "tc2_failure_description=OCI reported a multipath-enabled UHP attachment, but the OCI agent did not expose the configured consistent device path resolving to the multipath friendly device within the passive wait window."
    } >> "$EVIDENCE"
  fi

  echo "TC2_RESULT=$result" >> "$EVIDENCE"
  finish_case "$new_attachment_id"
  REATTACHED_ATTACHMENT_ID=""
  [ "$result" = "PASS_DETACH_UPDATE_ATTACH_MULTIPATH" ] || return 1
  pass "TC2 detach-update-reattach enabled multipath"
}

tc3_linux_unsafe_negative() {
  echo "=== TC3: detach while Linux process writes - expected negative/hazardous ===" >> "$EVIDENCE"
  echo "TC3 start: unsafe Linux procedure uses disposable mounted data and a writer process."
  begin_case "tc3-linux-unsafe" || return 1

  poll_for_non_multipath "tc3-baseline-non-uhp" || true
  append_oci_evidence "tc3-baseline-non-uhp"

  local volume_id instance_id old_attachment_id new_attachment_id result
  local old_attachment_json old_iqn old_ip old_port old_chap_user old_chap_secret
  local old_iqn_q old_ip_q old_port_q old_chap_user_q old_chap_secret_q
  local remote_iscsi_env
  volume_id="$(terraform -chdir="$WORKDIR" output -raw volume_id)"
  instance_id="$(terraform -chdir="$WORKDIR" output -raw instance_id)"
  old_attachment_id="$(terraform -chdir="$WORKDIR" output -raw volume_attachment_id)"
  old_attachment_json="$(attachment_get_json "$old_attachment_id")"
  old_iqn="$(printf '%s\n' "$old_attachment_json" | jq -r '.data.iqn // empty')"
  old_ip="$(printf '%s\n' "$old_attachment_json" | jq -r '.data.ipv4 // empty')"
  old_port="$(printf '%s\n' "$old_attachment_json" | jq -r '.data.port // empty')"
  old_chap_user="$(printf '%s\n' "$old_attachment_json" | jq -r '.data."chap-username" // empty')"
  old_chap_secret="$(printf '%s\n' "$old_attachment_json" | jq -r '.data."chap-secret" // empty')"

  if [ -z "$old_iqn" ] || [ -z "$old_ip" ] || [ -z "$old_port" ]; then
    result="INCONCLUSIVE_TC3_ATTACHMENT_ISCSI_METADATA_MISSING"
    {
      echo "TC3_RESULT=$result"
      echo "old_volume_attachment_id=$old_attachment_id"
      echo "old_iqn=$old_iqn"
      echo "old_ip=$old_ip"
      echo "old_port=$old_port"
      echo "tc3_failure_description=OCI attachment metadata did not include the iSCSI target fields required for manual Linux login, so TC3 could not create an active-writer negative case."
    } >> "$EVIDENCE"
    finish_case ""
    return 1
  fi

  old_iqn_q="$(shell_quote "$old_iqn")"
  old_ip_q="$(shell_quote "$old_ip")"
  old_port_q="$(shell_quote "$old_port")"
  old_chap_user_q="$(shell_quote "$old_chap_user")"
  old_chap_secret_q="$(shell_quote "$old_chap_secret")"
  remote_iscsi_env="$(printf 'IQN=%s\nIP=%s\nPORT=%s\nCHAP_USER=%s\nCHAP_SECRET=%s\n' \
    "$old_iqn_q" "$old_ip_q" "$old_port_q" "$old_chap_user_q" "$old_chap_secret_q")"

  trace "=== TC3 Linux setup: mounted filesystem and active writer ==="
  trace "intent=prove unsafe detach can cause application I/O errors or disposable data inconsistency"
  trace "guardrail=disposable volume and disposable test data only"
  trace "linux_release_procedure=false"
  trace "steps=manual iscsi register/login,mkfs,mount,write checksum data,start writer,detach without umount/logout"
  if ! run_remote_trace "$(remote_script_with_iscsi_helpers "tc3_setup_unsafe_writer.sh" "$remote_iscsi_env")"; then
    result="INCONCLUSIVE_TC3_BASELINE_ISCSI_CONNECT_OR_WRITER_SETUP_FAILED"
    {
      echo "TC3_RESULT=$result"
      echo "old_volume_attachment_id=$old_attachment_id"
      echo "old_iqn=$old_iqn"
      echo "old_ip=$old_ip"
      echo "old_port=$old_port"
      echo "tc3_failure_description=The non-UHP baseline attachment could not be manually connected, discovered, formatted, mounted, or started with an active writer, so the unsafe-detach negative case was not executed."
    } >> "$EVIDENCE"
    finish_case ""
    return 1
  fi

  trace "=== TC3 action: OCI force detach while writer is active ==="
  trace "expected_failure_modes=writer_io_error,busy_or_forced_detach,stale_device,fs_inconsistency,checksum_mismatch"
  trace "data_loss_assertion=not_guaranteed; this test captures unsafe exposure and verifies disposable data outcome"
  echo "TC3 force detach while mounted writer is active."
  oci compute volume-attachment detach \
    --volume-attachment-id "$old_attachment_id" \
    --force \
    --wait-for-state DETACHED \
    --max-wait-seconds 900 \
    --wait-interval-seconds 15 >> "$EVIDENCE" 2>&1 || true

  run_remote_trace "$(remote_script_with_iscsi_helpers "tc3_collect_after_unsafe_detach.sh" "$remote_iscsi_env")" || true

  oci bv volume update --volume-id "$volume_id" --vpus-per-gb 100 --force >> "$EVIDENCE" 2>&1
  wait_volume_available "$volume_id" >> "$EVIDENCE" 2>&1 || true
  new_attachment_id="$(oci compute volume-attachment attach-iscsi-volume \
    --instance-id "$instance_id" \
    --volume-id "$volume_id" \
    --device "/dev/oracleoci/oraclevdb" \
    --display-name "bv4db-s27-tc3-reattachment" \
    --wait-for-state ATTACHED \
    --max-wait-seconds 900 \
    --wait-interval-seconds 15 \
    --query 'data.id' \
    --raw-output)"
  SCENARIO_ATTACHMENTS="$SCENARIO_ATTACHMENTS $new_attachment_id"
  refresh_and_poll "tc3-after-unsafe-reattach-vpu-100" "$SPRINT27_POLL_RETRIES" "$new_attachment_id" || true
  append_oci_evidence "tc3-after-unsafe-reattach-vpu-100" "$new_attachment_id"
  wait_for_agent_multipath_login "tc3-after-unsafe-reattach-vpu-100" || true
  assert_uhp_consistent_path "tc3-after-unsafe-reattach-vpu-100" || true
  run_remote_trace "$(remote_script_file "tc3_check_after_reattach.sh")" || true
  result="NEGATIVE_UNSAFE_LINUX_PROCEDURE_OBSERVED"
  echo "TC3_RESULT=$result" >> "$EVIDENCE"
  finish_case "$new_attachment_id"
  pass "TC3 unsafe Linux procedure evidence captured on disposable data"
}

tc4_linux_clean_positive() {
  echo "=== TC4: clean Linux release then detach-update-reattach - expected positive ===" >> "$EVIDENCE"
  echo "TC4 start: clean Linux release with checksum validation."
  begin_case "tc4-linux-clean" || return 1

  poll_for_non_multipath "tc4-baseline-non-uhp" || true
  append_oci_evidence "tc4-baseline-non-uhp"

  local volume_id instance_id old_attachment_id new_attachment_id result checksum_result multipath_ok consistent_path_ok agent_wait_ok
  local old_attachment_json old_iqn old_ip old_port old_chap_user old_chap_secret
  local old_iqn_q old_ip_q old_port_q old_chap_user_q old_chap_secret_q
  local remote_iscsi_env
  volume_id="$(terraform -chdir="$WORKDIR" output -raw volume_id)"
  instance_id="$(terraform -chdir="$WORKDIR" output -raw instance_id)"
  old_attachment_id="$(terraform -chdir="$WORKDIR" output -raw volume_attachment_id)"
  old_attachment_json="$(attachment_get_json "$old_attachment_id")"
  old_iqn="$(printf '%s\n' "$old_attachment_json" | jq -r '.data.iqn // empty')"
  old_ip="$(printf '%s\n' "$old_attachment_json" | jq -r '.data.ipv4 // empty')"
  old_port="$(printf '%s\n' "$old_attachment_json" | jq -r '.data.port // empty')"
  old_chap_user="$(printf '%s\n' "$old_attachment_json" | jq -r '.data."chap-username" // empty')"
  old_chap_secret="$(printf '%s\n' "$old_attachment_json" | jq -r '.data."chap-secret" // empty')"

  trace "=== TC4 Linux setup and clean release ==="
  trace "oracle_reference=https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtoavolume.htm"
  trace "oracle_reference=https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtoavolume_topic-Connecting_to_iSCSIAttached_Volumes.htm"
  trace "oracle_validation=non-UHP iSCSI attachment requires explicit Linux iSCSI connect/login unless auto-connect was selected"
  trace "linux_release_procedure=true"
  trace "steps=manual iscsi register/login,mkfs,mount,write checksum data,sync,stop I/O,umount,iscsi logout,detach"

  if [ -z "$old_iqn" ] || [ -z "$old_ip" ] || [ -z "$old_port" ]; then
    result="INCONCLUSIVE_TC4_ATTACHMENT_ISCSI_METADATA_MISSING"
    {
      echo "TC4_RESULT=$result"
      echo "old_volume_attachment_id=$old_attachment_id"
      echo "old_iqn=$old_iqn"
      echo "old_ip=$old_ip"
      echo "old_port=$old_port"
      echo "tc4_failure_description=OCI attachment metadata did not include the iSCSI target fields required for manual Linux login."
    } >> "$EVIDENCE"
    finish_case ""
    return 1
  fi

  old_iqn_q="$(shell_quote "$old_iqn")"
  old_ip_q="$(shell_quote "$old_ip")"
  old_port_q="$(shell_quote "$old_port")"
  old_chap_user_q="$(shell_quote "$old_chap_user")"
  old_chap_secret_q="$(shell_quote "$old_chap_secret")"
  remote_iscsi_env="$(printf 'IQN=%s\nIP=%s\nPORT=%s\nCHAP_USER=%s\nCHAP_SECRET=%s\n' \
    "$old_iqn_q" "$old_ip_q" "$old_port_q" "$old_chap_user_q" "$old_chap_secret_q")"

  if ! run_remote_trace "$(remote_script_with_iscsi_helpers "tc4_prepare_clean_release.sh" "$remote_iscsi_env")"; then
    result="INCONCLUSIVE_TC4_BASELINE_ISCSI_CONNECT_OR_DEVICE_DISCOVERY_FAILED"
    {
      echo "TC4_RESULT=$result"
      echo "old_volume_attachment_id=$old_attachment_id"
      echo "old_iqn=$old_iqn"
      echo "old_ip=$old_ip"
      echo "old_port=$old_port"
      echo "tc4_failure_description=The non-UHP baseline attachment could not be manually connected or discovered in Linux, so TC4 did not create filesystem data and cannot prove data preservation or data loss."
    } >> "$EVIDENCE"
    finish_case ""
    return 1
  fi

  trace "=== TC4 action: detach after clean Linux release ==="
  trace "oci_detach_cli_confirmation=skipped_with_force_flag"
  trace "oci_force_flag_meaning=OCI CLI confirmation bypass; Linux clean release was already completed before detach"
  trace "detach_precondition=filesystem unmounted and manual iscsi session logged out"
  if ! oci compute volume-attachment detach \
    --volume-attachment-id "$old_attachment_id" \
    --force \
    --wait-for-state DETACHED \
    --max-wait-seconds 900 \
    --wait-interval-seconds 15 >> "$EVIDENCE" 2>&1; then
    result="NEGATIVE_TC4_CLEAN_DETACH_FAILED"
    {
      echo "TC4_RESULT=$result"
      echo "tc4_failure_description=OCI detach failed after Linux unmount and iSCSI logout; the clean release precondition was not sufficient or OCI detach returned an error."
    } >> "$EVIDENCE"
    finish_case ""
    return 1
  fi
  oci bv volume update --volume-id "$volume_id" --vpus-per-gb 100 --force >> "$EVIDENCE" 2>&1
  wait_volume_available "$volume_id" >> "$EVIDENCE" 2>&1 || true
  new_attachment_id="$(oci compute volume-attachment attach-iscsi-volume \
    --instance-id "$instance_id" \
    --volume-id "$volume_id" \
    --device "/dev/oracleoci/oraclevdb" \
    --display-name "bv4db-s27-tc4-reattachment" \
    --wait-for-state ATTACHED \
    --max-wait-seconds 900 \
    --wait-interval-seconds 15 \
    --query 'data.id' \
    --raw-output)"
  SCENARIO_ATTACHMENTS="$SCENARIO_ATTACHMENTS $new_attachment_id"

  multipath_ok=false
  if refresh_and_poll "tc4-after-clean-reattach-vpu-100" "$SPRINT27_POLL_RETRIES" "$new_attachment_id"; then
    multipath_ok=true
    result="PASS_CLEAN_LINUX_PROCEDURE_MULTIPATH"
  else
    result="NEGATIVE_CLEAN_LINUX_PROCEDURE_NO_MULTIPATH"
  fi
  append_oci_evidence "tc4-after-clean-reattach-vpu-100" "$new_attachment_id"
  agent_wait_ok=false
  if [ "$multipath_ok" = "true" ] && wait_for_agent_multipath_login "tc4-after-clean-reattach-vpu-100"; then
    agent_wait_ok=true
  fi
  consistent_path_ok=false
  if [ "$multipath_ok" = "true" ] && assert_uhp_consistent_path "tc4-after-clean-reattach-vpu-100"; then
    consistent_path_ok=true
  fi
  local checksum_output_file
  checksum_output_file="$TMPDIR/tc4-checksum-discovery.txt"
  trace "=== TC4 post-reattach Linux device discovery ==="
  trace "goal=validate the configured OCI consistent path, then verify the preserved filesystem data"
  run_remote_capture_trace "$(remote_script_file "tc4_check_after_reattach.sh")" "$checksum_output_file"
  checksum_status=$?
  checksum_result="$(cat "$checksum_output_file" 2>/dev/null || true)"

  if [ "$checksum_status" -eq 0 ] && printf '%s\n' "$checksum_result" | grep -q 'checksum_after_reattach=PASS'; then
    if [ "$multipath_ok" != "true" ]; then
      result="NEGATIVE_CLEAN_LINUX_PROCEDURE_CHECKSUM_OK_BUT_NO_MULTIPATH"
      {
        echo "TC4_RESULT=$result"
        echo "tc4_failure_description=Linux checksum survived, but OCI did not report a multipath-enabled UHP attachment."
      } >> "$EVIDENCE"
      finish_case "$new_attachment_id"
      return 1
    fi
    if [ "$consistent_path_ok" != "true" ]; then
      result="NEGATIVE_CLEAN_LINUX_PROCEDURE_CONSISTENT_PATH_INVALID"
      {
        echo "TC4_RESULT=$result"
        echo "tc4_agent_wait_ok=$agent_wait_ok"
        echo "tc4_failure_description=Linux checksum survived and OCI reported multipath, but the OCI agent did not expose the configured consistent device path resolving to the multipath friendly device within the passive wait window."
      } >> "$EVIDENCE"
      finish_case "$new_attachment_id"
      return 1
    fi
    result="PASS_CLEAN_LINUX_PROCEDURE_AFTER_DEVICE_DISCOVERY"
    {
      echo "TC4_RESULT=$result"
      echo "tc4_recovery_description=Post-reattach consistent path validation found the multipath friendly device and checksum verification passed."
    } >> "$EVIDENCE"
    finish_case "$new_attachment_id"
    pass "TC4 clean Linux procedure preserved data after post-reattach device discovery"
    return 0
  fi

  result="NEGATIVE_CLEAN_LINUX_PROCEDURE_DEVICE_DISCOVERY_FAILED"
  {
    echo "TC4_RESULT=$result"
    echo "tc4_failure_description=After clean Linux release and successful UHP multipath reattach, device discovery did not find an ext4 filesystem with a valid checksum. This does not by itself prove data loss unless baseline data creation was confirmed and the correct candidate device was inspected."
  } >> "$EVIDENCE"
  finish_case "$new_attachment_id"
  return 1
}

run_selected_cases() {
  local selected_case
  for selected_case in $SPRINT27_CASES; do
    case "$selected_case" in
      tc1)
        tc1_inplace_update_negative || fail "TC1 in-place negative failed"
        ;;
      tc2)
        tc2_detach_update_positive || fail "TC2 detach positive failed"
        ;;
      tc3)
        tc3_linux_unsafe_negative || fail "TC3 unsafe Linux negative failed"
        ;;
      tc4)
        tc4_linux_clean_positive || fail "TC4 clean Linux procedure found post-reattach mount failure; see evidence for device-path/multipath details"
        ;;
      *)
        fail "unknown Sprint 27 case: $selected_case"
        ;;
    esac
  done
}

live_probe() {
  command -v terraform >/dev/null 2>&1 || { fail "terraform CLI is available"; return 1; }
  command -v oci >/dev/null 2>&1 || { fail "oci CLI is available"; return 1; }
  command -v jq >/dev/null 2>&1 || { fail "jq is available"; return 1; }
  command -v ssh-keygen >/dev/null 2>&1 || { fail "ssh-keygen is available"; return 1; }

  discover_context || return 1

  TMPDIR="$(mktemp -d)"
  ssh-keygen -q -t rsa -b 3072 -N "" -f "$TMPDIR/sprint27.key"
  write_evidence_header
  {
    echo "=== Test matrix ==="
    echo "TC1: 20->100 without detach, expected negative for multipath"
    echo "TC2: 20->100 with detach, expected positive for OCI multipath and consistent device path"
    echo "TC3: detach/update/reattach without Linux release, expected negative/hazardous on disposable data"
    echo "TC4: detach/update/reattach with Linux release, expected positive for checksum, OCI multipath, and consistent device path"
    echo "selected_cases=$SPRINT27_CASES"
    echo
  } >> "$EVIDENCE"

  run_selected_cases

  echo "Evidence: $EVIDENCE"
}

echo "=== Sprint 27 non-UHP to UHP VPU update integration ==="

require_file "$MODULE_DIR/versions.tf"
require_file "$MODULE_DIR/variables.tf"
require_file "$MODULE_DIR/main.tf"
require_file "$MODULE_DIR/outputs.tf"
require_file "$MODULE_DIR/README.md"
for remote_script in \
  baseline_iscsi_helpers.sh \
  assert_uhp_consistent_path.sh \
  tc3_setup_unsafe_writer.sh \
  tc3_collect_after_unsafe_detach.sh \
  tc3_check_after_reattach.sh \
  tc4_prepare_clean_release.sh \
  tc4_check_after_reattach.sh \
  wait_for_agent_multipath_login.sh; do
  require_file "$REMOTE_SCRIPT_DIR/$remote_script"
done
require_contains "$MODULE_DIR/main.tf" 'Block Volume Management' "module enables Block Volume Management plugin"
require_contains "$MODULE_DIR/main.tf" 'resource[[:space:]]+"oci_core_volume_attachment"[[:space:]]+"test"' "module uses native Terraform attachment"
require_contains "$MODULE_DIR/main.tf" 'device[[:space:]]+=' "module sets persistent device path"
require_contains "$MODULE_DIR/variables.tf" 'initial_volume_vpus_per_gb < 30' "module validates non-UHP baseline"
require_not_contains "$MODULE_DIR/main.tf" 'raw-request|terraform_data|isMultipath|is_agent_auto_iscsi_login_enabled|iscsiadm|mpathconf|multipath\.conf' "module has no helper, auto-login flag, or guest setup"
require_tree_not_contains "$MODULE_DIR" 'is_agent_auto_iscsi_login_enabled|iscsiadm[[:space:]]+--login|mpathconf[[:space:]]+--enable' "module tree has no bypass/setup commands"

if [ "$FAIL" -eq 0 ]; then
  live_probe || fail "live VPU upgrade probe failed to execute"
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

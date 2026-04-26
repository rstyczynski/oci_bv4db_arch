# Multipath attribute not populated — Sprint 23 findings

## Executive summary

In Sprint 23 we hit a recurring situation where the **OCI Compute volume attachment** JSON did not yet show the multipath-related fields we expected (the “multipath attribute not populated” problem).

- **What we observed in this repo**: right after a volume attachment reports as attached, the attachment may temporarily return **empty / missing** values for `is-multipath` and/or the `multipath-devices` list. The repository therefore treats those fields as **eventually consistent** and applies a bounded wait/retry.
- **What Oracle documents explicitly**: Oracle documents the meaning of `is-multipath`, the prerequisites for multipath-enabled UHP attachments (including the Block Volume Management plugin), and troubleshooting steps when the attachment is **not** multipath-enabled.
- **Important**: Oracle documentation (linked below) does **not** explicitly state that `is-multipath` / `multipath-devices` can lag after `ATTACHED`. That “propagation lag” behavior is an **implementation assumption based on observed API responses** during sprint runs.

## What “multipath attribute” refers to

In this repo, “multipath attribute” refers to the OCI Compute **volume attachment properties** exposed by:

- the CLI JSON field `data."is-multipath"` (aka API model `isMultipath`)
- the CLI JSON field `data."multipath-devices"` (a list of additional iSCSI target endpoints for multipath)

These fields are read from:

- `oci compute volume-attachment get --volume-attachment-id <ocid>`

## Sprint 23 scope (where the issue shows up)

Sprint 23 is primarily about **dm-multipath load balancing configuration** and evidence collection, and it intentionally **reuses** the stable Sprint 20 A/B harness.

See also:

- [`README.md`](../../README.md) — section “UHP iSCSI multipath evidence (Sprints 22 and 23)” provides the repo-level narrative and entry points for running/inspecting Sprint 22/23 multipath evidence.

Sprint 23 documentation context:

- [`progress/sprint_23/sprint_23_design.md`](progress/sprint_23/sprint_23_design.md) — load-balancing policy goals and acceptance evidence
- [`progress/sprint_23/sprint_23_implementation.md`](progress/sprint_23/sprint_23_implementation.md) — “Sprint 22 + round-robin” reuse summary
- [`progress/sprint_23/sprint23_manual.md`](progress/sprint_23/sprint23_manual.md) — operator workflow for inspecting multipath policy on the guest

**Note**: these Sprint 23 docs describe how to inspect multipath state on the guest, but they do **not** include a detailed write-up of the “not populated yet” attachment-field behavior. That detail is captured in code (below).

## Repo evidence (what we implemented because of this)

### Evidence A: bounded wait for `is-multipath` / `multipath-devices`

The repo includes an explicit wait loop that keeps querying the attachment until either:

- `data."is-multipath"` becomes `"true"`, or
- `data."multipath-devices"` has length ≥ 1,
- otherwise it times out.

Source:

```61:77:oci_scaffold/resource/ensure-blockvolume.sh
wait_for_multipath_props() {
  local attach_id="$1"
  local timeout="${BV_MULTIPATH_PROPAGATION_SEC:-300}"
  local elapsed=0 is_mp mp_devs
  _info "Waiting for multipath properties to propagate (timeout ${timeout}s): $attach_id"
  while true; do
    is_mp="$(oci compute volume-attachment get --volume-attachment-id "$attach_id" --query 'data."is-multipath"' --raw-output 2>/dev/null)" || is_mp=""
    mp_devs="$(oci compute volume-attachment get --volume-attachment-id "$attach_id" --query 'length(data."multipath-devices")' --raw-output 2>/dev/null)" || mp_devs=""
    echo "  [WAIT] Multipath props ${elapsed}s (is-multipath=${is_mp:-}, multipath-devices=${mp_devs:-})"
    if [ "${is_mp:-}" = "true" ] || { [ -n "${mp_devs:-}" ] && [ "$mp_devs" != "null" ] && [ "$mp_devs" -ge 1 ]; }; then
      return 0
    fi
    sleep 10; elapsed=$((elapsed + 10))
    if [ "$elapsed" -ge "$timeout" ]; then
      return 1
    fi
  done
}
```

### Evidence B: A/B harness warns that the attachment fields may not be “true yet”

The Sprint 20 A/B harness (reused by Sprint 22 and Sprint 23 wrappers) explicitly warns when `is-multipath` is not `true` at the first read, and proceeds while `ensure-blockvolume.sh` handles retries.

Source:

```968:978:tools/run_bv4db_fio_multipath_ab_sprint20.sh
  attachment_json=$(oci compute volume-attachment get --volume-attachment-id "$volume_attach_id")
  local is_multipath
  is_multipath=$(echo "$attachment_json" | jq -r '.data."is-multipath" // empty')
  if [ "${is_multipath:-}" != "true" ]; then
    echo "  [WARN] Attachment multipath fields are not 'true' yet (is-multipath=${is_multipath:-empty}). Proceeding; ensure-blockvolume will retry/detach if needed." >&2
  fi
  iqn=$(echo "$attachment_json" | jq -r '.data.iqn')
  port=$(echo "$attachment_json" | jq -r '.data.port')
  mapfile -t target_ips < <(echo "$attachment_json" | jq -r '([.data.ipv4] + [.data."multipath-devices"[]?.ipv4]) | unique[]')
```

## What Oracle documentation explicitly says (relevant references)

### Checking the `is-multipath` property

Oracle documents that `is-multipath` is the property to check for multipath enablement:

- **Doc**: “Checking If a Volume Attachment is Multipath-Enabled”  
  `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/get-multipath-enable-check-compute-volume-attachment.htm`
- **Quote from the doc**: “The `is-multipath` property will be `true` for multipath-enabled attachments and `false` for attachments that are not multipath-enabled.”

### Prerequisites, and that the service attempts enablement during attach

Oracle documents prerequisites for UHP multipath enablement and states that the Block Volume service attempts to enable multipath during attach:

- **Doc**: “Configuring Attachments to Ultra High Performance Volumes”  
  `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm`
- **Quote from the doc**: “The Block Volume service attempts to enable the attachment for multipath when the volume is being attached. If not all of the prerequisites have been addressed, the volume attachment will not be multipath-enabled.”

This same page also calls out operational guidance that matters for real sprint runs (not necessarily for the “not populated” symptom), for example the Block Volume Management plugin requirement and reattach recommendations.

### Block Volume Management plugin (agent/plugin readiness)

Oracle explicitly ties **attachment failures** to the Block Volume Management plugin configuration for UHP+iSCSI:

- **Doc**: “Troubleshooting Ultra High Performance Volume Attachments”  
  `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/troubleshootingmultipathattachments.htm`
- **Quote from the doc**: “The Block Volume Management plugin is required … If the volume fails to attach to the instance, the issue is likely caused by incorrect configuration for the Block Volume Management plugin.”

This is **related**, but it describes a different failure mode than the Sprint 23 symptom:

- **Plugin/agent readiness issue**: typically manifests as *attach failing* or attachment never becoming multipath-enabled.
- **Sprint 23 symptom**: the attachment exists and the test proceeds, but the **multipath fields are temporarily empty/not yet populated** at first read.

## What is inferred / observed (and not explicitly stated by Oracle docs)

Based on sprint evidence and why the repo includes `wait_for_multipath_props()`:

- The attachment lifecycle can progress to a state where consumers start reading the attachment, while `is-multipath` and/or `multipath-devices` are still **not returned** (empty/missing) for a short window.
- This becomes more visible in workflows that **reuse/adopt** existing volumes/attachments or perform fast **detach/reattach** cycles, where the control-plane state transitions are rapid and clients read immediately.

Again: the Oracle docs above do not explicitly describe this timing nuance; this is a **repo-level operational finding** and the reason for the bounded wait loop.

## Operator guidance (practical interpretation)

When you see “multipath attribute not populated” in this repo’s sprint runs:

- **Do not immediately conclude “not multipath-enabled”** based on a single early read of `is-multipath` / `multipath-devices`.
- **Do** re-check with a short retry window (this repo defaults to \(300s\) in `BV_MULTIPATH_PROPAGATION_SEC`).
- **If it never becomes multipath-enabled**, then follow Oracle’s troubleshooting checklist (shapes/images, plugin enabled, prerequisites met), starting from the docs linked above.

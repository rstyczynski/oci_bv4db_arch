# Sprint 28 - Design

## BV4DB-63. Idempotent Linux block-volume preparation script for iSCSI and multipath transitions

Status: Accepted

### Feasibility Analysis

The requirement is feasible with standard Linux storage tools and OCI metadata. The script can operate safely if it has one automatic ensure workflow: discover the current host state, connect iSCSI only when needed, wait for the OCI consistent path when possible, inspect existing storage metadata, activate existing LVM/filesystem state, grow resized storage when safe, and mount the volume. The operator should not choose lifecycle modes for non-MP, MP, transition, or resize.

The only explicit boundary is first-time initialization of an actually empty volume. Creating PV/VG/LV/filesystem is allowed only when the script proves no existing signatures are present and the operator passes an explicit initialization permission flag. A missing path or failed `pvs` check must never trigger destructive initialization.

Oracle documentation supports the required behaviors:

- For iSCSI-attached volumes, Linux must connect to the iSCSI target before the volume is usable unless the Block Volume Management plugin auto-connect option was selected.
- For UHP multipath, the attachment needs a device path and the guest uses the multipath-backed device exposed through the consistent path.
- The Block Volume Management plugin checks instance metadata, can install/configure multipath only for multipath-enabled attachments, performs batch iSCSI login for qualifying attachments, and requires Oracle service access through public IP or service gateway.
- Block volumes can only be expanded, and resize handling must grow guest-side storage after the larger device is visible.

References:

- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtoavolume.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtouhpvolumes.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/resizingavolume.htm>

### Design Goals

The sprint will add a Linux-side operator script and evidence helpers:

- `tools/oci_bv_prepare_volume.sh`: data-safe idempotent ensure-and-mount workflow.
- `tools/oci_bv_360_diagnostics.sh`: local guest diagnostics collector usable independently and by integration tests.
- `tests/integration/test_sprint28_volume_prepare.sh`: Sprint 28 integration harness derived from Sprint 27 TC4.
- `tests/integration/sprint28/remote/`: remote guest scripts copied to the OCI instance during live tests.

The script must not expose lifecycle-selection modes. It should do the correct thing based on detected state. Destructive initialization commands include `pvcreate`, `vgcreate`, `lvcreate`, and `mkfs`; they are allowed only behind `--allow-initialize-empty` after signature checks prove the volume is empty. The initial implementation must not run `wipefs`.

### Operator Use Case

The supported operator use case is:

> Ensure this OCI block volume is connected, discovered through the best available stable path, has the requested LVM/filesystem/mount configuration, preserves existing data, grows safely if the volume was resized, and produces full diagnostics.

The same command is used when:

- The host starts with a non-MP attachment.
- The host starts with a UHP MP attachment.
- The volume was moved from non-MP to MP outside the script.
- The command is re-run on an already configured host.
- The OCI volume was resized.
- One block volume contains a single LV or multiple LVs in the same VG.

For example:

```bash
sudo tools/oci_bv_prepare_volume.sh \
  --device-path /dev/oracleoci/oraclevdf \
  --mount-point /software/oracle \
  --vg-name oraaio_vg \
  --lv-name oraaio_lv \
  --filesystem xfs \
  --iqn iqn.2015-12.com.oracleiaas:example \
  --portal 169.254.2.12:3260 \
  --log-dir /var/log/oci-bv-prepare
```

For a known-new, disposable or newly provisioned empty volume, the operator adds:

```bash
--allow-initialize-empty
```

Without that flag, an empty/unrecognized volume fails closed with diagnostics instead of creating or formatting anything.

For a volume with multiple LVs, the script must support repeatable LV definitions. The simple `--lv-name` and `--mount-point` options are a single-LV shorthand; internally they should be normalized into the same LV-definition model used for multi-LV volumes.

Example multi-LV shape derived from the current operator script:

```bash
sudo tools/oci_bv_prepare_volume.sh \
  --device-path /dev/oracleoci/oraclevdd \
  --vg-name oradata_edracc_vg \
  --filesystem xfs \
  --iqn iqn.2015-12.com.oracleiaas:example \
  --portal 169.254.2.72:3260 \
  --log-dir /var/log/oci-bv-prepare \
  --lv name=orared1_edracc_disk50_lv,size=50G,mount=/databases/disk50/edracc \
  --lv name=orared2_edracc_disk51_lv,size=50G,mount=/databases/disk51/edracc \
  --lv name=oradiag_edracc_disk60_lv,size=128G,mount=/databases/disk60/edracc \
  --lv name=oradata_edracc_disk01_lv,size=100%FREE,mount=/databases/disk01/edracc
```

### Script Contract

`tools/oci_bv_prepare_volume.sh` will accept explicit target and policy options:

- `--device-path /dev/oracleoci/oraclevdX`
- `--mount-point <path>`
- `--vg-name <name>`
- `--lv-name <name>`
- `--lv name=<name>,size=<size>,mount=<path>[,filesystem=xfs|ext4][,grow-policy=none|all-free|exact]` repeatable
- `--filesystem xfs|ext4`
- `--iqn <target>`
- `--portal <ip:port>`
- `--chap-user <user>`
- `--chap-secret <secret>`
- `--expected-uuid <uuid>`
- `--log-dir <path>`
- `--allow-initialize-empty`
- `--grow-policy none|all-free`
- `--diagnose-only`
- `--plan-only`
- `--persist-iscsi automatic|manual`
- `--wait-consistent-path-seconds <seconds>`

The exact final argument names may be simplified during construction, but the implementation must preserve the core contract: no lifecycle mode selection, explicit target identity, log directory, automatic state detection, fail-closed behavior, repeatable LV definitions for multi-LV volumes, and explicit permission for first-time initialization.

### Storage Layout

Sprint 28 supports one storage layout:

```text
OCI block volume consistent path
  -> whole block device or multipath mapper
  -> LVM PV
  -> VG named by --vg-name
  -> one or more LVs named by --lv-name or repeatable --lv definitions
  -> filesystem per LV
  -> mount point per LV
```

The script should handle logical volumes because the target use case uses LVM names as the stable storage identity. This avoids mounting directly from transient SCSI names such as `/dev/sdX` or from multipath names such as `/dev/mapper/mpathX`.

The minimum supported LVM shape for Sprint 28 is one PV and one VG per OCI block volume, with one or more LVs in that VG. Each LV definition has a name, size policy, filesystem, mount point, and growth policy. Supported size policies are fixed sizes such as `50G` or `128G`, percentage sizes such as `20%VG`, and all-free allocation such as `100%FREE`.

The script should not create a partition table for this sprint. It should not use `fdisk`, `parted`, `sfdisk`, `growpart`, or partition-resize logic. Whole-device LVM is simpler and safer for non-MP to MP remapping and for OCI volume resize because the growth path is `pvresize`, LV extension, then filesystem growth.

If an existing partition table is detected on the target device, the script must fail closed and collect diagnostics unless a future sprint explicitly adds partitioned-layout support. It must not silently repartition or reformat.

### Extensibility Boundary

The implementation must keep OCI/iSCSI/path discovery, diagnostics, layout detection, and layout enforcement separated. The whole-device LVM logic should live behind a layout handler so later sprints can add handlers such as partitioned LVM, plain filesystem, ASM disks, or multi-PV VGs without rewriting the iSCSI and diagnostics layers.

Required internal shape:

```text
parse_cli
collect_diagnostics
ensure_iscsi_connection_if_needed
resolve_consistent_path
detect_layout
validate_supported_layout
ensure_whole_device_lvm_layout
ensure_lv_filesystem_and_mount
grow_layout_if_needed
write_summary
```

The attached current script also contains application migration behavior such as copying existing directory contents, stopping services, and editing service unit dependencies. That is outside Sprint 28. Sprint 28 must not perform application data migration or service orchestration; it should fail closed or leave those steps to a future explicit migration sprint.

### Production Flexibility Design

Sprint 28 should be production-ready for the supported whole-device LVM layout, while keeping clean extension points for future storage shapes. The script must avoid the current pattern of long ad hoc generated shell blocks where storage detection, initialization, resizing, fstab editing, service handling, and application migration are mixed together.

Required Sprint 28 production behavior:

- **One-volume transaction boundary:** one script invocation manages one OCI block volume, one PV, one VG, and one or more LVs. Multi-volume hosts run the script once per volume or use a future orchestrator.
- **Repeatable LV definitions:** the implementation accepts multiple `--lv` specs and reconciles each LV independently.
- **Plan mode:** `--plan-only` resolves devices, reads metadata, computes intended actions, and writes diagnostics without mutating storage.
- **Run locking:** concurrent invocations against the same VG or device must be prevented with a local lock.
- **Managed fstab entries:** the script should only create or update fstab lines it owns, using stable LV paths or filesystem UUIDs and an identifiable managed marker. It must not use broad `sed` deletion of arbitrary matching mount paths.
- **Boot-safe persistence:** managed fstab entries must use network-storage-safe options such as `_netdev`, `nofail`, and bounded systemd device timeout. The instance must remain reachable after reboot even if a disposable test volume is absent.
- **Persistent iSCSI policy:** for non-MP iSCSI targets, the script must be able to persist node startup with `iscsiadm` when requested by policy. For MP/UHP attachments, the script must not fight the OCI agent; it should validate agent-managed readiness and reconcile after the device appears.
- **Open-iSCSI node database safe use:** `/etc/iscsi/nodes/` is natively owned and maintained by Open-iSCSI/`iscsiadm`. The script must not edit node database files directly. It may invoke `iscsiadm` to create or update only the node record for the requested IQN and portal, and it must not delete or rewrite unrelated node records.
- **Mount-point guardrail:** if the mount point is non-empty and not already the expected mount, the script fails closed. Application data movement is not part of this sprint.
- **Secret hygiene:** CHAP secrets must not be printed in logs, summaries, diagnostics, shell traces, or failed command output.
- **No blanket success masking:** diagnostic commands may tolerate failures, but storage mutation commands must not be hidden behind broad `|| true`.
- **Structured summary:** each run writes a human-readable log plus machine-readable summary with detected layout, resolved device, intended actions, performed actions, skipped actions, warnings, and final state.
- **Explicit unsupported-layout result:** partition tables, plain filesystems, ASM labels, foreign VGs, missing expected VG/LV names, or unexpected filesystem UUIDs produce a clear unsupported or mismatch result, not a best-effort rewrite.

Future extension points:

| Area | Sprint 28 decision | Future extension |
| ---- | ------------------ | ---------------- |
| Multi-volume host orchestration | Run one invocation per volume | Config-driven inventory that processes many volumes and orders dependencies |
| Layout handlers | Whole-device LVM only | Partitioned LVM, plain filesystem, ASM, multi-PV VG, striped or RAID LVs |
| Target discovery | Explicit IQN/portal plus IMDS diagnostics | Full auto-discovery from IMDS/OCI attachment metadata by device path or OCID |
| Application migration | Out of scope and fail closed | Controlled copy/restore, service stop/start, systemd dependency updates |
| Secret handling | Redact CLI-provided CHAP secret | Read from root-only files, environment, instance principals, or OCI Vault |
| Observability | Per-run logs and evidence | systemd unit/timer integration, health checks, metrics, alert-friendly exit codes |
| Recovery | Fail closed with diagnostics | Assisted cleanup for stale iSCSI nodes, stale multipath maps, and failed previous runs |

### Operating Model

The script starts by collecting diagnostics and resolving the usable block path. The script does not create `/dev/oracleoci` mappings and does not configure multipath for UHP. It waits for and validates the mappings produced by the OCI agent, udev, iSCSI, and multipath stack.

The automatic workflow:

1. Collect IMDS/MDS reachability and volume-attachment metadata.
2. Collect Oracle Cloud Agent and Block Volume Management plugin status, versions, desired state, enabled state, and logs.
3. Collect iSCSI sessions, `/etc/iscsi/nodes/` node database, and target/portal state.
4. If the requested path is not available and iSCSI target details are provided, perform non-MP iSCSI node setup/login.
5. Wait for the requested OCI consistent path and record `readlink`/`readlink -f` mapping.
6. Accept either a single-path target such as `/dev/oracleoci/oraclevdb -> ../sdb` or a multipath target such as `/dev/oracleoci/oraclevdb -> /dev/mapper/mpatha`.
7. If the consistent path does not appear within the configured window, fall back to real-device discovery only with explicit evidence, matching the Sprint 27 TC4 fallback behavior.
8. Collect `lsblk`, `blkid`, `/dev/mapper`, `multipath -ll`, and `multipathd show paths`.
9. Inspect signatures and LVM state with `pvs`, `vgs`, `lvs`, `pvscan`, `vgscan`, and non-mutating probes before any write.
10. If existing PV/VG/LV/filesystem metadata is found, activate it with `vgchange -ay` and reconcile every requested LV definition through stable LV path, UUID, or managed fstab entry.
11. If no signatures are found and `--allow-initialize-empty` is present, create PV/VG and each requested LV/filesystem/fstab entry/mount.
12. If no signatures are found and `--allow-initialize-empty` is absent, fail closed and preserve diagnostics.
13. If the device is larger than existing metadata and `--grow-policy all-free` is active, run safe growth steps after metadata health checks: `pvresize`, LV extension, and filesystem growth.
14. If `--diagnose-only` or `--plan-only` is present, stop after evidence collection and planned-action reporting without mutating storage state.

Reboot behavior:

- Sprint 28 does not install a systemd unit or daemon that automatically runs the script after every boot. That belongs to BV4DB-68.
- The script must still make the supported layout reboot-tolerant: persistent iSCSI node configuration when requested, managed fstab entries with `_netdev,nofail`, LVM metadata that can be activated after boot, and diagnostics that show whether iSCSI sessions, consistent paths, VGs, LVs, filesystems, and mounts recovered cleanly.
- For non-MP iSCSI with `--persist-iscsi automatic`, the script must ensure the requested target record under `/etc/iscsi/nodes/<target-iqn>/<portal>/` has `node.startup = automatic` or equivalent Open-iSCSI state, and must verify this state in evidence.
- After reboot, the operator or automation pipeline can run the same script again. The script must detect current state, wait for the consistent path, activate the VG/LVs if needed, mount missing managed filesystems, and preserve checksum data.
- If the volume is absent at boot, fstab must not block boot. A later script run should report the missing target clearly and fail closed without damaging local state.

Non-MP to MP lifecycle behavior:

- OCI detach, VPU update, and reattach are orchestrated outside the operator script or by the integration harness.
- Before detach, the operational procedure remains explicit: stop I/O, sync, unmount, deactivate where needed, and log out of non-MP iSCSI.
- After reattach, the operator runs the same ensure command again. The script waits for the consistent path and detects whether it now resolves to a multipath mapper.
- Existing LVM/filesystem metadata is reactivated and checksum/application marker data is verified without any transition-specific mode.

Resize behavior:

- The same ensure command handles a resized volume.
- The script verifies that larger device size is visible through the active path.
- Growth is non-destructive and runs only after existing metadata is healthy.
- Filesystem growth happens only after PV/LV growth succeeds.

### Evidence Requirements

Every run writes a timestamped evidence directory. It must contain:

- `summary.txt`
- `imds_volume_attachments.json`
- `oci_agent_status.txt`
- `oci_agent_versions.txt`
- `oci_blockautoconfig.log.tail`
- `iscsi_sessions.txt`
- `iscsi_nodes.txt`
- `iscsi_node_files.txt`
- `multipath_ll.txt`
- `multipathd_paths.txt`
- `oracleoci_links.txt`
- `readlink_map.txt`
- `lsblk.txt`
- `blkid.txt`
- `lvm.txt`
- `findmnt.txt`
- `fstab.txt`
- `kernel_journal.txt`
- `network_prerequisites.txt`
- action logs.

The integration harness must also archive OCI volume and volume-attachment JSON before and after each lifecycle phase.

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration because the script must be validated against live OCI iSCSI, UHP multipath, and resize behavior.
- **Regression:** integration because the implementation touches the same operational surface as Sprint 27 and must not regress TC4 behavior.

#### Unit Test Targets

No unit suite exists in this repository. Parser and guard behavior will be exercised through fast integration checks in the Sprint 28 script until a unit harness exists.

#### Single-Instance Live Test Topology

The live integration suite must create one OCI compute instance for the whole Sprint 28 run and reuse it for all live cases. The test harness may create, attach, detach, resize, and reattach disposable block volumes, but it must not destroy and recreate the compute instance between cases. This keeps the run time practical and also validates the real operator model: one host receiving multiple volume operations over time.

Baseline live topology:

- One Oracle Linux compute instance with SSH access.
- Oracle Cloud Agent and Block Volume Management plugin enabled.
- Network path to OCI services through public IP or Oracle Services Network/service gateway.
- One non-UHP disposable block volume for single-LV lifecycle cases.
- One non-UHP disposable block volume for multi-LV layout cases.
- Optional extra disposable block volume only if a negative guardrail case would make reuse unsafe.
- Stable OCI consistent paths for every attachment, for example `/dev/oracleoci/oraclevdb`, `/dev/oracleoci/oraclevdc`, and `/dev/oracleoci/oraclevdd`.

The test order should preserve time and state:

1. Provision the single compute instance once.
2. Create and attach the disposable test volumes at non-UHP performance.
3. Run local static checks.
4. Run all non-MP initialization, idempotency, diagnostics, guardrail, and resize cases on the same instance.
5. Detach one initialized non-MP volume, update it to `100` VPUs/GB, reattach it to the same instance with the same consistent path, and run the MP rediscovery case.
6. Run regression gates after the new-code integration gate.

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
| -------- | --------------------------- | ---------------- | ------------ |
| Static script contract | Local checkout only | Script files exist, no lifecycle `--mode`, no inline remote bodies, repeatable `--lv`, plan mode, locking, redaction, no partition tools, no app migration commands | < 10 sec |
| Single-instance provisioning | OCI tenancy and Sprint 27-style Terraform baseline | One reusable compute instance is created once; all later live cases reuse it | 10-20 min |
| Diagnostics-only baseline | Single compute instance before volume mutation | Evidence bundle contains IMDS/MDS, agent/plugin version/status/logs, iSCSI, multipath, LVM, filesystem, fstab, kernel/journal, network prerequisites | 2-5 min |
| Plan-only fresh empty volume | Same instance plus fresh non-UHP volume | Plan reports intended PV/VG/LV/filesystem/fstab/mount actions, but no storage mutation occurs | 2-5 min |
| Empty volume guardrail | Same instance plus fresh non-UHP volume | Without `--allow-initialize-empty`, script fails closed and does not create PV/VG/LV/filesystem | 2-5 min |
| Fresh single-LV non-MP initialization | Same instance and same fresh non-UHP volume | With `--allow-initialize-empty`, script creates whole-device PV, VG, one LV, filesystem, managed fstab entry, mount, checksum marker | 5-10 min |
| Existing single-LV idempotent re-run | Same initialized volume | Same command without initialization permission performs no destructive action, mounts/validates existing data, checksum preserved | 2-5 min |
| Multi-LV non-MP initialization | Same instance plus second fresh non-UHP volume | Repeatable `--lv` specs create multiple LVs/filesystems/mounts in one VG, checksums preserved for each mount | 5-15 min |
| Multi-LV idempotent re-run | Same multi-LV volume | Re-run reconciles all requested LVs independently without formatting or data loss | 2-5 min |
| Resize single-LV volume | Same initialized single-LV volume | OCI volume resize becomes visible; script runs safe `pvresize`, LV extension, filesystem growth, checksum preserved | 10-20 min |
| Resize multi-LV all-free LV | Same initialized multi-LV volume | Growth policy extends the intended LV only, other LVs and checksums remain stable | 10-20 min |
| Non-MP to MP lifecycle | Same instance and initialized single-LV or multi-LV volume | Clean release, detach/update to `100` VPUs/GB, reattach with same path, agent-managed MP appears, same command reactivates data through consistent path | 20-40 min |
| Reboot persistence and post-boot reconcile | Same instance after initialized storage exists | Instance reboots and remains reachable; iSCSI/agent/device/fstab/LVM/mount state is either recovered automatically or reconciled by the same script; checksum preserved | 10-20 min |
| Open-iSCSI node database safe use | Same instance with non-MP target | Script creates/updates only requested `/etc/iscsi/nodes/<iqn>/<portal>` entry through `iscsiadm`, persists startup policy when requested, and leaves unrelated entries untouched | 2-5 min |
| Unsupported partition table guardrail | Optional extra disposable volume or local loop-device check | Partitioned layout is detected as unsupported; script fails closed and writes diagnostics | 2-10 min |
| Mount-point non-empty guardrail | Same instance on disposable mount path | Non-empty unmounted mount point is refused; script does not hide or move existing files | 2-5 min |
| Concurrent run lock | Same instance and target VG/device | Second invocation exits with lock conflict while first run owns the target | 1-3 min |
| Secret redaction | Same instance with dummy CHAP argument | Logs, summaries, and diagnostics do not print the CHAP secret | 1-3 min |

#### Smoke Test Candidates

No separate smoke suite exists. The static integration scenario is the fast gate for script contract and guardrail checks.

#### RUP Quality Gate Confirmation

RUPStrikesBack covers the required quality gates. Sprint 28 is configured with `Test: integration` and `Regression: integration`, so the applicable gates are:

- **A3 Integration:** run Sprint 28 tests from `progress/sprint_28/new_tests.manifest`.
- **B3 Integration Regression:** run the integration regression suite.

Per `RUPStrikesBack/rules/generic/test_procedures.md`, quality gates run in order and each applicable gate must pass before proceeding. Therefore every designed Sprint 28 integration test that is part of the A3 gate must pass, and the configured B3 regression gate must also pass before Sprint 28 can be marked tested/closed.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: Static script contract and destructive guardrails

- **Preconditions:** repository checkout.
- **Steps:** verify Sprint 28 script paths, CLI help, absence of lifecycle `--mode`, repeatable `--lv`, `--plan-only`, locking, redaction, evidence options, no Terraform color output, no partition tools, no app migration/service commands, and no destructive storage commands without `--allow-initialize-empty`.
- **Expected Outcome:** static checks pass after implementation; before implementation the skeleton fails.
- **Verification:** `tests/integration/test_sprint28_volume_prepare.sh`.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-2: Single-instance provisioning and baseline diagnostics

- **Preconditions:** OCI CLI/Terraform configured, Sprint 1 state exists, quota available.
- **Steps:** create one reusable Oracle Linux compute instance, confirm agent/plugin status, confirm network access path to OCI services, and run `--diagnose-only` before storage mutation.
- **Expected Outcome:** one compute instance is reused for all later live tests; evidence includes IMDS/MDS, OCI metadata, agent status/version/logs, iSCSI, multipath, consistent paths, block inventory, LVM, filesystem, fstab, kernel/journal, and network prerequisites.
- **Verification:** `tests/integration/test_sprint28_volume_prepare.sh`.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-3: Plan-only fresh empty volume

- **Preconditions:** single compute instance exists; fresh non-UHP volume is attached with a consistent path.
- **Steps:** run the ensure command with `--plan-only` and `--allow-initialize-empty`.
- **Expected Outcome:** script reports intended create actions but does not create PV, VG, LV, filesystem, fstab entry, or mount.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-4: Empty volume fail-closed guardrail

- **Preconditions:** same fresh non-UHP volume is still empty.
- **Steps:** run the ensure command without `--allow-initialize-empty`.
- **Expected Outcome:** script fails closed with diagnostics and does not create PV, VG, LV, filesystem, fstab entry, or mount.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-5: Fresh single-LV non-MP initialization

- **Preconditions:** single compute instance exists; fresh non-UHP volume is attached and empty.
- **Steps:** run the ensure command with `--allow-initialize-empty`, one LV definition, and checksum marker creation after mount.
- **Expected Outcome:** whole-device PV, VG, LV, filesystem, managed fstab entry, and mount exist; checksum marker verifies.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-6: Existing single-LV idempotent re-run

- **Preconditions:** IT-5 completed.
- **Steps:** run the same command again without `--allow-initialize-empty`.
- **Expected Outcome:** no destructive commands execute, existing metadata is activated/reconciled, fstab remains managed and stable, checksum marker verifies.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-7: Multi-LV non-MP initialization

- **Preconditions:** same compute instance exists; second fresh non-UHP volume is attached and empty.
- **Steps:** run the ensure command with `--allow-initialize-empty` and multiple repeatable `--lv` specs using fixed-size and `100%FREE` policies.
- **Expected Outcome:** one PV and one VG exist on the volume; all requested LVs/filesystems/mounts exist; checksum marker verifies on each mount.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-8: Multi-LV idempotent re-run

- **Preconditions:** IT-7 completed.
- **Steps:** run the same multi-LV command again without `--allow-initialize-empty`.
- **Expected Outcome:** each LV is reconciled independently; no formatting or destructive command executes; all checksum markers verify.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-9: Single-LV resize and filesystem growth

- **Preconditions:** IT-5 or IT-6 completed.
- **Steps:** increase the OCI volume size, rescan iSCSI, run the same ensure command with growth policy, and verify PV/LV/filesystem size growth.
- **Expected Outcome:** storage grows without reinitializing existing metadata; checksum marker remains valid.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-10: Multi-LV resize with all-free LV

- **Preconditions:** IT-7 or IT-8 completed.
- **Steps:** increase the OCI volume size, run the same multi-LV ensure command, and verify only the LV configured for all-free growth expands.
- **Expected Outcome:** intended LV grows; fixed-size LVs remain stable; all checksum markers remain valid.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-11: Non-MP to UHP MP lifecycle using Sprint 27 TC4 baseline

- **Preconditions:** same compute instance exists; an initialized test volume has checksum data.
- **Steps:** cleanly release Linux storage, detach, update the volume to `100` VPUs/GB, reattach with the same consistent path, wait for agent-managed consistent-path and multipath readiness, run the same ensure command, and verify checksum.
- **Expected Outcome:** the same OCI consistent path resolves through the multipath mapper and existing data is preserved.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-12: Reboot persistence and post-boot reconcile

- **Preconditions:** same compute instance exists; at least one initialized test volume has checksum data and managed fstab entries.
- **Steps:** capture pre-reboot iSCSI, consistent-path, LVM, fstab, findmnt, and checksum evidence; reboot the compute instance; wait for SSH; capture post-reboot diagnostics; run the same ensure command; verify mount state and checksum.
- **Expected Outcome:** instance remains reachable after reboot; managed fstab entries do not block boot; iSCSI/agent/device/LVM state is either already recovered or reconciled by the script; checksum marker remains valid.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-13: Open-iSCSI node database safe use

- **Preconditions:** same compute instance exists; non-MP target IQN and portal are known.
- **Steps:** capture `/etc/iscsi/nodes/` and `iscsiadm -m node` before the run; run the ensure command with `--persist-iscsi automatic`; capture `/etc/iscsi/nodes/` and `iscsiadm -m node` after the run; verify requested target startup policy; compare unrelated node entries.
- **Expected Outcome:** only the requested IQN/portal node record is created or updated through Open-iSCSI/`iscsiadm`; `node.startup` is persisted as requested; unrelated node records are unchanged; evidence archives node DB files and sanitized node listing.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-14: Unsupported partition-table guardrail

- **Preconditions:** same compute instance exists; use a disposable extra volume or a controlled local loop-device equivalent if the live harness supports it.
- **Steps:** present a target with a partition table and run the ensure command.
- **Expected Outcome:** script detects unsupported layout, fails closed, and does not repartition, reformat, or mount.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-15: Mount-point non-empty guardrail

- **Preconditions:** same compute instance exists; disposable mount point contains pre-existing files and is not the expected mounted filesystem.
- **Steps:** run the ensure command for that mount point.
- **Expected Outcome:** script fails closed and does not move, delete, hide, or overwrite existing files.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-16: Concurrent run lock

- **Preconditions:** same compute instance exists; target VG/device is available.
- **Steps:** start one long-running or lock-held invocation, then start a second invocation against the same target.
- **Expected Outcome:** second invocation exits with a clear lock conflict and does not mutate state.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

#### IT-17: Secret redaction

- **Preconditions:** same compute instance exists.
- **Steps:** run a diagnostic or plan command with a dummy CHAP secret value.
- **Expected Outcome:** secret value does not appear in logs, summaries, diagnostics, command traces, or evidence files.
- **Verification:** timestamped Sprint 28 log and evidence directory.
- **Target file:** `tests/integration/test_sprint28_volume_prepare.sh`

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
| ------------ | ----- | ---------- | ----------------- |
| BV4DB-63 | n/a | n/a | IT-1, IT-2, IT-3, IT-4, IT-5, IT-6, IT-7, IT-8, IT-9, IT-10, IT-11, IT-12, IT-13, IT-14, IT-15, IT-16, IT-17 |
| BV4DB-70 | n/a | n/a | IT-12, IT-13 |

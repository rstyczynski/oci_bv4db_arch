# Sprint 25 - Bugs

## BUG-1: Persistent path and LVM migration safety must be explicit

**Item:** BV4DB-58 / BV4DB-59
**Severity:** high
**Status:** fixed

- **Symptom**: Sprint 25 Terraform and manuals did not make the persistent device path requirement and existing-LVM data-preservation workflow explicit enough for an operator migrating volumes that were previously attached with manual `iscsiadm` commands and transient Linux device names.
- **Root cause**: Oracle requires device paths for Ultra High Performance attachments, and existing LVM stacks must be rediscovered/reactivated after reattach. The original Sprint 25 text could be read as recreating LVM, which would risk data loss if an operator ran `pvcreate`, `vgcreate`, `lvcreate`, or `mkfs` on existing volumes.
- **Fix**: Added Terraform validation requiring `/dev/oracleoci/oraclevd[b-z]`, added helper-side `DEVICE_PATH` validation, documented persistent-path requirements, and added a sentinel-file LVM preservation procedure that verifies data after `pvscan`, `vgscan`, `vgchange -ay`, and remount. The fix follows Oracle's requirement that UHP volume attachments use a consistent device path.
- **Verification**: Integration test checks persistent-path validation and verifies the manual documents sentinel checksum plus non-destructive LVM reactivation commands. Latest gate: `progress/sprint_25/test_run_A3_integration_20260508_112519.log` passed the persistent-path/LVM safety checks and then failed at the existing live native OCI gate because Terraform/OCI authentication returned `401-NotAuthenticated`.

## BUG-2: Native probe must not force agent auto iSCSI login flag

**Item:** BV4DB-59
**Severity:** high
**Status:** fixed

- **Symptom**: The native no-helper module set `is_agent_auto_iscsi_login_enabled = true` on `oci_core_volume_attachment`, which made the test less pure: it mixed Terraform attachment auto-login behavior with the intended Block Volume Management plugin discovery flow.
- **Root cause**: The initial native probe tried to expose every likely agent-related provider field. For BV4DB-59, that is not the desired hypothesis. The hypothesis is that persistent path plus the enabled Block Volume Management plugin is sufficient for the agent to perform the login and multipath setup from metadata.
- **Fix**: Removed `is_agent_auto_iscsi_login_enabled` and the `enable_agent_auto_iscsi_login` variable from `terraform/sprint25-agent-multipath-native/`. Kept the persistent `device` path.
- **Verification**: Integration test asserts the native module no longer contains `is_agent_auto_iscsi_login_enabled` and reruns the live native Terraform gate.

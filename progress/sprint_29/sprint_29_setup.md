# Sprint 29 - Setup

## Contract

Sprint 29 delivers BV4DB-71 as an operator runbook. The runbook must describe a safe conversion from a single-path OCI block-volume attachment to a multipath attachment, preserve existing data, and include verification and recovery guidance. The sprint is managed: design approval is required before construction.

The implementation must preserve the repository's RUP boundaries. It may update only Sprint 29 artifacts and specifically approved implementation files, keep `RUPStrikesBack/` read-only, avoid destructive operations except against explicitly disposable validation data, and keep Terraform/test evidence logs plain ASCII with Terraform color disabled. Existing user changes outside the Sprint 29 scope must remain untouched.

## Analysis

Sprint 24 is the baseline for the target state. Its validated Oracle Cloud Agent Block Volume Management path creates an OCI `is-multipath=true` iSCSI attachment, then the plugin creates the iSCSI sessions, dm-multipath configuration, mapper-backed consistent device path, and associated guest state. The Sprint 29 runbook must not replace that plugin-owned configuration with manual `iscsiadm` logins, `mpathconf`, or custom multipath policy writes.

Sprint 27 provides the conversion evidence: changing an attached single-path/non-UHP volume to UHP in place does not establish the required multipath attachment; the safe route is a clean storage release, OCI detach, performance/attachment transition, and reattach, followed by plugin-managed discovery and validation. The runbook must clearly distinguish OCI prerequisites from guest filesystem and application lifecycle actions.

The Sprint 24 evidence also recorded a `user agent can not be blank` plugin warning while the guest paths came up. The design must therefore treat OCI service-network access and agent IAM permissions as mandatory preflight checks, and require a healthy reporting state rather than accepting only a guest-side mapper as success.

No critical ambiguity remains: the target is an Oracle-documented, OCI Agent-managed multipath configuration using Sprint 24 as the baseline, with data safety and recovery made explicit for the existing single-path workload.

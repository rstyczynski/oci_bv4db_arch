# Sprint 26 - Vanilla Oracle-Documented UHP Attachment Probe

This module is the BV4DB-60 clean-room Terraform probe. It follows Oracle's documented UHP multipath prerequisites without Sprint 25 investigation toggles.

The module creates:

- one Oracle Linux compute instance with Oracle Cloud Agent Block Volume Management enabled;
- one UHP block volume at `120` VPUs/GB;
- one native `oci_core_volume_attachment` with `attachment_type = "iscsi"` and an explicit persistent `device` path.

It deliberately does not use a raw API helper, `isMultipath`, `is_agent_auto_iscsi_login_enabled`, guest `iscsiadm`, guest multipath configuration, or custom `/etc/multipath.conf`.

## Validation

The live integration test is `tests/integration/test_sprint26_vanilla_uhp_attachment.sh`. It copies this module to a temporary directory, creates a temporary SSH key, applies the module against Sprint 1 OCI context, waits for OCI attachment metadata, and records either positive multipath evidence or a documented negative result.

## Official References

- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/multipathcheck.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/References/consistentdevicepaths.htm>

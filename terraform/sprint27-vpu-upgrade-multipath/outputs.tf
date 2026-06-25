output "instance_id" {
  description = "Created compute instance OCID."
  value       = oci_core_instance.vpu_upgrade.id
}

output "instance_public_ip" {
  description = "Public IP for SSH validation when assign_public_ip is true."
  value       = oci_core_instance.vpu_upgrade.public_ip
}

output "volume_id" {
  description = "Created block volume OCID."
  value       = oci_core_volume.test.id
}

output "volume_attachment_id" {
  description = "Native OCI Terraform volume attachment OCID."
  value       = oci_core_volume_attachment.test.id
}

output "device_path" {
  description = "Persistent OCI device path requested for the attachment."
  value       = var.device_path
}

output "is_multipath" {
  description = "Computed OCI attachment multipath status."
  value       = oci_core_volume_attachment.test.is_multipath
}

output "multipath_devices" {
  description = "Computed multipath target devices returned by OCI."
  value       = oci_core_volume_attachment.test.multipath_devices
}

output "iscsi_login_state" {
  description = "Computed iSCSI login state returned by OCI."
  value       = oci_core_volume_attachment.test.iscsi_login_state
}

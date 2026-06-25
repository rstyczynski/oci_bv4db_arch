output "instance_id" {
  description = "Created compute instance OCID."
  value       = oci_core_instance.vanilla.id
}

output "instance_public_ip" {
  description = "Public IP for SSH validation when assign_public_ip is true."
  value       = oci_core_instance.vanilla.public_ip
}

output "volume_id" {
  description = "Created UHP block volume OCID."
  value       = oci_core_volume.uhp.id
}

output "volume_attachment_id" {
  description = "Vanilla native OCI Terraform volume attachment OCID."
  value       = oci_core_volume_attachment.uhp.id
}

output "device_path" {
  description = "Persistent OCI device path requested for the attachment."
  value       = var.device_path
}

output "is_multipath" {
  description = "Computed OCI attachment multipath status."
  value       = oci_core_volume_attachment.uhp.is_multipath
}

output "multipath_devices" {
  description = "Computed multipath target devices returned by OCI."
  value       = oci_core_volume_attachment.uhp.multipath_devices
}

output "iscsi_login_state" {
  description = "Computed iSCSI login state returned by OCI."
  value       = oci_core_volume_attachment.uhp.iscsi_login_state
}

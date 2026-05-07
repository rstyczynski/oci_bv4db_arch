output "instance_id" {
  description = "Created compute instance OCID."
  value       = oci_core_instance.agent_multipath.id
}

output "volume_id" {
  description = "Created UHP block volume OCID."
  value       = oci_core_volume.uhp.id
}

output "volume_attachment_id" {
  description = "Native OCI Terraform volume attachment OCID."
  value       = oci_core_volume_attachment.uhp_native.id
}

output "is_multipath" {
  description = "Computed OCI attachment multipath status. Must be true after live apply for BV4DB-59 to pass."
  value       = oci_core_volume_attachment.uhp_native.is_multipath
}

output "multipath_devices" {
  description = "Computed multipath target devices returned by OCI."
  value       = oci_core_volume_attachment.uhp_native.multipath_devices
}

output "device_path" {
  description = "Consistent device path requested for the native attachment."
  value       = var.device_path
}

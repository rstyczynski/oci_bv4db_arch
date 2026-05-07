output "instance_id" {
  description = "Created compute instance OCID."
  value       = oci_core_instance.agent_multipath.id
}

output "volume_id" {
  description = "Created UHP block volume OCID."
  value       = oci_core_volume.uhp.id
}

output "attachment_state_file" {
  description = "Path to sanitized multipath attachment JSON written by the helper."
  value       = terraform_data.multipath_attachment.input.attachment_state_file
}

output "device_path" {
  description = "Consistent device path requested for the multipath attachment."
  value       = var.device_path
}

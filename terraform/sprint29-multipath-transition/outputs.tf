output "instance_id" { value = oci_core_instance.transition.id }
output "volume_id" { value = oci_core_volume.transition.id }
output "attachment_id" { value = oci_core_volume_attachment.transition.id }
output "is_multipath" { value = oci_core_volume_attachment.transition.is_multipath }
output "device_path" { value = var.device_path }
output "run_command_dynamic_group_id" { value = oci_identity_dynamic_group.run_command.id }
output "run_command_policy_id" { value = oci_identity_policy.run_command.id }

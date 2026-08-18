provider "oci" {
  region              = var.region
  config_file_profile = var.oci_profile
}

resource "oci_identity_dynamic_group" "run_command" {
  compartment_id = var.tenancy_id
  description    = "Sprint 29 instances allowed to poll their own OCI Run Commands."
  matching_rule  = "instance.compartment.id = '${var.compartment_id}'"
  name           = "${var.name_prefix}-run-command-dg"
}

resource "oci_identity_policy" "run_command" {
  compartment_id = var.tenancy_id
  description    = "Sprint 29 OCI Run Command execution policy."
  name           = "${var.name_prefix}-run-command-policy"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.run_command.name} to use instance-agent-command-execution-family in compartment id ${var.compartment_id} where request.instance.id=target.instance.id",
  ]
}

resource "oci_core_instance" "transition" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  display_name        = "${var.name_prefix}-instance"
  shape               = var.compute_shape

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false

    plugins_config {
      name          = "Block Volume Management"
      desired_state = "ENABLED"
    }

    plugins_config {
      name          = "Compute Instance Run Command"
      desired_state = "ENABLED"
    }
  }

  create_vnic_details {
    assign_public_ip = true
    subnet_id        = var.subnet_id
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data           = base64encode(file("${path.module}/cloud-init.yaml"))
  }

  shape_config {
    ocpus         = var.compute_ocpus
    memory_in_gbs = var.compute_memory_gb
  }

  source_details {
    source_id   = var.image_id
    source_type = "image"
  }

  depends_on = [oci_identity_policy.run_command]
}

resource "oci_core_volume" "transition" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  display_name        = "${var.name_prefix}-volume"
  size_in_gbs         = var.volume_size_gbs
  vpus_per_gb         = var.volume_vpus_per_gb
}

resource "oci_core_volume_attachment" "transition" {
  attachment_type                   = "iscsi"
  device                            = var.device_path
  instance_id                       = oci_core_instance.transition.id
  is_agent_auto_iscsi_login_enabled = true
  volume_id                         = oci_core_volume.transition.id
}

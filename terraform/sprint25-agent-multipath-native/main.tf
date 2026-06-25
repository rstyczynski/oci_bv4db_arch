provider "oci" {
  region = var.region
}

locals {
  display_name = var.name_prefix
}

resource "oci_core_instance" "agent_multipath" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  display_name        = "${local.display_name}-instance"
  shape               = var.compute_shape

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false

    plugins_config {
      name          = "Block Volume Management"
      desired_state = "ENABLED"
    }
  }

  create_vnic_details {
    assign_public_ip = var.assign_public_ip
    display_name     = "${local.display_name}-vnic"
    subnet_id        = var.subnet_id
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  shape_config {
    ocpus         = var.compute_ocpus
    memory_in_gbs = var.compute_memory_gb
  }

  source_details {
    source_id   = var.image_id
    source_type = "image"
  }

  preserve_boot_volume = false
}

resource "oci_core_volume" "uhp" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  display_name        = "${local.display_name}-uhp"
  size_in_gbs         = var.volume_size_gbs
  vpus_per_gb         = var.volume_vpus_per_gb
}

# Native Terraform variant for BV4DB-59. The OCI provider exposes is_multipath
# as computed state, so this resource intentionally does not force it. Oracle
# documents that Block Volume attempts to enable UHP multipath at attach time
# when prerequisites are met; a live apply must verify attachment.is_multipath.
resource "oci_core_volume_attachment" "uhp_native" {
  attachment_type = "iscsi"
  compartment_id  = var.compartment_id
  device          = var.device_path
  display_name    = "${local.display_name}-attachment"
  instance_id     = oci_core_instance.agent_multipath.id
  volume_id       = oci_core_volume.uhp.id
}

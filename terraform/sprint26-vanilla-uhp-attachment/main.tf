provider "oci" {
  region = var.region
}

locals {
  display_name = var.name_prefix
}

resource "oci_core_instance" "vanilla" {
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

  instance_options {
    are_legacy_imds_endpoints_disabled = true
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

# Vanilla BV4DB-60 attachment: follow Oracle docs with a UHP volume, capable
# shape, enabled Block Volume Management plugin, and a persistent device path.
# No raw API helper, no agent auto-login flag, and no guest-side setup.
resource "oci_core_volume_attachment" "uhp" {
  attachment_type = "iscsi"
  compartment_id  = var.compartment_id
  device          = var.device_path
  display_name    = "${local.display_name}-attachment"
  instance_id     = oci_core_instance.vanilla.id
  volume_id       = oci_core_volume.uhp.id
}

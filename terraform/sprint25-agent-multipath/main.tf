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

# The OCI Terraform provider exposes is_multipath on oci_core_volume_attachment
# as computed-only in current schemas. Sprint 25 therefore keeps Terraform as the
# orchestration entry point and uses the OCI API shape proven by Sprint 24 for
# the one field the provider cannot yet model as an argument.
resource "terraform_data" "multipath_attachment" {
  input = {
    attachment_state_file = abspath("${path.module}/${var.attachment_state_file}")
  }

  triggers_replace = {
    instance_id = oci_core_instance.agent_multipath.id
    volume_id   = oci_core_volume.uhp.id
    device_path = var.device_path
    region      = var.region
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_multipath_attachment.sh"

    environment = {
      INSTANCE_ID           = oci_core_instance.agent_multipath.id
      VOLUME_ID             = oci_core_volume.uhp.id
      DEVICE_PATH           = var.device_path
      OCI_REGION            = var.region
      ATTACHMENT_STATE_FILE = self.input.attachment_state_file
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/detach_multipath_attachment.sh"

    environment = {
      ATTACHMENT_STATE_FILE = self.input.attachment_state_file
    }
  }
}

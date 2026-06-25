variable "region" {
  description = "OCI region, for example eu-zurich-1."
  type        = string
}

variable "compartment_id" {
  description = "Compartment OCID where compute and block volume resources are created."
  type        = string
}

variable "availability_domain" {
  description = "Availability domain name for the instance and block volume."
  type        = string
}

variable "subnet_id" {
  description = "Subnet OCID for the instance primary VNIC."
  type        = string
}

variable "image_id" {
  description = "Oracle Linux image OCID with Oracle Cloud Agent support."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key to inject into the instance metadata."
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for Sprint 26 resources."
  type        = string
  default     = "bv4db-s26-vanilla"
}

variable "compute_shape" {
  description = "Supported compute shape capable of driving UHP block volume load."
  type        = string
  default     = "VM.Standard.E5.Flex"
}

variable "compute_ocpus" {
  description = "OCPUs for flexible shapes. Oracle UHP iSCSI multipath docs require at least 16 OCPUs for VM shapes."
  type        = number
  default     = 16

  validation {
    condition     = var.compute_ocpus >= 16
    error_message = "compute_ocpus must be at least 16 for the vanilla UHP multipath probe."
  }
}

variable "compute_memory_gb" {
  description = "Compute memory in GB for flexible shapes."
  type        = number
  default     = 64
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP. If false, the subnet must provide service gateway access to Oracle services."
  type        = bool
  default     = true
}

variable "volume_size_gbs" {
  description = "UHP block volume size in GB."
  type        = number
  default     = 1500
}

variable "volume_vpus_per_gb" {
  description = "VPUs per GB. Use 120 for Ultra High Performance."
  type        = number
  default     = 120

  validation {
    condition     = var.volume_vpus_per_gb == 120
    error_message = "volume_vpus_per_gb must be 120 for the vanilla UHP probe."
  }
}

variable "device_path" {
  description = "Required OCI consistent device path requested for the UHP attachment."
  type        = string
  default     = "/dev/oracleoci/oraclevdb"

  validation {
    condition     = can(regex("^/dev/oracleoci/oraclevd[b-z]$", var.device_path))
    error_message = "device_path must be an OCI consistent device path such as /dev/oracleoci/oraclevdb."
  }
}

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
  description = "Name prefix for all resources."
  type        = string
  default     = "bv4db-tf-agent-native"
}

variable "compute_shape" {
  description = "Compute shape that supports UHP multipath. VM shapes require 16 or more cores."
  type        = string
  default     = "VM.Standard.E5.Flex"
}

variable "compute_ocpus" {
  description = "Compute OCPUs for flexible shapes. Keep 16 or higher for UHP multipath support."
  type        = number
  default     = 16
}

variable "compute_memory_gb" {
  description = "Compute memory in GB for flexible shapes."
  type        = number
  default     = 64
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to the instance. If false, provide service gateway access to Oracle services."
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
}

variable "device_path" {
  description = "Consistent OCI device path required for UHP multipath enablement."
  type        = string
  default     = "/dev/oracleoci/oraclevdb"
}

variable "enable_agent_auto_iscsi_login" {
  description = "Ask OCI to use Oracle Cloud Agent for iSCSI login. UHP multipath still depends on OCI marking the attachment is_multipath."
  type        = bool
  default     = true
}

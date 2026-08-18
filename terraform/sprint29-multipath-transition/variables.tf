variable "region" { type = string }

variable "oci_profile" {
  description = "OCI config-file profile Terraform uses for provider authentication."
  type        = string
  default     = "DEFAULT"
}

variable "compartment_id" { type = string }
variable "tenancy_id" {
  description = "Tenancy OCID that owns the Sprint 29 Run Command dynamic group and policy."
  type        = string
}
variable "availability_domain" { type = string }
variable "subnet_id" { type = string }
variable "image_id" { type = string }
variable "ssh_public_key_path" { type = string }

variable "name_prefix" {
  type    = string
  default = "bv4db-s29"
}

variable "compute_shape" {
  type    = string
  default = "VM.Standard.E5.Flex"
}

variable "compute_ocpus" {
  type    = number
  default = 8
}

variable "compute_memory_gb" {
  type    = number
  default = 32
}

variable "volume_size_gbs" {
  type    = number
  default = 50
}

variable "volume_vpus_per_gb" {
  type    = number
  default = 20
}

variable "device_path" {
  type    = string
  default = "/dev/oracleoci/oraclevdb"
}

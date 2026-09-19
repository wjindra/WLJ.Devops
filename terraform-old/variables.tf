variable "ubuntu_image" {
  description = "Ubuntu image version to use for all VMs"
  type        = string
  default     = "24.04"
}

variable "cloud_init_file" {
  description = "Path or URL to cloud-init configuration"
  type        = string
  default     = "https://raw.githubusercontent.com/canonical/multipass/refs/heads/main/data/cloud-init-yaml/cloud-init-docker.yaml"
}

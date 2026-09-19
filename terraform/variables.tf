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

variable "bridge_network" {
  description = "Host network to bridge VMs to (see `multipass networks`)"
  type        = string
  default     = "enp2s0"
}

variable "lan_cidr" {
  description = "CIDR of the enp2s0/br-enp2s0 LAN, used to identify each VM's bridged (LAN) address among its ipv4 list"
  type        = string
  default     = "192.168.0.0/24"
}

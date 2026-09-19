terraform {
  required_providers {
    multipass = {
      source  = "larstobi/multipass"
      version = "~> 1.4"
    }
  }
}

provider "multipass" {}

resource "multipass_instance" "qa_pipeline" {
  name           = "qa-pipeline"
  image          = var.ubuntu_image
  cpus           = 2
  memory         = "1G"
  disk           = "20G"
  cloudinit_file = var.cloud_init_file
  bridged        = true
}

resource "multipass_instance" "qa_web" {
  name           = "qa-web"
  image          = var.ubuntu_image
  cpus           = 2
  memory         = "1G"
  disk           = "20G"
  cloudinit_file = var.cloud_init_file
  bridged        = true
}

resource "multipass_instance" "qa_db" {
  name           = "qa-db"
  image          = var.ubuntu_image
  cpus           = 2
  memory         = "2G"
  disk           = "40G"
  cloudinit_file = var.cloud_init_file
  bridged        = true
}

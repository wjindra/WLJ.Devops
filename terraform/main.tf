terraform {
  required_providers {
    multipass = {
      source = "todoroff/multipass"
    }
    tls = {
      source = "hashicorp/tls"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "multipass" {}

resource "multipass_instance" "qa_pipeline" {
  name   = "qa-pipeline"
  image  = var.ubuntu_image
  cpus   = 2
  memory = "1G"
  disk   = "20G"

  cloud_init_file     = var.cloud_init_file
  wait_for_cloud_init = true

  networks {
    name = var.bridge_network
  }
}

resource "multipass_instance" "qa_web" {
  name   = "qa-web"
  image  = var.ubuntu_image
  cpus   = 2
  memory = "1G"
  disk   = "20G"

  cloud_init_file     = var.cloud_init_file
  wait_for_cloud_init = true

  networks {
    name = var.bridge_network
  }
}

resource "multipass_instance" "qa_db" {
  name   = "qa-db"
  image  = var.ubuntu_image
  cpus   = 2
  memory = "2G"
  disk   = "40G"

  cloud_init_file     = var.cloud_init_file
  wait_for_cloud_init = true

  networks {
    name = var.bridge_network
  }
}

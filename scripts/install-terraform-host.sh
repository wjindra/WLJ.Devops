#!/usr/bin/env bash
set -euo pipefail

# Installs Terraform directly on this host via HashiCorp's official APT repo.
#
# Terraform runs on the host (not containerized): the larstobi/multipass
# provider shells out to the `multipass` CLI, which is snap-confined on this
# host and tightly coupled to multipassd's mount namespace, so it doesn't
# hand off cleanly to a generic Docker container.

sudo apt-get update -y
sudo apt-get install -y gnupg software-properties-common

wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y terraform

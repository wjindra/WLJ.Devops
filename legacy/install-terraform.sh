#!/usr/bin/env bash
set -euo pipefail

# Install Terraform on the Ubuntu host from HashiCorp's official APT repository.
# Reference: https://developer.hashicorp.com/terraform/install#linux

sudo apt-get update
sudo apt-get install -y gnupg software-properties-common curl

# Add the HashiCorp GPG key
curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Add the official HashiCorp APT repository for this Ubuntu release
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

sudo apt-get update
sudo apt-get install -y terraform

terraform version
